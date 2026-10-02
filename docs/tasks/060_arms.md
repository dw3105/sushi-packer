# 060 — arms: in hand sizes by pattern, more out hands on fast belts

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-060_arms`, branch `lane/060_arms`, base tag `lanes-base-v21`, merge target `int/v21`. Host `dev-vm`.

Lanes 059 gui (`scripts/gui.lua`) and 061 flow (`scripts/ledger.lua`, `scripts/tick.lua`) run beside you. No shared file. Integrator works on `tests/game/*` and docs.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v21`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- Packer, very short: belt-kind body entity (`N.body(tier)`) plus hidden parts on same tile: two lane stores (`rec.stores[lane]`, inventory `rec.invs[lane]`, `N.STORE_SLOTS` slots = 24 since this seam, was 12), hidden in hands `rec.arms[lane]` (inserters `N.ARM`, take from belt lane behind, drop into lane store), mop hands `rec.mop[lane]`, out hands `rec.out[lane]` (take belt stacks from lane store, drop on front belt). Engine way = out hands work; script way (skip list set, or game without stacking) = out hands paused, script pushes stacks.
- Why: author on public v1.20: belt behind packer jerks. Measured cause and fix: `docs/FINDINGS.md` FND-0053. Seam constants already in `scripts/names.lua` (section "v21"): `N.STORE_SLOTS = 24`, `N.ARM_HANDS = { 1, 4, 4, 4 }`, `N.OUT_FAST = { speed = 0.3, n = 12 }`, `N.out_count(speed)`, `N.HOT_LOOK = 5`, `N.HOT_FREE = 3`, `N.PRESS = 1`.
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. Never add a key to a table while walking it with `pairs` (setting an existing key or setting a key to nil is fine). State only in `storage` / `rec` (plain values and engine object references). Engine objects are userdata: test validity with `part ~= nil and part.valid == true`, never `type(part) == "table"`.
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- Every engine call costs time: never repeat a write whose value did not change, never build tables per call on hot paths.

## Explain very simply

An in hand that holds fewer items than its size hangs over belt about 20 ticks waiting for more of same kind. Belt then stands. Fix measured in game: one in hand of every four gets size 1 (never waits), others keep size 4. Second fix: belts faster than 0.3 tiles per tick get 12 out hands per lane instead of 8. Packers from old saves must get both without losing items.

## What to build

### Facts about current `scripts/arms.lua`

- `M.create(rec)`: saves hands of old arms into lane store, destroys old arms, makes per lane `n = M.count(speed)` in hands (`rec.arms[lane]`), `N.MOP_ARMS` mop hands (`rec.mop[lane]`), `N.OUT_ARMS` out hands (`rec.out[lane]`, each gets `inserter_stack_size_override = bss`, starts `disabled_by_script = true`). `speed = prototypes.entity[N.TIER[rec.tier].belt].belt_speed`.
- `M.ensure(rec)`: rebuilds (calls `M.create`) when a part is missing or a count differs (`#outs ~= N.OUT_ARMS` today); returns whether it rebuilt.
- `M.hand(rec, bss)` writes out hand size; do not change.
- Engine: `arm.inserter_stack_size_override = k` makes that inserter hold at most k items (prototype allows up to `N.ARM_HAND` = 4).

### Rule

- In hand number i (1-based, order of `rec.arms[lane]`) of each lane has size `N.ARM_HANDS[(i - 1) % #N.ARM_HANDS + 1]`, capped at `N.ARM_HAND`: written as `inserter_stack_size_override` right after the arm is made in `create`.
- Private helper `_in_hands(rec)` does the writes for all in hands of both lanes and sets `rec.in_hands = table.concat(N.ARM_HANDS, ",")`. `create` uses it (after making arms). Mop hands and out hands: no change (mop: no override; out: `bss`).
- Out hands per lane: `N.out_count(speed)` in `create`; `ensure` compares `#outs` with `N.out_count(speed)` of the packer's tier belt.
- `ensure`: when nothing is broken and `rec.in_hands ~= table.concat(N.ARM_HANDS, ",")` (packer from before v1.21): call `_in_hands(rec)`, no rebuild, return value as for "not rebuilt". When `rec.in_hands` already matches: zero writes.
- Nothing else changes: positions, lane flags, targets, pause state, wires, hood.

### Tests first — in `tests/offline/test_arms.lua` (describe `arms v21`); each seen RED before code

- `arms v21 > in hands get sizes by pattern` — yellow (4 in hands per lane): overrides `1, 4, 4, 4` on both lanes; tier with 8 in hands: `1, 4, 4, 4, 1, 4, 4, 4`; with `N.ARM_HANDS` swapped in test to `{ 2, 9 }` (restore after): `2, 4, 2, 4` (cap at `N.ARM_HAND`). `rec.in_hands` set.
- `arms v21 > mop and out hands keep their size` — mop hands: no override written; out hands: override = belt stack size as before.
- `arms v21 > out hand count follows belt speed` — belt speed 0.125: `#rec.out[lane] == N.OUT_ARMS`; speed 0.3: `N.OUT_ARMS`; speed 0.5625: `N.OUT_FAST.n`; out hand prototype name still `N.out_name(speed)` (or `N.OUT` fallback).
- `arms v21 > ensure sets hand sizes of old packer without rebuild` — complete packer whose `rec.in_hands == nil` and arms without override: `ensure` writes overrides by pattern, same arm objects kept (no destroy, no create_entity), returns false.
- `arms v21 > ensure rebuilds when out hand count differs` — fast belt packer with 8 out hands per lane: `ensure` rebuilds, then 12 per lane; items held in old hands end in lane store.
- `arms v21 > ensure on current packer writes nothing` — second `ensure`: zero property writes on arms, zero create_entity.

### Code — `scripts/arms.lua`

As rule. Keep `create` order of engine calls otherwise unchanged.

### Mutation

In `_in_hands` use index `i % #N.ARM_HANDS + 1` -> `in hands get sizes by pattern` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_arms.lua::arms v21 > in hands get sizes by pattern'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua <own file>`.

Keep-green list `tests/offline/fixtures/v21_keep_green.txt` (one `<file>::<name>` per line, tests in files no lane owns), run as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v21_keep_green.txt
```

Old tests in files you own that pin replaced behaviour (12 slots, old flush rule, 8 out hands on every belt): rewrite them to the new rule, never delete a still-true test, say in report which ones changed and why. Some tests in your files are red at base only because `N.STORE_SLOTS` is now 24: fix those too.

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `data.lua`, `scripts/names.lua`, `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fixtures/*`, anything under `tests/game/`, `tools/*`, `Makefile`. Never weaken a test to hide a defect. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v21..HEAD`, list of old tests rewritten.

## What done mean

```checks
{"name": "lane060-scope", "command": "git diff --name-only lanes-base-v21 HEAD | grep -Ev '^(scripts/arms\\.lua|tests/offline/test_arms\\.lua|tests/offline/test_lifecycle_arms\\.lua)$' | ( ! grep . ) && echo lane060-scope-ok", "expect_exit": 0, "expect_regex": "lane060-scope-ok", "timeout_s": 60}
{"name": "lane060-tests", "command": "( for t in 'arms v21 > in hands get sizes by pattern' 'arms v21 > mop and out hands keep their size' 'arms v21 > out hand count follows belt speed' 'arms v21 > ensure sets hand sizes of old packer without rebuild' 'arms v21 > ensure rebuilds when out hand count differs' 'arms v21 > ensure on current packer writes nothing'; do tools/run_tests.sh 2.0 \"tests/offline/test_arms.lua::$t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_arms.lua && lua5.2 tests/offline/run.lua tests/offline/test_lifecycle_arms.lua ) && echo lane060-tests-ok", "expect_exit": 0, "expect_regex": "lane060-tests-ok", "timeout_s": 600}
{"name": "lane060-guard", "command": "tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && echo lane060-guard-ok", "expect_exit": 0, "expect_regex": "lane060-guard-ok", "timeout_s": 120}
{"name": "lane060-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v21_keep_green.txt ) && echo lane060-keep-green-ok", "expect_exit": 0, "expect_regex": "lane060-keep-green-ok", "timeout_s": 1500}
```

## Files this lane owns

scripts/arms.lua, tests/offline/test_arms.lua, tests/offline/test_lifecycle_arms.lua. Never touch anything else.

Re-cut because: none

# bound: 2400s
