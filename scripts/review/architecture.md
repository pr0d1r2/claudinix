# Architecture
Find where the change puts responsibility in the wrong place.
- If the repository has a spec with nodes (`§F`), files and rows outside the node that owns them.
- New coupling between nodes, or between session code and repository-only tooling.
- A second way to do something the repository already does one way.
- Changes that break the repository's layering, such as setup, agent home, dev shell, gate and launchers where it has them.
