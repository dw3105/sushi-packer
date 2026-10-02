# 061 — flow: leftovers leave faster when lane store is nearly full (both ways)

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-061_flow`, branch `lane/061_flow`, base tag `lanes-base-v21`, merge target `int/v21`. Host `dev-vm`.

Lanes 059 gui (`scripts/gui.lua`) and 060 arms (`scripts/arms.lua`) run beside you. No shared file. Integrator works on `tests/game/*` and docs.

## You have about 50 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v21`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- Packer, very short: belt-kind body entity (`N.body(tier)`) plus hidden parts on same tile: two lane stores (`rec.stores[lane]`, inventory `rec.invs[lane]`, `N.STORE_SLOTS` slots = 24 since this seam, was 12), hidden in hands `rec.arms[lane]` (inserters `N.ARM`, take from belt lane behind, drop into lane store), mop hands `rec.mop[lane]`, out hands `rec.out[lane]` (take belt stacks from lane store, drop on front belt). Engine way = out hands work; script way (skip list set, or game without stacking) = out hands paused, script pushes stacks.
- Why: author on public v1.20: belt behind packer jerks. Measured cause and fix: `docs/FINDINGS.md` FND-0053. Seam constants already in `scripts/names.lua` (section "v21"): `N.STORE_SLOTS = 24`, `N.ARM_HANDS = { 1, 4, 4, 4 }`, `N.OUT_FAST = { speed = 0.3, n = 12 }`, `N.out_count(speed)`, `N.HOT_LOOK = 5`, `N.HOT_FREE = 3`, `N.PRESS = 1`.
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. Never add a key to a table while walking it with `pairs` (setting an existing key or setting a key to nil is fine). State only in `storage` / `rec` (plain values and engine object references). Engine objects are userdata: test validity with `part ~= nil and part.valid == true`, never `type(part) == "table"`.
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- Every engine call costs time: never repeat a write whose value did not change, never build tables per call on hot paths.

## Explain very simply

When belt carries more kinds than lane store has slots, store fills with leftovers (kinds with fewer items than one belt stack) and in hands stop. Leftovers leave too slowly. Two fixes, measured in game (FND-0053):
1. Engine way: packer with a steered lane whose store is nearly full gets a look every `N.HOT_LOOK` ticks instead of every 30.
2. Script way: when store is full and a new kind waits, `N.PRESS` oldest leftovers leave FIRST, also when full stacks wait (old rule: only when nothing else leaves).

## What to build

### Facts

- `scripts/tick.lua`: `engine_look(rec, tick, bss, flush_all)` per lane computes `used`, calls `ledger.scan`, then `local allowed = ledger.steer(rec.ledger, lane)` (non-nil = lane steered). `visit(rec, tick, script_mode, interval, counters)` calls `engine_look` for engine way. `build_sched()` returns `{ n, buckets, fast }`; `M.on_tick` walks `fast` (script way packers, every tick) then one bucket (`(tick + unit) % LOOK == 0` is the packer's own look tick, `LOOK = N.LOOK` = 30).
- `scripts/ledger.lua`: `M.plan(state, lane, contents, opts)` runs `plan_full` only when `complex or opts.flush_all or (cn == 0 and opts.slots_used >= opts.slots and opts.need_slot ~= false)` (`cn` = kinds with a full belt stack). `plan_full` output order: skip pieces, full stacks, flush_all / timed leftovers, then the pressure piece: one oldest leftover, only when `not priority_output and not timed_output and not flush_all and slots_used >= slots and need_slot ~= false`.
- Caller pushes pieces in list order and stops when front lane has no room, so only pieces at the head of the list are sure to leave.
- `scripts/ledger.lua` may `require("scripts.names")` at top (pure constants).

### Rule — ledger (script way)

- Pressure condition P: `not opts.flush_all and opts.slots_used >= opts.slots and opts.need_slot ~= false`.
- `M.plan`: runs `plan_full` whenever P holds (with or without full stacks), in addition to old reasons.
- `plan_full` under P and no timed leftover in this plan: up to `N.PRESS` pressure pieces are placed at the HEAD of the result (before skip pieces and full stacks), each = whole remainder of one kind (`count % size`, > 0, kind not on skip list). Order of choice: first kinds whose count is below one belt stack (they free a slot), oldest first (first-seen tick, then name, then quality: existing `before` order); only if none, kinds with a remainder above full stacks, same order. A kind chosen as pressure piece is not emitted again as a leftover in the same plan.
- Without P: output exactly as today. flush_all and timed rules unchanged.

### Rule — tick (engine way)

- In `engine_look`, lane is "hot" when `allowed ~= nil` (steered) and `used >= N.STORE_SLOTS - N.HOT_FREE`. After the look: `rec.hot = true` when any lane was hot, else `rec.hot = nil` (also nil when packer is stopped or has no front).
- `storage.sched.hot = { [unit] = true }`: set in `visit` after an engine look that left `rec.hot` true; `build_sched` fills it for every packer with `rec.hot` and stores.
- `M.on_tick`, after the `fast` walk and before the bucket: for each unit in `hot`: packer gone, no stores, `rec.hot` not true, or unit in `fast` -> remove from `hot`; else when `(tick + unit) % N.HOT_LOOK == 0` and `(tick + unit) % LOOK ~= 0` -> `visit(rec, tick, false, nil, counters)`.
- Never add a key to `hot` while walking it (a visit of the walked unit may set its own existing key again; that is fine). `storage.sched` may become nil during a visit (invalid entity): stop walking then.
- Packers that are not hot: zero extra work per tick beyond one `pairs` over an empty table.

### Tests first; each seen RED before code

In `tests/offline/test_ledger.lua` (describe `ledger v21`):
- `ledger v21 > full store with new kind waiting flushes oldest leftover first` — store full (slots_used = slots), need_slot true, contents: kind A 9 (belt stack 4, seen tick 10), kind B 1 (seen 20), kind C 3 (seen 30): plan = B 1 first, then A 4, A 4 (A remainder 1 stays).
- `ledger v21 > pressure flush prefers kind below one belt stack` — A 6 (seen 1), B 2 (seen 5): first piece B 2; with only A 6 and D 8: first piece A 2, then A 4, D 4, D 4.
- `ledger v21 > no pressure flush without need for a slot` — same contents, `need_slot = false` or slots_used < slots: only full stacks, old order.
- `ledger v21 > skip and timed pieces keep their rules` — skip kind still leaves whole; timed-out leftover present: no extra pressure piece; flush_all: everything, old order.
- `N.PRESS` swapped to 2 in test (restore after): two pressure pieces, oldest two below-stack kinds.

In `tests/offline/test_tick_look.lua` (describe `tick v21`):
- `tick v21 > pressured steered packer gets extra looks` — fake `ledger.steer` non-nil for lane 1 and store used 22 of 24: after its look, engine look runs again at every tick where `(tick + unit) % 5 == 0` (count looks over 30 ticks: 6).
- `tick v21 > extra looks stop when pressure is gone` — store used 10 or steer nil at a look: `rec.hot == nil`, removed from `storage.sched.hot`, next looks only every 30 ticks.
- `tick v21 > no extra look on own look tick` — at tick where `(tick + unit) % 30 == 0`: exactly one look.
- `tick v21 > script way packer never gets extra looks` — packer with skip list: not in `hot`.
- `tick v21 > schedule rebuild keeps hot packers` — `storage.sched = nil` with a packer whose `rec.hot == true`: after next tick it is in new `sched.hot`.

### Code — `scripts/ledger.lua`, `scripts/tick.lua`

As rules. No new public function (private helpers start with `_` or are local).

### Mutation

In `plan_full` append pressure pieces at the end instead of the head -> `full store with new kind waiting flushes oldest leftover first` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_ledger.lua::ledger v21 > full store with new kind waiting flushes oldest leftover first'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua <own file>`.

Keep-green list `tests/offline/fixtures/v21_keep_green.txt` (one `<file>::<name>` per line, tests in files no lane owns), run as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v21_keep_green.txt
```

Old tests in files you own that pin replaced behaviour (12 slots, old flush rule, 8 out hands on every belt): rewrite them to the new rule, never delete a still-true test, say in report which ones changed and why. Some tests in your files are red at base only because `N.STORE_SLOTS` is now 24: fix those too.

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `data.lua`, `scripts/names.lua`, `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fixtures/*`, anything under `tests/game/`, `tools/*`, `Makefile`. Never weaken a test to hide a defect. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v21..HEAD`, list of old tests rewritten.

## What done mean

```checks
{"name": "lane061-scope", "command": "git diff --name-only lanes-base-v21 HEAD | grep -Ev '^(scripts/ledger\\.lua|scripts/tick\\.lua|tests/offline/test_ledger\\.lua|tests/offline/test_ledger_look\\.lua|tests/offline/test_tick\\.lua|tests/offline/test_tick_extra\\.lua|tests/offline/test_tick_look\\.lua|tests/offline/test_tick_sleep\\.lua)$' | ( ! grep . ) && echo lane061-scope-ok", "expect_exit": 0, "expect_regex": "lane061-scope-ok", "timeout_s": 60}
{"name": "lane061-tests", "command": "( for t in 'ledger v21 > full store with new kind waiting flushes oldest leftover first' 'ledger v21 > pressure flush prefers kind below one belt stack' 'ledger v21 > no pressure flush without need for a slot' 'ledger v21 > skip and timed pieces keep their rules'; do tools/run_tests.sh 2.0 \"tests/offline/test_ledger.lua::$t\" || exit 1; done; for t in 'tick v21 > pressured steered packer gets extra looks' 'tick v21 > extra looks stop when pressure is gone' 'tick v21 > no extra look on own look tick' 'tick v21 > script way packer never gets extra looks' 'tick v21 > schedule rebuild keeps hot packers'; do tools/run_tests.sh 2.0 \"tests/offline/test_tick_look.lua::$t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_ledger.lua && lua5.2 tests/offline/run.lua tests/offline/test_ledger_look.lua && lua5.2 tests/offline/run.lua tests/offline/test_tick.lua && lua5.2 tests/offline/run.lua tests/offline/test_tick_extra.lua && lua5.2 tests/offline/run.lua tests/offline/test_tick_look.lua && lua5.2 tests/offline/run.lua tests/offline/test_tick_sleep.lua ) && echo lane061-tests-ok", "expect_exit": 0, "expect_regex": "lane061-tests-ok", "timeout_s": 600}
{"name": "lane061-guard", "command": "tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && echo lane061-guard-ok", "expect_exit": 0, "expect_regex": "lane061-guard-ok", "timeout_s": 120}
{"name": "lane061-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v21_keep_green.txt ) && echo lane061-keep-green-ok", "expect_exit": 0, "expect_regex": "lane061-keep-green-ok", "timeout_s": 1500}
```

## Files this lane owns

scripts/ledger.lua, scripts/tick.lua, tests/offline/test_ledger.lua, tests/offline/test_ledger_look.lua, tests/offline/test_tick.lua, tests/offline/test_tick_extra.lua, tests/offline/test_tick_look.lua, tests/offline/test_tick_sleep.lua. Never touch anything else.

Re-cut because: none

# bound: 3000s
