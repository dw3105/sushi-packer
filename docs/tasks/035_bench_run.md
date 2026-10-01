# 035 — bench-run: run.sh takes tier / mod set / flow, parser prints per box + per item, `make bench-all`

Repo `sushi-packer-mod`, lane worktree `~/wt-sushi-packer-035_bench_run`, branch `lane/035_bench_run`, base tag `lanes-base-v14`, merge target `int/v14`. Host `dev-vm`.

Lanes 034 (owns `tests/game/bench_builder.lua`, `tools/bench/mod/*`) and 036 (owns `scripts/tick.lua`, `scripts/belt_io.lua`) run beside you. No shared file. Seam = `docs/CONTRACT.md` section "Bench seam (v14)": setting names, counter log line, result line. Read it first, it is law.

## You have about 40 minutes — do NOT stop early

Do not stop until every item in "What to build" is done and its checks pass.

## What is true

**PRESERVE:** every file outside "Files this lane owns" byte-identical to `lanes-base-v14`. `tools/bench/run.sh <FV>` with no flags keeps today's behaviour: 200 boxes, 3600 ticks, yellow, flow single, no mod set, and its result line still starts `bench FV=<fv> boxes=<n> ticks=<n> script_ms_avg=<f> whole_ms_avg=<f>` with same numbers as today's parser gives. `make bench FV=2.0` keeps working. `Makefile` line 45 (`test-modsets`, `bench_only` filter) untouched.

- You cannot run Factorio (`LANE_RUN_ID` set; forbidden anyway). Real-engine samples are in repo: `tests/offline/fixtures/bench/benchmark.log` (real `--benchmark-verbose all` output: 5 tick rows `t0`..`t4`, summary `avg: 3.534 ms`; columns `wholeUpdate` index 2, `scriptUpdate` index 42; values = nanoseconds) and `tests/offline/fixtures/bench/factorio-current.log` (3 counter lines, ticks 600 / 1200 / 1800, `items_in` 22500 / 45000 / 67500). For boxes 200, ticks 5 today's parser logic gives `script_ms_avg=2.182 whole_ms_avg=3.534`.
- `tools/bench/run.sh` today: args lines 3-16 (`--boxes`, `--ticks`, unknown -> exit 2); stage line 22 `STAGE_DIR=$OUT "$ROOT/tools/stage.sh" "$FV" test`; bench mod copied lines 23-31; lines 32-38 OVERWRITE `mod-list.json` with built-ins + `sushi-packer` + `sushi-packer-bench`; settings line 45 `npx fmtk settings set startup sushi-packer-bench-boxes "$BOXES" --modsPath "$OUT/mods"` (run with cwd `$FT`); create + benchmark lines 46-47; inline python parser lines 48-end prints result line.
- `tools/stage.sh` reads env `MODSET`: hard-links that set's mod zips from `~/.cache/sushi-packer-mods/<FV>` into `$OUT/mods`, writes `$OUT/mods/.modset` (names), `$OUT/mods/.builtin_off` when set has `builtin_off`, generated mod `sushi-packer-test-settings` (startup overrides), and writes `mod-list.json`: built-ins (disabled when `.builtin_off`), `sushi-packer`, `sushi-packer-test-env` (test mode), names from `.modset`. Zips must be fetched before: `tools/fetch_mods.py fetch <FV> <MODSET>` (network; never run it, Makefile does).
- `tools/modsets.json`: keys not starting `_` = sets; each has `fv` list. Tier keys: `scripts/names.lua` `N.TIERS` (yellow, red, blue, turbo) + `N.EXTRA` row `key`s.
- Factorio writes its log to `$OUT/write/factorio-current.log`; after benchmark run that file holds only benchmark run lines. Bench mod (lane 034) logs every 600 ticks: `sushi-packer-bench counters tick=<n> visits=<n> reads=<n> pulls=<n> pushes=<n> items_in=<n> items_out=<n>` (line has Factorio prefix before it, see fixture).
- `Makefile:49-50`: `bench:` = `$(GATE) tools/bench/run.sh $(FV)`. `GATE` line 6. Pattern for mod-set fetch: line 21 / 42 `$(if $(MODSET),tools/fetch_mods.py fetch $(FV) $(MODSET) &&)`.
- Offline runner `tests/offline/run.lua`: `describe`, `it`, `eq`, `ok`; lua5.2; `io.popen` / `os.execute` available. Text-check pattern: `tests/offline/test_stage.lua:1-10`.

## Explain very simply

Bench script can only time 200 yellow boxes in plain game. Teach it: which tier, which mod set, which feed. Make it print cost per box and per item moved. Add one make target that runs five standing rows.

## What to build

### 1. `tools/bench/parse.py` (new) — parser moved out of run.sh

`python3 tools/bench/parse.py <benchmark.log> <factorio-current.log> <fv> <boxes> <ticks> <tier> <modset|none> <flow>` prints exactly one line:

`bench FV=<fv> boxes=<n> ticks=<n> script_ms_avg=<%.3f> whole_ms_avg=<%.3f> tier=<tier> modset=<modset> flow=<flow> ms_per_box=<%.5f> items_in=<int> us_per_item=<%.2f|na> load1=<%.2f>`

- First five fields: today's logic moved verbatim (header find, row filter, tick-count check, unit cross-check against summary, same error texts, same exit status on failure).
- `ms_per_box` = script_ms_avg / boxes.
- Counter lines: every line containing `sushi-packer-bench counters tick=`. Fewer than 2 lines or log file missing -> `items_in=0 us_per_item=na`. Else `items_in` = last `items_in` minus first; tick span = last `tick` minus first; `us_per_item` = script_ms_avg * 1000 / (items_in / tick span); `items_in` 0 -> `na`.
- `load1` = env `BENCH_LOAD1` when set, else first field of `/proc/loadavg`.

### 2. `tools/bench/run.sh`

- Flags: `--boxes N`, `--ticks T` (as today), `--tier KEY` (default `yellow`), `--modset SET` (default none), `--flow single|stacks` (default `single`), `--seed N` (default 1), `--dry-run`. Missing value or unknown flag -> exit 2 with message on stderr.
- Validation BEFORE any staging or Factorio call: flow not `single` / `stacks` -> exit 2; modset not a key of `tools/modsets.json` or FV not in its `fv` -> exit 2; seed not non-negative integer -> exit 2; tier with characters outside `[a-z0-9-]` -> exit 2.
- `--dry-run`: after validation print `bench-dry FV=<fv> boxes=<n> ticks=<n> tier=<tier> modset=<set|none> flow=<flow> seed=<n>` and exit 0. Nothing staged, nothing run.
- Stage with mod set: `MODSET=<set> STAGE_DIR=$OUT tools/stage.sh <FV> test` (empty MODSET when none).
- `mod-list.json`: do NOT overwrite. Read file stage wrote; keep every entry and its `enabled` value; add `{"name": "sushi-packer-bench", "enabled": true}`; set `sushi-packer-test-env` and `factorio-test` entries to `enabled: false` (bench runs player's game, not test env). Put this in `tools/bench/modlist.py <mods dir>` (new) so test can call it.
- Settings: `sushi-packer-bench-boxes`, `sushi-packer-bench-tier`, `sushi-packer-bench-flow`, `sushi-packer-bench-seed`, each by `npx fmtk settings set startup <name> <value> --modsPath "$OUT/mods"` as line 45 does.
- After benchmark: `python3 tools/bench/parse.py "$LOG" "$OUT/write/factorio-current.log" "$FV" "$BOXES" "$TICKS" "$TIER" "<set|none>" "$FLOW"`.

### 3. `Makefile`

- `bench`: vars `TIER`, `MODSET`, `FLOW`, `BOXES`, `TICKS`, `SEED`, each passed only when set; mod-set fetch prefix as line 21; still under `$(GATE)`. Help text: `## Bench one row: FV, TIER=, MODSET=, FLOW=single|stacks, BOXES=, TICKS=, SEED=`.
- `bench-all` (add to `.PHONY`): five rows, one after another, each own `$(GATE)` call, all `--flow stacks --boxes 200`: tiers `yellow`, `red`, `blue`, `turbo`, then fastest mod tier: FV 2.0 -> `--tier ub-ultimate --modset ubsa`, FV 2.1 -> `--tier kr-superior --modset k2so` (fetch that set first). Help text: `## Standing bench: 200 boxes x yellow, red, blue, turbo + fastest mod tier, flow stacks. Integrator only`.

### 4. Tests first — new `tests/offline/test_bench_run.lua`, describe `bench run`; each seen RED before code

Helper `sh(cmd) -> output, exit_code` via `io.popen(cmd .. ' 2>&1; echo "EXIT=$?"')`.

- `bench run > parser prints old fields then new` — `BENCH_LOAD1=1.50 python3 tools/bench/parse.py tests/offline/fixtures/bench/benchmark.log tests/offline/fixtures/bench/factorio-current.log 2.0 200 5 turbo ubsa stacks` -> output equals `bench FV=2.0 boxes=200 ticks=5 script_ms_avg=2.182 whole_ms_avg=3.534 tier=turbo modset=ubsa flow=stacks ms_per_box=0.01091 items_in=45000 us_per_item=58.19 load1=1.50` (unrounded script average 2.1819478 ms: 2.1819478 / 200 = 0.0109097; 2181.9478 / (45000 / 1200) = 58.185). RED at base.
- `bench run > parser without counter lines says na` — second arg = path that does not exist -> `items_in=0 us_per_item=na`, exit 0. RED at base.
- `bench run > parser rejects wrong tick count` — ticks arg 6 -> exit not 0, text `expected 6 ordered tick rows`. RED at base.
- `bench run > dry run prints resolved row` — `tools/bench/run.sh 2.0 --tier ub-ultimate --modset ubsa --flow stacks --boxes 5 --seed 3 --dry-run` -> `bench-dry FV=2.0 boxes=5 ticks=3600 tier=ub-ultimate modset=ubsa flow=stacks seed=3`, exit 0. RED at base.
- `bench run > defaults` — `tools/bench/run.sh 2.0 --dry-run` -> `bench-dry FV=2.0 boxes=200 ticks=3600 tier=yellow modset=none flow=single seed=1`. RED at base.
- `bench run > bad args exit 2` — each of `--flow dice`, `--modset nope`, `--modset ubsa` on FV 2.1 (set is 2.0 only), `--seed x`, `--tier 'a b'`, `--tier` (no value), `--what` -> exit 2, with `--dry-run` appended where a value is present. RED at base (some).
- `bench run > modlist keeps stage entries adds bench` — temp dir (`os.tmpname` based) with `mod-list.json` = `{"mods":[{"name":"base","enabled":true},{"name":"space-age","enabled":false},{"name":"sushi-packer","enabled":true},{"name":"sushi-packer-test-env","enabled":true},{"name":"AdvancedBeltsUpdated","enabled":true}]}`; run `python3 tools/bench/modlist.py <dir>`; result: `space-age` still false, `AdvancedBeltsUpdated` true, `sushi-packer-test-env` false, `sushi-packer-bench` true, `base` true. RED at base.
- `bench run > makefile has bench-all rows` — `Makefile` text has target `bench-all`, tiers yellow / red / blue / turbo, `ub-ultimate` with `ubsa`, `kr-superior` with `k2so`, `--flow stacks`; `make -n bench-all FV=2.0` output names `ub-ultimate` and not `kr-superior`; `FV=2.1` the reverse. (`make -n` runs nothing.) RED at base.
- `bench run > run.sh no longer overwrites mod list` — `tools/bench/run.sh` text has no `'sushi-packer','sushi-packer-bench'` literal and calls `tools/bench/modlist.py` and `tools/bench/parse.py`. RED at base.

### Mutation

In `parse.py` make `ms_per_box` = script_ms_avg (no divide) -> `bench run > parser prints old fields then new` red; restore -> green. Never commit mutated state.

## Test rule — read twice

**Lanes run single offline Lua tests only.** FORBIDDEN: any full suite of any kind — never `make test`, never `make test-modsets`, never `make load-check`, never `make bench`, never `make bench-all` (only `make -n bench-all`), never `make zip`, never `--full`, never a dir-wide run. Never start Factorio: never run `tools/bench/run.sh` without `--dry-run`, never `tools/stage.sh`, never `tools/fetch_mods.py`. One test per call:

```
make test-one T='tests/offline/test_bench_run.lua::bench run > defaults'
```

Only whole-file run allowed: your own new file, `lua5.2 tests/offline/run.lua tests/offline/test_bench_run.lua`.

**Never edit** anything outside "Files this lane owns": not `docs/*` (this file included), `tests/offline/fixtures/*`, `tools/stage.sh`, `tools/run_tests.sh`, `tools/modsets.json`, `tools/bench/mod/*`, `scripts/*`, `tests/game/*`, any existing `tests/offline/*`. Never weaken, skip or delete an existing test. Never write under `~/share`.

## Commit, THEN check

Commit tests first (red), then code, as separate commits. Run checks below as very LAST action.

## Final report

Paste: red output of each new test at base, green after, mutation red + restore green, `git log --oneline lanes-base-v14..HEAD`.

## What done mean

```checks
{"name": "lane035-scope", "command": "git diff --name-only lanes-base-v14 HEAD | grep -Ev '^(tools/bench/run\\.sh|tools/bench/parse\\.py|tools/bench/modlist\\.py|Makefile|tests/offline/test_bench_run\\.lua)$' | ( ! grep . ) && echo lane035-scope-ok", "expect_exit": 0, "expect_regex": "lane035-scope-ok", "timeout_s": 60}
{"name": "lane035-tests", "command": "( for t in 'parser prints old fields then new' 'parser without counter lines says na' 'parser rejects wrong tick count' 'dry run prints resolved row' 'defaults' 'bad args exit 2' 'modlist keeps stage entries adds bench' 'makefile has bench-all rows' 'run.sh no longer overwrites mod list'; do tools/run_tests.sh 2.0 \"tests/offline/test_bench_run.lua::bench run > $t\" || exit 1; done; lua5.2 tests/offline/run.lua tests/offline/test_bench_run.lua && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > contract frozen' && tools/run_tests.sh 2.0 'tests/offline/test_guard.lua::guard > names frozen' ) && echo lane035-tests-ok", "expect_exit": 0, "expect_regex": "lane035-tests-ok", "timeout_s": 300}
{"name": "lane035-modsets-line", "command": "git diff lanes-base-v14 HEAD -- Makefile | grep -c 'bench_only' | grep -qx 0 && sh -n tools/bench/run.sh && python3 -m py_compile tools/bench/parse.py tools/bench/modlist.py && echo lane035-syntax-ok", "expect_exit": 0, "expect_regex": "lane035-syntax-ok", "timeout_s": 60}
```

## Files this lane owns

tools/bench/run.sh, tools/bench/parse.py (new), tools/bench/modlist.py (new), Makefile (targets `bench`, `bench-all`, `.PHONY` only), tests/offline/test_bench_run.lua (new). Never touch anything else.

Re-cut because: none

# bound: 2400s
