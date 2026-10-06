#!/bin/bash
set -eu
FV=${1:?usage: tools/dump_data.sh <FV> <MODDIR> [sa]}
MODDIR=${2:?usage: tools/dump_data.sh <FV> <MODDIR> [sa]}
SA=${3:-}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$HOME/.cache/sushi-packer/dump-$FV"
FACTORIO="$HOME/factorio-$FV/factorio/bin/x64/factorio"
rm -rf "$OUT"
mkdir -p "$OUT"
STAGE_DIR="$OUT" "$ROOT/tools/stage.sh" "$FV" release >/dev/null
MODS="$OUT/mods"
python3 - "$MODDIR" "$MODS" "$SA" <<'PY'
import errno, json, os, shutil, sys
srcdir, modsdir, sa = sys.argv[1:]
names = ["base", "sushi-packer"]
for filename in sorted(os.listdir(srcdir)):
    if not filename.endswith(".zip"):
        continue
    name = filename.rsplit("_", 1)[0]
    src, dst = os.path.join(srcdir, filename), os.path.join(modsdir, filename)
    try:
        os.link(src, dst)
    except OSError as e:
        if e.errno != errno.EXDEV:
            raise
        shutil.copy2(src, dst)
    names.append(name)
extra = ["space-age", "quality", "elevated-rails", "recycler"]
if sa == "sa":
    names += extra
mods = [{"name": n, "enabled": True} for n in dict.fromkeys(names)]
if sa != "sa":
    mods += [{"name": n, "enabled": False} for n in extra]
with open(os.path.join(modsdir, "mod-list.json"), "w") as f:
    json.dump({"mods": mods}, f, indent=2)
PY
if ! "$FACTORIO" --config "$OUT/config.ini" --mod-directory "$MODS" --dump-data >"$OUT/dump.log" 2>&1; then
  tail -n 30 "$OUT/dump.log"
  exit 1
fi
grep 'Loading mod sushi-packer' "$OUT/dump.log" || true
"$ROOT/tools/dump_report.py" "$OUT/write/script-output/data-raw-dump.json"
echo "dump-data-$FV-ok"
