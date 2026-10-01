#!/usr/bin/env python3
import json
import os
import sys

if len(sys.argv) != 2:
    raise SystemExit('usage: modlist.py <mods dir>')
path = os.path.join(sys.argv[1], 'mod-list.json')
with open(path) as f:
    data = json.load(f)
mods = data['mods']
by_name = {entry['name']: entry for entry in mods}
for name in ('sushi-packer-test-env', 'factorio-test'):
    if name in by_name:
        by_name[name]['enabled'] = False
if 'sushi-packer-bench' in by_name:
    by_name['sushi-packer-bench']['enabled'] = True
else:
    mods.append({'name': 'sushi-packer-bench', 'enabled': True})
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
