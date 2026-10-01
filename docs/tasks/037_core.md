# 037 — core: cheaper box bookkeeping, same behaviour

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-037_core`, branch `lane/037_core`, base tag `lanes-base-v14b`, merge target `int/v14`. Host `dev-vm`.

Lanes 038 (owns `scripts/belt_io.lua`) and 039 (owns `scripts/tick.lua`) run beside you. No shared file. Every signature in `docs/CONTRACT.md` section "scripts/core.lua" stays as is (guard `contract frozen` pins arity).

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v14b`. Every public function of `scripts/core.lua` returns same values and leaves same box contents as base for every call sequence. Box stays plain data with same field names and same key strings (`partials`, `partial_by_key`, `ready`, `hold`, `used_slots`, `stored_count`, `sequence`, `lane_used`, `held`; keys `name .. "\0" .. quality .. "\0" .. lane`): boxes live in saved games, old saves must load. No function value in box.

- Measured (headless profile, 200 turbo boxes, `docs/FINDINGS.md` FND-0038): `core.accept` = 15 % of all box script time, `core.peek_out` + `core.take_out` + `core.on_tick` = 8 %. Called once per belt item: 350400 accepts in 1800 ticks.
- `scripts/core.lua:5` `partial_key` builds a new string by concat. One `accept` builds it 3 times for same (name, quality, lane): `item_room` line 124-128, `find_partial` line 40-43, `held_add` line 58-63.
- `scripts/core.lua:64` `add`: when partial fills, line 80 scans whole `box.partials` to find index of `p`, then `remove_partial` (line 24) concats key again.
- `scripts/core.lua:154` `peek_out` allocates a new table per call; `take_out` line 162-163 calls `peek_out` again only to learn `passthrough` and `count`.
- `ensure_counters` (line 47) and `ensure_partial_index` (line 8) run on every call; they do work only for boxes from old saves (fields missing).
- Frozen baseline copy of this module at base: `tests/offline/fixtures/core_v114.lua` (require as `tests.offline.fixtures.core_v114`). Never edit it.
- Memo table of key strings in an upvalue is allowed: pure function of (name, quality, lane), same on every client, holds no game state. No other upvalue state.
- Runs in Factorio Lua 5.2: no `require` inside functions, no `math.random`, no `pairs` order deciding logic.
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; `os.clock` available.

## Explain very simply

Box keeps a small ledger of items. Ledger is right but wasteful: builds same label three times per item, searches lists it could index, makes throwaway tables. Make ledger do same answers with less work.

## What to build

### Tests first — new `tests/offline/test_core_fast.lua`, describe `core fast`; each seen RED before code (or said green at base)

- `core fast > same trace as v114` — differential test. Own integer generator (no `math.random`): 20000 steps over two boxes, one from `scripts.core`, one from baseline. Each step picks an op: `accept` (5 item names, qualities `normal` / `rare`, lanes 1 / 2, count 1..4, stack_size 4, item_stack 100, sometimes `passthrough = true`), `peek_out` + `take_out` (n = 1..count), `on_tick` with timeout 0 or 600, `flush_partials`, `remove_external`, `adopt_external`, `hold_items` + `clear_hold`. After every step compare return values; every 500 steps compare `totals`, `used_slots`, `free_slots`, `led_state`, `is_idle`, `lane_room` both lanes, and box field `held` + `lane_used`. Errors must match too (`pcall` both). Green at base (preservation; say so). This is your safety net: run it after every edit.
- `core fast > keys built once per item` — expose test hook `core._key_builds()` returning count of key string constructions since load (counter increment only inside key construction, nothing else). 1000 accepts of same (name, quality, lane) with drains between -> hook grows by at most 1. RED at base (hook missing).
- `core fast > take out does not rebuild head table` — after `peek_out`, `take_out` must not call `M.peek_out` again: replace `core.peek_out` with counting wrapper, call `take_out`, count stays 0. RED at base.
- `core fast > full stack leaves partial list without scan` — box with 20 partials on lane 1 (20 item names); wrap `box.partials` in proxy counting index reads; fill last-added item to full stack; reads <= 4. RED at base (scan reads ~20).
- `core fast > faster than v114` — workload: 5 rounds, each 200000 accepts (5 names, 2 lanes, count 1..4 cycle, stack 4) with `peek_out` + `take_out` drain after each accept that made a ready stack; alternate baseline / new, `os.clock`, take min per module. Assert new_min <= 0.70 * baseline_min. RED at base (ratio ~1.0).

### Code — `scripts/core.lua`

Free hand inside the module within PRESERVE. Known waste listed in "What is true". Old-save migration (`ensure_counters`, `ensure_partial_index`) must keep working: tests `core > counters rebuilt for old box` and migration tests in keep-green list.

### Mutation

Make key memo return wrong lane for lane 2 -> `core fast > same trace as v114` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of an existing test file. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_core_fast.lua::core fast > same trace as v114'
```

Only whole-file run allowed: your own new file, `lua5.2 tests/offline/run.lua tests/offline/test_core_fast.lua`.

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
{"name": "lane037-scope", "command": "git diff --name-only lanes-base-v14b HEAD | grep -Ev '^(scripts/core\\.lua|tests/offline/test_core_fast\\.lua)$' | ( ! grep . ) && echo lane037-scope-ok", "expect_exit": 0, "expect_regex": "lane037-scope-ok", "timeout_s": 60}
{"name": "lane037-tests", "command": "( for t in 'same trace as v114' 'keys built once per item' 'take out does not rebuild head table' 'full stack leaves partial list without scan' 'faster than v114'; do tools/run_tests.sh 2.0 \"tests/offline/test_core_fast.lua::core fast > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_core_fast.lua ) && echo lane037-tests-ok", "expect_exit": 0, "expect_regex": "lane037-tests-ok", "timeout_s": 300}
{"name": "lane037-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v14_keep_green.txt ) && echo lane037-keep-green-ok", "expect_exit": 0, "expect_regex": "lane037-keep-green-ok", "timeout_s": 600}
```

## Files this lane owns

scripts/core.lua, tests/offline/test_core_fast.lua (new). Never touch anything else.

Re-cut because: none

# bound: 2400s
