# 011 — perf round 2 for R-1: front item read, stack size cache, core key index, LED skip

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-011_perf_r1_round2`, branch `lane/011_perf_r1_round2`, base tag `wave4-base`, merge target `int/v1`. Host `dev-vm`.

This task is complete in itself.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua`; every behaviour asserted by the existing offline tests named in the checks; every file outside "Files this lane owns" byte-identical to `wave4-base`.

- Profiler split and decision: `docs/DECISIONS.md` row PERF-2 (pull dominates: `get_detailed_contents` 2906 ms, `core.accept` ~1100 ms, `prototypes.item[name]` 420 ms over 1500 ticks at 200 boxes).
- Game facts measured on 2.0.77 and 2.1.20 (`tests/game/test_probe.lua`): `#line` = item count; `line[1]` = lowest-position (front-most) item, a LuaItemStack with `.name`, `.count`, `.quality` (LuaQualityPrototype, `.quality.name`) — probe `probe > line index 1 is front-most item`; `line.can_insert_at(0)` is false exactly when an item rests at the exit — probe `probe > can_insert_at 0 is false only when an item sits at the exit`.
- `scripts/belt_io.lua:79` `pull` builds `line.get_detailed_contents()` per try. `scripts/core.lua:25` `find_partial` scans all partials. `scripts/tick.lua:52`, `:94` call `prototypes.item[name]` per item. `scripts/tick.lua:127` calls `led.set` every tick for every box.
- Determinism: a module-level cache of prototype stack sizes is allowed (value derives from prototypes, identical on every client, rebuilt lazily after load); no other module-level state.
- Mock style: `tests/offline/test_tick.lua` fixture, `tests/offline/test_perf.lua`. A fake transport line is a table with `__len` and `__index` metamethods returning fake stacks `{ name, count, quality = { name = "normal" } }`, plus `can_insert_at(pos)` and `remove_item(x)`; make its `get_detailed_contents` raise `error` so any call fails the test.

## Explain very simply

Box still does slow work per item. Read only the first item on the belt, not the whole belt. Remember stack sizes. Find a partial stack by key, not by searching. Do not touch the LED when nothing changed.

## What to build

1. `scripts/belt_io.lua` `pull`: per lane, per try: `#line == 0` or `line.can_insert_at(0)` → stop lane (no item at exit). Else `s = line[1]`; copy `name = s.name`, `quality = s.quality and s.quality.name or "normal"`, `count = s.count`; `accepted = sink(...)`; `accepted > 0` → `line.remove_item({name, count = accepted, quality})`; else stop lane. No `get_detailed_contents` call anywhere in `pull`.
2. `scripts/tick.lua`: local `stack_size(name)` with module-level table cache; used at `:52` and `:94`. LED: call `led.set` only when `rec.led` is nil-safe and (`rec.led.state ~= state` or `rec.led.visible ~= visible`).
3. `scripts/core.lua`: keep an index `box.partial_by_key[name .. "\0" .. quality .. "\0" .. lane] = partial` maintained on every add/remove/flush/remove_external so `find_partial` is O(1); `box` stays plain data (index holds references to the same partial tables; `core > box is plain data` must still pass). Keep partials array order rules.

### Tests to write (exact names; each red on `wave4-base` first)

`tests/offline/test_perf2.lua`, `describe("perf2", ...)`:
- `perf2 > pull reads front item without detailed contents`
- `perf2 > pull skips lane when no item at exit`
- `perf2 > pull removes only accepted part of front item`
- `perf2 > stack size looked up once per item name`
- `perf2 > core finds partial by key with 47 others present`
- `perf2 > led set skipped when unchanged`

## Test rule — read twice

**Lanes run offline Lua tests only (SP-02 v0.2).** Never start Factorio, never `tests/game/*`, never `make test`, never `--full`, never a file-wide run. One test at a time: `make test-one T='tests/offline/test_perf2.lua::perf2 > <it>'`.

**Never edit** anything outside "Files this lane owns". Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Checks last.

## What done mean

```checks
{"name": "lane011-scope", "command": "git diff --name-only wave4-base HEAD | grep -Ev '^(scripts/tick\\.lua|scripts/belt_io\\.lua|scripts/core\\.lua|tests/offline/test_perf2\\.lua|tests/offline/test_perf\\.lua|tests/offline/test_tick\\.lua|tests/offline/test_belt_io\\.lua)$' | ( ! grep . ) && echo lane011-scope-ok", "expect_exit": 0, "expect_regex": "lane011-scope-ok", "timeout_s": 60}
{"name": "lane011-tests", "command": "( for t in 'pull reads front item without detailed contents' 'pull skips lane when no item at exit' 'pull removes only accepted part of front item' 'stack size looked up once per item name' 'core finds partial by key with 47 others present' 'led set skipped when unchanged'; do tools/run_tests.sh 2.0 \"tests/offline/test_perf2.lua::perf2 > $t\" || exit 1; done && for t in 'circuit off makes no network calls' 'behind belt looked up once while valid' 'missing belt rescanned at most every 60 ticks' 'rotated cached belt is dropped' 'pull with zero budget makes no belt calls' 'yellow box visited every 8 ticks' 'turbo box visited every 2 ticks' 'visits staggered by unit number' 'credits per visit keep tier rate over 800 ticks' 'led checked every tick' 'opened set built once per tick'; do tools/run_tests.sh 2.0 \"tests/offline/test_perf.lua::perf > $t\" || exit 1; done && tools/run_tests.sh 2.0 'tests/offline/test_perf.lua::perf scan > front rescan not starved by missing behind' && for t in 'timeout ticks custom and global' 'on research caches belt stack size' 'invalid entity drops rec' 'disabled box moves nothing and hides led' 'flush signal queues partials' 'intake budget follows tier rate' 'stored item goes to core and chest' 'filtered item goes to hold not chest' 'filter without quality matches any quality' 'output piece capped at belt stack size' 'output removes stored items from chest' 'passthrough output leaves chest alone' 'output rate never above tier rate' 'blocked lane does not stall other lane' 'led follows core state' 'opened box reconciles next tick' 'closed box reconciles every 60 ticks' 'idle box sleeps 30 ticks' 'belt stack computed when cache empty'; do tools/run_tests.sh 2.0 \"tests/offline/test_tick.lua::tick > $t\" || exit 1; done && for t in 'new box is idle and green' 'same item on two lanes keeps two buffers' 'quality is separate buffer' 'full stack becomes ready on its lane' 'ready stacks leave in ready order' 'arrival after ready starts new partial' 'accept splits across ready and new partial' 'used slots counts ready and partials' 'full box flushes oldest partial and accepts zero' 'oldest partial chosen across lanes' 'all ready refuses input' 'passthrough uses hold not slots' 'hold busy refuses second passthrough' 'hold waits while stack run started' 'hold goes before unstarted stack' 'take out last piece may be small' 'timeout flushes old partial only' 'timeout zero is off' 'flush partials queues all in arrival order' 'remove external takes newest partial first' 'adopt external lands on lane one' 'led yellow with items and red when full' 'totals sums lanes sorted' 'box is plain data'; do tools/run_tests.sh 2.0 \"tests/offline/test_core.lua::core > $t\" || exit 1; done && for t in 'front accepts same direction belt' 'front refuses sideways belt' 'front refuses belt facing box' 'front accepts underground input same direction' 'behind still requires belt moving into box'; do tools/run_tests.sh 2.0 \"tests/offline/test_belt_io.lua::belt_io > $t\" || exit 1; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane011-tests-ok", "expect_exit": 0, "expect_regex": "lane011-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/tick.lua, scripts/belt_io.lua, scripts/core.lua, tests/offline/test_perf2.lua, tests/offline/test_perf.lua, tests/offline/test_tick.lua, tests/offline/test_belt_io.lua. Never touch anything else.

Re-cut because: none

# bound: 2400s

Reviewer ask: read `git diff wave4-base HEAD`; confirm `get_detailed_contents` is gone from pull, the core index is updated on every path that adds or removes a partial (accept, fill-to-ready, flush, timeout, remove_external, adopt), and no test was weakened.
