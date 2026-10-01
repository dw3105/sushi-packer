# 045 — lifecycle: hidden parts follow box; old saves

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-045_lifecycle`, branch `lane/045_lifecycle`, base tag `lanes-base-v15`, merge target `int/v14`. Host `dev-vm`.

Lanes 040 data (`prototypes/hidden.lua`), 041 ledger (`scripts/ledger.lua`), 042 arms (`scripts/arms.lua`), 043 gui (`scripts/gui.lua`), 044 tick (`scripts/tick.lua`), 045 lifecycle (`scripts/registry.lua`, `scripts/copy.lua`), 046 text (`locale/*`, texts) run beside you or after you. No shared file. Seam = `docs/CONTRACT.md` section "v15 arms box seam (V15-1)". Read it first, it is law: names, signatures, rec fields, who owns what.

## You have about 45 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v15`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- New box, very short: hidden inserters ("arms"), each locked to one belt lane, drop items into hidden chest of that lane ("lane store", `N.STORE_SLOTS` = 12 slots). Engine moves items in. Script only pushes belt stacks out of each lane store onto same lane of front belt.
- Names in `scripts/names.lua`: `N.ARM`, `N.STORE`, `N.STORE_SLOTS`, `N.ARM_FILTERS`, `N.ARMS`.
- Stubs at base: `scripts/ledger.lua`, `scripts/arms.lua`, `prototypes/hidden.lua` (each lane fills its own; in your tests fake the others).
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API named in seam or already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. State only in `storage` / `rec` (plain values and engine object references).
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- `scripts/registry.lua`: `M.new_rec` line 42 (rec made with `box = core.new_box()`), `M.on_built` line 52, `M.on_removed` line 75 (mined: `e.buffer`; upgrade: `M.stash`), `M.on_died` line 95, `M.swap` line 106 (rotation: destroys box entity, creates other variant, copies inventory + wires, rekeys `storage.boxes`), `M.stash` line 162 / `M.take_stash` line 180 (upgrade planner), `M.on_configuration_changed` line 212. `scripts/copy.lua` `M.on_cloned` line 71 (rec made by hand with `core.new_box()`).
- New: every rec gets `rec.ledger = ledger.new()` and no `rec.box`; after rec is bound to a box entity call `arms.create(rec)` (seam). Lane stores are not direction-bound: on rotation keep stores (`arms.destroy(rec, true)` before old entity is destroyed is NOT needed: stores are own entities at same position; just call `arms.create(rec)` after rebinding: it reuses valid stores, replaces arms, rewires to new box entity).
- Mined box (`e.buffer` present): every stack of both lane stores goes into `e.buffer` (`buffer.insert`), then `arms.destroy(rec)`. Box died: store contents spilled like box contents (helper `spill` line 13), then `arms.destroy(rec)`. Upgrade stash: stores stay in world; `take_stash` rebinds rec then `arms.create(rec)` (arm count follows new tier). Stale stash pruned (line 156): destroy its parts, spill its store items at stash position.
- Clone (`copy.on_cloned`): destination gets own parts (`arms.create`), source store contents copied stack by stack into destination stores, settings copied as today.
- Old saves (`on_configuration_changed`): rec with `rec.box` and without `rec.stores`: `rec.extra` = list of `{ name, quality, count, lane }` built from old core box records (`rec.box.partials[i]`, `rec.box.ready[lane][i]`: fields `name`, `quality`, `lane`, `count`; same kind + lane merged) plus old pass-through hold `rec.box.hold[lane]` (`{name, quality, count}`; those items are not in box container: insert them into box container first; what does not fit is spilled and left out of `rec.extra`); items stay in box container; then `rec.box = nil`, `rec.ledger = ledger.new()`, `rec.in_credit = nil`, `arms.create(rec)`. Rec already migrated: `arms.ensure(rec)`. Invalid entity recs dropped as today; `led.ensure` as today.
- `scripts.core` is no longer required by `registry.lua` / `copy.lua` after your change (old-save reader touches plain tables only).
- Existing tests `tests/offline/test_registry.lua`, `tests/offline/test_copy.lua` (you own): update expectations the seam forces (no `rec.box`, hold handling), keep every other test green and unchanged; list each changed test with reason in report.

## Explain very simply

Box now has helpers on its tile. When box is built, turned, upgraded, copied, mined or destroyed, helpers and their items must follow: nothing left behind, nothing lost. Boxes from old saves get helpers too and keep their items.

## What to build

### Tests first — new `tests/offline/test_lifecycle_arms.lua`, describe `lifecycle arms`; each seen RED before code

Fake `arms` (record calls; `create` fills `rec.stores` / `rec.invs` with fake inventories), fake `ledger.new`, surface / entity fakes as in `tests/offline/test_registry.lua`.

- `lifecycle arms > built box gets ledger and parts` — after `on_built`: `rec.ledger` set, `rec.box == nil`, `arms.create(rec)` called once with bound rec. RED.
- `lifecycle arms > rotate keeps stores and rebuilds arms` — `swap`: `arms.create` called after rebinding with new `rec.dir` / entity; store inventories untouched; no `arms.destroy` without keep. RED.
- `lifecycle arms > mined box returns store items` — both lane inventories' stacks inserted into `e.buffer` (name, count, quality), then `arms.destroy(rec)`. RED.
- `lifecycle arms > died box spills store items` — spill calls for store stacks, then `arms.destroy(rec)`. RED.
- `lifecycle arms > upgrade carries stores` — robot mine of box marked for upgrade + build of next tier same tick: rec rebound, `arms.create` called, no store item in buffer / spilled. RED.
- `lifecycle arms > clone gets own parts and copies items` — destination `arms.create`; store stacks copied; source untouched. RED.
- `lifecycle arms > old save becomes extra` — rec with old `box` (2 partials + 1 ready stack on lanes 1 / 2, hold item on lane 2): `rec.extra` lists kinds with right lane + count (merged per kind + lane), hold item inserted into box container, `rec.box == nil`, `rec.ledger` set, `arms.create` called. RED.
- `lifecycle arms > migrated rec only ensured` — second `on_configuration_changed`: `arms.ensure(rec)` called, `rec.extra` not rebuilt. RED.
- `lifecycle arms > stale stash cleans its parts` — pruned stash: `arms.destroy` + store items spilled. RED.

### Code — `scripts/registry.lua`, `scripts/copy.lua`

Per "What is true".

### Mutation

Skip store items on mine -> `lifecycle arms > mined box returns store items` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_lifecycle_arms.lua::lifecycle arms > built box gets ledger and parts'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua tests/offline/test_lifecycle_arms.lua`.

Keep-green list `tests/offline/fixtures/v15_keep_green.txt` (one `<file>::<name>` per line), run as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v15_keep_green.txt
```

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `data.lua`, `scripts/names.lua`, `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fixtures/*`, anything under `tests/game/`, `tools/*`, `Makefile`. Checks also run whole files you own: keep every remaining test in them green. Never weaken a test to hide a defect. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v15..HEAD`.

## What done mean

```checks
{"name": "lane045-scope", "command": "git diff --name-only lanes-base-v15 HEAD | grep -Ev '^(scripts/(registry|copy)\\.lua|tests/offline/test_(lifecycle_arms|registry|copy)\\.lua)$' | ( ! grep . ) && echo lane045-scope-ok", "expect_exit": 0, "expect_regex": "lane045-scope-ok", "timeout_s": 60}
{"name": "lane045-tests", "command": "( for t in 'built box gets ledger and parts' 'rotate keeps stores and rebuilds arms' 'mined box returns store items' 'died box spills store items' 'upgrade carries stores' 'clone gets own parts and copies items' 'old save becomes extra' 'migrated rec only ensured' 'stale stash cleans its parts'; do tools/run_tests.sh 2.0 \"tests/offline/test_lifecycle_arms.lua::lifecycle arms > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_lifecycle_arms.lua ) && echo lane045-tests-ok", "expect_exit": 0, "expect_regex": "lane045-tests-ok", "timeout_s": 300}
{"name": "lane045-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v15_keep_green.txt ) && echo lane045-keep-green-ok", "expect_exit": 0, "expect_regex": "lane045-keep-green-ok", "timeout_s": 900}
```

## Files this lane owns

scripts/registry.lua, scripts/copy.lua, tests/offline/test_lifecycle_arms.lua (new), tests/offline/test_registry.lua, tests/offline/test_copy.lua. Never touch anything else.

Re-cut because: none

# bound: 2700s
