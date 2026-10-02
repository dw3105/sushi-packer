# 058 — data: packer body shows hood in ghosts and blueprints, no wire frame

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-058_data`, branch `lane/058_data`, base tag `lanes-base-v20`, merge target `int/v17`. Host `dev-vm`.

Lanes 057 gui (`scripts/gui.lua`) and 058 data (`prototypes/tier.lua`) run beside you; integrator works on `scripts/ledger.lua`, `scripts/arms.lua`, `scripts/tick.lua`. No shared file. Background: `docs/CONTRACT.md` section "v17 belt body seam (V17-1..5)" and its amendments (packer = belt-kind body + hidden parts).

## You have about 45 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v20`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- Packer, very short: belt-kind body entity (`N.body(tier)`, prototype type `transport-belt`) plus hidden parts on same tile: two lane stores (`rec.invs[lane]`, 12 slots), hidden inserters, hood picture entity (`N.hood(tier)`).
- These are bug fixes reported by author on public v1.19 (2026-10-02).
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API named in seam or already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. State only in `storage` / `rec` (plain values and engine object references). Engine objects are userdata: test validity with `part ~= nil and part.valid == true`, never `type(part) == "table"`.
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- Every engine call costs time: never repeat a write whose value did not change, never build tables per call on hot paths.

## Explain very simply

In a blueprint or as a ghost the packer shows as bare belt with a yellow wire frame: game draws that frame on every belt that has circuit / logistic settings, and belt kind has no picture of its own. Fix: body gets no frame sprites, and hood picture becomes a second layer of body belt picture, so ghost and blueprint show the hood.

## What to build

### Facts

- `prototypes/tier.lua` `M.make(tier, opts)`: `body = table.deepcopy(source_belt)` then fields; `picture(tier, dir)` returns `{ layers = { main png, shadow png } }` for dir in north, east, south, west; main file = `G .. "entity/sushi-packer/" .. tier .. "/sushi-packer-" .. tier .. "-" .. dir .. ".png"`, 128 x 128, scale 0.5.
- Belt picture: `belt_animation_set = { animation_set = <RotatedAnimation>, <index fields> }`. `animation_set` has `direction_count` (20 on vanilla belts) and `frame_count`; it may already be `{ layers = { ... } }`. Index fields choose the direction row (1-based), defaults when nil: `east_index = 1`, `west_index = 2`, `north_index = 3`, `south_index = 4`, `east_to_north_index = 5`, `north_to_east_index = 6`, `west_to_north_index = 7`, `north_to_west_index = 8`, `south_to_east_index = 9`, `east_to_south_index = 10`, `south_to_west_index = 11`, `west_to_south_index = 12`, `starting_south_index = 13`, `ending_south_index = 14`, `starting_west_index = 15`, `ending_west_index = 16`, `starting_north_index = 17`, `ending_north_index = 18`, `starting_east_index = 19`, `ending_east_index = 20`.
- Proven by game load on 2.0.77 (2026-10-02): body with `connector_frame_sprites = nil` (circuit connector kept) loads; `animation_set = { layers = { base, { filenames = <20 files>, lines_per_file = 1, line_length = 1, width = 128, height = 128, scale = 0.5, frame_count = 1, repeat_count = <base frame_count>, direction_count = 20 } } }` loads.

### Rule

`M._hood_layer(tier, set)` -> layer table or nil; pure.
- Direction row r (1..20) shows hood of the direction items LEAVE in that row: straight rows = own direction; `<a>_to_<b>` = b; `starting_<d>` and `ending_<d>` = d. Row number of each name = its index field in `set` (default above when nil).
- Layer: `filenames[r]` = hood main png of that direction (no shadow), `lines_per_file = 1`, `line_length = 1`, `width = 128`, `height = 128`, `scale = 0.5`, `frame_count = 1`, `repeat_count = F`, `direction_count = 20`, where F = `frame_count` of base (`set.animation_set.frame_count`, or of its first layer when base is layered; default 1).
- Returns nil (body keeps belt picture as is) when: `set` or `set.animation_set` nil; `direction_count` of base (or its first layer) is not 20; any index field is outside 1..20; two names map to one row with different hood directions.
- Body: `body.belt_animation_set` = deep copy of source belt set (source prototype never modified); when layer is non-nil: `animation_set = { layers = { <old animation_set, or its layers flattened>, layer } }`. `body.connector_frame_sprites = nil` always.

### Tests first — in `tests/offline/test_data.lua` (describe `data v20`); each seen RED before code

- `data v20 > body has no connector frame` — `raw["transport-belt"][N.body("yellow")].connector_frame_sprites == nil`, `circuit_connector` still deep-equals source belt.
- `data v20 > hood layer rows follow leaving direction` — default indexes: `filenames[1]` east, `[2]` west, `[3]` north, `[4]` south, `[5]` north, `[6]` east, `[7]` north, `[8]` west, `[9]` east, `[10]` south, `[11]` west, `[12]` south, `[13]` south, `[14]` south, `[15]` west, `[16]` west, `[17]` north, `[18]` north, `[19]` east, `[20]` east; each path = hood main png of tier.
- `data v20 > hood layer follows custom index fields` — set with `east_index = 3`, `north_index = 1`: `filenames[3]` east, `filenames[1]` north.
- `data v20 > hood layer repeat count equals belt frames` — base `frame_count = 32` -> `repeat_count == 32`; layered base (first layer `frame_count = 16`) -> 16 and old layers kept before hood layer.
- `data v20 > odd belt picture keeps belt picture` — `direction_count = 12`, missing `animation_set`, index 21, clash of two names on one row: `_hood_layer` returns nil and body `belt_animation_set` deep-equals source.
- `data v20 > source belt picture not modified` — source belt `belt_animation_set` deep-equals its value before `make`; body set is another table.
- `data v20 > body picture is belt plus hood` — yellow body: `animation_set.layers[#layers]` is hood layer, `layers[1]` deep-equals source `animation_set`.

Update `tests/offline/fake_data.lua` (belts need `belt_animation_set` with `animation_set = { filename = ..., frame_count = 16, direction_count = 20 }` and `connector_frame_sprites`) and regenerate `tests/offline/golden_vanilla.lua` the way test `data extra > vanilla prototypes identical to v8` reads it (dump of `F.extended` after `dofile("prototypes/packer.lua")`, file content `return <quoted dump>`); you may add a small generator under `tests/offline/` named `gen_golden.lua` (it is in your file list).

### Mutation

Map `ending_<d>` rows to opposite direction -> `hood layer rows follow leaving direction` red; restore -> green. Never commit mutated state.


## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_data.lua::data v20 > body has no connector frame'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua <own file>`.

Keep-green list `tests/offline/fixtures/v17_keep_green.txt` (one `<file>::<name>` per line, tests in files no lane owns), run as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v17_keep_green.txt
```

Old tests in files you own that pin replaced behaviour (chest body, `rec.entity.get_inventory`, variant names as live entity): rewrite them to the new rule, never delete a still-true test, say in report which ones changed and why.

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `data.lua`, `scripts/names.lua`, `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fixtures/*`, anything under `tests/game/`, `tools/*`, `Makefile`. Never weaken a test to hide a defect. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v20..HEAD`, list of old tests rewritten.

## What done mean

```checks
{"name": "lane058-scope", "command": "git diff --name-only lanes-base-v20 HEAD | grep -Ev '^(prototypes/tier\\.lua|tests/offline/test_data\\.lua|tests/offline/test_data_extra\\.lua|tests/offline/fake_data\\.lua|tests/offline/golden_vanilla\\.lua|tests/offline/gen_golden\\.lua)$' | ( ! grep . ) && echo lane058-scope-ok", "expect_exit": 0, "expect_regex": "lane058-scope-ok", "timeout_s": 60}
{"name": "lane058-tests", "command": "( for t in 'body has no connector frame' 'hood layer rows follow leaving direction' 'hood layer follows custom index fields' 'hood layer repeat count equals belt frames' 'odd belt picture keeps belt picture' 'source belt picture not modified' 'body picture is belt plus hood'; do tools/run_tests.sh 2.0 \"tests/offline/test_data.lua::data v20 > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_data.lua && lua5.2 tests/offline/run.lua tests/offline/test_data_extra.lua ) && echo lane058-tests-ok", "expect_exit": 0, "expect_regex": "lane058-tests-ok", "timeout_s": 600}
{"name": "lane058-guard", "command": "tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && echo lane058-guard-ok", "expect_exit": 0, "expect_regex": "lane058-guard-ok", "timeout_s": 120}
{"name": "lane058-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v17_keep_green.txt ) && echo lane058-keep-green-ok", "expect_exit": 0, "expect_regex": "lane058-keep-green-ok", "timeout_s": 1500}
```

## Files this lane owns

prototypes/tier.lua, tests/offline/test_data.lua, tests/offline/test_data_extra.lua, tests/offline/fake_data.lua, tests/offline/golden_vanilla.lua, tests/offline/gen_golden.lua. Never touch anything else.

Re-cut because: none

# bound: 2700s
