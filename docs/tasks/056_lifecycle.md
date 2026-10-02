# 056 — lifecycle: belt body is the packer; old chests become bodies

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-056_lifecycle`, branch `lane/056_lifecycle`, base tag `lanes-base-v17`, merge target `int/v17`. Host `dev-vm`.

Lanes 052 data (`prototypes/tier.lua`, `prototypes/extra.lua`), 053 arms (`scripts/arms.lua`), 054 io (`scripts/belt_io.lua`, `scripts/circuit.lua`), 055 gui (`scripts/gui.lua`), 056 lifecycle (`scripts/registry.lua`, `scripts/copy.lua`) run beside you. No shared file. Seam = `docs/CONTRACT.md` section "v17 belt body seam (V17-1..5)". Read it first, it is law: names, signatures, rec fields, who owns what. Sections "v15 arms box seam" and "v16 engine output seam" above it still hold for everything v17 does not change.

## You have about 60 minutes — do NOT stop early

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

Packer entity is now a belt-kind body. Build, mine, death, rotate, upgrade, clone, blueprint, paste must work on it. Chest packers of old saves are swapped to bodies once, with every item, setting and wire kept.

## What to build

### Facts about current code

- `scripts/registry.lua`: `on_built` swaps placer -> `N.variant(tier, dir)` chest and makes rec; `new_rec` reads `N.VARIANTS`; `swap(rec, new_dir)` re-creates chest for rotation; `on_removed` / `on_died` return store items, drained hands, chest items; `stash` / `take_stash` carry rec over robot upgrade; `on_configuration_changed` runs `migrate_old_box` (v1.14 recs: `rec.box` -> `rec.extra` with lane) then `arms.create` / `arms.ensure`.
- `scripts/copy.lua`: blueprint maps variant -> placer + tags; paste imports settings; clone copies stores.
- `storage.sched = nil` after every change of `storage.boxes` (tick schedule rebuild): keep.

### Tests first — `tests/offline/test_registry.lua` (describe `registry v17`), `tests/offline/test_copy.lua` (describe `copy v17`), `tests/offline/test_lifecycle_arms.lua` (describe `lifecycle v17`); each seen RED before code. Fake `scripts.arms` and `scripts.circuit` via `package.loaded` (recorders).

- `registry v17 > placer becomes body` — built placer `fast-sushi-packer-placer` facing east: placer destroyed, `surface.create_entity` called with `name = N.body("red")`, `direction = defines.direction.east`, same position / force / quality; rec `{ tier = "red", dir = "east" }` keyed by body unit; `arms.create` once; `circuit.apply` once (no control behaviour on fresh body); `arms.wire(rec, true)`.
- `registry v17 > legacy box built becomes body` — built entity `sushi-packer-south` (old blueprint): destroyed, body `N.body("yellow")` with `direction = defines.direction.south`.
- `registry v17 > body with control behaviour is synced` — built body whose `get_control_behavior()` returns a table: `circuit.sync` once, `circuit.apply` not called.
- `registry v17 > tags imported before sync` — `e.tags.sushi_packer` settings imported, then sync / apply order recorded.
- `registry v17 > new_rec only for bodies` — legacy name or placer: nil.
- `registry v17 > rotated updates dir and parts` — `on_rotated({ entity = body })` after body.direction = north: `rec.dir == "north"`, `arms.create` once, LED destroyed + created, old LED state restored by `led.set`. Entity without rec: nothing.
- `registry v17 > removal never reads chest inventory` — body fake without `get_inventory`: `on_removed` (buffer and no buffer) and `on_died` do not raise; store items and drained hands returned as today.
- `registry v17 > migrate chest to body` — rec with legacy box holding 5 plates, `rec.extra = { { name = "coal", quality = "normal", lane = 2, count = 7 } }`, one player red wire to a pole and one script-origin wire to a store: after `migrate(rec)`: body created with tier / direction / force / quality of chest; chest destroyed; `storage.boxes` re-keyed (old unit nil, new unit rec); plates in lane 1 store, coal in lane 2 store, `rec.extra == nil`; player wire connected from body connector to pole with player origin, script wire not copied; `rec.settings.circuit.read == true`; `circuit.apply` once; `arms.destroy(rec, true)` before chest destroy and `arms.create` after; LED re-created with old state; `storage.sched == nil`.
- `registry v17 > migrate overflow is spilled` — store `insert` takes only part: rest spilled at position; nothing dropped silently (sum of inserted + spilled == before).
- `registry v17 > migrate without body drops rec with items spilled` — `create_entity` returns nil: every chest / store / hand item spilled, parts destroyed, rec removed, returns nil.
- `registry v17 > config change migrates legacy recs once` — one legacy rec (-> `migrate`), one body rec (-> `arms.ensure`, `led.ensure`, no migrate), one v1.14 rec with `rec.box` (old path first, then migrate).
- `registry v17 > stash and take_stash for bodies` — robot upgrade mine of body marked for upgrade stashes; built `N.body("red")` same tick / position takes rec, `tier = "red"`, dir from entity direction.
- `copy v17 > default has read on` — `default_settings().circuit.read == true`; `import` of old settings without `read` fills true.
- `copy v17 > blueprint keeps body and tags it` — entity named `N.body("yellow")`: name and direction unchanged, `tags.sushi_packer` = export.
- `copy v17 > paste syncs belt settings` — after import: `circuit.sync(dst)` once, `arms.wire(dst, <read>)` once.
- `copy v17 > clone of body` — rec for destination body (tier by `N.BODIES`, dir by direction), stores copied, `circuit.sync` after `arms.create`.
- `lifecycle v17 > mined body returns hands` — existing hand tests re-pinned on body fakes.

### Code — `scripts/registry.lua`, `scripts/copy.lua`

Per seam tables. `scripts/registry.lua` requires `scripts.circuit` at file top. Remove stubs. Leave `swap` and `on_rotate_input` in place (legacy).

### Mutation

In `migrate` skip the origin check (copy script wires too) -> `migrate chest to body` red; restore -> green. Never commit mutated state.


## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_registry.lua::registry v17 > migrate chest to body'
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
{"name": "lane056-scope", "command": "git diff --name-only lanes-base-v17 HEAD | grep -Ev '^(scripts/registry\\.lua|scripts/copy\\.lua|tests/offline/test_registry\\.lua|tests/offline/test_copy\\.lua|tests/offline/test_lifecycle_arms\\.lua)$' | ( ! grep . ) && echo lane056-scope-ok", "expect_exit": 0, "expect_regex": "lane056-scope-ok", "timeout_s": 60}
{"name": "lane056-tests", "command": "( for t in 'placer becomes body' 'legacy box built becomes body' 'body with control behaviour is synced' 'tags imported before sync' 'new_rec only for bodies' 'rotated updates dir and parts' 'removal never reads chest inventory' 'migrate chest to body' 'migrate overflow is spilled' 'migrate without body drops rec with items spilled' 'config change migrates legacy recs once' 'stash and take_stash for bodies'; do tools/run_tests.sh 2.0 \"tests/offline/test_registry.lua::registry v17 > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_registry.lua && lua5.2 tests/offline/run.lua tests/offline/test_copy.lua && lua5.2 tests/offline/run.lua tests/offline/test_lifecycle_arms.lua ) && echo lane056-tests-ok", "expect_exit": 0, "expect_regex": "lane056-tests-ok", "timeout_s": 600}
{"name": "lane056-guard", "command": "tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && echo lane056-guard-ok", "expect_exit": 0, "expect_regex": "lane056-guard-ok", "timeout_s": 120}
{"name": "lane056-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v17_keep_green.txt ) && echo lane056-keep-green-ok", "expect_exit": 0, "expect_regex": "lane056-keep-green-ok", "timeout_s": 1500}
```

## Files this lane owns

scripts/registry.lua, scripts/copy.lua, tests/offline/test_registry.lua, tests/offline/test_copy.lua, tests/offline/test_lifecycle_arms.lua. Never touch anything else.

Re-cut because: none

# bound: 3600s
