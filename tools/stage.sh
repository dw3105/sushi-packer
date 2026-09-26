#!/bin/sh
# Stage mod for one Factorio version into build/<FV>/: mods/sushi-packer_<ver>/, mod-list.json, config.ini.
# usage: tools/stage.sh <2.0|2.1> [test|release]
# test = include tests/ (in-game test files); release = shipped files only.
set -eu
FV=${1:?usage: tools/stage.sh <2.0|2.1> [test|release]}
MODE=${2:-test}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
case "$FV" in
  2.0) VER=0.1.0 ;;
  2.1) VER=0.2.0 ;;
  *) echo "stage: FV must be 2.0 or 2.1" >&2; exit 2 ;;
esac
OUT=${STAGE_DIR:-$ROOT/build/$FV}
FACTORIO=${FACTORIO_ROOT:-$HOME/factorio-$FV/factorio}
test -x "$FACTORIO/bin/x64/factorio" || { echo "stage: no Factorio at $FACTORIO (make factorio FV=$FV)" >&2; exit 2; }
MOD="$OUT/mods/sushi-packer_$VER"
rm -rf "$OUT/mods/sushi-packer_"*
mkdir -p "$MOD" "$OUT/write"
for f in info.json data.lua settings.lua control.lua changelog.txt thumbnail.png; do
  test -e "$ROOT/$f" && cp "$ROOT/$f" "$MOD/"
done
for d in scripts prototypes locale graphics; do cp -r "$ROOT/$d" "$MOD/"; done
if [ "$MODE" = test ]; then mkdir -p "$MOD/tests"; cp -r "$ROOT/tests/game" "$MOD/tests/"; fi
python3 - "$MOD/info.json" "$FV" "$VER" <<'PY'
import json, sys
p, fv, ver = sys.argv[1:]
d = json.load(open(p)); d["factorio_version"] = fv; d["version"] = ver
json.dump(d, open(p, "w"), indent=2)
PY
# Enable every bundled data mod present in this build (2.1 adds recycler) plus ours and any extra zips in mods/.
python3 - "$FACTORIO/data" "$OUT/mods" <<'PY'
import json, os, sys
data, mods = sys.argv[1:]
names = [n for n in ("base", "elevated-rails", "quality", "recycler", "space-age") if os.path.isdir(os.path.join(data, n))]
names += ["sushi-packer"]
for f in os.listdir(mods):
    if f.startswith("factorio-test_"): names.append("factorio-test")
json.dump({"mods": [{"name": n, "enabled": True} for n in dict.fromkeys(names)]}, open(os.path.join(mods, "mod-list.json"), "w"), indent=2)
PY
cat > "$OUT/config.ini" <<CFG
[path]
read-data=$FACTORIO/data
write-data=$OUT/write
CFG
echo "$MOD"
