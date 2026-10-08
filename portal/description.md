# Sushi Packer

**Turn a mixed "sushi" belt into neat stacked belt items — without splitting lanes.**

With belt stacking enabled, hidden inserters move items in and out of the box, so it needs very little script time. Each lane holds 12 slots. Since 0.1.17 the box is a belt piece: belts join it, the game rotates it, and wires work as on a belt. Its own window shows both lanes.

Sushi Packer is a 1×1 box you place straight onto a belt. Items of any kind ride in on both lanes. The box keeps the two lanes apart, gathers each item kind until it fills one belt stack, then sends that stack out on the same lane it came in on. One belt, many item kinds, fully stacked — no splitters, no filter inserters, no sorting spaghetti.

## How it works

- **Lanes kept.** Left lane stays left, right lane stays right. Nothing crosses over.
- **Release at belt stack.** A stack leaves as soon as one item kind fills a belt stack: 1 item before belt stacking research (pass-through), then whatever research sets — 4 in vanilla Space Age, more when a mod raises it. Never more than the item's own stack size.
- **Flush timeout.** Partial stacks older than the timeout leave anyway (map default, or per box). `0` = never.
- **Separate lanes.** Each lane has 12 slots. A blocked output lane fills only its own store; the other lane keeps flowing.
- **Leftovers wait.** Items below one full belt stack wait inside the box until the stack is complete or the flush timer runs out.
- **Nothing lost.** If the belt in front is blocked, that lane fills up and its lane on the belt behind backs up — no item is ever dropped.
- **Keeps up with its belt.** Each tier moves exactly its belt's throughput, and items never stop at the belt end in front of the box.

## Tiers

| Tier | Recipe | Time |
| --- | --- | ---: |
| Sushi packer | steel chest, splitter, 2 inserters, 5 electronic circuits | 30 s |
| Fast sushi packer | sushi packer, fast splitter, 2 fast inserters, 5 advanced circuits | 45 s |
| Express sushi packer | fast sushi packer, express splitter, 2 bulk inserters, 5 processing units | 60 s |
| Turbo sushi packer | Space Age: express sushi packer, turbo splitter, 2 stack inserters, 2 quantum processors | 120 s |

## Modded belt tiers

These tiers appear only when the matching belt mod is installed.

| Tier | Belt mod | Speed | Builds |
| --- | --- | ---: | --- |
| Hyper sushi packer | Planetaris: Arig | 75/s | 2.0 + 2.1 |
| Ultimate sushi packer | Bob's Logistics | 75/s | 2.0 + 2.1 |
| Superior sushi packer | Krastorio 2 | 90/s | 2.0 + 2.1 |
| Ultra fast sushi packer | Ultimate Belts Space Age | 90/s | 2.0 |
| Ultra sushi packer | Better Belts | 96/s | 2.0 |
| Extreme fast sushi packer | Ultimate Belts Space Age | 135/s | 2.0 |
| Ultra express sushi packer | Ultimate Belts Space Age | 180/s | 2.0 |
| Extreme express sushi packer | Ultimate Belts Space Age | 225/s | 2.0 |
| Ultimate sushi packer | Ultimate Belts Space Age | 270/s | 2.0 |
| Elite sushi packer | Advanced Belts 2.0 | 60/s | 2.0 |
| Extreme sushi packer | Advanced Belts 2.0 | 75/s | 2.0 |
| Supreme sushi packer | Advanced Belts 2.0 | 90/s | 2.0 |
| Ultimate sushi packer | Advanced Belts 2.0 | 105/s | 2.0 |
| Space sushi packer | Space Exploration | 45/s | 2.0 + 2.1 |
| Deep space sushi packer | Space Exploration | 90/s by default (follows mod setting) | 2.0 + 2.1 |

Space Age is optional. Without it, stacked output needs belt stacking research from Space Age, Stack Inserters, or Infinite Belt Stacking; without that research items pass through one by one. There is no turbo box, and modded tiers chain after blue using 2 bulk inserters and 5 processing units (60 s). With Space Age, modded recipes use 2 stack inserters and 2 quantum processors (120 s), and tiers chain after turbo. Each box runs at its belt's real speed and follows speed changes made by the belt mod's settings. Boxes can be placed on Space Exploration space tiles. Planetaris Hyarion has no belt of its own: the hyper belt comes from Planetaris: Arig, and with Hyarion installed its technology moves into Hyarion's progression, so the packer tier follows it. In Space Exploration the space box starts its own line: it needs no earlier box (1 steel chest, 1 space splitter, 4 bulk inserters, 10 processing units), and the deep space box is made from it. German translation included.

Each tier has its own technology after its belt technology. Upgrade planner swaps tiers in place and keeps contents, settings and circuit wires.

## Per-box settings

- 10 skip filters with splitter-style quality rule (`=`, `≠`, `>`, `<`, `≥`, `≤`, or any quality): matching items are never stored and go straight out on the same lane.
- Circuit network: reads contents as signals, enable/disable condition, flush signal.
- Own flush timeout or map default.
- Status light: green = empty, yellow = holding items, red = a lane is full (its 12 slots used).

## Good to know

- Place a box directly over an existing belt tile. A belt cannot replace a box.
- Box marked for deconstruction stops and turns its light off.
- Factoriopedia entry and Tips & Tricks page show a live demo.
- Copy/paste settings between boxes; blueprints keep settings.

## Requirements

- **Space Age** is optional; belt stacking research can also come from Stack Inserters or Infinite Belt Stacking.
- Factorio 2.0 → mod version **0.1.25**; Factorio 2.1 → mod version **0.2.25**. Same features in both.

## Source and bug reports

Source, changelog and release builds: https://github.com/dw3105/sushi-packer — please attach a save when reporting a bug.
