# 025 — rate: box speed = live belt speed, fast tiers up to 270/s

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-025_rate`, branch `lane/025_rate`, base tag `lanes-base-v9`, merge target `int/v9`. Host `dev-vm`.

This task is complete in itself. Lane 024 (data stage: `prototypes/extra.lua`, `prototypes/packer.lua`, `data-final-fixes.lua`, `info.json`, `tests/offline/test_data_extra.lua`) and lane 027 (text: `locale/`, `README.md`, `portal/`, `changelog.txt`) run in parallel; you never need their code and never touch their files. After merge, fact: modded tiers exist in game only when their belt mod is loaded; every active tier key `t` has `N.TIER[t].belt` = a real belt prototype name.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua`; every file outside "Files this lane owns" byte-identical to `lanes-base-v9`.

- Requirements v9 M-6 (`docs/REQUIREMENTS.md` §17, author 2026-09-28): every tier (vanilla too) rate = live belt prototype speed. Output never above belt rate. Settings that change belt speed (Bob's belt speed overhaul) are followed.
- Unit: `belt_speed` = tiles per tick (Factorio `LuaEntityPrototype.belt_speed`). Belt items per lane per tick = `belt_speed * 4`. Vanilla: `transport-belt` 0.03125 → 0.125, `fast-` 0.0625 → 0.25, `express-` 0.09375 → 0.375, `turbo-` 0.125 → 0.5 (same as `N.TIER[t].lane_rate` today). Modded: 75/s = 0.15625 → 0.625; 90/s = 0.1875 → 0.75; 270/s = 0.5625 → 2.25.
- Measured (FND-0022, dev-vm 2.0.77 + 2.1.20): several `insert_at_back` per tick per lane work; 270/s test belt took 2.250 items per tick per lane. So no push cap; box only needs enough credit.
- `scripts/names.lua` (frozen): `N.TIER[t]` exists for every key of `N.ALL` (vanilla 4 + `N.EXTRA` keys like `"planetaris-hyper"`, `"kr-superior"`, `"ub-ultimate"`). Vanilla rows keep `lane_rate`; extra rows have NO `lane_rate` (nil). Each row has `.belt`.
- `scripts/belt_io.lua` at base: stub `function M.lane_rate(tier) return require("scripts.names").TIER[tier].lane_rate end`.
- `scripts/tick.lua` at base: `local INTERVAL = { yellow = 8, red = 4, blue = 2, turbo = 2 }`; visit uses `INTERVAL[rec.tier] or 1` (extra tier → every tick, keep). Line `local rate = N.TIER[rec.tier].lane_rate`; credits `rec.in_credit[lane] = math.min(rec.in_credit[lane] + rate * elapsed, 2)` and same for `out_credit` with cap 2; pull budget `math.floor(in_credit)`; push loop `while rec.out_credit[lane] >= 1`.
- Offline mocks: `tests/offline/belts.lua` = vanilla belt prototypes table, used as `prototypes.entity` in `test_tick.lua`, `test_perf.lua`, `test_perf2.lua`. Some mocks have no `prototypes.entity[belt]` (e.g. `test_perf.lua` belt_io tests use `"yellow-belt"`) → `lane_rate` must not crash there.
- Offline runner: `describe`, `it`, `eq(found, expected, msg)`, `ok(cond, msg)` (`tests/offline/run.lua`); test name `<describe> > <it>`. Tick fixture pattern: local `tick_fixture(tier, unit)` in `tests/offline/test_perf.lua` (copy it into your file; set `prototypes.entity` to your own table there). Rate check pattern: test `perf > credits per visit keep tier rate over 800 ticks` in same file.

## Explain very simply

Box speed now comes from real belt of its tier, read from game. Faster modded belt → faster box. If a mod makes belts slower or faster, box follows.

## What to build

1. `belt_io.lane_rate(tier)` in `scripts/belt_io.lua`: `local T = N.TIER[tier]` (require names inside or at top); `local p = prototypes.entity and prototypes.entity[T.belt]`; if `p` → `p.belt_speed * 4`; else `T.lane_rate or 0`. Cache result per tier in a module-local table (prototype-derived, identical on every client, same pattern as `stack_sizes` in `scripts/tick.lua`) — but only cache when `p` found.
2. `scripts/tick.lua`: `local rate = belt_io.lane_rate(rec.tier)`; credit cap for in and out = `math.max(2, 2 * rate)`. Nothing else changes.

### Tests to write — new file `tests/offline/test_tick_extra.lua`, `describe("tick extra", ...)`; each red against `lanes-base-v9` first

- `tick extra > lane rate is belt speed times 4` — mock `prototypes.entity` with `turbo-transport-belt` 0.125 and `kr-superior-transport-belt` 0.1875: `lane_rate("turbo") == 0.5`, `lane_rate("kr-superior") == 0.75`.
- `tick extra > missing belt prototype falls back to table rate` — empty `prototypes.entity`: `lane_rate("turbo") == 0.5`, `lane_rate("kr-superior") == 0`.
- `tick extra > modded vanilla speed followed` — `transport-belt` 0.0625 (Bob overhaul): `lane_rate("yellow") == 0.25`.
- `tick extra > 75 per s tier keeps rate over 800 ticks` — tier `planetaris-hyper`, belt 0.15625: pushed per lane over 800 ticks within ±2 of 500.
- `tick extra > 90 per s tier keeps rate over 800 ticks` — `kr-superior` 0.1875: ±2 of 600.
- `tick extra > 270 per s tier keeps rate over 800 ticks` — `ub-ultimate` 0.5625: ±2 of 1800.
- `tick extra > input budget reaches 2 per tick at 270 per s` — `ub-ultimate`: some visit calls `belt_io.pull` with `budget[1] >= 2`.
- `tick extra > extra tier visited every tick` — `kr-superior` box with items: 10 ticks → 10 pulls.

Every existing test stays green unchanged (notably `perf > credits per visit keep tier rate over 800 ticks`, `perf > yellow box visited every 8 ticks`, `perf > turbo box visited every 2 ticks`).

## Test rule — read twice

**Lanes run offline Lua tests only.** Never start Factorio, never run `tests/game/*`, never `make test`, never `make test-modsets`, never `make zip`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_tick_extra.lua::tick extra > lane rate is belt speed times 4'
```

Game API never needed: fake `prototypes`, `storage`, `game`, `defines`, `settings` as plain Lua tables in your test file. Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, `tests/offline/belts.lua`, any existing `tests/offline/test_*.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `data-final-fixes.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, any file not in "Files this lane owns". Never change an existing function signature. Never weaken, skip or delete an existing test. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane025-scope", "command": "git diff --name-only lanes-base-v9 HEAD | grep -Ev '^(scripts/belt_io\\.lua|scripts/tick\\.lua|tests/offline/test_tick_extra\\.lua)$' | ( ! grep . ) && echo lane025-scope-ok", "expect_exit": 0, "expect_regex": "lane025-scope-ok", "timeout_s": 60}
{"name": "lane025-tests", "command": "( for t in 'tests/offline/test_tick_extra.lua::tick extra > lane rate is belt speed times 4' 'tests/offline/test_tick_extra.lua::tick extra > missing belt prototype falls back to table rate' 'tests/offline/test_tick_extra.lua::tick extra > modded vanilla speed followed' 'tests/offline/test_tick_extra.lua::tick extra > 75 per s tier keeps rate over 800 ticks' 'tests/offline/test_tick_extra.lua::tick extra > 90 per s tier keeps rate over 800 ticks' 'tests/offline/test_tick_extra.lua::tick extra > 270 per s tier keeps rate over 800 ticks' 'tests/offline/test_tick_extra.lua::tick extra > input budget reaches 2 per tick at 270 per s' 'tests/offline/test_tick_extra.lua::tick extra > extra tier visited every tick' 'tests/offline/test_perf.lua::perf > credits per visit keep tier rate over 800 ticks' 'tests/offline/test_perf.lua::perf > yellow box visited every 8 ticks' 'tests/offline/test_perf.lua::perf > turbo box visited every 2 ticks' 'tests/offline/test_guard.lua::guard > contract frozen' 'tests/offline/test_guard.lua::guard > names frozen'; do tools/run_tests.sh 2.0 \"$t\" || exit 1; done ) && echo lane025-tests-ok", "expect_exit": 0, "expect_regex": "lane025-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/belt_io.lua (body of `M.lane_rate` + one module-local cache table), scripts/tick.lua (rate line + two credit caps), tests/offline/test_tick_extra.lua. Never touch anything else.

Re-cut because: none

# bound: 2400s
