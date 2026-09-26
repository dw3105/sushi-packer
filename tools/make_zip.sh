#!/bin/sh
# Release zip for one version: build/sushi-packer_<ver>.zip (no tests/). usage: tools/make_zip.sh <2.0|2.1>
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/build/zip-$1
MOD=$(STAGE_DIR=$OUT "$ROOT/tools/stage.sh" "$1" release)
name=$(basename "$MOD")
rm -f "$ROOT/build/$name.zip"
(cd "$OUT/mods" && zip -qr "$ROOT/build/$name.zip" "$name")
echo "$ROOT/build/$name.zip"
