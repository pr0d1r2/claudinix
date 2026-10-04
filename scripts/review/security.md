# Security
Find what lets an attacker, a hostile input or a leaked secret do harm.
- Injection: unquoted variables, `eval`, values reaching a shell, `sh -c` or a prompt unescaped.
- Secrets or private details (tokens, hostnames, paths) written to the repo, logs or the cloud environment.
- Permission rules wider than the task needs, and any path to pushing `main` or bypassing the gate.
- Downloads not pinned to a hash or SHA, and trust given to flake config or remote content.
