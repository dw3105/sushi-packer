# 024 — data: modded belt tiers built at data stage

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-024_data`, branch `lane/024_data`, base tag `lanes-base-v9`, merge target `int/v9`. Host `dev-vm`.

This task is complete in itself. Lane 025 (rate: `scripts/belt_io.lua`, `scripts/tick.lua`) and lane 027 (text: `locale/`, `README.md`, `portal/`, `changelog.txt`) run in parallel; you never need their code and never touch their files. After merge, facts: box speed per tier = its belt's live speed (025); every prototype you create gets locale from 027 by name (`N.item(key)`, `N.placer(key)`, `N.variant(key, dir)`, `N.remnant(key)`, `N.tech(key)`, recipe = `N.item(key)`), so you add no locale.

## You have about 60 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua`; every file outside "Files this lane owns" byte-identical to `lanes-base-v9`; vanilla prototypes (no belt mod) identical to base, field for field.

- Requirements v9 §17 (`docs/REQUIREMENTS.md`, author 2026-09-28):
  - M-1: extra tier per `N.EXTRA` row; exists only if `raw["transport-belt"][row.belt]` exists and is not `hidden`, and `raw.technology[row.tech]` exists, is not `hidden`, and has `unit`. Else skip + `log("sushi-packer: skip tier <key>: <reason>")`, never `error`.
  - M-2: no belt mod → exactly the 4 vanilla tiers, unchanged.
  - M-3: extra tiers built in `data-final-fixes.lua` (already: `require("prototypes.extra").build(data.raw)`).
  - M-4: order + upgrade chain = belt `speed` ascending after turbo; equal speed → `N.EXTRA` row order. Own chain; never read belt `next_upgrade`.
  - M-5: recipe = previous tier box 1 (`turbo-sushi-packer` for first extra), own splitter 1 (`N.TIER[key].splitter`), `stack-inserter` 2, `quantum-processor` 2, 120 s (`N.EXTRA_RECIPE`; already in `N.TIER[key]`: `inserter`, `circuit`, `circuits`, `craft_s`). Tech per U-1: prereqs = own belt tech + previous tier tech + every tech that unlocks an ingredient recipe; count = ceil(belt tech count × 1.5); time = belt tech time; packs = union over direct prereqs.
- `scripts/names.lua` (frozen): `N.EXTRA` rows in order: `planetaris-hyper` (75/s), `bob-ultimate` (75/s), `kr-superior` (90/s), `ub-ultra-fast` (90/s), `bb-ultra` (96/s), `ub-extreme-fast` (135/s), `ub-ultra-express` (180/s), `ub-extreme-express` (225/s), `ub-ultimate` (270/s). `N.TIER[key]` = `{belt, tech, splitter, inserter, circuit, circuits, craft_s, extra = row}`. `N.ALL` = vanilla 4 ++ extra keys. `N.PREFIX[key] = key .. "-"`, so `N.item("kr-superior") == "kr-superior-sushi-packer"`.
- Real prototype names verified in game (FND-0023): e.g. `kr-superior-transport-belt` speed 0.1875, splitter `kr-superior-splitter`, tech `kr-logistic-5` unit 2000; `kr-advanced-transport-belt` exists but `hidden = true`; Arig `disable-hyper-belts` setting hides hyper belt + tech.
- `prototypes/packer.lua` at base: local `make_tier(tier)` builds item, recipe, tech, placer, 4 container variants, remnant for vanilla `N.TIERS`; previous/next tier found by position in `N.TIERS`; `error()` when belt tech has no unit; item `order = "a[sushi-packer]-" .. string.char(96 + index)`; graphics path `graphics/entity/sushi-packer/<tier>/sushi-packer-<tier>-<dir>.png`, icon `graphics/icons/sushi-packer-<tier>.png` (tier = key, so extras use `<key>` folders; graphics come later from integrator).
- `prototypes/extra.lua` at base: stubs `M.tiers(raw) return {} end`, `M.build(raw) end`. Contract (`docs/CONTRACT.md`): `extra.tiers(raw) -> { {key=, prev=, speed=}, ... }` ordered; `extra.build(raw)`.
- Offline fixture `tests/offline/fake_data.lua`: `F.reset()` fakes `data`, `data.raw` (vanilla techs, recipes, items, 4 vanilla belts in `raw["transport-belt"]`, globals `circuit_connector_definitions`, `default_circuit_wire_max_distance`, `table.deepcopy`); `F.with_mods(set)` adds real mod rows, sets `vanilla`, `arig`, `hyarion`, `arig-off`, `k2so`, `arig-k2so`, `bob`, `ubsa`, `bb`, `all`. `F.extended` = list of prototypes passed to `data:extend`. Pattern: `tests/offline/test_data.lua` (`F.reset(); dofile("prototypes/packer.lua")`).
- `info.json` `dependencies` today: `["base >= 2.0.0", "space-age", "? factorio-test"]`.
- Offline runner: `describe`, `it`, `eq`, `ok` (`tests/offline/run.lua`); test name `<describe> > <it>`. Define `_G.log = function(s) ... end` in tests to capture skip logs.

## Explain very simply

When a belt mod is installed, we make a new box tier for its belt, chained after turbo in belt-speed order, with its own recipe and research. No mod → nothing changes.

## What to build

1. FIRST commit: `tests/offline/golden_vanilla.lua` = deterministic dump (sorted keys, all fields) of `F.extended` after `F.reset(); dofile("prototypes/packer.lua")` at base, plus test `data extra > vanilla prototypes identical to v8` comparing current output to it. Green at base. Never regenerate it later.
2. New `prototypes/tier.lua` (no side effects): `M.make(tier, opts)` → list of prototypes, same fields as base `make_tier`; `opts = { prev = key|nil, next = key|nil, index = n }` (prev nil → `N.RECIPE_BASE` + `steel-processing` prereq, as base). Raises `error` for missing unit only when `opts.strict` (vanilla keeps base behaviour).
3. `prototypes/packer.lua`: build vanilla 4 through `tier.make` with same prev/next/index as base. Golden test stays green.
4. `prototypes/extra.lua`: `M.tiers(raw)` per M-1 + M-4 (`prev` = previous entry key, first = `"turbo"`, `speed` = belt speed). `M.build(raw)`: `data:extend(tier.make(key, {prev, next, index = 4 + position}))` for each; set `raw.container[N.variant("turbo", dir)].next_upgrade = N.variant(first, dir)` for each dir when any extra.
5. `info.json`: add hidden optional deps (load order): `"(?) planetaris-arig"`, `"(?) Krastorio2"`, `"(?) Krastorio2-spaced-out"`, `"(?) boblogistics >= 2.1.0"`, `"(?) UltimateBeltsSpaceAge"`, `"(?) BetterBelts"`.

### Tests to write — new file `tests/offline/test_data_extra.lua`, `describe("data extra", ...)`; each (except golden) red against `lanes-base-v9` first

- `data extra > vanilla prototypes identical to v8` (golden, step 1)
- `data extra > no mods no extra tiers` — vanilla: `tiers == {}`, build extends nothing, turbo variants `next_upgrade == nil`.
- `data extra > arig adds hyper after turbo` — tiers `{ {key="planetaris-hyper", prev="turbo", speed=0.15625} }`.
- `data extra > hidden belt skipped` — `arig-off` → `{}`, and log called with key.
- `data extra > k2so hidden advanced belt ignored` — only `kr-superior`.
- `data extra > arig k2so chain turbo hyper superior` — keys + prevs.
- `data extra > all mods sorted by speed tie by row order` — keys: planetaris-hyper, bob-ultimate, kr-superior, ub-ultra-fast, bb-ultra, ub-extreme-fast, ub-ultra-express, ub-extreme-express, ub-ultimate.
- `data extra > belt tech without unit skipped` — `arig`, set tech `unit = nil`, `research_trigger = {...}` → `{}`, no error, log called.
- `data extra > missing tech skipped` — `arig`, remove tech → `{}`.
- `data extra > recipe chains previous tier` — `arig-k2so`: superior recipe ingredients = `planetaris-hyper-sushi-packer` 1, `kr-superior-splitter` 1, `stack-inserter` 2, `quantum-processor` 2; energy 120; hyper's first ingredient `turbo-sushi-packer`.
- `data extra > tech prereqs belt tech previous tier and ingredient unlocks` — superior tech prereqs include `kr-logistic-5`, `planetaris-hyper-sushi-packer`, `stack-inserter`, `quantum-processor`.
- `data extra > tech cost belt count x 1.5 and pack union` — superior count 3000, time 60, packs ⊇ belt tech packs.
- `data extra > next_upgrade chain keeps direction` — `arig-k2so`: turbo-west → hyper-west → superior-west → nil.
- `data extra > item order after turbo in chain order` — orders strictly increase yellow..turbo..hyper..superior.
- `data extra > extra graphics paths use tier key` — hyper north variant picture layer filename contains `graphics/entity/sushi-packer/planetaris-hyper/sushi-packer-planetaris-hyper-north.png`; icon `graphics/icons/sushi-packer-planetaris-hyper.png`.
- `data extra > info lists belt mods as hidden optional deps` — all 6 entries in `info.json`.

Every existing test stays green unchanged (notably all `tests/offline/test_data.lua`).

## Test rule — read twice

**Lanes run offline Lua tests only.** Never start Factorio, never run `tests/game/*`, never `make test`, never `make test-modsets`, never `make zip`, never `make load-check`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_data_extra.lua::data extra > arig adds hyper after turbo'
```

Game never needed: `tests/offline/fake_data.lua` fakes the data stage. Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, any existing `tests/offline/test_*.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/*`, `control.lua`, `data.lua`, `data-final-fixes.lua`, `settings.lua`, `locale/*`, `graphics/*`, `Makefile`, `tools/*`, `.agent-lane.toml`, any file not in "Files this lane owns". Never change an existing function signature. Never weaken, skip or delete an existing test. Never add dependencies beyond the 6 optional ones above.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane024-scope", "command": "git diff --name-only lanes-base-v9 HEAD | grep -Ev '^(prototypes/packer\\.lua|prototypes/tier\\.lua|prototypes/extra\\.lua|info\\.json|tests/offline/test_data_extra\\.lua|tests/offline/golden_vanilla\\.lua)$' | ( ! grep . ) && echo lane024-scope-ok", "expect_exit": 0, "expect_regex": "lane024-scope-ok", "timeout_s": 60}
{"name": "lane024-tests", "command": "( for t in 'tests/offline/test_data_extra.lua::data extra > vanilla prototypes identical to v8' 'tests/offline/test_data_extra.lua::data extra > no mods no extra tiers' 'tests/offline/test_data_extra.lua::data extra > arig adds hyper after turbo' 'tests/offline/test_data_extra.lua::data extra > hidden belt skipped' 'tests/offline/test_data_extra.lua::data extra > k2so hidden advanced belt ignored' 'tests/offline/test_data_extra.lua::data extra > arig k2so chain turbo hyper superior' 'tests/offline/test_data_extra.lua::data extra > all mods sorted by speed tie by row order' 'tests/offline/test_data_extra.lua::data extra > belt tech without unit skipped' 'tests/offline/test_data_extra.lua::data extra > missing tech skipped' 'tests/offline/test_data_extra.lua::data extra > recipe chains previous tier' 'tests/offline/test_data_extra.lua::data extra > tech prereqs belt tech previous tier and ingredient unlocks' 'tests/offline/test_data_extra.lua::data extra > tech cost belt count x 1.5 and pack union' 'tests/offline/test_data_extra.lua::data extra > next_upgrade chain keeps direction' 'tests/offline/test_data_extra.lua::data extra > item order after turbo in chain order' 'tests/offline/test_data_extra.lua::data extra > extra graphics paths use tier key' 'tests/offline/test_data_extra.lua::data extra > info lists belt mods as hidden optional deps' 'tests/offline/test_data.lua::data > chained tiers use previous box' 'tests/offline/test_data.lua::data > next_upgrade chain keeps direction' 'tests/offline/test_data.lua::data > tech prereqs include ingredient unlock techs' 'tests/offline/test_guard.lua::guard > names frozen'; do tools/run_tests.sh 2.0 \"$t\" || exit 1; done ) && echo lane024-tests-ok", "expect_exit": 0, "expect_regex": "lane024-tests-ok", "timeout_s": 300}
```

## Files this lane owns

prototypes/packer.lua, prototypes/tier.lua (new), prototypes/extra.lua, info.json (dependencies only), tests/offline/test_data_extra.lua (new), tests/offline/golden_vanilla.lua (new). Never touch anything else.

Re-cut because: none

# bound: 3600s
