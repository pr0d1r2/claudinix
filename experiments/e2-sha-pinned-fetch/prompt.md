EXP E2: SHA-pinned fetch (experiments:T57). In this session, with
REPO = <owner>/<repo> of this repository and SHA = a full 40-hex commit
already pushed to $REPO:
1. HTTP_STATUS=$(curl -sS --connect-timeout 10 --max-time 60 \
     --output setup.sh --write-out '%{http_code}' \
     "https://raw.githubusercontent.com/$REPO/$SHA/setup.sh")
   Stop unless $HTTP_STATUS is 200: curl saves an error page too.
   Compare `sha256sum setup.sh` with `git show "$SHA:setup.sh" | sha256sum`.
2. time nix build --no-link --print-out-paths \
     "git+https://github.com/$REPO?rev=$SHA&shallow=1#homeConfigurations.cloud.activationPackage"
Report the HTTP status, both hashes, the store path, the wall time and which
caches served the paths.
