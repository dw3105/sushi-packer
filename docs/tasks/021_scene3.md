# 021 — scene v3: box centered, machinery off frame, bottom pair one tile upstream (U-8)

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-021_scene3`, branch `lane/021_scene3`, base tag `lanes-base-1.4`, merge target `int/v1.4`. Host `legalcopilot-dev`.

This task is complete in itself. Lane 020 (files `scripts/tick.lua`, `scripts/belt_io.lua`, their offline tests, `tests/offline/test_perf*.lua`) runs in parallel on other files; you never need it.

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua` (`sim.scene(kind)`); every file outside "Files this lane owns" byte-identical to `lanes-base-1.4`. Existing tests in `tests/offline/test_sim.lua` describe the v1.3 layout — replace them with the set named below.

- `scripts/sim.lua` today: chests/inserters at x -4/-2, pole visible at (-3,-1), belts x -5..-1 and 1..3, loader (4,0), sink (5,0), camera `{-0.5, 0.5}`. Author 2026-09-27: viewer must see ONLY belt before, box, belt after, box in center; every supporting entity off frame; bottom chests + their inserters shifted back (upstream = west, against belt flow) one tile.
- Frame: tips view ≈ 18 × 9 tiles at zoom 2.4 (author screenshot), Factoriopedia view smaller at zoom 2.0. Keep zoom values.
- New layout. Tile coords `(x, y)` mean `position(x, y) = {x + 0.5, y + 0.5}` (helper already in file). Belt row y = 0 flows east, box at (0, 0):

```
 x:  -17  -16  -15  -14  -13  -12 ...... -1    0    1 ....... 11   12   13
 y-2:          [Fe]      [Cu]
 y-1:          [Iv]      [Iv] (P)
 y 0:  >>>  >>>  >>>  >>>  >>>  >>> ...... >>> [SP]  >>> ...... >>> [L>] [IC]
 y+1:     [I^]      [I^]
 y+2:     [Co]      [Ci]
            |<-- off frame -->|  |<------- visible: belt, SP, belt ------->|
```

  - infinity-chest iron-plate (-15,-2), copper-plate (-13,-2); coal (-16,2), electronic-circuit (-14,2). Filter `{name, count = 50, mode = "exactly"}` (unchanged).
  - `inserter` (-15,-1), (-13,-1) `direction = north`; (-16,1), (-14,1) `direction = south` (FND-0012: direction = pickup side; unchanged rule).
  - `medium-electric-pole` (-12,-1) and (-12,-9); `electric-energy-interface` (-12,-10) with power fields as today.
  - `transport-belt` east x = -17..-1 and x = 1..11; `N.placer("yellow")` (0,0) east `raise_built = true`; `loader-1x1` (12,0) east `type = "input"`; void `infinity-chest` (13,0) `remove_unfiltered_items = true` set after create.
  - Camera `M._CAMERA = { factoriopedia = { position = { 0.5, 0.5 }, zoom = 2.0 }, tips = { position = { 0.5, 0.5 }, zoom = 2.4 } }` (box center). Keep `if game.simulation then` guard. Bonuses unchanged (belt 3, inserter 0).
- Belt is long now, first items need ~7 s to reach box. Simulation definitions pre-run: `init_update_count = 900` in `prototypes/packer.lua` (`FACTORIOPEDIA_SIMULATION`) and `prototypes/tips.lua` (`simulation`). Only that number changes in those files.
- Offline runner: `describe`, `it`, `eq(found, expected, msg)` deep compare, `ok(cond, msg)`; full test name `<describe> > <it>`. Mocks in `tests/offline/test_sim.lua` `setup()` (records each create spec, `spec.entity`). `tests/offline/test_data.lua` loads prototypes from `tests/offline/fake_data.lua`; existing test `data > simulations call scene with mods` asserts `init_update_count = 0` — update it to 900.

## Explain very simply

Viewer should look at box only: belt comes in with mixed items, box, belt leaves with neat stacks. Factory that makes mixed items hides off screen left, trash bin off screen right.

## What to build

`scripts/sim.lua` layout exactly as above; `init_update_count = 900` in both simulation definitions.

### Tests to write (exact names; each red against current code first)

`tests/offline/test_sim.lua` (replace old set), `describe("sim", ...)`: `sim > four infinity chests bottom pair one tile upstream`, `sim > inserters between chests and belt`, `sim > machinery off frame` (every created entity except `transport-belt` and the placer has `|position[1] - camera x| >= 12` or `|position[2] - camera y| >= 6`, both kinds), `sim > power off frame`, `sim > inserter hand size one`, `sim > belt box and sink`, `sim > camera centered on box`, `sim > unknown kind errors`.
`tests/offline/test_data.lua`: update `data > simulations call scene with mods` (900), add `data > simulations pre-run 900 ticks`.

## Test rule — read twice

**Lanes run offline Lua tests only.** Never start Factorio, never run `tests/game/*`, never `make test`, never `make zip`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_sim.lua::sim > machinery off frame'
```

Game API is faked with plain Lua tables inside your test file. Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken, skip or delete an existing test unless this task names it. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane021-scope", "command": "git diff --name-only lanes-base-1.4 HEAD | grep -Ev '^(scripts/sim\\.lua|tests/offline/test_sim\\.lua|tests/offline/test_data\\.lua|prototypes/packer\\.lua|prototypes/tips\\.lua)$' | ( ! grep . ) && echo lane021-scope-ok", "expect_exit": 0, "expect_regex": "lane021-scope-ok", "timeout_s": 60}
{"name": "lane021-packer-diff", "command": "git diff -U0 lanes-base-1.4 HEAD -- prototypes/packer.lua prototypes/tips.lua | grep '^[-+][^-+]' | grep -v 'init_update_count' | ( ! grep . ) && echo lane021-diff-ok", "expect_exit": 0, "expect_regex": "lane021-diff-ok", "timeout_s": 60}
{"name": "lane021-tests", "command": "( for t in 'tests/offline/test_sim.lua::sim > four infinity chests bottom pair one tile upstream' 'tests/offline/test_sim.lua::sim > inserters between chests and belt' 'tests/offline/test_sim.lua::sim > machinery off frame' 'tests/offline/test_sim.lua::sim > power off frame' 'tests/offline/test_sim.lua::sim > inserter hand size one' 'tests/offline/test_sim.lua::sim > belt box and sink' 'tests/offline/test_sim.lua::sim > camera centered on box' 'tests/offline/test_sim.lua::sim > unknown kind errors' 'tests/offline/test_data.lua::data > simulations call scene with mods' 'tests/offline/test_data.lua::data > simulations pre-run 900 ticks' 'tests/offline/test_guard.lua::guard > contract frozen' 'tests/offline/test_guard.lua::guard > names frozen'; do tools/run_tests.sh 2.0 \"$t\" || exit 1; done ) && echo lane021-tests-ok", "expect_exit": 0, "expect_regex": "lane021-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/sim.lua, tests/offline/test_sim.lua, tests/offline/test_data.lua, prototypes/packer.lua (only `init_update_count`), prototypes/tips.lua (only `init_update_count`). Never touch anything else.

Re-cut because: none

# bound: 1800s
