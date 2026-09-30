# 033 — extra: copy collision mask to extra tiers (FND-0034)

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-033_extra`, branch `lane/033_extra`, base tag `lanes-base-v13`, merge target `int/v13`. Host `dev-vm`.

This task is complete in itself. No other lane runs.

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v13`; every existing test in `tests/offline/test_data_extra.lua` keeps its name, body and expectation.

- Bug (player report, reproduced headless on dev-vm 2026-09-30 on 2.0 and 2.1, `docs/FINDINGS.md` FND-0034), exact engine text:
  `Error while running setup for entity prototype "turbo-sushi-packer-east" (container): next_upgrade target (planetaris-hyper-sushi-packer-east) must have the same collision mask.`
- Why: mod Mining Drones Remastered, in its `data-final-fixes.lua` (runs BEFORE ours), adds layer `mining_drone` to `collision_mask.layers` of every prototype that has layer `player` — this hits our vanilla-tier boxes (yellow/red/blue/turbo containers). Our `data-final-fixes.lua` then calls `require("prototypes.extra").build(data.raw)`, which creates extra tiers (e.g. `planetaris-hyper`) via `prototypes/tier.lua` `tier.make` — those get NO `collision_mask` (nil = engine default, no `mining_drone`). Engine demands a box and its `next_upgrade` target have same mask → load fails.
  Measured after all fixes (2.0, Arig + MD): `turbo-sushi-packer-east` mask `{layers = {is_lower_object = true, is_object = true, item = true, mining_drone = true, object = true, player = true, water_tile = true}}`; `planetaris-hyper-sushi-packer-east` mask `nil`.
- Earlier same-shape bug FND-0029 (aai-containers resized box): fixed in `prototypes/extra.lua` `M.build`, loop at end: for each dir, `base = raw.container[N.variant(top, dir)]` (top vanilla box), and for each extra row `raw.container[N.variant(row.key, dir)].collision_box = table.deepcopy(base.collision_box)`. Test: `data extra > extra box matches resized vanilla box` in `tests/offline/test_data_extra.lua` (copy its shape).
- Required fix (decision V13-1, `docs/DECISIONS.md`): in that same loop, also `raw.container[N.variant(row.key, dir)].collision_mask = table.deepcopy(base.collision_mask)` — nil stays nil (deepcopy(nil) = nil; check fake `table.deepcopy` handles nil, else guard). Nothing else changes. Only API in both Factorio 2.0 and 2.1 (plain prototype field).
- Offline runner: `describe`, `it`, `eq`, `ok` (`tests/offline/run.lua`); test name `<describe> > <it>`. Helper `load(set)` at file top builds fake data.raw for a mod set (`"arig"`, `"se"`, ...).

## Explain very simply

Other mod paints a mark on our old boxes before we build new boxes. New boxes lack mark. Game says: box and its upgrade must carry same marks. Fix: new boxes copy marks from top old box, like they already copy size.

## What to build

### Tests first — `tests/offline/test_data_extra.lua`, inside existing `describe("data extra", ...)`, right after `extra box matches resized vanilla box`; each run BEFORE fix

- `data extra > extra box matches mask of vanilla box` — `load("arig")`; set on every vanilla tier box (`yellow`, `red`, `blue`, `turbo`) every dir: `collision_mask = { layers = { item = true, object = true, player = true, water_tile = true, is_object = true, is_lower_object = true, mining_drone = true } }`; `build(raw)`; for every dir: `raw.container[N.variant("planetaris-hyper", dir)].collision_mask` equals that mask, and is not same table as base (`ok(a ~= b)`: deep copy). Must be RED at base.
- `data extra > extra mask copied into every chain` — `load("se")`, same mask on `yellow`/`red`/`blue` boxes; `build`; `se-space` and `se-deep-space` every dir equal mask. Must be RED at base.
- `data extra > nil mask stays nil` — `load("arig")`, no mask set; `build`; `planetaris-hyper` every dir `collision_mask == nil`. Green at base too (preservation; say so in report).

### Fix — `prototypes/extra.lua`

Per "Required fix", one line in FND-0029 loop + comment `-- FND-0034: mods may edit masks before this runs (Mining Drones adds mining_drone layer); chain needs one mask.` Then new tests green, every existing `data extra` test green.

### Mutation

Remove the new line → `data extra > extra box matches mask of vanilla box` red; restore → green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make zip`, never `--full`, never a file-wide or dir-wide run, never `lua5.2 tests/offline/run.lua <file>` on a whole file. Never start Factorio, never run `tests/game/*` (`tools/run_tests.sh` refuses headless under `LANE_RUN_ID`). One test per call, milliseconds each:

```
make test-one T='tests/offline/test_data_extra.lua::data extra > extra box matches mask of vanilla box'
```

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/*`, any `prototypes/*` except `prototypes/extra.lua`, `control.lua`, `data.lua`, `data-final-fixes.lua`, `info.json`, `changelog.txt`, `locale/*`, `Makefile`, `tools/*`, `.agent-lane.toml`, any file not in "Files this lane owns". Never weaken, skip or delete an existing test or change an existing expectation. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then fix, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after fix, mutation red + restore green, `git log --oneline lanes-base-v13..HEAD`.

## What done mean

```checks
{"name": "lane033-scope", "command": "git diff --name-only lanes-base-v13 HEAD | grep -Ev '^(prototypes/extra\\.lua|tests/offline/test_data_extra\\.lua)$' | ( ! grep . ) && echo lane033-scope-ok", "expect_exit": 0, "expect_regex": "lane033-scope-ok", "timeout_s": 60}
{"name": "lane033-tests", "command": "( for t in 'extra box matches mask of vanilla box' 'extra mask copied into every chain' 'nil mask stays nil' 'extra box matches resized vanilla box' 'upgrade chain from top vanilla' 'arig adds hyper after turbo' 'next_upgrade chain keeps direction' 'se chain space root then deep space' 'vanilla prototypes identical to v8' 'se plus k2 two chains'; do tools/run_tests.sh 2.0 \"tests/offline/test_data_extra.lua::data extra > $t\" || exit 1; done; tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane033-tests-ok", "expect_exit": 0, "expect_regex": "lane033-tests-ok", "timeout_s": 300}
```

## Files this lane owns

prototypes/extra.lua (one line + comment in FND-0029 loop), tests/offline/test_data_extra.lua (add 3 tests only). Never touch anything else.

Re-cut because: none

# bound: 1800s
