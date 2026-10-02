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
| FND-0033 | 2026-09-30 | dev-vm | Library blueprint "select new contents" crashed (`LuaRecord doesn't contain key valid_for_read`, shipped since blueprint support) | fixed v1.13 (author in-game check) |
| FND-0034 | 2026-09-30 | dev-vm | Mining Drones + Arig: load refused, hyper box mask nil vs turbo `mining_drone` layer (shipped since v9 extras) | fixed v1.14 (`them8` regression set) |
| FND-0031 | 2026-09-30 | dev-vm | Residual bench gap v1.12 vs v1.10 | OPEN, third deferral (RULINGS 2026-09-29: box not free); cost to meet: quiet dev-vm ~1 h (A/A band + >= 6 alternated pairs, SP-20) |
| FRC-0033..0038 | 2026-09-30 | dev-vm | v12/v13 session reflection; rules SP-22..SP-24 + SP-21 text (author) | applied (skill v0.8) |
| FND-0035..0047 | 2026-10-01 | dev-vm | v1.14..v1.16 findings (player UPS report, arms box, engine output); not cited here at their close-outs, text in `docs/FINDINGS.md` | closed with v1.15 / v1.16 (catch-up row 2026-10-02) |
| FND-0048..0051 | 2026-10-02 | dev-vm | Belt body probes; one bench row slower (cause not found); push onto belt running across; load crash `invalid key to 'next'` | shipped v1.17 / fixed v1.18 / fixed v1.19; FND-0049 cause OPEN, accepted by author (V17-11) |
| FND-0052 | 2026-10-02 | dev-vm | Items pile up with many kinds / qualities; window without quality; blueprint shows bare belt | fixed v1.20; hood look in blueprint preview and ghost never seen by anyone: OPEN, second deferral; cost to meet: author, 2 min in game |
| FND-0053 | 2026-10-02 | dev-vm | Belt behind packer jerks: in hands wait to fill, store smaller than kinds, out hands short on 270/s | fixed v1.21 (public, tag `0d97c55`); known by author's picks: fast mod belt + more than 24 kinds per lane still backs up (V21-4), 1 small stack in 150 on fully stacked 270/s belt (V21-3) |
| FRC-0048..0063 | 2026-10-02 | dev-vm | v1.17..v1.21 session reflection | recorded; rule changes proposed in FRC-0062, FRC-0063 wait on author |
| close 2026-10-02 | 2026-10-02 | dev-vm | Open at close: v1.21 not seen in real game (first deferral); `make skill-lint` red, REQUIREMENTS v14 text, dead code `core.lua` / `belt_io.pull` (second deferral each, costs in `docs/STEPS.md`) | OPEN |

