# burn.sh's arithmetic (SPEC scripts:T176, V61). Modes (--arg mode):
#   table  slurped transcript rows -> markdown table, 1 row per model + total
#   self   slurped transcript rows -> the 1 line `Burn: ...` ("no-usage" when none)
#   pr     slurped `gh api .../pulls/N` then `gh pr view --json comments` ->
#          table of trusted Burn lines, the body's first (B117)
# --argjson prices: {model-prefix: [input, output]} in $ per million tokens.

def cents: (. * 100 | round) as $c
    | "\($c / 100 | floor).\($c % 100 | tostring | if length < 2 then "0" + . else . end)";
# A sum of dollars: null marks a model that has no price.
def usd_text: if . == null then "?" else cents end;
def row($label; $in; $cw; $cr; $out; $usd):
    "| \($label) | \($in) | \($cw) | \($cr) | \($out) | \($usd) |";
def sum_of(f): map(f) | add // 0;

def price_of($model):
    [$prices | to_entries[] | select(.key as $k | ($model // "") | startswith($k))]
    | sort_by(.key | length) | last | .value;

def cost($model; $m):
    price_of($model) as $p
    | if $p == null then null
      else ($m.in * $p[0] + $m.cw5 * $p[0] * 1.25 + $m.cw1 * $p[0] * 2
            + $m.cr * $p[0] * 0.1 + $m.out * $p[1]) / 1000000
      end;

# Last row of a message id wins (streaming rows repeat the id).
def models:
    [.[] | select(.type == "assistant" and (.message.usage? != null) and (.message.id? != null)
                         and (.message.model? != "<synthetic>"))]
    | group_by(.message.id) | map(last | .message)
    | group_by(.model) | map({
        model: .[0].model,
        in: sum_of(.usage.input_tokens // 0),
        cw5: sum_of(if .usage.cache_creation != null
                    then .usage.cache_creation.ephemeral_5m_input_tokens // 0
                    else .usage.cache_creation_input_tokens // 0 end),
        cw1: sum_of(.usage.cache_creation.ephemeral_1h_input_tokens // 0),
        cr: sum_of(.usage.cache_read_input_tokens // 0),
        out: sum_of(.usage.output_tokens // 0)
      } | . + {cw: (.cw5 + .cw1), usd: cost(.model; .)});

def totals($ms): {
    in: ($ms | sum_of(.in)), cw: ($ms | sum_of(.cw)), cr: ($ms | sum_of(.cr)),
    out: ($ms | sum_of(.out)),
    known: ($ms | map(select(.usd != null) | .usd) | add // 0),
    unknown: ($ms | map(select(.usd == null)) | length)
  };

def total_usd($t): if $t.unknown == 0 then $t.known | cents
    elif $t.known == 0 then "?" else "\($t.known | cents)+?" end;

def header($first): "| \($first) | in | cw | cr | out | $ |\n|---|---|---|---|---|---|";

def table:
    models as $ms | totals($ms) as $t
    | header("model"),
      ($ms[] | row(.model; .in; .cw; .cr; .out; .usd | usd_text)),
      row("total"; $t.in; $t.cw; $t.cr; $t.out; total_usd($t));

def self:
    models as $ms | totals($ms) as $t
    | if ($ms | length) == 0 then "Burn: unmeasured (no-usage)"
      else "Burn: in=\($t.in) cw=\($t.cw) cr=\($t.cr) out=\($t.out) $\(total_usd($t)) (\($ms | map(.model) | join(", ")))"
      end;

# The `Burn:` lines of the trusted comments, parsed or not.
def trusted_burn_lines:
    [.comments[] | select(.authorAssociation == "OWNER" or .authorAssociation == "MEMBER")
     | .body | split("\n")[]
     | select(startswith("Burn: ") and (startswith("Burn: unmeasured") | not))];

def parse_burn_line:
    capture("^Burn: in=(?<in>[0-9]+) cw=(?<cw>[0-9]+) cr=(?<cr>[0-9]+) out=(?<out>[0-9]+) \\$(?<usd>[0-9.?+]+) \\(");

# `$` of a Burn line: <known>, `?` or <known>+?.
def usd_known: capture("^(?<n>[0-9]+\\.[0-9]{2})?(?<unknown>\\+?\\?)?$");

def pr:
    trusted_burn_lines as $raw
    | [$raw[] | parse_burn_line?] as $ls
    | ($raw | length) - ($ls | length) as $unparsed
    | ($ls | map(.usd | usd_known)) as $usd
    | ($usd | map(select(.n != null) | .n | tonumber) | add // 0) as $known
    | ($usd | map(select((.unknown // "") != "")) | length) + $unparsed as $unknown
    | header("comment"),
      ($ls | to_entries[] | .key as $i | .value
         | row($i + 1; .in; .cw; .cr; .out; .usd)),
      row("total"; $ls | sum_of(.in | tonumber); $ls | sum_of(.cw | tonumber);
          $ls | sum_of(.cr | tonumber); $ls | sum_of(.out | tonumber);
          total_usd({known: $known, unknown: $unknown}));

if $mode == "table" then table
elif $mode == "self" then self
elif $mode == "pr" then
    {comments: [.[0] | {authorAssociation: .author_association, body: (.body // "")}]
               + .[1].comments} | pr
else error("burn.jq: unknown mode \($mode)")
end
