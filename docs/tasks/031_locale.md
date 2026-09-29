# 031 — locale: SE space tier text, German locale

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-031_locale`, branch `lane/031_locale`, base tag `lanes-base-v11`, merge target `int/v11`. Host `dev-vm`.

This task is complete in itself. Lane 030 (data: `prototypes/extra.lua`, `prototypes/tier.lua`, `tests/offline/test_data_extra.lua`) runs in parallel; you never need its code and never touch its files. After merge, facts: SE game has chains yellow → red → blue and space → deep space; space box recipe = 1 steel chest, 1 space splitter, 4 bulk inserters, 10 processing units, 60 s; deep space box needs the space box. You add no prototype code.

## You have about 60 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v11`; every existing `en` line keeps its key and text, except the lines this task names.

- Requirements v11 (author 2026-09-29, `docs/REQUIREMENTS.md` U-5, M-8; `docs/DECISIONS.md` V11-1, V11-5):
  - New tier row `se-space` in `N.EXTRA` (`scripts/names.lua`, frozen, at base): en name "Space sushi packer", mod "Space Exploration", belt "Space transport belt". Needs every locale key the other extra rows have (item-name, entity-name for placer + 4 dirs + remnants, technology-name, recipe-name, item-description, entity-description, technology-description, recipe-description), same text pattern as `se-deep-space` lines ("Matches the Space belt from Space Exploration." style — copy the `se-deep-space` line shape). Existing test `locale extra > every extra tier has names and descriptions` iterates `N.EXTRA` and is red at base for `se-space`; it turns green by your lines.
  - U-5: locales `en` + `de`, SAME key set per file (`locale/de/locale.cfg` ↔ `locale/en/locale.cfg`, `locale/de/gui.cfg` ↔ `locale/en/gui.cfg`), same sections, no empty value. In-game text only.
  - German terms (V11-5): vanilla terms from Factorio's own German locale on this host, read-only: `~/factorio-2.0/factorio/data/base/locale/de/base.cfg`, `~/factorio-2.0/factorio/data/space-age/locale/de/*.cfg`, `~/factorio-2.0/factorio/data/quality/locale/de/*.cfg` (e.g. `Fließband`, `Teilerfließband`, `Greifarm`, `Massengreifarm`, `Stapelgreifarm`, `Stahlkiste`, `Mikroprozessor`, `Qualität`, `Schaltkreisnetzwerk` — look each one up there, never guess). Mod terms from the mods' own German locale inside the zips in `~/.cache/sushi-packer-mods/2.0/` (read with `unzip -p <zip> '*/locale/de/*'`). Never copy a whole file; take words only.
  - Box noun: **Sushi-Packer** (masculine, "der Sushi-Packer"). Mod title stays "Sushi Packer".
  - Tier names (item-name, entity-name, technology-name, recipe-name) — use exactly:

| key | German name | rule |
|---|---|---|
| sushi-packer | Sushi-Packer | vanilla `Fließband` |
| fast-sushi-packer | Schneller Sushi-Packer | vanilla `Schnelles Fließband` |
| express-sushi-packer | Express-Sushi-Packer | vanilla `Express-Fließband` |
| turbo-sushi-packer | Turbo-Sushi-Packer | vanilla `Turbo-Fließband` |
| se-space-sushi-packer | Space-Sushi-Packer | SE de `Space-Fließband` |
| se-deep-space-sushi-packer | Deep-Space-Sushi-Packer | SE de `Deep-Space-Fließband` |
| kr-superior-sushi-packer | Überlegener Sushi-Packer | K2 de `Überlegenes Fließband` |
| bob-ultimate-sushi-packer | Ultimativer Sushi-Packer | Bob de `prefix-green=Ultimativ` |
| bb-ultra-sushi-packer | Hochgeschwindigkeit Sushi-Packer | Better Belts de `Hochgeschwindigkeit Fließband` |
| planetaris-hyper-sushi-packer | Hyper-Sushi-Packer | Arig: no de → English word + hyphen |
| ub-ultra-fast-sushi-packer | Ultra-Fast-Sushi-Packer | UBSA: no de |
| ub-extreme-fast-sushi-packer | Extreme-Fast-Sushi-Packer | UBSA: no de |
| ub-ultra-express-sushi-packer | Ultra-Express-Sushi-Packer | UBSA: no de |
| ub-extreme-express-sushi-packer | Extreme-Express-Sushi-Packer | UBSA: no de |
| ub-ultimate-sushi-packer | Ultimate-Sushi-Packer | UBSA: no de |
| ab-elite-sushi-packer | Elite-Sushi-Packer | AB: no de |
| ab-extreme-sushi-packer | Extreme-Sushi-Packer | AB: no de |
| ab-supreme-sushi-packer | Supreme-Sushi-Packer | AB: no de |
| ab-ultimate-sushi-packer | Ultimate-Sushi-Packer | AB: no de |

  - Remnants: `<name>-Überreste` style follows vanilla: look up how `base.cfg` de names remnants (e.g. key `express-splitter-remnants` / `remnants` pattern in `[entity-name]`), use that pattern with the German tier name.
  - Descriptions: translate meaning of each `en` line; mod names stay as written in `en` ("Space Exploration", "Krastorio 2", "Bob's Logistics", …); belt names inside descriptions use the belt's German name when the mod has one (table rule column), else English.
  - GUI (`gui.cfg`), settings, controls, tips: translate; game terms (circuit network, enable condition, quality, filter) from vanilla de.
- `README.md` + `portal/description.md`: tier table gains row `| Space sushi packer | Space Exploration | 45/s | 2.0 + 2.1 |` directly before the deep space row; the "Space Age is optional…" paragraph gains one sentence: "In Space Exploration the space box starts its own line: it needs no earlier box (1 steel chest, 1 space splitter, 4 bulk inserters, 10 processing units), and the deep space box is made from it." Add line "German translation included." at end of that paragraph. Portal + README stay English.
- `changelog.txt`: new top entries `Version: 0.2.12` / `Date: 2026-09-29` and `Version: 0.1.12` / `Date: 2026-09-29`, same shape as the 0.2.11 / 0.1.11 entries (both present today, 0.2.x block first — copy layout), Changes: "Added a sushi packer tier for Space Exploration space belts; the deep space packer is now made from it." and "Added German translation." Optimisations: "Slow belts (yellow, red) skip the take window read, lower script time." Keep every older entry.
- Offline runner: `describe`, `it`, `eq`, `ok` (`tests/offline/run.lua`); name `<describe> > <it>`.

## Explain very simply

Every text the game shows exists in English file. Make German file with same keys. Words for belts, inserters, chests come from the game's own German file, so players see the same words as in vanilla. Mods with no German keep their English belt word, glued with hyphen, like vanilla "Express-Fließband".

## What to build

1. `locale/en/locale.cfg`: all `se-space` keys (see above).
2. `locale/de/locale.cfg`, `locale/de/gui.cfg`: full German, same keys as `en`.
3. `README.md`, `portal/description.md`, `changelog.txt` as above.

### Tests to write — `tests/offline/test_locale_de.lua`, `describe("locale de", ...)`; each red at `lanes-base-v11` first, then green

- `locale de > same keys as en` — for `locale.cfg` and `gui.cfg`: set of `section/key` in `de` equals set in `en` (report missing and extra keys by name).
- `locale de > no empty value` — every `de` key has non-empty value.
- `locale de > tier names end with Sushi-Packer` — for every key of `N.ALL`: `[item-name]` value of `N.item(key)` in `de` ends with `Sushi-Packer`.
- `locale de > names follow table` — `sushi-packer`=`Sushi-Packer`, `fast-sushi-packer`=`Schneller Sushi-Packer`, `express-sushi-packer`=`Express-Sushi-Packer`, `se-space-sushi-packer`=`Space-Sushi-Packer`, `ab-elite-sushi-packer`=`Elite-Sushi-Packer`, `kr-superior-sushi-packer`=`Überlegener Sushi-Packer` in `[item-name]`.
- `locale de > same parameters as en` — for each key: every `__1__`, `__2__` … placeholder in `en` value appears in `de` value.

And in `tests/offline/test_locale_extra.lua` (`describe("locale extra", ...)`), add:
- `locale extra > se space name` — `[item-name]` `se-space-sushi-packer` = `Space sushi packer`.
- `locale extra > changelog has 0.2.12 and 0.1.12` — same shape as the 0.2.11 test: 0.2.12 dated 2026-09-29 precedes 0.2.11; 0.1.12 precedes 0.1.11.
- `locale extra > readme lists space tier` — `README.md` and `portal/description.md` contain `| Space sushi packer | Space Exploration | 45/s |`.

Also add `["se-space"] = "Space sushi packer",` to the `names` table in `tests/offline/test_locale_extra.lua` (so `locale extra > names mirror belt names` covers it). Every existing test stays green.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make zip`, never `--full`, never a file-wide or dir-wide run, never `lua5.2 tests/offline/run.lua <file>` on a whole file, except ONE allowed whole-file run: your own new file `lua5.2 tests/offline/run.lua tests/offline/test_locale_de.lua`. Never start Factorio, never run `tests/game/*` (`tools/run_tests.sh` refuses headless under `LANE_RUN_ID`). One test per call, milliseconds each:

```
make test-one T='tests/offline/test_locale_de.lua::locale de > same keys as en'
```

Write each new test first and see it fail before writing code.

**Never edit** `tests/offline/contract.lua`, `tests/offline/run.lua`, `tests/offline/test_guard.lua`, `tests/offline/fake_data.lua`, `tests/offline/golden_vanilla.lua`, `tests/offline/test_locale.lua`, `tests/offline/test_stage.lua`, anything under `tests/game/`, `docs/*` (this file included), `scripts/*`, `prototypes/*`, `control.lua`, `data.lua`, `data-final-fixes.lua`, `settings.lua`, `info.json`, `graphics/*`, `Makefile`, `tools/*`, `.agent-lane.toml`, any file not in "Files this lane owns". Never weaken, skip or delete an existing test or change an existing expectation. Never write under `~/share`.

## Commit, THEN check

Commit early, commit again. Run the checks below as the very LAST action.

## What done mean

```checks
{"name": "lane031-scope", "command": "git diff --name-only lanes-base-v11 HEAD | grep -Ev '^(locale/en/locale\\.cfg|locale/de/locale\\.cfg|locale/de/gui\\.cfg|README\\.md|portal/description\\.md|changelog\\.txt|tests/offline/test_locale_extra\\.lua|tests/offline/test_locale_de\\.lua)$' | ( ! grep . ) && echo lane031-scope-ok", "expect_exit": 0, "expect_regex": "lane031-scope-ok", "timeout_s": 60}
{"name": "lane031-tests", "command": "( for t in 'locale de > same keys as en' 'locale de > no empty value' 'locale de > tier names end with Sushi-Packer' 'locale de > names follow table' 'locale de > same parameters as en'; do tools/run_tests.sh 2.0 \"tests/offline/test_locale_de.lua::$t\" || exit 1; done; for t in 'locale extra > every extra tier has names and descriptions' 'locale extra > names mirror belt names' 'locale extra > descriptions name source mod' 'locale extra > readme and portal list every supported mod' 'locale extra > changelog has 0.2.11 and 0.1.11' 'locale extra > se space name' 'locale extra > changelog has 0.2.12 and 0.1.12' 'locale extra > readme lists space tier'; do tools/run_tests.sh 2.0 \"tests/offline/test_locale_extra.lua::$t\" || exit 1; done; tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane031-tests-ok", "expect_exit": 0, "expect_regex": "lane031-tests-ok", "timeout_s": 300}
```

## Files this lane owns

locale/en/locale.cfg (add `se-space` lines only), locale/de/locale.cfg (new), locale/de/gui.cfg (new), README.md, portal/description.md, changelog.txt, tests/offline/test_locale_extra.lua (add tests + one `names` entry only), tests/offline/test_locale_de.lua (new). Never touch anything else.

Re-cut because: none

# bound: 3600s
