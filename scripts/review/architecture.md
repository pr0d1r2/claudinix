# Architecture
Find where the change puts responsibility in the wrong place.
- Files and rows outside the spec node that owns them (`§F`: owns and does not own).
- New coupling between nodes, or between session code and repository-only tooling.
- A second way to do something the repository already does one way.
- Changes that break the layering: setup, agent home, dev shell, gate, launchers.
