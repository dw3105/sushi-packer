# 048 — arms: out arms of one box

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-048_arms`, branch `lane/048_arms`, base tag `lanes-base-v16`, merge target `int/v16`. Host `dev-vm`.

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

Box gets a second set of helpers: out arms. They take from lane store and put stacks on front belt. This module makes them, removes them, pauses them, sets their hand size, tells what they hold, and saves items held by arms before arms are destroyed.

## What to build

### Tests first — extend `tests/offline/test_arms.lua` (describe `arms`); each new test seen RED before code

Existing fake surface / entities there: extend entity fake with `held_stack` (`{ valid_for_read = bool, name =, count =, quality = { name = }, clear = function }` — `clear()` sets `valid_for_read = false`), writable `pickup_target`, `inserter_stack_size_override`, and box entity `get_inventory(defines.inventory.chest)` with `insert(stack) -> inserted count`; surface `spill_item_stack(spec)` recorder; store inventory `insert(stack) -> count` with settable room. Existing tests of this file must stay green (v15 behaviour of in arms unchanged).

- `arms > create makes out arms per lane` — turbo tier: besides v15 parts, `N.OUT_ARMS` entities `N.OUT` per lane at box position, same force, `destructible == false`; `rec.out[1]`, `rec.out[2]` filled; `rec.out_paused` = `{ false, false }`, `rec.hand == nil`. RED.
- `arms > out arm setup per lane and direction` — box at `{ x = 10.5, y = 20.5 }`, each of 4 `rec.dir`: `pickup_position` = box position, `pickup_target` = that lane's store; `drop_position`: north lane 1 `{ 10.25, 19.5 }`, lane 2 `{ 10.75, 19.5 }`; east lane 1 `{ 11.5, 20.25 }`, lane 2 `{ 11.5, 20.75 }`; south lane 1 `{ 10.75, 21.5 }`, lane 2 `{ 10.25, 21.5 }`; west lane 1 `{ 9.5, 20.75 }`, lane 2 `{ 9.5, 20.25 }` (formula in seam). RED.
- `arms > create saves hands of old arms` — second `create` while an old in arm of lane 1 holds 3 iron-plate and an old out arm of lane 2 holds 2 copper-plate (quality normal): items inserted into `rec.invs[1]` / `rec.invs[2]`; store takes only 1 of the 3 -> other 2 inserted into box container; box container takes 0 -> spilled via `surface.spill_item_stack` with `position` = box position and that stack; old arms destroyed after. No items -> no insert call. RED.
- `arms > destroy removes out arms` — `destroy(rec)` and `destroy(rec, true)`: out arms destroyed, `rec.out`, `rec.out_paused`, `rec.hand` nil; nil / invalid parts do not error; destroy never inserts or spills. RED.
- `arms > pause_out writes only on change` — like existing pause test, for out arms; in arms untouched; lane 2 untouched. RED.
- `arms > hand writes only on change` — `hand(rec, 4)`: every out arm of both lanes `inserter_stack_size_override = 4` once; again `hand(rec, 4)` -> zero writes; `hand(rec, 2)` writes again; in arms untouched; invalid arm skipped. RED.
- `arms > held lists out arm hands` — lane 1 arms 2 and 5 hold (`iron-plate`, normal, 3) and (`copper-plate`, rare, 4), others empty: `held(rec, 1)` -> `{ { arm = 2, name = "iron-plate", quality = "normal", count = 3 }, { arm = 5, name = "copper-plate", quality = "rare", count = 4 } }`; lane 2 -> `{}`; second call returns same list table (reused) with fresh content and no stale entries. RED.
- `arms > clear_held clears one hand` — `clear_held(rec, 1, 2)` calls `held_stack.clear()` of that arm only; invalid arm or index out of range -> no error. RED.
- `arms > drain_hands returns and clears all hands` — in arm lane 1 holds 3 iron-plate, out arm lane 2 holds 2 copper-plate: returns `{ { name = "iron-plate", quality = "normal", count = 3, lane = 1 }, { name = "copper-plate", quality = "normal", count = 2, lane = 2 } }` (in arms before out arms, lane 1 before lane 2), every such hand cleared; second call -> `{}`; `rec.arms == nil` or `rec.out == nil` -> no error. RED.
- `arms > ensure rebuilds when out arms missing` — v15 rec (valid stores + in arms, `rec.out == nil`) -> true and out arms made; all valid and counts right -> false, no create; one out arm invalid -> true; out arm count wrong -> true. RED.

### Code — `scripts/arms.lua`

Per seam table "scripts/arms.lua (lane 048)" exactly. Replace the five stubs. `create` wires stay as v15. Keep `count`, `pause`, `skip`, `need_slot` as they are.

### Mutation

Swap sign of `s` (lane 1 uses `-0.25`) -> `arms > out arm setup per lane and direction` red; restore -> green. Never commit mutated state.


## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_arms.lua::arms > create makes out arms per lane'
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
{"name": "lane048-scope", "command": "git diff --name-only lanes-base-v16 HEAD | grep -Ev '^(scripts/arms\\.lua|tests/offline/test_arms\\.lua)$' | ( ! grep . ) && echo lane048-scope-ok", "expect_exit": 0, "expect_regex": "lane048-scope-ok", "timeout_s": 60}
{"name": "lane048-tests", "command": "( for t in 'create makes out arms per lane' 'out arm setup per lane and direction' 'create saves hands of old arms' 'destroy removes out arms' 'pause_out writes only on change' 'hand writes only on change' 'held lists out arm hands' 'clear_held clears one hand' 'drain_hands returns and clears all hands' 'ensure rebuilds when out arms missing'; do tools/run_tests.sh 2.0 \"tests/offline/test_arms.lua::arms > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_arms.lua ) && echo lane048-tests-ok", "expect_exit": 0, "expect_regex": "lane048-tests-ok", "timeout_s": 300}
{"name": "lane048-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v16_keep_green.txt ) && echo lane048-keep-green-ok", "expect_exit": 0, "expect_regex": "lane048-keep-green-ok", "timeout_s": 1200}
```

## Files this lane owns

scripts/arms.lua, tests/offline/test_arms.lua. Never touch anything else.

Re-cut because: none

# bound: 2400s
