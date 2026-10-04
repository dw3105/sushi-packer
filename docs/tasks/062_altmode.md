# 062 — altmode: direction arrow in alt-mode, hidden parts show nothing in alt-mode

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-062_altmode`, branch `lane/062_altmode`, base tag `lanes-base-v23`, merge target `int/v23`. Host `dev-vm`.

Lane 063 cap runs beside you. It also edits `scripts/arms.lua`, but ONLY function `M.skip`. You edit ONLY `_hood` and `M.destroy` there (and may add private `_arrow*` helpers next to `_hood`). Integrator works on `tests/game/*` and docs.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v23`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`). `scripts/names.lua` frozen: never edit.

- Packer, very short: belt-kind body entity (`N.body(tier)`) plus hidden parts on same tile: two lane stores (`N.STORE`), in arms + mop arms (`N.ARM`), out arms (`N.OUT` and swing copies `N.OUT .. "-" .. swing`). Old saves may still hold hood entity `N.hood(tier)` and old chest bodies `N.variant(tier, dir)`; those prototypes stay so saves load.
- Hood today: `_hood(rec)` in `scripts/arms.lua` (about lines 54-64) draws `rendering.draw_sprite{ sprite = N.hood_sprite(rec.tier, rec.dir), target = entity, surface = entity.surface, render_layer = "object" }` into `rec.hood`; on a valid hood it only rewrites `.sprite`. `_hood` is called by `M.create` (build, rotate, flip, upgrade, migration) and `M.ensure` (load / configuration change). `M.destroy` destroys `rec.hood`. `rec.dir` is a string: "north", "east", "south", "west".
- Fact from lane 063 (true after merge): engine look writes in-arm and mop-arm blacklist filters from `ledger.hoard` through `M.skip`. Not your code.
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API present in both (`rendering.draw_sprite` with `only_in_alt_mode`, `orientation`, `render_layer`; `LuaRenderObject.orientation` read-write; `.valid`; `.destroy()`). No `require` inside functions. No `math.random`. Never add a key to a table while walking it with `pairs`. Engine objects are userdata: test validity with `obj ~= nil and obj.valid == true`.
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file (`tests/offline/test_arms.lua` has an inline `rendering = { draw_sprite = ... }` stub: extend it to record calls and return objects with `valid`, `orientation`, `destroy`).

## Explain very simply

Hood hides belt, so player can't see which way packer runs. In alt-mode (Alt key) we draw small game arrow on each packer pointing way items leave. Same arrow game shows on pumps in alt-mode. And today alt-mode shows icons of hidden inserters and chests inside packer: one engine flag hides them.

## What to build

### Rule — arrow (`scripts/arms.lua`)

- Constant in `arms.lua` (local, not in `names.lua`): `ARROW = "utility/fluid_indication_arrow"`; orientation per direction `north = 0`, `east = 0.25`, `south = 0.5`, `west = 0.75` (arrow points to side items leave, REQUIREMENTS G-4, G-10).
- Inside `_hood(rec)` (or a private `_arrow(rec)` it calls): when `rec.arrow` valid -> write `rec.arrow.orientation` only if value differs; else draw `rec.arrow = rendering.draw_sprite{ sprite = ARROW, target = entity, surface = entity.surface, only_in_alt_mode = true, orientation = <dir>, render_layer = "entity-info-icon" }`.
- Exactly one arrow per packer at all times: create twice -> still one; rotate -> same object, new orientation.
- `M.destroy`: destroy `rec.arrow` when valid; `rec.arrow = nil`.
- `M.ensure`: invalid or missing arrow -> drawn again (through `_hood` path or own check; ensure must redraw arrow even when hood is valid).

### Rule — clean alt-mode (`prototypes/hidden.lua`, `prototypes/tier.lua`)

- `hide(p, store)` flag list gets `"hide-alt-info"` (covers `N.ARM`, `N.STORE`, `N.OUT`; swing copies are deep copies of out arm made after, so they inherit).
- `prototypes/tier.lua`: old hood entity `N.hood(tier)` flag list and old chest variants `N.variant(tier, dir)` flag list also get `"hide-alt-info"`.
- Body (`N.body(tier)`) and placer: unchanged.

### Tests first; each seen RED before code

In `tests/offline/test_arms.lua` (describe `arms`):
- `arms > create draws one alt-only arrow per packer` — one `draw_sprite` call with `sprite == "utility/fluid_indication_arrow"`, `only_in_alt_mode == true`, `target == entity`.
- `arms > arrow orientation per direction` — north 0, east 0.25, south 0.5, west 0.75.
- `arms > rotate rewrites arrow orientation, no second arrow` — create north, set `rec.dir = "east"`, create again: no new arrow draw, `rec.arrow.orientation == 0.25`.
- `arms > destroy removes arrow` — arrow `destroy` called, `rec.arrow == nil`.
- `arms > ensure redraws invalid arrow` — arrow `valid = false`, hood valid: `M.ensure` draws one new arrow.

In `tests/offline/test_data_hidden.lua` (describe `data hidden`):
- `data hidden > every hidden part has hide-alt-info` — `N.ARM`, `N.STORE`, `N.OUT` and every swing copy after `finalize`.

In `tests/offline/test_data.lua`: existing hood flag list test (about line 159, `eq(hood.flags, {...})`) gets `"hide-alt-info"`; add `data > old chest variants have hide-alt-info`.

### Code

As rules. No new public function, no `names.lua` edit.

### Mutation

Remove `only_in_alt_mode = true` -> `create draws one alt-only arrow per packer` red; restore -> green. Remove `"hide-alt-info"` from `hide()` -> `every hidden part has hide-alt-info` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_arms.lua::arms > create draws one alt-only arrow per packer'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua <own file>`.

Keep-green list `tests/offline/fixtures/v23_keep_green.txt` (tests in files no lane owns; all green at base), run as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v23_keep_green.txt
```

Old tests in files you own that pin replaced behaviour (exact flag lists, one `draw_sprite` call per create): rewrite to the new rule, never delete a still-true test, say in report which ones changed and why.

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `data.lua`, `scripts/names.lua`, `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fixtures/*`, anything under `tests/game/`, `tools/*`, `Makefile`. In `scripts/arms.lua` never touch `M.skip`. Never weaken a test to hide a defect. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, both mutations red + restore green, `git log --oneline lanes-base-v23..HEAD`, list of old tests rewritten.

## What done mean

```checks
{"name": "lane062-scope", "command": "git diff --name-only lanes-base-v23 HEAD | grep -Ev '^(scripts/arms\\.lua|prototypes/hidden\\.lua|prototypes/tier\\.lua|tests/offline/test_arms\\.lua|tests/offline/test_data_hidden\\.lua|tests/offline/test_data\\.lua)$' | ( ! grep . ) && echo lane062-scope-ok", "expect_exit": 0, "expect_regex": "lane062-scope-ok", "timeout_s": 60}
{"name": "lane062-skip-untouched", "command": "[ \"$(git show lanes-base-v23:scripts/arms.lua | sed -n '/^function M.skip/,/^end/p')\" = \"$(sed -n '/^function M.skip/,/^end/p' scripts/arms.lua)\" ] && echo lane062-skip-ok", "expect_exit": 0, "expect_regex": "lane062-skip-ok", "timeout_s": 60}
{"name": "lane062-tests", "command": "( for t in 'arms > create draws one alt-only arrow per packer' 'arms > arrow orientation per direction' 'arms > rotate rewrites arrow orientation, no second arrow' 'arms > destroy removes arrow' 'arms > ensure redraws invalid arrow'; do tools/run_tests.sh 2.0 \"tests/offline/test_arms.lua::$t\" || exit 1; done; tools/run_tests.sh 2.0 'tests/offline/test_data_hidden.lua::data hidden > every hidden part has hide-alt-info' || exit 1; tools/run_tests.sh 2.0 'tests/offline/test_data.lua::data > old chest variants have hide-alt-info' || exit 1; lua5.2 tests/offline/run.lua tests/offline/test_arms.lua && lua5.2 tests/offline/run.lua tests/offline/test_data_hidden.lua && lua5.2 tests/offline/run.lua tests/offline/test_data.lua ) && echo lane062-tests-ok", "expect_exit": 0, "expect_regex": "lane062-tests-ok", "timeout_s": 600}
{"name": "lane062-guard", "command": "tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && echo lane062-guard-ok", "expect_exit": 0, "expect_regex": "lane062-guard-ok", "timeout_s": 120}
{"name": "lane062-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v23_keep_green.txt ) && echo lane062-keep-green-ok", "expect_exit": 0, "expect_regex": "lane062-keep-green-ok", "timeout_s": 1500}
```

## Files this lane owns

scripts/arms.lua (`_hood`, `M.destroy`, `M.ensure`, new private helpers only), prototypes/hidden.lua, prototypes/tier.lua, tests/offline/test_arms.lua, tests/offline/test_data_hidden.lua, tests/offline/test_data.lua. Never touch anything else.

Re-cut because: none

# bound: 2400s
