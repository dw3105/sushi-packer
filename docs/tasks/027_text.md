# 027 — text: locale, README, portal page, changelog for modded belt tiers

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-027_text`, branch `lane/027_text`, base tag `lanes-base-v9`, merge target `int/v9`. Host `dev-vm`.

This task is complete in itself. Lane 024 (data stage: `prototypes/extra.lua`, `prototypes/packer.lua`, `data-final-fixes.lua`, `info.json`) and lane 025 (rate: `scripts/belt_io.lua`, `scripts/tick.lua`) run in parallel; you never need their code and never touch their files. After merge, fact: each modded tier's prototypes are named with `scripts/names.lua` helpers (`N.item(key)`, `N.placer(key)`, `N.variant(key, dir)`, `N.remnant(key)`, `N.tech(key)`), recipe name = `N.item(key)`, exactly like vanilla tiers.

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v9`; every existing line of `locale/en/locale.cfg` unchanged (only add lines).

- Requirements v9 §17 (`docs/REQUIREMENTS.md`, author 2026-09-28): M-1 extra tier per supported modded belt, exists only when its mod is installed; M-5 recipe = previous tier box 1, own belt splitter 1, `stack-inserter` 2, `quantum-processor` 2, 120 s, own tech after its belt tech; M-4 upgrade chain turbo → modded tiers by belt speed; M-6 speed = real belt speed, follows mod settings; M-8 names mirror belt names.
- `scripts/names.lua` (frozen): `N.EXTRA` = rows `{key, belt, splitter, tech, mod, fv, ...}`. Keys and display names you must use:

| key | display name | mod (`row.mod`) | belt speed | builds |
|---|---|---|---|---|
| `planetaris-hyper` | Hyper sushi packer | Planetaris: Arig | 75/s | 2.0 + 2.1 |
| `bob-ultimate` | Ultimate sushi packer | Bob's Logistics | 75/s | 2.0 + 2.1 |
| `kr-superior` | Superior sushi packer | Krastorio 2 | 90/s | 2.0 + 2.1 |
| `ub-ultra-fast` | Ultra fast sushi packer | Ultimate Belts Space Age | 90/s | 2.0 |
| `bb-ultra` | Ultra sushi packer | Better Belts | 96/s | 2.0 |
| `ub-extreme-fast` | Extreme fast sushi packer | Ultimate Belts Space Age | 135/s | 2.0 |
| `ub-ultra-express` | Ultra express sushi packer | Ultimate Belts Space Age | 180/s | 2.0 |
| `ub-extreme-express` | Extreme express sushi packer | Ultimate Belts Space Age | 225/s | 2.0 |
| `ub-ultimate` | Ultimate sushi packer | Ultimate Belts Space Age | 270/s | 2.0 |

- Hyarion note (true, say it on portal/README): Planetaris Hyarion has no belt of its own; hyper belt comes from Planetaris: Arig; with Hyarion installed the hyper belt tech moves into Hyarion's progression and the packer tier follows it.
- `locale/en/locale.cfg`: sections `[item-name]`, `[entity-name]`, `[technology-name]`, `[item-description]`, `[entity-description]`, `[technology-description]`, `[recipe-name]`, `[recipe-description]`. Turbo lines are the pattern (e.g. `turbo-sushi-packer-placer=Turbo sushi packer`, `turbo-sushi-packer-remnants=Turbo sushi packer remnants`, recipe description `Assemble a turbo sushi packer.`). Existing test `locale > every prototype has name and description` requires phrases `collects items per lane until one kind fills a belt stack` and `size set by belt stacking research, modded or not` somewhere, and forbids `up to 4`.
- `changelog.txt`: blocks separated by a line of 99 `-`; 0.2.x blocks first (newest top), then 0.1.x blocks. Format `Version: 0.2.8` / `Date: 2026-09-28` / `  Changes:` / `    - text`. 2.0 build = 0.1.x, 2.1 build = 0.2.x.
- `README.md` has a tier table near line 16; `portal/description.md` has `## Tiers` table.
- Offline runner: `describe`, `it`, `eq`, `ok` (`tests/offline/run.lua`); file helpers pattern at top of `tests/offline/test_locale.lua` (`read`, `has`, `value` — copy them).

## Explain very simply

New box tiers need names and descriptions in game, and pages must tell players which belt mods are supported.

## What to build

1. `locale/en/locale.cfg`: for every `N.EXTRA` row, add in each section the same keys vanilla turbo has (item, placer, 4 directions, remnants, tech, recipe; names + descriptions). Name = display name above; remnants = name + ` remnants`. Item + tech description = vanilla turbo text + ` Matches the <belt display> belt from <row.mod>.` (belt display: Hyper, Ultimate, Superior, Ultra fast, Ultra, Extreme fast, Ultra express, Extreme express, Ultimate). Entity descriptions = turbo text. Recipe description `Assemble a <lowercase display name>.`
2. `README.md` + `portal/description.md`: new section `## Modded belt tiers` after tier table: one sentence that tiers appear only when the belt mod is installed; table columns `Tier | Belt mod | Speed | Builds` with all 9 rows; recipe sentence per M-5; upgrade chain sentence per M-4; speed sentence per M-6; Hyarion note.
3. `changelog.txt`: new block `Version: 0.2.9` at very top and `Version: 0.1.9` directly above the `Version: 0.1.8` block, both `Date: 2026-09-28`, `  Changes:` lines: modded belt tiers (list mods), box speed follows real belt speed (mod settings too).

### Tests to write — new file `tests/offline/test_locale_extra.lua`, `describe("locale extra", ...)`; each red against `lanes-base-v9` first

- `locale extra > every extra tier has names and descriptions` — for each `N.EXTRA` row: item, tech, placer, 4 variants, remnant, recipe have name + description.
- `locale extra > names mirror belt names` — item-name per key = table above; placer + variants = same; remnant = name .. " remnants".
- `locale extra > descriptions name source mod` — item-description of each row contains `row.mod`.
- `locale extra > readme and portal list every supported mod` — `README.md` and `portal/description.md` each contain `## Modded belt tiers` and every distinct `row.mod` and `Hyarion`.
- `locale extra > changelog has 0.2.9 and 0.1.9` — both blocks, 99-dash separator, `Date: 2026-09-28`.

Every existing test stays green unchanged.

## Test rule — read twice

**Lanes run offline Lua tests only.** Never start Factorio, never run `tests/game/*`, never `make test`, never `make test-modsets`, never `make zip`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_locale_extra.lua::locale extra > names mirror belt names'
```

Write each new test first and see it fail before writing text.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, any existing `tests/offline/test_*.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/*`, `prototypes/*`, `control.lua`, `data.lua`, `data-final-fixes.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, any file not in "Files this lane owns". Never weaken, skip or delete an existing test. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane027-scope", "command": "git diff --name-only lanes-base-v9 HEAD | grep -Ev '^(locale/en/locale\\.cfg|README\\.md|portal/description\\.md|changelog\\.txt|tests/offline/test_locale_extra\\.lua)$' | ( ! grep . ) && echo lane027-scope-ok", "expect_exit": 0, "expect_regex": "lane027-scope-ok", "timeout_s": 60}
{"name": "lane027-tests", "command": "( for t in 'tests/offline/test_locale_extra.lua::locale extra > every extra tier has names and descriptions' 'tests/offline/test_locale_extra.lua::locale extra > names mirror belt names' 'tests/offline/test_locale_extra.lua::locale extra > descriptions name source mod' 'tests/offline/test_locale_extra.lua::locale extra > readme and portal list every supported mod' 'tests/offline/test_locale_extra.lua::locale extra > changelog has 0.2.9 and 0.1.9' 'tests/offline/test_locale.lua::locale > vanilla style names' 'tests/offline/test_locale.lua::locale > every prototype has name and description' 'tests/offline/test_stage.lua::stage > changelog format valid' 'tests/offline/test_guard.lua::guard > names frozen'; do tools/run_tests.sh 2.0 \"$t\" || exit 1; done ) && echo lane027-tests-ok", "expect_exit": 0, "expect_regex": "lane027-tests-ok", "timeout_s": 300}
```

## Files this lane owns

locale/en/locale.cfg (add lines only), README.md, portal/description.md, changelog.txt, tests/offline/test_locale_extra.lua. Never touch anything else.

Re-cut because: none

# bound: 1800s
