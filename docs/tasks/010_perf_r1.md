# 010 — perf for R-1: cached belts, circuit early return, per-tier cadence

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-010_perf_r1`, branch `lane/010_perf_r1`, base tag `wave3-base`, merge target `int/v1`. Host `dev-vm`.

This task is complete in itself.

## You have about 45 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every signature in `tests/offline/contract.lua`; every behaviour asserted by the existing offline tests named in the checks; every file outside "Files this lane owns" byte-identical to `wave3-base`.

- R-1 (`docs/REQUIREMENTS.md` §11): 200 boxes ≤ 1 ms/tick script time. Measured on `wave3-base` (integrator, headless bench, 200 yellow boxes, 3600 ticks): `script_ms_avg=20.536`. R-2 allows batching (`on_nth_tick`-style cadence) as long as tier throughput holds. Decision PERF-1 in `docs/DECISIONS.md` fixes the design below.
- Per box per tick today (`scripts/tick.lua:56-122`): `circuit.evaluate` calls `get_circuit_network` twice (`scripts/circuit.lua:13-38`); `belt_io.pull` calls `M.behind` → `surface.find_entities_filtered` before checking budget (`scripts/belt_io.lua:44-70`, `:14-34`); `belt_io.push` calls `M.front` → `find_entities_filtered` per push (`:72-81`); `get_inventory` every tick (`scripts/tick.lua:68`); loop over `game.connected_players` per box (`:112`).
- New storage field `rec.belt = { behind = LuaEntity|nil, front = LuaEntity|nil, scan = 0 }` owned by `scripts/belt_io.lua` (`docs/CONTRACT.md` storage layout). Recs built before this change lack it: create on first use.
- Tier rates `scripts/names.lua:13-16` (`lane_rate` 0.125, 0.25, 0.375, 0.5 belt items per lane per tick). One `insert_at_back` per lane per visit is the physical limit (back slot fills), so visit interval must be ≤ `1 / lane_rate`.
- Offline runner and mock style: see `tests/offline/test_tick.lua` (fixture with fake inventory, fake `belt_io`, `circuit`, `led`) and `tests/offline/test_belt_io.lua` (fake surface). Globals `game`, `defines`, `storage`, `settings`, `prototypes` are plain tables in tests; `game.tick` readable.

## Explain very simply

Box does costly game lookups every tick. Make it remember its belts, skip circuit reads when circuit unused, and wake each box only as often as its belt tier can move an item (yellow every 8 ticks), moving the same amount per visit. LED still checked every tick (cheap).

## What to build

1. `scripts/circuit.lua` `evaluate`: `circuit.enable ~= true` and `circuit.flush ~= true` → return `true, false` with no entity call (keep `rec.circuit_state.last_flush = false`).
2. `scripts/belt_io.lua`: cache. `behind`/`front` lookups for a rec go through `rec.belt`: cached entity used while `valid` and still matching the rule of `find_belt` (direction, underground type); else cleared. Cleared or never found → rescan only when `game.tick >= rec.belt.scan + 60` (store `scan = game.tick` on every rescan). `pull` returns `{0, 0}` before any lookup when `budget[1] < 1` and `budget[2] < 1`. Public `behind(entity, dir)` / `front(entity, dir)` keep their uncached behaviour.
3. `scripts/tick.lua` cadence: local `INTERVAL = { yellow = 8, red = 4, blue = 2, turbo = 2 }`. Box processed (steps 2-8 of current code) only when `(e.tick + rec.unit_number) % INTERVAL[tier] == 0`; credits per visit `+ lane_rate * INTERVAL[tier]`, cap 2. Every tick for every enabled rec: `led.set(rec, core.led_state(rec.box), rec.enabled ~= false)` (V-5). Opened-box reconcile: build `opened[unit_number] = true` from `game.connected_players` once per `on_tick`; opened boxes reconcile every tick; others on the existing 60-tick rule. Chest inventory fetched once per visit, only when needed. Idle rule stays (`next_poll`).
4. Update `tests/offline/test_tick.lua` only where cadence changes expected numbers (e.g. `intake budget follows tier rate`: run on visit ticks, expect `lane_rate * 8`); never weaken what a test proves.

### Tests to write (exact names; each red on `wave3-base` first)

`tests/offline/test_perf.lua`, `describe("perf", ...)`, count fake API calls:
- `perf > circuit off makes no network calls`
- `perf > behind belt looked up once while valid`
- `perf > missing belt rescanned at most every 60 ticks`
- `perf > rotated cached belt is dropped`
- `perf > pull with zero budget makes no belt calls`
- `perf > yellow box visited every 8 ticks`
- `perf > turbo box visited every 2 ticks`
- `perf > visits staggered by unit number`
- `perf > credits per visit keep tier rate over 800 ticks`
- `perf > led checked every tick`
- `perf > opened set built once per tick`

## Test rule — read twice

**Lanes run offline Lua tests only (SP-02 v0.2).** Never start Factorio, never `tests/game/*`, never `make test`, never `--full`, never a file-wide run. One test at a time:

```
make test-one T='tests/offline/test_perf.lua::perf > yellow box visited every 8 ticks'
```

**Never edit** anything outside "Files this lane owns" (this task file, `docs/*`, `tests/offline/contract.lua`, `tests/offline/run.lua`, guard tests, `tests/game/*`, `scripts/names.lua`, `control.lua`, `Makefile`, `tools/*` included). Never change a function signature. Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Checks last.

## What done mean

```checks
{"name": "lane010-scope", "command": "git diff --name-only wave3-base HEAD | grep -Ev '^(scripts/tick\\.lua|scripts/belt_io\\.lua|scripts/circuit\\.lua|tests/offline/test_perf\\.lua|tests/offline/test_tick\\.lua|tests/offline/test_belt_io\\.lua)$' | ( ! grep . ) && echo lane010-scope-ok", "expect_exit": 0, "expect_regex": "lane010-scope-ok", "timeout_s": 60}
{"name": "lane010-tests", "command": "( for t in 'circuit off makes no network calls' 'behind belt looked up once while valid' 'missing belt rescanned at most every 60 ticks' 'rotated cached belt is dropped' 'pull with zero budget makes no belt calls' 'yellow box visited every 8 ticks' 'turbo box visited every 2 ticks' 'visits staggered by unit number' 'credits per visit keep tier rate over 800 ticks' 'led checked every tick' 'opened set built once per tick'; do tools/run_tests.sh 2.0 \"tests/offline/test_perf.lua::perf > $t\" || exit 1; done && for t in 'timeout ticks custom and global' 'on research caches belt stack size' 'invalid entity drops rec' 'disabled box moves nothing and hides led' 'flush signal queues partials' 'intake budget follows tier rate' 'stored item goes to core and chest' 'filtered item goes to hold not chest' 'filter without quality matches any quality' 'output piece capped at belt stack size' 'output removes stored items from chest' 'passthrough output leaves chest alone' 'output rate never above tier rate' 'blocked lane does not stall other lane' 'led follows core state' 'opened box reconciles next tick' 'closed box reconciles every 60 ticks' 'idle box sleeps 30 ticks' 'belt stack computed when cache empty'; do tools/run_tests.sh 2.0 \"tests/offline/test_tick.lua::tick > $t\" || exit 1; done && for t in 'front accepts same direction belt' 'front refuses sideways belt' 'front refuses belt facing box' 'front accepts underground input same direction' 'behind still requires belt moving into box'; do tools/run_tests.sh 2.0 \"tests/offline/test_belt_io.lua::belt_io > $t\" || exit 1; done && for t in 'compare all six comparators' 'compare unknown comparator is false' 'compare false cases' 'enable nil means condition off' 'enable true applies condition'; do tools/run_tests.sh 2.0 \"tests/offline/test_circuit.lua::circuit > $t\" || exit 1; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane010-tests-ok", "expect_exit": 0, "expect_regex": "lane010-tests-ok", "timeout_s": 300}
```

## Files this lane owns

scripts/tick.lua, scripts/belt_io.lua, scripts/circuit.lua, tests/offline/test_perf.lua, tests/offline/test_tick.lua, tests/offline/test_belt_io.lua. Never touch anything else.

Re-cut because: none

# bound: 2700s

Reviewer ask: read `git diff wave3-base HEAD`; confirm the rate test runs ≥ 800 ticks and bounds pushed belt items both above (≤ rate·ticks + 2) and below (≥ rate·ticks − 2), and every changed `test_tick.lua` assertion stays as strong.
