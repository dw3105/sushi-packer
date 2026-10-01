# 041 — ledger: pure rules for what leaves a lane store

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-041_ledger`, branch `lane/041_ledger`, base tag `lanes-base-v15`, merge target `int/v14`. Host `dev-vm`.

Lanes 040 data (`prototypes/hidden.lua`), 041 ledger (`scripts/ledger.lua`), 042 arms (`scripts/arms.lua`), 043 gui (`scripts/gui.lua`), 044 tick (`scripts/tick.lua`), 045 lifecycle (`scripts/registry.lua`, `scripts/copy.lua`), 046 text (`locale/*`, texts) run beside you or after you. No shared file. Seam = `docs/CONTRACT.md` section "v15 arms box seam (V15-1)". Read it first, it is law: names, signatures, rec fields, who owns what.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v15`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- New box, very short: hidden inserters ("arms"), each locked to one belt lane, drop items into hidden chest of that lane ("lane store", `N.STORE_SLOTS` = 12 slots). Engine moves items in. Script only pushes belt stacks out of each lane store onto same lane of front belt.
- Names in `scripts/names.lua`: `N.ARM`, `N.STORE`, `N.STORE_SLOTS`, `N.ARM_FILTERS`, `N.ARMS`.
- Stubs at base: `scripts/ledger.lua`, `scripts/arms.lua`, `prototypes/hidden.lua` (each lane fills its own; in your tests fake the others).
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API named in seam or already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. State only in `storage` / `rec` (plain values and engine object references).
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- Module is pure Lua: no `game`, `storage`, `prototypes`, `defines`, no engine object. Everything comes in as arguments.
- Rules it replaces (in `docs/REQUIREMENTS.md`): C-2 full stack N = min(belt stack, item stack size); C-4 ready order; F-1 flush oldest partial when lane store is full; S-1 flush timer from first arrival of kind; P-1..P-3 skip-list items leave without waiting for full stack; N-4 flush signal; C-6 hoarding (one inventory stack per kind per lane); V-2..V-4 LED.
- Contents arrive in engine order (not stable for you): never let input order or `pairs` order decide output; sort.
- Called once per lane per visit (every 2-8 ticks per box): keep it cheap: no key string built for a kind already in `state.seen` lookup path more than once per call, no table per kind beyond result pieces.

## Explain very simply

Lane store is a small chest with mixed items. This module looks at what is inside and says: these stacks may leave now, in this order. It also remembers when each kind first showed up, so old leftovers get flushed.

## What to build

### Tests first — new `tests/offline/test_ledger.lua`, describe `ledger`; each seen RED before code

Helper `opts(t)` with defaults `tick = 100, bss = 4, stack_size = function() return 100 end, timeout_ticks = 0, slots_used = 1, slots = 12`.

- `ledger > full stacks leave partial stays` — contents iron 9: pieces iron 4, iron 4; nothing for the 1 left. RED.
- `ledger > belt stack follows bss and item stack size` — `bss = 2` -> pieces of 2; `stack_size` 1 for that item -> pieces of 1; `bss = 1` -> every item leaves one by one. RED.
- `ledger > order by first seen then name then quality` — copper seen at tick 10, iron at tick 20 (two `plan` calls), both full: copper pieces first. Same tick: name order; same name: quality order. Shuffled `contents` order gives same result. RED.
- `ledger > kind gone is forgotten` — kind absent in a later call leaves `state.seen[lane]`; when it comes back its clock restarts. Lanes have separate clocks. RED.
- `ledger > timer flushes leftover after its stacks` — `timeout_ticks = 60`, iron 5 first seen tick 0, call at tick 60: iron 4 then iron 1. At tick 59: only iron 4. `timeout_ticks = 0`: never. RED.
- `ledger > flush all sends every leftover` — `flush_all = true`: iron 2 + copper 3 -> both leftovers, order by first seen. RED.
- `ledger > full store flushes oldest only` — `slots_used = 12, slots = 12`, three kinds below N, none skip: only oldest kind leaves (one piece, its whole count); with any full stack present: no flush piece. RED.
- `ledger > skip kinds leave first whole` — `skip` true for coal: coal 6 -> coal 4, coal 2, before other kinds' full stacks. RED.
- `ledger > quality is separate kind` — iron normal 3 + iron rare 4: only rare leaves. RED.
- `ledger > plan never changes contents` — deep compare `contents` before / after. RED.
- `ledger > hoard lists kinds at one inventory stack` — iron 100 (stack 100), copper 99, gear 250 (stack 100): `{ gear, iron }` sorted by name then quality; 7 kinds over -> 5 with largest counts, then sorted. RED.
- `ledger > led states` — `(0, 0, 12)` green; `(3, 0, 12)` yellow; `(12, 1, 12)` red; `(0, 12, 12)` red. RED.
- `ledger > state is plain data` — after calls `state` holds only tables, strings, numbers (walk it). RED.

### Code — `scripts/ledger.lua`

Per seam table "scripts/ledger.lua" exactly.

### Mutation

Sort full stacks by name only (ignore first seen) -> `ledger > order by first seen then name then quality` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_ledger.lua::ledger > full stacks leave partial stays'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua tests/offline/test_ledger.lua`.

Keep-green list `tests/offline/fixtures/v15_keep_green.txt` (one `<file>::<name>` per line), run as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v15_keep_green.txt
```

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `control.lua`, `data.lua`, `scripts/names.lua`, `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fixtures/*`, anything under `tests/game/`, `tools/*`, `Makefile`. Never weaken a test to hide a defect. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v15..HEAD`.

## What done mean

```checks
{"name": "lane041-scope", "command": "git diff --name-only lanes-base-v15 HEAD | grep -Ev '^(scripts/ledger\\.lua|tests/offline/test_ledger\\.lua)$' | ( ! grep . ) && echo lane041-scope-ok", "expect_exit": 0, "expect_regex": "lane041-scope-ok", "timeout_s": 60}
{"name": "lane041-tests", "command": "( for t in 'full stacks leave partial stays' 'belt stack follows bss and item stack size' 'order by first seen then name then quality' 'kind gone is forgotten' 'timer flushes leftover after its stacks' 'flush all sends every leftover' 'full store flushes oldest only' 'skip kinds leave first whole' 'quality is separate kind' 'plan never changes contents' 'hoard lists kinds at one inventory stack' 'led states' 'state is plain data'; do tools/run_tests.sh 2.0 \"tests/offline/test_ledger.lua::ledger > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_ledger.lua ) && echo lane041-tests-ok", "expect_exit": 0, "expect_regex": "lane041-tests-ok", "timeout_s": 300}
{"name": "lane041-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v15_keep_green.txt ) && echo lane041-keep-green-ok", "expect_exit": 0, "expect_regex": "lane041-keep-green-ok", "timeout_s": 900}
```

## Files this lane owns

scripts/ledger.lua, tests/offline/test_ledger.lua (new). Never touch anything else.

Re-cut because: none

# bound: 2400s
