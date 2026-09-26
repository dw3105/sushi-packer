# Steps

Contract: `docs/REQUIREMENTS.md`. Build plan: `~/.claude/plans/step-0-initialize-local-peaceful-hartmanis.md`.

| Step | What | Done when |
|---|---|---|
| 0 | repo, estate wiring, rules, skill | `.agent-lane.toml` present, hooks shims, skill live |
| S0 | headless 2.0.77 + 2.1.20, FactorioTest, skeleton, frozen seams, probes, guards | probe red→green on both versions via `make test-one`; tag `lanes-base` |
| W1 | lanes A core, B tiers, C lifecycle, D belt I/O, E GUI, F circuit, H bench | each lane checks PASS, merged into `int/v1` |
| W2 | lane G glue + end-to-end | checks PASS, merged into `int/v1` |
| INT | `make test FV=2.0`, `FV=2.1` full until green; bench; zips; REQ-STATUS | both full suites exit 0 on `main` |
| PUB | operator blocks + zips in `~/share/sushi-packer/` | origin SHA = local `main` |

Headless installed 2026-09-26 on `legalcopilot-dev`: `~/factorio-2.0/factorio` `Version: 2.0.77 (build 84539, linux64, headless)` (tar.xz 57,225,308 B); `~/factorio-2.1/factorio` `Version: 2.1.20 (build 87512, linux64, headless)` (tar.xz 60,993,508 B). Both `data/` hold `space-age`, `quality`, `elevated-rails`; 2.1 also `recycler`.
Root commit 2026-09-26: made in main checkout with `git -c core.hooksPath=/dev/null commit` (a worktree needs a first commit); released `pre-commit` body run by hand on staged tree first, exit 0. Every later commit goes through worktree + hooks.

S0 proof, 2026-09-26, `legalcopilot-dev`: FactorioTest mod 3.0.1 (2.0) / 3.1.0 (2.1), sha1 match portal; CLI 3.6.0 in `tools/ft/` for both (FND-0003). Probes + guards green on both versions via `tools/run_tests.sh`: 6 probes, 2 game guards, 2 offline guards. Red seen: probe `front-most item has highest position` failed on 2.0 (real finding FND-0004, rewritten to lowest), planted wrong direction failed on 2.1, planted arity breach failed offline guard, planted bad prototype failed load check. One in-game test: 10-26 s wall, 347-456 MB peak RSS → heavy weight 768 MiB / 1 core, max 3.

Integration, 2026-09-26, `legalcopilot-dev`: lanes 001-011 merged into `int/v1` after integrator review (REV). SP-02 v0.2 mid-run (author): lanes offline mock tests only, headless only at integrator merge/release; lanes 003-007 stopped, committed work merged. First full suite 2.0: headless crashed (lifecycle test faked `core.new_box`, live tick read it), then 16 reds, all test defects (require in before_each, timing, blocked-lane fill, player reach, bench 1x2 loader) - fixed, both suites green. R-1 bench 20.536 ms -> PERF-1 lane 010 -> 5.440 -> PERF-2 lane 011 -> 3.318 / 3.258 ms (load avg ~10). Integrator fixes with red first: belt cache per-side rescan clock, clone clears core index. R-1 amended by author to 5 ms on this VM (v4). Final: `full-2.0-ok`, `full-2.1-ok` (77 offline + 88 game each), both zips load headless.

v1.1 finalize, 2026-09-26, `legalcopilot-dev`: author answers (recipe B chained, own tech per tier ×1.5, no stack gate, polish all) → REQUIREMENTS v5 U-1..U-6. S1 integrator: upgrade probe (FND-0006), data dump both builds identical (FND-0007), offline data fixture, frozen names/contract. Lanes 012 data, 013 upgrade, 014 polish (offline only) merged after review; integrator fixes red first: hand mine of marked box returns hold, tech count ceil. Full suites: 2.0 1 red, 2.1 1 red (test-only, FND-0008) → fixed → `full-2.0-ok`, `full-2.1-ok` (106 offline + 92 game each). Bench `script_ms_avg=1.957`. Zips 0.1.1 / 0.2.1 load headless.
