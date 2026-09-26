#!/bin/sh
set -eu
FV=${1:?usage: tools/bench/run.sh <2.0|2.1> [--boxes N] [--ticks T]}
shift
BOXES=200
TICKS=3600
while [ $# -gt 0 ]; do
  case "$1" in
    --boxes) BOXES=${2:?missing --boxes value}; shift 2 ;;
    --ticks) TICKS=${2:?missing --ticks value}; shift 2 ;;
    *) echo "run.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$FV" in 2.0|2.1) ;; *) echo "run.sh: FV must be 2.0 or 2.1" >&2; exit 2 ;; esac
case "$BOXES:$TICKS" in *[!0-9:]*|:*|*:) echo "run.sh: boxes and ticks must be positive integers" >&2; exit 2 ;; esac
[ "$BOXES" -gt 0 ] && [ "$TICKS" -gt 0 ] || { echo "run.sh: boxes and ticks must be positive" >&2; exit 2; }
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/bench-$FV
FACTORIO=${FACTORIO_ROOT:-$HOME/factorio-$FV/factorio}
MAIN=$(cd "$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/.." && pwd)
FT=$MAIN/tools/ft
STAGE_DIR=$OUT "$ROOT/tools/stage.sh" "$FV" test >/dev/null
BENCH=$OUT/mods/sushi-packer-bench_0.1.0
mkdir -p "$BENCH"
cp -R "$ROOT/tools/bench/mod/." "$BENCH/"
python3 - "$BENCH/info.json" "$FV" <<'PY'
import json, sys
p, fv = sys.argv[1:]
d = json.load(open(p)); d['factorio_version'] = fv
json.dump(d, open(p, 'w'), indent=2)
PY
python3 - "$FACTORIO/data" "$OUT/mods" <<'PY'
import json, os, sys
data, mods = sys.argv[1:]
names = [n for n in ('base','elevated-rails','quality','recycler','space-age') if os.path.isdir(os.path.join(data,n))]
names += ['sushi-packer','sushi-packer-bench']
json.dump({'mods':[{'name':n,'enabled':True} for n in names]}, open(os.path.join(mods,'mod-list.json'),'w'), indent=2)
PY
SAVE=$OUT/bench.zip
LOG=$OUT/benchmark.log
rm -f "$SAVE" "$LOG"
# Factorio creates the initial settings container the first time it starts with this mod directory.
"$FACTORIO/bin/x64/factorio" --config "$OUT/config.ini" --mod-directory "$OUT/mods" --create "$OUT/init.zip" >"$OUT/init.log" 2>&1
rm -f "$OUT/init.zip"
(cd "$FT" && npx fmtk settings set startup sushi-packer-bench-boxes "$BOXES" --modsPath "$OUT/mods")
"$FACTORIO/bin/x64/factorio" --config "$OUT/config.ini" --mod-directory "$OUT/mods" --create "$SAVE" >"$OUT/create.log" 2>&1
"$FACTORIO/bin/x64/factorio" --config "$OUT/config.ini" --mod-directory "$OUT/mods" --benchmark "$SAVE" --benchmark-ticks "$TICKS" --benchmark-runs 1 --benchmark-verbose all >"$LOG" 2>&1
python3 - "$LOG" "$FV" "$BOXES" "$TICKS" <<'PY'
import csv, re, sys
path, fv, boxes, ticks = sys.argv[1:]
lines = open(path, errors='replace').read().splitlines()
header = next((i for i, line in enumerate(lines) if 'scriptUpdate' in line and 'wholeUpdate' in line), None)
if header is None: raise SystemExit('benchmark parse failed: CSV header missing')
hline = lines[header]
sep = ',' if ',' in hline else ';'
cols = next(csv.reader([hline], delimiter=sep))
si, wi = cols.index('scriptUpdate'), cols.index('wholeUpdate')
values=[]
tick_ids=[]
for line in lines[header+1:]:
    if not line.strip(): continue
    try:
        row=next(csv.reader([line], delimiter=sep))
        if len(row) <= max(si,wi) or not re.fullmatch(r't\d+', row[0]): continue
        a,b=float(row[si]),float(row[wi])
        if a >= 0 and b >= 0:
            values.append((a,b))
            tick_ids.append(int(row[0][1:]))
    except (ValueError, csv.Error): continue
if not values: raise SystemExit('benchmark parse failed: no per-tick rows')
if len(values) != int(ticks) or tick_ids != list(range(int(ticks))):
    raise SystemExit(f'benchmark parse failed: expected {ticks} ordered tick rows, found {len(values)}')
raw_script=sum(x for x,_ in values)/len(values); raw_whole=sum(y for _,y in values)/len(values)
# The verbose CSV timing columns are nanoseconds. Cross-check that unit against
# Factorio's summary average (which is printed in milliseconds) to reject an
# unexpected CSV format rather than silently reporting a wrong scale.
summary = next((re.search(r'avg:\s*([0-9.]+)\s*ms', line) for line in lines if 'avg:' in line and ' ms' in line), None)
if summary is None: raise SystemExit('benchmark parse failed: summary timing units missing')
summary_ms = float(summary.group(1))
scale = 1e-6
if raw_whole <= 0 or abs(raw_whole * scale - summary_ms) > max(0.02, summary_ms * 0.25):
    raise SystemExit('benchmark parse failed: CSV timing units do not match millisecond summary')
sa=raw_script*scale; wa=raw_whole*scale
print(f'bench FV={fv} boxes={boxes} ticks={ticks} script_ms_avg={sa:.3f} whole_ms_avg={wa:.3f}')
PY
