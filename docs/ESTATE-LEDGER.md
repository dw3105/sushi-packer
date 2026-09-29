# Estate ledger (sushi-packer)

Cross-repo citation of findings raised in this repo (session-lifecycle CL-07). One row per finding; full text in `docs/FINDINGS.md`, reflection in `docs/FRICTION.md`. Author 2026-09-29: this file is the estate ledger for this repo.

| Finding | Date | Host | One line | Status |
|---|---|---|---|---|
| FND-0025 | 2026-09-29 | dev-vm | Stacked belt items work with `space-age` mod off; script stack size ignores force research | closed (T-1 v10) |
| FND-0026 | 2026-09-29 | dev-vm | No-SA game: v1.10 refused to load (hard `space-age` dependency) | fixed v1.11 |
| FND-0027 | 2026-09-29 | dev-vm | Advanced Belts 2.0 + Space Age: shipped 0.1.10 crashed on load (row name clash) | fixed v1.11 (owner gate) |
| FND-0028 | 2026-09-29 | dev-vm | v10 row names read from real SE / Advanced Belts zips | closed |
| FND-0029 | 2026-09-29 | dev-vm | SE game: aai-containers shrinks container box, upgrade chain refused | fixed v1.11 |
| FND-0030 | 2026-09-29 | dev-vm | Blue box 200 / 225 per lane (shipped since v1.x); first report overstated yellow/red (rig) | fixed v1.11 (V10-7) |
| FND-0031 | 2026-09-29 | dev-vm | v10 bench slower than v1.10 on yellow boxes (V10-7 cost); v11: cause proven + fixed (window > 0.0625), residual v1.12 vs v1.10 x1.09..x1.23 at load 4-6 with no code cause | PARTLY FIXED v1.12; residual OPEN, second deferral (V11-12) |
| FND-0032 | 2026-09-29 | dev-vm | SE space belt / splitter / tech names same in SE 0.7.57 (2.0) + 0.7.62 (2.1); SE German names; icon median 215 | closed (v1.12 row) |
| FRC-0027..0032 | 2026-09-29 | dev-vm | v11 session reflection; rules SP-17..SP-21 adopted (author) | applied (skill v0.7) |
| FRC-0021..0026 | 2026-09-29 | dev-vm | Session reflection; rules SP-11..SP-16 adopted (author) | applied (skill v0.6) |
