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
