# REQUIREMENTS v17 — proposed wording (author decides)

`docs/REQUIREMENTS.md` is still v14 text: only author amends it. v1.17 follows author decisions of grill 2026-10-02 (V17-1, V17-2, V17-4) and integrator decisions V17-3, V17-5..10. Read after `docs/REQUIREMENTS-v16-PROPOSED.md`: rows below replace or add to it.

| ID | v1.17 does | Proposed text |
|---|---|---|
| E-2 | Packer = belt-kind entity ("belt body", copy of tier's belt, kept shut by script) plus hidden parts on same tile: per lane 12-slot lane store, in arms (belt behind -> store), 2 mop arms (belt body -> store), 8 out arms; hood picture entity. No chest, no 48-slot inventory. | Built as 1x1 belt-kind entity kept shut (nothing rides onto it from belts) plus hidden parts on same tile: per lane one 12-slot lane store, hidden inserters in and out, hood. |
| E-7, Q-8 | Game rotates packer like belt (R, reverse R, flip); hidden parts follow. No 4 direction copies in play; old chest copies exist only so old saves and blueprints load, and are swapped when met. | Rotation: by game, as belt. Drop "4 container variants". |
| E-10 (was dropped) | Belt pointing at packer's flank puts nothing in. | New: "No side-loading into packer." |
| E-3 | Front belt running same way: as before. Front belt running across: stacks go onto its near lane, both packer lanes (lanes merge there, as with belt side-loading). Belt facing packer, underground / splitter across: no output. | Add: "Belt running across in front gets both lanes on its near lane, stacked." |
| D-1, V16-5 | Outside inserter drops onto belt body; that item is packed on the lane it landed on. Outside inserter takes only items lying on belt body, never stored items. Player can not put items in or take items out by hand in the window; mining returns everything. | Replace D-1: "Inserters interact as with a belt. Stored items leave only by front, or when packer is mined." |
| N-1, N-2, N-3 | Wire connects to belt body. Enable condition and read contents are belt's own settings (copy-paste, blueprint, upgrade carry them); shown in packer window. Read contents: all stored items of both lanes plus items lying on belt body, hold mode, on by default, can be switched off. Enable condition is still checked by script at each look (up to 30 ticks late). | N-2: "Read contents (on by default, switchable): all items inside packer." N-3 unchanged in effect. |
| N-4 | Flush signal unchanged (packer extra, in window). | unchanged |
| S-3, E-6 | Own window on click (no chest window): lanes (look only), items to skip, flush timeout, circuit section. Not opened while cursor holds an item. | Window: own packer window; contents shown, not taken by hand. |
| U-3 | Upgrade planner chain runs over belt bodies; settings, stored items, wires kept; circuit settings carried by game. | unchanged in effect |
| E-9 | Unchanged: packer item placed over belt replaces belt; belt never replaces packer. | unchanged |
| S-4 | Blueprint holds belt body with tags; ghost shows plain belt of tier until built. Old blueprints (chest copies) build belt bodies. | Add note on ghost look. |
| old saves | Packers of saves up to v1.16 are swapped to belt body at load: items (extra ones in hidden spare stores that empty themselves), settings, player wires kept; read contents on. | Add migration rule. |
| R-1 | Speed vs v1.16: see FND-0049 (measured pairs). | bar: author |
