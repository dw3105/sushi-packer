# 040 — data: hidden arm + lane store prototypes

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-040_data`, branch `lane/040_data`, base tag `lanes-base-v15`, merge target `int/v14`. Host `dev-vm`.

Lanes 040 data (`prototypes/hidden.lua`), 041 ledger (`scripts/ledger.lua`), 042 arms (`scripts/arms.lua`), 043 gui (`scripts/gui.lua`), 044 tick (`scripts/tick.lua`), 045 lifecycle (`scripts/registry.lua`, `scripts/copy.lua`), 046 text (`locale/*`, texts) run beside you or after you. No shared file. Seam = `docs/CONTRACT.md` section "v15 arms box seam (V15-1)". Read it first, it is law: names, signatures, rec fields, who owns what.

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v15`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- New box, very short: hidden inserters ("arms"), each locked to one belt lane, drop items into hidden chest of that lane ("lane store", `N.STORE_SLOTS` = 12 slots). Engine moves items in. Script only pushes belt stacks out of each lane store onto same lane of front belt.
- Names in `scripts/names.lua`: `N.ARM`, `N.STORE`, `N.STORE_SLOTS`, `N.ARM_FILTERS`, `N.ARMS`.
- Stubs at base: `scripts/ledger.lua`, `scripts/arms.lua`, `prototypes/hidden.lua` (each lane fills its own; in your tests fake the others).
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API named in seam or already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. State only in `storage` / `rec` (plain values and engine object references).
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- `data.lua` line 5 already does `data:extend(require("prototypes.hidden").make())`.
- Probe-proven prototype shapes (`tests/env/sushi-packer-test-env/data-final-fixes.lua`, blocks `sp-test-arm`, `sp-test-arm-f`, `sp-test-r2-chest`): arm = `table.deepcopy(data.raw.inserter["bulk-inserter"])` with `allow_custom_vectors = true`, `chases_belt_items = false`, `uses_inserter_stack_size_bonus = false`, `stack_size_bonus = 11`, `bulk = true`, `rotation_speed = 0.5`, `extension_speed = 1`, `energy_source = { type = "void" }`, `energy_per_movement = "1J"`, `energy_per_rotation = "1J"`, `collision_mask = { layers = {} }`, `filter_count = 5`; store = `table.deepcopy(data.raw.container["steel-chest"])` with `collision_mask = { layers = {} }`.
- Offline data fixture: `tests/offline/fake_data.lua` (fake `data.raw`), used by `tests/offline/test_data.lua` top lines.
- Game without Space Age has `bulk-inserter` and `steel-chest` (base mod).

## Explain very simply

Box needs two kinds of hidden helper things: an arm and a small chest. Define them once, invisible, untouchable by player, so game can create them by script.

## What to build

### Tests first — new `tests/offline/test_data_hidden.lua`, describe `data hidden`; each seen RED before code

Fake `data.raw` with `inserter["bulk-inserter"]` and `container["steel-chest"]` plain tables (some sprite fields, `minable`, `next_upgrade`, `fast_replaceable_group`), global `table.deepcopy`, `util` only if you use it.

- `data hidden > makes arm and store` — `make()` returns exactly 2 prototypes named `N.ARM` (type `inserter`) and `N.STORE` (type `container`). RED at base.
- `data hidden > arm fields` — every field of the probe-proven arm list above, with `filter_count = N.ARM_FILTERS`. RED.
- `data hidden > store fields` — `inventory_size = N.STORE_SLOTS`, `collision_mask = { layers = {} }`, `se_allow_in_space = true`. RED.
- `data hidden > parts are hidden and untouchable` — both: `hidden = true`, `hidden_in_factoriopedia = true`, `selectable_in_game = false`, `minable == nil`, `next_upgrade == nil`, `fast_replaceable_group == nil`, `placeable_by == nil`, flags contain `placeable-off-grid`, `not-on-map`, `not-blueprintable`, `not-deconstructable`, `not-upgradable`, `not-flammable`, `no-automated-item-removal`, `no-automated-item-insertion` (store only: these two), `not-in-kill-statistics`; `allow_copy_paste = false`; `corpse`, `dying_explosion`, `open_sound`, `close_sound`, `working_sound` nil. RED.
- `data hidden > parts draw nothing` — arm: `draw_held_item = false`, `draw_inserter_arrow = false`, every picture field (`platform_picture`, `hand_base_picture`, `hand_open_picture`, `hand_closed_picture`, `hand_base_shadow`, `hand_open_shadow`, `hand_closed_shadow`) is a 1x1 empty sprite `{ filename = "__core__/graphics/empty.png", size = 1 }` or absent where engine allows; store: `picture` same empty sprite, `draw_circuit_wires = false`, `draw_copper_wires = false`, keeps `circuit_connector` + `circuit_wire_max_distance > 0` copied from steel chest. RED.
- `data hidden > source prototypes untouched` — `bulk-inserter` and `steel-chest` tables in fake `data.raw` unchanged after `make()` (deep compare with copy taken before). RED or green at base: say which.

### Code — `prototypes/hidden.lua`

`M.make()` per seam + tests. Comment at top: what parts are for, FND-0040 / FND-0042.

### Mutation

Drop `collision_mask` line of store -> `data hidden > store fields` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_data_hidden.lua::data hidden > makes arm and store'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua tests/offline/test_data_hidden.lua`.

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
{"name": "lane040-scope", "command": "git diff --name-only lanes-base-v15 HEAD | grep -Ev '^(prototypes/hidden\\.lua|tests/offline/test_data_hidden\\.lua)$' | ( ! grep . ) && echo lane040-scope-ok", "expect_exit": 0, "expect_regex": "lane040-scope-ok", "timeout_s": 60}
{"name": "lane040-tests", "command": "( for t in 'makes arm and store' 'arm fields' 'store fields' 'parts are hidden and untouchable' 'parts draw nothing' 'source prototypes untouched'; do tools/run_tests.sh 2.0 \"tests/offline/test_data_hidden.lua::data hidden > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_data_hidden.lua ) && echo lane040-tests-ok", "expect_exit": 0, "expect_regex": "lane040-tests-ok", "timeout_s": 300}
{"name": "lane040-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v15_keep_green.txt ) && echo lane040-keep-green-ok", "expect_exit": 0, "expect_regex": "lane040-keep-green-ok", "timeout_s": 900}
```

## Files this lane owns

prototypes/hidden.lua, tests/offline/test_data_hidden.lua (new). Never touch anything else.

Re-cut because: none

# bound: 1800s
