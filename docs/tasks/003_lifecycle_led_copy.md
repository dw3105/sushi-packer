# 003 — lifecycle, LED, settings copy (registry, led, copy)

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-003_lifecycle_led_copy`, branch `lane/003_lifecycle_led_copy`, base tag `lanes-base`, merge target `int/v1`. Host `legalcopilot-dev`.

This task is complete in itself. Other modules are built by other lanes against the same frozen contract; you never need them.

## You have about 60 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** signatures of `registry`, `led`, `copy` in `tests/offline/contract.lua`; event wiring in `control.lua:20-60`; every file outside "Files this lane owns" byte-identical to `lanes-base`.

- Contract: `docs/CONTRACT.md` (module rules `:5-11`, storage layout `:15-42`, measured game facts `:46-54`, this lane's module section cited below). Requirements `docs/REQUIREMENTS.md`, decisions `docs/DECISIONS.md`.
- Modules owned by other lanes are S0 stubs (`scripts/<module>.lua`): pure functions `error("stub: ...")`, event handlers no-op. Never call a stub for real. In tests, fake the other side: save the original function in `before_each`, replace it on the shared module table (`local core = require("scripts.core"); core.new_box = function() return {} end`), restore in `after_each`. Or build `rec` by hand per `docs/CONTRACT.md:15-42` and put it in `storage.boxes[entity.unit_number]`.
- `scripts/names.lua`: every prototype name (`N.variant(tier, dir)`, `N.placer(tier)`, `N.item(tier)`, `N.led(state, dir)`), `N.DIRS`, `N.TIERS`, `N.TIER[tier].lane_rate`.
- S0 data stage builds tier `yellow` only (`prototypes/packer.lua:6`); build yellow boxes in tests.
- In-game tests: FactorioTest with luassert. Globals `describe`, `it`, `test`, `before_each`, `after_each`, `after_ticks(n, fn)` (test waits), `assert.are_equal(expected, found)`, `assert.is_true`, `assert.is_nil`, `assert.is_not_nil`. Examples: `tests/game/test_probe.lua` (belts, `after_ticks`, blueprint, player). Surface `game.surfaces[1]`, force `game.forces.player`, player `game.players[1]` (one, with character). Clear your area in `before_each` (see `tests/game/test_probe.lua:4-8`).
- Test full name = `<describe> > <it>`. Runner: `tools/run_tests.sh <2.0|2.1> '<file>::<describe> > <it>'` fails unless exactly that one test ran and passed. One in-game test takes 10-26 s wall.
- Factorio headless `~/factorio-2.0/factorio` (2.0.77) and `~/factorio-2.1/factorio` (2.1.20). Only API present in both. Docs https://lua-api.factorio.com/2.0.72/ (no network in lane; use local `~/factorio-2.0/factorio/data` Lua sources and `doc-html` if present for reference).
- This lane's contract: `docs/CONTRACT.md:88-119` (led, registry, copy). Decisions D-3, D-4, Q-9 in `docs/DECISIONS.md`.
- `control.lua:20-46` routes build events (placers + variants) to `registry.on_built`, removal events (variants) to `registry.on_removed`, `on_entity_died` to `registry.on_died`, custom inputs `N.INPUT_ROTATE` / `N.INPUT_REVERSE_ROTATE` to `registry.on_rotate_input(e, reverse)`; `:48-50` blueprint, paste, clone to `copy`.
- `scripts/core.lua` is a stub: `registry.new_rec` needs `core.new_box`, removal needs `core.hold_items` / `core.clear_hold`, clone needs a deep copy of `rec.box`. Fake these in tests (see above); your code calls the real names.
- Direction map: `defines.direction.north/east/south/west`; variant direction name in `N.VARIANTS[name].dir`, tier in `.tier`; placer tier in `N.PLACERS[name]`.
- Measured: blueprint of placer built with `direction = defines.direction.east` turns ghost east → south (`tests/game/test_probe.lua` `probe > rotated blueprint turns placer ghost`). `LuaItemStack.create_blueprint{surface, force, area}` returns index → entity mapping; `get_blueprint_entities()` / `set_blueprint_entities()`; `build_blueprint{surface, force, position, direction}` returns ghosts; `ghost.revive{raise_revive=true}` raises `script_raised_revive` with `tags`.
- LED sprites `N.led(state, dir)` exist for states `green`, `yellow`, `red` (`data.lua:5-16`). `LuaRenderObject` fields `sprite`, `color`, `visible` are writable; `.valid`, `.destroy()`.
- Container death destroys contents in vanilla; E-5 wants spill: `surface.spill_item_stack{position=..., stack={name=..., count=..., quality=...}, enable_looted=true}`.

## Explain very simply

Player places a turnable fake box (placer); script swaps it for real box facing same way. Script turns box on R, keeps contents and wires. Mining gives items back; death drops them. Every box has an LED drawn on top. Settings travel with blueprints, paste and cloning.

## What to build

1. `copy.default_settings()` per `docs/CONTRACT.md:24-34`; `export` / `import` deep copy (import fills missing keys from defaults).
2. `registry.new_rec(entity)`: rec per `docs/CONTRACT.md:15-42` (`box = core.new_box()`, `settings = copy.default_settings()`, `enabled = true`, credits `{0, 0}`, `next_poll = 0`), stored in `storage.boxes[unit_number]`.
3. `registry.on_built(e)`: entity = `e.entity`. Placer → tier + dir from `direction`, remember position/force/quality/last_user, `destroy()` placer, `surface.create_entity{name=N.variant(tier, dir), position, force, quality}`, `new_rec`, apply `e.tags.sushi_packer` via `copy.import` when present, `led.create`. Variant (clone/revive/undo/script) without rec → same from `new_rec` on. Ignore invalid entities.
4. `registry.on_removed(e)`: rec of `e.entity`; `e.buffer` present → insert `core.hold_items(rec.box)` into it; absent → spill them; `core.clear_hold`; `led.destroy`; drop rec.
5. `registry.on_died(e)`: spill every stack of chest inventory and every hold item at entity position (E-5, D-3); `led.destroy`; drop rec.
6. `registry.swap(rec, new_dir)`: save `get_inventory(defines.inventory.chest).get_contents()`, save every circuit wire (`defines.wire_connector_id.circuit_red` / `circuit_green`: `get_wire_connector(id, false)` → `.connections` → `{target.owner, target.wire_connector_id, origin}`), `destroy()` old (no raise), create new variant same position/force/quality, re-insert contents, reconnect wires (`connect_to(target, false, origin)`), rekey `storage.boxes`, `led.destroy` old + `led.create` new then `led.set(rec, old_state, old_visible)`. Return rec.
7. `registry.on_rotate_input(e, reverse)`: `game.get_player(e.player_index).selected` is a variant with rec → `swap` to next dir in `N.DIRS` order (reverse → previous).
8. `registry.get(entity)`, `registry.on_configuration_changed(data)`: drop recs with invalid entity, `led.ensure` the rest.
9. `led.create(rec)`: `rendering.draw_sprite{sprite=N.led("green", rec.dir), target=rec.entity, surface=rec.entity.surface, render_layer="higher-object-under"}` and `rendering.draw_light{sprite="utility/light_small", target=rec.entity, surface=rec.entity.surface, color=GREEN, scale=0.3, intensity=0.5}`; `rec.led = {sprite, light, state="green", visible=true}`.
10. `led.set(rec, state, visible)`: state differs → write `sprite.sprite` and `light.color`; visible differs → write both `.visible`; nothing else written (V-6). `led.destroy`, `led.ensure` (recreate when missing/invalid, restore state + visible).
11. `copy.on_setup_blueprint(e)`: `bp = e.record or e.stack` (skip when nil / not valid / not blueprint), entities → every variant renamed to its placer with `direction = defines.direction[dir]` and `tags.sushi_packer = copy.export(rec)` (rec from `e.mapping.get()[entity_number]`), `set_blueprint_entities`.
12. `copy.on_settings_pasted(e)`: both variants with recs → destination settings = export(source).
13. `copy.on_cloned(e)`: destination variant → `new_rec`, settings = export(source rec), `box` = deep copy of source `rec.box`, `led.create`.

### Tests to write (exact names; each red against stub first)

- `lifecycle > placer becomes variant facing its direction` (E-7, D-4: all 4 directions via create_entity{raise_built=true})
- `lifecycle > built box gets rec and green led` (V-1, V-6)
- `lifecycle > build tags apply settings` (S-4)
- `lifecycle > swap keeps inventory and settings` (E-7)
- `lifecycle > swap keeps circuit wires` (E-7, N-1)
- `lifecycle > rotate input turns selected box` (E-7: set player.selected, call registry.on_rotate_input)
- `lifecycle > mining returns contents and hold to player` (E-5: player.mine_entity)
- `lifecycle > mining with full inventory spills rest` (E-5)
- `lifecycle > died box spills contents and hold` (E-5: entity.die())
- `lifecycle > led set writes only on change` (V-6)
- `lifecycle > led hidden when not visible` (Q-9)
- `lifecycle > led destroyed with box` (V-8)
- `lifecycle > ensure recreates missing led` (V-8)
- `lifecycle > blueprint stores placer with tags` (S-4, D-4)
- `lifecycle > rotated blueprint builds rotated box with settings` (S-4, D-4: build_blueprint direction + ghost.revive{raise_revive=true})
- `lifecycle > paste settings copies settings` (S-4)
- `lifecycle > clone copies settings and box state` (S-4: surface.clone_entities)
- `lifecycle > configuration changed drops invalid recs` (V-8)

## Test rule — read twice

**NEVER run `make test`, `tools/run_tests.sh <v> --full`, `lua5.2 tests/offline/run.lua <file>` without a test name, or any full, file-wide or dir-wide suite.** Run only single tests, one at a time:

```
make test-one FV=2.0 T='tests/game/test_lifecycle.lua::lifecycle > placer becomes variant facing its direction'
make test-one FV=2.1 T='tests/game/test_lifecycle.lua::lifecycle > placer becomes variant facing its direction'
```

Write each new test first and see it fail against the stub before writing code. In-game test counts only when green on both `FV=2.0` and `FV=2.1`.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/game/test_guard.lua`, `tests/game/test_probe.lua`, `tests/game/index.lua`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit on your branch. Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane003-scope", "command": "git diff --name-only lanes-base HEAD | grep -Ev '^(scripts/registry\\.lua|scripts/led\\.lua|scripts/copy\\.lua|tests/game/test_lifecycle\\.lua)$' | ( ! grep . ) && echo lane003-scope-ok", "expect_exit": 0, "expect_regex": "lane003-scope-ok", "timeout_s": 60}
{"name": "lane003-tests", "command": "( for fv in 2.0 2.1; do for t in 'placer becomes variant facing its direction' 'built box gets rec and green led' 'build tags apply settings' 'swap keeps inventory and settings' 'swap keeps circuit wires' 'rotate input turns selected box' 'mining returns contents and hold to player' 'mining with full inventory spills rest' 'died box spills contents and hold' 'led set writes only on change' 'led hidden when not visible' 'led destroyed with box' 'ensure recreates missing led' 'blueprint stores placer with tags' 'rotated blueprint builds rotated box with settings' 'paste settings copies settings' 'clone copies settings and box state' 'configuration changed drops invalid recs'; do tools/run_tests.sh $fv \"tests/game/test_lifecycle.lua::lifecycle > $t\" || exit 1; done; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' && for fv in 2.0 2.1; do tools/run_tests.sh $fv 'tests/game/test_guard.lua::guard > prototypes exist' || exit 1; done ) && echo lane003-tests-ok", "expect_exit": 0, "expect_regex": "lane003-tests-ok", "timeout_s": 3600}
```

## Files this lane owns

scripts/registry.lua, scripts/led.lua, scripts/copy.lua, tests/game/test_lifecycle.lua. Never touch anything else.

Re-cut because: none

# bound: 5400s

Reviewer ask: read `git diff lanes-base HEAD`; confirm every S-4/E-5 test checks item counts and settings values, fakes of `core` are restored in `after_each`, and no test calls a stub for real.
