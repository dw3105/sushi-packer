---
name: sushi-packer-code
description: "Working rule for sushi-packer, Factorio 2.0 + 2.1 belt-stacking box mod: requirements contract, frozen seams, lanes run single offline mock-based Lua tests only, headless Factorio only at integrator merge and release, API in both versions only, no push from VM. Read before editing prototypes/, scripts/, tests/, control.lua, data.lua, or claiming anything about this repo."
---

**v0.7 - 29 Sep 2026.** File caveman full. Change log in `references/ledger.md`, never here.

**Canonical copy is `skills/sushi-packer-code/` in this repo.** Live copy `~/.claude/skills/sushi-packer-code` installed by `make skill-install` from clean `main` only. Edit live copy and SessionStart audit report drift. Shape copied from `local-transcriber-code`; lane rules follow shared `codex-tasks`. Requirements file in docs outranks this skill; when they disagree, requirements win and this skill gets fixed on next round by integrator.

## What this enforces, and what it does not

| State | Rules |
|---|---|
| Machine check | SP-01 (`tests/offline/test_guard.lua`, `tests/game/test_guard.lua`), SP-02 (`tools/run_tests.sh` refuses non-test `T`, and refuses `tests/game/*` and `--full` when `LANE_RUN_ID` is set) |
| Human checklist | SP-03 .. SP-21 |

SP-02 has machine stop inside `tools/run_tests.sh` (and `make test-one`, which calls it): refuses file or dir, one-test mode fails unless exactly one test ran and passed, and under `LANE_RUN_ID` (set by `lane_run` for engine and checks) refuses every headless run. Lane calling Factorio binary or `lua5.2 tests/offline/run.lua <file>` direct meets no stop, only task-file ban and reviewer read of lane log. Integrator greps lane log for `factorio`, `make test ` and bare runner calls before merge. Green lint prove copy match only, never rule read or obeyed.

## Code and tests

- **SP-01** **Seams frozen.** `docs/CONTRACT.md` signatures, names module `scripts.names`, storage layout pinned by guard tests. Lane never edits guard, contract or names. Change = integrator decision in `docs/DECISIONS.md`.
- **SP-02** **Lanes run single offline Lua tests only, built on mocks.** `make test-one T='tests/offline/<file>.lua::<describe> > <it>'`. Never Factorio, never `tests/game/*`, never `make test`, never full suite of any kind. Only whole-file run allowed: lane's own new offline file in task checks, `lua5.2 tests/offline/run.lua <own new file>` (ms; catches order dependence; shared `codex-tasks` rule, friction log, 2026-09-28). Game API faked with plain Lua tables in the test file. Headless Factorio belongs to integrator: at merge and release, full suite once per version after all lanes merged, fix each red with `make test-one`, rerun full, repeat until green (author, 2026-09-26).
- **SP-03** **Red first.** Every new test seen failing against stub before code. Green without seen red is not evidence (`proving`).
- **SP-04** **Both versions.** Only API present in 2.0 and 2.1. Docs https://lua-api.factorio.com/2.0.72/ first, `/latest/` second. Forbidden 2.1-only: `LuaTransportLine.get_item_position`, container `direction_count`. Headless result counts only when run on both `FV=2.0` and `FV=2.1`.
- **SP-05** **State in `storage` only.** No upvalue caches that survive save/load, no `math.random` without game RNG, no `pairs` order in logic (desync; see requirements §1).
- **SP-06** **Offline tests `lua5.2` only.** Pure logic (module `scripts.core`) never touches `game`, `defines`, `storage`. Adapter modules take game objects as arguments or read globals inside functions, so a test swaps in mock tables.

## Assets, shipping

- **SP-07** **No base-game file in mod.** Graphics only from `graphics/` (copied from `~/share/sushi-packer/mod-graphics/graphics/`). Never redraw unless author asks.
- **SP-08** **No push from VM.** Operator pushes from laptop via publish boxes (`operator-blocks`). Commit in worktree, `git merge --ff-only` into `~/sushi-packer-mod`.
- **SP-09** **Requirement IDs are progress.** Report every ID PASS / FAIL / NOT-TESTED with test name in `docs/REQ-STATUS.md`. Never "works" without run.
- **SP-10** **Probe files (report via `error()`) stay out of `tests/game/index.lua`.** Run: add temporary index entry, `make test-one`, remove entry before commit. Every filtered output keeps `Tests:` line; `0 passed ... skipped` = probe never ran (friction log, 2026-09-27). Long probe: passed-test `print` never reaches CLI, so report via `log()` (read `build/<FV>/ftdata/factorio-current.log`); runner passes `--output-timeout 180` (SE universe build, 2026-09-29); still `print` progress under 180 s apart.

## Evidence, hosts, operator (v0.6, friction log 2026-09-29, author approved)

- **SP-11** **"Cannot serve" needs engine probe.** Before telling author a player request cannot be served, probe engine fact the "no" rests on. Mod dependency text is not feature availability (findings 2026-09-29: stacking works with `space-age` mod off).
- **SP-12** **Grep tools before moving shared files.** Before move or delete in shared dir (`~/share`, `~/.cache`), `grep -rn <path> tools/ Makefile .github` in repo. `~/share` = only files author asked for or files presented (`docs/RULINGS.md`).
- **SP-13** **Test asserts its environment.** Test or set that claims environment (mods on/off, settings) asserts it inside run (`tools/run_tests.sh` harness space-age guard). Set name is not proof.
- **SP-14** **Probe proves rig first.** Rate/timing probe shows warm-up >= transit time for every tier measured, or known-good control per speed class, before numbers become finding (first blue-rate report 2026-09-29 was rig artifact).
- **SP-15** **Watch what own heavy job blocks; never edit running script.** After starting heavy wrap, read `gateslot status` once for "waiting behind it". Stop background job before editing file it executes.
- **SP-16** **Box guard prints what it compared.** Every guard `test` in operator box ends `|| echo "SP-GUARD <name>=<value>"` so silent stop shows cause. Laptop facts read once go to memory (origin = `https://github.com/dw3105/sushi-packer.git`, vm = `claude-vm:sushi-packer-mod`).

## Planning, proving, handoff (v0.7, friction log 2026-09-29 v11, author approved)

- **SP-17** **Grill = one question per turn.** Each question carries line starting `Recommend`; never numbered batch (`docs/RULINGS.md`, author "ONE AT A TIME").
- **SP-18** **S0 greps semantics, not only names.** Before lanes, grep offline + game tests for every field and constant whose meaning requirement amendment changes (`own_role`, `prev`, ...); fix old-rule tests in S0 (v11: lane hard-coded `se-space` around stale `own_role` test).
- **SP-19** **Translation task carries term table.** Every recurring domain word (lane, belt stack, research, circuit) with vanilla locale source line, plus guard test banning known wrong words (v11: "Spur", "Bandstapel" ~270 lines).
- **SP-20** **Bench bar needs measured noise.** Before any bench bar, run A/A control (same build twice, alternated) for noise band; bar = mean of >= 6 alternated pairs outside that band (v11: build C alone ranged 3.36-3.97 ms).
- **SP-21** **Box lint before send.** Run `guards/boxlint.py` on every operator box before sending, not only `bash -n` (v1.12 box re-issued for BL-7 / BX-3).

| Reference | Read when |
|---|---|
| `references/ledger.md` | changing this skill |
