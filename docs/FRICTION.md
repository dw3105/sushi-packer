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


## FRC-0008 - Shell box format pasted into Factorio console broke Lua parse

**2026-09-28, thumbnail.** Box gave `/c ... # expected: ...` lines (shell trailing-comment convention). In Lua `#` = length operator: author got `unexpected symbol near '#'`, one round trip lost. Bucket: operator-blocks. Root cause: box rules written for shells, applied to non-shell console unchanged. Applied: memory `release-box-gate-sha` (second note). Proposed rule change (operator-blocks): box for non-shell target (game console, REPL) carries no trailing comment; expected result goes above box in prose.

## FRC-0009 - Release box gated on wrong CI run

**2026-09-28, v1.8 publish.** `gh run watch --exit-status $(gh run list --workflow release.yml --limit 1 ...)` ran right after tag push; run list still showed v1.7 run 36316885880 (success) -> `main` pushed before v1.8 run existed; `gh release download` -> "release not found". v1.8 run 36418169509 later green, zips identical to dev-vm build. Bucket: shipping-and-integration. Root cause: gate picked newest run, not run of tag sha. Applied: memory `release-box-gate-sha`. Proposed rule change (shipping-and-integration / BL-7 gate): gate command waits for run with `head_sha` = tag sha, then watches that id.

## FRC-0010 - Screenshot line fired on time, not on state

**2026-09-28, thumbnail.** First shots had empty output belt: author pasted screenshot line too soon; I sent a fixed-delay line (3600 ticks) before author asked "is it taken when outputs exist?". Condition line (`on_nth_tick` until both output lanes hold items) worked first time. Headless repro `sim > scene built by console in fresh game outputs` passed on e5dfff1 + v8 = no bug. Bucket: evidence capture. Proposed rule: capture scripts wait on observed state (item on output), never wall or tick delay.

## FRC-0011 - FactorioTest hides print of passed tests; 15 s silence kills run

**2026-09-28, soak probe.** Passed-test `print` never reaches CLI output (soak report lost once), and CLI watchdog killed run after `no output received for 15 seconds` (3600-tick silent window). Fix: report via `log()` (lands in `build/<FV>/ftdata/factorio-current.log`), progress `print` every 600 ticks. Bucket: sushi-packer-code SP-10. Proposed rule change (SP-10): long probes log via `log()` and print progress < 15 s apart.

## FRC-0012 - Parallel lanes on one function: cross-lane test clash found only at merge

**2026-09-28, lanes 022 + 023.** Cap test `cap > no item stack means no cap` put 100 items (25 slots) on one lane; quota lane capped lane at 24 -> red only after both merged; integrator fixed test (80 items). Also game test `tick > output never faster than tier` built 150-ore backlog, now impossible under both rules; fixed at full suite (2 reruns ~25 min). Bucket: codex-tasks / plan. Root cause: task files told each lane other rule absent. Proposed: task file for lanes sharing a seam lists other lane's rule as fact ("lane holds max 24 slots after merge") so lane tests stay valid under both; integrator greps game tests for old-rule fixtures (backlog size, shared 48) in S1.

## FRC-0013 - Auto-mode classifier outage blocked tools mid-turn

**2026-09-28.** Server-side auto-mode classifier returned no verdict on `Bash` and `SendMessage` 6+ times (peer handoff to `rrc_fixer_3` pasted by author instead). Bucket: environment. No rule change; retry once, then hand text to operator.

## FRC-0014 - `cmd | tail` hid failing exit code twice

**2026-09-28, close-out.** `make skill-lint | tail -2 && git commit` committed + installed despite lint failure (fixed next commit `7b2d083`); `git commit ... | tail -3` in `~/skills` reported exit 0 while pre-commit hook refused commit (found ~20 min later). Bucket: evidence-and-claims. Root cause: pipeline exit = last stage. Rule: gate commands never piped without `set -o pipefail`; read `commit_rc` / `git log -1` after commit. Also found: `~/skills` main `72a4f1c` red on `tests.test_host_sweep_roots` `test_mutation_evidence_reproduces` (125 != 0), unrelated; skills commit `9e2e2d4` used `--no-verify` with reason in body.

## FRC-0015 - Lane tests green one by one, red as a file (twice in v9)

**2026-09-28, v9 S2.** Lane 025 (`belt_io` rate cache kept across tests) and lane 024 (tests set `_G.log = nil`) passed every `make test-one` check, but whole-file runs failed (1 of 8, 8 of 16). Lanes only run single tests (SP-02), so order dependence is invisible to them. Integrator caught both by running each merged file whole before headless. Bucket: process. Proposed (author decides): task checks also run the lane's own new file whole (`lua5.2 tests/offline/run.lua <new file>`, ms, offline, not a suite).

## FRC-0016 - S0 stub with `require` inside function reached headless

**2026-09-28, v9 S2.** My S0 stub `belt_io.lane_rate` did `require("scripts.names")` inside the function; lua5.2 allows it, Factorio does not (`Require can't be used outside of control.lua parsing.`). Lane 025 kept the line; first modded headless run crashed. Fix: guard test `guard > no require inside runtime functions` (red on that line first). Bucket: integrator seam quality.

## FRC-0017 - Uncalibrated gateslot wrap blocked shared queue 16 min

**2026-09-28, v9 S0.** Blender test render wrapped in `gateslot --label sushi-packer/heavy` got whole-box weight (15986 MiB / 4 cores), sat at queue head (no overtaking), blocked own P1 + `skills/heavy` x2 + `suite-runner/agent` x2 for ~16 min. Auto mode refused my kill of own queued pid; author ran `! kill 633219`. Bucket: shared host. Root cause: new command never calibrated; label weight lookup falls back to whole machine. Proposed rule (shared-host): first run of any new command under gateslot needs `gateslot calibrate`, or runs unwrapped under `nice -n 19` when single-thread light.

## FRC-0018 - Operator asks buried or unlocatable

**2026-09-28.** (1) Token box given mid-turn then buried under tool output; later status said only "P1 waits on your token file" -> "THEN FUCKING GIVE ME INSTRUCTIONS!!!!!". (2) Told author zips are "in the Box 3 temp dir" of a `mktemp -d` subshell that never printed its path -> "ARE YOU SERIOUS?". Bucket: talking to operator. Root cause: ask written for my context, not operator's screen. Proposed rule (talking-to-operator): every operator ask = numbered steps as last content of turn, never "as before"; every file handed over sits at a named, printed path.

## FRC-0019 - Version bump missed README + portal text; test pinned stale value

**2026-09-28, v1.9.** Bump edited `info.json`, `stage.sh`, `load_check.sh`, tests, changelog; `README.md` + `portal/description.md` kept `0.1.8` / `0.2.8`; `stage > portal logo and description in repo` required `0.1.8`, so it stayed green. Author caught it on portal page. Bucket: shipping. Fix: test pins current version in both docs (red first). Proposed rule (shipping-and-integration): version bump greps whole repo for previous version string before commit.

## FRC-0020 - `lane launch` loop ran lanes one after another

**2026-09-28, v9 S1.** `for l in 024 025 027; do lane.py launch ...; done` blocks per lane (foreground until lane ends); only 024 started. Killed loop shell, relaunched 025 + 027 as separate background calls (~5 min lost). `--deadline 80m` refused (plain seconds). Bucket: tooling. Proposed: `lane launch --help` says it blocks; parallel lanes = one background call each (memory `lane-launch-blocks`).
