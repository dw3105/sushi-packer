#!/bin/sh
# Headless load: stage mod (release mode), create map, fail on any error line. usage: tools/load_check.sh <2.0|2.1>
set -eu
FV=${1:?usage: tools/load_check.sh <2.0|2.1>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/build/load-$FV
STAGE_DIR=$OUT "$ROOT/tools/stage.sh" "$FV" release >/dev/null
# Release zip present (make zip) -> load the zip itself, not the staged folder.
case "$FV" in 2.0) VER=0.1.16 ;; 2.1) VER=0.2.16 ;; esac
if [ -f "$ROOT/build/sushi-packer_$VER.zip" ]; then
  rm -rf "$OUT/mods/sushi-packer_$VER"; cp "$ROOT/build/sushi-packer_$VER.zip" "$OUT/mods/"; echo "load-check: using build/sushi-packer_$VER.zip"
fi
FACTORIO=${FACTORIO_ROOT:-$HOME/factorio-$FV/factorio}
rm -f "$OUT/check.zip"
if "$FACTORIO/bin/x64/factorio" --config "$OUT/config.ini" --mod-directory "$OUT/mods" --create "$OUT/check.zip" > "$OUT/load.log" 2>&1 \
   && grep -q "Loading mod sushi-packer" "$OUT/load.log" \
   && if [ -n "${MODSET:-}" ]; then ! grep -iE "error|failed" "$OUT/load.log" | grep -qi "sushi"; else ! grep -qiE "error|failed" "$OUT/load.log"; fi; then
  echo "load-check-$FV${MODSET:+-$MODSET}-ok"
else
  tail -40 "$OUT/load.log"; echo "load-check-$FV${MODSET:+-$MODSET}-FAIL"; exit 1
fi
