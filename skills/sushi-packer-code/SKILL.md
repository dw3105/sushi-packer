---
name: sushi-packer-code
description: "Working rule for sushi-packer, Factorio 2.0 + 2.1 belt-stacking box mod: requirements contract, frozen seams, lanes run single tests only, integrator runs full suite on both versions, API in both versions only, no push from VM. Read before editing prototypes/, scripts/, tests/, control.lua, data.lua, or claiming anything about this repo."
---

**v0.1 - 26 Sep 2026.** File caveman full. Change log in `references/ledger.md`, never here.

**Canonical copy is `skills/sushi-packer-code/` in this repo.** Live copy `~/.claude/skills/sushi-packer-code` installed by `make skill-install` from clean `main` only. Edit live copy and SessionStart audit report drift. Shape copied from `local-transcriber-code`; lane rules follow shared `codex-tasks`. Requirements file in docs outranks this skill; when they disagree, requirements win and this skill gets fixed on next round by integrator.

## What this enforces, and what it does not

| State | Rules |
|---|---|
| Machine check | SP-01 (`tests/offline/test_guard.lua`, `tests/game/test_guard.lua`), SP-02 (`make test-one` refuses non-test `T`) |
| Human checklist | SP-03 .. SP-09 |

SP-02 has machine stop inside `make test-one` and `tools/run_tests.sh`: both refuse file or dir, and one-test mode fails unless exactly one test ran and passed. Lane calling `tools/run_tests.sh <v> --full` meets no stop, only task-file ban and reviewer read of lane log. Integrator greps lane log for `make test `, `--full` and bare `lua5.2` runner calls before merge. Green lint prove copy match only, never rule read or obeyed.

## Code and tests

- **SP-01** **Seams frozen.** `docs/CONTRACT.md` signatures, names module `scripts.names`, storage layout pinned by guard tests. Lane never edits guard, contract or names. Change = integrator decision in `docs/DECISIONS.md`.
- **SP-02** **Lanes run single tests only.** `make test-one FV=<v> T='<file>::<test name>'`. Never `make test`, never runner without test name, never full suite of any kind. Full suite belongs to integrator after all lanes merged: run once per version, fix each red with `make test-one`, rerun full, repeat until green.
- **SP-03** **Red first.** Every new test seen failing against stub before code. Green without seen red is not evidence (`proving`).
- **SP-04** **Both versions.** Only API present in 2.0 and 2.1. Docs https://lua-api.factorio.com/2.0.72/ first, `/latest/` second. Forbidden 2.1-only: `LuaTransportLine.get_item_position`, container `direction_count`. In-game test counts only when run on both `FV=2.0` and `FV=2.1`.
- **SP-05** **State in `storage` only.** No upvalue caches that survive save/load, no `math.random` without game RNG, no `pairs` order in logic (desync; see requirements §1).
- **SP-06** **Offline tests `lua5.2` only.** Pure logic (module `scripts.core`) never touches `game`, `defines`, `storage`.

## Assets, shipping

- **SP-07** **No base-game file in mod.** Graphics only from `graphics/` (copied from `~/share/sushi-packer/mod-graphics/graphics/`). Never redraw unless author asks.
- **SP-08** **No push from VM.** Operator pushes from laptop via publish boxes (`operator-blocks`). Commit in worktree, `git merge --ff-only` into `~/sushi-packer-mod`.
- **SP-09** **Requirement IDs are progress.** Report every ID PASS / FAIL / NOT-TESTED with test name in `docs/REQ-STATUS.md`. Never "works" without run.

| Reference | Read when |
|---|---|
| `references/ledger.md` | changing this skill |
