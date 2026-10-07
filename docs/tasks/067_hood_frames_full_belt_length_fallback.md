# 067 — hood frames: hood layer as long as whole belt picture, else no hood layer

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-067_hood_frames_full_belt_length_fallback`, branch `lane/067_hood_frames_full_belt_length_fallback`, base tag `lanes-base-v25`, merge target `int/v25`. Host `dev-vm`.

Only lane this round. Integrator runs headless hunt beside you in scratch dirs; no shared file.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v25`. In `prototypes/tier.lua` only body of `function M._hood_layer` changes (any helper goes nested inside it as `local function`). In `tests/offline/test_data.lua` only: fixture of test `hood layer repeat count equals belt frames` (see below) and new `describe("data v25")` block at file end; every other test byte-identical.

- `M._hood_layer(tier, set)` (`prototypes/tier.lua:85-122`) builds one extra layer (our hood picture) that `M.make` appends to body's `belt_animation_set.animation_set` layers (`prototypes/tier.lua:206-214`). Return `nil` = no hood layer, belt picture kept as is (already used for odd shapes, test `odd belt picture keeps belt picture`).
- Hood layer = `frame_count = 1`, `repeat_count = <belt length>`. Factorio refuses load when layers of one animation differ in length. Layer length in game = `frame_count` (default 1) x `repeat_count` (default 1).
- Defect (FND-0059): line 111 takes `base.frame_count or first.frame_count` only, ignores `repeat_count`. Black Rubber Belts (`black-rubber-belts-remastered` 2.3.10) builds belt layers `frame_count = 8, repeat_count = 2` (also 4, 8) plus arrow layer `frame_count = 16` (or 32, 64). Our hood gets 8 -> game load error `Different frame counts (expected 16, but has 8)` (reproduced headless 2026-10-07).
- Real Black Rubber shape (default settings): `animation_set = { layers = { { filename = "rubber-belt-base-....png", frame_count = 8, repeat_count = 2, direction_count = 20 }, { filename = "rubber-belt-arrows.png", frame_count = 16, direction_count = 20 } } }`. Rails "colored" adds third layer `frame_count = 8, repeat_count = 2`. Arrow style "no-arrows" + vanilla rails: one layer, set has no `layers` key: `{ frame_count = 8, repeat_count = 2, direction_count = 20 }`.
- Lua 5.2, Factorio data stage, 2.0 and 2.1. Runner: `describe`, `it`, `eq`, `ok`. Test file has `picture_set()` helper (inside `data v20`) and file-level `load()`.

## Explain very simply

Belt picture is flip-book. Some belt mods use 8 pages shown twice instead of 16 pages. We counted only 8 and game refused to start. Fix: count pages x times shown, on every layer. If layers don't agree, or something looks strange, skip our hood in belt picture — game always starts.

## What to build

### Rule — `M._hood_layer` length (decision V25-1)
- Belt layers = `base.layers` when present, else `{ base }`. Empty `layers` table -> `nil`.
- Each layer length = `(layer.frame_count or 1) * (layer.repeat_count or 1)`.
- Layer that has `frame_sequence` -> `nil` (other length rule, we don't guess).
- Length not whole number >= 1 -> `nil`.
- Lengths differ between layers -> `nil`.
- All same -> hood `repeat_count = length`, `frame_count = 1` (unchanged).
- Direction check stays as today (`base.direction_count or first.direction_count` must be 20); rows / caps / filenames logic unchanged.

### Test first; seen RED before code
In `tests/offline/test_data.lua`:
- Test `data v20 > hood layer repeat count equals belt frames`: keep every assert; only change: second layer `{ filename = "other.png" }` becomes `{ filename = "other.png", frame_count = 16 }` in all 3 places it appears (old fixture had length 1 beside 16; game refuses that shape). Green before and after code.
- New block `describe("data v25", function() local tier_builder = require("prototypes.tier") ... end)` at file end with:
  - `hood length counts repeat on every layer` — Black Rubber default shape above: `repeat_count == 16`. Arrow-quadrupled (`8 x 8` + `64`): `64`. Rails colored (`8 x 2`, `16`, `8 x 2`): `16`. Single set no `layers` key `{ frame_count = 8, repeat_count = 4, direction_count = 20 }`: `32`. RED at base.
  - `hood left out when belt layers disagree` — layers `8 x 2` and `frame_count = 81`: `nil`; layer with `frame_sequence = { 1, 2, 3 }`: `nil`; `layers = {}` with `direction_count = 20`: `nil`; `frame_count = 0`: `nil`. RED at base (first case).
  - `body keeps belt picture when hood left out` — source yellow belt (`load()`, `raw["transport-belt"][N.TIER.yellow.belt]`) gets `belt_animation_set = { animation_set = { layers = { { filename = "a.png", frame_count = 8, repeat_count = 2 }, { filename = "b.png", frame_count = 81 } }, direction_count = 20 } }`; deep copy taken before `tier_builder.make("yellow", { index = 1 })`; body proto `belt_animation_set.animation_set` equals copy. RED at base.

### Mutations
1. Length from first layer only (no compare) -> `hood left out when belt layers disagree` red. Restore -> green.
2. Ignore `repeat_count` -> `hood length counts repeat on every layer` red. Restore -> green.
Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite — never `make test`, `make test-modsets`, `make load-check`, `make bench`, `make zip`, `make dump-data`, `--full`, dir-wide runs. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_data.lua::data v25 > hood length counts repeat on every layer'
```

Whole-file run allowed only for `tests/offline/test_data.lua`. Keep-green `tests/offline/fixtures/v25_keep_green.txt` (494, green at base) as single tests:

```
while IFS= read -r t; do tools/run_tests.sh 2.0 "$t" >/dev/null 2>&1 || echo "RED $t"; done < tests/offline/fixtures/v25_keep_green.txt
```

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `scripts/*`, other `prototypes/*`, other test files, `tests/offline/fixtures/*`, `tools/*`, `Makefile`, `graphics/*`. Never weaken a test.

## Commit, THEN check
Test commit (red) first, then code commit. Checks very LAST.

## Final report
Red output at base, green after, each mutation red + restore green, `git log --oneline lanes-base-v25..HEAD`.

## What done mean

```checks
{"name": "lane067-scope", "command": "git diff --name-only lanes-base-v25 HEAD | grep -Ev '^(prototypes/tier\\.lua|tests/offline/test_data\\.lua)$' | ( ! grep . ) && [ \"$(git show lanes-base-v25:prototypes/tier.lua | sed '/^function M._hood_layer/,/^end/d')\" = \"$(sed '/^function M._hood_layer/,/^end/d' prototypes/tier.lua)\" ] && [ \"$(git show lanes-base-v25:tests/offline/test_data.lua | sed '/hood layer repeat count equals belt frames/,/^  end)/d')\" = \"$(sed '/hood layer repeat count equals belt frames/,/^  end)/d; /^describe(\\\"data v25\\\"/,$d' tests/offline/test_data.lua)\" ] && echo lane067-scope-ok", "expect_exit": 0, "expect_regex": "lane067-scope-ok", "timeout_s": 60, "red_at_base": false}
{"name": "lane067-tests", "command": "( for t in 'data v25 > hood length counts repeat on every layer' 'data v25 > hood left out when belt layers disagree' 'data v25 > body keeps belt picture when hood left out' 'data v20 > hood layer repeat count equals belt frames'; do tools/run_tests.sh 2.0 \"tests/offline/test_data.lua::$t\" || exit 1; done; out=$(lua5.2 tests/offline/run.lua tests/offline/test_data.lua) || exit 1; n=$(printf '%s\\n' \"$out\" | sed -n 's/^offline .*: \\([0-9]*\\) ran, 0 failed$/\\1/p'); [ \"${n:-0}\" -ge 37 ] || { echo \"count=$n\"; exit 1; } ) && echo lane067-tests-ok", "expect_exit": 0, "expect_regex": "lane067-tests-ok", "timeout_s": 300}
{"name": "lane067-keep-green", "command": "( n=0; while IFS= read -r t; do n=$((n+1)); tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v25_keep_green.txt; [ $n -ge 494 ] || { echo \"count=$n\"; exit 1; } ) && echo lane067-keep-green-ok", "expect_exit": 0, "expect_regex": "lane067-keep-green-ok", "timeout_s": 600, "red_at_base": false}
```

Owner base colours (`lanes-base-v25`, scratch `HOME`, 2026-10-07): lane067-scope GREEN, lane067-tests RED (test not found), lane067-keep-green GREEN.

## Files this lane owns

- `prototypes/tier.lua` (body of `M._hood_layer` only)
- `tests/offline/test_data.lua` (fixture of `hood layer repeat count equals belt frames` + new `describe("data v25")` block at end)

Never touch anything else.

Re-cut because: none

# bound: 1800s

Reviewer ask: does hood length equal frame_count x repeat_count agreed on every belt layer, nil on any disagreement / frame_sequence / bad number, and does nothing outside `_hood_layer` and the named tests change?
