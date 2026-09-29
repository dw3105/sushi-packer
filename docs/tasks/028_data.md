# 028 — data: space-age optional, owner gate, chain after top vanilla tier

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-028_data`, branch `lane/028_data`, base tag `lanes-base-v10`, merge target `int/v10`. Host `dev-vm`.

This task is complete in itself. Lane 029 (ui: `scripts/gui.lua`, `locale/`, `README.md`, `portal/`, `changelog.txt`, `tests/offline/test_gui.lua`, `tests/offline/test_locale_extra.lua`) runs in parallel; you never need its code and never touch its files. After merge, facts: GUI hides the quality picker when the game has one quality; locale exists for every prototype name of every `N.EXTRA` row. You add no locale, no GUI.

## You have about 60 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua`; every file outside "Files this lane owns" byte-identical to `lanes-base-v10`; with space-age and no belt mod, prototypes identical to `tests/offline/golden_vanilla.lua` (test `data extra > vanilla prototypes identical to v8` stays green; never regenerate the golden).

- Requirements v10 (author 2026-09-29, `docs/DECISIONS.md` V10-1..V10-5, `docs/CONTRACT.md` section `prototypes/extra.lua`):
  - T-1: `space-age` is an optional dependency. Game may run without space-age, quality, elevated-rails, recycler.
  - Q6: vanilla tier in `N.OPTIONAL_VANILLA` (`turbo`) is built only when its belt `raw["transport-belt"][N.TIER[key].belt]` AND its tech `raw.technology[N.TIER[key].tech]` (with `unit`) exist. yellow/red/blue stay `strict` (error on missing unit, as today). prev/next of built tiers skip an absent tier (no SA: yellow → red → blue).
  - `extra.top_vanilla(raw)` = last built vanilla tier: `"turbo"` with space-age, `"blue"` without.
  - Q11 (M-1): row live only if some `row.owners[i]` is loaded (`mods[name] ~= nil`, `mods` = data-stage global), belt exists and not `hidden`, splitter exists in `raw.splitter` OR `raw.item` (fixture only fakes items/recipes; accept either), tech exists, not `hidden`, has `unit`. Else skip + `log("sushi-packer: skip tier <key>: <reason>")`, never `error`.
  - Q7 (M-4): row with belt `speed` <= top vanilla belt speed is skipped (log reason) unless `row.own_role` is truthy. Sort by speed ascending, tie by `N.EXTRA` row order. First `prev` = `top_vanilla(raw)`.
  - Q6 (M-5): extra tier recipe/tech uses `N.EXTRA_RECIPE` (`stack-inserter` 2, `quantum-processor` 2, 120 s) when `raw.item["stack-inserter"]` and `raw.item["quantum-processor"]` both exist; else `N.EXTRA_RECIPE_NOSA` (`bulk-inserter` 2, `processing-unit` 5, 60 s). Tech rule U-1 unchanged (prereq scan finds unlocks of whichever items are used).
  - `extra.build(raw)`: upgrade link `next_upgrade` from `top_vanilla` variants (not hard-coded `"turbo"`) to first extra, same direction.
  - `info.json` `dependencies`: `"space-age"` → `"? space-age"`; add `"? space-exploration"`, `"? AdvancedBeltsUpdated"`; keep every other entry and order.
- `scripts/names.lua` (frozen, already at base): every `N.EXTRA` row has `owners = { ... }`; 14 rows (v9 nine + `ab-elite`, `ab-extreme`, `ab-supreme`, `ab-ultimate`, `se-deep-space`); `N.EXTRA_RECIPE_NOSA`; `N.OPTIONAL_VANILLA = { turbo = true }`. `N.TIER[key]` for extras still carries `inserter`/`circuit`/`circuits`/`craft_s` from `N.EXTRA_RECIPE`: pick the no-SA set in `tier.lua` at build time, do not edit names.
- `prototypes/tier.lua` at base already sets `se_allow_in_space = true` on containers (Q10). Keep it.
- Offline fixture `tests/offline/fake_data.lua` (frozen, at base): `F.reset()` = 2.0.77 + space-age, fake global `mods` with `space-age`. `F.reset{ sa = false }` = no space-age (turbo belt/tech, `turbo-splitter`, `stack-inserter`, `quantum-processor` removed; `mods = { base = ... }`). `F.with_mods(set)` adds the set's belts + techs + splitter items and its owner mods to `mods`; sets `nosa`, `se`, `ab` strip space-age themselves; `ab-sa` = AB with space-age. Real names: AB `elite-belt` 0.125, `extreme-belt` 0.15625, `supreme-belt` 0.1875, `ultimate-belt` 0.21875 (splitters `<x>-splitter`, techs `<x>-logistics`); SE `se-space-transport-belt` 0.09375 (no row), `se-deep-space-transport-belt-black` 0.1875, splitter `se-deep-space-splitter-black`, tech `se-deep-space-transport-belt`. UBSA `ultimate-belt` + `ultimate-logistics` have the SAME names as AB's (FND-0027): fixture set `all` has UBSA's, and the base code wrongly makes `ab-ultimate` live there.
- Existing test red at base, turns green by your owner gate: `data extra > all mods sorted by speed tie by row order` (expected list unchanged; do not edit its expectation).
- Old tests expecting `prev = "turbo"` / first ingredient `turbo-sushi-packer` stay valid: they run with space-age (`F.reset()` default).
- Offline runner: `describe`, `it`, `eq`, `ok` (`tests/offline/run.lua`); name `<describe> > <it>`. Define `_G.log` in tests to capture skip logs.

## Explain very simply

Game without Space Age has no turbo belt. So no turbo box; modded boxes chain after blue and use blue-tier parts. A modded row turns on only when its own mod is loaded, so two mods with the same belt name never mix.

## What to build

1. `prototypes/packer.lua`: build each `N.TIERS` key through `tier.make`; skip an `N.OPTIONAL_VANILLA` key whose belt or tech (with `unit`) is missing; prev/next/index over built tiers only (index keeps `N.TIERS` position so item order strings stay as today).
2. `prototypes/extra.lua`: `M.top_vanilla(raw)`; `M.tiers(raw, mods)` (`mods` defaults to global `mods` when nil); owner gate, splitter check, speed-vs-top rule, `own_role`; `M.build(raw)` uses both.
3. `prototypes/tier.lua`: recipe + tech ingredients from `N.EXTRA_RECIPE_NOSA` for extra tiers when `stack-inserter` or `quantum-processor` item is missing.
4. `info.json` dependencies as above.

### Tests to write — `tests/offline/test_data_extra.lua`, `describe("data extra", ...)`; each red at `lanes-base-v10` first, then green

- `data extra > nosa no turbo tier` — `F.reset{ sa = false }; dofile("prototypes/packer.lua")`: no `turbo-sushi-packer` item/recipe/tech/variants; blue variants `next_upgrade == nil`; no error.
- `data extra > nosa extras chain after blue` — set `ab`: tiers keys `ab-elite, ab-extreme, ab-supreme, ab-ultimate`, first `prev = "blue"`.
- `data extra > nosa extra recipe bulk inserter processing unit` — set `ab`: `ab-elite` recipe = `express-sushi-packer` 1, `elite-splitter` 1, `bulk-inserter` 2, `processing-unit` 5; energy 60.
- `data extra > sa extra recipe unchanged` — set `arig`: hyper recipe still `stack-inserter` 2, `quantum-processor` 2, 120 s.
- `data extra > owner missing row skipped` — set `arig`, then `mods["planetaris-arig"] = nil`: tiers `{}`, log names key.
- `data extra > ab-sa ub-ultimate not live` — set `ab-sa`: `ub-ultimate` not in tiers; build does not error.
- `data extra > ab-sa ab rows after turbo` — set `ab-sa`: keys `ab-extreme, ab-supreme, ab-ultimate` (`ab-elite` 0.125 = turbo speed → skipped, Q7), first `prev = "turbo"`.
- `data extra > splitter missing row skipped logged` — set `arig`, remove `raw.item["planetaris-hyper-splitter"]`: tiers `{}`, log names key.
- `data extra > speed at or below top vanilla skipped` — set `se`: `se-space-transport-belt` has no row; with `ab` + `se` style check: a row whose belt speed equals top belt speed is skipped (use `ab-sa`, `ab-elite`).
- `data extra > own_role keeps slow row` — set `ab-sa`, temporarily set `N.EXTRA[<ab-elite index>].own_role = true` (restore after): `ab-elite` live, chain `turbo → ab-elite → ...`.
- `data extra > se deep space after blue` — set `se`: tiers `{ {key="se-deep-space", prev="blue", speed=0.1875} }`.
- `data extra > container allowed in se space` — set `se`, build: every `container` of `se-deep-space` and of vanilla tiers has `se_allow_in_space == true`.
- `data extra > ab four rows speed order` — set `ab`: speeds strictly ascending 0.125, 0.15625, 0.1875, 0.21875.
- `data extra > upgrade chain from top vanilla` — set `se`: `express-sushi-packer-west.next_upgrade == "se-deep-space-sushi-packer-west"`; set `arig`: turbo west → hyper west (unchanged).
- `data extra > info lists space-age as optional` — `info.json` has `"? space-age"`, `"? space-exploration"`, `"? AdvancedBeltsUpdated"`, and no bare `"space-age"` entry.

Every existing test stays green (all of `tests/offline/test_data.lua`, `tests/offline/test_data_extra.lua`), and the red one above turns green.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make zip`, never `--full`, never a file-wide or dir-wide run, never `lua5.2 tests/offline/run.lua <file>` on a whole file. Never start Factorio, never run `tests/game/*` (`tools/run_tests.sh` refuses headless under `LANE_RUN_ID`). One test per call, milliseconds each:

```
make test-one T='tests/offline/test_data_extra.lua::data extra > nosa no turbo tier'
```

Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, `tests/offline/golden_vanilla.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/*`, `control.lua`, `data.lua`, `data-final-fixes.lua`, `settings.lua`, `locale/*`, `graphics/*`, `Makefile`, `tools/*`, `.agent-lane.toml`, any file not in "Files this lane owns". Never change an existing public signature except `extra.tiers(raw)` → `extra.tiers(raw, mods)` (contract). Never weaken, skip or delete an existing test or change an existing expectation.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane028-scope", "command": "git diff --name-only lanes-base-v10 HEAD | grep -Ev '^(prototypes/packer\\.lua|prototypes/tier\\.lua|prototypes/extra\\.lua|info\\.json|tests/offline/test_data_extra\\.lua|tests/offline/test_data\\.lua)$' | ( ! grep . ) && echo lane028-scope-ok", "expect_exit": 0, "expect_regex": "lane028-scope-ok", "timeout_s": 60}
{"name": "lane028-tests", "command": "( for t in 'data extra > vanilla prototypes identical to v8' 'data extra > no mods no extra tiers' 'data extra > arig adds hyper after turbo' 'data extra > all mods sorted by speed tie by row order' 'data extra > recipe chains previous tier' 'data extra > next_upgrade chain keeps direction' 'data extra > info lists belt mods as visible optional deps' 'data extra > nosa no turbo tier' 'data extra > nosa extras chain after blue' 'data extra > nosa extra recipe bulk inserter processing unit' 'data extra > sa extra recipe unchanged' 'data extra > owner missing row skipped' 'data extra > ab-sa ub-ultimate not live' 'data extra > ab-sa ab rows after turbo' 'data extra > splitter missing row skipped logged' 'data extra > speed at or below top vanilla skipped' 'data extra > own_role keeps slow row' 'data extra > se deep space after blue' 'data extra > container allowed in se space' 'data extra > ab four rows speed order' 'data extra > upgrade chain from top vanilla' 'data extra > info lists space-age as optional'; do tools/run_tests.sh 2.0 \"tests/offline/test_data_extra.lua::$t\" || exit 1; done; for t in 'data > chained tiers use previous box' 'data > next_upgrade chain keeps direction' 'data > tech prereqs include ingredient unlock techs'; do tools/run_tests.sh 2.0 \"tests/offline/test_data.lua::$t\" || exit 1; done; tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane028-tests-ok", "expect_exit": 0, "expect_regex": "lane028-tests-ok", "timeout_s": 300}
```

## Files this lane owns

prototypes/packer.lua, prototypes/tier.lua, prototypes/extra.lua, info.json (dependencies only), tests/offline/test_data_extra.lua, tests/offline/test_data.lua (add tests only). Never touch anything else.

Re-cut because: none

# bound: 3600s
