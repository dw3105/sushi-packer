# 042 — arms: hidden parts of one box

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-042_arms`, branch `lane/042_arms`, base tag `lanes-base-v15`, merge target `int/v14`. Host `dev-vm`.

Lanes 040 data (`prototypes/hidden.lua`), 041 ledger (`scripts/ledger.lua`), 042 arms (`scripts/arms.lua`), 043 gui (`scripts/gui.lua`), 044 tick (`scripts/tick.lua`), 045 lifecycle (`scripts/registry.lua`, `scripts/copy.lua`), 046 text (`locale/*`, texts) run beside you or after you. No shared file. Seam = `docs/CONTRACT.md` section "v15 arms box seam (V15-1)". Read it first, it is law: names, signatures, rec fields, who owns what.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v15`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- New box, very short: hidden inserters ("arms"), each locked to one belt lane, drop items into hidden chest of that lane ("lane store", `N.STORE_SLOTS` = 12 slots). Engine moves items in. Script only pushes belt stacks out of each lane store onto same lane of front belt.
- Names in `scripts/names.lua`: `N.ARM`, `N.STORE`, `N.STORE_SLOTS`, `N.ARM_FILTERS`, `N.ARMS`.
- Stubs at base: `scripts/ledger.lua`, `scripts/arms.lua`, `prototypes/hidden.lua` (each lane fills its own; in your tests fake the others).
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API named in seam or already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. State only in `storage` / `rec` (plain values and engine object references).
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- Box directions: `rec.dir` = side items leave (`"north"|"east"|"south"|"west"`). Tile behind box = opposite side. Factorio map: north = y - 1, east = x + 1.
- Engine calls proven on both game versions (`docs/FINDINGS.md` FND-0040, FND-0042): exactly those named in seam table "scripts/arms.lua". `entity.active` must not be used (read-only on 2.1).
- `prototypes.entity[name].belt_speed` gives belt speed (tiles per tick); `N.TIER[rec.tier].belt` = belt name of tier (vanilla and mod tiers).
- Every engine write costs time: `pause` and `skip` are called every visit by lane 044 and must do nothing when state is unchanged.
- Old saves and partial failures: any `rec.stores[i]`, `rec.arms[i][k]` may be nil or `valid == false`.

## Explain very simply

Each box needs helpers on its tile: two small chests and some arms. This module puts them there, removes them, pauses them, and tells them which kinds to leave on belt. Nothing else touches them.

## What to build

### Tests first — new `tests/offline/test_arms.lua`, describe `arms`; each seen RED before code

Fake surface recording `create_entity` specs and returning entity tables (`valid = true`, `destroy()` sets `valid = false`, `get_inventory()` returns tagged table, `get_wire_connector(id, create)` returns connector with `connect_to` recorder, `set_filter` recorder; count writes of `disabled_by_script`, `use_filters`, `inserter_filter_mode` via proxy `__newindex`). Fake `prototypes.entity`, `defines.inventory.chest`, `defines.wire_connector_id`, `defines.wire_origin.script`.

- `arms > count from speed table` — 0.03125 -> 2; 0.0625 -> 4; 0.125 -> 4; 0.15625 -> 8; 0.5625 -> 8. RED.
- `arms > create makes two stores and n arms per lane` — turbo tier (speed 0.125): 2 `N.STORE` + 8 `N.ARM` at box position, same force; `rec.stores`, `rec.invs`, `rec.arms` filled; every part `destructible == false`. RED.
- `arms > arm setup per lane and direction` — for each of 4 `rec.dir`: `pickup_position` = centre of tile behind, `drop_position` = box position; lane 1 arms `pickup_from_left_lane = true`, `pickup_from_right_lane = false`, lane 2 reversed; `drop_target` = that lane's store. RED.
- `arms > wires join stores to box` — for red and green: each store connector `connect_to(box connector, false, defines.wire_origin.script)` once. RED.
- `arms > create reuses valid stores and replaces arms` — second `create` (other `rec.dir`): same store entities, old arms destroyed, new arms made, inventories untouched. Invalid store -> new one. RED.
- `arms > destroy` — `destroy(rec)` destroys arms + stores, clears `rec.arms`, `rec.stores`, `rec.invs`; `destroy(rec, true)` keeps stores + `rec.invs`. Nil / invalid parts do not error. RED.
- `arms > pause writes only on change` — `pause(rec, 1, true)` twice: `disabled_by_script` written once per arm of lane 1, lane 2 untouched; then `false` writes again. RED.
- `arms > skip sets blacklist only on change` — kinds `{ {name="iron-plate", quality="normal"} }`: each arm of lane: `use_filters = true`, `inserter_filter_mode = "blacklist"`, `set_filter(1, { name = "iron-plate", quality = "normal", comparator = "=" })`, slots 2..5 cleared with nil; same kinds again -> zero engine calls; `{}` -> `use_filters = false` and slots cleared; other lane untouched. RED.
- `arms > ensure rebuilds broken box` — all valid and count right -> false, no create; one arm invalid -> true and parts rebuilt; arm count wrong for tier -> true; no stores at all (old save rec) -> true. RED.
- `arms > create resets pause and skip memory` — after `create`, `rec.paused` = `{ false, false }`, `rec.skip` = `{ "", "" }` (new arms are unpaused, unfiltered). RED.

### Code — `scripts/arms.lua`

Per seam table "scripts/arms.lua" exactly.

### Mutation

Swap lane flags (lane 1 takes right lane) -> `arms > arm setup per lane and direction` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_arms.lua::arms > count from speed table'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua tests/offline/test_arms.lua`.

Keep-green list `tests/offline/fixtures/v15_keep_green.txt` (one `<file>::<name>` per line), run as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v15_keep_green.txt
```

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `data.lua`, `scripts/names.lua`, `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fixtures/*`, anything under `tests/game/`, `tools/*`, `Makefile`. Never weaken a test to hide a defect. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v15..HEAD`.

## What done mean

```checks
{"name": "lane042-scope", "command": "git diff --name-only lanes-base-v15 HEAD | grep -Ev '^(scripts/arms\\.lua|tests/offline/test_arms\\.lua)$' | ( ! grep . ) && echo lane042-scope-ok", "expect_exit": 0, "expect_regex": "lane042-scope-ok", "timeout_s": 60}
{"name": "lane042-tests", "command": "( for t in 'count from speed table' 'create makes two stores and n arms per lane' 'arm setup per lane and direction' 'wires join stores to box' 'create reuses valid stores and replaces arms' 'destroy' 'pause writes only on change' 'skip sets blacklist only on change' 'ensure rebuilds broken box' 'create resets pause and skip memory'; do tools/run_tests.sh 2.0 \"tests/offline/test_arms.lua::arms > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_arms.lua ) && echo lane042-tests-ok", "expect_exit": 0, "expect_regex": "lane042-tests-ok", "timeout_s": 300}
{"name": "lane042-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v15_keep_green.txt ) && echo lane042-keep-green-ok", "expect_exit": 0, "expect_regex": "lane042-keep-green-ok", "timeout_s": 900}
```

## Files this lane owns

scripts/arms.lua, tests/offline/test_arms.lua (new). Never touch anything else.

Re-cut because: none

# bound: 2400s
