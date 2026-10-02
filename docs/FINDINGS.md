# Findings

Things found and not fixed here. Each row says where found, what breaks, what it looks like when it breaks.

Rules for rows:

- Id `FND-NNNN`, heading `## FND-NNNN - title`. Numbers never reused.
- Title states finding as raised, never current state; body records what closed.
- Append-only.
- Claim that something is absent or checked carries `Verified-by: \`<command>\`` in same row.

---

## FND-0001 - Newest FactorioTest mod (3.1.0) targets Factorio 2.1 only

Found 2026-09-26 on `dev-vm` while planning. Mod portal lists `factorio-test` 3.1.0 with `factorio_version` "2.1"; last 2.0 build is 3.0.1. Using 3.1.0 on 2.0.77 headless = mod refused at load. Closed by pinning 3.0.1 for 2.0 and 3.1.0 for 2.1 (`docs/DECISIONS.md`). Portal download needs login; author supplies zips.

Verified-by: `curl -s https://mods.factorio.com/api/mods/factorio-test | python3 -c "import sys,json;[print(r['version'],r['info_json']['factorio_version']) for r in json.load(sys.stdin)['releases']]"`

## FND-0002 - Rotated blueprint does not rotate a not-rotatable container

Found 2026-09-26 by web research (https://forums.factorio.com/127223): since 2.0.42 blueprint rotation leaves not-rotatable entities facing their stored direction. Per-direction container variants in a blueprint would build facing wrong way after rotating the blueprint. Closed by placer design (`docs/DECISIONS.md` D-4): blueprints store rotatable placer, not variant.

## FND-0003 - FactorioTest CLI 3.0.1 tries to download builtin mods through fmtk

Found 2026-09-26 on `dev-vm`, S0 first in-game run. CLI 3.0.1 `installModDependencies` treats `space-age` from `info.json` as portal mod and runs `npx fmtk mods install ... space-age`: `npm error 404 'fmtk@*' is not in this registry`, no test runs. CLI 3.6.0 has `BUILTIN_MODS` (`base`, `quality`, `elevated-rails`, `space-age`, `recycler`) and accepts mod ≥ 3.0.0. Second trap: CLI shells out to `npx fmtk`, which resolves from cwd, not PATH. Closed by `tools/run_tests.sh`: one CLI 3.6.0 in main checkout `tools/ft/`, run with cwd there, all paths absolute; mod 3.0.1 on 2.0, 3.1.0 on 2.1.

Verified-by: `grep -n BUILTIN_MODS tools/ft/node_modules/factorio-test-cli/mod-setup.js`

## FND-0004 - Transport line position shrinks toward exit; web summary said it grows

Found 2026-09-26 on `dev-vm`, S0 probe. Research summary said front-most item = highest `position`. Measured on 2.0.77 and 2.1.20: iron inserted at 0.1, copper at 0.6 on a lone north belt; after 120 ticks `line_length=1 iron-plate@0 copper-plate@0.25`. Front-most (next to leave) = lowest `position`; items stop at 0 on belt end. Code taking highest position would pull the item farthest from box. Closed by probe `probe > front-most item has lowest position` and `docs/CONTRACT.md` Lanes section.

Verified-by: `tools/run_tests.sh 2.1 'tests/game/test_probe.lua::probe > front-most item has lowest position'`

## FND-0005 - FactorioTest CLI aborts when a test run has not started within 10 s

Found 2026-09-26 on `dev-vm`, lane 006 checks (verdict FAIL, reason `check-exit-mismatch`). `factorio-process.js:171-176` kills Factorio if no `testRunStarted` event arrives within hard-coded `10_000` ms; several headless loads sharing 4 vCPUs start slower. What it looks like: `Error: Factorio unresponsive: no test run started within 10 seconds`, code correct, lane FAIL. Closed by `tools/ft/patch-cli.sh` (120 s), run by `tools/run_tests.sh` before every game run; lane 006 relaunched.

Verified-by: `grep -n '120_000' tools/ft/node_modules/factorio-test-cli/factorio-process.js`

## FND-0006 - Robot upgrade = mined(old) then built(new) in same tick; engine moves inventory, script state lost

Found 2026-09-26 on `dev-vm`, S1 probe (v1.1). Yellow east box with 7 iron + `timeout_s = 33`, `order_upgrade` to red east, roboport + 4 construction robots. Event order on 2.0.77 and 2.1.20: `on_marked_for_upgrade` (old), then `on_robot_mined_entity` (old, `to_be_upgraded() = true`, chest already empty, buffer 0 iron) and `on_robot_built_entity` (new, 7 iron) in same tick. What it looks like without fix: new box has items but default settings (`timeout_s = 0`), core counters reset. Closed by decision UPG (stash on upgrade-mine, take on build).

Verified-by: `tools/run_tests.sh 2.1 'tests/game/test_probe.lua::probe > upgrade events'`

## FND-0007 - Ingredient unlock techs and belt tech costs identical on 2.0.77 and 2.1.20

Found 2026-09-26 on `dev-vm`, `factorio --dump-data` of both builds with space-age. Every U-2 ingredient recipe starts disabled; unlock techs: `steel-chest` steel-processing, `splitter` logistics, `fast-splitter` logistics-2, `express-splitter` logistics-3, `turbo-splitter` turbo-transport-belt, `inserter` + `electronic-circuit` electronics (research trigger, no unit), `fast-inserter` fast-inserter, `bulk-inserter` bulk-inserter, `stack-inserter` stack-inserter, `advanced-circuit` advanced-circuit, `processing-unit` processing-unit, `quantum-processor` quantum-processor. Space Age already makes `sushi-packer-<tier>-recycling`. Offline fixture `tests/offline/fake_data.lua` carries these values; a tech with `research_trigger` has no `unit` (skip it in ingredient union).

Verified-by: `python3 -c "import json;d=json.load(open('build/2.1/write/script-output/data-raw-dump.json'));print(d['technology']['bulk-inserter']['unit']['count'])"`

## FND-0008 - Runtime recipe prototype differs: ingredient order and `category` (2.1)

Found 2026-09-26 on `dev-vm`, v1.1 integrator full suite. `LuaRecipePrototype.ingredients` comes back reordered vs data stage (yellow: `electronic-circuit` first) on 2.0.77. On 2.1.20 reading `LuaRecipePrototype.category` raises `LuaRecipePrototype doesn't contain key category.` Mod runtime code reads neither; only test did. What it looks like: `data > recipes match table` red. Closed: test matches ingredients by name and reads category via `pcall` (`category` or `categories`).

Verified-by: `tools/run_tests.sh 2.1 'tests/game/test_data.lua::data > recipes match table'`

## FND-0009 - One-way fast replace: placer in "transport-belt" group replaces belt, belt cannot replace placed box

Found 2026-09-26 on `dev-vm`, S1 probe v1.2. Placer (`simple-entity-with-owner`) with `fast_replaceable_group = "transport-belt"`, container variants with `"sushi-packer"`. `player.build_from_cursor` with box item over east belt carrying 1 iron: `can_build_from_cursor = true`, belt gone, box built, player inventory +1 `transport-belt` +1 `iron-plate`. Belt in cursor over placed box: `can_build_from_cursor = false`, box kept. Without group line: `can=false boxes=0 belts=1` (red seen). Both 2.0.77 and 2.1.20.

Verified-by: `tools/run_tests.sh 2.1 'tests/game/test_probe.lua::probe > placer over belt replaces belt'`

## FND-0010 - Mock GUI hid real LuaGuiElement semantics: tags is a copy, item elem_value is a string

Found 2026-09-26 on `dev-vm`, integrator review of lane 016 + real-API game tests. `frame.tags.selected_slot = n` changes a copy (write back `el.tags = t`); `choose-elem-button` `elem_type = "item"` value is a plain string, not `{name}` (writing a table raised at `gui.lua:74`); picking item straight in grid slot did not save filter; nil holes in filters array stop `ipairs` in `filter.match`. What it looks like: 4 reds in `tests/game/test_gui.lua` (`item picked in slot saved as filter`, `editor sets comparator and quality on selected slot`, `editor item change writes selected slot`, `clearing slot writes false`). Closed: `set_tag`, string values, slot pick saves, `pad` empty slots with `false`.

Verified-by: `tools/run_tests.sh 2.1 'tests/game/test_gui.lua::gui > editor sets comparator and quality on selected slot'`

## FND-0012 - Inserter `direction` is its pickup side

Found 2026-09-26 on `dev-vm`, S1 probe v1.3 (scene redo). Inserter at y=-0.5: `direction = north` → `pickup_position.y = -1.5`, `drop_position.y = 0.699` (far half of belt tile south of it); `direction = south` → pickup 0.5, drop -1.699. Both 2.0.77 and 2.1.20. Scene inserters above belt use `north`, below use `south`.

Verified-by: `tools/run_tests.sh 2.1 'tests/game/test_probe.lua::probe > inserter direction picks from chest drops on belt'`

## FND-0011 - CLOSED: one output lane dies when overloaded belt brings stacks (cap 4 + full-box lane starvation)

Reported 2026-09-26 by author: north turbo box, only left lane works. Author save: belt stack 20 (modded), 16 epic recyclers on scrap, belts overloaded so recyclers drop stacks. Reproduced 2026-09-27 on dev-vm 2.0.77 by `repro > sixteen scrap recyclers feed north turbo box` (speed modules overload turbo belt, belt stack 20 via test-env mod): 0.1.5 last 2 min out L=1002 R=0.
Two faults, both measured:
1. Release capped at literal 4 while research allows 20: arrivals of 10-20 split into many small stacks, 48 slots fill (log t=3600: used=48, readyL=48 all 1-item stacks, readyR=0).
2. Full box: `belt_io.pull` always asked lane 1 first; each slot freed by output went to lane 1; lane 2 offered its 10-stack 300 times per 10 s, refused 300 times, forever. First fix (refused lane first, flip on all-refused) parity-locked with output cadence (slot freed every 4th poll): cap 4 run gave L=0 R=993.
Fix: cap = engine `max_belt_stack_size` (O-3 v7); lane that took an item last asks second next visit. Cap-4 run with lane rule alone passes; full fix passes 2.0.77 + 2.1.20.

Verified-by: `tools/run_tests.sh 2.0 'tests/game/test_repro.lua::repro > sixteen scrap recyclers feed north turbo box'`

## FND-0013 - Box makes items rest at belt end: tier cadence + 30-tick idle sleep (stutter)

Reported 2026-09-27 by author (v1.3 tips scene): yellow box stutters with tiny input. Cause (code read, PERF-1 + PERF-2): box visited only every `INTERVAL[tier]` ticks and takes item only when it already rests at belt end (`not line.can_insert_at(0)`); idle box sleeps 30 ticks. Measured on `dev-vm` 2.0.77 before fix, longest rest of item at belt end: sparse yellow feed 19 ticks, sparse turbo feed 21 ticks, tips scene 13 ticks. Fix: PERF-3 (wake on front item eta, idle sleep < tile crossing).

Verified-by: `tools/run_tests.sh 2.0 'tests/game/test_tick.lua::tick > front item never rests at exit'`

## FND-0014 - Open blueprint crashed tick: `player.opened` may be LuaItemStack

Reported 2026-09-27 by author (0.1.4): `Error while running event sushi-packer::on_tick ... LuaItemStack doesn't contain key unit_number` at `scripts/tick.lua:74`. `player.opened` is entity, item stack, GUI element or equipment depending on `opened_gui_type`; reading missing key on item stack raises. Fix: read only when `opened_gui_type == defines.gui_type.entity`. Headless test player is not connected (`opened_gui_type` stays 0, measured dev-vm 2.0.77), so repro is offline fake with erroring `__index`, red on 0.1.4 with author's exact message.

Verified-by: `tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > opened blueprint does not crash'`

## FND-0015 - Splitter behind or in front: box read only belts/undergrounds, so it took nothing

Reported 2026-09-27 by author (blueprint, "THIS DOESN'T WORK"): north turbo box between turbo splitters (behind: stone filter, in front: holmium filter, bypass splitter east). Built from author's blueprint string headless on dev-vm 2.0.77: `stored=0` after 80 s. Cause: `belt_io.find_belt` searched only `transport-belt` / `underground-belt`. Probe `probe > splitter transport line numbering` (2.0.77 + 2.1.20, north splitter): input left half = lines 1/2, right half = 3/4; output left half = 5/6, right half = 7/8 (matches `defines.transport_line`). Fix: splitter facing box direction whose half touches box tile; behind → that half's output lines, in front → that half's input lines.

Verified-by: `tools/run_tests.sh 2.0 'tests/game/test_repro.lua::repro > author blueprint splitters around turbo box'`

## FND-0016 - Loaders behind or in front: same gap as FND-0015

Reported 2026-09-27 by author (blueprint 2: chest -> modded 1x1 output loader -> west turbo box -> 1x1 input loader -> chest). Headless with vanilla `loader-1x1` stand-in on dev-vm 2.0.77: `pushed L=0 R=0 sink got=0` on old code. Probe `probe > loader transport line numbering` (2.0.77 + 2.1.20): loader-1x1 has 2 lines = lanes, output loader holds items at exit when box does not take, input loader accepts `insert_at_back` on both lines. Fix: loaders (1x1, 2x1 with centre half a tile further) and linked belts facing box direction; behind must be output, front must be input.

Verified-by: `tools/run_tests.sh 2.0 'tests/game/test_repro.lua::repro > author blueprint loaders around west box'`

## FND-0017 - CLOSED (plan scrapped 2026-09-27, see FND-0018): plan C S0 host probes (packer as belt-like entity, E-10)

Measured 2026-09-27 on dev-vm 2.0.77 (`tests/game/test_probe_v2.lua`, test-env mod hosts, run single, report via error). Hosts: A `sushi-probe-belt` (turbo belt copy), B `sushi-probe-lane` (copy of hidden base `lane-splitter`, present in 2.0.77 + 2.1.20 data).
- A: identical to plain belt for belt/underground/splitter/loader behind, inserter drops (far lane), output into belt, side-load onto belt/underground, underground, splitter, loader, inserter pick. Accepts side input -> violates E-10.
- B: refuses belt pushing in from side (side belt keeps items) -> fits E-10. Lines 1/2 input (len 0.699, lanes kept, inserter east -> 1, west -> 2), 3/4 output (len 0.5). Items rest on 1/2, then cross to 3/4 where lane-splitter logic mixes lanes (left iron ended on 4 after 90 ticks). All outputs work like belt.
- BLOCKER: `entity.active = false` accepted on both, but belt behind + host emptied within 120 ticks -> cannot stop flow when box full (F-3); front belt not watched, "passed through" inferred.
- Not probed: drill, recycler, player drop, circuit/GUI on host, save/load, bench.
Next (author decides): probe 1 circuit-disable host condition set by script; probe 2 parked plug item at input line end; or option 3 accept bounded overflow.

## FND-0018 - CLOSED, plan scrapped: plan B3 probes (lane-splitter base + companion chest + companion belt)

Measured 2026-09-27 on dev-vm, 2.0.77 + 2.1.20 identical except recycler item split (`tests/game/test_probe_b3.lua`, NOT in index; run with temporary index entry, report via error). Author scrapped v2 after report ("scrap the plan, we publish the current version"), 2026-09-27.
- Companion belt IMPOSSIBLE: load error both versions, `entity prototype "sushi-probe-lane" (lane-splitter) collision_mask ... must collide with entity prototype "sushi-probe-cbelt" (transport-belt)`. Engine: every belt-connectable must collide with every transport-belt (also cbelt with empty mask vs `transport-belt`).
- Lane-splitter base at runtime: `splitter_filter` and `splitter_input_priority` / `splitter_output_priority` accepted (no GUI); `get_or_create_control_behavior()` nil, no wire connector; `disabled_by_script = true` reads back false; `rotatable` true.
- Base + companion chest (empty collision mask, `selection_priority` 60) share tile either order; belt behind feeds base, side belt refused; `update_selected_entity` picks chest; red wire + read contents native (`iron=7`); `player.opened = chest` works.
- Companion chest STEALS drops: inserter `drop_target` = chest (2 of 3 copper in chest after 150 ticks); burner + electric drill into chest; recycler partly chest, partly base output lines 3/4; `spill_item_stack{allow_belts=true}` lands on output lines 3/4. Chest `set_bar(1)` also blocks script `insert` (0) and inserter waits. -> fails E-10.
- Unpacked pass-through through lane-splitter SWAPS lanes (iron in left -> out right).
- Stop when full: `disabled_by_script` no effect (4 items to front in 600 ticks); fast-replace swap to `speed = 1/256` copy keeps items but still passes them; fast-replace swap to unlinked `linked-belt` copy (`allow_side_loading=false`) facing forward stops flow (0 to front in 610 ticks, lanes kept) - item conservation NOT checked (only 1 of 2 feed belts counted, 12 of 16 untracked). Facing backward disconnects from belt behind. `linked_belt_type` create param ignored (always `input`).
- Not probed: save/load, bench.

## FND-0019 - Blocked output lane starves other lane (shared 48 slots)

Reported 2026-09-28 by author ("when one output lane is congested, other must not starve"). Repro `repro > blocked left lane never starves right lane` (east red box, belt stack 4, script feed iron/copper left + coal/stone right, output belt dead end, only right lane drained), dev-vm 2.0.77, code `e5dfff1`: RED, `right drained early=172 late=0 fed L=301 R=300 used=48 slotsL=48 slotsR=0` (early = ticks 600..2400, late = 5400..7200). Left ready stacks take all 48 slots, input stops on both lanes, right lane output dies. Fix (author pick): hard split 24 + 24 per lane (REQUIREMENTS v8 L-2, D-5).

Verified-by: `tools/run_tests.sh 2.0 'tests/game/test_repro.lua::repro > blocked left lane never starves right lane'`

## FND-0020 - Box hoards far more than one stack of an item

Reported 2026-09-28 by author ("prevent getting more than one full stack ... of each item"). Repro `repro > box holds at most one stack per item per lane` (east yellow box, no front belt, iron-ore both lanes, belt stack 4, 3600 ticks), dev-vm 2.0.77, code `e5dfff1`: RED, `stack=50 chest=192 laneL=96 laneR=96 used=48`. Fix (author pick): cap one item stack per (item, quality, lane), size from `prototypes.item[name].stack_size` at runtime (REQUIREMENTS v8 C-6, D-5).

Verified-by: `tools/run_tests.sh 2.0 'tests/game/test_repro.lua::repro > box holds at most one stack per item per lane'`

## FND-0021 - Leak report: sushi-packer state flat; author save dominated by RRC-Fork storage

Reported 2026-09-28 by author (RAM grows, UPS drops over time; perf CSV = `--output-perf-stats` renderer dump, no Lua memory data). Soak probe `tests/game/test_probe_soak.lua` (NOT in index, SP-10), dev-vm 2.0.77, code `e5dfff1`: 200 yellow boxes full flow, churn every 600 ticks (destroy+rebuild, rotate x4, die+rebuild, clone+destroy), 108 000 ticks. Every 3600 ticks: recs = live = 200, render objects 400, upgrade_stash 0, `storage.boxes` tables 4 592 (t=3600) -> 4 506 (t=108000), `collectgarbage("count")` after collect 2 997..3 715 KB, no trend (log `~/.cache/sushi-packer/share-archive/soak-2.0.txt`). Verdict: no growth in sushi-packer state or render objects.
Author save `SA_D0.zip` (2026-09-28): `script.dat` 30 334 631 B parsed per mod block: `mod-RRC-Fork` 30 030 288 B (~99 %), machine-upgrades 201 522 B, sushi-packer 51 580 B (9 boxes). RRC-Fork block = cache of ~41 553 records (`status`, `selected`, `consumer`, `beacons`, `modules`). Growth unproven (one save; second save asked). Handed to RRC session `rrc_fixer_3` (author pasted, 2026-09-28). No sushi-packer code change (lane L not spawned).

Verified-by: `tools/run_tests.sh 2.0 'tests/game/test_probe_soak.lua::probe > soak storage and render objects bounded'` (temporary index entry)

## FND-0022 - Fast belts: insert_at_back reaches full belt rate; prototypes readable in control main chunk

Measured 2026-09-28 on dev-vm, 2.0.77 + 2.1.20 identical (`tests/game/test_probe_push.lua`, NOT in index, SP-10; test-env belts `sp-test-belt-90/135/270` = express copy with speed 0.1875 / 0.28125 / 0.5625). One lane, 12-tile north line, last tile cleared each tick, 300 measured ticks after 60 warm-up, loop `can_insert_at_back` + `insert_at_back` up to 10 per tick:
- turbo 0.125: 0.500 per tick (need 0.500), max 1 in a tick.
- 90/s: 0.750 (need 0.750), max 1. 135/s: 1.123 (need 1.125), max 2. 270/s: 2.250 (need 2.250), max 3.
- `insert_at` scan over line gives same numbers (no gain).
Verdict: no engine cap below belt rate; several `insert_at_back` per tick per lane work. Risk R2 (v9 plan) closed: box credit cap must allow > 2 per visit, no push cap constant needed.
P3: `prototypes.item["iron-plate"].name` inside `pcall` at top of `control.lua` main chunk returns `iron-plate` both versions -> event filters may test prototype existence at load.

Verified-by: `tools/run_tests.sh 2.0 'tests/game/test_probe_push.lua::probe v9 > push rate per lane on fast belts'` (temporary index entry + TEMP control line), same on 2.1

## FND-0023 - P1: real belt-family prototypes per mod set (v9 table rows verified)

Measured 2026-09-28 on dev-vm, 2.0.77 + 2.1.20, packer v1.8 + v9 seam (`tests/game/test_probe_modset.lua`, NOT in index, SP-10; dumps `~/.cache/sushi-packer/share-archive/v9-p1/<FV>-<set>.txt`, versions `tests/mods.lock.json`). Every `N.EXTRA` row name verified (belt / splitter / tech, speed x 480):
- `planetaris-hyper-transport-belt` 0.15625 = 75/s, splitter `planetaris-hyper-splitter`, tech `planetaris-hyper-transport-belt` (unit 3000; prereq `planetaris-compression-science` + `turbo-transport-belt`; with Hyarion prereq `planetaris-polishing-science-pack` + turbo). 2.0 + 2.1.
- `kr-superior-transport-belt` 0.1875 = 90/s, `kr-superior-splitter`, tech `kr-logistic-5` (unit 2000). 2.0 (K2SO standalone) + 2.1 (K2SO on Krastorio2). `kr-advanced-*` 60/s `hidden=true` both.
- `bob-ultimate-transport-belt` 0.15625 = 75/s, `bob-ultimate-splitter`, tech `logistics-5` (unit 300). Bob also adds `bob-basic-*` 7.5/s below yellow (no tier). Default `bobmods-logistics-beltoverhaulspeed=false`.
- UBSA (2.0): `ultra-fast-belt` 90, `extreme-fast-belt` 135, `ultra-express-belt` 180, `extreme-express-belt` 225, `ultimate-belt` 270; splitters `ultra-fast-splitter`, `extreme-fast-splitter`, `ultra-express-splitter`, `extreme-express-splitter`, `original-ultimate-splitter`; techs `ultra-fast-logistics`, `extreme-fast-logistics`, `ultra-express-logistics`, `extreme-express-logistics`, `ultimate-logistics` (all with unit).
- Better Belts (2.0): `BetterBelts_ultra-transport-belt` 0.2 = 96/s, `BetterBelts_ultra-splitter`, tech `BetterBelts_ultra-class` (unit 150, prereq `logistics-3`). Loads with Space Age 2.0.77 (risk R3 closed).
- `arig-off` (startup `disable-hyper-belts=true`): 2.0 belt + splitter + tech `hidden=true`. 2.1: Arig 1.1.47 itself fails load: `Error while running setup for entity prototype "turbo-transport-belt" (transport-belt): next_upgrade target (planetaris-hyper-transport-belt) must have an item that builds it that isn't hidden.` -> set 2.0 only (upstream bug, not ours).
- All sets load with packer v1.8 (4 vanilla sushi items only).

Verified-by: `~/.cache/sushi-packer/share-archive/v9-p1/run.sh` (temporary index entry), per set `make test-one FV=<fv> MODSET=<set> T='tests/game/test_probe_modset.lua::probe v9 modset > dump belts splitters techs'`

## FND-0024 - Boxes on belts faster than turbo capped at 60/s (pull rule + eta wake)

Measured 2026-09-28 on dev-vm, 2.0.77, MODSET `arig-k2so`, code `int/v9` after lanes 024/025/027 merged (`tests/game/test_modtiers.lua::modtiers > box output matches belt rate`, probe `tests/game/test_probe_rate.lua` NOT in index). Belt stack 1, both lanes saturated, 600 ticks:
- Before: turbo 300/300 per lane, hyper (0.15625) 300 of 375, superior (0.1875) 300 of 450.
- Cause 1 (superior): `belt_io.pull` took only items resting at position 0 (`not line.can_insert_at(0)`). Front item at 0.063 (< belt_speed, reaches end this tick) gives `can_insert_at(0) == true` -> taken one tick later; compressed items then arrive every 2 ticks -> 0.5 item/lane/tick = 60/s for every belt faster than turbo. Probe: polls 600, pulls 300, pushes 300.
- Cause 2 (hyper): eta wake (PERF-3) slept until item reaches position 0 (ceil(0.188 / 0.15625) = 2), one tick past the take window -> polls 450, pulls 300.
- Also on the way: `require` inside `belt_io.lane_rate` crashes at runtime (`Require can't be used outside of control.lua parsing.`); stale `LuaItemStack` read after `remove_item` (`LuaItemStack API call when LuaItemStack was invalid.`).
- Fix (speed > 0.125 only; vanilla path unchanged): take front items with position <= belt_speed (one `get_detailed_contents` read per lane visit); eta to take window `max(speed/2, pos - speed)`; count read before removal; guard test `guard > no require inside runtime functions`.
- After: turbo 300/300, hyper 375/375, superior 450/450 per lane.

Verified-by: `make test-one FV=2.0 MODSET=arig-k2so T='tests/game/test_modtiers.lua::modtiers > box output matches belt rate'`

## FND-0025 - Stacked belt items need no space-age mod; script stack size ignores force research

Measured 2026-09-29 on dev-vm, 2.0.77 + 2.1.20, standalone probe mod `sp-probe` (`tools/probe_nosa/`, not sushi-packer), log `~/.cache/sushi-packer/v10/logs/fnd25.txt`. One `transport-belt` per case, `insert_at_back({iron-plate x4}, 4)`, then `get_detailed_contents()`:
- `base` only (space-age, quality, elevated-rails, recycler disabled), bonus 0: `belt_items=[4]`; bonus 3: `[4]`. Both versions.
- space-age on (control), bonus 0: `[4]`; bonus 3: `[4]`. Both versions.
- `belt_stack_size_bonus` writable without space-age (bonus 3 set, read back 3).
- Separate try: probe with `space_travel_required = true` in info.json and no space-age fails map create (`tile prototype "empty-space" (tile) is missing`) - flag needs space content; not needed for stacking.
Verdict: engine makes stacked belt items with no space-age mod and no feature flag. Planned red control (bonus 0 -> `[1]`) is NOT red: stack size is the caller's argument, force research does not cap it. So research sets nothing in the engine for script belt inserts; box stack N comes only from our rule O-3 (`1 + force.belt_stack_size_bonus`). T-1 (space-age optional) has no engine blocker.

Verified-by: `gateslot --label sushi-packer/heavy --weight-mib 768 --weight-cores 1 -- sh -c 'for v in 2.0 2.1; do for c in nosa sa; do tools/probe_nosa/run.sh $v $c; done; done'`

## FND-0026 - No-SA game: sushi-packer refuses to load (hard dependency)

Measured 2026-09-29 on dev-vm, code `e5e8e7f` (= v1.10 mod files), `tools/load_check.sh` with sets `nosa` (2.0, 2.1), `ab` (2.0), `se` (2.0 SE 0.7.57, 2.1 SE 0.7.62), all `builtin_off`. Every case: `Error Util.cpp:81: Failed to load mod "sushi-packer": ... Missing required dependency space-age`. Logs `~/.cache/sushi-packer/v10/logs/load-<FV>-<set>.log`. Data stage never runs, so the turbo `strict` error in `prototypes/packer.lua` (turbo belt tech lives in space-age) is still unseen behind it.

Verified-by: `MODSET=nosa tools/load_check.sh 2.0` (under `gateslot --label sushi-packer/heavy --weight-mib 1536 --weight-cores 1`)

## FND-0027 - Advanced Belts 2.0 + Space Age: shipped 0.1.10 crashes on load (row name clash)

Measured 2026-09-29 on dev-vm 2.0.77, code `e5e8e7f` (= v1.10 mod files), set `ab-sa` (AdvancedBeltsUpdated 2.4.0 + space-age on; AB declares no `! space-age`, so players can load this): `Error in assignID: item with name 'original-ultimate-splitter' does not exist. Source: ub-ultimate-sushi-packer (recipe).` Log `~/.cache/sushi-packer/v10/logs/load-2.0-ab-sa.log`.
Cause (log + code): AB defines `ultimate-belt` + tech `ultimate-logistics`, same names as UBSA row `ub-ultimate`. `prototypes/extra.lua` M-1 guard checks belt + tech only, not owner mod, not splitter -> UBSA row goes live on AB belt, recipe asks UBSA splitter. Fix by design: Q11 owner gate + splitter check (v10).

Verified-by: `MODSET=ab-sa tools/load_check.sh 2.0`

## FND-0028 - v10 row names read from real zips

Read 2026-09-29 on dev-vm from portal zips (sha1 = portal API): AdvancedBeltsUpdated 2.4.0 (factorio 2.0 only), space-exploration 0.7.57 (2.0) + 0.7.62 (2.1).
- AB `prototypes/entities/transport-belts.lua`, `splitters.lua`, `technologies.lua`: `elite-belt` 0.125, `extreme-belt` 0.15625, `supreme-belt` 0.1875, `ultimate-belt` 0.21875; splitters `elite-`/`extreme-`/`supreme-`/`ultimate-splitter`; techs `elite-`/`extreme-`/`supreme-`/`ultimate-logistics`.
- SE `prototypes/phase-1/combined/transport-belt.lua`: `se-space-transport-belt` = express copy (45/s, ties blue -> no tier, Q7); deep space speed = setting `se-deep-space-belt-speed-2` (default 90, range 60..512) `* (4/3)/10/64` -> 0.1875 at default; 8 colour variants `se-deep-space-transport-belt-<colour>`, default `black`; splitter `se-deep-space-splitter-black`; tech `se-deep-space-transport-belt` (unit 500).
- SE `prototypes/phase-3/space-collision.lua`: every `container` without `se_allow_in_space` (and name without chest/warehouse/...) gets space collision layer -> sushi-packer boxes blocked in SE space today.
- `grep belt.stack` over both mods: 0 hits (no belt stack research from SE or AB).

Verified-by: `unzip` of `~/.cache/sushi-packer-mods/2.0/{AdvancedBeltsUpdated_2.4.0,space-exploration_0.7.57}.zip` + `~/.cache/sushi-packer-mods/2.1/space-exploration_0.7.62.zip` + read of files above

## FND-0029 - SE game: upgrade chain refused, aai-containers shrinks our 1x1 container box

Measured 2026-09-29 on dev-vm 2.0.77, set `se` (SE 0.7.57, aai-containers 0.3.2), code `ec8e801` + runner fix: map create fails `Error while running setup for entity prototype "express-sushi-packer-east" (container): next_upgrade target (se-deep-space-sushi-packer-east) must have the same bounding box. Modifications: Sushi Packer › AAI Containers & Warehouses › Sushi Packer`. Cause (log + aai-containers `data-final-fixes.lua`): setting `aai-containers-resize-1x1` shrinks every 1x1 container with box +-0.35 to +-0.3; aai-containers sorts before sushi-packer, so vanilla boxes are shrunk before our `data-final-fixes` builds extra tiers at +-0.35. Fix: `extra.build` copies top vanilla container `collision_box` into every extra container. Also on the way: test harness ran `nosa`/`se` with space-age ON (FactorioTest `--mods` list hard-coded built-ins; `builtin_off` ignored) -> runner passes `name=false` and a guard fails the run when harness space-age state differs from the set (planted old behaviour -> `FAIL harness space-age enabled=True, set wants False`); SE universe build prints nothing > 15 s -> `--output-timeout 180`.
After: `se` 2.0 modtiers 6/7 (deep space 450/450 per lane, box placeable on `se-space-platform-scaffold`); only red = blue rate (FND-0030).

Verified-by: `make test-one T='tests/offline/test_data_extra.lua::data extra > extra box matches resized vanilla box'`; `MODSET=se tools/run_tests.sh 2.0 --modtiers`

## FND-0030 - Blue box below belt rate (200 / 225 per lane, shipped since v1.x; E-4)

Measured 2026-09-29 on dev-vm 2.0.77 + space-age, probe `tests/game/test_probe_v10rate.lua` (NOT in index, SP-10; same rig as `modtiers > box output matches belt rate`: belt stack 1, both lanes saturated, 12 front tiles). Base code (= v1.10 path), warm-up 600, measure 600 ticks, per lane got / want: yellow 75 / 75, red 150 / 150, blue 200 / 225, turbo 300 / 300. Same blue 200 / 225 in no-SA sets `nosa` and `se` (blue = first measured chain tier there, V10-1).
Correction: first report (commit `2bf1a96`) said yellow 42 / 75 and red 140 / 150 - rig artifact, warm-up 180 shorter than 12-tile crossing (yellow 384, red 192 ticks). Only blue is real.
Cause (experiment, not code read): resting-only take rule for speed <= 0.125; blue item gap 0.25 / 0.09375 = 2.67 ticks vs 2-tick visits. Experiment 1 (take window for all speeds) -> all four tiers full; experiments 2 (eta after take) and 3 (retry push next tick) changed nothing, reverted.
Fix (V10-7): `belt_io.pull` take window (position <= belt_speed) for all speeds; `modtiers > box output matches belt rate` always measures blue (red on base with SA: blue 200 / 225, green after). Old-rule offline expectations updated: eta to window ({4,7}->{3,6}, {8,8}->{7,7}), turbo takes item at 0.063.

Verified-by: `make test-one FV=2.0 T='tests/game/test_modtiers.lua::modtiers > box output matches belt rate'`

## FND-0031 - v10 bench slower than v1.10 (yellow boxes, V10-7 take window)

Measured 2026-09-29 on dev-vm 2.0.77, `make bench FV=2.0` (200 yellow boxes, 3600 ticks), alternating `int/v10` (`ae7ea4c`) vs v1.10 code (`~/wt-sushi-packer-v9`, `edd66f0`), script ms avg: r1 9.481 (load 28.45) vs 8.600 (21.12); r2 7.073 (17.28) vs 5.390 (14.51); r3 14.517 (18.26) vs 6.965 (14.76). v10 slower in 3 of 3 pairs (x1.10, x1.31, x2.08); host load uncontrolled. Suspect (not proven): V10-7 take window for all speeds adds `get_detailed_contents` reads on yellow boxes, which reached full rate without it (FND-0030 75/75). Author 2026-09-29 (Q16 c): ship v1.11 as is; narrowing to speed > 0.0625 is the known next step.

Verified-by: `make bench FV=2.0` in both worktrees (log `~/.cache/sushi-packer/v10/logs/bench-v10-vs-v110.txt`)
v11 S0 attribution (2026-09-29, dev-vm 2.0.77, `make bench FV=2.0` under gateslot `sushi-packer/heavy`, host load 1.1-3.4, alternating A/B/C x 3): A v1.10 (`edd66f0`) 3.714 / 3.042 / 3.452 (mean 3.40); B v1.11 (`97b66b4` = `642da81` code) 3.903 / 4.571 / 4.283 (mean 4.25); C = B + `fast = speed > 0.0625` in `scripts/belt_io.lua` 3.836 / 3.358 / 3.406 (mean 3.53). B slower than A 3 of 3 (x1.05, x1.50, x1.24); C faster than B 3 of 3; C vs A +3 %, +10 %, -1 %. Suspect proven (V11-7): take window on yellow/red costs; narrowing removes most of it. Residual C vs A within host noise not shown. R-1: all 9 runs <= 5 ms on quiet host (first time met). Fix goes in v1.12 INT; rate test must keep red 150/150 (FND-0030 base had red full without window).

Verified-by: `~/.cache/sushi-packer/v11/bench-s0.sh` (log `~/.cache/sushi-packer/v11/logs/bench-s0.txt`)
v11 INT (2026-09-29, dev-vm 2.0.77, host load 3.9-6.2, other users active): D = v1.12 (`int/v11`) vs A = v1.10, 6 alternating pairs both orders: D 4.165 / 4.127 / 3.983 / 4.095 / 4.032 / 4.015 vs A 3.680 / 3.503 / 3.651 / 3.387 / 3.310 / 3.263 -> D slower 6 of 6 (x1.09..x1.23); V11-6 bar (no slower 3 of 3) NOT met. Per-tick code for yellow boxes in D = v1.10 (only runtime diff since `edd66f0`: `fast` threshold 0.125 -> 0.0625; yellow 0.03125 outside both). Controls: fresh worktree at D sha = D (4.021 / 3.925 vs 3.960 / 3.876) -> not worktree artifact; bisect C (v1.11 + fix) / E (C + v1.12 names + prototypes) / F (C + locale de + graphics) / D, 2 rounds: 3.929 / 4.017 / 3.932 / 3.880 and 3.768 / 3.869 / 3.618 / 3.797 -> no half carries a cost; C itself ranged 3.358-3.969 over the session. Cause of D vs A gap not found; not reproduced as a code change. R-1: every D run <= 5 ms (max 4.165).

Verified-by: logs `~/.cache/sushi-packer/v11/logs/bench-int.txt`, `bench-int-swap.txt`, `bench-int-cda.txt`, `bench-int-d2.txt`, `bench-bisect.txt`

## FND-0032 - SE space belt names same in SE 0.7.57 (2.0) and 0.7.62 (2.1)

Read 2026-09-29 on dev-vm from `~/.cache/sushi-packer-mods/{2.0,2.1}/space-exploration_*.zip`: belt `se-space-transport-belt` (copy of express, speed 0.09375 = 45/s, `next_upgrade = nil`, own `fast_replaceable_group`), splitter `se-space-splitter`, tech `se-space-belt` (100 x 60 s, automation + logistic + chemical + `se-rocket-science-pack`, prereqs `logistics-2`, `se-space-assembling`). Deep space belt recipe uses 10 space belts; deep space splitter uses 2 `se-space-splitter`. SE info.json has `! space-age`. SE German: `se-space-transport-belt=Space-Fließband`, `se-deep-space-transport-belt=Deep-Space-Fließband`. Icon `space-exploration-graphics/graphics/icons/underground-belt.png` light body median (max channel > 150, 999 px) = 215,215,215, saturation 0 (paint, V11-4).

Verified-by: `unzip -p <zip> '*.lua' | grep` + `'*/locale/de/*'` (this session); median via `~/.cache/sushi-packer/graphics-src/venv/bin/python`.

## FND-0033 - Library blueprint "select new contents" crashed: `e.record` is LuaRecord

Reported 2026-09-29 on portal by Gammel2012 (thread `6abcbd58f00bbe9ee51d2831`): inventory blueprint fine, library blueprint crashes in `on_player_setup_blueprint`. Reproduced by author in real game 2026-09-30 on 0.1.12: `Error while running event sushi-packer::on_player_setup_blueprint (ID 83) LuaRecord doesn't contain key valid_for_read.` at `__sushi-packer__/scripts/copy.lua:41`. Cause: handler takes `e.record or e.stack`, then reads `valid_for_read` / `is_blueprint`; LuaRecord (API 2.0.72 + 2.1.20 json) has `valid`, `valid_for_write`, `type`, `object_name`, get/set_blueprint_entities, no `valid_for_read`, no `is_blueprint`. Same shape as FND-0014. Old game tests passed item stack as `record` (`tests/game/test_lifecycle.lua:172,185`), so they never hit record path. S0 probe (dev-vm 2.0.77 + 2.1.20, FactorioTest game): `#game.blueprints = 0`, player connected, `#player.blueprints = 0`, `cursor_record = nil`; no API creates LuaRecord -> no real record reachable headless; record path proven offline with fake whose `__index` raises engine message. Fix (V12-2): branch on `object_name`.

Verified-by: `tools/run_tests.sh 2.0 'tests/offline/test_copy.lua::copy > library record does not crash'`; `tools/run_tests.sh 2.0 'tests/game/test_probe.lua::probe > library record reachable'` (+ 2.1)

## FND-0034 - Mining Drones + Arig: load fails, hyper box mask differs from turbo box

Reported 2026-09-30 on portal by them8 (thread `6abd72a34c791f3fbc708afc`, screenshot `https://i.imgur.com/unPNAgJ.png`), 0.1.12 with Mining_Drones_Remastered 2.1.5, aai-containers 0.3.2, panglia_planet 0.5.8 (+ planetaris-arig): `Failed to load mods: Error while running setup for entity prototype "turbo-sushi-packer-east" (container): next_upgrade target (planetaris-hyper-sushi-packer-east) must have the same collision mask.`

Reproduced dev-vm 2026-09-30, headless, packer 0.1.13 / 0.2.13 (bug present since extra tiers, v9): mod set `them8` (2.0 lock = screenshot versions; 2.1 newest: Arig 1.1.47, MD 2.3.0, aai-containers 0.4.0, panglia 0.7.2): `make load-check FV=2.0 MODSET=them8` and `FV=2.1` both red with exact message. Bisect (2.0, mods disabled in mod-list): without sushi-packer green; without Mining_Drones_Remastered green; without planetaris-arig green; without aai-containers red; without panglia red; Arig + MD + sushi-packer only red, same minus sushi-packer green. Cause: MD `data-final-fixes.lua` adds layer `mining_drone` to every prototype with layer `player` (`collision_util.collect_prototypes_with_layer("player")`); MD data-final-fixes runs before ours; our `data-final-fixes.lua` builds extra tiers (`prototypes/extra.lua` `M.build`) after it, and FND-0029 copies only `collision_box` from top vanilla box, not `collision_mask`. Probe mod log after all fixes (2.0, Arig + MD): `turbo-sushi-packer-east` mask `{is_lower_object, is_object, item, mining_drone, object, player, water_tile}`, `planetaris-hyper-sushi-packer-east` mask `nil` (default, no `mining_drone`). Any mod editing container masks in data-final-fixes before ours hits same fault for every extra tier.

Verified-by: `make load-check FV=2.0 MODSET=them8` + `FV=2.1` (red on 0.x.13, green on 0.x.14); `tools/run_tests.sh 2.0 'tests/offline/test_data_extra.lua::data extra > extra box matches mask of vanilla box'`; bisect script `~/.cache/sushi-packer/v13/bisect/run.sh`, probe mod `~/.cache/sushi-packer/v13/bisect/min-arig-md/mods/zz-mask-probe`, log `min-arig-md/probe.log`

## FND-0035 - Player report: 5 extreme packers = 0.4 ms script time (not measured here yet)

Reported 2026-10-01 on portal by Gamer433 (thread `6abb236eee95f227b880c3b2`, text only; thread images = site logo, mod thumbnail, avatars): "I placed 5 extreme packers (the one after turbo/green) and its running on 0,4 ms. Sounds a bit much for only 5 Sushi Packers." = 0.08 ms per box on their PC; set: Space Exploration, Advanced Belts 2.0, Belt Speed Multiplier, `sei-stack-inserters`. Their multiplier value, belt stack, flow, CPU: not stated. Our posted figure (0.02 ms per box) = 200 yellow boxes only (`make bench FV=2.0`, dev-vm 2026-09-29, FND-0031); no bench of any tier above yellow exists. Status: open, repro = mod set `g433` + bench (v14 S0b).

Set facts, dev-vm 2026-10-01, 2.0.77, mod set `g433` (space-exploration 0.7.57, AdvancedBeltsUpdated 2.4.0, BeltSpeedMultiplier 1.0.4 with `BeltSpeedMultiplier-speed-factor` = 2.0, sei-stack-inserters 1.0.10, stack-inserters 1.0.1, space-age off), packer 0.1.14: loads (`load-check-2.0-g433-ok`); `transport-belt` 0.0625, `extreme-belt` 0.3125 (= 150/s), `ultimate-belt` 0.4375; vanilla loaders doubled too (`loader-1x1` 0.0625); belt stack techs `stack-inserter`, `transport-belt-capacity-1`, `transport-belt-capacity-2`, each +1: `belt_stack_size_bonus` 0 -> 3 after all research (belt stack 4).

Verified-by: `make load-check FV=2.0 MODSET=g433`; `make test-one FV=2.0 MODSET=g433 T='tests/game/test_probe_v14.lua::probe v14 > set facts'` (temporary index entry, SP-10; log `build/2.0/ftdata-g433/factorio-current.log`)

## FND-0036 - Bench feed: old scene = single iron plates only; engine-only 1..4 stack mix needs 4 loaders + splitters

Measured 2026-10-01 on dev-vm, 2.0.77 + 2.1.20 identical, `tests/game/test_probe_v14.lua` (NOT in index, SP-10), force bonus 3, test loader `sp-test-loader` (`loader-1x1` copy, speed 1, `max_belt_stack_size` 4, adjustable), last belt tile read + cleared every tick, 300 ticks after warm-up 420 (yellow 6-tile crossing 192 ticks):
- Old bench scene (infinity chest, 5 items `at-least`, vanilla `loader-1x1`, yellow belt): belt carries only `iron-plate`, stack 1 (74 of 74 belt items). So every R-1 number to date = single iron plates, not 5 mixed item types (only 10 primed items are mixed).
- Same chest, test loader, `loader_belt_stack_size_override` 0 / 1 / 2 / 3 / 4: only iron-plate, stack 4 / 1 / 2 / 3 / 4. Override works on both versions.
- One loader caps at 2 belt items per lane per tick: 270/s belt got 600 of 675 per lane.
- Chest filters `exactly` 1, 2, 3, 4 of four items + override 4: mix depends on belt speed (270/s: even 1..4; 135/s: mostly 3 and 4; 90/s, turbo: only 3 and 4; yellow: two sizes). Not usable.
- Prefilled steel chest (slots of 1..4 items) + override 4: loader merges same item across slots, every belt stack = 4. Not usable.
- 4 infinity chests (one item each) -> 4 loaders (override 1, 2, 3, 4) -> 2 tier splitters -> 1 tier splitter -> belt, 600 ticks after warm-up 600: yellow 75 / 75 per lane (want 75), turbo 300 / 300 (want 300); stack sizes even (yellow 38 / 37 / 38 / 37, turbo 150 each); order = fixed cycle of 4 per lane. Engine only, no script feed.
Verdict (V14-4): flow `stacks` = that merge feed. Stack sizes 1..4 in even shares, fixed cycle, not dice; seed varies item and loader order per box.

Verified-by: `make test-one FV=2.0 T='tests/game/test_probe_v14.lua::probe v14 > loader feed shapes'`, `... > prefilled chest feed'` (2.0), `... > splitter merge feed'` (temporary index entry; same on `FV=2.1` for first and third)

## FND-0037 - v14 S0b: packer cost by tier, packers minus plain belts (player rig red, cost follows belt items taken)

Measured 2026-10-01 11:10-12:35 UTC on dev-vm, 2.0.77 + 2.1.20, code `7c241a2` (`int/v14`), `tools/bench/run.sh`, 3600 ticks, flow `stacks` (FND-0036) unless said, belt stack 4. Every row = pair back to back: packers, then same scene with plain tier belt at box tile (`--belt-only`, V14-5); order flips per round. Host busy all session (load1 logged per run, 7..31; other sessions), 2 host reboots after global OOM at 10:17 and 10:32 (bench Factorio 316 MB RSS when killed; cause not found) - earlier partial logs kept, not used. Round 3 not run (load 20-38). No A/A noise run yet (SP-20): numbers below are NOT fit for a bar.

| FV | Row (200 boxes) | Round | Packers script ms | Belts script ms | Delta script ms | Delta whole ms | Delta per box ms | Items in / 3000 ticks | Load1 packers / belts |
|---|---|---|---|---|---|---|---|---|---|
| 2.0 | yellow | 1 | 11.815 | 0.013 | 11.80 | 15.97 | 0.059 | 351087 | 14.3 / 14.6 |
| 2.0 | yellow | 2 | 5.865 | 0.013 | 5.85 | 7.02 | 0.029 | 351087 | 8.8 / 9.3 |
| 2.0 | red | 1 | 13.169 | 0.016 | 13.15 | 14.21 | 0.066 | 726086 | 11.8 / 11.5 |
| 2.0 | red | 2 | 10.507 | 0.014 | 10.49 | 11.69 | 0.052 | 726086 | 7.4 / 8.2 |
| 2.0 | blue | 1 | 30.192 | 0.019 | 30.17 | 32.47 | 0.151 | 1101047 | 14.6 / 13.7 |
| 2.0 | blue | 2 | 25.037 | 0.018 | 25.02 | 25.95 | 0.125 | 1101047 | 7.9 / 7.4 |
| 2.0 | turbo | 1 | 36.966 | 0.019 | 36.95 | 40.21 | 0.185 | 1476092 | 14.6 / 13.1 |
| 2.0 | turbo | 2 | 24.230 | 0.015 | 24.21 | 26.08 | 0.121 | 1476092 | 7.1 / 7.0 |
| 2.0 | `ub-ultimate` (set `ubsa`) | 1 | 88.807 | 0.024 | 88.78 | 91.09 | 0.444 | 6675803 | 14.3 / 12.7 |
| 2.0 | `ub-ultimate` (set `ubsa`) | 2 | 78.149 | 0.023 | 78.13 | 80.10 | 0.391 | 6675803 | 6.8 / 9.0 |
| 2.0 | yellow, flow `single` (old R-1 scene) | 1 | 4.912 | 0.013 | 4.90 | 4.92 | 0.024 | 144800 | 12.5 / 12.3 |
| 2.0 | yellow, flow `single` (old R-1 scene) | 2 | 5.035 | 0.010 | 5.03 | 6.05 | 0.025 | 144800 | 8.3 / 7.0 |
| 2.1 | yellow | 1 | 7.498 | 0.016 | 7.48 | 8.00 | 0.037 | 351087 | 11.3 / 10.8 |
| 2.1 | yellow | 2 | 5.616 | 0.012 | 5.60 | 6.30 | 0.028 | 351087 | 6.9 / 7.6 |
| 2.1 | red | 1 | 13.294 | 0.015 | 13.28 | 15.14 | 0.066 | 726086 | 10.5 / 9.5 |
| 2.1 | red | 2 | 16.179 | 0.012 | 16.17 | 19.82 | 0.081 | 726086 | 11.9 / 8.7 |
| 2.1 | blue | 1 | 27.350 | 0.017 | 27.33 | 28.36 | 0.137 | 1101047 | 7.9 / 10.7 |
| 2.1 | blue | 2 | 43.351 | 0.016 | 43.34 | 48.68 | 0.217 | 1101047 | 16.2 / 17.1 |
| 2.1 | turbo | 1 | 28.075 | 0.020 | 28.05 | 29.06 | 0.140 | 1476092 | 8.8 / 12.4 |
| 2.1 | turbo | 2 | 38.919 | 0.022 | 38.90 | 41.02 | 0.194 | 1476092 | 31.3 / 20.6 |
| 2.1 | `kr-superior` (set `k2so`) | 1 | 45.162 | 0.033 | 45.13 | 47.81 | 0.226 | 2226082 | 6.9 / 6.9 |
| 2.1 | yellow, flow `single` | 1 | 5.087 | 0.010 | 5.08 | 5.88 | 0.025 | 144800 | 9.4 / 9.7 |

Player rig (FND-0035; set `g433`, 5 `ab-extreme` boxes, multiplier 2.0, FV 2.0): pair before reboot (load 15-17) packers 1.246 / belts 0.131 -> delta 1.115 ms = 0.223 ms per box; round 1 (load 12-13) 1.310 / 0.148 -> 1.162 = 0.232; round 2 (load 7-9) 0.947 / 0.132 -> 0.815 = 0.163. RED vs V14-1 bar 0.02 ms per box in 3 of 3 pairs (x8..x11). Player's own figure: 0.08 ms per box on their PC.

Readings (arithmetic on rows above, not a mechanism):
- Belt-only scenes cost 0.010..0.033 ms script: delta = packer script cost. Whole-update delta is 0..5 ms above script delta: engine side of box is small.
- Yellow `stacks` moves 2.42x items of yellow `single` (351087 vs 144800) for 1.1..1.2x script (round 2, FV 2.0: 5.85 vs 5.03 ms). Both carry same count of belt items (belt spots). Cost follows belt items taken, not items and not box count.
- Per belt item taken (items / 2.5 for `stacks`), lowest-load pair per row: yellow 120-125 us, red 108, blue 170, turbo 123, `ub-ultimate` 88, yellow `single` 101-104. Same band from 15/s to 270/s belts.
- 200 `ub-ultimate` boxes at full flow: 78-89 ms script per tick (tick budget 16.7 ms).
- Old R-1 scene on this busy host: 4.9-5.1 ms.

Verified-by: `~/.cache/sushi-packer/v14/bench-s0.sh ~/wt-sushi-packer-int-v14 s0 3 both` (stopped after round 2; log `~/.cache/sushi-packer/v14/logs/bench-s0.txt`; partial logs `bench-s0-partial-load15-reboot.txt`, `bench-s0-partial-oom-1032.txt`)

## FND-0038 - v14 S0b profile: no single hot spot; per belt item ~12 engine calls + core bookkeeping

Measured 2026-10-01 12:40-12:46 UTC on dev-vm 2.0.77, scratch worktree `~/wt-sushi-packer-prof-v14` (= `8444ab7` + `LuaProfiler` sections in `scripts/tick.lua` / `scripts/belt_io.lua`, never merged), 200 boxes, flow `stacks`, cumulative over ticks 0..1800. Host load1 37-40: absolute times inflated (turbo 86 ms per tick vs 24-37 in FND-0037), shares only. Profiler start/stop pair cost 2.8 us here (100000 empty pairs = 276 ms); about 4.4 M pairs in turbo run = ~8 % spread over sections.

| Section | Turbo ms | Share | Calls | Yellow ms | Share | Calls |
|---|---|---|---|---|---|---|
| whole `tick.on_tick` | 154640 | 100 % | 1801 | 35898 | 100 % | 1801 |
| `belt_io.pull` total | 100027 | 64.7 % | 176662 | 20111 | 56.0 % | 41745 |
| - sink: `core.accept` | 23523 | 15.2 % | 350400 | 5505 | 15.3 % | 80400 |
| - `get_detailed_contents` (take window) | 18021 | 11.7 % | 350924 | 0 (not fast) | - | - |
| - neighbour cache check, behind (`cached` -> `matches`) | 8527 | 5.5 % | 176662 | 1838 | 5.1 % | 41745 |
| - sink: `inventory.insert` | 8548 | 5.5 % | 350400 | 2036 | 5.7 % | 80400 |
| - `line[1]` + 3 field reads | 6076 | 3.9 % | 350400 | 1482 | 4.1 % | 80400 |
| - `line.remove_item` | 5705 | 3.7 % | 350400 | 2156 | 6.0 % | 80400 |
| - `#line` + `can_insert_at(0)` | 4680 | 3.0 % | 703724 | 1212 | 3.4 % | 163890 |
| - `get_transport_line` | 3786 | 2.4 % | 353324 | 925 | 2.6 % | 83490 |
| - eta block | 2515 | 1.6 % | 176662 | 1260 | 3.5 % | 41745 |
| - sink rest (stack size, filter check, closure) | 5109 | 3.3 % | - | 1022 | 2.8 % | - |
| - pull rest (loop, profiler) | 13540 | 8.8 % | - | 4175 | 11.6 % | - |
| `belt_io.push` total | 19197 | 12.4 % | 218518 | 4313 | 12.0 % | 49896 |
| - `can_insert_at_back` + `insert_at_back` | 5005 | 3.2 % | 218518 | 1083 | 3.0 % | 49896 |
| - push rest = front cache check + `get_transport_line` (not split) | 14192 | 9.2 % | - | 3230 | 9.0 % | - |
| `core.peek_out` + `core.take_out` + `core.on_tick` | 12197 | 7.9 % | - | 2832 | 7.9 % | - |
| `inventory.remove` (push side) | 2749 | 1.8 % | 218518 | 606 | 1.7 % | 49896 |
| circuit + reconcile + LED | 2174 | 1.4 % | - | 1035 | 2.9 % | - |
| loop rest (per box per tick: valid, force, LED state, closures) | 18300 | 11.8 % | 360200 box-ticks | 7000 | 19.5 % | 360200 box-ticks |

Counters same runs (ticks 0..1800): turbo visits 176662, reads 351448, pulls 350400, pushes 218518, items in 876092; yellow visits 41745, reads 690, pulls 80400, pushes 49896, items in 201021. Turbo: 2.0 belt items per visit, one `get_detailed_contents` per belt item taken.

Verdict: cost is spread. Largest single pieces: `core.accept` (pure Lua) 15 %, `get_detailed_contents` 12 % (fast tiers only), neighbour cache checks behind + front ~15 % together, inventory mirror insert + remove ~7 %, per-box-per-tick loop 12-20 %. No one fix removes most of it. Rung 1 (script only) candidates = those five; their sum is about 60 % of cost on turbo, so a x10 cut (to 0.02 ms per box on fast tiers) is not in reach of rung 1 by this profile.

Verified-by: `cd ~/wt-sushi-packer-prof-v14 && gateslot --label sushi-packer/heavy -- tools/bench/run.sh 2.0 --tier turbo --flow stacks --ticks 1900` (and `--tier yellow`); dumps `~/.cache/sushi-packer/v14/logs/prof-turbo.txt`, `prof-yellow.txt` (lines `tick=1800`)

## FND-0039 - Rung 2 probes: one loader per tile (hard engine rule); engine input into box chest works at belt rate

Measured 2026-10-01 on dev-vm, 2.0.77 + 2.1.20 identical unless said, `tests/game/test_probe_v14.lua` (NOT in index, SP-10), test-env prototypes `sp-test-r2-in` / `sp-test-r2-out` (`loader-1x1` copies, `container_distance = 0`, `max_belt_stack_size = 4`; out: `wait_for_full_stack = true`) and `sp-test-r2-chest` (steel chest, empty collision mask). API docs 2.0.72 + 2.1.20: `LoaderPrototype` has `container_distance`, `wait_for_full_stack`, `per_lane_filters` (needs `filter_count = 2`), `max_belt_stack_size`, `adjustable_belt_stack_size`.
- Prototypes load: `container_distance = 0` accepted. Loader on same tile as chest: `loader_container` = that chest.
- Two loaders on one tile: second `create_entity` returns nil (2.0.77). Giving each loader a different single belt layer (`transport_belt` / `floor`) fails load: `entity prototype "sp-test-r2-out" (loader-1x1) collision_mask ... must collide with entity prototype "sp-test-r2-in" (loader-1x1) collision_mask`. Engine rule: every belt-connectable collides with every other (same family as FND-0018). So engine input AND engine output on one 1x1 tile: impossible.
- Engine input alone (candidate G: belt behind -> input loader on box tile -> chest on box tile; warm-up 600, measured 300 ticks, chest emptied every 30 ticks): yellow 38 / 38 belt items per lane (want 38), turbo 150 / 150 (want 150), 270/s test belt 600 / 600 (want 675: loader cap 2 belt items per lane per tick = 240/s, same as FND-0036). Stacked belt items 1..4 taken at same rate. Both lanes land in one chest: lane of origin is lost.
- Stop by script: `loader.disabled_by_script = true` -> 2 + 2 belt items in next 300 ticks (stopped), reads back true, both versions. `loader.active = false` stops on 2.0.77; 2.1.20: `LuaEntity::active is read only.` -> not usable (SP-04).
- Rung 1 helper idea dead: `line.can_insert_at(q)` is false only at the exact position of an item (item at 0: only q = 0 false; item at 0.125: only q = 0.125 false), not over a range, so it cannot replace `get_detailed_contents` for "front item within belt_speed of end".
Open (not probed): script-side output cost for candidate G, loader visuals / rotation / blueprint on box tile, circuit wires on chest with loader on top, pass-through and timeout rules without per-item arrival data.

Verified-by: `make test-one FV=2.0 T='tests/game/test_probe_v14.lua::probe v14 > r2 loader pair on one tile'`, `... > r2 engine input into box chest'`, `... > can_insert_at vs front item position'` (temporary index entry; second one same on `FV=2.1`)

## FND-0040 - Way A probe: hidden inserters locked to one belt lane keep lanes exactly, reach full belt rate

Source of idea (web, read 2026-10-01): Miniloader Redux (`github.com/hgschmie/factorio-miniloader-redux`, `scripts/controller.lua`): hidden inserters with `pickup_from_left_lane` / `pickup_from_right_lane` (LuaEntity, read/write, 2.0.72 + 2.1.20 docs; added 2.0.56). Inserters are not belt-connectables, so many share one tile (unlike loaders, FND-0039).

Measured 2026-10-01 on dev-vm, 2.0.77 + 2.1.20 identical, `tests/game/test_probe_v14.lua` (NOT in index, SP-10), test-env `sp-test-arm` (`bulk-inserter` copy: `allow_custom_vectors`, `chases_belt_items = false`, `stack_size_bonus = 11`, `uses_inserter_stack_size_bonus = false`, `rotation_speed = 0.5`, `extension_speed = 1`, void energy, empty collision mask). Rig: belt dead-ends at box tile; on box tile 2 chests `sp-test-r2-chest` (one per lane) + n arms per lane, each with `pickup_position` = belt tile behind, `drop_position` = box tile, lane flags, `drop_target` = its lane chest. Left lane fed `iron-plate`, right lane `copper-plate` (one kind per lane); warm-up 600, measured 600 ticks, chests read + emptied every 20 ticks. Every property write accepted on both versions.
- Lane lock exact: left chest 0 copper, right chest 0 iron in all 10 rigs.
- `drop_target` picks one of two chests on same tile.
- Rate, belt items accepted per lane vs want: yellow 1 arm 75 / 75; turbo 1, 2, 4 arms 300 / 300; 270/s belt 2 arms 1108 / 1350 (82 %), 4 and 8 arms 1350 / 1350 (full: no 240/s loader cap). Belt stacks of 4: turbo 1 arm 1200 / 1200 items, 270/s belt 4 arms 5400 / 5400.
- Caveat found in scratch bench (same day, 5 turbo boxes, flow `stacks` = 4 kinds mixed per lane, 1200 ticks, load 28-41): one arm carries one kind per swing, so mixed lanes need more arms: items through per arms-per-lane 1 / 2 / 4 / 8 = 2248 / 6024 / 14140 / 14164 (engine loader same scene: 14360). Turbo mixed flow needs 4 arms per lane.

Verified-by: `make test-one FV=2.0 T='tests/game/test_probe_v14.lua::probe v14 > arms lane lock and rate'` (temporary index entry; same on `FV=2.1`); scratch bench `~/wt-sushi-packer-r2-v14` `tools/bench/run.sh 2.0 --tier turbo --flow stacks --boxes 5 --ticks 1300 --arms <n>`

## FND-0041 - Big-fix scratch bench: arms (Way A) and pot (Way B) vs today's packer vs plain belts

Measured 2026-10-01 13:44-15:03 UTC on dev-vm 2.0.77, scratch worktree `~/wt-sushi-packer-r2-v14` (= `53d7d9b` + scratch rigs in bench mod, never merged), 200 boxes, 3600 ticks, flow `stacks`, belt stack 4, 1 run per row, host load1 15-42 (other sessions): order of size only, not bar-grade. Rigs: pot = input loader `container_distance = 0` + one chest on box tile (FND-0039); arms = n lane-locked inserters per lane + one chest per lane (FND-0040). Output half of both = bench-mod script every 2 ticks per box: `get_contents` of chest, `insert_at_back` full stacks of 4 while lane free, `inventory.remove`; pot alternates lanes, arms push each chest to its own lane. No filter, timeout, circuit, LED, GUI logic in rigs.

| Row | Scene | script ms | whole ms | items in 3000 ticks | load1 |
|---|---|---|---|---|---|
| turbo | packers today | 56.280 | 70.232 | 1476092 | 21.7 |
| turbo | pot | 2.442 / 2.669 | 11.152 / 11.479 | 1474864 | 25.4 / 24.5 |
| turbo | arms, 4 per lane | 3.855 | 13.937 | 1463492 | 35.0 |
| turbo | plain belts | 0.020 / 0.020 | 5.441 / 4.728 | - | 32.9 / 19.8 |
| yellow | packers today | 16.316 | 25.663 | 351087 | 26.1 |
| yellow | pot | 1.533 | 6.504 | 350400 | 33.0 |
| yellow | arms, 1 per lane | 1.688 | 4.737 | 226060 (64 %) | 19.4 |
| yellow | arms, 2 per lane | 1.485 | 4.958 | 347416 | 28.4 |
| yellow | plain belts | 0.017 / 0.014 | 4.672 / 1.752 | - | 44.2 / 23.1 |
| `ub-ultimate` | packers today | 342.336 (load 28; 78-89 at load 7-14, FND-0037) | 383.880 | 6675803 | 28.0 |
| `ub-ultimate` | pot | 15.490 / 12.674 | 47.640 / 35.504 | 5973448 (89 %, loader cap) | 42.0 / 23.5 |
| `ub-ultimate` | arms, 8 per lane | 9.403 | 25.721 | 6586656 (98.7 %) | 15.4 |
| `ub-ultimate` | arms, 16 per lane | 8.822 | 26.682 | 6650064 (99.6 %) | 16.8 |
| `ub-ultimate` | plain belts | 0.034 / 0.019 | 18.541 / 6.667 | - | 39.0 / 19.7 |

Readings: both rigs cut script cost about x10-x20 and whole-update cost (minus belts) about x5-x8 against today's packer in same session. Arms keep lanes exactly (FND-0040) and reach belt rate on 270/s belt with 8 arms per lane; pot loses lane of origin and caps at 240/s. Arms needed for mixed flow: yellow 2, turbo 4, 270/s 8 per lane. First `ub-ultimate` arms rows (8 and 16 arms both 2387220 items) were a rig artifact: output script pushed one stack per lane per visit; fixed to push while lane free, rows above are the rerun.

Verified-by: logs `~/.cache/sushi-packer/v14/logs/bench-r2.txt`, `bench-arms.txt`; `cd ~/wt-sushi-packer-r2-v14 && gateslot --label sushi-packer/heavy -- tools/bench/run.sh 2.0 --tier <tier> [--modset ubsa] --flow stacks [--arms <n> | --r2 | --belt-only]`

## FND-0042 - v15 S0 probes: arms box engine facts (skip kind, pause, behind kinds, wires, arms per speed)

Measured 2026-10-01 on dev-vm, 2.0.77 + 2.1.20 identical, `tests/game/test_probe_v15.lua` (NOT in index, SP-10), test-env `sp-test-arm` / `sp-test-arm-f` (filter_count 5), `sp-test-r2-chest`. Turbo belts unless said, 4 arms per lane, 1200 ticks.
- Skip kind: arms of left lane `use_filters = true`, `inserter_filter_mode = "blacklist"`, `set_filter(1, { name = "iron-plate" })`; left lane fed copper / iron alternating: left store copper 4, iron 0; lane then waits at iron (28 belt items fed in 1200 ticks vs right lane coal 576 through). = C-6 wait semantics, no script per item.
- Pause: `disabled_by_script = true` on all arms at tick 600: stores 276 / 278 at tick 630 and at tick 1200, belt accepted 304 / 304 at both times (frozen); flag reads true. (`active` is read-only on 2.1, FND-0039.)
- Behind box: splitter output half: left store iron 1116 / copper 0, right store iron 0 / copper 1116; underground exit 564 / 0 and 0 / 555; `loader-1x1` output (iron on both lanes) 2376 / 2376; belt running north 579 / 0 and 0 / 576. Lane lock exact in every case; `pickup_position` = centre of tile behind box.
- Wires: `store.get_wire_connector(id, true).connect_to(box.get_wire_connector(id, true), false, defines.wire_origin.script)` for red + green; box 3 coal, store L 7 iron, store R 5 copper + 2 iron: `box.get_signal` red iron 9, copper 5, coal 3; green iron 9. Native read contents sums box + both stores.
- Arms per lane, worst mix (single items, 4 kinds, every belt item differs from one before), belt items accepted per lane in 600 ticks vs want, n = 1 / 2 / 4 / 8 / 12: yellow (75) 50 / 75 / 75 / 75 / 75; red (150) 46 / 99 / 150 / 150 / 150; blue (225) 45 / 106 / 225 / 225 / 225; turbo (300) 45 / 118 / 300 / 300 / 300; 135/s test belt (675) 45 / 113 / 584 / 675 / 675; 270/s test belt (1350) 45 / 144 / 1350 / 1350 / 1350. Table chosen (`N.ARMS`): speed <= 0.03125 -> 2, <= 0.125 -> 4, above -> 8.

Verified-by: `make test-one FV=2.0 T='tests/game/test_probe_v15.lua::probe v15 > arms per speed worst mix'`, `... > skip kind pause wires behind kinds'` (temporary index entry; same on `FV=2.1`)

## FND-0043 - v1.15 arms box: integration results (tests, old save, speed pairs vs v1.14)

Measured 2026-10-01 on dev-vm, 2.0.77 + 2.1.20, branch `int/v14`. Design: V14-9..11, V15-1..4.

Integration path (each red seen before fix): first headless run of merged lanes 040-046 `Tests: 26 failed, 117 passed`; 25 of 26 were tests reading old internals (rewritten on lane stores, helper run, each alone on both versions), 1 real defect (C-6 overshoot 55 / 53 of 50). Further defects found by headless runs and fixed: visit gap 2 lost blue rate (200 of 225); `arms._valid` asked `type(part) == "table"` (engine objects are userdata); full-store flush fired without a waiting kind; arm does not pick an item its store cannot take, so waiting kind is seen on belt behind (`belt_io.behind_kinds`), not in arm hand; idle nap on a pass-through box cost 10-25 % rate; hoard limit with slack blocked stack-50 kinds at 2 items; arms with hand 12 held up to 18 items while lane store ran empty (trace: `321:s0,h13 ... 336:s0,h18`), blue 213..216 of 225 -> hand 4; hand 4 at 270/s needs 12 arms per lane (8 gave 1271 of 1350); yellow needs 4 arms per lane for a belt of mixed stacks (2 passed 95.7 %).

Final code `4b22600`: `make test FV=2.0` -> `Tests: 143 passed (143 total)`, `full-2.0-ok`; `make test FV=2.1` -> `Tests: 143 passed (143 total)`, `full-2.1-ok` (round 5; rounds 3 and 4 same counts on `9065aa9` / `89b2b6c`). Mod sets and load checks: see STEPS v1.15 (round 5).

Old save: save made by released 0.1.14 code (stage of `73b4849`) + test mod `sp-oldsave`: 3 north boxes (yellow, red, turbo), no front belt, 900 ticks of feed, 16 kinds on left lane, 8 other kinds on right lane; at tick 950: `fed=593 behind1=48 behind2=48 box=497`. Same save loaded by 0.1.15 build (`89b2b6c`), front belts built at tick 1000, run to tick 6000 (`--benchmark`, 5100 ticks): `fed=593 front1=229 front2=279 store=85 mismatch[] lane_cross=0`: every kind conserved (229 + 279 + 85 = 593), nothing on ground, no left-lane kind on right lane or reverse; 85 = leftovers below one belt stack in lane stores. Same result on earlier build `a3c929b` (232 / 279 / 82). FV 2.1 (18:31 UTC): save made by 0.2.14 (stage of `73b4849`, 2.1.20; 2.1 has no `--until-tick`: loopback server stopped by `timeout 60`, autosave at tick 950: `fed=593 behind1=48 behind2=48 box=497`), loaded by 0.2.15 (`7fe638f`): `fed=593 front1=229 front2=279 store=85 mismatch[] lane_cross=0`.

Speed, alternating pairs base (`99e243b` = v1.14 scripts + v14 bench tooling) vs new, `tools/bench/run.sh`, flow `stacks`, belt stack 4, 200 boxes, 3600 ticks unless said, script ms per tick; host load1 2.5..9; no separate A/A run (base rows of one tier differ up to x1.4 between rounds with load: cuts below are far outside that).

| FV | Row | Base r1 / r2 | New r1 / r2 | Cut r1 / r2 | Items new / base | New code |
|---|---|---|---|---|---|---|
| 2.0 | yellow | 5.297 / 5.184 | 1.995 / 1.683 | 62 % / 68 % | 350816 / 351087 | `4b22600` |
| 2.0 | red | 12.203 / 9.066 | 3.307 / 3.102 | 73 % / 66 % | 725692 / 726086 | `89b2b6c` |
| 2.0 | blue | 24.490 / 21.169 | 8.407 / 7.600 | 66 % / 64 % | 1100140 / 1101047 | `89b2b6c` |
| 2.0 | turbo | 24.079 / 20.650 | 5.753 / 5.559 | 76 % / 73 % | 1473228 / 1476092 | `89b2b6c` |
| 2.0 | `ub-ultimate` (set `ubsa`, 1300 ticks) | 66.120 / 67.351 | 14.038 / 14.384 | 79 % / 79 % | 2632444 / 2638403 | `89b2b6c` |
| 2.0 | player rig `g433`, 5 `ab-extreme` boxes | 0.963 / 1.066 | 0.406 / 0.373 | 58 % / 65 % | 92300 / 92372 (r2) | `89b2b6c` |
| 2.1 | yellow | 5.225 / 4.840 | 1.678 / 1.601 | 68 % / 67 % | 350816 / 351087 | `4b22600` |
| 2.1 | turbo | 20.798 / 20.666 | 5.375 / 5.856 | 74 % / 72 % | 1473228 / 1476092 | `89b2b6c` |
| 2.1 | `kr-superior` (set `k2so`) | 36.660 / 34.230 | 11.065 / 9.884 | 70 % / 71 % | 2223608 / 2226082 | `89b2b6c` |

`89b2b6c` -> `4b22600` changes only arms per lane of tiers with belt speed <= 0.03125 (yellow 2 -> 4); other rows unaffected by code. Yellow on `89b2b6c` (2 arms): 6.823 / 4.916 -> 2.048 / 1.712, items 336084 of 351087 (95.7 %): reason for the change. Player rig base includes other mods' scripts (belt-only scene 0.13..0.15 ms, FND-0037): packer share falls from about 0.85 ms to about 0.25 ms for 5 boxes (about 0.05 ms per box on this VM; player saw 0.08 ms per box with 0.1.12 on their PC).
R-1 (v14 text): every FV 2.0 row and player rig at least 50 % below v1.14 code: met in 12 of 12 pairs (58..79 %); FV 2.1 rows not slower: met (67..74 % less). Rule asked for mean of >= 6 pairs after an A/A band: 2 pairs per row measured, no A/A run - stated, not met as written.
Rig numbers of FND-0041 (x10..x20) were not reached: real loop keeps order, timers, hoarding rule, LED, pause and extra items.

Verified-by: logs `~/.cache/sushi-packer/v14/logs/full-2.0-v15-r5.log`, `full-2.1-v15-r5.log`, `pairs-v15.txt`, `pairs-v15-yellow4.txt`; old save `~/.cache/sushi-packer/v15/oldsave/` (`run-old.log`, `run-new-final.log`, mod `sp-oldsave`), `~/.cache/sushi-packer/v15/oldsave21/` (`run-old.log`, `run-new.log`); scripts `~/.cache/sushi-packer/v14/pairs-v15.sh`, `pairs-yellow.sh`

## FND-0044 - v1.15 speed proof as R-1 words it: noise check, 6 pairs, bench-all; bench map was random

Measured 2026-10-01 17:36-20:16 UTC, dev-vm, load1 1.9..7. Adds to FND-0043 (rounds 1-2); rounds 3-6 same script, new code `4b22600`. Yellow rounds 1-2 = 4-arm reruns.

Noise (A/A, v1.14 code against itself, FV 2.0, alternating): yellow 5.032 / 5.355 (+6.4 %), 5.883 / 5.710 (-2.9 %); turbo 23.525 / 22.119 (-6.0 %), 22.891 / 21.847 (-4.6 %). Band: +-6.4 %.

| FV | Row | Pairs | Base mean | New mean | Mean cut | Worst pair | Gain |
|---|---|---|---|---|---|---|---|
| 2.0 | yellow | 6 | 5.127 | 1.723 | 66.4 % | 62.3 % | x3.0 |
| 2.0 | red | 6 | 9.562 | 3.179 | 66.4 % | 63.1 % | x3.0 |
| 2.0 | blue | 6 | 21.157 | 7.874 | 62.7 % | 60.7 % | x2.7 |
| 2.0 | turbo | 6 | 19.981 | 5.592 | 71.7 % | 62.8 % | x3.6 |
| 2.0 | `ub-ultimate` | 6 | 61.091 | 13.518 | 77.8 % | 75.5 % | x4.5 |
| 2.0 | player rig `g433` | 6 | 1.015 | 0.370 | 63.4 % | 57.8 % | x2.7 |
| 2.1 | yellow | 6 | 5.149 | 1.654 | 67.8 % | 66.8 % | x3.1 |
| 2.1 | turbo | 6 | 20.354 | 5.718 | 71.9 % | 69.6 % | x3.6 |
| 2.1 | `kr-superior` | 6 | 35.019 | 10.345 | 70.5 % | 65.0 % | x3.4 |

Verdict R-1 (v14 text): every FV 2.0 row and player rig: mean cut 62.7..77.8 %, worst pair 57.8 %, band 6.4 % -> at least 50 % below v1.14: MET. FV 2.1 not slower: MET. Not x10..x20 of rig (FND-0041): gain x2.7..x4.5.

R-3 `make bench-all` (new code, one run per row, 200 boxes, script ms): FV 2.0 yellow 1.508, red 2.835, blue 6.616, turbo 5.030, `ub-ultimate` 12.236; FV 2.1 yellow 1.449, red 2.474, blue 6.050, turbo 5.106, `kr-superior` 8.490.

Bench flaw found: `tools/bench/run.sh` made save with random map seed. On `g433` (Space Exploration terrain) `items_in` differed between runs of same code: new 92300 x4, 86348, 54924; base 92372 x5, 78742. With `--map-gen-seed 1`: new 86012 in 3 of 3 runs, base 86444: counts repeat, both codes alike on same map -> difference came from map, not from box code. Which rig part the terrain blocks: not looked at. Fix: seed pinned in `run.sh` (rows from now on not comparable in `items_in` to rows above on `g433`; vanilla rows showed no such spread).

Verified-by: `~/.cache/sushi-packer/v14/logs/pairs-v15.txt`, `pairs-v15-yellow4.txt`, `pairs-v15-r3-6.txt`, `pairs-v15-aa.txt`, `bench-all-2.0-v15.log`, `bench-all-2.1-v15.log`

## FND-0045 - Where arms-box script time goes (timers per step, scratch build)

Measured 2026-10-01 20:3x UTC, dev-vm, 2.0.77, scratch worktree `~/wt-sushi-packer-prof-v15` (`317e281` + `LuaProfiler` around each step of `visit_lane`; never merged), 200 boxes, flow stacks, 3000 ticks. Timers themselves cost: turbo 5.1 -> 8.3 ms per tick, yellow 1.7 -> 2.8, so shares are rough.

| Step | Turbo ms (share of lane time) | Yellow ms (share) |
|---|---|---|
| before checks (pause, credit) | 965 (5 %) | 303 (5 %) |
| `belt_io.can_push` | 3543 (20 %) | 1222 (22 %) |
| `inv.get_contents()` | 4505 (26 %) | 1342 (24 %) |
| rules: slot count, `ledger.plan`, hoard | 4912 (28 %) | 1622 (29 %) |
| `belt_io.push` | 2649 (15 %) | 744 (13 %) |
| `inv.remove` | 1075 (6 %) | 322 (6 %) |
| lane time total | 17649 | 5554 |
| whole `on_tick` | 24503 | 8306 |

Reading: putting stacks on belt and taking them from store (work that must happen) is about 20 % of lane time. About 75 % is looking and deciding: can lane push, what is in store, which stack leaves. Outer loop per box (circuit, LED, bookkeeping, timer cost) is the rest of `on_tick` (28 % turbo, 33 % yellow).
Not tried: skipping read + rules on visits where store did not change; one rules pass for several pushes. No claim on gain before a bench of real code (FRC-0043).

Verified-by: `~/wt-sushi-packer-prof-v15/build/bench-2.0/benchmark.log` (yellow run; turbo line from run before it, copied here from tool output), patch `prof_patch.py` (session scratchpad, plus `PS.reset()` fix)

## FND-0046 - v16 S0: engine can do output (out arms). Probes P1..P12 + scratch bench

Measured 2026-10-01 20:50-22:30 UTC, dev-vm (load1 5..11, other jobs on host), 2.0.77 + 2.1.20, scratch branch `probe/v16` (`~/wt-sushi-packer-probe-v16`, never merged), file `tests/game/test_probe_v16.lua`, test-env prototypes `sp-test-out*`, `sp-test-store`.

| # | Result |
|---|---|
| P1 lane | 4 directions: left-store kinds only on left lane, right-store kinds only on right lane (`dir1..4 L[copper-plate=396,iron-plate=348] R[electronic-circuit=348,steel-plate=396]`), 2.0 and 2.1. `pickup_target` writable, picks store among two on tile. Drop lane = front tile centre +- 0.25 across travel. |
| P2 stacks | all belt items `stacks[4=186]` at belt stack 4. Set `nosa` (no Space Age mod, flag off): items leave single (`stacks[1=136]`), as box does today without stacking research. |
| P3 leftover | arm takes 3 plates into hand and waits forever (store 0, nothing out); arm takes last slot first (3 gears in last slot taken while 400 copper present). Variant `wait_for_full_hand = false` drops partial stacks at once (not used). |
| P5 rate, no script at all | feed = full belt of mixed stacks 1..4, 5 kinds, 1200 ticks: 8 out arms: yellow 99.7 / 99.2 %, red 100.8 / 99.2, blue 98.9 / 99.4, turbo 100.4 / 101.0, 270/s 100.2 / 99.8; 4 arms: yellow 100 %, turbo 99.9 / 81.7; belt stack 1: 100 % every tier with 4 and 8 arms. |
| P10 jam | 8 rare kinds (1..3 items each, once): no script -> red, turbo, 270/s lanes at 0 % (every arm holds a rare leftover). Filter steering every 30 ticks + hand return: 98.4..100.8 % but costs script (below). Cheap rule (look at hands only when store had a full stack two looks in a row; flush partial hands when every arm holds): 8 arms 100.0..102.4 % (270/s row fed 71 % of belt: stores full of rare leftovers, needs full-store flush F-1); 12 kinds: 96.6..103 %, 6..8 % of stacks leave below full size on slow tiers. |
| P11 | no stack with mixed kinds; below-size stacks only from flush. |
| hand size | prototype hand = engine max; `inserter_stack_size_override = bss`: stacks exactly 2 / 4 / 20; bss 1: nothing waits (`hands=0,0,0,0`). |
| P7 front | splitter half: lanes kept (`L[iron-plate=200] R[copper-plate=200]`), underground entrance same, 1x1 loader into chest all 400 items; sideways belt: arms drop onto it (all on one lane) -> script must pause out arms without valid front. |
| P12 outside inserters | store without `no-automated-item-removal`: outside inserter `pickup_target=sushi-packer-lane-store` (takes lane-store items); giver `drop_target` = box. Tiny off-centre store: still targeted. |
| P6 pause, P9 two loaders, P4 order | not run (pause proven for in arms FND-0042; loaders not needed; order dropped V16-2). |

Scratch bench (200 boxes, flow stacks, 3600 ticks, 8 out arms, script = look every 30 ticks: circuit, 2 x `get_contents`, LED; no flush, no jam rule): turbo 2.0 script 0.226 ms, whole 5.529 (belt-only whole 2.891); yellow script 0.214, whole 3.864 (belt-only 1.363); `full_lane_looks=0` (stores never full). Reference same day: v1.14 turbo 20.0 / whole 23.9, v1.15 turbo 5.6 / 9.0; v1.14 yellow 5.1 / 6.3, v1.15 yellow 1.7 / 3.7..3.9. With naive filter steering each look: turbo 1.532, yellow 1.217 (2.1 turbo 1.131) -> rejected.
Gate (plan v16): lane-true yes, stacked yes, no jam with cheap rule yes, scratch >= x10 yes (x24 yellow, x88 turbo, scratch without flush rules). Product number comes from bench of real code.
Also seen: v1.15 loses items held in arm hands when box is mined or rotated (`arms.create` / `arms.destroy` destroy arms with items; registry returns store items only). Not reproduced as test yet; fixed by seam (`arms.create` saves hands, `arms.drain_hands`).

Verified-by: `~/wt-sushi-packer-probe-v16` (`make test-one FV=2.0|2.1 T='tests/game/test_probe_v16.lua::probe v16 > <name>'`, names: out arm lane stack leftover, pipe bss4 no script, pipe bss1 no script, pipe 12 kinds no script, pipe rare no script, pipe rare steer30, pipe 12 kinds steer30, pipe rare jamflush, pipe 12 kinds jamflush, outside inserters, small stores off centre, hand bss*, front variants); bench lines in session log 2026-10-01

## FND-0047 - v1.16 engine-output box: integration results (tests, old saves, speed vs v1.14 and v1.15)

Measured 2026-10-01 21:30 .. 2026-10-02, dev-vm (shared, load1 1.2..18), 2.0.77 + 2.1.20, branch `int/v16`. Design V16-1..13.

Integration path, each red seen before fix: first full suite after lanes 048..051 `Tests: 12 failed, 131 passed`: 7 tests of dropped rules or of script push counts (moved / removed), 5 real: leftovers of one kind split over hands never became a stack (V16-8); box passed far above tier (V16-9; swing time measured: rotation speed 0.5 / k -> 2 (k - 1) ticks per swing; zero pickup vector made swing depend on box direction); LED blind to stopped box and to hands. Later rounds: mod sets `nosa`, `se`, `ab` output single items (V16-10); bench of real code 1.0..1.4 ms per 200 boxes on every belt (timers: hand reads 57 % of look, front check 17 us per look, 0.38 ms per tick walking all boxes) -> schedule, rare hand looks, cached front check (V16-11, V16-13); game test `rare leftovers do not jam a busy lane` red (`fed=1230 out=480 store=1103 hands=19`); game test `arms holding leftovers do not block later stacks on an idle belt` red (`out=0 held=48 store=40 hands=8`); 2 s flush timer fired after about 10 s (next sweep now at timer end); in full suite only: front belt `{1, 4}` with `out1.7=3` (hand size written at first look; now at creation). Wrong causes named by me before repro, both refuted by a test: "deadlock" read from old-save totals (true leftovers: about 3 items per kind per box); "3 + 3 + 2 in hands" for the `{1, 4}` failure.

Final code `632a5c4`: `make test FV=2.0` -> `Tests: 145 passed (145 total)`, `full-2.0-ok`; `make test FV=2.1` -> `Tests: 145 passed (145 total)`, `full-2.1-ok`; `test-modsets-2.0-ok` (13 sets), `test-modsets-2.1-ok` (8 sets); `load-check-2.0-ok`, `load-check-2.1-ok`, sets `them8` (both), `g433` (2.0) ok; zips `sushi-packer_0.1.16.zip` / `sushi-packer_0.2.16.zip` 292 files each.

Old saves (harness `~/.cache/sushi-packer/v16/oldsave/`, checker counts arm hands): save made by 0.1.14 / 0.2.14 and by 0.1.15 / 0.2.15, loaded by 0.1.16 / 0.2.16, front belts built at tick 1000, state at tick 6000: v1.14 save both versions `fed=593 front1=218 front2=279 hands=73 store=23 mismatch[] lane_cross=0`; v1.15 save `fed=731 front1=22 front2=596 hands=78 store=35 mismatch[] lane_cross=0` (2.1: `front2=594 hands=80`). Every kind conserved, nothing on ground, no kind on wrong lane. Left lane of v1.15 save holds about 3 items per kind per box: true leftovers.

Speed, `tools/bench/run.sh` (map seed pinned), flow stacks, 200 boxes, 3600 ticks, script ms per tick; trio base (`99e243b`, v1.14 scripts) / v1.15 (`353c37a`) / new (`06c4ef2`; later commits change timer sweep, merge follow-up, hand size at creation: spot check on `632a5c4` yellow 2.0 0.317, yellow 2.1 0.286, turbo 0.361). A/A band of base +-6.4 % (FND-0044).

| FV | Row | Base r1 / r2 | v1.15 r1 / r2 | New r1 / r2 | Gain vs base | Whole tick v1.15 -> new |
|---|---|---|---|---|---|---|
| 2.0 | yellow | 4.870 / 4.521 | 1.593 / 1.325 | 0.344 / 0.280 | x14 / x16 | 3.43 / 2.77 -> 2.38 / 1.82 |
| 2.0 | red | 9.199 / 7.319 | 2.946 / 2.671 | 0.322 / 0.260 | x29 / x28 | 5.31 / 4.92 -> 3.01 / 2.20 |
| 2.0 | blue | 21.096 / 17.037 | 7.001 / 5.940 | 0.259 / 0.267 | x81 / x64 | 10.22 / 8.35 -> 2.62 / 2.85 |
| 2.0 | turbo | 16.462 / 17.705 | 4.618 / 4.654 | 0.259 / 0.272 | x64 / x65 | 7.53 / 7.56 -> 3.03 / 3.04 |
| 2.0 | `ub-ultimate` (1300 ticks) | 49.777 / 55.916 | 10.777 / 11.120 | 0.391 / 0.444 | x127 / x126 | 15.90 / 16.46 -> 5.91 / 7.60 |
| 2.0 | player rig `g433`, 5 boxes | 0.954 / 0.857 | 0.312 / 0.338 | 0.125 / 0.131 | x7.6 / x6.5 raw | 1.10 / 1.22 -> 0.86 / 0.90 |
| 2.1 | yellow | 3.683 / 3.925 | 1.300 / 1.758 | 0.273 / 0.344 | x13 / x11 | 2.69 / 4.16 -> 1.74 / 2.68 |
| 2.1 | turbo | 15.699 / 17.344 | 4.404 / 5.164 | 0.265 / 0.376 | x59 / x46 | 7.14 / 8.72 -> 2.87 / 5.53 |
| 2.1 | `kr-superior` | 28.281 / 45.563 | 7.584 / 15.290 | 0.324 / 0.436 | x87 / x104 | 11.19 / 24.58 -> 3.90 / 7.20 |

Player rig: same scene with plain belts (other mods' scripts) 0.134 / 0.142 / 0.151 ms: packer share about 0.8 ms (v1.14) -> not distinguishable from zero (new 0.125 / 0.131 is inside belt-only spread). Raw ratio x6.5..x7.6 is therefore not the packer gain; stated, not hidden. Counter `full` (lane looks with store full): 0 on every vanilla and mod-tier row, 4..5 on `g433` (5 boxes, 2 rounds).
Third trio round on final code (`632a5c4` = `main` without docs), reverse order (new, v1.15, base), 02:36-02:57 UTC, load1 2.1..5.4, script base / v1.15 / new and gain: FV 2.0 yellow 4.373 / 1.452 / 0.342 (x12.8), red 6.949 / 2.309 / 0.320 (x21.7), blue 16.531 / 5.906 / 0.245 (x67.5), turbo 15.724 / 4.431 / 0.266 (x59.1), `ub-ultimate` 57.790 / 10.991 / 0.386 (x150), `g433` 0.793 / 0.310 / 0.127 (x6.2 raw); FV 2.1 yellow 3.921 / 1.302 / 0.322 (x12.2), turbo 18.030 / 4.598 / 0.295 (x61), `kr-superior` 30.929 / 7.864 / 0.323 (x96). Whole tick new below v1.15 on all 9 rows (yellow 2.0 3.19 -> 2.62, yellow 2.1 2.77 -> 2.25, `g433` 1.08 -> 0.88). `full=0` on 8 belt rows, 4 on `g433`. Log `pairs-v16-final.txt`. Rounds 1 and 2 above ran in same order (base first): my script call, not alternating as planned; round 3 is the reverse one.
Bar (author 2026-10-01): script at least x10 below v1.14 on every belt row: met on all 8 belt rows in 2 of 2 rounds (closest: FV 2.1 yellow x11); whole tick not above v1.15: met on all 9 rows in 2 of 2 rounds. Applies to installs with space-travel feature flag; without it box runs v1.15 path (V16-10).
Whole-tick numbers on a shared host move with load (see r1 / r2 spread on FV 2.1 rows).

Verified-by: `~/.cache/sushi-packer/v16/logs/` (`full-2.0-r10.log`, `full-2.1-r10.log`, `modsets-2.0-r9.log`, `modsets-2.1-r9.log`, `pairs-v16.txt`, older rounds `pairs-v16-*.txt`), `~/.cache/sushi-packer/v16/oldsave/<FV>/load14.log`, `load15.log`, script `~/.cache/sushi-packer/v16/pairs-v16.sh`
