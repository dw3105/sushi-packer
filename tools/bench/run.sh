#!/bin/sh
set -eu
FV=${1:?usage: tools/bench/run.sh <2.0|2.1> [options]}
shift
BOXES=200
TICKS=3600
TIER=yellow
MODSET=none
FLOW=single
SEED=1
DRY_RUN=0
usage_error() { echo "run.sh: $1" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --boxes|--ticks|--tier|--modset|--flow|--seed)
      flag=$1
      [ $# -ge 2 ] || usage_error "missing $flag value"
      value=$2
      case "$value" in --*) usage_error "missing $flag value" ;; esac
      case "$flag" in
        --boxes) BOXES=$value ;;
        --ticks) TICKS=$value ;;
        --tier) TIER=$value ;;
        --modset) MODSET=$value ;;
        --flow) FLOW=$value ;;
        --seed) SEED=$value ;;
      esac
      shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) usage_error "unknown argument: $1" ;;
  esac
done
case "$FV" in 2.0|2.1) ;; *) usage_error "FV must be 2.0 or 2.1" ;; esac
case "$BOXES:$TICKS" in *[!0-9:]*|:*|*:) usage_error "boxes and ticks must be positive integers" ;; esac
[ "$BOXES" -gt 0 ] && [ "$TICKS" -gt 0 ] || usage_error "boxes and ticks must be positive"
case "$TIER" in ''|*[!a-z0-9-]*) usage_error "tier must contain only lowercase letters, digits, and hyphens" ;; esac
case "$SEED" in ''|*[!0-9]*) usage_error "seed must be a non-negative integer" ;; esac
case "$FLOW" in single|stacks) ;; *) usage_error "flow must be single or stacks" ;; esac
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
if [ "$MODSET" != none ]; then
  if ! python3 - "$ROOT/tools/modsets.json" "$FV" "$MODSET" <<'PY'
import json, sys
sets=json.load(open(sys.argv[1])); fv=sys.argv[2]; name=sys.argv[3]
if name not in sets or name.startswith('_'):
    raise SystemExit('run.sh: unknown mod set: ' + name)
if fv not in sets[name].get('fv', []):
    raise SystemExit(f'run.sh: mod set {name} is not available for FV {fv}')
PY
  then exit 2; fi
fi
if [ "$DRY_RUN" -eq 1 ]; then
  echo "bench-dry FV=$FV boxes=$BOXES ticks=$TICKS tier=$TIER modset=$MODSET flow=$FLOW seed=$SEED"
  exit 0
fi
OUT=$ROOT/build/bench-$FV
FACTORIO=${FACTORIO_ROOT:-$HOME/factorio-$FV/factorio}
MAIN=$(cd "$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/.." && pwd)
FT=$MAIN/tools/ft
if [ "$MODSET" = none ]; then
  MODSET= STAGE_DIR=$OUT "$ROOT/tools/stage.sh" "$FV" test >/dev/null
else
  MODSET=$MODSET STAGE_DIR=$OUT "$ROOT/tools/stage.sh" "$FV" test >/dev/null
fi
BENCH=$OUT/mods/sushi-packer-bench_0.1.0
mkdir -p "$BENCH"
cp -R "$ROOT/tools/bench/mod/." "$BENCH/"
python3 - "$BENCH/info.json" "$FV" <<'PY'
import json, sys
p, fv = sys.argv[1:]
d = json.load(open(p)); d['factorio_version'] = fv
json.dump(d, open(p, 'w'), indent=2)
PY
python3 "$ROOT/tools/bench/modlist.py" "$OUT/mods"
SAVE=$OUT/bench.zip
LOG=$OUT/benchmark.log
rm -f "$SAVE" "$LOG"
"$FACTORIO/bin/x64/factorio" --config "$OUT/config.ini" --mod-directory "$OUT/mods" --create "$OUT/init.zip" >"$OUT/init.log" 2>&1
rm -f "$OUT/init.zip"
for pair in "boxes $BOXES" "tier $TIER" "flow $FLOW" "seed $SEED"; do
  set -- $pair
  (cd "$FT" && npx fmtk settings set startup "sushi-packer-bench-$1" "$2" --modsPath "$OUT/mods")
done
"$FACTORIO/bin/x64/factorio" --config "$OUT/config.ini" --mod-directory "$OUT/mods" --create "$SAVE" >"$OUT/create.log" 2>&1
"$FACTORIO/bin/x64/factorio" --config "$OUT/config.ini" --mod-directory "$OUT/mods" --benchmark "$SAVE" --benchmark-ticks "$TICKS" --benchmark-runs 1 --benchmark-verbose all >"$LOG" 2>&1
python3 "$ROOT/tools/bench/parse.py" "$LOG" "$OUT/write/factorio-current.log" "$FV" "$BOXES" "$TICKS" "$TIER" "$MODSET" "$FLOW"
