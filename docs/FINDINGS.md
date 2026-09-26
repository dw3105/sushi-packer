# Findings

Things found and not fixed here. Each row says where found, what breaks, what it looks like when it breaks.

Rules for rows:

- Id `FND-NNNN`, heading `## FND-NNNN - title`. Numbers never reused.
- Title states finding as raised, never current state; body records what closed.
- Append-only.
- Claim that something is absent or checked carries `Verified-by: \`<command>\`` in same row.

---

## FND-0001 - Newest FactorioTest mod (3.1.0) targets Factorio 2.1 only

Found 2026-09-26 on `legalcopilot-dev` while planning. Mod portal lists `factorio-test` 3.1.0 with `factorio_version` "2.1"; last 2.0 build is 3.0.1. Using 3.1.0 on 2.0.77 headless = mod refused at load. Closed by pinning 3.0.1 for 2.0 and 3.1.0 for 2.1 (`docs/DECISIONS.md`). Portal download needs login; author supplies zips.

Verified-by: `curl -s https://mods.factorio.com/api/mods/factorio-test | python3 -c "import sys,json;[print(r['version'],r['info_json']['factorio_version']) for r in json.load(sys.stdin)['releases']]"`

## FND-0002 - Rotated blueprint does not rotate a not-rotatable container

Found 2026-09-26 by web research (https://forums.factorio.com/127223): since 2.0.42 blueprint rotation leaves not-rotatable entities facing their stored direction. Per-direction container variants in a blueprint would build facing wrong way after rotating the blueprint. Closed by placer design (`docs/DECISIONS.md` D-4): blueprints store rotatable placer, not variant.
