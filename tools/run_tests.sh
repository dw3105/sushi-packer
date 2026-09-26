#!/bin/sh
# Test runner. No gateslot here: Makefile wraps it; lane checks call it direct (they already hold a lease).
# usage: tools/run_tests.sh <2.0|2.1> '<file>::<full test name>'   one test (lanes, SP-02)
#        tools/run_tests.sh <2.0|2.1> --full                       whole suite (integrator only)
# One-test mode fails unless exactly one test ran and passed (typo never passes).
set -eu
FV=${1:?usage: tools/run_tests.sh <2.0|2.1> '<file>::<name>' | --full}
T=${2:?usage: tools/run_tests.sh <2.0|2.1> '<file>::<name>' | --full}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
FACTORIO=${FACTORIO_ROOT:-$HOME/factorio-$FV/factorio}
FT_ZIP_DIR=${FT_ZIP_DIR:-$HOME/share/sushi-packer}
case "$FV" in 2.0) FT_VER=3.0.1 ;; 2.1) FT_VER=3.1.0 ;; *) echo "FV must be 2.0 or 2.1" >&2; exit 2 ;; esac
CLI=$ROOT/tools/ft-$FV/node_modules/.bin/factorio-test

game() {  # game <pattern|""> -> runs FactorioTest, writes build/<FV>/results.json
  pattern=$1
  mod=$("$ROOT/tools/stage.sh" "$FV" test)
  data="$ROOT/build/$FV/ftdata"
  mkdir -p "$data/mods"
  test -f "$data/mods/factorio-test_$FT_VER.zip" || cp "$FT_ZIP_DIR/factorio-test_$FT_VER.zip" "$data/mods/"
  test -x "$CLI" || (cd "$ROOT/tools/ft-$FV" && npm ci --silent --no-audit --no-fund)
  mods="space-age quality elevated-rails"
  test -d "$FACTORIO/data/recycler" && mods="$mods recycler"
  rm -f "$ROOT/build/$FV/results.json"
  set -- run -p "$mod" --factorio-path "$FACTORIO/bin/x64/factorio" -d "$data" --no-reorder-failed-first \
    --output-file "$ROOT/build/$FV/results.json" --mods $mods
  if [ -n "$pattern" ]; then set -- "$@" --test-pattern "$pattern"; fi
  "$CLI" "$@"
}

if [ "$T" = --full ]; then
  status=0
  for f in tests/offline/test_*.lua; do lua5.2 tests/offline/run.lua "$f" || status=1; done
  game "" || status=1
  [ $status = 0 ] && echo "full-$FV-ok"
  exit $status
fi

case "$T" in *::*) ;; *) echo "run_tests: refuse, T must be '<file>::<full test name>', not a file or dir" >&2; exit 2 ;; esac
file=${T%%::*}
name=${T#*::}
test -n "$name" || { echo "run_tests: refuse, empty test name" >&2; exit 2; }
case "$file" in
  tests/offline/*) lua5.2 tests/offline/run.lua "$file" "$name" ;;
  tests/game/*)
    # Lua pattern with magic chars escaped, anchored: matches this one full name only.
    pat="^$(printf '%s' "$name" | sed 's/[][().%+*?^$-]/%&/g')\$"
    game "$pat" || true
    python3 - "$ROOT/build/$FV/results.json" "$name" <<'PY'
import json, sys
p, want = sys.argv[1:]
try:
    d = json.load(open(p))
except Exception as e:
    print(f"run_tests: no results file ({e})"); sys.exit(1)
tests = d.get("tests", d if isinstance(d, list) else [])
ran = [t for t in tests if t.get("result", t.get("status")) not in ("skipped", "todo")]
names = [t.get("path", t.get("name")) for t in ran]
passed = [t for t in ran if t.get("result", t.get("status")) == "passed"]
print(f"game ran={len(ran)} passed={len(passed)} names={names}")
sys.exit(0 if len(ran) == 1 and len(passed) == 1 else 1)
PY
    ;;
  *) echo "run_tests: unknown test dir: $file" >&2; exit 2 ;;
esac
