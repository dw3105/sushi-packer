# Decisions

Author answers and integrator defaults. Author may overturn any default; then `docs/REQUIREMENTS.md` or this file changes first, code second.

| Id | Decision | By, date |
|---|---|---|
| Q-8 | 4 container variants per tier `sushi-packer-<tier>-<north\|east\|south\|west>`, swapped by script. Mechanics D-4. | author, 2026-09-26 |
| Q-9 | LED off (sprite + light `visible=false`) while circuit disables box. | author, 2026-09-26 |
| T-1 | Two builds, one source: 2.0 → `0.1.x`, 2.1 → `0.2.x`. Same mechanics on both; 2.1 native container rotation not used. Only API present in both. | author, 2026-09-26 |
| TST | FactorioTest mod 3.0.1 (2.0, sha1 `01bb91e6d0abf084e2232df62146d8efb4ad1119`) and 3.1.0 (2.1, sha1 `aea78793855e9058d2b831fbc5e43939528f73d3`); author downloads. Offline tests `lua5.2` only. | author, 2026-09-26 |
| PUB | Publish = operator command blocks (laptop pushes) + both zips in `~/share/sushi-packer/`. | author, 2026-09-26 |
| Q-1 | Recipe per tier: 1 `steel-chest` + 4 matching belt + 5 circuits (yellow `electronic-circuit`, red `advanced-circuit`, blue `processing-unit`, turbo `processing-unit`). | default, 2026-09-26 |
| Q-2 | All tiers same health (350, steel chest) and 48 slots. | default |
| Q-3 | Timeout clock from first item arrival of partial. | default (proposed in reqs) |
| Q-4 | Circuit disabled = input and output stop. | default (current spec) |
| Q-5 | Flush signal flushes partials only, not pass-through hold. | default (proposed in reqs) |
| Q-6 | Reference machine `legalcopilot-dev` (4 vCPU GCP VM); budget 200 boxes ≤ 1 ms/tick script time. | default |
| Q-7 | Mod name and prefix `sushi-packer`. | default |
| D-1 | Stored items live in container inventory; engine counters = logic truth. Reconcile on `on_gui_closed` of box + every 60 ticks: deficit removed newest partial first, then back of ready queue; surplus adopted as left-lane arrival. | integrator |
| D-2 | Map setting `sushi-packer-flush-timeout`, int seconds, default 0 (off), range 0..3600. | integrator |
| D-3 | Pass-through hold items live in `storage`, not inventory; returned on mine, spilled on death. | integrator |
| D-4 | Placer: item `place_result` = `sushi-packer-<tier>-placer` (`simple-entity-with-owner`, Sprite4Way). Build events swap placer → variant by `direction`. `on_player_setup_blueprint` rewrites variants → placer + direction + tags. Rotate placed box via custom inputs linked to `rotate` / `reverse-rotate` on `player.selected`. Swap copies inventory + wires, destroys old, creates new, rekeys storage. | integrator (FND-0002) |
