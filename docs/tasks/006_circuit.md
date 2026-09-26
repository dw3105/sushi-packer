# 006 — circuit network (circuit)

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-006_circuit`, branch `lane/006_circuit`, base tag `lanes-base`, merge target `int/v1`. Host `legalcopilot-dev`.

This task is complete in itself. Other modules are built by other lanes against the same frozen contract; you never need them.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** signatures of `circuit` in `tests/offline/contract.lua`; every file outside "Files this lane owns" byte-identical to `lanes-base`.

- Contract: `docs/CONTRACT.md` (module rules `:5-11`, storage layout `:15-42`, measured game facts `:46-54`, this lane's module section cited below). Requirements `docs/REQUIREMENTS.md`, decisions `docs/DECISIONS.md`.
- Modules owned by other lanes are S0 stubs (`scripts/<module>.lua`): pure functions `error("stub: ...")`, event handlers no-op. Never call a stub for real. In tests, fake the other side: save the original function in `before_each`, replace it on the shared module table (`local core = require("scripts.core"); core.new_box = function() return {} end`), restore in `after_each`. Or build `rec` by hand per `docs/CONTRACT.md:15-42` and put it in `storage.boxes[entity.unit_number]`.
- `scripts/names.lua`: every prototype name (`N.variant(tier, dir)`, `N.placer(tier)`, `N.item(tier)`, `N.led(state, dir)`), `N.DIRS`, `N.TIERS`, `N.TIER[tier].lane_rate`.
- S0 data stage builds tier `yellow` only (`prototypes/packer.lua:6`); build yellow boxes in tests.
- In-game tests: FactorioTest with luassert. Globals `describe`, `it`, `test`, `before_each`, `after_each`, `after_ticks(n, fn)` (test waits), `assert.are_equal(expected, found)`, `assert.is_true`, `assert.is_nil`, `assert.is_not_nil`. Examples: `tests/game/test_probe.lua` (belts, `after_ticks`, blueprint, player). Surface `game.surfaces[1]`, force `game.forces.player`, player `game.players[1]` (one, with character). Clear your area in `before_each` (see `tests/game/test_probe.lua:4-8`).
- Test full name = `<describe> > <it>`. Runner: `tools/run_tests.sh <2.0|2.1> '<file>::<describe> > <it>'` fails unless exactly that one test ran and passed. One in-game test takes 10-26 s wall.
- Factorio headless `~/factorio-2.0/factorio` (2.0.77) and `~/factorio-2.1/factorio` (2.1.20). Only API present in both. Docs https://lua-api.factorio.com/2.0.72/ (no network in lane; use local `~/factorio-2.0/factorio/data` Lua sources and `doc-html` if present for reference).
- This lane's contract: `docs/CONTRACT.md:129-136`; settings layout `docs/CONTRACT.md:24-34` (`settings.circuit`), `rec.circuit_state = { last_flush = false }` owned by this module (`docs/CONTRACT.md:35`). Tests build rec by hand.
- Variants carry `circuit_connector = circuit_connector_definitions["chest"]` and `circuit_wire_max_distance` (`prototypes/packer.lua:90-91`), so boxes take red/green wires; a container sends its inventory contents to its networks natively (N-2).
- API: `entity.get_signal(signal, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)` sums both wires; `entity.get_circuit_network(defines.wire_connector_id.circuit_red)`; wiring in tests: `a.get_wire_connector(defines.wire_connector_id.circuit_red, true).connect_to(b.get_wire_connector(defines.wire_connector_id.circuit_red, true))`. Constant combinator output: `cc.get_or_create_control_behavior()`, `.add_section()`, `section.set_slot(1, {value={type="virtual", name="signal-A", quality="normal"}, min=5})`. Networks update one tick later: read inside `after_ticks(2, ...)`.
- A box reads its own contents on its network too; use virtual signals (`signal-A`, `signal-F`) in condition tests.
- Offline file `tests/offline/test_circuit.lua` runs `circuit.compare` under `lua5.2` (module load must touch no game global).

## Explain very simply

Box can be wired. Wire shows box contents. A condition on a signal switches box on or off. A flush signal going above zero empties all partial stacks once per rise.

## What to build

1. `circuit.compare(a, comparator, b)`: `>`, `<`, `=`, `≥`, `≤`, `≠`; unknown comparator → `false`.
2. `circuit.evaluate(rec)`: settings `rec.settings.circuit`. `enabled`: `enable == false` or no `cond.first_signal` → `true`; else `compare(get_signal(first_signal, red, green), cond.comparator, cond.constant)`. `flush_now`: `flush == true` and `flush_signal` set and value > 0 and `rec.circuit_state.last_flush == false` → `true`; store `last_flush = value > 0` every call (create `rec.circuit_state` when missing). No network → value 0.

### Tests to write (exact names; each red against stub first)

- `circuit > compare all six comparators` (N-3)
- `circuit > compare unknown comparator is false`

In-game, file `tests/game/test_circuit.lua`:

- `circuit > wire connects to box` (N-1)
- `circuit > box outputs contents with quality` (N-2)
- `circuit > condition off means enabled` (N-3)
- `circuit > condition true enables` (N-3)
- `circuit > condition false disables` (N-3)
- `circuit > red and green wires sum` (N-3)
- `circuit > flush fires once per rising edge` (N-4)
- `circuit > flush off ignores signal` (N-4)
- `circuit > no wire means enabled and no flush` (N-3, N-4)

## Test rule — read twice

**NEVER run `make test`, `tools/run_tests.sh <v> --full`, `lua5.2 tests/offline/run.lua <file>` without a test name, or any full, file-wide or dir-wide suite.** Run only single tests, one at a time:

```
make test-one FV=2.0 T='tests/game/test_circuit.lua::circuit > condition true enables'
make test-one FV=2.1 T='tests/game/test_circuit.lua::circuit > condition true enables'
```

Write each new test first and see it fail against the stub before writing code. In-game test counts only when green on both `FV=2.0` and `FV=2.1`.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/game/test_guard.lua`, `tests/game/test_probe.lua`, `tests/game/index.lua`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit on your branch. Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane006-scope", "command": "git diff --name-only lanes-base HEAD | grep -Ev '^(scripts/circuit\\.lua|tests/offline/test_circuit\\.lua|tests/game/test_circuit\\.lua)$' | ( ! grep . ) && echo lane006-scope-ok", "expect_exit": 0, "expect_regex": "lane006-scope-ok", "timeout_s": 60}
{"name": "lane006-tests", "command": "( for t in 'compare all six comparators' 'compare unknown comparator is false'; do tools/run_tests.sh 2.0 \"tests/offline/test_circuit.lua::circuit > $t\" || exit 1; done && for fv in 2.0 2.1; do for t in 'wire connects to box' 'box outputs contents with quality' 'condition off means enabled' 'condition true enables' 'condition false disables' 'red and green wires sum' 'flush fires once per rising edge' 'flush off ignores signal' 'no wire means enabled and no flush'; do tools/run_tests.sh $fv \"tests/game/test_circuit.lua::circuit > $t\" || exit 1; done; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' && for fv in 2.0 2.1; do tools/run_tests.sh $fv 'tests/game/test_guard.lua::guard > prototypes exist' || exit 1; done ) && echo lane006-tests-ok", "expect_exit": 0, "expect_regex": "lane006-tests-ok", "timeout_s": 2400}
```

## Files this lane owns

scripts/circuit.lua, tests/offline/test_circuit.lua, tests/game/test_circuit.lua. Never touch anything else.

Re-cut because: none

# bound: 3000s

Reviewer ask: read `git diff lanes-base HEAD`; confirm rising-edge test evaluates at least four times (0→1 true, 1 false, 0 false, 1 true) and N-2 test checks quality in signal.
