# Sushi Packer

**Turn a mixed "sushi" belt into neat stacked belt items — without splitting lanes.**

Sushi Packer is a 1×1 box you place straight onto a belt. Items of any kind ride in on both lanes. The box keeps the two lanes apart, gathers each item kind until it fills one belt stack, then sends that stack out on the same lane it came in on. One belt, many item kinds, fully stacked — no splitters, no filter inserters, no sorting spaghetti.

## How it works

- **Lanes kept.** Left lane stays left, right lane stays right. Nothing crosses over.
- **Release at belt stack.** A stack leaves as soon as one item kind fills a belt stack: 1 item before belt stacking research (pass-through), then whatever research sets — 4 in vanilla Space Age, more when a mod raises it. Never more than the item's own stack size.
- **Flush timeout.** Partial stacks older than the timeout leave anyway (map default, or per box). `0` = never.
- **Lanes never starve each other.** Each lane owns 24 of the 48 slots. A blocked output lane fills only its own half; the other lane keeps flowing.
- **One stack per item.** Each lane holds at most one full item stack of each item and quality (e.g. 50 ore, modded stack sizes included). More of that item waits on the belt.
- **Nothing lost.** When a lane's 24 slots are used, the box flushes that lane's oldest partial stack to make room. If the belt in front is blocked, that lane fills up and its lane on the belt behind backs up — no item is ever dropped.
- **Keeps up with its belt.** Each tier moves exactly its belt's throughput, and items never stop at the belt end in front of the box.

## Tiers

| Tier | Recipe | Time |
| --- | --- | ---: |
| Sushi packer | steel chest, splitter, 2 inserters, 5 electronic circuits | 30 s |
| Fast sushi packer | sushi packer, fast splitter, 2 fast inserters, 5 advanced circuits | 45 s |
| Express sushi packer | fast sushi packer, express splitter, 2 bulk inserters, 5 processing units | 60 s |
| Turbo sushi packer | express sushi packer, turbo splitter, 2 stack inserters, 2 quantum processors | 120 s |

Each tier has its own technology after its belt technology. Upgrade planner swaps tiers in place and keeps contents, settings and circuit wires.

## Per-box settings

- 10 skip filters with splitter-style quality rule (`=`, `≠`, `>`, `<`, `≥`, `≤`, or any quality): matching items are never stored and go straight out on the same lane.
- Circuit network: reads contents as signals, enable/disable condition, flush signal.
- Own flush timeout or map default.
- Status light: green = empty, yellow = holding items, red = a lane is full (its 24 slots used).

## Good to know

- Place a box directly over an existing belt tile. A belt cannot replace a box.
- Box marked for deconstruction stops and turns its light off.
- Factoriopedia entry and Tips & Tricks page show a live demo.
- Copy/paste settings between boxes; blueprints keep settings.

## Requirements

- **Space Age** (belt stacking and quality come from it).
- Factorio 2.0 → mod version **0.1.8**; Factorio 2.1 → mod version **0.2.8**. Same features in both.

## Source and bug reports

Source, changelog and release builds: https://github.com/dw3105/sushi-packer — please attach a save when reporting a bug.
