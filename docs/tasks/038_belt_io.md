# 038 — belt_io: cheap neighbour check, cached lines, same behaviour

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-038_belt_io`, branch `lane/038_belt_io`, base tag `lanes-base-v14b`, merge target `int/v14`. Host `dev-vm`.

Lanes 037 (owns `scripts/core.lua`) and 039 (owns `scripts/tick.lua`) run beside you. No shared file. Every signature in `docs/CONTRACT.md` section "scripts/belt_io.lua" stays as is. Lane 039 rule you rely on as fact: `tick.on_tick` keeps calling `belt_io.pull(rec, budget, sink)` and `belt_io.push(rec, lane, item, belt_stack_size)` exactly as today.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v14b`. `pull` and `push` take and give same items, same counts, same return values as base for a box whose neighbour belts do not move. Counters (`storage.sp_counters`, lines of `pull` / `push` that touch `counters`) keep counting as today. Helpers `M._speed`, `M._eta`, `M.eta`, `M.speed`, `M._reset_rates` keep working.

- Measured (headless profile, 200 turbo boxes, `docs/FINDINGS.md` FND-0038): neighbour cache check behind = 5.5 % of all box script time, front check + `get_transport_line` in push = 9 %, `get_transport_line` in pull = 2.4 %. Runs on every visit: 176662 visits in 1800 ticks.
- `scripts/belt_io.lua:112` `cached(rec, field, sign)`: every visit calls `matches` (line 97): reads `belt.valid`, `belt.direction`, `belt.type` (up to 3 times), `entity.position` (twice, each makes a table), `belt.position` (up to 3 times). Each read of an engine object is an engine call.
- `scripts/belt_io.lua:170`, `:201` (pull) and `:220` (push): `belt.get_transport_line(map[lane])` on every visit, per lane; pull does it twice per lane.
- Engine facts: belt `type` never changes. A placed belt keeps its `position` unless a mod teleports it (rare; then entity stays `valid`). Player rotation changes `direction`. Removal makes `valid` false. `LuaTransportLine` objects of a valid belt stay usable across ticks and may be kept in `storage` (`rec` lives in `storage`).
- `rec.belt` (owned by this module, `docs/CONTRACT.md` storage layout): `{ behind, front, scan = {}, lines = {} }`; you may add plain fields and `LuaTransportLine` values. Recs from old saves lack new fields: build them lazily.
- Tests today that pin cache behaviour: `tests/offline/test_perf.lua` `perf > behind belt looked up once while valid`, `perf > rotated cached belt is dropped`, `perf > missing belt rescanned at most every 60 ticks` and `perf scan` block. Mock pattern: `tests/offline/test_perf.lua:15-32`, fast line mock `tests/offline/test_belt_io_fast.lua:6-38`. Several tests give belts with no `position` field and lines as fresh tables per `get_transport_line` call: keep them green (keep-green list).
- No `require` inside functions. No state outside `storage` except prototype-derived caches already there (`belt_speeds`, `lane_rates`).

## Explain very simply

Each time box looks at its belt it first re-asks engine ten questions: still there? still same kind? still same place? Kind and place almost never change. Ask only "still there, still same direction" each time, ask everything once a second. Also keep belt's two lanes in hand instead of asking for them each time.

## What to build

### Tests first — new `tests/offline/test_belt_io_cache.lua`, describe `belt_io cache`; each seen RED before code

Belt mock = proxy table whose `__index` counts reads per key (`valid`, `direction`, `type`, `position`, `get_transport_line`); box entity mock counts `position` reads. `game = { tick = n }`.

- `belt_io cache > cached belt visit reads valid and direction only` — plain `transport-belt` behind; first `pull` at tick 1 may read anything; second `pull` at tick 2: belt reads of `type` = 0, `position` = 0; entity `position` reads = 0; `valid` + `direction` reads <= 2. RED at base.
- `belt_io cache > lines fetched once while belt cached` — 5 pulls at ticks 1..5: `get_transport_line` calls total <= 2 (one per lane). RED at base.
- `belt_io cache > push uses cached front lines` — 5 pushes at ticks 1..5 on plain front belt: `get_transport_line` calls <= 2; `type` and `position` reads after first push = 0. RED at base.
- `belt_io cache > moved belt dropped within 60 ticks` — belt `position` changes at tick 5 (still `valid`, same `direction`): some `pull` at a tick <= 65 stops using it (surface lookup runs again / `rec.belt.behind` no longer that belt). And at tick 6 (before full check is due) it is still used. Green part at base = dropped at once; assert only "dropped by tick 65" + "full check happens at most once per 60 ticks while nothing changes" (count `position` reads over ticks 1..120 <= 6). RED at base (reads far more).
- `belt_io cache > rotated belt dropped at once` — `direction` changes at tick 5: `pull` at tick 5 does not take from it. Green at base (preservation; say so).
- `belt_io cache > splitter neighbour keeps full check` — neighbour of `type` `splitter`: every visit still runs today's check (`neighbour_lines`); items still taken from right splitter lines (reuse expectation shape from `perf scan` block). Green at base (preservation; say so).
- `belt_io cache > dropped belt clears cached lines` — belt becomes `valid = false`, new belt appears: `pull` takes from new belt's lines, never calls a method on old line objects (old line mock errors on any call). RED at base only if your cache is wrong; write it before cache code and see it red against a first naive cache, or say "green at base".

### Code — `scripts/belt_io.lua`

- Per side remember kind at find time (plain belt / underground / other). Plain belt and underground: per-visit check = `valid` and `direction` only; full `matches` once per 60 ticks per side (own clock in `rec.belt`, plain number). Other kinds (splitter, loader, linked belt): today's check every visit.
- Cache both lane line objects per side in `rec.belt` when belt is found; drop them whenever belt is dropped or rescanned. `pull` and `push` use cached lines.
- Old `rec.belt` without new fields works (lazy build).

### Mutation

Skip clearing cached lines on drop -> `belt_io cache > dropped belt clears cached lines` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of an existing test file. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_belt_io_cache.lua::belt_io cache > lines fetched once while belt cached'
```

Only whole-file run allowed: your own new file, `lua5.2 tests/offline/run.lua tests/offline/test_belt_io_cache.lua`.

Keep-green list: `tests/offline/fixtures/v14_keep_green.txt`, one `<file>::<name>` per line (138 lines). Run it as single tests, one call per line:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v14_keep_green.txt
```

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `scripts/names.lua`, any `scripts/*` you do not own, any existing `tests/offline/*`, `tests/offline/fixtures/*`, anything under `tests/game/`, `tools/*`, `Makefile`. Never weaken, skip or delete an existing test. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v14b..HEAD`.
## What done mean

```checks
{"name": "lane038-scope", "command": "git diff --name-only lanes-base-v14b HEAD | grep -Ev '^(scripts/belt_io\\.lua|tests/offline/test_belt_io_cache\\.lua)$' | ( ! grep . ) && echo lane038-scope-ok", "expect_exit": 0, "expect_regex": "lane038-scope-ok", "timeout_s": 60}
{"name": "lane038-tests", "command": "( for t in 'cached belt visit reads valid and direction only' 'lines fetched once while belt cached' 'push uses cached front lines' 'moved belt dropped within 60 ticks' 'rotated belt dropped at once' 'splitter neighbour keeps full check' 'dropped belt clears cached lines'; do tools/run_tests.sh 2.0 \"tests/offline/test_belt_io_cache.lua::belt_io cache > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_belt_io_cache.lua ) && echo lane038-tests-ok", "expect_exit": 0, "expect_regex": "lane038-tests-ok", "timeout_s": 300}
{"name": "lane038-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v14_keep_green.txt ) && echo lane038-keep-green-ok", "expect_exit": 0, "expect_regex": "lane038-keep-green-ok", "timeout_s": 600}
```

## Files this lane owns

scripts/belt_io.lua, tests/offline/test_belt_io_cache.lua (new). Never touch anything else.

Re-cut because: none

# bound: 2400s
