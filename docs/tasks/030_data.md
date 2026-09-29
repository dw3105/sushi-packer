# 030 — data: SE space root tier, chains by `after`, root recipe

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-030_data`, branch `lane/030_data`, base tag `lanes-base-v11`, merge target `int/v11`. Host `dev-vm`.

This task is complete in itself. Lane 031 (locale: `locale/`, `tests/offline/test_locale_extra.lua`, `tests/offline/test_locale_de.lua`) runs in parallel; you never need its code and never touch its files. After merge, facts: locale `en` + `de` exist for every prototype name of every `N.EXTRA` row, `se-space` included. You add no locale.

## You have about 60 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua`; every file outside "Files this lane owns" byte-identical to `lanes-base-v11`; with space-age and no belt mod, prototypes identical to `tests/offline/golden_vanilla.lua` (test `data extra > vanilla prototypes identical to v8` stays green; never regenerate the golden).

- Requirements v11 (author 2026-09-29, `docs/REQUIREMENTS.md` M-4, M-5, U-1, U-3; `docs/DECISIONS.md` V11-1..V11-3; `docs/CONTRACT.md` section `prototypes/extra.lua`):
  - M-4: row with `after = <key>` → its `prev` is `<key>`, NOT the speed-chain previous. If `<key>` is not among active tiers → row skipped, `log("sushi-packer: skip tier <key>: previous tier <after> not active")`, never `error`.
  - M-4: row with `own_role` truthy and no `after` = **root tier**: `prev = nil` (field absent in the returned table). It is kept even when its belt speed <= top vanilla belt speed (rule already in base code).
  - Rows with `after` or root leave the main chain. Every other active row keeps today's rule: sort by belt speed ascending, tie by `N.EXTRA` row order, first `prev = top_vanilla(raw)`, each next `prev` = previous main-chain row.
  - Returned list `extra.tiers(raw, mods)` stays one flat list sorted by speed ascending, tie by row order (crafting-menu order = speed order, all chains together). Only `prev` changes.
  - U-3: `next_upgrade` stays inside one chain. Top vanilla variants → first MAIN-chain extra (or `nil` when main chain has no extra). Each extra → next row of SAME chain, same direction; last of a chain → `nil`. A root is never the `next_upgrade` of any box.
  - M-5 / U-1 root recipe + tech: previous box replaced by `N.EXTRA_RECIPE_ROOT.base` (`steel-chest`) amount 1; inserter amount and circuit amount = recipe set amount × `N.EXTRA_RECIPE_ROOT.mult` (2); craft time and item names unchanged from the recipe set in use (`N.EXTRA_RECIPE`, or `N.EXTRA_RECIPE_NOSA` without `stack-inserter`/`quantum-processor`). SE game (no space-age): `steel-chest` 1, `se-space-splitter` 1, `bulk-inserter` 4, `processing-unit` 10, 60 s. Tech: no previous-tier tech prerequisite (base code `prototypes/tier.lua:71` already adds it only when `prev` is set); belt tech + ingredient-unlock techs as today; cost rule U-1 unchanged.
- `scripts/names.lua` (frozen, already at base): row `se-space` (`own_role = true`, belt `se-space-transport-belt`, splitter `se-space-splitter`, tech `se-space-belt`) before row `se-deep-space`; `se-deep-space.after = "se-space"`; `N.EXTRA_RECIPE_ROOT = { base = "steel-chest", mult = 2 }`. Do not edit names.
- `prototypes/tier.lua:49` at base already uses `N.RECIPE_BASE` when there is no previous tier (yellow). Root extra tier must use `N.EXTRA_RECIPE_ROOT.base` and the ×2 amounts; yellow stays exactly as today (golden).
- Offline fixture `tests/offline/fake_data.lua` (frozen): set `se` (no space-age) = `sespace` belt 0.09375 + `sedeep` 0.1875 with owner `space-exploration`. Other sets unchanged. There is no SE + K2 set: build one inside your test with `F.with_mods` for `se` and then add the `superior`/`advanced` fixtures the same way the `k2so` set does (read `fake_data.lua`), or set `_G.mods` + raw entries by hand; restore after.
- Tests red at base, turn green by your code (their expectations are integrator-set; do not edit them): `data extra > se chain space root then deep space`, `data extra > upgrade chain from top vanilla`.
- Offline runner: `describe`, `it`, `eq`, `ok` (`tests/offline/run.lua`); name `<describe> > <it>`. Define `_G.log` in tests to capture skip logs.

## Explain very simply

SE space belt is as fast as blue, but works in space. Its box starts its own line: no box before it, made from a steel chest. Deep space box now comes after space box, not after blue. Other mod boxes still line up after the top vanilla box by speed. Upgrade planner never jumps from one line to the other.

```
SE game:        yellow ► red ► blue          space ► deep space
SE + K2 game:   yellow ► red ► blue ► superior(60/s)          space ► deep space
menu row:       [yellow][red][blue][space][superior][deep space]   (speed order)
```

## What to build

1. `prototypes/extra.lua` `M.tiers`: `after` rule (skip + log when target inactive), root rule (`prev` absent), main chain unchanged for the rest; flat list sorted by speed.
2. `prototypes/extra.lua` `M.build`: `next_upgrade` per chain as above; `next` passed to `tier.make` = next row of same chain.
3. `prototypes/tier.lua`: root extra tier recipe from `N.EXTRA_RECIPE_ROOT` (base 1, inserters and circuits × mult); no previous-tier tech prereq.

### Tests to write — `tests/offline/test_data_extra.lua`, `describe("data extra", ...)`; each red at `lanes-base-v11` first, then green

- `data extra > se space root recipe` — set `se`, build: `se-space-sushi-packer` recipe ingredients = `steel-chest` 1, `se-space-splitter` 1, `bulk-inserter` 4, `processing-unit` 10 (any order); energy 60; no ingredient name containing `sushi-packer`.
- `data extra > se space root tech` — set `se`, build: tech `se-space-sushi-packer` prerequisites contain `se-space-belt`, contain no name starting `sushi-packer` or ending `-sushi-packer`; unit count = 200 × 1.5 (fixture `se-space-belt` count 200); ingredients include `se-rocket-science-pack`.
- `data extra > se deep space recipe needs space box` — set `se`, build: `se-deep-space-sushi-packer` recipe has `se-space-sushi-packer` 1 and no `express-sushi-packer`; tech prerequisites contain `se-space-sushi-packer` tech, not the `express-sushi-packer` tech.
- `data extra > after target inactive skips row` — set `se`, remove `raw["transport-belt"]["se-space-transport-belt"]`: tiers contain neither `se-space` nor `se-deep-space`; log names `se-deep-space`.
- `data extra > se plus k2 two chains` — SE + K2 fixture: `F.with_mods` set `se` then add fixture entries `superior` (`kr-superior-transport-belt` 0.1875, owner `Krastorio2-spaced-out`) and `advanced` (hidden belt, skipped) exactly as set `k2so` does (read `fake_data.lua` `F.with_mods`), owner mod in `_G.mods`. Flat tiers keys = `se-space`, `kr-superior`, `se-deep-space` (speed 0.09375, 0.1875, 0.1875; tie `kr-superior` first by row order). `kr-superior` prev = `blue`; `se-deep-space` prev = `se-space`; `se-space` prev nil. After build: blue west `next_upgrade` = `kr-superior-sushi-packer-west`; `se-space` west → `se-deep-space-sushi-packer-west`; `kr-superior` west nil; `se-deep-space` west nil. Fixture `superior` tech lists prerequisite `turbo-transport-belt`, absent without space-age; if build trips on it, remove that prerequisite from the raw tech inside your test (never edit `fake_data.lua`).
- `data extra > yellow recipe unchanged by root rule` — default `F.reset()`, `dofile("prototypes/packer.lua")`: yellow recipe = `steel-chest` 1, `splitter` 1, `inserter` 2, `electronic-circuit` 5, 30 s (U-2).

Every existing test stays green (all of `tests/offline/test_data.lua`, `tests/offline/test_data_extra.lua`), and the two red ones above turn green.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make zip`, never `--full`, never a file-wide or dir-wide run, never `lua5.2 tests/offline/run.lua <file>` on a whole file. Never start Factorio, never run `tests/game/*` (`tools/run_tests.sh` refuses headless under `LANE_RUN_ID`). One test per call, milliseconds each:

```
make test-one T='tests/offline/test_data_extra.lua::data extra > se space root recipe'
```

Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, `tests/offline/golden_vanilla.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/*`, `control.lua`, `data.lua`, `data-final-fixes.lua`, `settings.lua`, `info.json`, `locale/*`, `graphics/*`, `Makefile`, `tools/*`, `.agent-lane.toml`, any file not in "Files this lane owns". Never change an existing public signature. Never weaken, skip or delete an existing test or change an existing expectation.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane030-scope", "command": "git diff --name-only lanes-base-v11 HEAD | grep -Ev '^(prototypes/tier\\.lua|prototypes/extra\\.lua|tests/offline/test_data_extra\\.lua)$' | ( ! grep . ) && echo lane030-scope-ok", "expect_exit": 0, "expect_regex": "lane030-scope-ok", "timeout_s": 60}
{"name": "lane030-tests", "command": "( for t in 'data extra > vanilla prototypes identical to v8' 'data extra > no mods no extra tiers' 'data extra > arig adds hyper after turbo' 'data extra > all mods sorted by speed tie by row order' 'data extra > recipe chains previous tier' 'data extra > next_upgrade chain keeps direction' 'data extra > nosa no turbo tier' 'data extra > nosa extras chain after blue' 'data extra > nosa extra recipe bulk inserter processing unit' 'data extra > sa extra recipe unchanged' 'data extra > owner missing row skipped' 'data extra > ab-sa ub-ultimate not live' 'data extra > ab-sa ab rows after turbo' 'data extra > splitter missing row skipped logged' 'data extra > speed at or below top vanilla skipped' 'data extra > own_role keeps slow row' 'data extra > se chain space root then deep space' 'data extra > container allowed in se space' 'data extra > ab four rows speed order' 'data extra > upgrade chain from top vanilla' 'data extra > se space root recipe' 'data extra > se space root tech' 'data extra > se deep space recipe needs space box' 'data extra > after target inactive skips row' 'data extra > se plus k2 two chains' 'data extra > yellow recipe unchanged by root rule'; do tools/run_tests.sh 2.0 \"tests/offline/test_data_extra.lua::$t\" || exit 1; done; for t in 'data > chained tiers use previous box' 'data > next_upgrade chain keeps direction' 'data > tech prereqs include ingredient unlock techs'; do tools/run_tests.sh 2.0 \"tests/offline/test_data.lua::$t\" || exit 1; done; tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane030-tests-ok", "expect_exit": 0, "expect_regex": "lane030-tests-ok", "timeout_s": 300}
```

## Files this lane owns

prototypes/tier.lua, prototypes/extra.lua, tests/offline/test_data_extra.lua (add tests only). Never touch anything else.

Re-cut because: none

# bound: 3600s
