# Extensibility
Find where the next likely addition will need edits in many places instead of one.
- Lists and cases hard-coded in code that the spec or docs say will grow, if the repository has them.
- Choices that close off an obvious next step named in the repository's open tasks or roadmap, if it has one.
- Interfaces (flags, files, env vars, output formats) that cannot change without breaking callers.
- Do not ask for abstraction no open task needs.
