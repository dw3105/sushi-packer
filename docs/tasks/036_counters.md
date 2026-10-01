# 036 — counters: per-work counts in tick + belt_io, off unless asked

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-036_counters`, branch `lane/036_counters`, base tag `lanes-base-v14`, merge target `int/v14`. Host `dev-vm`.

Lanes 034 (owns `tests/game/bench_builder.lua`, `tools/bench/mod/*`) and 035 (owns `tools/bench/run.sh`, `tools/bench/parse.py`, `Makefile`) run beside you. No shared file. Seam = `docs/CONTRACT.md`: storage layout line `storage.sp_counters`, rows `tick.counters_on` / `tick.counters`, paragraph "Counters (v14 ...)". Read it first, it is law.

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v14`. With `storage.sp_counters == nil` (normal play) box behaviour is unchanged: no new table write, no new engine call, same return values from `belt_io.pull` / `belt_io.push`, every existing offline test green untouched. Signatures of `belt_io.pull(rec, budget, sink)` and `belt_io.push(rec, lane, item, belt_stack_size)` unchanged (guard `contract frozen` pins arity).

- `scripts/tick.lua:173-174`: stubs `function M.counters_on() end`, `function M.counters() return nil end`. `control.lua` already exposes them as remote calls (frozen, never edit).
- `scripts/tick.lua:70` `M.on_tick(e)`: per box, poll gate at lines 92-93; first statement inside gate is line 94 `local enabled, flush_now = circuit.evaluate(rec)`. One pass through line 94 = one visit.
- `scripts/belt_io.lua:152` `M.pull`: `line.get_detailed_contents()` called at line 176 (take window) and line 200 (eta). Belt item leaves belt at line 187 `line.remove_item({ name = name, count = accepted, quality = quality })`; `accepted` = item count taken.
- `scripts/belt_io.lua:210` `M.push`: success branch line 215 returns `item.count`.
- Several offline test files call `belt_io.pull` with no `storage` global at all (`tests/offline/test_perf.lua:27-32`, `tests/offline/test_belt_io_fast.lua:45`). Read as `local c = storage and storage.sp_counters` — once per `pull` call, once per `push` call, once per `on_tick` call; never per item.
- No state outside `storage` (SP-05): counters live only in `storage.sp_counters`. No upvalue counter, no function value in `storage`.
- No `require` inside any function.
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq`, `ok`; lua5.2. Belt line mock: `tests/offline/test_belt_io_fast.lua:6-38`. Tick fixture: `tests/offline/test_tick.lua` top (`fixture()`, `run(t, rec)`).

## Explain very simply

We want to know how much work boxes do: how many visits, belt reads, items in, items out. Add six counters. They sleep (nil) in normal game and cost one nil check. Bench switches them on.

## What to build

### Tests first — new `tests/offline/test_counters.lua`, describe `counters`; each seen RED before code

- `counters > off by default` — `storage = { boxes = {}, belt_stack = {} }`; `tick.counters()` is nil; one `belt_io.pull` that takes an item + one `belt_io.push` that succeeds; `storage.sp_counters` still nil. Green at base (preservation; say so).
- `counters > on starts at zero` — `tick.counters_on()`; `tick.counters()` equals `{ visits = 0, reads = 0, pulls = 0, pushes = 0, items_in = 0, items_out = 0 }`. RED at base.
- `counters > counters returns copy` — table from `tick.counters()` is not `storage.sp_counters` itself; writing into it does not change next `tick.counters()`. RED at base.
- `counters > on again resets` — count something, `counters_on()` again -> all 0. RED at base.
- `counters > pull counts belt items and items` — fast belt mock (speed 0.1875) with front items of count 3 then 1 inside take window, sink accepts all: `pulls = 2`, `items_in = 4`, `reads >= 1`. RED at base.
- `counters > partial accept counts accepted only` — sink accepts 2 of 3: `pulls = 1`, `items_in = 2`. RED at base.
- `counters > refused item counts nothing` — sink returns 0: `pulls = 0`, `items_in = 0`. RED at base (after on: fields exist only once implemented).
- `counters > reads count each detailed call` — mock line counts its own `get_detailed_contents` calls; after `pull`, `reads` equals mock's count (both call sites, lines 176 and 200). RED at base.
- `counters > push counts belt item and items` — `push` of `{count = 4}` success: `pushes = 1`, `items_out = 4`; blocked line (`can_insert_at_back` false): unchanged. RED at base.
- `counters > visit counted once per gate pass` — tick fixture with one box: run ticks 1..16; `visits` equals number of `circuit.evaluate` calls (wrap it and count). RED at base.

### Code — `scripts/tick.lua`, `scripts/belt_io.lua`

Per seam. `counters_on`: `storage.sp_counters = { visits = 0, reads = 0, pulls = 0, pushes = 0, items_in = 0, items_out = 0 }`. `counters`: nil when off, else new table with same six fields. Increments only where "What is true" names lines.

### Mutation

Remove `pulls` increment -> `counters > pull counts belt items and items` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of an existing test file. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_counters.lua::counters > on starts at zero'
```

Only whole-file run allowed: your own new file, `lua5.2 tests/offline/run.lua tests/offline/test_counters.lua`.

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `scripts/names.lua`, `scripts/core.lua`, any other `scripts/*`, any existing `tests/offline/*`, anything under `tests/game/`, `tools/*`, `Makefile`. Never weaken, skip or delete an existing test. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v14..HEAD`.

## What done mean

```checks
{"name": "lane036-scope", "command": "git diff --name-only lanes-base-v14 HEAD | grep -Ev '^(scripts/tick\\.lua|scripts/belt_io\\.lua|tests/offline/test_counters\\.lua)$' | ( ! grep . ) && echo lane036-scope-ok", "expect_exit": 0, "expect_regex": "lane036-scope-ok", "timeout_s": 60}
{"name": "lane036-tests", "command": "( for t in 'off by default' 'on starts at zero' 'counters returns copy' 'on again resets' 'pull counts belt items and items' 'partial accept counts accepted only' 'refused item counts nothing' 'reads count each detailed call' 'push counts belt item and items' 'visit counted once per gate pass'; do tools/run_tests.sh 2.0 \"tests/offline/test_counters.lua::counters > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_counters.lua && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > no require inside runtime functions' && tools/run_tests.sh 2.0 'tests/offline/test_belt_io_fast.lua::belt_io fast > fast belt takes item arriving this tick' && tools/run_tests.sh 2.0 'tests/offline/test_belt_io_fast.lua::belt_io fast > 270 per s belt takes every item within one tick of end' && tools/run_tests.sh 2.0 'tests/offline/test_perf.lua::perf > behind belt looked up once while valid' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > stored item goes to core and chest' ) && echo lane036-tests-ok", "expect_exit": 0, "expect_regex": "lane036-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/tick.lua (counters_on, counters, one visit increment), scripts/belt_io.lua (increments in pull and push), tests/offline/test_counters.lua (new). Never touch anything else.

Re-cut because: none

# bound: 1800s
