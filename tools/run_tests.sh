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
  data="$ROOT/build/$FV/ftdata${MODSET:+-$MODSET}"  # own data dir per mod set (mod-settings, saves)
  mkdir -p "$data/mods"
  test -f "$data/mods/factorio-test_$FT_VER.zip" || cp "$FT_ZIP_DIR/factorio-test_$FT_VER.zip" "$data/mods/"
  rm -rf "$data/mods/sushi-packer-test-env_"*; cp -r "$(dirname "$mod")/sushi-packer-test-env_0.0.1" "$data/mods/"  # test-only env mod (max belt stack 20)
  # v9 MODSET: same third-party zips + settings mod as staged (stage.sh wrote mods/.modset)
  staged=$(dirname "$mod"); extra=$(cat "$staged/.modset" 2>/dev/null || true)
  rm -rf "$data/mods/sushi-packer-test-settings_"*
  python3 -c "import json,os,sys; l=json.load(open(sys.argv[1])); fs={e['file'] for v in l.values() for e in v.values()}; [os.remove(os.path.join(sys.argv[2],f)) for f in os.listdir(sys.argv[2]) if f in fs]" "$ROOT/tests/mods.lock.json" "$data/mods"
  for f in "$staged"/*.zip; do case "$(basename "$f")" in factorio-test_*) ;; *) cp "$f" "$data/mods/" ;; esac; done 2>/dev/null || true
  test -d "$staged/sushi-packer-test-settings_0.0.1" && cp -r "$staged/sushi-packer-test-settings_0.0.1" "$data/mods/"
  test -x "$CLI" || { echo "run_tests: FactorioTest CLI missing: (cd $FT && npm ci)" >&2; exit 2; }
  FT_DIR="$FT" "$ROOT/tools/ft/patch-cli.sh" >/dev/null  # FND-0005: 10 s startup watchdog -> 120 s
  mods="space-age quality elevated-rails sushi-packer-test-env"
  test -d "$FACTORIO/data/recycler" && mods="$mods recycler"
  mods="$mods $extra"
  rm -f "$ROOT/build/$FV/results.json"
  set -- run -p "$mod" --factorio-path "$FACTORIO/bin/x64/factorio" -d "$data" --no-reorder-failed-first \
    --output-file "$ROOT/build/$FV/results.json" --mods $mods
  if [ -n "$pattern" ]; then set -- "$@" --test-pattern "$pattern"; fi
  (cd "$FT" && "$CLI" "$@")
}

# SP-02 (author 2026-09-26): lanes run offline Lua tests only. Headless Factorio (tests/game, --full)
# is for integrator merge and release. lane_run sets LANE_RUN_ID in engine and checks env.
if [ -n "${LANE_RUN_ID:-}" ]; then
  case "$T" in
    --full|--modtiers|tests/game/*) echo "run_tests: refuse, lanes run offline tests only (SP-02); headless is integrator merge/release" >&2; exit 2 ;;
  esac
fi

if [ "$T" = --full ]; then
  status=0
  for f in tests/offline/test_*.lua; do lua5.2 tests/offline/run.lua "$f" || status=1; done
  game "" || status=1
  [ $status = 0 ] && echo "full-$FV-ok"
  exit $status
fi

# v9: whole tests/game/test_modtiers.lua under current MODSET (integrator, make test-modsets)
if [ "$T" = --modtiers ]; then
  test -n "${MODSET:-}" || { echo "run_tests: --modtiers needs MODSET" >&2; exit 2; }
  game '^tests%.game%.test_modtiers >' || true
  python3 - "$ROOT/build/$FV/results.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
hits = [t for t in d["tests"] if t["path"].startswith("tests.game.test_modtiers >")]
bad = [t for t in hits if t["result"] != "passed"]
for t in bad:
    print("FAIL", t["path"]); [print("  " + e) for e in t.get("errors", [])]
errs = d["summary"].get("describeBlockErrors", 0)
print(f"modtiers ran={len(hits)} failed={len(bad)} describeBlockErrors={errs}")
sys.exit(0 if hits and not bad and errs == 0 else 1)
PY
  exit $?
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
