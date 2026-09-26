# 017 — names, menu row, Factoriopedia + tip simulation data, belt-group placer, migration (U-7, U-8, E-9)

Repo `sushi-packer-mod`, lane worktree `/home/dev_zaigraev_gmail_com/wt-sushi-packer-017_data`, branch `lane/017_data`, base tag `lanes-base-1.2`, merge target `int/v1.2`. Host `legalcopilot-dev`.

This task is complete in itself. Lanes 015, 016, 018 run in parallel on other files; you never need them.

## You have about 35 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** recipes, techs, weight, `next_upgrade` from v1.1 (existing tests in `tests/offline/test_data.lua` must stay green); graphics paths (they use tier keys `yellow..turbo`, unchanged); every file outside "Files this lane owns" byte-identical to `lanes-base-1.2`.

- Contract: `docs/REQUIREMENTS.md` v6 U-7, U-8, E-9; decisions E9, SIM (`docs/DECISIONS.md`); FND-0009 (`docs/FINDINGS.md`).
- `scripts/names.lua` (S1, frozen): `N.item("yellow") = "sushi-packer"`, red `"fast-sushi-packer"`, blue `"express-sushi-packer"`, turbo `"turbo-sushi-packer"`; `N.placer`, `N.variant`, `N.remnant`, `N.tech` derive from item; `N.old_item(tier)` = v1.1 name `"sushi-packer-<tier>"` (old placer `<old>-placer`, variants `<old>-<dir>`, remnants `<old>-remnants`, tech = old item). `N.SUBGROUP = "sushi-packer"`, `N.SIM_INTERFACE = "sushi-packer"`, `N.BELT_GROUP = "transport-belt"`, `N.TIPS`.
- `prototypes/packer.lua` today: item `subgroup = "belt"`, `order = "z[sushi-packer]-" .. tier` (sorts blue, red, turbo, yellow — wrong). Placer already has `fast_replaceable_group = "transport-belt"` from S1 probe (keep it, use `N.BELT_GROUP`); variants keep `N.FAST_REPLACE_GROUP`. No simulations.
- Vanilla facts (local 2.0.77 data): item-subgroups of group `logistics`: `storage` order `a`, `belt` order `b`, `inserter` order `c` (`base/prototypes/item-groups.lua`). Vanilla names: "Transport belt", "Fast transport belt", "Express transport belt", "Turbo transport belt".
- Simulation (https://lua-api.factorio.com/2.0.72/types/SimulationDefinition.html): fields `init` (string), `mods` (array of mod names whose control scripts load), `init_update_count`, `checkboard`. Put on item + north variant as `factoriopedia_simulation`, and on tips item as `simulation`: `{ mods = {"sushi-packer"}, init = "remote.call(\"sushi-packer\", \"scene\", \"factoriopedia\")" (tips: \"tips\"), init_update_count = 0, checkboard = true }` — build the string from `N.SIM_INTERFACE`.
- JSON migration format (https://lua-api.factorio.com/2.0.72/auxiliary/migrations.html): `{"entity": [["old","new"], ...], "item": [...], "recipe": [...], "technology": [...]}` in `migrations/<name>.json`, applied once per save.
- Offline fixture `tests/offline/fake_data.lua`: `F.reset()` then `dofile("prototypes/packer.lua")` / `dofile("prototypes/tips.lua")`; read `F.raw[...]`; `F.extended` lists everything added. Locale test helper `has(section, key)` in `tests/offline/test_locale.lua`. Lua 5.2 has no JSON lib: parse the migration file in the test with string patterns (`"%[\"([^\"]+)\",%s*\"([^\"]+)\"%]"`).
- Offline runner: `describe`, `it`, `eq(found, expected, msg)` deep compare, `ok(cond, msg)` (`tests/offline/run.lua`); full test name `<describe> > <it>`; missing name = exit 1.

## Explain very simply

Rename boxes like vanilla belts (Sushi packer, Fast…, Express…, Turbo…), give them their own neat row in the crafting menu, let old saves keep their boxes, and make encyclopedia + tip pages run a live mini-factory scene.

## What to build

1. `prototypes/packer.lua`: add `item-subgroup` `{type="item-subgroup", name=N.SUBGROUP, group="logistics", order="b-a"}` once; items `subgroup = N.SUBGROUP`, `order = "a[sushi-packer]-a"`..`-d` by tier index; placer `fast_replaceable_group = N.BELT_GROUP`; `factoriopedia_simulation` on item and north variant (per above).
2. `prototypes/tips.lua`: tips item gets `simulation` (kind `"tips"`), keep category + trigger.
3. `locale/en/locale.cfg`: rename every key to new names; display names "Sushi packer", "Fast sushi packer", "Express sushi packer", "Turbo sushi packer" (items, recipes, techs, placer, variants; remnants "… remnants"). Keep descriptions; update item/tech description to: collects items per lane until one kind fills a belt stack (up to 4 with research), then sends that stack forward. Tip description: same idea, 2-3 sentences.
4. `migrations/sushi-packer_0.1.2.json` and `migrations/sushi-packer_0.2.2.json` (identical): map every v1.1 name → new name: entity (placer, 4 variants, remnants), item, recipe, technology, per tier.

### Tests to write (exact names; each red against current code first)

`tests/offline/test_data.lua` (add): `data > own subgroup row after belts`, `data > order yellow red blue turbo`, `data > item names follow vanilla series`, `data > simulations call scene with mods`, `data > placer joins belt group variants do not`.
`tests/offline/test_locale.lua` (add `locale > vanilla style names`; `locale > every prototype has name and description` must pass with new names).
`tests/offline/test_migration.lua` (new): `migration > maps every old name to new` (all 4 tiers × placer, 4 variants, remnants, item, recipe, technology), `migration > both version files identical`.

## Test rule — read twice

**Lanes run offline Lua tests only (SP-02 v0.2).** Never start Factorio, never run `tests/game/*`, never `make test`, never `make zip`, never `--full`, never a file-wide or dir-wide run. `tools/run_tests.sh` refuses headless runs under `LANE_RUN_ID`. Run one test at a time, milliseconds each:

```
make test-one T='tests/offline/test_data.lua::data > order yellow red blue turbo'
```

Game API is faked with plain Lua tables inside your test file. Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/names.lua`, `control.lua`, `data.lua`, `settings.lua`, `info.json`, `Makefile`, `tools/*`, `.agent-lane.toml`, `.gateslot.conf`, any file not in "Files this lane owns". Never change a function signature. Never weaken, skip or delete an existing test unless this task names it. Never add dependencies.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane017-scope", "command": "git diff --name-only lanes-base-1.2 HEAD | grep -Ev '^(prototypes/packer\\.lua|prototypes/tips\\.lua|locale/en/locale\\.cfg|migrations/sushi-packer_0\\.1\\.2\\.json|migrations/sushi-packer_0\\.2\\.2\\.json|tests/offline/test_data\\.lua|tests/offline/test_locale\\.lua|tests/offline/test_migration\\.lua)$' | ( ! grep . ) && echo lane017-scope-ok", "expect_exit": 0, "expect_regex": "lane017-scope-ok", "timeout_s": 60}
{"name": "lane017-tests", "command": "( tools/run_tests.sh 2.0 'tests/offline/test_data.lua::data > own subgroup row after belts' && tools/run_tests.sh 2.0 'tests/offline/test_data.lua::data > order yellow red blue turbo' && tools/run_tests.sh 2.0 'tests/offline/test_data.lua::data > item names follow vanilla series' && tools/run_tests.sh 2.0 'tests/offline/test_data.lua::data > simulations call scene with mods' && tools/run_tests.sh 2.0 'tests/offline/test_data.lua::data > placer joins belt group variants do not' && tools/run_tests.sh 2.0 'tests/offline/test_locale.lua::locale > vanilla style names' && tools/run_tests.sh 2.0 'tests/offline/test_locale.lua::locale > every prototype has name and description' && tools/run_tests.sh 2.0 'tests/offline/test_migration.lua::migration > maps every old name to new' && tools/run_tests.sh 2.0 'tests/offline/test_migration.lua::migration > both version files identical' && tools/run_tests.sh 2.0 'tests/offline/test_data.lua::data > yellow recipe matches table' && tools/run_tests.sh 2.0 'tests/offline/test_data.lua::data > chained tiers use previous box' && tools/run_tests.sh 2.0 'tests/offline/test_data.lua::data > tech prereqs include ingredient unlock techs' && tools/run_tests.sh 2.0 'tests/offline/test_data.lua::data > next_upgrade chain keeps direction' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane017-tests-ok", "expect_exit": 0, "expect_regex": "lane017-tests-ok", "timeout_s": 300}
```

## Files this lane owns

prototypes/packer.lua, prototypes/tips.lua, locale/en/locale.cfg, migrations/sushi-packer_0.1.2.json, migrations/sushi-packer_0.2.2.json, tests/offline/test_data.lua, tests/offline/test_locale.lua, tests/offline/test_migration.lua. Never touch anything else.

Re-cut because: none

# bound: 2100s
