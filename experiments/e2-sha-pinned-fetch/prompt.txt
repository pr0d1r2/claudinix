EXP E2: SHA-pinned fetch (experiments:T57). In this session, with
REPO = <owner>/<repo> of this repository and SHA = a full 40-hex commit
already pushed to $REPO:
1. curl -sS --connect-timeout 10 --max-time 60 -o setup.sh \
     https://raw.githubusercontent.com/$REPO/$SHA/setup.sh
   Compare its sha256 with `git show $SHA:setup.sh`.
2. time nix build --no-link --print-out-paths \
     "git+https://github.com/$REPO?rev=$SHA&shallow=1#homeConfigurations.cloud.activationPackage"
Report the HTTP status, both hashes, the store path, the wall time and which
caches served the paths.
