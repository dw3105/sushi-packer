# 034 — bench-scene: builder takes tier, flow, seed; bench mod settings, loader, counter log

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-034_bench_scene`, branch `lane/034_bench_scene`, base tag `lanes-base-v14`, merge target `int/v14`. Host `dev-vm`.

Lanes 035 (owns `tools/bench/run.sh`, `tools/bench/parse.py`, `Makefile`) and 036 (owns `scripts/tick.lua`, `scripts/belt_io.lua`) run beside you. No shared file. You meet them only at frozen seam `docs/CONTRACT.md` section "Bench seam (v14)" — read it first, it is law.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v14`. `builder.build(surface, force, n, origin)` with `opts` nil or `{}` creates exactly same entities, same order, same fields as `tests/game/bench_builder.lua` at base (lines 6-42): game tests `bench > builder places requested setups` and `bench > setup feeds both lanes` depend on it and you cannot run them.

- `tests/game/bench_builder.lua:6` `M.build(surface, force, n, origin)`: per box i, column pitch 12, row pitch 12 (`cols = 20`); westbound scene: infinity chest `{x+10.5, y+0.5}` -> `loader-1x1` output `{x+9.5, y+0.5}` -> `transport-belt` x+6..x+8 -> box placer `N.placer("yellow")` at `{x+5.5, y+0.5}` (`raise_built = true`) -> `transport-belt` x+1..x+4 -> `loader-1x1` input `{x+0.5, y+0.5}` -> void infinity chest `{x-0.5, y+0.5}`. Lines 34-38 prime input belt lanes with 5 item names by `insert_at_back`.
- Hard-coded today: belt name line 22 and 25, loader lines 27-28, tier line 39.
- `scripts/names.lua`: `N.TIER[tier].belt`, `N.TIER[tier].splitter` exist for every key of `N.ALL` (vanilla lines 15-21, extra rows line 108). `N.placer(tier)`.
- Engine facts, measured on Factorio 2.0.77 and 2.1.20 (`docs/FINDINGS.md` FND-0036), you cannot re-measure:
  - `loader.loader_belt_stack_size_override = k` (LuaEntity, RW, both versions) makes loader put belt stacks of k.
  - Infinity chest with several `at-least` items: loader takes only first item. So one chest = one item.
  - 4 chests -> 4 loaders (override 1, 2, 3, 4) -> 2 splitters -> 1 splitter -> belt gives full belt rate, stack sizes 1..4 in even shares. Splitter with belt on one output only sends all to that output.
  - Splitter facing west covers 2 tiles in y; entity position = centre between its two rows.
- Bench mod `tools/bench/mod/`: `control.lua` (9 lines) builds on `script.on_init` with `settings.startup["sushi-packer-bench-boxes"]`; `settings.lua` has that one int setting; `info.json`. Mod is staged as `sushi-packer-bench`; builder is required as `__sushi-packer__.tests.game.bench_builder`.
- Remote calls exist at base (stubs, lane 036 fills them): `remote.call("sushi-packer", "counters_on")`, `remote.call("sushi-packer", "counters")` -> nil or table `{visits=, reads=, pulls=, pushes=, items_in=, items_out=}`.
- Offline runner `tests/offline/run.lua`: globals `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; test name `<describe> > <it>`; lua5.2. Mock pattern for `surface.create_entity`: `tests/offline/test_sim.lua:3-23`.
- No `math.random` anywhere (SP-05): seed logic = own integer arithmetic.
- No `require` inside any function (`guard > no require inside runtime functions`).

## Explain very simply

Bench scene today can only build yellow boxes fed with single iron plates. Make it build any tier, and second feed kind `stacks`: four loaders, each drops stacks of one size (1, 2, 3, 4), merged by splitters into one full belt. Bench mod gets settings to pick tier / flow / seed, its own fast loader, and prints work counters every 600 ticks.

## What to build

### 1. `tests/game/bench_builder.lua`

`M.build(surface, force, n, origin, opts) -> positions`.

- `opts` nil or `{}` -> old scene, unchanged (PRESERVE).
- `opts.tier` (default `"yellow"`): unknown key -> `error("bench_builder: unknown tier " .. tostring(tier))`. Belts = `N.TIER[tier].belt` (both sides of box), placer = `N.placer(tier)`.
- `opts.loader`: loader entity name for source and sink. Default `"loader-1x1"` when tier is yellow and flow is single, else `"sushi-packer-bench-loader"`.
- `opts.flow` `"single"` (default): old layout, one chest, with names above. Priming stays. Other value than `single` / `stacks` -> `error("bench_builder: unknown flow " .. tostring(flow))`.
- `opts.flow` `"stacks"`: column pitch 16 (not 12), row pitch 12, `cols = 20`. Box, output belts x+1..x+4, sink loader, void chest: same places as old. Input side, all westbound (`defines.direction.west`):
  - belts `N.TIER[tier].belt` at x+6, x+7, x+8 on row `y+0.5`;
  - splitter `N.TIER[tier].splitter` at `{x+9.5, y+1}`;
  - belts at `{x+10.5, y+0.5}` and `{x+10.5, y+1.5}`;
  - splitters at `{x+11.5, y+0}` and `{x+11.5, y+2}`;
  - 4 loaders (`type = "output"`) at `{x+12.5, y-0.5}`, `{x+12.5, y+0.5}`, `{x+12.5, y+1.5}`, `{x+12.5, y+2.5}`, each then `loader.loader_belt_stack_size_override = size`;
  - 4 infinity chests at `x+13.5`, same rows, each `infinity_container_filters = { { index = 1, name = item, count = 1000, mode = "at-least" } }`;
  - no priming.
- `M.plan(seed, i) -> { { item = <name>, size = <1..4> }, x4 }`, rows top (y-0.5) to bottom: pure function, own integer arithmetic. Sizes = permutation of 1, 2, 3, 4. Items = 4 distinct names out of `iron-plate`, `copper-plate`, `iron-gear-wheel`, `electronic-circuit`, `coal`. Same `(seed, i)` -> same plan. `opts.seed` default 1. Flow `stacks` uses `M.plan(seed, i)` for box i.
- Returns box positions as before.

### 2. Bench mod `tools/bench/mod/`

- `settings.lua`: keep `sushi-packer-bench-boxes`; add startup settings `sushi-packer-bench-tier` (string-setting, default `"yellow"`, `allow_blank = false`), `sushi-packer-bench-flow` (string-setting, default `"single"`, `allowed_values = { "single", "stacks" }`), `sushi-packer-bench-seed` (int-setting, default 1, minimum 0).
- new `data-final-fixes.lua`: `sushi-packer-bench-loader` = `table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])` with `name`, `speed = 1`, `max_belt_stack_size = 4`, `adjustable_belt_stack_size = true`, `minable = nil`, `next_upgrade = nil`; `data:extend`.
- `control.lua`: on init set `belt_stack_size_bonus = 3`, call `builder.build(surface, force, boxes, { 0, 0 }, { tier = <setting>, flow = <setting>, seed = <setting> })`, then `remote.call("sushi-packer", "counters_on")`. `script.on_nth_tick(600, ...)`: `c = remote.call("sushi-packer", "counters")`; when `c` is a table, `log(string.format("sushi-packer-bench counters tick=%d visits=%d reads=%d pulls=%d pushes=%d items_in=%d items_out=%d", game.tick, c.visits, c.reads, c.pulls, c.pushes, c.items_in, c.items_out))`; nil -> no log line. Yellow + single + seed 1 must pass `opts` that build old scene (builder default path).

### 3. Tests first — new `tests/offline/test_bench_builder.lua`, describe `bench builder`; each seen RED before code

Mock `surface.create_entity` recording specs (entity table accepts field writes, has `get_transport_line` returning table with `insert_at_back`), mock `defines.direction`, `surface.find_entity` returning recorded belt.

- `bench builder > default scene unchanged` — `build(surface, force, 2, {0,0})` and `build(..., {})`: same list of `{name, position, direction, type}`; list for box 1 equals literal expected table written in test from base lines 6-42 (chest, 3 belts, 4 belts, 2 loaders `loader-1x1`, void chest, placer `sushi-packer-yellow` placer name via `N.placer("yellow")`); second box at x offset 12. Green at base for 4-arg call (say so in report), red for `{}`-arg only if base ignores it — then say "green at base, preservation".
- `bench builder > tier sets belt placer loader` — `{ tier = "turbo" }`: every belt `turbo-transport-belt`, placer `N.placer("turbo")`, both loaders `sushi-packer-bench-loader`. RED at base.
- `bench builder > extra tier uses row names` — `{ tier = "ub-ultimate", flow = "stacks" }`: belts `ultimate-belt`, 3 splitters `original-ultimate-splitter`. RED at base.
- `bench builder > unknown tier errors` and `bench builder > unknown flow errors` — `pcall` false, message has the name. RED at base.
- `bench builder > stacks layout` — `{ flow = "stacks" }`, 1 box at origin `{0,0}` (x = 10, y = 10): exact positions from "What to build" for 3 splitters, 2 merge belts, 4 loaders, 4 chests; loaders carry override = plan size; each chest one filter `count = 1000`, `mode = "at-least"`, name = plan item; no `insert_at_back` call. RED at base.
- `bench builder > stacks column pitch 16` — 2 boxes: placer x differs by 16. RED at base.
- `bench builder > plan same seed same plan` — `plan(7, 3)` twice equal; sizes sorted = `{1,2,3,4}`; 4 distinct items from the 5 names, for every i in 1..200 and seeds 1, 2, 7. RED at base (no `plan`).
- `bench builder > plan varies across boxes` — over i = 1..200 seed 1: at least 6 different size orders and every one of 5 names used. RED at base.
- `bench builder > control passes settings and logs counters` — load `tools/bench/mod/control.lua` with `dofile` under mocks: `package.loaded["__sushi-packer__.tests.game.bench_builder"]` = fake recording `build` args; fake `script` (`on_init`, `on_nth_tick` store handlers), `settings.startup`, `game`, `remote.call`, `log`. Assert build got `{tier="blue", flow="stacks", seed=5}`, `counters_on` called after build, nth-tick period 600, log line exactly `sushi-packer-bench counters tick=1200 visits=1 reads=2 pulls=3 pushes=4 items_in=5 items_out=6` for that fake table, and no log when counters returns nil. RED at base.

### Mutation

In `M.plan` return fixed sizes `{1,1,1,1}` -> `bench builder > plan same seed same plan` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run. Never start Factorio, never run `tests/game/*` (`tools/run_tests.sh` refuses headless under `LANE_RUN_ID`). One test per call, milliseconds each:

```
make test-one T='tests/offline/test_bench_builder.lua::bench builder > stacks layout'
```

Only whole-file run allowed: your own new file, `lua5.2 tests/offline/run.lua tests/offline/test_bench_builder.lua`.

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), not `scripts/*`, not `tests/game/index.lua`, `tests/game/test_bench.lua`, any other `tests/game/*`, `tests/offline/run.lua`, `tests/offline/contract.lua`, `tests/offline/test_guard.lua`, `tools/bench/run.sh`, `Makefile`, `control.lua`. Never weaken, skip or delete an existing test. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v14..HEAD`.

## What done mean

```checks
{"name": "lane034-scope", "command": "git diff --name-only lanes-base-v14 HEAD | grep -Ev '^(tests/game/bench_builder\\.lua|tests/offline/test_bench_builder\\.lua|tools/bench/mod/(control\\.lua|settings\\.lua|data-final-fixes\\.lua|info\\.json))$' | ( ! grep . ) && echo lane034-scope-ok", "expect_exit": 0, "expect_regex": "lane034-scope-ok", "timeout_s": 60}
{"name": "lane034-tests", "command": "( for t in 'default scene unchanged' 'tier sets belt placer loader' 'extra tier uses row names' 'unknown tier errors' 'unknown flow errors' 'stacks layout' 'stacks column pitch 16' 'plan same seed same plan' 'plan varies across boxes' 'control passes settings and logs counters'; do tools/run_tests.sh 2.0 \"tests/offline/test_bench_builder.lua::bench builder > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_bench_builder.lua && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > no require inside runtime functions' ) && echo lane034-tests-ok", "expect_exit": 0, "expect_regex": "lane034-tests-ok", "timeout_s": 300}
{"name": "lane034-no-random", "command": "! grep -n 'math.random' tests/game/bench_builder.lua tools/bench/mod/control.lua && echo lane034-no-random-ok", "expect_exit": 0, "expect_regex": "lane034-no-random-ok", "timeout_s": 30}
```

## Files this lane owns

tests/game/bench_builder.lua, tests/offline/test_bench_builder.lua (new), tools/bench/mod/control.lua, tools/bench/mod/settings.lua, tools/bench/mod/data-final-fixes.lua (new), tools/bench/mod/info.json. Never touch anything else.

Re-cut because: none

# bound: 2400s
