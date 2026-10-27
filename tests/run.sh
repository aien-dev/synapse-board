#!/bin/sh
# tests/run.sh: build synapse-board, then run positive and negative cases in a throwaway directory.
# Env: OMEGA_SRC (default /tmp/Coord/omega-mv), TEST_ROOT (default /tmp/Coord/test-homes/board-run),
#      UPDATE_GOLDEN=1 rewrites tests/golden from the fixture render (review the diff before committing).
# The live serve case runs only when this host has an address inside 100.64.0.0/10; otherwise NOT_RUN.
# Exit 0 only if every case that ran passed.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
OMEGA_SRC=${OMEGA_SRC:-/tmp/Coord/omega-mv}
TEST_ROOT=${TEST_ROOT:-/tmp/Coord/test-homes/board-run}
fx=$here/tests/fixtures
gd=$here/tests/golden
rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT/bin"
B=$TEST_ROOT/bin/synapse-board
pass=0 fail=0 notrun=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1"; }
# expect NAME WANT_RC CMD...: run CMD, compare its exit code
expect() {
  name=$1 want=$2; shift 2
  "$@" > "$TEST_ROOT/out.txt" 2> "$TEST_ROOT/err.txt"; rc=$?
  if [ "$rc" = "$want" ]; then ok "$name (rc=$rc)"; else bad "$name (rc=$rc, want $want)"; sed 's/^/  stderr: /' "$TEST_ROOT/err.txt"; fi
}

if ! sh "$here/build.sh" "$OMEGA_SRC" "$B"; then
  echo "FAIL build"
  exit 1
fi
echo "PASS build"

NOW=2026-10-27T02:00:00Z
HEAD=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
R=$TEST_ROOT/r1
expect render-fixture 0 "$B" render --claims "$fx/claims.jsonl" --map "$fx/map.jsonl" --findings "$fx/findings.jsonl" --out "$R" --now $NOW --head $HEAD
want='{"ok":true,"files":2,"active":6,"conflicts":1,"findings":3,"repos":9,"head":"'$HEAD'"}'
[ "$(cat "$TEST_ROOT/out.txt")" = "$want" ] && ok "render stdout json" || { bad "render stdout json"; cat "$TEST_ROOT/out.txt"; }
if [ "${UPDATE_GOLDEN:-0}" = 1 ]; then
  mkdir -p "$gd" && cp "$R/BOARD.md" "$R/index.html" "$gd/" && echo "NOTE golden rewritten"
fi
for f in BOARD.md index.html; do
  if cmp -s "$R/$f" "$gd/$f"; then ok "golden $f"; else bad "golden $f"; diff "$gd/$f" "$R/$f" | sed -n 1,20p; fi
done
ls -a "$R" | grep -q '\.tmp$' && bad "no leftover .tmp" || ok "no leftover .tmp"

# escaping: the fixture intent carries <script>alert(1)</script>
grep -qi '<script' "$R/index.html" && bad "html has no <script" || ok "html has no <script"
grep -qi '<script' "$R/BOARD.md" && bad "md has no <script" || ok "md has no <script"
grep -q '&lt;script&gt;alert(1)&lt;/script&gt;' "$R/index.html" && ok "html escapes script" || bad "html escapes script"
grep -q '&lt;script&gt;alert(1)&lt;/script&gt;' "$R/BOARD.md" && ok "md escapes script" || bad "md escapes script"
grep -q 'href="javascript' "$R/index.html" && bad "javascript: never linked" || ok "javascript: never linked"
grep -q 'href="https://github.com/aien-dev/omega-mv/pull/880"' "$R/index.html" && ok "safe evidence linked" || bad "safe evidence linked"
grep -q 'href="https://aienos.com/community' "$R/index.html" && bad "quoted URL not linked" || ok "quoted URL not linked"
grep -Eqi '<(script|iframe|object|embed|link|img)|src=|http-equiv="refresh"' "$R/index.html" && bad "no active/external elements" || ok "no active/external elements"
grep -q 'Vulkan GLCompute \\| SPIR-V' "$R/BOARD.md" && ok "md pipe escaped" || bad "md pipe escaped"
grep -q 'LAPSED' "$R/BOARD.md" && ok "lapsed marked" || bad "lapsed marked"
grep -q 'INFERRED: name-prefix synapse-' "$R/BOARD.md" && ok "inferred parent marked" || bad "inferred parent marked"
grep -q '\[cycle\]' "$R/BOARD.md" && ok "cycle reported" || bad "cycle reported"

# determinism and re-render over existing files
R2=$TEST_ROOT/r2
expect render-again 0 "$B" render --claims "$fx/claims.jsonl" --map "$fx/map.jsonl" --findings "$fx/findings.jsonl" --out "$R2" --now $NOW --head $HEAD
expect render-overwrite 0 "$B" render --claims "$fx/claims.jsonl" --map "$fx/map.jsonl" --findings "$fx/findings.jsonl" --out "$R2" --now $NOW --head $HEAD
cmp -s "$R/BOARD.md" "$R2/BOARD.md" && cmp -s "$R/index.html" "$R2/index.html" && ok "deterministic" || bad "deterministic"

# clock: without --now the generated-by time is the current UTC second
t0=$(date -u +%s)
expect render-clock 0 "$B" render --claims "$fx/claims.jsonl" --map "$fx/map.jsonl" --out "$TEST_ROOT/r3"
t1=$(date -u +%s)
ts=$(sed -n 's/.* at \([0-9TZ:-]*\)_$/\1/p' "$TEST_ROOT/r3/BOARD.md")
tv=$(date -u -d "$ts" +%s 2>/dev/null || echo -1)
[ "$tv" -ge "$t0" ] && [ "$tv" -le "$t1" ] && ok "clock iso ($ts)" || bad "clock iso ($ts not in $t0..$t1)"
grep -q 'ledger head unknown' "$TEST_ROOT/r3/BOARD.md" && ok "head unknown" || bad "head unknown"
grep -q 'none' "$TEST_ROOT/r3/BOARD.md" && ok "no findings file = empty" || bad "no findings file = empty"

# negative cases
expect missing-claims 4 "$B" render --claims "$TEST_ROOT/nope.jsonl" --map "$fx/map.jsonl" --out "$TEST_ROOT/n1"
expect missing-map 4 "$B" render --claims "$fx/claims.jsonl" --map "$TEST_ROOT/nope.jsonl" --out "$TEST_ROOT/n1"
expect missing-findings-ok 0 "$B" render --claims "$fx/claims.jsonl" --map "$fx/map.jsonl" --findings "$TEST_ROOT/nope.jsonl" --out "$TEST_ROOT/n2"
expect bad-claims 65 "$B" render --claims "$fx/bad-claims.jsonl" --map "$fx/map.jsonl" --out "$TEST_ROOT/n1"
grep -q 'claims:2:' "$TEST_ROOT/err.txt" && ok "bad-claims names line 2" || bad "bad-claims names line 2"
expect bad-map 65 "$B" render --claims "$fx/claims.jsonl" --map "$fx/bad-map.jsonl" --out "$TEST_ROOT/n1"
[ -e "$TEST_ROOT/n1/BOARD.md" ] && bad "nothing written on refusal" || ok "nothing written on refusal"
expect no-out 64 "$B" render --claims "$fx/claims.jsonl" --map "$fx/map.jsonl"
expect bad-now 64 "$B" render --claims "$fx/claims.jsonl" --map "$fx/map.jsonl" --out "$TEST_ROOT/n1" --now '2026<x>'
expect bad-head 64 "$B" render --claims "$fx/claims.jsonl" --map "$fx/map.jsonl" --out "$TEST_ROOT/n1" --head XYZ
expect unknown-flag 64 "$B" render --claims "$fx/claims.jsonl" --map "$fx/map.jsonl" --out "$TEST_ROOT/n1" --bogus 1
expect dup-flag 64 "$B" render --claims "$fx/claims.jsonl" --claims "$fx/claims.jsonl" --map "$fx/map.jsonl" --out "$TEST_ROOT/n1"
expect no-command 64 "$B"
expect bad-command 64 "$B" delete --out "$TEST_ROOT/n1"
expect serve-0.0.0.0 64 "$B" serve --dir "$R" --bind 0.0.0.0:18731 --max 1
expect serve-127.0.0.1 64 "$B" serve --dir "$R" --bind 127.0.0.1:18731 --max 1
expect serve-100.128.0.1 64 "$B" serve --dir "$R" --bind 100.128.0.1:18731 --max 1
expect serve-100.63.255.255 64 "$B" serve --dir "$R" --bind 100.63.255.255:18731 --max 1
expect serve-no-port 64 "$B" serve --dir "$R" --bind 100.64.0.1 --max 1
expect serve-no-dir 64 "$B" serve --bind 100.64.0.1:18731 --max 1
expect serve-render-flag 64 "$B" serve --dir "$R" --bind 100.64.0.1:18731 --out "$R"

# live serve on this host's tailnet address (GET only, read-only, one connection)
tip=$(ip -4 -o addr show 2>/dev/null | sed -n 's/.* inet \(100\.[0-9.]*\)\/.*/\1/p' | while read -r a; do
  o2=$(echo "$a" | cut -d. -f2); [ "$o2" -ge 64 ] && [ "$o2" -le 127 ] && echo "$a"; done | head -n 1)
if [ -n "$tip" ] && command -v curl >/dev/null; then
  port=${SERVE_PORT:-18731}
  "$B" serve --dir "$R" --bind "$tip:$port" --max 1 > "$TEST_ROOT/serve.out" 2> "$TEST_ROOT/serve.err" &
  spid=$!
  i=0; while [ $i -lt 50 ] && ! grep -q serving "$TEST_ROOT/serve.out"; do sleep 0.1; i=$((i+1)); done
  code=$(curl -s -o "$TEST_ROOT/got.html" -w '%{http_code}' --max-time 5 "http://$tip:$port/")
  i=0; while [ $i -lt 50 ] && kill -0 $spid 2>/dev/null; do sleep 0.1; i=$((i+1)); done
  if kill -0 $spid 2>/dev/null; then kill $spid; bad "serve exits after --max 1"; else ok "serve exits after --max 1"; fi
  wait $spid 2>/dev/null
  [ "$code" = 200 ] && cmp -s "$TEST_ROOT/got.html" "$R/index.html" && ok "live serve GET / on $tip:$port" || bad "live serve GET / ($code)"
else
  notrun=$((notrun+1)); echo "NOT_RUN live serve (no 100.64.0.0/10 address on this host)"
fi

echo "SUMMARY pass=$pass fail=$fail not_run=$notrun"
[ "$fail" = 0 ]
