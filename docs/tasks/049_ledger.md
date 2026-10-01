# 049 — ledger: slow-look rules

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-049_ledger`, branch `lane/049_ledger`, base tag `lanes-base-v16`, merge target `int/v16`. Host `dev-vm`.

Lanes 048 arms (`scripts/arms.lua`), 049 ledger (`scripts/ledger.lua`), 050 tick (`scripts/tick.lua`), 051 lifecycle (`scripts/registry.lua`) run beside you. No shared file. Seam = `docs/CONTRACT.md` section "v16 engine output seam (V16-1)". Read it first, it is law: names, signatures, rec fields, who owns what. Section "v15 arms box seam" above it still holds for everything v16 does not change.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v16`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- New box, very short: v15 box (hidden in arms pull items from belt lane into hidden lane store) plus hidden OUT arms: `N.OUT_ARMS` (8) inserters `N.OUT` per lane take from lane store and drop belt stacks onto same lane of front belt. Engine moves items in and out. Script looks at a box only once per `N.LOOK` (30) ticks.
- Facts proven in real game on 2.0 and 2.1 (`docs/FINDINGS.md` FND-0046): out arm takes last slot first; holds a partial hand until it is full (leftover waits in hand); `pickup_target` picks store; drop lane by `drop_position`; `inserter_stack_size_override` sets hand; `held_stack` readable, `.clear()` works.
- Stubs at base: new functions in `scripts/arms.lua` and `scripts/ledger.lua` are `error("stub: ...")` (each lane fills its own; in your tests fake the others).
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API named in seam or already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. State only in `storage` / `rec` (plain values and engine object references). Engine objects are userdata: test validity with `part ~= nil and part.valid == true`, never `type(part) == "table"`.
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- Every engine call costs time (about 1 microsecond): never repeat a write whose value did not change, never build tables per call on hot paths.

## Explain very simply

Out arms move full stacks by themselves. Script only needs two answers at each slow look: which leftovers in lane store must be pushed out now, and which arm hands holding leftovers must be emptied. This module answers both from plain data. No game calls.

## What to build

### Tests first — new `tests/offline/test_ledger_look.lua`, describe `ledger look`; each seen RED before code

Helpers in test: `c(name, count, quality)` -> `{ name =, quality = quality or "normal", count = }`; `opts(t)` with defaults `{ tick = 0, bss = 4, stack_size = function(name) return name == "tool" and 1 or 100 end, timeout_ticks = 300, slots = 12, slots_used = 1, need_slot = false, flush_all = false, n_out = 8 }` merged with `t`. State from `ledger.new()`; also test with state `{ seen = { {}, {} } }` (v15 save shape, no new tables).

- `ledger look > scan flushes nothing while leftover is young` — tick 0 contents `{ c("iron", 3) }`: flush `{}`; tick 299 same -> `{}`. RED.
- `ledger look > scan flushes leftover after timeout` — clock set at tick 0, tick 300 -> flush `{ { name = "iron", quality = "normal", count = 3 } }`; after that call the clock is gone (same contents at tick 301 -> `{}`, clock restarts at 301). RED.
- `ledger look > scan clock resets when kind reaches a stack or leaves` — iron 3 at tick 0; iron 7 at tick 100 (>= S) clears clock; iron 2 at tick 200 starts clock at 200 -> tick 499 `{}`, tick 500 flush 2. Kind gone at a look also clears clock. RED.
- `ledger look > scan never flushes full stacks` — `{ c("iron", 9) }`, `timeout_ticks = 1`, any tick: flush `{}` (out arms take them; rest shows up later as leftover). RED.
- `ledger look > scan timeout zero means off` — `timeout_ticks = 0`, leftover forever: `{}`. RED.
- `ledger look > scan flush_all flushes every leftover` — `{ c("iron", 3), c("copper", 9), c("gear", 1) }`, `flush_all = true`: flush = iron 3 and gear 1 (order: contents order), copper not. RED.
- `ledger look > scan need_slot flushes oldest leftover when store is full` — iron 3 seen tick 0, gear 1 seen tick 30; at tick 60 `need_slot = true, slots_used = 12`: flush `{ iron 3 }` only; with `slots_used = 11` -> `{}`; `need_slot = true` and no leftover (all kinds >= S) -> `{}`; same clock: tie broken by name then quality. RED.
- `ledger look > scan S uses item stack size` — `tool` (stack size 1): count 1 is a full belt stack (S = 1): never a leftover. RED.
- `ledger look > scan ready streak and want_hands` — sweep not due (`state.sweep[1] = 10000` set by a first `hands` call or directly): look with a kind `count >= S` -> ready 1, `want_hands == false`; second such look -> ready 2, `want_hands == true`; look with no such kind -> ready 0, false. `flush_all` -> true. `tick >= state.sweep[lane]` (or sweep unset) -> true. RED.
- `ledger look > scan lanes are separate` — clocks / ready of lane 1 never change lane 2. RED.
- `ledger look > scan reuses its tables` — two calls return same array object; pieces of a previous call may be overwritten (document in comment). RED.
- `ledger look > hands jam flushes every partial hand` — `state.ready[1] = 2`, `held` = 8 entries (arms 1..8), arms 3 and 6 partial (count 2 of S 4), others count 4: -> `{ 3, 6 }`. With only 7 entries in `held` (one arm free) and sweep not due -> `{}`. RED.
- `ledger look > hands sweep flushes hand stuck since previous sweep` — `timeout_ticks = 300`. Sweep 1 at tick 0: arm 2 holds iron 3 -> `{}`, memory arm 2 -> iron, `state.sweep[1] == 150`. Call at tick 100 (not due, ready 0) -> `{}` and memory unchanged. Sweep 2 at tick 150: arm 2 still iron 3 -> `{ 2 }`, memory of arm 2 cleared, sweep = 300. If at sweep 2 arm 2 holds copper 1 instead -> `{}` and memory arm 2 -> copper. Full hands never remembered. RED.
- `ledger look > hands sweep period` — `timeout_ticks = 60` -> next sweep `tick + 60` (floor 60); `timeout_ticks = 0` -> `tick + 600`, nothing flushed by sweep, memory emptied. RED.
- `ledger look > hands flush_all flushes all partial hands` — any ready, any sweep: partial hands of `held`, ascending. RED.
- `ledger look > hands result is ascending without duplicates and reused` — jam and sweep both name arm 3 -> `{ 3, ... }` once; same array object on next call. RED.

### Code — `scripts/ledger.lua`

Per seam table "scripts/ledger.lua (lane 049)" exactly. Replace the two stubs. Do not change `new`, `plan`, `hoard`, `led` (tests of `tests/offline/test_ledger.lua` stay green; you may run that file whole: you own it). Memory tables made lazily inside `scan` / `hands` (`state.left`, `state.ready`, `state.sweep`, `state.held`), each `{ <lane 1>, <lane 2> }`.

### Mutation

In `scan` use `>` instead of `>=` for timeout -> `scan flushes leftover after timeout` red; restore -> green. Never commit mutated state.


## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_ledger_look.lua::ledger look > scan flushes leftover after timeout'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua <own file>`.

Keep-green list `tests/offline/fixtures/v16_keep_green.txt` (one `<file>::<name>` per line), run as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v16_keep_green.txt
```

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `data.lua`, `scripts/names.lua`, `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fixtures/*`, anything under `tests/game/`, `tools/*`, `Makefile`. Never weaken a test to hide a defect. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v16..HEAD`.

## What done mean

```checks
{"name": "lane049-scope", "command": "git diff --name-only lanes-base-v16 HEAD | grep -Ev '^(scripts/ledger\\.lua|tests/offline/test_ledger\\.lua|tests/offline/test_ledger_look\\.lua)$' | ( ! grep . ) && echo lane049-scope-ok", "expect_exit": 0, "expect_regex": "lane049-scope-ok", "timeout_s": 60}
{"name": "lane049-tests", "command": "( lua5.2 tests/offline/run.lua tests/offline/test_ledger_look.lua && lua5.2 tests/offline/run.lua tests/offline/test_ledger.lua && tools/run_tests.sh 2.0 'tests/offline/test_ledger_look.lua::ledger look > scan flushes leftover after timeout' && tools/run_tests.sh 2.0 'tests/offline/test_ledger_look.lua::ledger look > hands jam flushes every partial hand' ) && echo lane049-tests-ok", "expect_exit": 0, "expect_regex": "lane049-tests-ok", "timeout_s": 300}
{"name": "lane049-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v16_keep_green.txt ) && echo lane049-keep-green-ok", "expect_exit": 0, "expect_regex": "lane049-keep-green-ok", "timeout_s": 1200}
```

## Files this lane owns

scripts/ledger.lua, tests/offline/test_ledger.lua, tests/offline/test_ledger_look.lua (new). Never touch anything else.

Re-cut because: none

# bound: 2400s
