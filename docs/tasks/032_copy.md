# 032 — copy: library blueprint record guard (FND-0033)

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-032_copy`, branch `lane/032_copy`, base tag `lanes-base-v12`, merge target `int/v12`. Host `dev-vm`.

This task is complete in itself. No other lane runs. Integrator already changed `tests/game/*` (you never touch it).

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v12`; every existing test in `tests/offline/test_copy.lua` keeps its name, body and expectation.

- Bug (author reproduced in real game on 0.1.12, 2026-09-30), exact engine text:
  `Error while running event sushi-packer::on_player_setup_blueprint (ID 83) LuaRecord doesn't contain key valid_for_read.` at `__sushi-packer__/scripts/copy.lua:41`.
- Why: `scripts/copy.lua` `M.on_setup_blueprint(e)` does `local bp = e.record or e.stack` then reads `bp.valid_for_read` and `bp.is_blueprint`. Blueprint in inventory → game passes `e.stack` (LuaItemStack, has both fields). Blueprint in library → game passes `e.record` (LuaRecord). LuaRecord has NO `valid_for_read`, NO `is_blueprint`. Reading any missing field on a Factorio object raises error `<Class> doesn't contain key <key>.` → crash.
- LuaRecord fields (API 2.0.72 and 2.1, both checked): `object_name` (= `"LuaRecord"`), `valid` (bool), `valid_for_write` (bool), `type` (`"blueprint"`, `"blueprint-book"`, `"deconstruction-planner"`, `"upgrade-planner"`), `get_blueprint_entities()`, `set_blueprint_entities(list)`. LuaItemStack has `object_name` (= `"LuaItemStack"`), `valid_for_read`, `is_blueprint`, same two methods.
- Required fix (decision V12-2, `docs/DECISIONS.md`):
  - `bp.object_name == "LuaRecord"` → continue only if `bp.valid and bp.type == "blueprint" and bp.valid_for_write`; else return. Never read `valid_for_read` / `is_blueprint` on record.
  - Anything else (stack) → continue only if `bp.valid_for_read and bp.is_blueprint`, same as today. Existing offline fakes are plain tables without `object_name`; they must keep working as stacks.
  - Rest of function (entities loop, placer swap, tags, `set_blueprint_entities`) unchanged and runs for record too.
  - Touch only lines 39-41 area of `scripts/copy.lua`. Only API present in both 2.0 and 2.1.
- Offline runner: `describe`, `it`, `eq`, `ok` (`tests/offline/run.lua`); test name `<describe> > <it>`. Tests in `tests/offline/test_copy.lua` already `require("scripts.copy")`, set globals `storage`, `defines`; copy the `setup` helper pattern at file top.

## Explain very simply

Game gives handler one of two things. Old code asked both things a question only one understands. Ask "what are you?" (`object_name`) first, then ask right questions.

## What to build

### Tests first — `tests/offline/test_copy.lua`, inside existing `describe("copy", ...)`; each red at `lanes-base-v12` first, then green

Add local helper `fake_record(fields)`: returns table with given fields plus `object_name = "LuaRecord"`, with metatable `__index = function(_, k) error("LuaRecord doesn't contain key " .. tostring(k) .. ".", 2) end` (missing field raises like engine; never put `valid_for_read` / `is_blueprint` in it).

- `copy > library record does not crash` — record `valid = true, valid_for_write = true, type = "blueprint"`, entities `{ { entity_number = 1, name = N.variant("red", "west"), direction = 0 } }`, mapping empty; call `on_setup_blueprint({ record = rec, mapping = ... })`; no error; written list `[1].name == N.placer("red")`, `[1].direction == 12`. At base it must fail with text containing `LuaRecord doesn't contain key valid_for_read`.
- `copy > library record gets tags` — record as above, `storage.boxes[42]` rec with settings, mapping `{ [1] = { unit_number = 42, valid = true } }`, entity `N.variant("blue", "east")` → written `[1].tags.sushi_packer` equals settings, name = `N.placer("blue")`.
- `copy > read-only record skipped` — `valid_for_write = false` → no error, `set_blueprint_entities` never called.
- `copy > non-blueprint record skipped` — `type = "deconstruction-planner"`, `valid_for_write = true` → no error, `set_blueprint_entities` never called, `get_blueprint_entities` never called.
- `copy > stack still read as stack` — stack fake with `object_name = "LuaItemStack"`, `valid_for_read = true`, `is_blueprint = true` (metatable raising `LuaItemStack doesn't contain key <k>.` on missing fields) → placer swap as first test.

Run each via `make test-one` BEFORE fixing; keep red outputs for final report.

### Fix — `scripts/copy.lua`

Per "Required fix". Then each new test green, and every existing `copy` / `copy clone` test green.

### Mutation — prove test bites

Temporarily restore old line 41 (`if not bp or not bp.valid_for_read or not bp.is_blueprint then return end`), run `copy > library record does not crash` → must be red with `LuaRecord doesn't contain key valid_for_read`; restore fix; rerun → green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make zip`, never `--full`, never a file-wide or dir-wide run, never `lua5.2 tests/offline/run.lua <file>` on a whole file. Never start Factorio, never run `tests/game/*` (`tools/run_tests.sh` refuses headless under `LANE_RUN_ID`). One test per call, milliseconds each:

```
make test-one T='tests/offline/test_copy.lua::copy > library record does not crash'
```

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/names.lua`, any `scripts/*` except `scripts/copy.lua`, `prototypes/*`, `control.lua`, `data.lua`, `info.json`, `changelog.txt`, `locale/*`, `Makefile`, `tools/*`, `.agent-lane.toml`, any file not in "Files this lane owns". Never weaken, skip or delete an existing test or change an existing expectation. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then fix, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base (first shows `LuaRecord doesn't contain key valid_for_read`), green output after fix, mutation red + restore green, `git log --oneline lanes-base-v12..HEAD`.

## What done mean

```checks
{"name": "lane032-scope", "command": "git diff --name-only lanes-base-v12 HEAD | grep -Ev '^(scripts/copy\\.lua|tests/offline/test_copy\\.lua)$' | ( ! grep . ) && echo lane032-scope-ok", "expect_exit": 0, "expect_regex": "lane032-scope-ok", "timeout_s": 60}
{"name": "lane032-tests", "command": "( for t in 'copy > library record does not crash' 'copy > library record gets tags' 'copy > read-only record skipped' 'copy > non-blueprint record skipped' 'copy > stack still read as stack' 'copy > blueprint renames variant to placer without mapping' 'copy > blueprint adds tags when rec found' 'copy > blueprint leaves other entities alone' 'copy clone > cloned box stays consistent after more input'; do tools/run_tests.sh 2.0 \"tests/offline/test_copy.lua::$t\" || exit 1; done; tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane032-tests-ok", "expect_exit": 0, "expect_regex": "lane032-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/copy.lua (guard lines only), tests/offline/test_copy.lua (add tests + helper only). Never touch anything else.

Re-cut because: none

# bound: 1800s
