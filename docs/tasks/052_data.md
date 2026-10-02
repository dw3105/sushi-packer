# 052 — data: belt body, hood, legacy boxes hidden

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-052_data`, branch `lane/052_data`, base tag `lanes-base-v17`, merge target `int/v17`. Host `dev-vm`.

Lanes 052 data (`prototypes/tier.lua`, `prototypes/extra.lua`), 053 arms (`scripts/arms.lua`), 054 io (`scripts/belt_io.lua`, `scripts/circuit.lua`), 055 gui (`scripts/gui.lua`), 056 lifecycle (`scripts/registry.lua`, `scripts/copy.lua`) run beside you. No shared file. Seam = `docs/CONTRACT.md` section "v17 belt body seam (V17-1..5)". Read it first, it is law: names, signatures, rec fields, who owns what. Sections "v15 arms box seam" and "v16 engine output seam" above it still hold for everything v17 does not change.

## You have about 50 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v17`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- New packer, very short: v16 packer (hidden in arms pull from belt lane behind into hidden lane stores, hidden out arms push belt stacks to front) with a new body: the entity player sees is a belt-kind entity (`transport-belt` prototype, "body"), not a chest. Body is kept shut by script so nothing rides onto it. Legacy chest entities stay only so old saves load; they are swapped to bodies.
- Facts proven in real game on 2.0 and 2.1: `docs/FINDINGS.md` FND-0048 (read its table).
- Stubs at base: new functions of other lanes are `error("stub: ...")`; in your tests fake the other modules.
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API named in seam or already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. State only in `storage` / `rec` (plain values and engine object references). Engine objects are userdata: test validity with `part ~= nil and part.valid == true`, never `type(part) == "table"`.
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- Every engine call costs time: never repeat a write whose value did not change, never build tables per call on hot paths.

## Explain very simply

Today each tier has 4 chest entities (one per direction). New: each tier gets one belt-kind body (copy of its belt) and one hood picture entity. Old chests stay but hidden, so old saves still load.

## What to build

### Facts about current code

- `prototypes/tier.lua` `M.make(tier, opts)` returns item, recipe, technology, placer (`simple-entity-with-owner`, 4-direction `picture`), 4 `container` variants (`N.variant(tier, dir)`), remnant. Called from `prototypes/packer.lua` (vanilla, data stage) and `prototypes/extra.lua` `M.build(raw)` (modded tiers, data-final-fixes). Early return (no technology unit) before entities stays as it is.
- `prototypes/extra.lua` `M.build(raw)` patches `raw.container[N.variant(...)]`: `next_upgrade` of top vanilla variant, one `collision_box` / `collision_mask` per chain.
- Offline data tests load prototypes with fakes in `tests/offline/fake_data.lua`; `tests/offline/golden_vanilla.lua` pins vanilla output.

### Tests first — in `tests/offline/test_data.lua` (describe `data v17`) and `tests/offline/test_data_extra.lua` (describe `data extra v17`); each seen RED before code

- `data v17 > body is belt copy per tier` — for yellow: `transport-belt` prototype `N.body("yellow")` exists; `speed`, `belt_animation_set`, `collision_box`, `circuit_connector` equal source belt values (deep equal); source belt table itself not modified (deepcopy).
- `data v17 > body fields` — every field of seam row "body" (name, icon, localised_name, minable, placeable_by, fast_replaceable_group, related_underground_belt nil, corpse, max_health, se_allow_in_space, icons nil, factoriopedia_simulation set).
- `data v17 > body upgrade chain` — `next_upgrade` = `N.body(opts.next)`; last tier nil.
- `data v17 > hood fields` — seam row "hood": type, 4-direction picture same as placer picture, empty collision mask, not selectable, hidden, flags, no minable.
- `data v17 > legacy boxes hidden without upgrade` — 4 variants still `container` with `inventory_size = N.SLOTS`, `hidden = true`, `next_upgrade == nil`, no `factoriopedia_simulation`, `placeable_by` kept.
- `data v17 > item still places placer` — `place_result = N.placer(tier)`.
- `data extra v17 > chain fix-ups go to bodies` — after `extra.build(raw)` with one extra tier: top vanilla body `next_upgrade` = first extra body; extra body `collision_box` / `collision_mask` deep-equal top vanilla body values; containers not given `next_upgrade`.
- `data extra v17 > source belt missing in raw` — tier whose belt is absent from `data.raw["transport-belt"]`: `tier.make` raises error naming tier and belt (never a nil index crash).

### Code

`prototypes/tier.lua`: build body and hood per seam; legacy variants per seam. `prototypes/extra.lua`: fix-ups on `raw["transport-belt"][N.body(key)]`. Update `tests/offline/fake_data.lua` (belts need `speed`, `belt_animation_set`, `collision_box`, `circuit_connector`) and `tests/offline/golden_vanilla.lua` to new output.

### Mutation

Drop `related_underground_belt = nil` -> `body fields` red; restore -> green. Never commit mutated state.


## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_data.lua::data v17 > body fields'
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

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v17..HEAD`, list of old tests rewritten.

## What done mean

```checks
{"name": "lane052-scope", "command": "git diff --name-only lanes-base-v17 HEAD | grep -Ev '^(prototypes/tier\\.lua|prototypes/extra\\.lua|tests/offline/test_data\\.lua|tests/offline/test_data_extra\\.lua|tests/offline/fake_data\\.lua|tests/offline/golden_vanilla\\.lua)$' | ( ! grep . ) && echo lane052-scope-ok", "expect_exit": 0, "expect_regex": "lane052-scope-ok", "timeout_s": 60}
{"name": "lane052-tests", "command": "( for t in 'body is belt copy per tier' 'body fields' 'body upgrade chain' 'hood fields' 'legacy boxes hidden without upgrade' 'item still places placer'; do tools/run_tests.sh 2.0 \"tests/offline/test_data.lua::data v17 > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_data.lua && lua5.2 tests/offline/run.lua tests/offline/test_data_extra.lua ) && echo lane052-tests-ok", "expect_exit": 0, "expect_regex": "lane052-tests-ok", "timeout_s": 600}
{"name": "lane052-guard", "command": "tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && echo lane052-guard-ok", "expect_exit": 0, "expect_regex": "lane052-guard-ok", "timeout_s": 120}
{"name": "lane052-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v17_keep_green.txt ) && echo lane052-keep-green-ok", "expect_exit": 0, "expect_regex": "lane052-keep-green-ok", "timeout_s": 1500}
```

## Files this lane owns

prototypes/tier.lua, prototypes/extra.lua, tests/offline/test_data.lua, tests/offline/test_data_extra.lua, tests/offline/fake_data.lua, tests/offline/golden_vanilla.lua. Never touch anything else.

Re-cut because: none

# bound: 3000s
