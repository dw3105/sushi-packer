# REQUIREMENTS v23 — proposed wording (author decides)

SUPERSEDED 2026-10-04: folded into `docs/REQUIREMENTS.md` v23 text, author approved ("approved"). Kept as history.

`docs/REQUIREMENTS.md` is v21 text; only author amends it. v1.23 follows author decisions of grill 2026-10-04 (V23-1..V23-7, `docs/DECISIONS.md`). Rows below replace or add.

| ID | v1.23 does | Proposed text |
|---|---|---|
| C-6 | Kind cap holds in both ways. | "Per lane, packer stops taking a kind (item + quality) once its lane store holds one full item stack of it (runtime `prototypes.item[name].stack_size`); resumes at half a stack. Items already in hidden inserter hands still arrive; a kind never uses more than 2 slots per lane. Holds in script way and engine way. Kind at cap and next on belt: belt behind waits." |
| G-10 (new) | Alt-mode arrow. | "Alt-mode shows one direction arrow per packer: game sprite `utility/fluid_indication_arrow`, drawn by script only in alt-mode, pointing to side items leave (G-4), turns with packer. No arrow outside alt-mode." |
| G-11 (new) | Alt-mode clean. | "Hidden parts of packer show nothing in alt-mode (`hide-alt-info`): no inserter arrows, no content icons. Packer's alt-mode = arrow (G-10) only." |
| V-8 | Arrow follows LED rules for life. | Add: "Same for alt-mode arrow (G-10)." |
