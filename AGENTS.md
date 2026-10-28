# AGENTS.md: synapse-board

Development follows [Human-Directed Agentic Engineering (HDAE)](README.md#human-directed-agentic-engineering).
The README defines the human and agent responsibilities and cites Gregory M. Kurtzer's report.

The board is generated output. `BOARD.md` and `index.html` are rendered from the claims ledger, the
repo map and pulse findings, and each render overwrites them.

- Never edit BOARD.md or index.html, by hand or by script. Edits are lost at the next render, and nobody
  reads them as a claim.
- To claim, renew, change state or release work, go through `synapse-claims` (CLI) or `synapse-mcp`
  (MCP tools). To fix a repo's parent or purpose, change `synapse-map` inputs or the repo's `.crumb`.
- Do not use the board to decide whether a target is free: it is a snapshot. Ask `synapse-claims who TARGET`.
- Changes to this repo: `.om` only in `src/`. Every change re-runs `sh tests/run.sh`. A golden change must be
  reviewed as a diff (`UPDATE_GOLDEN=1`) and explained in the commit.
- `serve` stays read-only, GET/HEAD only, and tailnet-only (100.64.0.0/10). Do not add a flag that widens the
  bind range.
