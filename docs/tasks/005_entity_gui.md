# 005 — entity GUI (gui)

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-005_entity_gui`, branch `lane/005_entity_gui`, base tag `lanes-base`, merge target `int/v1`. Host `dev-vm`.

This task is complete in itself. Other modules are built by other lanes against the same frozen contract; you never need them.

## You have about 45 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** signatures of `gui` in `tests/offline/contract.lua`; settings layout `docs/CONTRACT.md:24-34`; every file outside "Files this lane owns" byte-identical to `lanes-base`.

- Contract: `docs/CONTRACT.md` (module rules `:5-11`, storage layout `:15-42`, measured game facts `:46-54`, this lane's module section cited below). Requirements `docs/REQUIREMENTS.md`, decisions `docs/DECISIONS.md`.
- Modules owned by other lanes are S0 stubs (`scripts/<module>.lua`): pure functions `error("stub: ...")`, event handlers no-op. Never call a stub for real. In tests, fake the other side: save the original function in `before_each`, replace it on the shared module table (`local core = require("scripts.core"); core.new_box = function() return {} end`), restore in `after_each`. Or build `rec` by hand per `docs/CONTRACT.md:15-42` and put it in `storage.boxes[entity.unit_number]`.
- `scripts/names.lua`: every prototype name (`N.variant(tier, dir)`, `N.placer(tier)`, `N.item(tier)`, `N.led(state, dir)`), `N.DIRS`, `N.TIERS`, `N.TIER[tier].lane_rate`.
- S0 data stage builds tier `yellow` only (`prototypes/packer.lua:6`); build yellow boxes in tests.
- In-game tests: FactorioTest with luassert. Globals `describe`, `it`, `test`, `before_each`, `after_each`, `after_ticks(n, fn)` (test waits), `assert.are_equal(expected, found)`, `assert.is_true`, `assert.is_nil`, `assert.is_not_nil`. Examples: `tests/game/test_probe.lua` (belts, `after_ticks`, blueprint, player). Surface `game.surfaces[1]`, force `game.forces.player`, player `game.players[1]` (one, with character). Clear your area in `before_each` (see `tests/game/test_probe.lua:4-8`).
- Test full name = `<describe> > <it>`. Runner: `tools/run_tests.sh <2.0|2.1> '<file>::<describe> > <it>'` fails unless exactly that one test ran and passed. One in-game test takes 10-26 s wall.
- Factorio headless `~/factorio-2.0/factorio` (2.0.77) and `~/factorio-2.1/factorio` (2.1.20). Only API present in both. Docs https://lua-api.factorio.com/2.0.72/ (no network in lane; use local `~/factorio-2.0/factorio/data` Lua sources and `doc-html` if present for reference).
- This lane's contract: `docs/CONTRACT.md:121-127`; settings layout `docs/CONTRACT.md:24-34`. Settings live in `storage.boxes[unit_number].settings`; read and write them there directly (`registry` and `copy` are stubs in this worktree — never call them). Tests build rec by hand with settings table inline per layout.
- `control.lua:52-60` routes `on_gui_opened`, `on_gui_closed` and click / elem_changed / text_changed / checked_state_changed / selection_state_changed / value_changed / switch_state_changed / confirmed to `gui`.
- Test world has one player `game.players[1]` with character (`docs/CONTRACT.md:53`). `player.opened = entity` opens the entity GUI; tests may also call `gui.on_opened{player_index=1, entity=box, gui_type=defines.gui_type.entity}` directly. Element events in tests: set element state, then call `gui.on_event{player_index=1, element=el, name=defines.events.<event>}`.
- Relative GUI: `player.gui.relative.add{type="frame", name=..., anchor={gui=defines.relative_gui_type.container_gui, position=defines.relative_gui_position.right, names=<all variant names>}}`. Elements carry `tags` (plain table) to route events. `choose-elem-button` `elem_type = "item-with-quality"` gives `{name, quality}`; `elem_type = "item"` gives name; `elem_type = "signal"` gives SignalID.
- Locale: this lane owns new file `locale/en/gui.cfg` (Factorio loads every `.cfg` in `locale/en/`); never edit `locale/en/locale.cfg`.

## Explain very simply

Opening a box shows a side panel. Panel sets: timeout (use map default, or own seconds), filter list (items that skip storage, with or without quality), circuit enable condition, and flush signal. Every change is saved into the box settings right away.

## What to build

1. `gui.on_opened(e)`: `e.entity` is a variant with rec → build frame (name `sushi_packer_frame`) with: timeout mode switch or radio (global / custom) + numeric textfield seconds; 10 filter rows, each `choose-elem-button` (`item-with-quality`) + checkbox "any quality"; circuit: checkbox enable, `choose-elem-button` signal, dropdown comparator (`>`, `<`, `=`, `≥`, `≤`, `≠`), numeric textfield constant; flush: checkbox + signal button. Every element tagged `{sushi_packer = unit_number, field = "..."}`. Fill from current settings.
2. `gui.on_closed(e)`: destroy frame when present.
3. `gui.on_event(e)`: element without our tag → return. Else write field into `storage.boxes[unit].settings`: `timeout_mode`, `timeout_s` (non-negative integer ≤ 3600; other text ignored), `filters` (rebuilt from rows: `{name, quality}` or `{name, quality=nil}` when "any quality"; empty rows dropped), `circuit.enable`, `circuit.cond.first_signal`, `circuit.cond.comparator`, `circuit.cond.constant`, `circuit.flush`, `circuit.flush_signal`.

### Tests to write (exact names; each red against stub first)

- `gui > opening box shows frame` (S-2, S-3)
- `gui > closing removes frame`
- `gui > frame reflects current settings` (S-2)
- `gui > custom timeout written to settings` (S-1, S-2)
- `gui > global timeout mode written` (S-2)
- `gui > bad timeout text ignored` (S-2)
- `gui > filter item any quality written` (S-3, P-1)
- `gui > filter item with quality written` (P-1)
- `gui > clearing filter removes entry` (S-3)
- `gui > circuit condition written` (N-3)
- `gui > flush signal written` (N-4)
- `gui > foreign gui events ignored`

## Test rule — read twice

**NEVER run `make test`, `tools/run_tests.sh <v> --full`, `lua5.2 tests/offline/run.lua <file>` without a test name, or any full, file-wide or dir-wide suite.** Run only single tests, one at a time:

```
make test-one FV=2.0 T='tests/game/test_gui.lua::gui > opening box shows frame'
make test-one FV=2.1 T='tests/game/test_gui.lua::gui > opening box shows frame'
```

Write each new test first and see it fail against the stub before writing code. In-game test counts only when green on both `FV=2.0` and `FV=2.1`.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/game/test_guard.lua`, `tests/game/test_probe.lua`, `tests/game/index.lua`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit on your branch. Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane005-scope", "command": "git diff --name-only lanes-base HEAD | grep -Ev '^(scripts/gui\\.lua|locale/en/gui\\.cfg|tests/game/test_gui\\.lua)$' | ( ! grep . ) && echo lane005-scope-ok", "expect_exit": 0, "expect_regex": "lane005-scope-ok", "timeout_s": 60}
{"name": "lane005-tests", "command": "( for fv in 2.0 2.1; do for t in 'opening box shows frame' 'closing removes frame' 'frame reflects current settings' 'custom timeout written to settings' 'global timeout mode written' 'bad timeout text ignored' 'filter item any quality written' 'filter item with quality written' 'clearing filter removes entry' 'circuit condition written' 'flush signal written' 'foreign gui events ignored'; do tools/run_tests.sh $fv \"tests/game/test_gui.lua::gui > $t\" || exit 1; done; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' && for fv in 2.0 2.1; do tools/run_tests.sh $fv 'tests/game/test_guard.lua::guard > prototypes exist' || exit 1; done ) && echo lane005-tests-ok", "expect_exit": 0, "expect_regex": "lane005-tests-ok", "timeout_s": 3000}
```

## Files this lane owns

scripts/gui.lua, locale/en/gui.cfg, tests/game/test_gui.lua. Never touch anything else.

Re-cut because: none

# bound: 3600s

Reviewer ask: read `git diff lanes-base HEAD`; confirm each write test reads the value back from `storage.boxes[...].settings`, and the frame builds for every variant name.
