# 004 — belt I/O adapter (belt_io)

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-004_belt_io`, branch `lane/004_belt_io`, base tag `lanes-base`, merge target `int/v1`. Host `dev-vm`.

This task is complete in itself. Other modules are built by other lanes against the same frozen contract; you never need them.

## You have about 45 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** signatures of `belt_io` in `tests/offline/contract.lua`; every file outside "Files this lane owns" byte-identical to `lanes-base`.

- Contract: `docs/CONTRACT.md` (module rules `:5-11`, storage layout `:15-42`, measured game facts `:46-54`, this lane's module section cited below). Requirements `docs/REQUIREMENTS.md`, decisions `docs/DECISIONS.md`.
- Modules owned by other lanes are S0 stubs (`scripts/<module>.lua`): pure functions `error("stub: ...")`, event handlers no-op. Never call a stub for real. In tests, fake the other side: save the original function in `before_each`, replace it on the shared module table (`local core = require("scripts.core"); core.new_box = function() return {} end`), restore in `after_each`. Or build `rec` by hand per `docs/CONTRACT.md:15-42` and put it in `storage.boxes[entity.unit_number]`.
- `scripts/names.lua`: every prototype name (`N.variant(tier, dir)`, `N.placer(tier)`, `N.item(tier)`, `N.led(state, dir)`), `N.DIRS`, `N.TIERS`, `N.TIER[tier].lane_rate`.
- S0 data stage builds tier `yellow` only (`prototypes/packer.lua:6`); build yellow boxes in tests.
- In-game tests: FactorioTest with luassert. Globals `describe`, `it`, `test`, `before_each`, `after_each`, `after_ticks(n, fn)` (test waits), `assert.are_equal(expected, found)`, `assert.is_true`, `assert.is_nil`, `assert.is_not_nil`. Examples: `tests/game/test_probe.lua` (belts, `after_ticks`, blueprint, player). Surface `game.surfaces[1]`, force `game.forces.player`, player `game.players[1]` (one, with character). Clear your area in `before_each` (see `tests/game/test_probe.lua:4-8`).
- Test full name = `<describe> > <it>`. Runner: `tools/run_tests.sh <2.0|2.1> '<file>::<describe> > <it>'` fails unless exactly that one test ran and passed. One in-game test takes 10-26 s wall.
- Factorio headless `~/factorio-2.0/factorio` (2.0.77) and `~/factorio-2.1/factorio` (2.1.20). Only API present in both. Docs https://lua-api.factorio.com/2.0.72/ (no network in lane; use local `~/factorio-2.0/factorio/data` Lua sources and `doc-html` if present for reference).
- This lane's contract: `docs/CONTRACT.md:78-86`. Game facts `docs/CONTRACT.md:48-54`: line 1 = left, 2 = right facing belt motion; `position` shrinks toward exit, front-most = LOWEST position, rests at 0 on belt end (FND-0004); `insert_at_back({name, count=4}, 4)` with bonus 3 makes one belt item of 4.
- `rec` fields used: `rec.entity` (yellow variant `N.variant("yellow", dir)`), `rec.dir` (side items leave). Box at tile T facing `north`: input belt on tile south of T moving north; output belt on tile north of T.
- `LuaTransportLine`: `get_detailed_contents()` → `{stack=LuaItemStack, position, unique_id}`; copy `name`, `quality.name`, `count` into a plain table before removing (stack goes invalid after removal); `remove_item{name, count, quality}` returns removed count; `insert_at_back(items, belt_stack_size)`, `can_insert_at_back()`. Belt entity types: `transport-belt`, `underground-belt` (`belt_to_ground_type` `"output"` = exit side). `LuaForce.belt_stack_size_bonus` RW.

## Explain very simply

Box reads the belt tile behind it, lane by lane, taking only the item that has reached the end. It hands each item to a callback that says how many it took. Box writes stacked items onto the matching lane of the belt in front.

## What to build

1. `belt_io.behind(entity, dir)`: entity on the tile behind (opposite of `dir`) of type `transport-belt` with same direction as box, or `underground-belt` output side with same direction; else `nil`.
2. `belt_io.front(entity, dir)`: entity on the tile in front of type `transport-belt` / `underground-belt` (input side) whose direction is not opposite to box; else `nil`.
3. `belt_io.pull(rec, budget, sink)`: for lane 1 then 2: up to `budget[lane]` times: item with lowest `position` on behind line `lane`, only when `position <= 0.125` (reached end); `accepted = sink(name, quality_name, lane, count)`; `accepted > 0` → `remove_item{name, quality, count=accepted}`; `accepted == 0` → stop lane. Return belt items taken per lane `{n1, n2}` (partial take counts 1).
4. `belt_io.push(rec, lane, item, belt_stack_size)`: front line `lane`; `can_insert_at_back()` and `insert_at_back({name, count, quality}, belt_stack_size)` → return `item.count`; else 0. No front belt → 0.
5. `belt_io.belt_stack_size(force)`: `math.min(4, 1 + force.belt_stack_size_bonus)`.

### Tests to write (exact names; each red against stub first)

- `belt_io > behind finds belt moving into box` (E-3)
- `belt_io > behind ignores belt moving away` (E-3)
- `belt_io > behind accepts underground output` (E-3)
- `belt_io > front finds belt not facing back` (E-3)
- `belt_io > front ignores belt facing box` (E-3)
- `belt_io > pull keeps lanes` (L-1)
- `belt_io > pull takes front-most item only` (FND-0004)
- `belt_io > pull ignores items not at belt end`
- `belt_io > pull respects budget` (O-4 intake cap)
- `belt_io > pull removes only accepted part of stacked item`
- `belt_io > pull stops lane on zero accept` (F-3 backpressure)
- `belt_io > push inserts stacked item on matching lane` (O-1, L-1)
- `belt_io > push returns zero when front blocked` (L-3)
- `belt_io > push returns zero without front belt` (E-3)
- `belt_io > belt stack size follows research capped at 4` (O-3)
- `belt_io > works in all four directions` (E-1)

## Test rule — read twice

**NEVER run `make test`, `tools/run_tests.sh <v> --full`, `lua5.2 tests/offline/run.lua <file>` without a test name, or any full, file-wide or dir-wide suite.** Run only single tests, one at a time:

```
make test-one FV=2.0 T='tests/game/test_belt_io.lua::belt_io > pull keeps lanes'
make test-one FV=2.1 T='tests/game/test_belt_io.lua::belt_io > pull keeps lanes'
```

Write each new test first and see it fail against the stub before writing code. In-game test counts only when green on both `FV=2.0` and `FV=2.1`.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/game/test_guard.lua`, `tests/game/test_probe.lua`, `tests/game/index.lua`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit on your branch. Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane004-scope", "command": "git diff --name-only lanes-base HEAD | grep -Ev '^(scripts/belt_io\\.lua|tests/game/test_belt_io\\.lua)$' | ( ! grep . ) && echo lane004-scope-ok", "expect_exit": 0, "expect_regex": "lane004-scope-ok", "timeout_s": 60}
{"name": "lane004-tests", "command": "( for fv in 2.0 2.1; do for t in 'behind finds belt moving into box' 'behind ignores belt moving away' 'behind accepts underground output' 'front finds belt not facing back' 'front ignores belt facing box' 'pull keeps lanes' 'pull takes front-most item only' 'pull ignores items not at belt end' 'pull respects budget' 'pull removes only accepted part of stacked item' 'pull stops lane on zero accept' 'push inserts stacked item on matching lane' 'push returns zero when front blocked' 'push returns zero without front belt' 'belt stack size follows research capped at 4' 'works in all four directions'; do tools/run_tests.sh $fv \"tests/game/test_belt_io.lua::belt_io > $t\" || exit 1; done; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' && for fv in 2.0 2.1; do tools/run_tests.sh $fv 'tests/game/test_guard.lua::guard > prototypes exist' || exit 1; done ) && echo lane004-tests-ok", "expect_exit": 0, "expect_regex": "lane004-tests-ok", "timeout_s": 3000}
```

## Files this lane owns

scripts/belt_io.lua, tests/game/test_belt_io.lua. Never touch anything else.

Re-cut because: none

# bound: 3600s

Reviewer ask: read `git diff lanes-base HEAD`; confirm lane tests put different items on each lane and assert lane numbers reach the sink unswapped, and the front-most test uses two items at known positions.
