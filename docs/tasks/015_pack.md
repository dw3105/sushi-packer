# 015 — pack at belt stack, quality filter rule, decon stop (C-2, O-5, P-1, E-8)

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-015_pack`, branch `lane/015_pack`, base tag `lanes-base-1.2`, merge target `int/v1.2`. Host `legalcopilot-dev`.

This task is complete in itself. Lanes 016, 017, 018 run in parallel on other files; you never need them.

## You have about 35 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua`; every existing test in `tests/offline/test_tick.lua` keeps passing (except `tick > filter without quality matches any quality` may be rewritten only if its meaning is kept); every file outside "Files this lane owns" byte-identical to `lanes-base-1.2`.

- Contract: `docs/REQUIREMENTS.md` v6 C-2, O-5, P-1, E-8; `docs/CONTRACT.md` sections `scripts/filter.lua`, `tick.on_decon`, `rec.decon`, filter shape `{name, quality = string|nil, comparator = "="|"≠"|">"|"<"|"≥"|"≤"|nil}` (nil quality = any quality, nil comparator = `"="`).
- `scripts/filter.lua` is a stub (`error("stub: task 015")`); `scripts/tick.lua` `M.on_decon` is a stub at file end.
- `scripts/tick.lua` today: `sink` passes `stack_size(name)` (item prototype stack size, e.g. 100) to `core.accept` → box waits for 100 plates. `reconcile` passes `stack_size(name)` to `core.adopt_external`. Belt stack `bss` = `storage.belt_stack[force.index]` (fallback `belt_io.belt_stack_size(force)`), computed in the output block. `has_filter` does exact quality match.
- `core.accept(box, name, quality, lane, count, stack_size, tick, passthrough)`: a partial becomes ready (queued for output) when it reaches `stack_size` (`scripts/core.lua`). Core is NOT yours; do not change it.
- Quality levels: `prototypes.quality[name].level` (normal 0, uncommon 1, rare 2, epic 3, legendary 5). A module-level cache of levels is allowed (prototype-derived, identical on every client).
- Decon events wired in `control.lua`: `on_marked_for_deconstruction` → `tick.on_decon(e, true)`, `on_cancelled_deconstruction` → `tick.on_decon(e, false)`; `e.entity` is the box variant.
- Offline tick fixture: `tests/offline/test_tick.lua` `fixture(tier)` fakes `belt_io.pull/push`, `circuit.evaluate`, `led.set`; feeds per lane `f[lane] = {name, quality, count}`; pushes recorded in `p[lane]`. Add `prototypes.quality = {normal={level=0}, uncommon={level=1}, rare={level=2}, legendary={level=5}}` in tests that need it. Restore fakes at test end like existing tests.
- Offline runner: `describe`, `it`, `eq(found, expected, msg)` deep compare, `ok(cond, msg)` (`tests/offline/run.lua`); full test name `<describe> > <it>`; missing name = exit 1.

## Explain very simply

Box waited for 100 plates. Wrong. It must wait only for as many as ride together on one belt item (1 to 4, research). Filters get splitter rule: "iron, quality ≥ uncommon". Box marked for deconstruction must freeze and turn LED off.

## What to build

1. `scripts/filter.lua` `M.match(filters, name, quality, levels)`: iterate with `ipairs`, skip entries that are not tables (`false` = empty GUI slot); true when any filter `f` has `f.name == name` and (`f.quality == nil` or compare `levels[quality]` to `levels[f.quality]` with `f.comparator or "="`, comparators `=`, `≠`, `>`, `<`, `≥`, `≤`). Unknown level → no match. Pure: no game API.
2. `scripts/tick.lua`: release size `n = math.min(bss, stack_size(name))` passed to `core.accept` in `sink` and to `core.adopt_external` in `reconcile` (compute `bss` once per visit before pull; reconcile uses the same rule). Replace `has_filter` with `filter.match(rec.settings.filters, name, quality, levels)` where `levels` = cached `{[q] = prototypes.quality[q].level}`.
3. `M.on_decon(e, marked)`: rec of `e.entity` (by `unit_number` in `storage.boxes`) → `rec.decon = marked`, `rec.next_poll = 0`. Unknown entity → nothing. In `on_tick`: when `rec.decon` → skip pull, push, core tick for that box; LED `visible = rec.enabled ~= false and not rec.decon`.

### Tests to write (exact names; each red against current code first)

`tests/offline/test_filter.lua` (new), `describe("filter", ...)`: `filter > ≥ uncommon matches rare not normal`, `filter > nil quality matches any`, `filter > nil comparator means equals`, `filter > all six comparators`, `filter > other item never matches`, `filter > empty slot false skipped`.

`tests/offline/test_tick.lua` (add to `describe("tick", ...)`):
- `tick > releases at belt stack` — `storage.belt_stack[1] = 4`, feed 4 iron one by one → 1 ready stack of 4, push of 4
- `tick > belt stack 1 passes through` — `storage.belt_stack[1] = 1`, each iron pushed as count 1 at once
- `tick > item stack size caps release` — item with `stack_size = 2`, belt stack 4 → release at 2
- `tick > research raise changes next release size`
- `tick > adopt uses belt stack` — reconcile of 8 external iron with belt stack 4 → 2 ready stacks
- `tick > filter uses quality rule` — filter `{name="iron", quality="uncommon", comparator="≥"}`: rare iron → hold, normal iron → stored
- `tick > decon marked stops input and output`, `tick > decon cancel resumes`, `tick > decon hides led`, `tick > decon on unknown entity ignored`

## Test rule — read twice

**Lanes run offline Lua tests only (SP-02 v0.2).** Never start Factorio, never run `tests/game/*`, never `make test`, never `make zip`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_filter.lua::filter > ≥ uncommon matches rare not normal'
```

Game API is faked with plain Lua tables inside your test file. Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken, skip or delete an existing test unless this task names it. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane015-scope", "command": "git diff --name-only lanes-base-1.2 HEAD | grep -Ev '^(scripts/tick\\.lua|scripts/filter\\.lua|tests/offline/test_tick\\.lua|tests/offline/test_filter\\.lua)$' | ( ! grep . ) && echo lane015-scope-ok", "expect_exit": 0, "expect_regex": "lane015-scope-ok", "timeout_s": 60}
{"name": "lane015-tests", "command": "( tools/run_tests.sh 2.0 'tests/offline/test_filter.lua::filter > ≥ uncommon matches rare not normal' && tools/run_tests.sh 2.0 'tests/offline/test_filter.lua::filter > nil quality matches any' && tools/run_tests.sh 2.0 'tests/offline/test_filter.lua::filter > nil comparator means equals' && tools/run_tests.sh 2.0 'tests/offline/test_filter.lua::filter > all six comparators' && tools/run_tests.sh 2.0 'tests/offline/test_filter.lua::filter > other item never matches' && tools/run_tests.sh 2.0 'tests/offline/test_filter.lua::filter > empty slot false skipped' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > releases at belt stack' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > belt stack 1 passes through' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > item stack size caps release' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > research raise changes next release size' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > adopt uses belt stack' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > filter uses quality rule' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > decon marked stops input and output' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > decon cancel resumes' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > decon hides led' && tools/run_tests.sh 2.0 'tests/offline/test_tick.lua::tick > decon on unknown entity ignored' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane015-tests-ok", "expect_exit": 0, "expect_regex": "lane015-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/tick.lua, scripts/filter.lua, tests/offline/test_tick.lua, tests/offline/test_filter.lua. Never touch anything else.

Re-cut because: none

# bound: 2100s
