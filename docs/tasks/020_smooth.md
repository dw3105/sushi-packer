# 020 — smooth pull: box wakes when front item reaches belt end (no stutter)

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-020_smooth`, branch `lane/020_smooth`, base tag `lanes-base-1.4`, merge target `int/v1.4`. Host `dev-vm`.

This task is complete in itself. Lane 021 (scene, files `scripts/sim.lua`, prototypes, `tests/offline/test_sim.lua`, `tests/offline/test_data.lua`) runs in parallel on other files; you never need it.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua`; every file outside "Files this lane owns" byte-identical to `lanes-base-1.4`.

- Author play-test 2026-09-27: yellow box stutters with tiny input flow. Cause (code read): `scripts/tick.lua` visits a box only when `(e.tick + rec.unit_number) % INTERVAL[tier] == 0` (yellow 8, red 4, blue 2, turbo 2) and `e.tick >= rec.next_poll`; `scripts/belt_io.lua` `M.pull` takes an item only when it already rests at belt end (`not line.can_insert_at(0)`). So each item STOPS at belt end up to 7 ticks. When box is idle and took nothing, `next_poll = tick + 30` → item waits up to 30 ticks. Stop-go = stutter.
- Measured facts (headless probes, 2.0.77 + 2.1.20): transport line position shrinks toward exit, front item = `line[1]`, items rest at position `0` on belt end (FND-0004); `line.can_insert_at(0)` false only when item rests at exit (PERF-2 probe); `line.get_detailed_contents()` returns array of `{stack=LuaItemStack, position=number, unique_id=...}` ordered front first (used by game tests on both versions). Belt speed = `belt.prototype.belt_speed` tiles per tick (yellow 0.03125, red 0.0625, blue 0.09375, turbo 0.125). Behind line is one belt tile, length 1.
- Tier lane rate `N.TIER[tier].lane_rate` items/tick (yellow 0.125 … turbo 0.5); credits `rec.in_credit[lane]`, `rec.out_credit[lane]`, cap 2. Rate cap must hold (R-2, O-4).
- Offline runner: `describe`, `it`, `eq(found, expected, msg)` deep compare, `ok(cond, msg)` (`tests/offline/run.lua`); full test name `<describe> > <it>`. Fixtures: `tests/offline/test_tick.lua` `fixture(tier)` fakes `belt_io.pull/push`, `circuit.evaluate`, `led.set`; `tests/offline/test_perf.lua` `tick_fixture`; `tests/offline/test_belt_io.lua` fakes surface/belts.

## Explain very simply

Box knows how far front item is from belt end and how fast belt moves. So box knows exact tick item arrives. Box wakes on that tick and eats item — item never stops. Nothing coming → normal slow cadence.

## What to build

1. `belt_io.pull(rec, budget, sink)` returns `taken, eta`. `eta = {e1, e2}` per lane, measured AFTER pulling: `nil` when lane empty; `0` when front item rests at exit (`not line.can_insert_at(0)`); else `math.ceil(front_position / belt_speed)` with `front_position = line.get_detailed_contents()[1].position`. Only call `get_detailed_contents` when `#line > 0` and front not at exit. Cache `belt_speed` per belt prototype name in module-local table. When no behind belt → `taken, nil`. When early return because budget empty → still compute eta (budget empty must not hide an arriving item). Add pure helper `M.eta(position, speed)` (ceil, min 0).
2. `tick.on_tick`: visit gate = `e.tick >= (rec.next_poll or 0)` only (drop `% interval` gate). After visit: `rec.last_poll = e.tick`;
   - default `next_poll = e.tick + interval`;
   - if some lane eta `e` with `0 < e < interval` → `next_poll = e.tick + e` (smallest). eta `0` never causes early wake (item stuck behind full box must not poll every tick);
   - idle (`core.is_idle(rec.box) and not taken_any`): today `+30`. New: `+ math.min(30, idle_gap)` where `idle_gap = math.floor(1 / belt_speed) - 1` for behind belt speed (item entering tile caught before arrival); unknown speed → 30. Expose speed via `belt_io.speed(rec)` (returns cached speed of behind belt or nil).
   - first visit spread: when `rec.next_poll == nil` or `0` and `rec.last_poll == nil` → keep today's stagger: visit only if `(e.tick + rec.unit_number) % interval == 0` (one-time; after first visit `next_poll` rules).
3. Credits: accrue by elapsed ticks: `elapsed = e.tick - (rec.last_poll or (e.tick - interval))`, `in_credit[lane] = min(in_credit[lane] + rate * elapsed, 2)`; same for `out_credit`. Rate cap holds with early wakes.
4. Save/load safe: old recs without `last_poll` work (default above). No new storage tables.

### Tests to write (exact names; each red against current code first)

`tests/offline/test_belt_io.lua`, `describe("belt_io", ...)`: `belt_io > pull reports eta of front item per lane`, `belt_io > eta zero when item at exit, nil when lane empty`, `belt_io > eta computed when budget empty`.
`tests/offline/test_tick.lua`, `describe("tick", ...)`: `tick > wakes on eta tick not on cadence`, `tick > eta zero never wakes early`, `tick > idle sleep shorter than tile crossing`, `tick > credit accrues by elapsed ticks`, `tick > rate cap holds with early wakes` (fake pull always offers item at exit with eta 1; over 600 ticks taken per lane ≤ `lane_rate * 600 + 2`), `tick > old rec without last_poll works`.

Existing tests that encode old cadence — you MAY rewrite these (same name, new rule), nothing else: `tick > intake budget follows tier rate`, `tick > idle box sleeps 30 ticks`, `perf > yellow box visited every 8 ticks`, `perf > turbo box visited every 2 ticks`, `perf > visits staggered by unit number`, `perf > credits per visit keep tier rate over 800 ticks` (check exact describe name in `tests/offline/test_perf.lua`). Every other existing test in owned files stays green unchanged in meaning.

## Test rule — read twice

**Lanes run offline Lua tests only.** Never start Factorio, never run `tests/game/*`, never `make test`, never `make zip`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_tick.lua::tick > wakes on eta tick not on cadence'
```

Game API is faked with plain Lua tables inside your test file. Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change an existing function signature (adding a second return value is allowed). Never weaken, skip or delete an existing test unless this task names it. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane020-scope", "command": "git diff --name-only lanes-base-1.4 HEAD | grep -Ev '^(scripts/tick\\.lua|scripts/belt_io\\.lua|tests/offline/test_tick\\.lua|tests/offline/test_belt_io\\.lua|tests/offline/test_perf\\.lua|tests/offline/test_perf2\\.lua)$' | ( ! grep . ) && echo lane020-scope-ok", "expect_exit": 0, "expect_regex": "lane020-scope-ok", "timeout_s": 60}
{"name": "lane020-tests", "command": "( for t in 'tests/offline/test_belt_io.lua::belt_io > pull reports eta of front item per lane' 'tests/offline/test_belt_io.lua::belt_io > eta zero when item at exit, nil when lane empty' 'tests/offline/test_belt_io.lua::belt_io > eta computed when budget empty' 'tests/offline/test_tick.lua::tick > wakes on eta tick not on cadence' 'tests/offline/test_tick.lua::tick > eta zero never wakes early' 'tests/offline/test_tick.lua::tick > idle sleep shorter than tile crossing' 'tests/offline/test_tick.lua::tick > credit accrues by elapsed ticks' 'tests/offline/test_tick.lua::tick > rate cap holds with early wakes' 'tests/offline/test_tick.lua::tick > old rec without last_poll works' 'tests/offline/test_tick.lua::tick > releases at belt stack' 'tests/offline/test_tick.lua::tick > output rate never above tier rate' 'tests/offline/test_guard.lua::guard > contract frozen' 'tests/offline/test_guard.lua::guard > names frozen'; do tools/run_tests.sh 2.0 \"$t\" || exit 1; done ) && echo lane020-tests-ok", "expect_exit": 0, "expect_regex": "lane020-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/tick.lua, scripts/belt_io.lua, tests/offline/test_tick.lua, tests/offline/test_belt_io.lua, tests/offline/test_perf.lua, tests/offline/test_perf2.lua. Never touch anything else.

Re-cut because: none

# bound: 2400s
