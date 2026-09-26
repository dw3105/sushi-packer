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
