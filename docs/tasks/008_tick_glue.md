# 008 — tick glue (scripts/tick.lua), offline mocks

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-008_tick_glue`, branch `lane/008_tick_glue`, base tag `wave2-base`, merge target `int/v1`. Host `dev-vm`.

This task is complete in itself. Lane 009 runs in parallel on other files; you never need it.

## You have about 45 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** tick arities in `tests/offline/contract.lua` (`on_tick` 1, `on_research` 1, `timeout_ticks` 1); every file outside "Files this lane owns" byte-identical to `wave2-base`.

- Contract `docs/CONTRACT.md`: storage layout `:15-42` (`rec.enabled`, `out_credit`, `in_credit`, `next_poll` owned by tick), tick section `:138-144`. Every other module is real and merged: `scripts/core.lua` (pure; use it for real in tests), `scripts/belt_io.lua` (`pull(rec, budget, sink)`, `push(rec, lane, item, bss)`, `belt_stack_size(force)`; `docs/CONTRACT.md:84-86`), `scripts/circuit.lua` (`evaluate(rec) -> enabled, flush_now`; `:134`), `scripts/led.lua` (`set(rec, state, visible)`; `:93`). In tests replace `belt_io`, `circuit`, `led` functions with fakes; keep `core` real.
- `control.lua:62` routes `on_tick` → `tick.on_tick`; `:63-68` research events → `tick.on_research`.
- Tier rates `scripts/names.lua:13-16` (`N.TIER[tier].lane_rate` belt items per lane per tick: yellow 0.125, red 0.25, blue 0.375, turbo 0.5). Timeout map setting `settings.global[N.SETTING_TIMEOUT].value` seconds (0 = off).
- Decisions D-1 (reconcile: every tick for boxes a connected player has `opened`, every 60 ticks for all), D-3, Q-4 (disabled = input and output stop), Q-9 (LED hidden while disabled): `docs/DECISIONS.md`.
- Mocks: offline runner loads the test file in plain `lua5.2` with `package.path = "./?.lua;..."` (`tests/offline/run.lua:5`). Before requiring a module under test, set the globals it reads inside functions to plain tables: `defines = { direction = { north = 0, east = 4, south = 8, west = 12 }, inventory = { chest = 1 }, wire_connector_id = { circuit_red = 1, circuit_green = 2 } }`, `storage = { boxes = {}, belt_stack = {} }`, `settings = { global = { ["sushi-packer-flush-timeout"] = { value = 0 } } }`, `prototypes = { item = { ["iron-plate"] = { stack_size = 100 } } }`, `game = { connected_players = {} }`. Fake entities are tables with the fields and methods the code calls (`valid = true`, `unit_number`, `position`, `surface`, `force = { index = 1, belt_stack_size_bonus = 0 }`, `get_inventory = function() return inv end`). Reset globals in each test (no shared state between tests). Replace a collaborator by writing a field on its module table (`require("scripts.belt_io").pull = fake`) and restore it at test end.
- Offline runner: `describe`, `it`, `eq(found, expected, msg)` deep compare, `ok(cond, msg)` (`tests/offline/run.lua:10-34`); full name `<describe> > <it>`; missing name = exit 1.

## Explain very simply

Every tick, each box: ask circuit if on; pull from belt behind into storage (or 1-item hold for filtered items); release timed-out partials; push ready stacks out no faster than tier belt; set LED. Empty boxes nap 30 ticks. Chest inventory mirrors core counts; if player or inserter changes chest, core follows.

## What to build

`scripts/tick.lua` (call collaborators through their module tables at call time, e.g. `belt_io.pull(...)`, never cache function values, so tests can swap them):

1. `timeout_ticks(rec)`: `settings.timeout_mode == "custom"` → `timeout_s * 60`; else `settings.global[N.SETTING_TIMEOUT].value * 60`.
2. `on_research(e)`: force = `e.research and e.research.force or e.force`; `storage.belt_stack[force.index] = belt_io.belt_stack_size(force)`.
3. `on_tick(e)` for each `rec` in `storage.boxes` (boxes independent; order has no effect):
   1. `rec.entity.valid` false → remove rec, next. `e.tick < rec.next_poll` → next.
   2. `enabled, flush_now = circuit.evaluate(rec)`; `rec.enabled = enabled`. Not enabled → `led.set(rec, core.led_state(rec.box), false)`, next (N-3, Q-4, Q-9).
   3. `flush_now` → `core.flush_partials(rec.box, e.tick)`. Then `core.on_tick(rec.box, e.tick, timeout_ticks(rec))`.
   4. Intake: for lane 1, 2: `in_credit[l] = math.min(in_credit[l] + rate, 2)`; `budget[l] = math.floor(in_credit[l])`. Sink `(name, quality, lane, count)`: item matches a filter in `rec.settings.filters` (same name and (`filter.quality == nil` or same quality)) → return `core.accept(box, name, quality, lane, count, 1, e.tick, true)`; else `stack = prototypes.item[name].stack_size`, `n = core.accept(box, name, quality, lane, count, stack, e.tick, false)`, `n > 0` → `ins = inventory.insert({name=name, count=n, quality=quality})`, `ins < n` → `core.remove_external(box, name, quality, n - ins)`; return `ins`. `taken = belt_io.pull(rec, budget, sink)`; `in_credit[l] = in_credit[l] - taken[l]`.
   5. Output: `bss = storage.belt_stack[force.index]`, nil → `belt_io.belt_stack_size(force)` and store it. For lane 1, 2: `out_credit[l] = math.min(out_credit[l] + rate, 2)`; while `out_credit[l] >= 1`: `item = core.peek_out(box, l)`; nil → stop; `piece = {name, quality, count = math.min(item.count, bss)}`; `pushed = belt_io.push(rec, l, piece, bss)`; 0 → stop lane; not `item.passthrough` → `inventory.remove({name, count = pushed, quality})`; `core.take_out(box, l, pushed)`; `out_credit[l] = out_credit[l] - 1` (O-4, L-3, O-5).
   6. `led.set(rec, core.led_state(rec.box), true)`.
   7. Reconcile when some `game.connected_players[i].opened == rec.entity`, or `(e.tick + rec.unit_number) % 60 == 0`: per (name, quality) compare `inventory.get_contents()` (array of `{name, quality, count}`) with `core.totals(box)`; chest lower → `core.remove_external`; chest higher → `core.adopt_external(box, name, quality, diff, prototypes.item[name].stack_size, e.tick)`.
   8. `core.is_idle(box)` and nothing taken → `rec.next_poll = e.tick + 30`; else `rec.next_poll = 0`.

### Tests to write (exact names; each red against stub first)

File `tests/offline/test_tick.lua`, `describe("tick", ...)`, full name `tick > <it>`:

- `tick > timeout ticks custom and global`
- `tick > on research caches belt stack size`
- `tick > invalid entity drops rec`
- `tick > disabled box moves nothing and hides led`
- `tick > flush signal queues partials`
- `tick > intake budget follows tier rate`
- `tick > stored item goes to core and chest`
- `tick > filtered item goes to hold not chest`
- `tick > filter without quality matches any quality`
- `tick > output piece capped at belt stack size`
- `tick > output removes stored items from chest`
- `tick > passthrough output leaves chest alone`
- `tick > output rate never above tier rate`
- `tick > blocked lane does not stall other lane`
- `tick > led follows core state`
- `tick > opened box reconciles next tick`
- `tick > closed box reconciles every 60 ticks`
- `tick > idle box sleeps 30 ticks`
- `tick > belt stack computed when cache empty`

## Mocks for this lane

Fake inventory: table with `contents` list, `insertEllipsis` (returns inserted count, cap via a `limit` field for the short-insert case), `removeEllipsis`, `get_contents()`. Fake `belt_io.pull` feeds scripted `(name, quality, lane, count)` into the sink per lane, respecting `budget`, and returns taken counts; fake `belt_io.push` records pieces per lane and returns `piece.count` or 0 when that lane is marked blocked. Fake `circuit.evaluate` returns values set by the test. Fake `led.set` records `(state, visible)`.

## Test rule — read twice

**Lanes run offline Lua tests only (SP-02 v0.2).** Never start Factorio, never run `tests/game/*`, never `make test`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_tick.lua::tick > timeout ticks custom and global'
```

Game API is faked with plain Lua tables inside your test file (see "Mocks" above). Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane008-scope", "command": "git diff --name-only wave2-base HEAD | grep -Ev '^(scripts/tick\\.lua|tests/offline/test_tick\\.lua)$' | ( ! grep . ) && echo lane008-scope-ok", "expect_exit": 0, "expect_regex": "lane008-scope-ok", "timeout_s": 60}
{"name": "lane008-tests", "command": "( for t in 'timeout ticks custom and global' 'on research caches belt stack size' 'invalid entity drops rec' 'disabled box moves nothing and hides led' 'flush signal queues partials' 'intake budget follows tier rate' 'stored item goes to core and chest' 'filtered item goes to hold not chest' 'filter without quality matches any quality' 'output piece capped at belt stack size' 'output removes stored items from chest' 'passthrough output leaves chest alone' 'output rate never above tier rate' 'blocked lane does not stall other lane' 'led follows core state' 'opened box reconciles next tick' 'closed box reconciles every 60 ticks' 'idle box sleeps 30 ticks' 'belt stack computed when cache empty'; do tools/run_tests.sh 2.0 \"tests/offline/test_tick.lua::tick > $t\" || exit 1; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane008-tests-ok", "expect_exit": 0, "expect_regex": "lane008-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/tick.lua, tests/offline/test_tick.lua. Never touch anything else.

Re-cut because: none

# bound: 2700s

Reviewer ask: read `git diff wave2-base HEAD`; confirm each test asserts exact counts per lane (pushed pieces, chest contents, core totals), and the rate test runs many ticks and bounds the pushed count by `rate * ticks`.
