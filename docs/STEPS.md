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
