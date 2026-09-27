#!/bin/sh
# Release zip for one version: build/sushi-packer_<ver>.zip (no tests/). usage: tools/make_zip.sh <2.0|2.1>
# Python zipfile: no `zip` binary on dev-vm.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/build/zip-$1
MOD=$(STAGE_DIR=$OUT "$ROOT/tools/stage.sh" "$1" release)
name=$(basename "$MOD")
rm -f "$ROOT/build/$name.zip"
python3 - "$OUT/mods" "$name" "$ROOT/build/$name.zip" <<'PY'
import os, sys, zipfile
base, name, dest = sys.argv[1:]
with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in sorted(os.walk(os.path.join(base, name))):
        for f in sorted(files):
            full = os.path.join(root, f)
            z.write(full, os.path.relpath(full, base))
PY
echo "$ROOT/build/$name.zip"
