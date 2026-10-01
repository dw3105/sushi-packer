# 039 — tick: sleeping boxes cost nothing, same behaviour

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-039_tick`, branch `lane/039_tick`, base tag `lanes-base-v14b`, merge target `int/v14`. Host `dev-vm`.

Lanes 037 (owns `scripts/core.lua`) and 038 (owns `scripts/belt_io.lua`) run beside you. No shared file. Facts about them you rely on: every `core.*` and `belt_io.*` signature and return value stays as in `docs/CONTRACT.md`. Signatures of `tick.*` stay as is (guard `contract frozen`).

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v14b`. For every box, on every tick: same `belt_io.pull` / `belt_io.push` calls with same arguments, same `core.*` calls, same inventory `insert` / `remove`, same `rec.next_poll`, `rec.last_poll`, `rec.in_credit`, `rec.out_credit`, same reconcile ticks, same `led.set` calls, as base. Only allowed difference: a destroyed box entity (`valid == false`) is dropped from `storage.boxes` on its next due visit or reconcile slot instead of next tick. Counters (`storage.sp_counters.visits`, functions `M.counters_on`, `M.counters`) unchanged.

- Measured (headless profile, 200 boxes, `docs/FINDINGS.md` FND-0038): work outside pull / push / core = 12 % of box script time on turbo row, 20 % on yellow row. It runs for every box on every tick, due or not.
- `scripts/tick.lua:79` loop over `storage.boxes`. For every box every tick: line 80 `rec.entity.valid`, line 83 `rec.entity.force`, then `force.index`, belt stack lookup, reconcile test `(e.tick + rec.unit_number) % 60 == 0` or opened box, poll gate lines 92-93 (`e.tick >= rec.next_poll`, first-visit stagger), and after gate line 166 `core.led_state(rec.box)` + compare with `rec.led.state` / `rec.led.visible`. Each `rec.entity.<field>` read and `force.index` read is an engine call.
- LED state can change only when box contents, `rec.enabled` or `rec.decon` change: in a visit, in reconcile, or in `M.on_decon` (line 187, sets `rec.decon`, `rec.next_poll = 0`).
- Per visit two closures are created: `inventory` line 101, `sink` line 114.
- Yellow box polls every 8 ticks, red 4, blue / turbo 2, extra tiers 1 (`INTERVAL`, line 8); idle box sleeps up to 30 ticks.
- Old saves: recs may lack any new field you add; build lazily. State only in `rec` / `storage` (plain values); prototype-derived upvalue caches like `stack_sizes` (line 9) are fine.
- Frozen baseline copy of this module at base: `tests/offline/fixtures/tick_v114.lua` (require as `tests.offline.fixtures.tick_v114`). Never edit it.
- Fixture pattern with fake `belt_io`, `circuit`, `led`: `tests/offline/test_tick.lua:8-46` (`fixture()`, `run(t, rec)`; `run` with `rec` forces `next_poll = 0`).
- No `require` inside functions, no `pairs` order deciding logic.

## Explain very simply

Every tick we wake every box and ask engine "are you alive, whose are you", even when box said "do not wake me for 8 ticks". Let sleeping boxes sleep: look at box only when its time comes, when its once-a-second check comes, when player has it open, or when its LED must change.

## What to build

### Tests first — new `tests/offline/test_tick_sleep.lua`, describe `tick sleep`; each seen RED before code (or said green at base)

Entity mock = proxy counting reads per key.

- `tick sleep > sleeping box costs no engine read` — box with `next_poll = 1000`, `last_poll` set, `unit_number` chosen so no reconcile slot falls in ticks 1..50; run ticks 1..50: entity reads total = 0, `led.set` calls = 0. RED at base (2+ reads per tick).
- `tick sleep > sleeping box still reconciles on its 60 tick slot` — same box, run ticks 1..120: inventory `get_contents` (reconcile) called exactly on ticks where `(tick + unit_number) % 60 == 0`. Green at base (preservation; say so).
- `tick sleep > opened sleeping box reconciles every tick` — `game.connected_players` has player with box opened (`opened_gui_type == defines.gui_type.entity`): reconcile each tick. Green at base (say so).
- `tick sleep > due box visited same tick as before` — `next_poll = 7`: `belt_io.pull` first called at tick 7, not before, not after. Green at base (say so).
- `tick sleep > decon mark hides led same tick` — sleeping box (`next_poll = 1000`); `tick.on_decon({entity = ...}, true)` then `on_tick`: `led.set` called with `visible = false` in that tick; cancel -> `visible = true` in next `on_tick`. Green at base (say so): must stay green after your change.
- `tick sleep > invalid entity dropped when due` — `valid = false`, `next_poll = 5`: rec gone after tick 5 at latest; and gone at its reconcile slot when sleeping longer. RED at base only for "no read before due" part: assert entity reads at ticks 1..4 = 0.
- `tick sleep > led set only on state change` — box visited each tick with unchanged contents: `led.set` calls stay 0 after first. Green at base (say so).
- `tick sleep > same trace as v114 tick` — differential test against `tests.offline.fixtures.tick_v114`: two identical worlds (own `storage`, 12 recs of tiers yellow / red / blue / turbo, scripted fake `belt_io.pull` feeding items by own integer generator, fake `belt_io.push` that blocks some ticks, real `scripts.core`); swap global `storage` between modules per tick; run 600 ticks; after each tick compare, per rec: `next_poll`, `last_poll`, `in_credit`, `out_credit`, `enabled`, list of pull / push calls with arguments, list of `led.set` calls, inventory contents, `core.totals`. Green at base. This is your safety net: run it after every edit.

### Code — `scripts/tick.lua`

- Box that is not due, not on reconcile slot, not opened, and whose LED needs no update: no engine read, no `core.led_state` call.
- LED update (`core.led_state` + `led.set`) only after visit, reconcile or decon change.
- No closure creation per visit (hoist `sink` / `inventory` state; keep same calls into `core` and inventory).

### Mutation

Skip reconcile for sleeping boxes -> `tick sleep > sleeping box still reconciles on its 60 tick slot` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of an existing test file. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_tick_sleep.lua::tick sleep > sleeping box costs no engine read'
```

Only whole-file run allowed: your own new file, `lua5.2 tests/offline/run.lua tests/offline/test_tick_sleep.lua`.

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
{"name": "lane039-scope", "command": "git diff --name-only lanes-base-v14b HEAD | grep -Ev '^(scripts/tick\\.lua|tests/offline/test_tick_sleep\\.lua)$' | ( ! grep . ) && echo lane039-scope-ok", "expect_exit": 0, "expect_regex": "lane039-scope-ok", "timeout_s": 60}
{"name": "lane039-tests", "command": "( for t in 'sleeping box costs no engine read' 'sleeping box still reconciles on its 60 tick slot' 'opened sleeping box reconciles every tick' 'due box visited same tick as before' 'decon mark hides led same tick' 'invalid entity dropped when due' 'led set only on state change' 'same trace as v114 tick'; do tools/run_tests.sh 2.0 \"tests/offline/test_tick_sleep.lua::tick sleep > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_tick_sleep.lua ) && echo lane039-tests-ok", "expect_exit": 0, "expect_regex": "lane039-tests-ok", "timeout_s": 300}
{"name": "lane039-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v14_keep_green.txt ) && echo lane039-keep-green-ok", "expect_exit": 0, "expect_regex": "lane039-keep-green-ok", "timeout_s": 600}
```

## Files this lane owns

scripts/tick.lua, tests/offline/test_tick_sleep.lua (new). Never touch anything else.

Re-cut because: none

# bound: 2400s
