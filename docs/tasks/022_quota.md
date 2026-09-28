# 022 — lane quota: each lane owns 24 of 48 slots (no starve)

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-022_quota`, branch `lane/022_quota`, base tag `lanes-base-v8`, merge target `int/v8`. Host `dev-vm`.

This task is complete in itself. Lane 023 (cap, function `M.item_room` in `scripts/core.lua`, file `tests/offline/test_core_cap.lua`) runs in parallel; you never need it and never touch its function or file.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua`; every file outside "Files this lane owns" byte-identical to `lanes-base-v8`; function `M.item_room` in `scripts/core.lua` byte-identical.

- Requirements v8 (`docs/REQUIREMENTS.md`, author 2026-09-28): L-2 each lane owns 24 slots (`N.SLOTS / 2`, `N.SLOTS = 48`); lane slot use = its partials + its ready stacks (each = 1 slot). L-3 blocked lane never stops other lane input or output. F-1 needs new slot and its lane's 24 used → flush oldest partial OF SAME LANE (oldest = smallest `first_tick`, tie smaller `sequence`), accept 0. F-4 all 24 slots of lane ready → that lane accepts 0, other lane unaffected. V-4 red = either lane full (its 24 slots used).
- Measured (FND-0019, dev-vm 2.0.77, code before v8): left output blocked → left ready stacks took all 48 slots → right lane drained 172 items early, 0 late. This lane fixes that.
- `scripts/core.lua` at `lanes-base-v8` already keeps counters: `box.lane_used = {n1, n2}` (partials + ready per lane) and `box.held` (per key), built lazily by local `ensure_counters(box)` (old saves). `add(...)` calls `ensure_counters` first. Stub `function M.lane_room(box, lane) return true end`. In `add`, new-slot branch today: `if limited and (box.used_slots >= N.SLOTS or not M.lane_room(box, lane)) then local oldest = oldest_partial(box) ... flush it ... return accepted end`. `oldest_partial(box)` searches both lanes today.
- `adopt_external` (inserter/player items, D-1) calls `add` with `limited=false`: may push lane 1 over 24. That lane then takes nothing new until drained; other lane must still get its own 24.
- `M.led_state(box)` today: red when `box.used_slots >= N.SLOTS`.
- Offline runner: `describe`, `it`, `eq(found, expected, msg)` deep compare, `ok(cond, msg)` (`tests/offline/run.lua`); full test name `<describe> > <it>`. Helper pattern: see top of `tests/offline/test_core.lua` (`accept(b, name, q, lane, n, size, tick, pass)`).

## Explain very simply

Box has 48 shelves. Today one lane can grab all 48, then other lane has nowhere to put things and stops. New rule: left lane gets 24 shelves, right lane gets 24. Left full → only left waits.

## What to build

1. `M.lane_room(box, lane)`: `true` when `box.lane_used[lane] < N.SLOTS / 2`. Must work when called on box without counters (call local `ensure_counters(box)` first).
2. In `add` new-slot branch: gate ONLY by `not M.lane_room(box, lane)` (drop the `box.used_slots >= N.SLOTS` clause — it lets one lane over 24 block other lane). Flush oldest partial of SAME lane only (change `oldest_partial` to take `lane`, or add lane filter). No partial on that lane → accept 0, flush nothing.
3. `M.led_state(box)`: red when `box.lane_used[1] >= N.SLOTS / 2 or box.lane_used[2] >= N.SLOTS / 2` (ensure counters first). Green/yellow unchanged.
4. `used_slots`, `free_slots`, `used_slots` counter keep today meaning (total over both lanes).

### Tests to write — new file `tests/offline/test_core_quota.lua`, `describe("quota", ...)`; each red against `lanes-base-v8` first

- `quota > blocked lane never takes 25th slot` — 30 ready stacks offered on lane 1 (count = stack): only 24 accepted; `b.lane_used[1] == 24`.
- `quota > other lane keeps 24 slots` — lane 1 full of 24 ready; lane 2 still accepts 24 new items of different names; 25th on lane 2 refused.
- `quota > flush picks oldest partial same lane` — oldest partial on lane 2 (tick 1), lane 1 full of 24 partials (ticks 2..25); new item on lane 1 → accept 0, lane 1 oldest (tick 2) queued ready, lane 2 partial untouched.
- `quota > led red when one lane full` — lane 1 at 24, lane 2 empty → `"red"`; one lane-1 stack taken out → `"yellow"`.
- `quota > old box over quota drains` — box built then `b.lane_used, b.held = nil, nil`, then `core.adopt_external` 30 distinct items (lane 1, over 24): lane 1 refuses new item; lane 2 accepts; after `take_out` until lane 1 below 24, lane 1 accepts again.

Existing tests that encode shared pool — you MAY rewrite these only (same name, new v8 rule): `core > full box flushes oldest partial and accepts zero`, `core > oldest partial chosen across lanes` (becomes: oldest of same lane), `core > all ready refuses input`. Every other existing test stays green unchanged.

## Test rule — read twice

**Lanes run offline Lua tests only.** Never start Factorio, never run `tests/game/*`, never `make test`, never `make zip`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_core_quota.lua::quota > blocked lane never takes 25th slot'
```

Game API never needed: `scripts/core.lua` is pure Lua. Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, any file not in "Files this lane owns", function `M.item_room`. Never change an existing function signature. Never weaken, skip or delete an existing test unless this task names it. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane022-scope", "command": "git diff --name-only lanes-base-v8 HEAD | grep -Ev '^(scripts/core\\.lua|tests/offline/test_core_quota\\.lua|tests/offline/test_core\\.lua)$' | ( ! grep . ) && echo lane022-scope-ok", "expect_exit": 0, "expect_regex": "lane022-scope-ok", "timeout_s": 60}
{"name": "lane022-tests", "command": "( for t in 'tests/offline/test_core_quota.lua::quota > blocked lane never takes 25th slot' 'tests/offline/test_core_quota.lua::quota > other lane keeps 24 slots' 'tests/offline/test_core_quota.lua::quota > flush picks oldest partial same lane' 'tests/offline/test_core_quota.lua::quota > led red when one lane full' 'tests/offline/test_core_quota.lua::quota > old box over quota drains' 'tests/offline/test_core.lua::core > full box flushes oldest partial and accepts zero' 'tests/offline/test_core.lua::core > oldest partial chosen across lanes' 'tests/offline/test_core.lua::core > all ready refuses input' 'tests/offline/test_core.lua::core > counters track partial and ready per lane' 'tests/offline/test_core.lua::core > counters rebuilt for old box' 'tests/offline/test_core.lua::core > used slots counts ready and partials' 'tests/offline/test_guard.lua::guard > contract frozen' 'tests/offline/test_guard.lua::guard > names frozen'; do tools/run_tests.sh 2.0 \"$t\" || exit 1; done ) && echo lane022-tests-ok", "expect_exit": 0, "expect_regex": "lane022-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/core.lua (functions `M.lane_room`, `M.led_state`, local `oldest_partial`, new-slot branch of local `add` only), tests/offline/test_core_quota.lua, tests/offline/test_core.lua (only the 3 named tests). Never touch anything else.

Re-cut because: none

# bound: 2400s
