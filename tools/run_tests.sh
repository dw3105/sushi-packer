#!/bin/sh
# Test runner. No gateslot here: Makefile wraps it; lane checks call it direct (they already hold a lease).
# usage: tools/run_tests.sh <2.0|2.1> '<file>::<describe> > <it>'    one test (lanes, SP-02)
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
# FactorioTest CLI 3.6.0 for both versions (3.0.1 tries to download builtin mods, FND-0003).
# Installed once in main checkout; worktrees share it. CLI shells out to `npx fmtk`, which resolves
# from cwd, so the CLI runs with cwd = its install dir and every path passed is absolute.
MAIN=$(cd "$(git rev-parse --path-format=absolute --git-common-dir)/.." && pwd)
FT=$MAIN/tools/ft
CLI=$FT/node_modules/.bin/factorio-test

game() {  # game <pattern|""> -> runs FactorioTest, writes build/<FV>/results.json
  pattern=$1
  mod=$("$ROOT/tools/stage.sh" "$FV" test)
  data="$ROOT/build/$FV/ftdata"
  mkdir -p "$data/mods"
  test -f "$data/mods/factorio-test_$FT_VER.zip" || cp "$FT_ZIP_DIR/factorio-test_$FT_VER.zip" "$data/mods/"
  test -x "$CLI" || { echo "run_tests: FactorioTest CLI missing: (cd $FT && npm ci)" >&2; exit 2; }
  FT_DIR="$FT" "$ROOT/tools/ft/patch-cli.sh" >/dev/null  # FND-0005: 10 s startup watchdog -> 120 s
  mods="space-age quality elevated-rails"
  test -d "$FACTORIO/data/recycler" && mods="$mods recycler"
  rm -f "$ROOT/build/$FV/results.json"
  set -- run -p "$mod" --factorio-path "$FACTORIO/bin/x64/factorio" -d "$data" --no-reorder-failed-first \
    --output-file "$ROOT/build/$FV/results.json" --mods $mods
  if [ -n "$pattern" ]; then set -- "$@" --test-pattern "$pattern"; fi
  (cd "$FT" && "$CLI" "$@")
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
    # FactorioTest matches string.match(path, pattern); path = "tests.game.<file> > <describe> > <it>".
    mod=$(printf '%s' "${file%.lua}" | tr / .)
    path="$mod > $name"
    pat="^$(printf '%s' "$path" | sed 's/[][().%+*?^$-]/%&/g')\$"
    game "$pat" || true
    python3 - "$ROOT/build/$FV/results.json" "$path" <<'PY'
import json, sys
p, want = sys.argv[1:]
try:
    d = json.load(open(p))
except Exception as e:
    print(f"run_tests: no results file ({e})"); sys.exit(1)
hits = [t for t in d["tests"] if t["path"] == want]
errs = d["summary"].get("describeBlockErrors", 0)
print(f"game test={want!r} result={[t['result'] for t in hits]} describeBlockErrors={errs}")
for t in hits:
    for e in t.get("errors", []): print("  " + e)
sys.exit(0 if len(hits) == 1 and hits[0]["result"] == "passed" and errs == 0 else 1)
PY
    ;;
  *) echo "run_tests: unknown test dir: $file" >&2; exit 2 ;;
esac
