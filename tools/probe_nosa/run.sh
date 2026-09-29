#!/bin/sh
# FND-0025. usage: tools/probe_nosa/run.sh <2.0|2.1> <nosa|sa>  (wrap in gateslot --weight-mib 768 --weight-cores 1)
set -u
S=$(dirname "$0"); FV=$1; C=$2; F=$HOME/factorio-$FV/factorio; O=${OUT:-$HOME/share/sushi-packer/v10/probe}/$FV-$C
rm -rf "$O"; mkdir -p "$O/mods/sp-probe_0.0.1" "$O/write"
cp "$S/control.lua" "$O/mods/sp-probe_0.0.1/"
cat > "$O/mods/sp-probe_0.0.1/info.json" <<J
{"name":"sp-probe","version":"0.0.1","title":"probe","author":"probe","factorio_version":"$FV","dependencies":["base"]}
J
SA=false; [ "$C" = sa ] && SA=true
python3 - "$O/mods/mod-list.json" $SA <<'P'
import json,sys
on=sys.argv[2]=="true"
json.dump({"mods":[{"name":"base","enabled":True},{"name":"sp-probe","enabled":True}]+[{"name":n,"enabled":on} for n in ("space-age","quality","elevated-rails","recycler")]},open(sys.argv[1],"w"))
P
printf '[path]\nread-data=%s/data\nwrite-data=%s/write\n' "$F" "$O" > "$O/config.ini"
"$F/bin/x64/factorio" --config "$O/config.ini" --mod-directory "$O/mods" --create "$O/p.zip" > "$O/create.log" 2>&1 || { echo "$FV $C CREATE-FAIL"; tail -5 "$O/create.log"; exit 1; }
"$F/bin/x64/factorio" --config "$O/config.ini" --mod-directory "$O/mods" --benchmark "$O/p.zip" --benchmark-ticks 3 > "$O/bench.log" 2>&1 || { echo "$FV $C BENCH-FAIL"; tail -5 "$O/bench.log"; }
echo "$FV $C: $(grep -h 'SP-PROBE' "$O/write/factorio-current.log" "$O/bench.log" | head -1)"
