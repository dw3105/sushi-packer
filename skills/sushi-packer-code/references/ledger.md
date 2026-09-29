# Ledger

| Version | Date | Change |
|---|---|---|
| v0.1 | 2026-09-26 | First cut: SP-01..SP-09 from build plan step-0-initialize-local-peaceful-hartmanis. |
| v0.2 | 2026-09-26 | SP-02: lanes offline mock-based Lua tests only; headless Factorio only integrator merge/release; runner refuses headless under `LANE_RUN_ID` (author ask after lanes stalled on 10-26 s engine boots). |
| v0.3 | 2026-09-27 | SP-10: probe files out of index, run with temporary index entry, keep `Tests:` line in filtered output (FRC-0006). |
| v0.4 | 2026-09-28 | SP-10: long probes report via `log()`, print progress < 15 s apart (FRC-0011, author approved). |
| v0.5 | 2026-09-28 | SP-02: lane task checks may run lane's own new offline test file whole (`codex-tasks:CX-31`, FRC-0015; author adopted all 4 v9 reflection rules). |
| v0.6 | 2026-09-29 | SP-11..SP-16 from FRC-0021..0026 (author approved all 6); SP-10 output timeout 180 s. |
