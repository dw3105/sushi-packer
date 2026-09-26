# 009 — review hardening: blueprint rename, front belt direction, circuit enable

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-009_review_hardening`, branch `lane/009_review_hardening`, base tag `wave2-base`, merge target `int/v1`. Host `legalcopilot-dev`.

This task is complete in itself. Lane 008 runs in parallel on other files; you never need it.

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** signatures in `tests/offline/contract.lua`; existing tests in `tests/game/*` untouched; every file outside "Files this lane owns" byte-identical to `wave2-base`.

- `scripts/copy.lua:39-59` `on_setup_blueprint`: renames a variant entity to its placer (and sets `direction`, tags) only inside `if rec then` (`rec` from `e.mapping.get()[entity_number]`). Blueprint without mapping (library record, copy tool edge) keeps the not-rotatable variant; rotating that blueprint then builds the box facing the wrong way (`docs/FINDINGS.md` FND-0002, decision D-4).
- `scripts/belt_io.lua:14-34` `find_belt`: front side (`sign == 1`) accepts any belt whose direction is not opposite to the box, so a sideways belt passes. Output onto a sideways belt side-loads: both box lanes land on one belt lane (breaks L-1, `docs/REQUIREMENTS.md` §4). Behind side (`sign == -1`) already requires same direction.
- `scripts/circuit.lua:13-38` `evaluate`: applies condition when `circuit.enable ~= false` (so `nil` applies it). Contract: condition applies only when `enable == true` (`docs/CONTRACT.md:24-34`, `:134`). `tests/offline/test_circuit.lua` checks `compare` true cases only; a `>` → `>=` swap stays green.
- Direction values in 2.0/2.1: `defines.direction.north = 0, east = 4, south = 8, west = 12`.
- Mocks: offline runner loads the test file in plain `lua5.2` with `package.path = "./?.lua;..."` (`tests/offline/run.lua:5`). Before requiring a module under test, set the globals it reads inside functions to plain tables: `defines = { direction = { north = 0, east = 4, south = 8, west = 12 }, inventory = { chest = 1 }, wire_connector_id = { circuit_red = 1, circuit_green = 2 } }`, `storage = { boxes = {}, belt_stack = {} }`, `settings = { global = { ["sushi-packer-flush-timeout"] = { value = 0 } } }`, `prototypes = { item = { ["iron-plate"] = { stack_size = 100 } } }`, `game = { connected_players = {} }`. Fake entities are tables with the fields and methods the code calls (`valid = true`, `unit_number`, `position`, `surface`, `force = { index = 1, belt_stack_size_bonus = 0 }`, `get_inventory = function() return inv end`). Reset globals in each test (no shared state between tests). Replace a collaborator by writing a field on its module table (`require("scripts.belt_io").pull = fake`) and restore it at test end.
- Offline runner: `describe`, `it`, `eq(found, expected, msg)` deep compare, `ok(cond, msg)` (`tests/offline/run.lua:10-34`); full name `<describe> > <it>`; missing name = exit 1.

## Explain very simply

Three small fixes found in review. Blueprints must always store the turnable placer. Box must only output onto a belt going straight on. Circuit condition counts only when switched on.

## What to build

1. `scripts/copy.lua` `on_setup_blueprint`: for every entity whose name is a variant: always set `name = N.placer(tier)` and `direction = defines.direction[dir]`; add `tags.sushi_packer = M.export(rec)` only when `rec` found. Other entities untouched.
2. `scripts/belt_io.lua` `find_belt` front side: accept only `transport-belt` with `direction == box direction`, or `underground-belt` with `belt_to_ground_type == "input"` and `direction == box direction`.
3. `scripts/circuit.lua` `evaluate`: condition applies only when `circuit.enable == true`.

### Tests to write (exact names; each red against current code first where it is a fix)

`tests/offline/test_copy.lua` (new), `describe("copy", ...)` — fake blueprint stack: `valid_for_read = true`, `is_blueprint = true`, `get_blueprint_entities()` returns list, `set_blueprint_entities(list)` records it:
- `copy > blueprint renames variant to placer without mapping`
- `copy > blueprint adds tags when rec found`
- `copy > blueprint leaves other entities alone`

`tests/offline/test_belt_io.lua` (new), `describe("belt_io", ...)` — fake `entity.surface.find_entities_filtered{position, type}` returning fake belts `{valid = true, type = ..., direction = ..., belt_to_ground_type = ...}` placed by position:
- `belt_io > front accepts same direction belt`
- `belt_io > front refuses sideways belt`
- `belt_io > front refuses belt facing box`
- `belt_io > front accepts underground input same direction`
- `belt_io > behind still requires belt moving into box`

`tests/offline/test_circuit.lua` (existing file, add to `describe("circuit", ...)`) — fake entity with `get_circuit_network()` and `get_signal(signal, ...)`:
- `circuit > compare false cases`
- `circuit > enable nil means condition off`
- `circuit > enable true applies condition`

## Test rule — read twice

**Lanes run offline Lua tests only (SP-02 v0.2).** Never start Factorio, never run `tests/game/*`, never `make test`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_belt_io.lua::belt_io > front refuses sideways belt'
```

Game API is faked with plain Lua tables inside your test file (see "Mocks" above). Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane009-scope", "command": "git diff --name-only wave2-base HEAD | grep -Ev '^(scripts/copy\\.lua|scripts/belt_io\\.lua|scripts/circuit\\.lua|tests/offline/test_copy\\.lua|tests/offline/test_belt_io\\.lua|tests/offline/test_circuit\\.lua)$' | ( ! grep . ) && echo lane009-scope-ok", "expect_exit": 0, "expect_regex": "lane009-scope-ok", "timeout_s": 60}
{"name": "lane009-tests", "command": "( for t in 'blueprint renames variant to placer without mapping' 'blueprint adds tags when rec found' 'blueprint leaves other entities alone'; do tools/run_tests.sh 2.0 \"tests/offline/test_copy.lua::copy > $t\" || exit 1; done && for t in 'front accepts same direction belt' 'front refuses sideways belt' 'front refuses belt facing box' 'front accepts underground input same direction' 'behind still requires belt moving into box'; do tools/run_tests.sh 2.0 \"tests/offline/test_belt_io.lua::belt_io > $t\" || exit 1; done && for t in 'compare false cases' 'enable nil means condition off' 'enable true applies condition' 'compare all six comparators' 'compare unknown comparator is false'; do tools/run_tests.sh 2.0 \"tests/offline/test_circuit.lua::circuit > $t\" || exit 1; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane009-tests-ok", "expect_exit": 0, "expect_regex": "lane009-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/copy.lua, scripts/belt_io.lua, scripts/circuit.lua, tests/offline/test_copy.lua, tests/offline/test_belt_io.lua, tests/offline/test_circuit.lua. Never touch anything else.

Re-cut because: none

# bound: 1800s

Reviewer ask: read `git diff wave2-base HEAD`; confirm each fix test was red before its fix (lane log), and fakes return exactly the fields the code reads.
