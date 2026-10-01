# 044 — tick: visit loop on lane stores

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-044_tick`, branch `lane/044_tick`, base tag `lanes-base-v15`, merge target `int/v14`. Host `dev-vm`.

Lanes 040 data (`prototypes/hidden.lua`), 041 ledger (`scripts/ledger.lua`), 042 arms (`scripts/arms.lua`), 043 gui (`scripts/gui.lua`), 044 tick (`scripts/tick.lua`), 045 lifecycle (`scripts/registry.lua`, `scripts/copy.lua`), 046 text (`locale/*`, texts) run beside you or after you. No shared file. Seam = `docs/CONTRACT.md` section "v15 arms box seam (V15-1)". Read it first, it is law: names, signatures, rec fields, who owns what.

## You have about 45 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v15`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- New box, very short: hidden inserters ("arms"), each locked to one belt lane, drop items into hidden chest of that lane ("lane store", `N.STORE_SLOTS` = 12 slots). Engine moves items in. Script only pushes belt stacks out of each lane store onto same lane of front belt.
- Names in `scripts/names.lua`: `N.ARM`, `N.STORE`, `N.STORE_SLOTS`, `N.ARM_FILTERS`, `N.ARMS`.
- Stubs at base: `scripts/ledger.lua`, `scripts/arms.lua`, `prototypes/hidden.lua` (each lane fills its own; in your tests fake the others).
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API named in seam or already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. State only in `storage` / `rec` (plain values and engine object references).
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- Today `scripts/tick.lua` `M.on_tick` (line ~92): per box poll gate (`rec.next_poll`, tier cadence `INTERVAL` line 8, first-visit stagger), reconcile slot `(tick + unit_number) % 60 == 0` or opened box, circuit (`circuit.evaluate(rec) -> enabled, flush_now`), then pull via `belt_io.pull` + old `core`, then push loop with `rec.out_credit[lane]` (rate `belt_io.lane_rate(rec.tier)`, cap `max(2, 2 * rate)`, credit += rate * elapsed), LED (`update_led`), counters, `M.on_decon`, `M.timeout_ticks`, `M.on_research`, `M.counters_on`, `M.counters`. Sleeping-box rule (no engine read for a box that is not due) must stay.
- New visit per seam section "tick visit": no `belt_io.pull`, no `scripts.core` use for boxes with `rec.stores`. Inventory calls allowed per lane visit: `inv.is_empty()`, `inv.get_contents()`, `inv.remove(piece)`, `#inv - inv.count_empty_stacks()`.
- `belt_io.push(rec, lane, { name=, quality=, count= }, bss) -> pushed` (0 = lane blocked or no front belt). `bss` = `storage.belt_stack[force.index]` as today.
- Skip-list rule: `rec.settings.filters` with `filter.match(filters, name, quality, levels())` (today inside `sink`, lines 75-80): pass as `opts.skip`.
- Extra items (old saves): `rec.extra` entries live in box container `rec.entity.get_inventory(defines.inventory.chest)`; lane with extra entries: arms paused, its extra pieces pushed first (pieces of N, last smaller), removed from box container and from entry; entry at 0 removed; `rec.extra = nil` when empty.
- Recs of old saves not yet migrated (`rec.stores == nil`): skip visit (lane 045 migrates on configuration change).
- Idle: both lane inventories empty and no extra -> next poll in 15 ticks; else tier cadence (`INTERVAL[rec.tier] or 2`; minimum 2).
- Old tests in your files pin pull-based internals: rewrite them to new seam; a behaviour that still exists (decon stop, circuit off pause, flush signal, timer, credits / rate cap, LED change only, sleeping box, counters, research cache, invalid entity drop) keeps a test. List every deleted test with reason in report.

## Explain very simply

Old loop took items off belt by hand. New loop does not: arms fill two small chests. Loop only looks into each chest, asks ledger what may leave, and pushes those stacks onto front belt, same lane. It also pauses arms when box is switched off.

## What to build

### Tests first — new describe `tick arms` in `tests/offline/test_tick.lua` (rewrite file as needed); each seen RED before code

Fake `rec.invs[lane]` (inventory table with `get_contents`, `remove`, `is_empty`, `count_empty_stacks`, `#`), fake `ledger`, `arms`, `belt_io.push`, `circuit.evaluate`, `led.set` by swapping module functions (pattern: today's `fixture()`).

- `tick arms > pushes ledger pieces on own lane and removes them` — ledger returns iron 4, iron 4 for lane 1: two `belt_io.push(rec, 1, piece, bss)`, two `inv.remove`, lane 2 untouched. RED.
- `tick arms > stops at blocked lane` — push returns 0 on second piece: one remove; next visit plans again. RED.
- `tick arms > rate cap by credit` — yellow box: no more belt items per lane than `lane_rate * elapsed` allows (same numbers as today's `output never faster than tier` case). RED.
- `tick arms > passes rules to ledger` — `opts.tick`, `bss`, `timeout_ticks` (`M.timeout_ticks(rec)`), `slots = N.STORE_SLOTS`, `slots_used` from inventory, `flush_all` true on visit where `circuit.evaluate` returns flush, `skip` true for skip-list item, `stack_size` from `prototypes.item`. RED.
- `tick arms > circuit off pauses both lanes` — `enabled = false`: `arms.pause(rec, 1, true)`, `(rec, 2, true)`, no push; enabled again: pause false. Same for `rec.decon`. RED.
- `tick arms > hoard kinds go to arms` — `arms.skip(rec, lane, ledger.hoard(contents, stack_size))` each lane visit. RED.
- `tick arms > extra leaves first and pauses its lane` — `rec.extra = { {name="iron-plate", quality="normal", count=9, lane=1} }`, box container holds them: lane 1 paused, pieces 4, 4, 1 pushed from box container before any store piece; then `rec.extra == nil`, lane 1 unpaused. Lane 2 runs normally meanwhile. RED.
- `tick arms > led from used slots` — `led.set` called with `ledger.led(used1, used2, N.STORE_SLOTS)` only when state or visibility changes. RED.
- `tick arms > empty box sleeps 15 ticks` and `tick arms > sleeping box costs no engine read` — as named. RED / keep.
- `tick arms > unmigrated rec skipped` — `rec.stores == nil`: no error, no push. RED.
- `tick arms > counters` — on: `visits` per due visit, `pushes` per belt item, `items_out` and `items_in` += pushed count. RED.

### Code — `scripts/tick.lua`

Per seam. Remove `scripts.core` and `belt_io.pull` use from visit. Keep `M.on_research`, `M.timeout_ticks`, `M.on_decon`, `M.counters_on`, `M.counters` signatures.

### Mutation

Push extra after store pieces -> `tick arms > extra leaves first and pauses its lane` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_tick.lua::tick arms > pushes ledger pieces on own lane and removes them'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua tests/offline/test_tick.lua`.

Keep-green list `tests/offline/fixtures/v15_keep_green.txt` (one `<file>::<name>` per line), run as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v15_keep_green.txt
```

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `data.lua`, `scripts/names.lua`, `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fixtures/*`, anything under `tests/game/`, `tools/*`, `Makefile`. Checks also run whole files you own: keep every remaining test in them green. Never weaken a test to hide a defect. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v15..HEAD`.

## What done mean

```checks
{"name": "lane044-scope", "command": "git diff --name-only lanes-base-v15 HEAD | grep -Ev '^(scripts/tick\\.lua|tests/offline/test_(tick|tick_extra|tick_sleep|counters|perf|perf2)\\.lua)$' | ( ! grep . ) && echo lane044-scope-ok", "expect_exit": 0, "expect_regex": "lane044-scope-ok", "timeout_s": 60}
{"name": "lane044-tests", "command": "( for t in 'pushes ledger pieces on own lane and removes them' 'stops at blocked lane' 'rate cap by credit' 'passes rules to ledger' 'circuit off pauses both lanes' 'hoard kinds go to arms' 'extra leaves first and pauses its lane' 'led from used slots' 'empty box sleeps 15 ticks' 'sleeping box costs no engine read' 'unmigrated rec skipped' 'counters'; do tools/run_tests.sh 2.0 \"tests/offline/test_tick.lua::tick arms > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_tick.lua ) && echo lane044-tests-ok", "expect_exit": 0, "expect_regex": "lane044-tests-ok", "timeout_s": 300}
{"name": "lane044-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v15_keep_green.txt ) && echo lane044-keep-green-ok", "expect_exit": 0, "expect_regex": "lane044-keep-green-ok", "timeout_s": 900}
```

## Files this lane owns

scripts/tick.lua, tests/offline/test_tick.lua, tests/offline/test_tick_extra.lua, tests/offline/test_tick_sleep.lua, tests/offline/test_counters.lua, tests/offline/test_perf.lua, tests/offline/test_perf2.lua (rewrite / delete tests of removed behaviour; list each in report). Never touch anything else.

Re-cut because: none

# bound: 2700s
