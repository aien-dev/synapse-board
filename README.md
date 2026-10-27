Child of [aien-dev/synapse](https://github.com/aien-dev/synapse) (pinned in [`synapse.pin`](synapse.pin)).

# synapse-board

`synapse-board` writes the human view of the agent coordination state. It reads the claims ledger
listing, the repo map and the pulse findings, and writes `BOARD.md` and `index.html`. It can also serve
those two files read-only on the tailnet. The board is generated output for humans: agents write
through `synapse-claims` and never edit the board (see [AGENTS.md](AGENTS.md)).

The implementation is seeded Omega (`src/*.om`), compiled with the pinned `omc` together with
`seed/json/json.om` and `seed/net/http.om` from aien-dev/omega-mv (pinned in [`omega.pin`](omega.pin)).
There is no interim host code in the binary. `build.sh` and `tests/run.sh` are POSIX shell build and test
drivers only.

## Build

    sh build.sh /path/to/omega-mv OUT/synapse-board    # omega-mv checked out at the omega.pin sha

`build.sh` checks the omega-mv sha and the `omc` sha256 against `omega.pin`. It concatenates the unit into
`OUT/synapse-board.unit.om` and compiles it. A rejected unit leaves no binary.

## Use

    synapse-claims list --all > claims.jsonl
    synapse-pulse  ...        > findings.jsonl
    synapse-board render --claims claims.jsonl --map map.jsonl --findings findings.jsonl \
        --out /srv/board [--now 2026-10-27T02:00:00Z] [--head <ledger head hex>]
    synapse-board serve --dir /srv/board --bind 100.x.y.z:8731 [--max N]

`render` writes `DIR/BOARD.md` and `DIR/index.html` atomically: it writes a temp file, fsyncs it, then
renames it over the old file. The board contains, in this order:

1. the generated-by line (ledger head, or `unknown` without `--head`)
2. summary counts
3. conflicts (findings with `kind` `conflict`)
4. the other pulse findings
5. active claims grouped by repo, with agent, target, mode, state, intent, expires (`LAPSED` once past
   `--now`) and evidence links
6. the repo map as a tree; `INFERRED` parents show their `infer_rule`, and ROOT, NONE, archived, fork,
   parent-outside-map and cycle are marked

On success `render` prints one JSON line on stdout:
`{"ok":true,"files":2,"active":N,"conflicts":N,"findings":N,"repos":N,"head":"..."}`.

Every input string is escaped for its output.

- **HTML:** `& < > " '` are escaped, and control bytes become spaces.
- **Markdown:** `& < >` are escaped, ``| \ ` [ ]`` get a backslash, and control bytes become spaces.
- **Evidence:** a URL becomes a link only when it is `http://` or `https://` and every byte is in a
  conservative URL set. Any other evidence is shown as text.
- **HTML page:** no scripts and no external assets. It sets the CSP
  `default-src 'none'; style-src 'unsafe-inline'`.

`serve` answers only `GET`/`HEAD` for `/`, `/index.html` and `/BOARD.md`, re-reading the file for each
request. It sends `Cache-Control: no-store`, `nosniff` and the same CSP. Any other method gets 405 and any
other path 404. It refuses to bind any address outside 100.64.0.0/10 (the tailnet range), including
`0.0.0.0` and `127.0.0.1`, with exit 64.

The input formats are defined in COORD-CONTRACT (claims `list --all`, map.jsonl, pulse findings). A
missing findings file counts as empty.

Exit codes: 0 ok, 4 claims or map file missing, 64 usage or refused bind address, 65 malformed input
(stderr names `FILE:LINE`), 70 internal (output over 8 MiB), 75 temporary (write or listen failed).

## Tests

    sh tests/run.sh          # OMEGA_SRC=/path/to/omega-mv TEST_ROOT=/tmp/... optional

The tests cover:

- the fixture render compared byte-for-byte against `tests/golden/`
- `<script>` escaping and URL linking rules
- determinism, and the realtime clock checked against `date -u`
- refusals: missing or malformed input, bad flags, and bind addresses outside the tailnet
- a live `GET /`, run when the host has a tailnet address (otherwise reported NOT_RUN)

CI (`.github/workflows/ci.yml`) runs the same script on `ubuntu-24.04-arm` with omega-mv at the pin.

## Connected repos

- [aien-dev/synapse](https://github.com/aien-dev/synapse): parent.
- [aien-dev/synapse-claims](https://github.com/aien-dev/synapse-claims): signed claims ledger; `list --all` is this tool's claims input.
- [aien-dev/synapse-map](https://github.com/aien-dev/synapse-map): org repo map; `map.jsonl` is the tree input.
- [aien-dev/synapse-pulse](https://github.com/aien-dev/synapse-pulse): pulse findings (conflicts, force-pushes, stale claims).
- [aien-dev/synapse-mcp](https://github.com/aien-dev/synapse-mcp): MCP server through which agents claim and query.

## License

Apache-2.0 (copy of the parent's LICENSE), see [LICENSE](LICENSE).
