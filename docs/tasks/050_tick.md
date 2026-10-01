# 050 — tick: slow look for engine-mode boxes

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-050_tick`, branch `lane/050_tick`, base tag `lanes-base-v16`, merge target `int/v16`. Host `dev-vm`.

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

Until now script visited every box every few ticks and pushed every stack itself. Now out arms do that. Script visits a box once per 30 ticks, checks on/off, pushes out old leftovers, and updates the light. Boxes that use pass-through filters keep the old way.

## What to build

### Facts about current `scripts/tick.lua` (read it whole first)

- `M.on_tick(e)` loops `storage.boxes`; per due box: `circuit.evaluate(rec)`, `visit_lane(rec, lane, ...)` twice, idle nap, `update_led(rec)`. `visit_lane` = v15 script path (credit, `belt_io.can_push`, `get_contents`, `ledger.plan`, `ledger.hoard` + `arms.skip`, pushes). `drain_extra` pushes `rec.extra` items (old-save items in box container) first. `adopt_outside` runs once per 60 ticks. GUI refresh every 30 ticks. Counters `storage.sp_counters`.
- Offline tests `tests/offline/test_tick.lua`, `test_tick_extra.lua`, `test_tick_sleep.lua` build a rec with `settings.filters = {}` and fake `arms.pause`, `arms.skip`, `ledger.plan`, `ledger.hoard`, `belt_io.*`.

### Modes (seam "Two modes per box")

- `script mode` when `rec.settings.filters` has a first entry: run today's code path unchanged, plus `arms.pause_out(rec, 1, true)` and `arms.pause_out(rec, 2, true)` at each visit.
- `engine mode` otherwise: slow look below. On a look in engine mode after script mode: `arms.pause_out(rec, lane, <stopped>)` unpauses, `arms.skip(rec, lane, EMPTY)` clears hoard blacklist left on in arms (`arms.skip` is cheap when already empty).

### Tests first — each seen RED before code

1. Existing three test files describe today's script path. Make them script-mode tests with the smallest change: their fixture rec gets `settings.filters = { { name = "__never__" } }` (a pass-through filter for a kind that never appears) and a fake `arms.pause_out` recorder. Every existing test must stay green with unchanged expectations.
2. New file `tests/offline/test_tick_look.lua`, describe `tick look`. Fixture like `test_tick.lua` but `settings.filters = {}`, `rec.out = { {}, {} }`, `rec.unit_number = 30` (so a look is due at ticks 0, 30, 60 ...; tick 1 is not), fakes with call recorders: `belt_io.front_ok`, `belt_io.can_push`, `belt_io.push`, `belt_io.belt_stack_size`, `circuit.evaluate`, `ledger.scan` (returns configurable `flush, want`; copy `opts` because tick reuses it), `ledger.hands` (configurable), `ledger.plan` / `ledger.hoard` (must NOT be called in engine mode), `arms.pause`, `arms.pause_out`, `arms.hand`, `arms.held`, `arms.clear_held`, `arms.skip`, `arms.need_slot`, `led.set`.
   - `tick look > engine box is looked at once per N.LOOK ticks` — ticks 1..29: no `get_contents`, no `circuit.evaluate`; tick 30: one look (one `circuit.evaluate`, one `get_contents` per lane). RED.
   - `tick look > look never plans or hoards` — `ledger.plan`, `ledger.hoard` call counts 0; `belt_io.push` 0 when `scan` returns `{}`. RED.
   - `tick look > look sets hand and pauses` — `arms.hand(rec, 4)` called with force belt stack; enabled + front ok: `arms.pause(rec, lane, false)`, `arms.pause_out(rec, lane, false)`; circuit off: `pause(.., true)` and `pause_out(.., true)`, no `get_contents`; `rec.decon`: same; `belt_io.front_ok` false: `pause_out(.., true)` but `pause(.., false)` (box still fills), no pushes. RED.
   - `tick look > scan gets contents and options` — `ledger.scan` called per lane with that lane's contents and opts `tick`, `bss = 4`, `stack_size` function, `timeout_ticks` from `timeout_for(rec)`, `slots = N.STORE_SLOTS`, `slots_used` (slots estimate as in `visit_lane`), `flush_all` = second result of `circuit.evaluate`, `n_out = #rec.out[lane]`. RED.
   - `tick look > flush pieces are pushed and removed` — `scan` returns `{ iron 3, gear 1 }`: `belt_io.push(rec, lane, piece, 4)` for each in order, `inv.remove(piece)` after each success; first push returning 0 stops the lane (no remove, no further push). RED.
   - `tick look > hands are read only when wanted` — `want == false`: `arms.held` not called. `want == true`: `arms.held(rec, lane)` once, `ledger.hands(state, lane, held, opts)` once; for returned `{ 2, 5 }`: push `{ name, quality, count }` of those hands (hand quality string as given by `arms.held`), `arms.clear_held(rec, lane, k)` after each success; failed push -> no clear, stop. RED.
   - `tick look > need_slot only asked when store is full` — as `visit_lane`: `arms.need_slot` / `belt_io.behind_kinds` only when estimate says full and `count_empty_stacks() == 0`; result passed as `opts.need_slot`. RED.
   - `tick look > extra items leave first` — rec with `rec.extra` for lane 1: lane 1 `arms.pause(rec, 1, true)` and `arms.pause_out(rec, 1, true)`, extra pushed by existing `drain_extra` at v15 pace (box is visited by v15 interval rule while `rec.extra ~= nil`, not only every 30 ticks), no `ledger.scan` for lane 1 while extra remains; lane 2 looked at normally. RED.
   - `tick look > led and used slots` — `rec.used[lane]` = slots estimate; LED set through `ledger.led` / `led.set` only when state changes (existing `update_led`). RED.
   - `tick look > mode switch` — filters added: next visit runs script path and `arms.pause_out(rec, lane, true)`; filters removed: next look `arms.skip(rec, lane, {})` both lanes and `pause_out(.., false)`. RED.
   - `tick look > look reuses option table` — two looks: `ledger.scan` receives same `opts` table object. RED.
   - `tick look > counters count looks` — `storage.sp_counters.visits` + 1 per look; pushes counted by `belt_io.push` as today. RED.

### Code — `scripts/tick.lua`

Add engine-mode look beside `visit_lane` (keep `visit_lane`, `drain_extra`, `adopt_outside`, `update_led`, `M._interval`, `M._nap`, counters, GUI refresh). Due rule in `M.on_tick` for engine-mode box without `rec.extra`: `(tick + rec.unit_number) % N.LOOK == 0`; with `rec.extra`: today's rule (`rec.next_poll`, interval). `M.on_decon` pauses out arms too (`arms.pause_out`). Old recs without `rec.stores` are skipped as today. No table built per look except what engine calls return.

### Mutation

Call `ledger.plan` in engine mode -> `tick look > look never plans or hoards` red; restore -> green. Never commit mutated state.


## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_tick_look.lua::tick look > engine box is looked at once per N.LOOK ticks'
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
{"name": "lane050-scope", "command": "git diff --name-only lanes-base-v16 HEAD | grep -Ev '^(scripts/tick\\.lua|tests/offline/test_tick\\.lua|tests/offline/test_tick_extra\\.lua|tests/offline/test_tick_sleep\\.lua|tests/offline/test_tick_look\\.lua)$' | ( ! grep . ) && echo lane050-scope-ok", "expect_exit": 0, "expect_regex": "lane050-scope-ok", "timeout_s": 60}
{"name": "lane050-tests", "command": "( lua5.2 tests/offline/run.lua tests/offline/test_tick_look.lua && lua5.2 tests/offline/run.lua tests/offline/test_tick.lua && lua5.2 tests/offline/run.lua tests/offline/test_tick_extra.lua && lua5.2 tests/offline/run.lua tests/offline/test_tick_sleep.lua && tools/run_tests.sh 2.0 'tests/offline/test_tick_look.lua::tick look > look never plans or hoards' ) && echo lane050-tests-ok", "expect_exit": 0, "expect_regex": "lane050-tests-ok", "timeout_s": 300}
{"name": "lane050-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v16_keep_green.txt ) && echo lane050-keep-green-ok", "expect_exit": 0, "expect_regex": "lane050-keep-green-ok", "timeout_s": 1200}
```

## Files this lane owns

scripts/tick.lua, tests/offline/test_tick.lua, tests/offline/test_tick_extra.lua, tests/offline/test_tick_sleep.lua, tests/offline/test_tick_look.lua (new). Never touch anything else.

Re-cut because: none

# bound: 2400s
