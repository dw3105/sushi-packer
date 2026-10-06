# 066 — relink nil: `tier.relink` leaves tech alone when its recipe is gone

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-066_relink_nil`, branch `lane/066_relink_nil`, base tag `lanes-base-retro`, merge target `retro/v24`. Host `dev-vm`.

Lane 065 dumptool runs beside you; it owns only `tools/*`, `Makefile`, `tests/tools/*`. No shared file.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-retro`. In `prototypes/tier.lua` only `function M.relink` changes. Existing 6 tests in `tests/offline/test_data_v24.lua` unchanged.

- `M.relink(raw)` (`prototypes/tier.lua:289-301`): walks `N.TIERS`; for each tier whose `raw.technology[N.tech(tier)]` exists with `unit`, reads `local recipe = raw.recipe[N.item(tier)]` and calls `tech_requirements(raw, tier, previous_tier, recipe.ingredients, false)`; sets `previous_tier = tier`.
- Defect: when another mod deleted our recipe (`raw.recipe[N.item(tier)] == nil`), `recipe.ingredients` raises `attempt to index local 'recipe' (a nil value)` and the game refuses to load.
- Test file `tests/offline/test_data_v24.lua` (`describe("data v24")`): setup `F.reset()`, `dofile("prototypes/packer.lua")`, `local tier = require("prototypes.tier")`; has a deep-copy helper already.
- Lua 5.2, Factorio data stage, 2.0 and 2.1. Runner: `describe`, `it`, `eq`, `ok`.

## Explain very simply

If some mod removes our packer recipe, our late tech scan crashes game load. Fix: no recipe → leave that tech as it is and keep walking.

## What to build

### Rule — `M.relink`
- Tier with tech + `unit` but `raw.recipe[N.item(tier)] == nil`: tech untouched (`prerequisites`, `unit` same tables, same values); `previous_tier = tier` still set (next tier still names it as previous).

### Test first; seen RED before code
Add to `tests/offline/test_data_v24.lua` inside `describe("data v24")`:
- `data v24 > relink keeps tech when recipe gone` — `F.raw.recipe["fast-sushi-packer"] = nil`, deep copy of `F.raw.technology["fast-sushi-packer"]`, `tier.relink(F.raw)` inside `pcall`: pcall returns true; `fast-sushi-packer` `prerequisites` and `unit` equal copy; `express-sushi-packer` prerequisites == `{ "logistics-3", "fast-sushi-packer", "bulk-inserter", "processing-unit" }`. RED at base (pcall false).

### Mutation
Guard returns from whole `relink` at first missing recipe (instead of skipping one tier) -> new test red (express not relinked is invisible, so also assert: after `F.raw.technology["processing-unit"].effects` loses `processing-unit` unlock and tech `pu2` with `effects = { { type = "unlock-recipe", recipe = "processing-unit" } }`, `unit = { count = 1, time = 1, ingredients = { { "automation-science-pack", 1 } } }`, `prerequisites = {}` is added before relink, express prerequisites == `{ "logistics-3", "fast-sushi-packer", "bulk-inserter", "pu2" }`). Use this moved-unlock form in the test; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite — never `make test`, `make test-modsets`, `make load-check`, `make bench`, `make zip`, `--full`, dir-wide runs. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_data_v24.lua::data v24 > relink keeps tech when recipe gone'
```

Whole-file run allowed only for `tests/offline/test_data_v24.lua`. Keep-green `tests/offline/fixtures/v24_keep_green.txt` (91, green at base) as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v24_keep_green.txt
```

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `scripts/*`, other `prototypes/*`, `data-final-fixes.lua`, any other test file, `tests/offline/fixtures/*`, `tools/*`, `Makefile`. Never weaken a test.

## Commit, THEN check
Test commit (red) first, then code commit. Checks very LAST.

## Final report
Red output at base, green after, mutation red + restore green, `git log --oneline lanes-base-retro..HEAD`.

## What done mean

```checks
{"name": "lane066-scope", "command": "git diff --name-only lanes-base-retro HEAD | grep -Ev '^(prototypes/tier\\.lua|tests/offline/test_data_v24\\.lua)$' | ( ! grep . ) && [ \"$(git show lanes-base-retro:prototypes/tier.lua | sed '/^function M.relink/,/^end/d')\" = \"$(sed '/^function M.relink/,/^end/d' prototypes/tier.lua)\" ] && echo lane066-scope-ok", "expect_exit": 0, "expect_regex": "lane066-scope-ok", "timeout_s": 60}
{"name": "lane066-tests", "command": "( tools/run_tests.sh 2.0 'tests/offline/test_data_v24.lua::data v24 > relink keeps tech when recipe gone' || exit 1; out=$(lua5.2 tests/offline/run.lua tests/offline/test_data_v24.lua) || exit 1; n=$(printf '%s\\n' \"$out\" | sed -n 's/^offline .*: \\([0-9]*\\) ran, 0 failed$/\\1/p'); [ \"${n:-0}\" -ge 7 ] || { echo \"count=$n\"; exit 1; } ) && echo lane066-tests-ok", "expect_exit": 0, "expect_regex": "lane066-tests-ok", "timeout_s": 300}
{"name": "lane066-keep-green", "command": "( n=0; while IFS= read -r t; do n=$((n+1)); tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v24_keep_green.txt; [ $n -ge 91 ] || { echo \"count=$n\"; exit 1; } ) && echo lane066-keep-green-ok", "expect_exit": 0, "expect_regex": "lane066-keep-green-ok", "timeout_s": 600}
```

Owner base colours (`lanes-base-retro`, scratch `HOME`, 2026-10-06): lane066-scope GREEN, lane066-tests RED (test not found), lane066-keep-green GREEN.

## Files this lane owns

prototypes/tier.lua (`M.relink` only), tests/offline/test_data_v24.lua. Never touch anything else.

Re-cut because: none

# bound: 1500s

Reviewer ask: does a missing recipe skip only that tier (tech untouched, still previous for next tier) and touch only `M.relink` plus the test file?
