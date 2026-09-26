# 002 — tiers and data: all four tiers, recipes, techs, locale

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-002_tiers_and_data`, branch `lane/002_tiers_and_data`, base tag `lanes-base`, merge target `int/v1`. Host `legalcopilot-dev`.

This task is complete in itself. Other modules are built by other lanes against the same frozen contract; you never need them.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every name in `scripts/names.lua`; yellow prototypes stay as S0 built them except fields this task names; every file outside "Files this lane owns" byte-identical to `lanes-base`.

- Contract: `docs/CONTRACT.md` (module rules `:5-11`, storage layout `:15-42`, measured game facts `:46-54`, this lane's module section cited below). Requirements `docs/REQUIREMENTS.md`, decisions `docs/DECISIONS.md`.
- Modules owned by other lanes are S0 stubs (`scripts/<module>.lua`): pure functions `error("stub: ...")`, event handlers no-op. Never call a stub for real. In tests, fake the other side: save the original function in `before_each`, replace it on the shared module table (`local core = require("scripts.core"); core.new_box = function() return {} end`), restore in `after_each`. Or build `rec` by hand per `docs/CONTRACT.md:15-42` and put it in `storage.boxes[entity.unit_number]`.
- `scripts/names.lua`: every prototype name (`N.variant(tier, dir)`, `N.placer(tier)`, `N.item(tier)`, `N.led(state, dir)`), `N.DIRS`, `N.TIERS`, `N.TIER[tier].lane_rate`.
- S0 data stage builds tier `yellow` only (`prototypes/packer.lua:6`); build yellow boxes in tests.
- In-game tests: FactorioTest with luassert. Globals `describe`, `it`, `test`, `before_each`, `after_each`, `after_ticks(n, fn)` (test waits), `assert.are_equal(expected, found)`, `assert.is_true`, `assert.is_nil`, `assert.is_not_nil`. Examples: `tests/game/test_probe.lua` (belts, `after_ticks`, blueprint, player). Surface `game.surfaces[1]`, force `game.forces.player`, player `game.players[1]` (one, with character). Clear your area in `before_each` (see `tests/game/test_probe.lua:4-8`).
- Test full name = `<describe> > <it>`. Runner: `tools/run_tests.sh <2.0|2.1> '<file>::<describe> > <it>'` fails unless exactly that one test ran and passed. One in-game test takes 10-26 s wall.
- Factorio headless `~/factorio-2.0/factorio` (2.0.77) and `~/factorio-2.1/factorio` (2.1.20). Only API present in both. Docs https://lua-api.factorio.com/2.0.72/ (no network in lane; use local `~/factorio-2.0/factorio/data` Lua sources and `doc-html` if present for reference).
- `prototypes/packer.lua:6` `BUILT_TIERS = { "yellow" }`; `:23` `make_tier(tier)` builds item, recipe, tech, placer, 4 variants, remnant. Tech at `:50-57`: prerequisites `{ T.tech, "steel-processing" }`, hand-set `unit`.
- `scripts/names.lua:12-17` `N.TIER`: belt item, belt tech, circuit per tier. Belt techs exist on both versions and all four carry `unit` (checked in `~/factorio-2.0/factorio/data/base/prototypes/technology.lua` `logistics`, `logistics-2`, `logistics-3`; `space-age/prototypes/technology.lua:755` `turbo-transport-belt`).
- `locale/en/locale.cfg` holds yellow names only (`[item-name]`, `[entity-name]`, `[technology-name]`, `[mod-setting-name]`, `[controls]`).
- Graphics for all tiers present: `graphics/entity/sushi-packer/<tier>/`, `graphics/icons/sushi-packer-<tier>.png`. Missing file = load error, so a green load proves paths.
- Runtime prototype API: `prototypes.entity[name]` (`.type`, `.flags`, `.get_inventory_size(defines.inventory.chest)`, `.mineable_properties.products`), `prototypes.item[name].place_result`, `prototypes.recipe[name].ingredients`, `prototypes.technology[name].prerequisites` / `.effects` / `.research_unit_count` / `.research_unit_ingredients`, `settings.global[N.SETTING_TIMEOUT].value`. Locale keys are checked by a shell check in "What done mean", not by an in-game test.

## Explain very simply

Box comes in four colours, one per belt tier. Each colour needs its item, recipe, research, 4 facing variants, a placer, and wreck. S0 made yellow only; make all four from one generator.

## What to build

1. `BUILT_TIERS` = all of `N.TIERS` (keep generator shape).
2. Tech per tier: `prerequisites` = `{ T.tech }` plus `"steel-processing"` for yellow, plus previous tier's packer tech for red, blue, turbo (`N.tech("yellow")` for red, etc.). `unit` = deep copy of `data.raw.technology[T.tech].unit` (error at data stage if nil). `icon` tier icon.
3. Recipe per tier as now (Q-1): 1 `steel-chest`, 4 `T.belt`, 5 `T.circuit`.
4. Remnant, placer, variants for every tier (same fields as yellow).
5. `locale/en/locale.cfg`: `[item-name]`, `[entity-name]` (placer, 4 variants, remnants), `[technology-name]` for every tier; keep existing `[mod-setting-name]` and `[controls]` lines.

### Tests to write (exact names; each red against stub first)

- `data > every tier has item placer variants and remnant` (E-4, E-7, G-9)
- `data > variants are 48 slot not rotatable containers` (E-2, E-7)
- `data > variants and placer mine to tier item` (E-5)
- `data > placer is item place result` (D-4)
- `data > recipe is steel chest belt and circuits` (U-2, Q-1)
- `data > tech requires matching belt tech` (U-1)
- `data > tech unlocks its recipe` (U-1)
- `data > tech cost copies matching belt tech` (U-1)
- `data > timeout setting defaults to off` (S-2, D-2)

## Test rule — read twice

**NEVER run `make test`, `tools/run_tests.sh <v> --full`, `lua5.2 tests/offline/run.lua <file>` without a test name, or any full, file-wide or dir-wide suite.** Run only single tests, one at a time:

```
make test-one FV=2.0 T='tests/game/test_data.lua::data > every tier has item placer variants and remnant'
make test-one FV=2.1 T='tests/game/test_data.lua::data > every tier has item placer variants and remnant'
```

Write each new test first and see it fail against the stub before writing code. In-game test counts only when green on both `FV=2.0` and `FV=2.1`.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/game/test_guard.lua`, `tests/game/test_probe.lua`, `tests/game/index.lua`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit on your branch. Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane002-scope", "command": "git diff --name-only lanes-base HEAD | grep -Ev '^(prototypes/packer\\.lua|locale/en/locale\\.cfg|tests/game/test_data\\.lua)$' | ( ! grep . ) && echo lane002-scope-ok", "expect_exit": 0, "expect_regex": "lane002-scope-ok", "timeout_s": 60}
{"name": "lane002-tests", "command": "( for fv in 2.0 2.1; do for t in 'every tier has item placer variants and remnant' 'variants are 48 slot not rotatable containers' 'variants and placer mine to tier item' 'placer is item place result' 'recipe is steel chest belt and circuits' 'tech requires matching belt tech' 'tech unlocks its recipe' 'tech cost copies matching belt tech' 'timeout setting defaults to off'; do tools/run_tests.sh $fv \"tests/game/test_data.lua::data > $t\" || exit 1; done; done && tools/load_check.sh 2.0 && tools/load_check.sh 2.1 && for t in yellow red blue turbo; do for k in sushi-packer-$t sushi-packer-$t-placer sushi-packer-$t-north sushi-packer-$t-east sushi-packer-$t-south sushi-packer-$t-west sushi-packer-$t-remnants; do grep -q \"^$k=\" locale/en/locale.cfg || { echo missing locale $k; exit 1; }; done; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' && for fv in 2.0 2.1; do tools/run_tests.sh $fv 'tests/game/test_guard.lua::guard > prototypes exist' || exit 1; done ) && echo lane002-tests-ok", "expect_exit": 0, "expect_regex": "lane002-tests-ok", "timeout_s": 2400}
```

## Files this lane owns

prototypes/packer.lua, locale/en/locale.cfg, tests/game/test_data.lua. Never touch anything else.

Re-cut because: none

# bound: 2700s

Reviewer ask: read `git diff lanes-base HEAD`; confirm each test loops over all four tiers (not yellow only) and asserts exact names/amounts from `scripts/names.lua`.
