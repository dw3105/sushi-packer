# 064 — relink: vanilla tier tech prerequisites scanned again at data-final-fixes

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-064_relink`, branch `lane/064_relink`, base tag `lanes-base-v24`, merge target `int/v24`. Host `dev-vm`.

Only lane of this round. Integrator works on docs only.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v24`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen`). `scripts/names.lua` frozen: never edit. Data-stage output of `prototypes/packer.lua` unchanged: golden test in `tests/offline/test_data_extra.lua` (compares `F.extended` with `tests/offline/golden_vanilla.lua`) stays green with golden file untouched.

- Vanilla tiers `N.TIERS = { "yellow", "red", "blue", "turbo" }` (`scripts/names.lua:5`); tech name `N.tech(key)` = item name (`scripts/names.lua:64`): `sushi-packer`, `fast-sushi-packer`, `express-sushi-packer`, `turbo-sushi-packer`; recipe name `N.item(key)`. Turbo optional (`N.OPTIONAL_VANILLA`, `scripts/names.lua:173`): absent without space-age.
- `prototypes/packer.lua:6-20` (runs from `data.lua`, data stage) builds vanilla tiers with `tier.make(key, { prev, next, index, strict = true })`; `prev` = previous BUILT tier (turbo skipped when absent).
- `prototypes/tier.lua:113-170`, inside `M.make`: tech prerequisites = `{ T.tech }` (belt tech, `T = N.TIER[key]`), then `N.tech(prev)` when prev, else `steel-processing` unless `opts.root`; then for each recipe ingredient (recipe order), every tech in `data.raw.technology` (sorted by name, own tech skipped) whose `effects` hold `{ type = "unlock-recipe", recipe = <ingredient name> }` is appended once. `unit.ingredients` = union of `unit.ingredients` over those prerequisites in prerequisite order, first seen kept, techs without `unit` skipped. `unit.count = ceil(belt count * N.TECH_COST_FACTOR)`, `unit.time` = belt time.
- Defect (FND-0058, `docs/FINDINGS.md`): this scan runs at data stage. A mod loading later (pY `pyhightech` `data.lua`) moves recipe `advanced-circuit` from tech `advanced-circuit` to tech `basic-electronics`; our `fast-sushi-packer` keeps stale prerequisite `advanced-circuit` (a late pY tech). Our `data-final-fixes.lua` runs after that move.
- `data-final-fixes.lua` today (3 lines): comment, `require("prototypes.extra").build(data.raw)` (extra tiers, built late already), `require("prototypes.hidden").finalize(data.raw)`.
- Offline data fixture `tests/offline/fake_data.lua`: `F.reset(opts)` fills fake `data`, `data.raw`, `F.raw`; `F.TECH` techs (lines 14-27) get `effects` from `F.UNLOCK` (lines 30-44): recipe `advanced-circuit` unlocked by tech `advanced-circuit`, `fast-inserter` by `fast-inserter`, `fast-splitter` by `logistics-2`, `processing-unit` by `processing-unit`. `F.reset{ sa = false }` = no space-age (turbo absent). Usage: `local F = require("tests.offline.fake_data"); F.reset(); dofile("prototypes/packer.lua")` (`tests/offline/test_data.lua:4-8`).
- At base after `packer.lua`: `fast-sushi-packer` prerequisites = `{ "logistics-2", "sushi-packer", "fast-inserter", "advanced-circuit" }`, pack names = `{ "automation-science-pack", "logistic-science-pack" }` (`tests/offline/test_data.lua:289-318`).
- Runs in Factorio Lua 5.2, data stage, game versions 2.0 and 2.1. No `require` inside functions. Never add a key to a table while walking it with `pairs`. No `pairs` order in results: sort names.
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected, msg)`, `ok(cond, msg)`; lua5.2.

## Explain very simply

Our mod asks "which tech unlocks this recipe part?" while loading data. pY moves the advanced circuit recipe to another tech after we asked. So our Fast Sushi Packer waits for wrong, very late tech. Fix: ask again at end of loading (`data-final-fixes`) and rebuild the tech's prerequisites and science packs from the answer.

## What to build

### Rule — `prototypes/tier.lua`

- Move prerequisite + science-pack computation of `M.make` (lines 119-150) into a private local function taking `raw` explicitly; `M.make` calls it with `data.raw` and gives exactly today's result.
- New public `M.relink(raw)`: walk `N.TIERS` in order; skip key when `raw.technology[N.tech(key)]` is nil or has no `unit`; `prev` = last key NOT skipped. For each kept key: `tech.prerequisites` = new list computed by same private function from current `raw` (belt tech, `N.tech(prev)` or `steel-processing` when no prev, ingredient-unlock techs from `raw.recipe[N.item(key)].ingredients`); `tech.unit.ingredients` = union over the new list. `unit.count`, `unit.time`, `effects`, every other field unchanged. Whole list rebuilt: stale entries dropped.

### Rule — `data-final-fixes.lua`

- First code line: `require("prototypes.tier").relink(data.raw)` with comment `-- v24 (U-1, FND-0058): vanilla tier techs re-scan ingredient unlocks after other mods moved them.` Before `prototypes.extra` line. Other two lines unchanged.

### Tests first; each seen RED before code

New file `tests/offline/test_data_v24.lua`, `describe("data v24", ...)`. Setup per test: `F.reset()`, `dofile("prototypes/packer.lua")`, `local tier = require("prototypes.tier")`. "Move" = remove `{ type = "unlock-recipe", recipe = "advanced-circuit" }` from `F.raw.technology["advanced-circuit"].effects`, add `F.raw.technology["basic-electronics"] = { type = "technology", name = "basic-electronics", prerequisites = {}, effects = { { type = "unlock-recipe", recipe = "advanced-circuit" } }, unit = { count = 50, time = 15, ingredients = { { "automation-science-pack", 1 }, { "py-science-pack-1", 1 } } } }`. Pack names = `ingredient[1]` of each `unit.ingredients` entry, in order.
- `data v24 > relink follows unlock moved after data stage` — move, `tier.relink(F.raw)`: `fast-sushi-packer` prerequisites == `{ "logistics-2", "sushi-packer", "fast-inserter", "basic-electronics" }`; pack names == `{ "automation-science-pack", "logistic-science-pack", "py-science-pack-1" }`.
- `data v24 > relink keeps count and time` — move, relink: `fast-sushi-packer` `unit.count == 300`, `unit.time == 30`, `effects == { { type = "unlock-recipe", recipe = "fast-sushi-packer" } }`.
- `data v24 > relink without move changes nothing` — deep copy of 4 vanilla techs after `packer.lua`; relink; each tech's `prerequisites` and `unit` equal copy (`eq`).
- `data v24 > relink twice equals once` — move, relink, deep copy of 4 techs, relink: equal copy.
- `data v24 > relink without space-age skips turbo` — `F.reset{ sa = false }`, packer.lua, relink: `F.raw.technology["turbo-sushi-packer"] == nil`; `express-sushi-packer` prerequisites == `{ "logistics-3", "fast-sushi-packer", "bulk-inserter", "processing-unit" }`.
- `data v24 > final fixes relinks before extra tiers` — read `data-final-fixes.lua` text: plain `string.find` position of `require("prototypes.tier").relink(data.raw)` found and smaller than position of `prototypes.extra`.

All 6 RED at base (no `relink`, no line in `data-final-fixes.lua`).

### Code

As rules. One new public function `M.relink` in `prototypes/tier.lua`. Nothing else public.

### Mutation

1. `M.relink` returns at once -> `relink follows unlock moved after data stage` red; restore -> green.
2. `M.relink` appends found techs to existing `tech.prerequisites` instead of rebuilding -> `relink follows unlock moved after data stage` red (stale `advanced-circuit` stays); restore -> green.
Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_data_v24.lua::data v24 > relink follows unlock moved after data stage'
```

Whole-file run allowed only for `tests/offline/test_data_v24.lua`: `lua5.2 tests/offline/run.lua tests/offline/test_data_v24.lua`.

Keep-green list `tests/offline/fixtures/v24_keep_green.txt` (91 tests of `test_data.lua`, `test_data_extra.lua`, `test_data_hidden.lua`, `test_guard.lua`; all green at base, golden test included), run as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v24_keep_green.txt
```

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `data.lua`, `control.lua`, `prototypes/packer.lua`, `prototypes/extra.lua`, `scripts/names.lua`, `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, `tests/offline/golden_vanilla.lua`, `tests/offline/fixtures/*`, any other test file, anything under `tests/game/`, `tools/*`, `Makefile`. Never weaken a test to hide a defect. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, both mutations red + restore green, `git log --oneline lanes-base-v24..HEAD`.

## What done mean

```checks
{"name": "lane064-scope", "command": "git diff --name-only lanes-base-v24 HEAD | grep -Ev '^(prototypes/tier\\.lua|data-final-fixes\\.lua|tests/offline/test_data_v24\\.lua)$' | ( ! grep . ) && echo lane064-scope-ok", "expect_exit": 0, "expect_regex": "lane064-scope-ok", "timeout_s": 60}
{"name": "lane064-tests", "command": "( for t in 'data v24 > relink follows unlock moved after data stage' 'data v24 > relink keeps count and time' 'data v24 > relink without move changes nothing' 'data v24 > relink twice equals once' 'data v24 > relink without space-age skips turbo' 'data v24 > final fixes relinks before extra tiers'; do tools/run_tests.sh 2.0 \"tests/offline/test_data_v24.lua::$t\" || exit 1; done; out=$(lua5.2 tests/offline/run.lua tests/offline/test_data_v24.lua) || exit 1; n=$(printf '%s\\n' \"$out\" | sed -n 's/^offline .*: \\([0-9]*\\) ran, 0 failed$/\\1/p'); [ \"${n:-0}\" -ge 6 ] || { echo \"count=$n\"; exit 1; } ) && echo lane064-tests-ok", "expect_exit": 0, "expect_regex": "lane064-tests-ok", "timeout_s": 300}
{"name": "lane064-guard", "command": "tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && echo lane064-guard-ok", "expect_exit": 0, "expect_regex": "lane064-guard-ok", "timeout_s": 120}
{"name": "lane064-keep-green", "command": "( n=0; while IFS= read -r t; do n=$((n+1)); tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v24_keep_green.txt; [ $n -ge 91 ] || { echo \"count=$n\"; exit 1; } ) && echo lane064-keep-green-ok", "expect_exit": 0, "expect_regex": "lane064-keep-green-ok", "timeout_s": 600}
```

Owner base colours (`lanes-base-v24`, scratch `HOME`, 2026-10-06): lane064-scope GREEN, lane064-tests RED (no test file), lane064-guard GREEN, lane064-keep-green GREEN.

## Files this lane owns

prototypes/tier.lua, data-final-fixes.lua, tests/offline/test_data_v24.lua (new). Never touch anything else.

Re-cut because: none

# bound: 2400s

Reviewer ask: does `relink` rebuild (not append) vanilla tier prerequisites from current `raw`, leave `make` data-stage output byte-identical (golden), and touch only the three owned files?
