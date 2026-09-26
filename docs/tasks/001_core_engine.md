# 001 — core engine: pure accumulate/release engine (scripts/core.lua)

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-001_core_engine`, branch `lane/001_core_engine`, base tag `lanes-base`, merge target `int/v1`. Host `legalcopilot-dev`.

This task is complete in itself. Other modules are built by other lanes against the same frozen contract; you never need them.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua:3-8` (core arities); every file outside "Files this lane owns" byte-identical to `lanes-base`.

- Contract text for this module: `docs/CONTRACT.md:56-76`. Module rules (no game globals, no `pairs` order in logic, plain tables only): `docs/CONTRACT.md:5-11`.
- Requirements this lane implements: `docs/REQUIREMENTS.md` §3 (C-1..C-5), §4 (L-2), §5 (F-1..F-4), §8 (P-2, P-3), §7 (S-1), §6 (O-2, O-5), §12 (V-2..V-5). Decisions Q-3, Q-5, D-1, D-3: `docs/DECISIONS.md`.
- `scripts/core.lua` is a generated stub: every function `error("stub: core.<fn>")`.
- `scripts/names.lua:8` `N.SLOTS = 48`. Core may `require("scripts.names")` (plain table, no game globals).
- Offline runner `tests/offline/run.lua`: globals `describe(name, fn)`, `it(name, fn)` (`:10-17`), `eq(found, expected, msg)` deep compare (`:29`), `ok(cond, msg)` (`:34`). Full test name = describe names and it name joined by " > ". Named test not found = exit 1 (`:46`).
- Interpreter `lua5.2` only (`/usr/bin/lua5.2`, 5.2.4). No network needed.

## Explain very simply

Box keeps a count per (item, quality, lane). Count grows. When count hits item stack size, that stack is "ready" and waits in the lane's line to leave. Box has 48 slots; every partial and every ready stack takes one. When full, oldest partial gets pushed to the line early. Filtered items skip storage: they sit in a 1-item hold per lane and leave between stacks.

## What to build

`scripts/core.lua`, all functions of `docs/CONTRACT.md:56-76`, exact semantics:

1. Data: `box` holds only plain tables/numbers/strings/booleans. Partials in one array ordered by first arrival (`first_tick`, then insertion sequence). Ready queue per lane: array, FIFO. Hold per lane: `nil` or `{name, quality, count}`. Keep running counters (used slots, stored item count) so `used_slots`, `led_state`, `is_idle` do no scan (V-5).
2. Slot rule (L-2): each partial = 1 slot (a partial never reaches `stack_size`); each ready stack = 1 slot whatever its count. Hold = 0 slots (P-2).
3. `accept(..., passthrough=false)`: key = (name, quality, lane). Partial for key exists → add to it; else a new partial needs 1 free slot. Partial reaching `stack_size` becomes ready (appended to `ready[lane]`, C-3/C-4); leftover of same call starts a new partial (C-5), again needing 1 free slot. Accept as much as fits; return accepted count.
   - Needed slot and `free_slots == 0`: any partial exists → move oldest partial (earliest `first_tick`, both lanes, F-1) to back of its lane ready queue (F-2) and return accepted-so-far (0 when nothing went in). No partial (all ready, F-4) → return accepted-so-far.
4. `accept(..., passthrough=true)`: `hold[lane] == nil` → store `{name, quality, count}`, return `count`; else return 0.
5. `peek_out(box, lane)`: head = `ready[lane][1]`. Head exists and `head.started` → `{name, quality, count=remaining, passthrough=false}`. Else `hold[lane]` → hold item, `passthrough=true`. Else head → head remaining, `passthrough=false`. Else `nil`. Fresh table each call.
6. `take_out(box, lane, n)`: acts on exactly what `peek_out` returns now. Stack: subtract `n`, mark `started`; at 0 pop it (slot freed). Hold: subtract; at 0 set `nil`. `n` above remaining → `error`.
7. `on_tick(box, tick, timeout_ticks)`: `timeout_ticks == 0` → nothing. Else every partial with `first_tick + timeout_ticks <= tick` moves to its lane ready queue, first-arrival order (S-1, Q-3).
8. `flush_partials(box, tick)`: every partial to its lane ready queue, first-arrival order (N-4, Q-5; holds untouched).
9. `remove_external(box, name, quality, n)`: take from partials of (name, quality), newest `first_tick` first (either lane), then ready stacks of (name, quality) from back of queues (latest readied first across lanes). Emptied entries removed. Return removed count (≤ n).
10. `adopt_external(box, name, quality, n, stack_size, tick)`: add as lane-1 arrival by rule 3, never flushing, ignoring 48 limit (items already sit in chest). Return `n`.
11. `hold_items(box)`: array of hold items, lane 1 then lane 2. `clear_hold(box)`: both holds `nil`.
12. `totals(box)`: partials + ready (not hold), summed across lanes per (name, quality), array sorted by name then quality.
13. `led_state(box)`: `used_slots >= 48` → `"red"`; `is_idle` → `"green"`; else `"yellow"`.
14. `is_idle(box)`: no partial, no ready stack, both holds `nil`.
15. `new_box()`: empty box.

### Tests to write (exact names; each red against stub first)

File `tests/offline/test_core.lua`, one `describe("core", ...)`; full name = `core > <it name>`:

- `new box is idle and green`
- `same item on two lanes keeps two buffers` (C-1, L-2: 10 iron lane 1 + 10 iron lane 2 → `used_slots == 2`)
- `quality is separate buffer` (C-1)
- `full stack becomes ready on its lane` (C-2, C-3: stack 50, 50 accepted → `peek_out(lane)` count 50, other lane `nil`)
- `ready stacks leave in ready order` (C-4)
- `arrival after ready starts new partial` (C-5)
- `accept splits across ready and new partial` (60 into empty key, stack 50 → 1 ready + partial 10, used 2)
- `used slots counts ready and partials` (L-2)
- `full box flushes oldest partial and accepts zero` (F-1, F-2, F-3)
- `oldest partial chosen across lanes` (F-1)
- `all ready refuses input` (F-4)
- `passthrough uses hold not slots` (P-2)
- `hold busy refuses second passthrough` (P-3)
- `hold waits while stack run started` (P-3, O-2)
- `hold goes before unstarted stack` (P-3)
- `take out last piece may be small` (O-5: 50 ore, pieces of 4 → 12×4 + 1×2)
- `timeout flushes old partial only` (S-1, Q-3)
- `timeout zero is off` (S-1)
- `flush partials queues all in arrival order` (N-4)
- `remove external takes newest partial first` (D-1)
- `adopt external lands on lane one` (D-1)
- `led yellow with items and red when full` (V-3, V-4)
- `totals sums lanes sorted`
- `box is plain data` (walk box: only table/number/string/boolean values)

## Test rule — read twice

**NEVER run `make test`, `tools/run_tests.sh <v> --full`, `lua5.2 tests/offline/run.lua <file>` without a test name, or any full, file-wide or dir-wide suite.** Run only single tests, one at a time:

```
make test-one FV=2.0 T='tests/offline/test_core.lua::core > <it name>'
```

Write each new test first and see it fail against the stub before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/game/*`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`. Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit on your branch. Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane001-scope", "command": "git diff --name-only lanes-base HEAD | grep -Ev '^(scripts/core\\.lua|tests/offline/test_core\\.lua)$' | ( ! grep . ) && echo lane001-scope-ok", "expect_exit": 0, "expect_regex": "lane001-scope-ok", "timeout_s": 60}
{"name": "lane001-tests", "command": "for t in 'new box is idle and green' 'same item on two lanes keeps two buffers' 'quality is separate buffer' 'full stack becomes ready on its lane' 'ready stacks leave in ready order' 'arrival after ready starts new partial' 'accept splits across ready and new partial' 'used slots counts ready and partials' 'full box flushes oldest partial and accepts zero' 'oldest partial chosen across lanes' 'all ready refuses input' 'passthrough uses hold not slots' 'hold busy refuses second passthrough' 'hold waits while stack run started' 'hold goes before unstarted stack' 'take out last piece may be small' 'timeout flushes old partial only' 'timeout zero is off' 'flush partials queues all in arrival order' 'remove external takes newest partial first' 'adopt external lands on lane one' 'led yellow with items and red when full' 'totals sums lanes sorted' 'box is plain data'; do tools/run_tests.sh 2.0 \"tests/offline/test_core.lua::core > $t\" || exit 1; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' && echo lane001-tests-ok", "expect_exit": 0, "expect_regex": "lane001-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/core.lua, tests/offline/test_core.lua. Never touch anything else.

Re-cut because: none

# bound: 2400s

Reviewer ask: read `git diff lanes-base HEAD` in full; confirm every test asserts what its name promises (numbers, lanes, order), no test only checks "no error", and core touches no game global.
