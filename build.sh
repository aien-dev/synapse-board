#!/bin/sh
# build.sh OMEGA_SRC OUT: builds OUT (synapse-board, seeded Omega) from src/*.om plus the pinned
# seed/json/json.om and seed/net/http.om libraries.
#   OMEGA_SRC  checkout of aien-dev/omega-mv at the sha in omega.pin (its seed/out/omc must match the pin)
#   OUT        output binary path; OUT.unit.om keeps the concatenated unit, OUT.err omc's diagnostics
# Exit: 0 built; 1 omc rejected the unit (OUT is removed, never run); 64 usage; 65 pin mismatch.
set -eu
[ $# -eq 2 ] || { echo "usage: build.sh OMEGA_SRC OUT" >&2; exit 64; }
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$1" && pwd)
out=$2
case $out in /*) ;; *) out=$(pwd)/$out ;; esac
mkdir -p "$(dirname "$out")"

want_sha=$(sed -n 's|^aien-dev/omega-mv@\([0-9a-f]\{40\}\)$|\1|p' "$here/omega.pin")
want_omc=$(sed -n 's|^omc-sha256 \([0-9a-f]\{64\}\)$|\1|p' "$here/omega.pin")
[ -n "$want_sha" ] && [ -n "$want_omc" ] || { echo "build.sh: omega.pin malformed" >&2; exit 65; }
have_sha=$(git -C "$src" rev-parse HEAD)
[ "$have_sha" = "$want_sha" ] || { echo "build.sh: $src is at $have_sha, omega.pin wants $want_sha" >&2; exit 65; }
have_omc=$(sha256sum "$src/seed/out/omc" | cut -d' ' -f1)
[ "$have_omc" = "$want_omc" ] || { echo "build.sh: omc sha256 $have_omc != pin $want_omc" >&2; exit 65; }

unit=$out.unit.om
{ printf 'om2\n'; cat "$src/seed/json/json.om" "$src/seed/net/http.om" "$here"/src/*.om; } > "$unit"
rm -f "$out" "$out.tmp"
if ! "$src/seed/out/omc" < "$unit" > "$out.tmp" 2> "$out.err"; then
  rm -f "$out.tmp"
  cat "$out.err" >&2
  echo "build.sh: omc rejected $unit" >&2
  exit 1
fi
chmod 755 "$out.tmp"
mv "$out.tmp" "$out"
echo "build.sh: built $out" >&2
