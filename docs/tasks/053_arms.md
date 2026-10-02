# 053 — arms: parts on belt body (mop arms, hood, shut, aim, wire)

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-053_arms`, branch `lane/053_arms`, base tag `lanes-base-v17`, merge target `int/v17`. Host `dev-vm`.

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

Hidden parts now hang on a belt-kind body, not on a chest. New small parts: 2 mop arms per lane that take what lands on body, a hood picture, a "shut" switch on body, out arms that can aim at a belt running across, and wires from stores to body that can be put on and off.

## What to build

### Facts about current `scripts/arms.lua`

- `M.create(rec)`: saves hands of old arms (store, then chest `rec.entity.get_inventory(defines.inventory.chest)`, then spill), makes stores, in arms (pickup = tile behind), out arms (drop = pos + f + a * s, pickup = pos - 0.3 * drop vector, hand override), wires stores to chest connector.
- `rec.dir` is a string (`"north"` ...); helpers `_delta`, `_opposite`, `_valid`, `_destroy` exist.

### Tests first — in `tests/offline/test_arms.lua` (describe `arms v17`); each seen RED before code

- `arms v17 > create never reads chest inventory` — fake body without `get_inventory`: `arms.create(rec)` does not raise; hand of old arm that does not fit store is spilled at body position (`surface.spill_item_stack` recorded with name, count, quality).
- `arms v17 > create makes mop arms` — `#rec.mop[1] == N.MOP_ARMS` and same lane 2; each: name `N.ARM`, `pickup_position` = `drop_position` = body position, lane flags per lane, `pickup_target == rec.entity`, `drop_target == rec.stores[lane]`, `destructible == false`.
- `arms v17 > create saves mop hands before replacing` — second `create` with a mop arm holding 3 plates: plates inserted into its lane store, old arm destroyed.
- `arms v17 > create makes hood once and turns it` — first create: one `N.hood(tier)` entity with direction of `rec.dir`, `destructible == false`; second create after `rec.dir` change: same entity, `direction` written; no second hood.
- `arms v17 > shut writes logistic condition` — `arms.shut(body)`: `connect_to_logistic_network == true`, `logistic_condition` deep-equals `N.SHUT`; circuit fields untouched. `create` calls it.
- `arms v17 > aim ahead and across` — expected drop and pickup positions computed by seam formula for all 4 directions, both lanes, both kinds (table in test); pickup = pos - 0.3 * (drop - pos).
- `arms v17 > aim unchanged writes nothing` — second `aim_out(rec, "across")`: zero writes on arms.
- `arms v17 > wire on off` — `wire(rec, true)`: 4 `connect_to` (2 stores x red, green) to body connector with `defines.wire_origin.script`; again `true`: no call; `wire(rec, false)`: 4 `disconnect_from`. `create` wires by `rec.settings.circuit.read ~= false`.
- `arms v17 > pause covers mop arms` — `pause(rec, 1, true)`: lane 1 mop arms `disabled_by_script = true`, lane 2 untouched.
- `arms v17 > destroy and drain cover mop arms and hood` — `drain_hands` returns mop hand with lane; `destroy` destroys mop arms and hood, clears `rec.mop`, `rec.hood`, `rec.aim`, `rec.wired`.
- `arms v17 > ensure sees missing mop arms or hood` — rec without `rec.mop` -> rebuilt; with invalid hood -> rebuilt; complete -> `false`.
- `arms v17 > need_slot sees mop hand` — mop arm holds kind absent from contents -> true.

### Code — `scripts/arms.lua`

Per seam table. Remove stubs. `aim_out` shares one private helper with `create`.

### Mutation

In `aim_out` swap 0.75 for 1 in across branch -> `aim ahead and across` red; restore -> green. Never commit mutated state.


## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_arms.lua::arms v17 > wire on off'
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
{"name": "lane053-scope", "command": "git diff --name-only lanes-base-v17 HEAD | grep -Ev '^(scripts/arms\\.lua|tests/offline/test_arms\\.lua)$' | ( ! grep . ) && echo lane053-scope-ok", "expect_exit": 0, "expect_regex": "lane053-scope-ok", "timeout_s": 60}
{"name": "lane053-tests", "command": "( for t in 'create never reads chest inventory' 'create makes mop arms' 'create saves mop hands before replacing' 'create makes hood once and turns it' 'shut writes logistic condition' 'aim ahead and across' 'aim unchanged writes nothing' 'wire on off' 'pause covers mop arms' 'destroy and drain cover mop arms and hood' 'ensure sees missing mop arms or hood' 'need_slot sees mop hand'; do tools/run_tests.sh 2.0 \"tests/offline/test_arms.lua::arms v17 > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_arms.lua ) && echo lane053-tests-ok", "expect_exit": 0, "expect_regex": "lane053-tests-ok", "timeout_s": 600}
{"name": "lane053-guard", "command": "tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && echo lane053-guard-ok", "expect_exit": 0, "expect_regex": "lane053-guard-ok", "timeout_s": 120}
{"name": "lane053-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v17_keep_green.txt ) && echo lane053-keep-green-ok", "expect_exit": 0, "expect_regex": "lane053-keep-green-ok", "timeout_s": 1500}
```

## Files this lane owns

scripts/arms.lua, tests/offline/test_arms.lua. Never touch anything else.

Re-cut because: none

# bound: 3000s
