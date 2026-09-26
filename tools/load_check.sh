#!/bin/sh
# Headless load: stage mod (release mode), create map, fail on any error line. usage: tools/load_check.sh <2.0|2.1>
set -eu
FV=${1:?usage: tools/load_check.sh <2.0|2.1>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/build/load-$FV
STAGE_DIR=$OUT "$ROOT/tools/stage.sh" "$FV" release >/dev/null
FACTORIO=${FACTORIO_ROOT:-$HOME/factorio-$FV/factorio}
rm -f "$OUT/check.zip"
if "$FACTORIO/bin/x64/factorio" --config "$OUT/config.ini" --mod-directory "$OUT/mods" --create "$OUT/check.zip" > "$OUT/load.log" 2>&1 \
   && grep -q "Loading mod sushi-packer" "$OUT/load.log" && ! grep -qiE "error|failed" "$OUT/load.log"; then
  echo "load-check-$FV-ok"
else
  tail -40 "$OUT/load.log"; echo "load-check-$FV-FAIL"; exit 1
fi
