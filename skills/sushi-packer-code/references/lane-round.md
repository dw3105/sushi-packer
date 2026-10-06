# Lane round, in order

Integrator commands for one round. `L=~/skills/tools/lane.py`. `<n>` = round name (`v24`, `retro`).

1. Int worktree from `main`: `git worktree add ~/wt-sushi-packer-int-<n> -b int/<n> main`.
2. Claim number + task file: `python3 $L --repo ~/wt-sushi-packer-int-<n> cut "<title>"` writes `docs/tasks/<NNN>_<slug>.md` from template and a `CLAIMED_NUMBERS.md` row; makes no worktree. Replace template text; last task file in `docs/tasks/` is the model (sections, test rule, checks, owned files, `# bound:`, `Reviewer ask:`).
3. Keep-green list for files no lane owns: `lua5.2 tests/offline/run.lua <file>` per file, `PASS` lines -> `tests/offline/fixtures/<n>_keep_green.txt` as `<file>::<name>`; run each once with `tools/run_tests.sh 2.0 "<line>"`, all green.
4. Checks block: one `json.dumps` per check (`codex-tasks:CX-40`); keep a copy as `.jsonl` in scratchpad.
5. Commit S0 on int branch, tag `lanes-base-<n>`, lane worktree per task: `git worktree add ~/wt-sushi-packer-<NNN>_<slug> -b lane/<NNN>_<slug> lanes-base-<n>`.
6. Run every check at base in each lane worktree with scratch `HOME`; write colours into task (`Owner base colours ...`), commit on int.
7. Launch, one background call per lane: `python3 $L --repo ~/wt-sushi-packer-int-<n> launch --deadline <s> <lane worktree> <int worktree>/docs/tasks/<file>.md`. Deadline must sit inside 0.5x..2x of lane bound or launch refuses.
8. Watch: `python3 $L --repo <int worktree> watch <NNN>_<slug> --follow`, filter `VERDICT|WATCH-EXPIRY|RETRIED`.
9. On `VERDICT ... PASS`: `git status`, `git log lanes-base-<n>..HEAD`, diff; checks again with scratch `HOME`; new tests red at test-only commit (detached worktree); plant task mutations, see red, restore.
10. Merge on int: `git merge --no-ff lane/<NNN>_<slug> -m "S1: merge lane/<NNN>_<slug> (...)"`.
11. After all lanes: integrator gates (`make test FV=2.0`, `FV=2.1`, `make test-modsets`, `make zip`, `make load-check`) under gateslot, then `git -C ~/sushi-packer-mod merge --ff-only int/<n>`.
