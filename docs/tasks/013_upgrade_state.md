# 013 — upgrade keeps box state (U-3)

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-013_upgrade_state`, branch `lane/013_upgrade_state`, base tag `lanes-base-1.1`, merge target `int/v1.1`. Host `legalcopilot-dev`.

This task is complete in itself. Lanes 012 and 014 run in parallel on other files; you never need them.

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua`; behaviour of `on_built` (placer → variant, tags import, LED), `on_removed` for normal mining (hold → `e.buffer`, else spill), `on_died`, `swap`; every file outside "Files this lane owns" byte-identical to `lanes-base-1.1`.

- Measured (FND-0006, 2.0.77 and 2.1.20): robot upgrade fires `on_robot_mined_entity` for old box (old `entity.valid`, `entity.to_be_upgraded() == true`, chest already emptied by engine, `e.buffer` present) then `on_robot_built_entity` for new variant, SAME `game.tick`, same position, same force. Engine moves chest items; script state (settings, core box, hold) is lost today (`scripts/registry.lua` `on_removed` drops rec; `on_built` makes `new_rec`).
- Contract (`docs/CONTRACT.md`, decision UPG): `storage.upgrade_stash = { [key] = { rec = rec, tick = uint, force = uint, wires = {...} } }`, `key = surface.index .. ":" .. position.x .. ":" .. position.y`. `registry.stash(rec)` and `registry.take_stash(entity) -> rec|nil` are stubs at `scripts/registry.lua` (`error("stub: task 013")`).
- Wire copy pattern already in `scripts/registry.lua` `M.swap` (reads `get_wire_connector(id, false).connections`, reconnects with `connect_to`).
- `rec.belt` cache is owned by `scripts/belt_io.lua`; setting `rec.belt = nil` makes it rescan.
- Mocks: offline runner loads the test file in plain `lua5.2` with `package.path = "./?.lua;..."`. Before requiring `scripts.registry`, set globals: `defines = { direction = { north = 0, east = 4, south = 8, west = 12 }, inventory = { chest = 1 }, wire_connector_id = { circuit_red = 1, circuit_green = 2 } }`, `storage = { boxes = {} }`, `game = { tick = 100 }`. Fake entity: `{ valid = true, name = "sushi-packer-yellow-east", unit_number = 11, position = { x = 10.5, y = 18.5 }, surface = { index = 1 }, force = { index = 1 }, to_be_upgraded = function() return true end, get_wire_connector = function(id, create) ... end, get_inventory = function() return inv end }`. Replace `led` with fakes by writing fields on `require("scripts.led")` (`create`, `destroy`, `ensure`, `set`) and restore at test end. Reset globals in each test.
- Offline runner: `describe`, `it`, `eq(found, expected, msg)`, `ok(cond, msg)` (`tests/offline/run.lua`).

## Explain very simply

When robots upgrade box, game removes old box and builds new one in same tick. Items move by themselves. Our settings and counters do not. So: old box leaving for upgrade → park its record. New box built on same spot same tick → take record back.

## What to build

1. `M.stash(rec)`: key from `rec.entity`; save `{ rec, tick = game.tick, force = rec.entity.force.index, wires = <list like swap> }`; `led.destroy(rec)`; `storage.boxes[rec.unit_number] = nil`; prune entries with `tick < game.tick`.
2. `M.take_stash(entity)`: prune entries with `tick < game.tick`; entry at key with `tick == game.tick` and `force == entity.force.index` → rebind `rec.entity`, `rec.unit_number`, `rec.tier`/`rec.dir` from `N.VARIANTS[entity.name]`, `rec.belt = nil`, `rec.next_poll = 0`; `storage.boxes[entity.unit_number] = rec`; reconnect each saved wire only when not already connected; remove entry; return rec. Else nil.
3. `M.on_removed(e)`: rec found and `entity.to_be_upgraded()` true → `M.stash(rec)`, return (hold stays in rec, not buffer). Else as today.
4. `M.on_built(e)`: variant with no rec → `M.take_stash(entity)` first; found → `led.create(rec)` (tags still imported if present); else `new_rec` as today.

### Tests to write (exact names; each red against current code first)

`tests/offline/test_registry.lua` (new), `describe("registry", ...)`:
- `registry > upgrade mine stashes rec`
- `registry > upgrade build takes stash`
- `registry > upgraded rec keeps settings box and hold`
- `registry > upgraded rec gets tier and dir from new entity`
- `registry > stash from older tick ignored and pruned`
- `registry > stash other force ignored`
- `registry > normal mine still returns hold to buffer`
- `registry > upgrade reconnects missing wires`

## Test rule — read twice

**Lanes run offline Lua tests only (SP-02 v0.2).** Never start Factorio, never run `tests/game/*`, never `make test`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_registry.lua::registry > upgrade build takes stash'
```

Game API is faked with plain Lua tables inside your test file. Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane013-scope", "command": "git diff --name-only lanes-base-1.1 HEAD | grep -Ev '^(scripts/registry\\.lua|tests/offline/test_registry\\.lua)$' | ( ! grep . ) && echo lane013-scope-ok", "expect_exit": 0, "expect_regex": "lane013-scope-ok", "timeout_s": 60}
{"name": "lane013-tests", "command": "( for t in 'upgrade mine stashes rec' 'upgrade build takes stash' 'upgraded rec keeps settings box and hold' 'upgraded rec gets tier and dir from new entity' 'stash from older tick ignored and pruned' 'stash other force ignored' 'normal mine still returns hold to buffer' 'upgrade reconnects missing wires'; do tools/run_tests.sh 2.0 \"tests/offline/test_registry.lua::registry > $t\" || exit 1; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane013-tests-ok", "expect_exit": 0, "expect_regex": "lane013-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/registry.lua, tests/offline/test_registry.lua. Never touch anything else.

Re-cut because: none

# bound: 1800s
