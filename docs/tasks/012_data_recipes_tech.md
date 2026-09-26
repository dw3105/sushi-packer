# 012 — data: chained recipes, tech rule, weight (U-1, U-2, U-4)

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-012_data_recipes_tech`, branch `lane/012_data_recipes_tech`, base tag `lanes-base-1.1`, merge target `int/v1.1`. Host `legalcopilot-dev`.

This task is complete in itself. Lanes 013 and 014 run in parallel on other files; you never need them.

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** `next_upgrade` lines in `prototypes/packer.lua` (integrator S1, U-3); placer, variants, remnant, graphics, `fast_replaceable_group`, `placeable_by`, `inventory_size`; every file outside "Files this lane owns" byte-identical to `lanes-base-1.1`.

- Contract: `docs/REQUIREMENTS.md` §10 U-1, U-2, U-4 (v5, author 2026-09-26). Names: `scripts/names.lua` `N.TIER[tier]` has `belt`, `tech`, `splitter`, `inserter`, `circuit`, `circuits`, `craft_s`; `N.RECIPE_BASE = "steel-chest"`, `N.TECH_COST_FACTOR = 1.5`, `N.ITEM_WEIGHT = 20000`; `N.item(tier)`, `N.tech(tier)`, `N.variant(tier, dir)`.
- `prototypes/packer.lua:37-48` recipe today: flat `steel-chest` + 4 belt + 5 circuit, `energy_required = 1`. `:50-71` tech today: prereqs belt tech + previous tier (yellow: `steel-processing`), `unit = table.deepcopy(belt_tech.unit)`.
- Real game facts (FND-0007, both 2.0.77 and 2.1.20): every ingredient recipe starts disabled and is unlocked by one tech's `effects` (`{type = "unlock-recipe", recipe = ...}`). `electronics` (unlocks `inserter`, `electronic-circuit`) has `research_trigger` and NO `unit`.
- Offline fixture `tests/offline/fake_data.lua`: `F.reset()` installs global `data` (`data.raw`, `data:extend`), `table.deepcopy`, `circuit_connector_definitions`, `default_circuit_wire_max_distance` with real tech values; then `dofile("prototypes/packer.lua")`; read `F.raw.recipe[...]`, `F.raw.technology[...]`, `F.raw.item[...]`, `F.raw.container[...]`. Call `F.reset()` at start of every test.
- Offline runner: `describe`, `it`, `eq(found, expected, msg)` deep compare, `ok(cond, msg)` (`tests/offline/run.lua`); full name `<describe> > <it>`.

## Explain very simply

Box recipes now chain: each tier eats previous box plus its splitter, inserters, circuits. Tech needs every tech that unlocks an ingredient, so player never gets recipe they cannot craft. Tech costs 1.5 × belt tech. Item weighs 20 kg.

## What to build

1. Recipe per tier: `ingredients` in this order: base (yellow `N.RECIPE_BASE`, else `N.item(previous tier)`) ×1, `T.splitter` ×1, `T.inserter` ×2, `T.circuit` ×`T.circuits`. `energy_required = T.craft_s`. `enabled = false`. No `category` (default `crafting`).
2. Tech per tier: `prerequisites` in this order, no duplicates: `T.tech`, `N.tech(previous tier)` (not yellow), then for each ingredient in recipe order every tech in `data.raw.technology` (iterate names sorted) whose `effects` has `unlock-recipe` of that ingredient name, skipping the tier's own tech. `unit.count = belt_tech.unit.count * N.TECH_COST_FACTOR`, `unit.time = belt_tech.unit.time`, `unit.ingredients` = union of `{pack, 1}` over direct prerequisites that have a `unit` (order = first appearance walking prerequisites in order, then each tech's ingredients in order). Tech without `unit` adds nothing.
3. Item: `weight = N.ITEM_WEIGHT`. No `surface_conditions` anywhere.

### Tests to write (exact names; each red against current code first)

`tests/offline/test_data.lua` (new), `describe("data", ...)`:
- `data > yellow recipe matches table` — `{steel-chest 1, splitter 1, inserter 2, electronic-circuit 5}`, 30 s
- `data > chained tiers use previous box` — red/blue/turbo first ingredient = previous box ×1; turbo `quantum-processor` ×2, `stack-inserter` ×2
- `data > craft times 30 45 60 120`
- `data > recipes disabled until research`
- `data > tech prereqs include ingredient unlock techs` — exact lists: yellow `{"logistics","steel-processing","electronics"}`; red `{"logistics-2","sushi-packer-yellow","fast-inserter","advanced-circuit"}`; blue `{"logistics-3","sushi-packer-red","bulk-inserter","processing-unit"}`; turbo `{"turbo-transport-belt","sushi-packer-blue","stack-inserter","quantum-processor"}`
- `data > tech count is belt count x 1.5` — 30, 300, 450, 750; time 15, 30, 15, 60
- `data > tech ingredients are union over prereqs` — yellow `{automation}`; red `{automation, logistic}`; blue adds chemical, production; turbo 10 packs incl. `cryogenic-science-pack`, `agricultural-science-pack`, `electromagnetic-science-pack`
- `data > tech unlocks its recipe`
- `data > next_upgrade chain keeps direction` — yellow-east → red-east, blue-west → turbo-west, turbo none
- `data > item weight 20 kg`
- `data > no surface conditions`

## Test rule — read twice

**Lanes run offline Lua tests only (SP-02 v0.2).** Never start Factorio, never run `tests/game/*`, never `make test`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_data.lua::data > yellow recipe matches table'
```

Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/*`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `locale/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane012-scope", "command": "git diff --name-only lanes-base-1.1 HEAD | grep -Ev '^(prototypes/packer\\.lua|tests/offline/test_data\\.lua)$' | ( ! grep . ) && echo lane012-scope-ok", "expect_exit": 0, "expect_regex": "lane012-scope-ok", "timeout_s": 60}
{"name": "lane012-tests", "command": "( for t in 'yellow recipe matches table' 'chained tiers use previous box' 'craft times 30 45 60 120' 'recipes disabled until research' 'tech prereqs include ingredient unlock techs' 'tech count is belt count x 1.5' 'tech ingredients are union over prereqs' 'tech unlocks its recipe' 'next_upgrade chain keeps direction' 'item weight 20 kg' 'no surface conditions'; do tools/run_tests.sh 2.0 \"tests/offline/test_data.lua::data > $t\" || exit 1; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane012-tests-ok", "expect_exit": 0, "expect_regex": "lane012-tests-ok", "timeout_s": 300}
```

## Files this lane owns

prototypes/packer.lua, tests/offline/test_data.lua. Never touch anything else.

Re-cut because: none

# bound: 1800s
