# 046 — text: words for arms box (en + de), changelog, README, portal

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-046_text`, branch `lane/046_text`, base tag `lanes-base-v15`, merge target `int/v14`. Host `dev-vm`.

Lanes 040 data (`prototypes/hidden.lua`), 041 ledger (`scripts/ledger.lua`), 042 arms (`scripts/arms.lua`), 043 gui (`scripts/gui.lua`), 044 tick (`scripts/tick.lua`), 045 lifecycle (`scripts/registry.lua`, `scripts/copy.lua`), 046 text (`locale/*`, texts) run beside you or after you. No shared file. Seam = `docs/CONTRACT.md` section "v15 arms box seam (V15-1)". Read it first, it is law: names, signatures, rec fields, who owns what.

## You have about 30 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v15`. Signatures in `tests/offline/contract.lua` unchanged (guard `contract frozen` pins names + arity; private helpers start with `_`).

- New box, very short: hidden inserters ("arms"), each locked to one belt lane, drop items into hidden chest of that lane ("lane store", `N.STORE_SLOTS` = 12 slots). Engine moves items in. Script only pushes belt stacks out of each lane store onto same lane of front belt.
- Names in `scripts/names.lua`: `N.ARM`, `N.STORE`, `N.STORE_SLOTS`, `N.ARM_FILTERS`, `N.ARMS`.
- Stubs at base: `scripts/ledger.lua`, `scripts/arms.lua`, `prototypes/hidden.lua` (each lane fills its own; in your tests fake the others).
- Runs in Factorio Lua 5.2 on game versions 2.0 and 2.1: only API named in seam or already used in this repo. No `require` inside functions. No `math.random`. No `pairs` order deciding logic. State only in `storage` / `rec` (plain values and engine object references).
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq(found, expected)`, `ok(cond, msg)`; lua5.2; game API faked with plain tables in test file.
- What changes for player in v1.15 (author decisions 2026-10-01): box is much lighter on game speed (script cost about 10x less; say "much less script time", no number in locale); each lane now holds 12 slots (was 24); box window shows two rows, left lane and right lane, items can be taken by click; everything else works as before; old saves keep all items.
- Locale files `locale/en/*.cfg`, `locale/de/*.cfg`: same keys in both (guard test `locale de > same keys` family in `tests/offline/test_locale_de.lua`). New keys in section `[gui]`: `lanes`, `lane-left`, `lane-right`. German terms table (vanilla words, never others): lane = "Fließbandseite", belt stack = "Stapelhöhe", slots = "Plätze"; left / right lane = "Linke Fließbandseite" / "Rechte Fließbandseite"; section title "Fließbandseiten". Banned German words (guard): "Spur", "Bandstapel".
- Texts that name slot counts today: grep `24` and `48` in `locale/`, `README.md`, `portal/description.md`.
- `changelog.txt` format is pinned by `stage > changelog format valid`: copy shape of newest entry exactly (dash line, `Version:`, `Date:`, category lines with two-space indent, `- ` bullets). Add entries for `0.2.15` and `0.1.15` at top in same order as existing pairs, date `2026-10-01`.
- Version numbers elsewhere (`info.json`, `README.md` version line, `portal/description.md` version line, `tools/*`) are bumped by integrator: do not touch version strings outside `changelog.txt`. Test `stage > versions are 0.1.14 and 0.2.14` must stay green.

## Explain very simply

Box works in a new way inside. Tell player in few plain words: lighter, 12 slots per lane, window shows both lanes. Same words in English and German, plus changelog.

## What to build

### Tests first — new `tests/offline/test_text_v15.lua`, describe `text v15`; each seen RED before text

Read files as text (pattern `tests/offline/test_stage.lua` lines 1-10).

- `text v15 > gui lane keys in en and de` — keys `lanes`, `lane-left`, `lane-right` under `[gui]` in both locales, non-empty; de values contain "Fließbandseite". RED.
- `text v15 > no stale slot counts` — no text in `locale/en`, `locale/de`, `README.md`, `portal/description.md` says a lane holds 24 slots or box holds 48 slots; each of those four places that spoke of slots now says 12 per lane. RED.
- `text v15 > changelog has 0.1.15 and 0.2.15` — both `Version:` lines present above older ones, each with at least 3 bullets, mentions lanes window and 12 slots. RED.
- `text v15 > german avoids banned words` — no "Spur", no "Bandstapel" in `locale/de`. Green at base (say so).

### Text

Write texts per "What is true". Short sentences. No promise of exact speed numbers.

### Mutation

Remove key `lane-right` from `locale/de` -> `text v15 > gui lane keys in en and de` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all`, never `make zip`, never `--full`, never a dir-wide run, never whole-file run of a test file you do not own. Never start Factorio, never run `tests/game/*`. One test per call:

```
make test-one T='tests/offline/test_text_v15.lua::text v15 > gui lane keys in en and de'
```

Whole-file run allowed only for test files this lane owns: `lua5.2 tests/offline/run.lua tests/offline/test_text_v15.lua`.

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
{"name": "lane046-scope", "command": "git diff --name-only lanes-base-v15 HEAD | grep -Ev '^(locale/(en|de)/[^/]+\\.cfg|changelog\\.txt|README\\.md|portal/description\\.md|tests/offline/test_text_v15\\.lua)$' | ( ! grep . ) && echo lane046-scope-ok", "expect_exit": 0, "expect_regex": "lane046-scope-ok", "timeout_s": 60}
{"name": "lane046-tests", "command": "( for t in 'gui lane keys in en and de' 'no stale slot counts' 'changelog has 0.1.15 and 0.2.15' 'german avoids banned words'; do tools/run_tests.sh 2.0 \"tests/offline/test_text_v15.lua::text v15 > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_text_v15.lua ) && echo lane046-tests-ok", "expect_exit": 0, "expect_regex": "lane046-tests-ok", "timeout_s": 300}
{"name": "lane046-keep-green", "command": "( while IFS= read -r t; do tools/run_tests.sh 2.0 \"$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done < tests/offline/fixtures/v15_keep_green.txt ) && echo lane046-keep-green-ok", "expect_exit": 0, "expect_regex": "lane046-keep-green-ok", "timeout_s": 900}
```

## Files this lane owns

locale/en/*.cfg, locale/de/*.cfg, changelog.txt, README.md, portal/description.md, tests/offline/test_text_v15.lua (new). Never touch anything else.

Re-cut because: none

# bound: 1800s
