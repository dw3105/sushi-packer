# 007 — bench harness for R-1 (200 boxes, script ms/tick)

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-007_bench_harness`, branch `lane/007_bench_harness`, base tag `lanes-base`, merge target `int/v1`. Host `legalcopilot-dev`.

This task is complete in itself. Other modules are built by other lanes against the same frozen contract; you never need them.

## You have about 45 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** `Makefile` target `bench` calls `tools/bench/run.sh $(FV)` under gateslot; every file outside "Files this lane owns" byte-identical to `lanes-base`.

- Contract: `docs/CONTRACT.md` (module rules `:5-11`, storage layout `:15-42`, measured game facts `:46-54`, this lane's module section cited below). Requirements `docs/REQUIREMENTS.md`, decisions `docs/DECISIONS.md`.
- Modules owned by other lanes are S0 stubs (`scripts/<module>.lua`): pure functions `error("stub: ...")`, event handlers no-op. Never call a stub for real. In tests, fake the other side: save the original function in `before_each`, replace it on the shared module table (`local core = require("scripts.core"); core.new_box = function() return {} end`), restore in `after_each`. Or build `rec` by hand per `docs/CONTRACT.md:15-42` and put it in `storage.boxes[entity.unit_number]`.
- `scripts/names.lua`: every prototype name (`N.variant(tier, dir)`, `N.placer(tier)`, `N.item(tier)`, `N.led(state, dir)`), `N.DIRS`, `N.TIERS`, `N.TIER[tier].lane_rate`.
- S0 data stage builds tier `yellow` only (`prototypes/packer.lua:6`); build yellow boxes in tests.
- In-game tests: FactorioTest with luassert. Globals `describe`, `it`, `test`, `before_each`, `after_each`, `after_ticks(n, fn)` (test waits), `assert.are_equal(expected, found)`, `assert.is_true`, `assert.is_nil`, `assert.is_not_nil`. Examples: `tests/game/test_probe.lua` (belts, `after_ticks`, blueprint, player). Surface `game.surfaces[1]`, force `game.forces.player`, player `game.players[1]` (one, with character). Clear your area in `before_each` (see `tests/game/test_probe.lua:4-8`).
- Test full name = `<describe> > <it>`. Runner: `tools/run_tests.sh <2.0|2.1> '<file>::<describe> > <it>'` fails unless exactly that one test ran and passed. One in-game test takes 10-26 s wall.
- Factorio headless `~/factorio-2.0/factorio` (2.0.77) and `~/factorio-2.1/factorio` (2.1.20). Only API present in both. Docs https://lua-api.factorio.com/2.0.72/ (no network in lane; use local `~/factorio-2.0/factorio/data` Lua sources and `doc-html` if present for reference).
- R-1: 200 boxes ≤ 1 ms/tick script time on this VM (Q-6 in `docs/DECISIONS.md`). R-2 idle skip is lane G's job; this lane only measures.
- `Makefile` `bench` target: `$(GATE) tools/bench/run.sh $(FV)`. `tools/stage.sh <FV> test` stages our mod (with `tests/`) into `build/<FV>/mods/sushi-packer_<ver>/` and writes `build/<FV>/config.ini` (use `STAGE_DIR=<dir>` to stage elsewhere; see `tools/load_check.sh` for the create-map pattern: `factorio --config <cfg> --mod-directory <mods> --create <save>`).
- Benchmark mode: `factorio --config <cfg> --mod-directory <mods> --benchmark <save> --benchmark-ticks N --benchmark-runs 1 --benchmark-verbose all` prints per-tick CSV with columns including `wholeUpdate` and `scriptUpdate` (all mods' script time; check units from the header, the 2.0.77 binary prints them). Headless benchmark exits by itself.
- Tick glue (`scripts/tick.lua`) is a stub in this worktree: boxes do nothing yet, so measured numbers now are near zero; integrator re-runs after merge. Your job is the harness, not the number.
- Hidden base loaders exist in 2.0 and 2.1 data (`loader`, `fast-loader`, `express-loader`; check `~/factorio-2.0/factorio/data/base/prototypes/entity/entities.lua`); infinity chest `infinity-chest` with `infinity_container_filters`. Use only prototypes present in both versions.

## Explain very simply

Build a test map with 200 boxes, each fed a mixed belt from a never-empty chest and emptied into a sink. Run Factorio in benchmark mode and print how many ms our script uses per tick.

## What to build

1. `tests/game/bench_builder.lua` (plain module, returns table): `build(surface, force, n, origin)` places `n` setups in a grid; each: source `infinity-chest` (mixed items: `iron-plate`, `copper-plate`, `iron-gear-wheel`, `electronic-circuit`, `coal`) → loader onto a straight belt run feeding both lanes → box placer (`N.placer("yellow")`, raise_built so the box forms) → belt → loader → sink `infinity-chest` set to remove everything. Returns list of box positions.
2. `tools/bench/mod/` bench mod `sushi-packer-bench` (info.json factorio_version patched per FV by run.sh, dependency `sushi-packer`): `control.lua` `on_init` calls `require("__sushi-packer__.tests.game.bench_builder").build(game.surfaces[1], game.forces.player, BOXES, {0, 0})` where BOXES comes from a startup setting `sushi-packer-bench-boxes` (default 200) defined in bench mod `settings.lua`; also sets `game.forces.player.belt_stack_size_bonus = 3`.
3. `tools/bench/run.sh <FV> [--boxes N] [--ticks T]` (defaults 200, 3600): stage our mod (`test` mode) + bench mod into `build/bench-<FV>/mods`, `mod-list.json` enabling base data mods present + both mods, set startup setting via `mod-settings` (use `npx fmtk settings set startup ...` from `$(git rev-parse --git-common-dir)/../tools/ft` with cwd there, or write `mod-settings.dat` with fmtk), create map, run benchmark, parse CSV, print exactly one line: `bench FV=<FV> boxes=<N> ticks=<T> script_ms_avg=<x.xxx> whole_ms_avg=<y.yyy>`. Exit non-zero on any parse failure.

### Tests to write (exact names; each red against stub first)

- `bench > builder places requested setups` (R-1 harness)
- `bench > setup feeds both lanes` (R-1 harness)

## Test rule — read twice

**NEVER run `make test`, `tools/run_tests.sh <v> --full`, `lua5.2 tests/offline/run.lua <file>` without a test name, or any full, file-wide or dir-wide suite.** Run only single tests, one at a time:

```
make test-one FV=2.0 T='tests/game/test_bench.lua::bench > builder places requested setups'
make test-one FV=2.1 T='tests/game/test_bench.lua::bench > builder places requested setups'
```

Write each new test first and see it fail against the stub before writing code. In-game test counts only when green on both `FV=2.0` and `FV=2.1`.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/game/test_guard.lua`, `tests/game/test_probe.lua`, `tests/game/index.lua`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*` except new files under `tools/bench/`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit on your branch. Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane007-scope", "command": "git diff --name-only lanes-base HEAD | grep -Ev '^(tests/game/bench_builder\\.lua|tests/game/test_bench\\.lua|tools/bench/.*)$' | ( ! grep . ) && echo lane007-scope-ok", "expect_exit": 0, "expect_regex": "lane007-scope-ok", "timeout_s": 60}
{"name": "lane007-tests", "command": "( for fv in 2.0 2.1; do for t in 'builder places requested setups' 'setup feeds both lanes'; do tools/run_tests.sh $fv \"tests/game/test_bench.lua::bench > $t\" || exit 1; done; done && tools/bench/run.sh 2.0 --boxes 10 --ticks 120 | grep -E '^bench FV=2\\.0 boxes=10 ticks=120 script_ms_avg=[0-9.]+ whole_ms_avg=[0-9.]+$' && tools/bench/run.sh 2.1 --boxes 10 --ticks 120 | grep -E '^bench FV=2\\.1 boxes=10 ticks=120 script_ms_avg=[0-9.]+ whole_ms_avg=[0-9.]+$' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' && for fv in 2.0 2.1; do tools/run_tests.sh $fv 'tests/game/test_guard.lua::guard > prototypes exist' || exit 1; done ) && echo lane007-tests-ok", "expect_exit": 0, "expect_regex": "lane007-tests-ok", "timeout_s": 2400}
```

## Files this lane owns

tests/game/bench_builder.lua, tests/game/test_bench.lua, tools/bench/* (new). Never touch anything else.

Re-cut because: none

# bound: 3600s

Reviewer ask: read `git diff lanes-base HEAD`; confirm `script_ms_avg` is parsed from the `scriptUpdate` column with units from the header, and the builder feeds both lanes.
