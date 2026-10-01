# 051 — lifecycle: items in arm hands are never lost

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-051_lifecycle`, branch `lane/051_lifecycle`, base tag `lanes-base-v16`, merge target `int/v16`. Host `dev-vm`.

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

Arms can hold a few items in hand. When player mines box or box dies, those items must come back like items in lane stores. One small change in two places.

## What to build

### Facts about current `scripts/registry.lua`

- `M.on_removed(e)`: `store_items(rec)` go to `e.buffer` (or are spilled when no buffer), then `arms.destroy(rec)`. `M.on_died(e)`: box contents and `store_items(rec)` spilled, then `arms.destroy(rec)`. Items held by arms are destroyed with the arms today (defect).
- Upgrade path (`M.stash(rec)`) keeps parts alive: no change. Rotate / upgrade / clone call `arms.create(rec)`, which saves hands itself from v16 on (lane 048): no change here.
- `M.on_configuration_changed` already calls `arms.ensure(rec)` for recs with stores: v15 saves get out arms there (lane 048 makes `ensure` see missing out arms): no change here, but pin it with a test.

### Tests first — extend `tests/offline/test_lifecycle_arms.lua` (describe `lifecycle arms`); each seen RED before code

Fake `arms.drain_hands` in fixture (recorder returning configurable list; default `{}`), and record call order against `arms.destroy`.

- `lifecycle arms > mined box returns items held by arms` — `drain_hands` returns `{ { name = "iron-plate", quality = "normal", count = 3, lane = 1 }, { name = "copper-plate", quality = "rare", count = 2, lane = 2 } }`: both inserted into `e.buffer` with name, count, quality, beside store items; `drain_hands` called before `arms.destroy`. RED.
- `lifecycle arms > mined box without buffer spills hand items` — no `e.buffer`: hand items spilled at box position like store items. RED.
- `lifecycle arms > died box spills items held by arms` — spilled with store items; `drain_hands` before `arms.destroy`. RED.
- `lifecycle arms > upgrade stash does not drain hands` — robot mine of box marked for upgrade: `drain_hands` not called. RED (after fake exists) or green by construction: then state so in report.
- `lifecycle arms > config change ensures parts of v15 rec` — rec with `stores` and no `box`: `arms.ensure(rec)` called once, `arms.create` not called directly. (May be green at base: pin.)

### Code — `scripts/registry.lua`

In `on_removed` (non-upgrade path) and `on_died`: `local held = arms.drain_hands(rec)` before `arms.destroy(rec)`; items join the same `e.buffer.insert` / `spill` handling as `store_items(rec)`. Nothing else.

### Mutation

Call `arms.destroy` before `arms.drain_hands` -> order assertion red; restore -> green. Never commit mutated state.


## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_lifecycle_arms.lua::lifecycle arms > mined box returns items held by arms'
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
{"name": "lane051-scope", "command": "git diff --name-only lanes-base-v16 HEAD | grep -Ev '^(scripts/registry\\.lua|tests/offline/test_lifecycle_arms\\.lua)$' | ( ! grep . ) && echo lane051-scope-ok", "expect_exit": 0, "expect_regex": "lane051-scope-ok", "timeout_s": 60}
{"name": "lane051-tests", "command": "( for t in 'mined box returns items held by arms' 'mined box without buffer spills hand items' 'died box spills items held by arms' 'upgrade stash does not drain hands' 'config change ensures parts of v15 rec'; do tools/run_tests.sh 2.0 \"tests/offline/test_lifecycle_arms.lua::lifecycle arms > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_lifecycle_arms.lua ) && echo lane051-tests-ok", "expect_exit": 0, "expect_regex": "lane051-tests-ok", "timeout_s": 300}
{"name": "lane051-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v16_keep_green.txt ) && echo lane051-keep-green-ok", "expect_exit": 0, "expect_regex": "lane051-keep-green-ok", "timeout_s": 1200}
```

## Files this lane owns

scripts/registry.lua, tests/offline/test_lifecycle_arms.lua. Never touch anything else.

Re-cut because: none

# bound: 2400s
