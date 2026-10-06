# 065 — dumptool: fetch any portal mod pack and dump our techs with it

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-065_dumptool`, branch `lane/065_dumptool`, base tag `lanes-base-retro`, merge target `retro/v24`. Host `dev-vm`.

Lane 066 relink_nil runs beside you; it owns only `prototypes/tier.lua` and `tests/offline/test_data_v24.lua`. No shared file.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-retro`. Existing subcommands of `tools/fetch_mods.py` (`lock`, `fetch FV [MODSET]`, `list FV MODSET`) keep output and behaviour; `tests/mods.lock.json` and `tools/modsets.json` untouched; existing Makefile targets unchanged.

- `tools/fetch_mods.py` (stdlib only): `api(name)` (line 20) GETs `https://mods.factorio.com/api/mods/<name>/full`, memoised; `dep_name(dep)` (line 27) returns `None` for optional `?`, hidden `(?)`, incompatible `!`, else bare name; `newest(name, fv)` (line 35) = release with `info_json.factorio_version == fv` and latest `released_at`, `SystemExit` when none; `resolve(fv, mods, pinned=None)` (line 42) walks hard deps, skips `BUILTIN` (`base`, `space-age`, `quality`, `elevated-rails`, `recycler`, `core`), returns `{name: {version, file, sha1, url}}`; `creds()` (line 86) reads `~/.factorio-portal` (`username=`, `token=`); `cmd_fetch` (lines 100-128) downloads `https://mods.factorio.com<url>?username=..&token=..` with header `User-Agent: sushi-packer-fetch/1` (default urllib UA gets 403), writes `<file>.part`, checks sha1, `os.replace`, prints `fetched <file> <size>`; cache `CACHE = ~/.cache/sushi-packer-mods`.
- `tools/stage.sh <FV> release` with env `STAGE_DIR=<dir>` stages our mod into `<dir>/mods/sushi-packer_<ver>/`, writes `<dir>/config.ini` (`read-data` = Factorio data, `write-data=<dir>/write`); Factorio at `~/factorio-<FV>/factorio/bin/x64/factorio`.
- Reference probe that worked (dev-vm 2026-10-06, full pY, FND-0058): stage, hard-link every `*.zip` of mod dir into `<dir>/mods/`, write `mod-list.json` = `base` + `sushi-packer` + each zip's mod name (file name before last `_`) enabled; `space-age`, `quality`, `elevated-rails`, `recycler` disabled unless asked; run `factorio --config <dir>/config.ini --mod-directory <dir>/mods --dump-data > <dir>/dump.log 2>&1`; result `<dir>/write/script-output/data-raw-dump.json`. pY zips cached at `~/.cache/sushi-packer-mods/py-2.1/` (21 zips).
- Our tier tech and recipe names end with `sushi-packer` (`scripts/names.lua:60`, `N.item(tier) = N.PREFIX[tier] .. "sushi-packer"`; tech name = item name). pY adds recipes `<item>-pyvoid` (not ours).
- Makefile `GATE := gateslot --label sushi-packer/heavy --` when gateslot present (line 6); targets carry `## help` comments.
- No Python test suite exists yet. New tests: stdlib `unittest`, one file each, `unittest.main()` at bottom so `python3 tests/tools/<file>.py <Class>.<test>` runs one test and prints `Ran N test(s)`.

## Explain very simply

Players report bugs with big mod packs (pY, Krastorio). Today checking one takes hand-written scripts. Build two commands: one downloads any portal mod with its hard dependencies; one loads our mod with a folder of mod zips headless and prints our techs and recipes.

## What to build

### `tools/fetch_mods.py fetch-adhoc FV MOD [MOD ...]`
- `plan = resolve(FV, mods)` (newest per mod, no pins). Prints `plan <name> <version> <file>` per mod, sorted by name, then downloads each into `~/.cache/sushi-packer-mods/adhoc-<FV>/` (skip file already there with right sha1, print `have <file>`), last line `fetch-adhoc-<FV>-ok <n> mods <dir>`.
- Move download of one entry into `download(entry, d, user, token)` returning path; `cmd_fetch` calls it (same output). Functions `api`, `dep_name`, `newest`, `resolve`, `cmd_lock`, `members`, `creds`, `sha1` stay byte-same (AST check). Module docstring (usage, printed on bad args) gains line `tools/fetch_mods.py fetch-adhoc FV MOD...   download newest portal mods + hard deps into ~/.cache/sushi-packer-mods/adhoc-FV (probe only)`.

### `tools/dump_report.py <data-raw-dump.json>`
- Prints, sorted by name: `TECH <name> prereq=<a,b,..> packs=<x,y,..> count=<n>` for every technology whose name ends with `sushi-packer` (packs = first element of each `unit.ingredients` entry, in order; `count=-` when no `unit` or no `count`); then `RECIPE <name> <ing>:<amount>,..` for every recipe whose name ends with `sushi-packer`; last line `dump-report-ok <path>`.

### `tools/dump_data.sh <FV> <MODDIR> [sa]`
- `set -eu`. Out dir `~/.cache/sushi-packer/dump-<FV>` (wiped first). Stage with own repo's `tools/stage.sh` (repo = dir above script). Link zips, mod-list as reference probe (`sa` = keep space-age set on). Run dump; on failure print last 30 lines of `dump.log` and exit 1. Print every `Loading mod sushi-packer` line of `dump.log`, then `tools/dump_report.py` output, last line `dump-data-<FV>-ok`.

### Makefile
- `fetch-adhoc: ## Download portal mods + hard deps for a probe: FV=, MODS="a b"` -> `tools/fetch_mods.py fetch-adhoc $(FV) $(MODS)`.
- `dump-data: ## Headless data dump of our mod with mod zips: FV=, MODS=<dir>, SA=1` -> `$(GATE) tools/dump_data.sh $(FV) $(MODS) $(if $(SA),sa)`. Add both to `.PHONY`.

### Tests first; each seen RED before code
`tests/tools/test_fetch_mods.py` (class `FetchAdhocTests`; import module from `tools/fetch_mods.py` by path with `importlib.util`; patch `api` with fake dict, patch `urllib.request.urlopen`; never network, never real `~/.factorio-portal`, never real cache: pass temp dir):
- `test_plan_takes_hard_deps_only` — mod `A` deps `["base", "B >= 1.0", "? C", "(?) D", "! E", "~ F"]` -> plan names `{"A", "B", "F"}`.
- `test_plan_takes_newest_release_for_version` — `A` releases 2.0 (`2026-01-01`), 2.0 (`2026-02-01`), 2.1 (`2026-03-01`); plan for 2.0 picks February one.
- `test_plan_skips_builtin_mods` — dep `space-age` and `quality` absent from plan.
- `test_download_refuses_wrong_sha1` — fake body, wrong sha1 -> `SystemExit`; no file and no `.part` left in temp dir.
- `test_download_keeps_good_file` — right sha1 -> file present with body; request URL carries `username=` and `token=`, header `User-agent` = `sushi-packer-fetch/1`.

`tests/tools/test_dump_report.py` (class `DumpReportTests`; run `tools/dump_report.py` on fake JSON in temp dir via `subprocess`):
- `test_report_lists_tier_techs_and_recipes` — techs `sushi-packer` (unit count 30, packs automation) and `fast-sushi-packer` (prereqs `logistics-2`, `basic-electronics`), recipe `fast-sushi-packer` (`fast-splitter` 1, `advanced-circuit` 5): exact lines `TECH fast-sushi-packer prereq=logistics-2,basic-electronics packs=... count=...` etc. in name order.
- `test_report_ignores_other_techs` — `logistics-2`, recipe `fast-sushi-packer-pyvoid` absent from output.
- `test_report_last_line_names_dump` — last line `dump-report-ok <path>`.

### Mutation
1. `resolve` keeps optional deps (drop `?` handling in a copy) -> `test_plan_takes_hard_deps_only` red; restore. 2. `download` skips sha1 check -> `test_download_refuses_wrong_sha1` red; restore. Never commit mutated state.

## Test rule — read twice

Lanes run single offline tests only. FORBIDDEN: any full suite, `make test*`, `make load-check`, `make bench*`, `make zip`, `make dump-data`, `make fetch-adhoc` (they download GBs or start Factorio), running `tools/dump_data.sh`, running `fetch-adhoc` for real, any network call, starting Factorio. One test per call: `python3 tests/tools/test_fetch_mods.py FetchAdhocTests.test_plan_takes_hard_deps_only`. Whole-file run allowed only for your two new test files. Integrator runs real fetch + dump after merge.

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `tools/stage.sh`, `tools/modsets.json`, `tests/mods.lock.json`, `tests/offline/*`, `tests/game/*`, `prototypes/*`, `scripts/*`. Never weaken a test.

## Commit, THEN check
Tests commit (red) first, then code commit. Checks very LAST.

## Final report
Red output of each new test at base, green after, both mutations red + restore green, `git log --oneline lanes-base-retro..HEAD`.

## What done mean

```checks
{"name": "lane065-scope", "command": "git diff --name-only lanes-base-retro HEAD | grep -Ev '^(tools/fetch_mods\\.py|tools/dump_data\\.sh|tools/dump_report\\.py|Makefile|tests/tools/test_fetch_mods\\.py|tests/tools/test_dump_report\\.py)$' | ( ! grep . ) && echo lane065-scope-ok", "expect_exit": 0, "expect_regex": "lane065-scope-ok", "timeout_s": 60}
{"name": "lane065-tests", "command": "( for t in FetchAdhocTests.test_plan_takes_hard_deps_only FetchAdhocTests.test_plan_takes_newest_release_for_version FetchAdhocTests.test_plan_skips_builtin_mods FetchAdhocTests.test_download_refuses_wrong_sha1 FetchAdhocTests.test_download_keeps_good_file DumpReportTests.test_report_lists_tier_techs_and_recipes DumpReportTests.test_report_ignores_other_techs DumpReportTests.test_report_last_line_names_dump; do f=tests/tools/test_fetch_mods.py; case $t in Dump*) f=tests/tools/test_dump_report.py;; esac; python3 $f $t || exit 1; done; for f in tests/tools/test_fetch_mods.py tests/tools/test_dump_report.py; do out=$(python3 $f 2>&1) || { echo \"$out\"; exit 1; }; n=$(printf '%s\\n' \"$out\" | sed -n 's/^Ran \\([0-9]*\\) tests\\{0,1\\} in .*/\\1/p'); [ \"${n:-0}\" -ge 3 ] || { echo \"$f count=$n\"; exit 1; }; done ) && echo lane065-tests-ok", "expect_exit": 0, "expect_regex": "lane065-tests-ok", "timeout_s": 300}
{"name": "lane065-fetch-unchanged", "command": "( python3 -c \"import ast,subprocess,sys; old=ast.parse(subprocess.check_output(['git','show','lanes-base-retro:tools/fetch_mods.py'],text=True)); new=ast.parse(open('tools/fetch_mods.py').read()); f=lambda t:{n.name:ast.dump(n) for n in t.body if isinstance(n,ast.FunctionDef)}; o,n=f(old),f(new); bad=[k for k in ('api','dep_name','newest','resolve','cmd_lock','members','creds','sha1') if o.get(k)!=n.get(k)]; print('changed',bad) if bad else None; sys.exit(1 if bad else 0)\" && python3 tools/fetch_mods.py 2>&1 | grep -q fetch-adhoc && bash -n tools/dump_data.sh && make -n dump-data FV=2.1 MODS=/nonexistent | grep -q 'tools/dump_data.sh 2.1 /nonexistent' && make -n fetch-adhoc FV=2.0 MODS='a b' | grep -q 'tools/fetch_mods.py fetch-adhoc 2.0 a b' ) && echo lane065-wiring-ok", "expect_exit": 0, "expect_regex": "lane065-wiring-ok", "timeout_s": 120}
{"name": "lane065-keep-green", "command": "( for t in 'stage > versions are 0.1.24 and 0.2.24' 'stage > changelog format valid' 'stage > release stage needs no Factorio'; do tools/run_tests.sh 2.0 \"tests/offline/test_stage.lua::$t\" >/dev/null 2>&1 || { echo \"RED $t\"; exit 1; }; done ) && echo lane065-keep-green-ok", "expect_exit": 0, "expect_regex": "lane065-keep-green-ok", "timeout_s": 120}
```

Owner base colours (`lanes-base-retro`, scratch `HOME`, 2026-10-06): lane065-scope GREEN, lane065-tests RED (no test files), lane065-fetch-unchanged RED (AST half green, no `fetch-adhoc` in usage yet), lane065-keep-green GREEN.

## Files this lane owns

tools/fetch_mods.py, tools/dump_data.sh (new), tools/dump_report.py (new), Makefile, tests/tools/test_fetch_mods.py (new), tests/tools/test_dump_report.py (new). Never touch anything else.

Re-cut because: none

# bound: 2700s

Reviewer ask: do `fetch-adhoc` and `dump_data.sh` follow the reference probe, stay offline in tests, and leave existing `fetch`/`list`/`lock` behaviour unchanged?
