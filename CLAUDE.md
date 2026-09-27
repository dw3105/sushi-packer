# sushi-packer — repository facts

Factorio mod, two builds from one source: 2.0 (`0.1.x`) and 2.1 (`0.2.x`), hard dep `space-age`. 1x1 box sits inline on belt, takes mixed items per lane, releases full stacks as stacked belt items. Register: **caveman full**.

## Read first, every session

1. `docs/REQUIREMENTS.md` — contract. Outranks every other doc. Only author amends it.
2. Repo skill `sushi-packer-code` (`skills/sushi-packer-code/SKILL.md`).
3. `docs/STEPS.md`, `docs/DECISIONS.md`, `docs/CONTRACT.md`, `docs/FINDINGS.md`.
4. Shared skills leaned on: `codex-tasks`, `proving`, `evidence-and-claims`, `shared-host`, `session-lifecycle`, `operator-blocks`, `shipping-and-integration`, `talking-to-operator`.

## Machine map

| Machine | Who | May |
|---|---|---|
| `dev-vm` (this VM, 4 vCPU, 15 GB, shared) | agents, codex lanes | edit, single tests under gateslot, commit in worktree. Never `git push`, never `make release`/`install` in `~/skills` unasked |
| operator laptop | operator | `gh repo create`, `git push`, play-test in real game, mod portal downloads (login) |

Headless Factorio: `~/factorio-2.0/factorio` (2.0.77), `~/factorio-2.1/factorio` (2.1.20). Graphics source: `~/share/sushi-packer/mod-graphics/` (already copied to `graphics/`, never redraw).

## Build

- `make test-one T='tests/offline/<file>.lua::<describe> > <it>'` — one offline test, mocks, ms. Lanes use only this.
- `make test-one FV=<2.0|2.1> T='tests/game/<file>.lua::<describe> > <it>'` — one headless test. Integrator only (refused under `LANE_RUN_ID`).
- `make test FV=2.0` / `FV=2.1` — FULL suite incl. headless, gateslot `sushi-packer/heavy`. Integrator only, at merge and release.
- `make zip` — two zips in `build/`. `make load-check FV=<v>` — headless load, zero errors.
- `make bench FV=2.0` — R-1 measure.

## `~/sushi-packer-mod` is merge-only

Commit in worktree, then `git merge --ff-only` into main checkout (after S0).

## Hard rules

- Only gateslot labels `sushi-packer/heavy` and `sushi-packer/agent`.
- Frozen seams (`docs/CONTRACT.md`, `scripts/names.lua`, guard tests) change only by integrator decision recorded in `docs/DECISIONS.md`.
- API only present in both 2.0 and 2.1. Docs pinned: https://lua-api.factorio.com/2.0.72/ ; cross-check `/latest/` (2.1).
- Never ship file copied from base game. Belt visuals come from game's own sprites.
- Never commit `build/`, `*.zip`, `node_modules/`, `.env`.
