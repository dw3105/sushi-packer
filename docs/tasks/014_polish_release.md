# 014 — polish: locale descriptions, tips, thumbnail, changelog, README, release zip (U-5, U-6)

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-014_polish_release`, branch `lane/014_polish_release`, base tag `lanes-base-1.1`, merge target `int/v1.1`. Host `dev-vm`.

This task is complete in itself. Lanes 012 and 013 run in parallel on other files; you never need them.

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every existing locale key and value in `locale/en/locale.cfg` and `locale/en/gui.cfg`; every file outside "Files this lane owns" byte-identical to `lanes-base-1.1`. Never copy any file from the base game (`~/factorio-*/`). Never redraw graphics: thumbnail is built only from `graphics/` PNGs already in repo.

- Contract: `docs/REQUIREMENTS.md` §10 U-5, U-6 (v5, author 2026-09-26); decision POL: versions 0.1.1 (2.0 build) and 0.2.1 (2.1 build).
- Names: `scripts/names.lua` (`N.TIERS`, `N.DIRS`, `N.item`, `N.placer`, `N.variant`, `N.remnant`, `N.tech`, `N.SETTING_TIMEOUT`, `N.INPUT_ROTATE`, `N.INPUT_REVERSE_ROTATE`, `N.TIPS = "sushi-packer-tips"`). Recipe name = `N.item(tier)`.
- `locale/en/locale.cfg` today: names only (`[item-name]`, `[entity-name]`, `[technology-name]`, `[mod-setting-name]`, `[controls]`). No descriptions, no `[recipe-name]`, no `[mod-name]`.
- `data.lua` already has `require("prototypes.tips")`; `prototypes/tips.lua` is a stub. Tips prototypes in 2.0/2.1: `{ type = "tips-and-tricks-item-category", name, order }` and `{ type = "tips-and-tricks-item", name, category, order, is_title?, trigger = { type = "research", technology = <name> } }`; locale sections `[tips-and-tricks-item-name]`, `[tips-and-tricks-item-description]`, `[tips-and-tricks-item-category-name]`. Offline fixture `tests/offline/fake_data.lua` (`F.reset()` installs global `data`; then `dofile("prototypes/tips.lua")`; read `F.raw["tips-and-tricks-item"]`).
- `tools/stage.sh:10-11` versions `0.1.0`/`0.2.0`; `tools/load_check.sh:9` same; `info.json:3` `"version": "0.1.0"`; `info.json:8` deps include `"? factorio-test"` and stage.sh copies it into release (bug). stage.sh already copies `changelog.txt` and `thumbnail.png` when present (`:20`). `STAGE_DIR=<dir> tools/stage.sh <2.0|2.1> release` stages to `<dir>/mods/sushi-packer_<ver>/` and prints that path (it checks Factorio binary exists, never starts it).
- No PIL on `dev-vm`: `tools/thumb.py` uses only `zlib` + `struct` (decode 8-bit RGBA non-interlaced PNG incl. filter types 0-4, write RGBA PNG). Source sprites `graphics/entity/sushi-packer/<tier>/sushi-packer-<tier>-north.png` are 128×128 RGBA.
- Factorio changelog format: each block starts with a line of exactly 99 `-`, then `Version: x.y.z`, `Date: YYYY-MM-DD`, category lines indented 2 spaces ending `:` (e.g. `  Features:`), entries indented 4 spaces starting `- `.
- Offline runner: `describe`, `it`, `eq(found, expected, msg)`, `ok(cond, msg)` (`tests/offline/run.lua`); lua5.2 has `io.open`, `io.popen`, `string.byte`.

## Explain very simply

Make mod look finished on portal and in game: every name has description, one tip, picture, changelog, readme. Release zip must not ask for test mod.

## What to build

1. `locale/en/locale.cfg`: add `[item-description]` per item, `[entity-description]` per placer + 4 variants + remnant, `[technology-description]` per tech, `[recipe-name]` + `[recipe-description]` per recipe, `[mod-setting-description]` for `N.SETTING_TIMEOUT`, `[mod-name]` + `[mod-description]` for `sushi-packer`, tips name + description + category name. Plain English, one or two sentences; tech/item description says: sorts mixed belt items per lane into full stacks, output stacked when belt capacity research done.
2. `prototypes/tips.lua`: category `sushi-packer` + item `N.TIPS`, trigger research `N.tech("yellow")`.
3. `tools/thumb.py`: 144×144 RGBA PNG `thumbnail.png`: 2×2 grid of four tier north sprites (yellow, red / blue, turbo), each area-averaged 128→72. Commit generated `thumbnail.png`.
4. `changelog.txt`: blocks 0.2.1, 0.2.0, 0.1.1, 0.1.0 (newest first), date 2026-09-26. 0.x.1: chained recipes, tech rule, upgrade planner, descriptions, tips, weight, thumbnail. 0.x.0: first release.
5. `README.md`: what box does, tiers + recipe table (`docs/REQUIREMENTS.md` U-2), unlock rule, settings, 2.0 vs 2.1 builds, space-age required.
6. `tools/stage.sh`: versions `0.1.1`/`0.2.1`; in `release` mode drop every dependency containing `factorio-test` from staged `info.json`. `tools/load_check.sh`: versions `0.1.1`/`0.2.1`. `info.json`: `"version": "0.1.1"`.

### Tests to write (exact names; each red against current code first)

`tests/offline/test_locale.lua` (new), `describe("locale", ...)`:
- `locale > every prototype has name and description`
- `locale > recipes and setting described`
- `locale > tips entry has locale and prototype`
- `locale > mod name and description`

`tests/offline/test_stage.lua` (new), `describe("stage", ...)`:
- `stage > release info has no test dependency`
- `stage > versions are 0.1.1 and 0.2.1`
- `stage > release ships thumbnail and changelog`
- `stage > thumbnail is 144 by 144 png`
- `stage > changelog format valid`

## Test rule — read twice

**Lanes run offline Lua tests only (SP-02 v0.2).** Never start Factorio, never run `tests/game/*`, never `make test`, never `make zip`, never `make load-check`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time:

```
make test-one T='tests/offline/test_locale.lua::locale > every prototype has name and description'
```

Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/*`, `prototypes/packer.lua`, `control.lua`, `data.lua`, `settings.lua`, `Makefile`, `tools/run_tests.sh`, `tools/make_zip.sh`, `tools/bench/*`, `locale/en/gui.cfg`, `graphics/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never weaken or skip a test. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane014-scope", "command": "git diff --name-only lanes-base-1.1 HEAD | grep -Ev '^(locale/en/locale\\.cfg|prototypes/tips\\.lua|tools/thumb\\.py|thumbnail\\.png|changelog\\.txt|README\\.md|tools/stage\\.sh|tools/load_check\\.sh|info\\.json|tests/offline/test_locale\\.lua|tests/offline/test_stage\\.lua)$' | ( ! grep . ) && echo lane014-scope-ok", "expect_exit": 0, "expect_regex": "lane014-scope-ok", "timeout_s": 60}
{"name": "lane014-tests", "command": "( for t in 'every prototype has name and description' 'recipes and setting described' 'tips entry has locale and prototype' 'mod name and description'; do tools/run_tests.sh 2.0 \"tests/offline/test_locale.lua::locale > $t\" || exit 1; done && for t in 'release info has no test dependency' 'versions are 0.1.1 and 0.2.1' 'release ships thumbnail and changelog' 'thumbnail is 144 by 144 png' 'changelog format valid'; do tools/run_tests.sh 2.0 \"tests/offline/test_stage.lua::stage > $t\" || exit 1; done && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane014-tests-ok", "expect_exit": 0, "expect_regex": "lane014-tests-ok", "timeout_s": 300}
```

## Files this lane owns

locale/en/locale.cfg, prototypes/tips.lua, tools/thumb.py, thumbnail.png, changelog.txt, README.md, tools/stage.sh, tools/load_check.sh, info.json, tests/offline/test_locale.lua, tests/offline/test_stage.lua. Never touch anything else.

Re-cut because: none

# bound: 1800s
