# REQUIREMENTS v16 — proposed wording (author decides)

`docs/REQUIREMENTS.md` is still v14 text: only author amends it. v1.16 follows author decisions of grill 2026-10-01 (bar x10; hoarding rule, exact tier cap, order of leaving may go) and integrator decisions V16-1..13. Read after `docs/REQUIREMENTS-v15-PROPOSED.md`: rows below replace or add to it.

| ID | v1.16 does | Proposed text |
|---|---|---|
| E-2 | Box = container + per lane: 12-slot lane store, hidden in arms (belt behind -> store), 8 hidden out arms (store -> front belt lane, full belt stacks). Script looks at a box once per 30 ticks. | Built as 1x1 container plus hidden parts on same tile: per lane one 12-slot lane store, hidden inserters taking from belt lane behind, hidden inserters putting belt stacks on same lane in front. Lua moves items only to flush leftovers, to join leftovers into a stack and for boxes on script path. |
| script path | Box with pass-through filters, and any box when game has no belt-stacking feature (no space-travel feature flag) while force belt stack is above 1, works as v1.15 (script pushes stacks; hoarding rule, order and exact tier cap as in v15 proposal). | Add section: "Script path: boxes with pass-through filters; games without belt stacking feature." |
| E-4, O-4 | No exact cap. Out arms of a tier move about 1.6 x its lane rate (measured: yellow box on turbo belt 12.0 stacks/s per lane, yellow lane 7.5). | Tier sets output speed: about 1.6 x own belt rate at most; front belt limits flow. |
| C-4, C-5, F-2 | No order: out arms take what store offers (last slot first). | Drop order rule for engine path. |
| C-6 | No hoarding rule on engine path: lane store may fill with one kind (12 slots). | Drop for engine path. |
| C-1, leftovers | Leftover below one belt stack waits in an out-arm hand (not shown in window; up to 8 hands x (stack - 1) items per lane). Leftovers of one kind split over hands are joined into a stack at a hand look (every 300 ticks; at next look while more full stacks wait). | Items below one belt stack wait inside box (hidden); they leave as full stack once enough arrive. |
| S-1 | Flush timer counts from hand look that first saw leftover: leaves between N and N + 5 s. Store leftovers as before. | "... is flushed N to N + 5 seconds after it started waiting." |
| F-1 | Partial stacks also leave when lane is jammed: store holds 16 belt stacks or more, or store unchanged with full stacks at three looks while front has room. | Add jam rule. |
| V-2..V-5 | LED counts items in arm hands, known at hand looks: up to 5 s late. Stopped box shows store state. | "LED may lag up to 5 seconds for items waiting in hidden inserters." |
| E-6 | Outside inserters aimed at box take items from lane stores (as v1.14 allowed for box; v1.15 did not). Items put in from outside: unchanged. | State it. |
| E-3 | Front belt presence asked once per 120 ticks while present: after front belt is rotated sideways box may feed it up to 2 s. | State it or ask for exact rule (costs script time). |
| E-5 | Mined / died / rotated / upgraded box returns items held by hidden inserters too (v1.15 lost them). | Unchanged meaning; now true. |
| R-1 | Bar of 2026-10-01 met (FND-0047). | Replace v14 R-1 by: script time at least x10 below v1.14 on every bench row with stacking feature; whole tick not above v1.15. Proof: noise check + 2 alternating rounds; more only when a row is nearer to bar than 2 x noise. |
