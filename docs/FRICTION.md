# Friction

Rows committed unasked at session close. Only a proposed rule change gets operator confirmation, asked in its own turn.

Row shape: `## FRC-NNNN - title`, then date + context, issue, root cause, proposed rule change (or "none").

---

## FRC-0001 - Foreground `lane launch` under `timeout` orphaned the worker

**2026-09-26, wave 1 launch.** First `lane launch` ran in foreground wrapped in `timeout 120`; timeout killed the supervisor, worker kept running unsupervised. Root cause: launcher supervises in foreground until verdict; not known at launch. Cost: one killed attempt, partial edits discarded. Proposed rule change: none; launch always with background runner (done for every later lane).

## FRC-0002 - Headless tests in lanes cost more than the code they checked

**2026-09-26, wave 1.** Each single in-game test boots Factorio (10-26 s, more at load avg 17); lanes 003-007 spent most of their budget booting; 3 lanes hit the 10 s CLI watchdog (FND-0005) and their deadlines. Root cause: plan let lanes run engine tests. Rule change applied by author: SP-02 v0.2, lanes offline mock tests only; runner refuses headless under `LANE_RUN_ID`.

## FRC-0003 - Estate `lane merge` refuses integrator as reviewer when codex wrote the code

**2026-09-26, lane 001 merge.** `lane review` records reviewer session = merging session (subagents inherit `CLAUDE_CODE_SESSION_ID`), `lane merge` refuses self-approval although author was codex. Author decided: integrator reviews, merges with `git merge --no-ff` (REV). Proposed rule change: none here; estate tool could accept engine identity as author.

## FRC-0004 - Plan mode kept me from running probes author asked for

**2026-09-27, plan B3.** Author asked "run the probes"; session still in plan mode, I rewrote plan and called ExitPlanMode instead of saying writes were blocked; author: "YOU DIDN'T RUN PROBES I ASKED FOR!!!!". Root cause: did not tell author plan mode blocks every write incl. test files. Proposed rule change: none in repo; memory `plan-mode-blocks-probes`.

## FRC-0005 - Author's chosen shape added as side note, not as plan

**2026-09-27.** Author proposed B3 (lane-splitter + companion chest + companion belt); I added it as one bullet next to B1/B2. Author: "B3 MUST BE THE PLAN, NOT A SIDE NOTE!!!!". Rule change: memory `author-pick-is-the-plan` (applied).

## FRC-0006 - Probe file not in index: 12 runs skipped, output filtered to nothing

**2026-09-27, B3 probes.** `test_probe_b3.lua` not in `tests/game/index.lua` -> runner reported `Tests: 129 skipped, 0 passed`; my `grep PROBE` filter hid that line, and 2.1 FactorioTest exit trace looked like mod crash. Cost: one full 12-run batch (~15 min) wasted. Root cause: output filter dropped the `Tests:` count line. Rule change applied: SP-10 in repo skill (probe runs need temporary index entry; always keep `Tests:` line in filtered output).

## FRC-0007 - Plan promised design before checking engine load rules

**2026-09-27.** B3 plan listed companion belt as working piece; first load showed engine forbids it (FND-0018). Cheap check (define prototype, load once) came after author picked shape. Proposed rule change: none; data-stage load of any new prototype idea goes before offering it as plan option.

