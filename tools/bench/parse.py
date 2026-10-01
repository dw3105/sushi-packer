#!/usr/bin/env python3
import csv
import os
import re
import sys

if len(sys.argv) != 9:
    raise SystemExit('usage: parse.py <benchmark.log> <factorio-current.log> <fv> <boxes> <ticks> <tier> <modset|none> <flow>')
path, counters_path, fv, boxes, ticks, tier, modset, flow = sys.argv[1:]
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
summary = next((re.search(r'avg:\s*([0-9.]+)\s*ms', line) for line in lines if 'avg:' in line and ' ms' in line), None)
if summary is None: raise SystemExit('benchmark parse failed: summary timing units missing')
summary_ms = float(summary.group(1))
scale = 1e-6
if raw_whole <= 0 or abs(raw_whole * scale - summary_ms) > max(0.02, summary_ms * 0.25):
    raise SystemExit('benchmark parse failed: CSV timing units do not match millisecond summary')
sa=raw_script*scale; wa=raw_whole*scale
items_in = 0
us_per_item = 'na'
if os.path.exists(counters_path):
    counters=[]
    for line in open(counters_path, errors='replace'):
        if 'sushi-packer-bench counters tick=' not in line: continue
        tick=re.search(r'\btick=(\d+)', line)
        items=re.search(r'\bitems_in=(\d+)', line)
        if tick and items: counters.append((int(tick.group(1)), int(items.group(1))))
    if len(counters) >= 2:
        items_in = counters[-1][1] - counters[0][1]
        span = counters[-1][0] - counters[0][0]
        if items_in > 0 and span > 0:
            us_per_item = f'{sa * 1000 / (items_in / span):.2f}'
load1 = os.environ.get('BENCH_LOAD1')
if load1 is None:
    try: load1 = open('/proc/loadavg').read().split()[0]
    except (OSError, IndexError): load1 = 'na'
print(f'bench FV={fv} boxes={boxes} ticks={ticks} script_ms_avg={sa:.3f} whole_ms_avg={wa:.3f} tier={tier} modset={modset} flow={flow} ms_per_box={sa / int(boxes):.5f} items_in={items_in} us_per_item={us_per_item} load1={float(load1):.2f}')
