# Sushi Packer — Requirements

Factorio mod. 1x1 belt-inline box. Takes mixed ("sushi") items off belt, holds them until one item type reaches full stack, then pushes that stack out as stacked belt items. Output = sorted, compressed runs of single item type.

Status: v4, 2026-09-26. Source: Q&A with author. v2 adds status LED (§12) and graphics spec (§13). v3 (author 2026-09-26): T-1 two builds 2.0 + 2.1; Q-8, Q-9 answered. v4 (author 2026-09-26): R-1 budget 5 ms on `dev-vm`; Q-6 answered. v5 (author 2026-09-26): chained recipes + tech rule (U-1, U-2, Q-1 answered), upgrade planner, weight, locale, tips, release files (U-3..U-6); no stack gate (O-3 unchanged). v6 (author play-test 2026-09-26): release at belt stack (C-2, O-5), vanilla-style names + own row (U-7), live Factoriopedia/tips scene (U-8), splitter-style quality filter (P-1), GUI sections (S-3, N-3, N-4), decon stops box (E-8), box placed over belt (E-9). v7 (author 2026-09-27): O-3 belt stack follows research up to engine max; E-10 added, then dropped same day. v8 (author 2026-09-28, plan approved): lanes own 24 slots each (L-2, L-3, F-1, F-3, F-4, V-4), one item stack per (item, quality, lane) (C-6). v9 (author 2026-09-28, plan approved; portal suggestion by Ziktofel): modded belt tiers §17 (M-1..M-9). v10 (author 2026-09-29, grill + plan approved; portal request by Gamer433): `space-age` optional (T-1, E-4, U-2, O-3), owner-gated rows + Advanced Belts 2.0 / Space Exploration tiers (M-1..M-5, M-8), one-quality picker (P-1), SE space placement (U-4). Decisions V10-1..V10-6. v11 (author 2026-09-29, grill; portal request by Gamer433): SE space tier as own-role root tier + separate SE chain (U-1, U-3, M-1, M-4, M-5, M-7, M-8), German locale (U-5). Decisions V11-1..V11-9. v14 (author 2026-10-01, grill + gate; portal report by Gamer433, FND-0035): R-1 rewritten as packers-minus-belts delta at full flow with v1.15 bar 50 % cut, R-3 standing bench. Decisions V14-1..V14-8. v21 (2026-10-02, on author's word "do all now"): text brought in line with public v1.21 from author decisions V14-9..V21-5 (`docs/DECISIONS.md`) and proposals `REQUIREMENTS-v15/16/17-PROPOSED.md`; rows changed carry "(v21 text)". "Box" and "packer" mean the same thing.

## 1. Target

| ID | Requirement |
|----|-------------|
| T-1 | Factorio 2.0 and 2.1: two builds from one source (2.0 → `0.1.x`, 2.1 → `0.2.x`), only API present in both. v10: `space-age` optional (`? space-age`). Belt stacking is an engine feature: stacked belt items work with the `space-age` mod off (FND-0025). Quality works with or without the `quality` mod (only `normal` without it). |
| T-2 | Multiplayer-safe, save/load-safe. All state in `storage`. No desync sources. |

## 2. Entity

| ID | Requirement |
|----|-------------|
| E-1 | 1x1 entity, rotated by game like a belt piece (R, reverse R, flip). Input side = back, output side = front. (v21 text) |
| E-2 | Built as 1x1 belt-kind entity ("belt body", copy of tier's belt) kept shut by script: nothing rides onto it from belts. Hidden parts on same tile: per lane one lane store (24 slots), hidden inserters taking from belt lane behind, hidden inserters putting belt stacks on same lane in front, hood picture. Lua moves items only to flush leftovers, to join leftovers into a stack, and on script way (E-11). No hidden loaders. (v21 text; v1.14: scripted chest, v1.15..v1.16: chest + hidden parts) |
| E-3 | Takes items from belt tile behind it (lane-preserving, see §4). Puts items onto belt tile in front. Front belt running across: both lanes go onto its near lane, stacked (as belt side-loading). Belt facing packer, underground or splitter across: no output. No belt in front → output stalls; input continues until lane store full (§5). Front belt presence is asked once per 120 ticks while present. (v21 text) |
| E-4 | Tier per belt: yellow, red, blue, turbo, plus modded tiers (§17). v10: turbo tier exists only when `turbo-transport-belt` and its tech exist (space-age on); top vanilla tier = turbo with space-age, blue without. Tier sets output speed: hidden out inserters of a tier move about 1.6 x own belt rate at most; front belt limits flow. Input is bounded by lane store space. (v21 text) Tier does NOT set belt stack size (see O-3). |
| E-5 | Mining entity returns stored items to player (spill on ground if inventory full), items held by hidden inserters too. Destroyed entity spills contents on ground. (v21 text) |
| E-6 | Own packer window on click (not opened while cursor holds an item): contents of both lane stores with quality, 12 slots per row; items to skip; flush timeout; circuit section. Contents are shown, not taken by hand; mining returns everything. Inserters beside packer interact as with a belt: what they drop on belt body is packed on the lane it landed on; they take only items lying on belt body, never stored items. (v21 text) |
| E-8 | Box marked for deconstruction stops: no input, no output, LED off. Cancel → resumes. |
| E-10 | v17 (author 2026-10-02, replaces "dropped" of 2026-09-27): belt pointing at packer's flank puts nothing in (no side-loading into packer). (v21 text) |
| E-9 | Box item placed over belt replaces that belt (belt + its items to player), like splitter. One way: belt never replaces placed box. |
| E-7 | Rotation by game, as belt (belt body). The 4 chest variants and the chest body of v1.1..v1.16 exist only so old saves and blueprints load; they are swapped to belt body when met (§18). (v21 text) |
| E-11 | Two ways of working. Engine way: hidden inserters take belt stacks out of lane store (normal). Script way: packers with items to skip (S-3), and every packer in a game without belt stacking feature (no space-travel feature flag) while force belt stack is above 1: hidden out inserters paused, Lua pushes stacks. Rules that differ are marked. (v21 text, V16-4, V16-10) |

## 3. Core behavior — accumulate and release

| ID | Requirement |
|----|-------------|
| C-1 | Buffer key = (item name, quality, lane). Each quality is separate kind. Same item on left and right lane = two separate buffers. Items of a kind below one belt stack ("leftover") wait inside packer (lane store or hidden inserter hand) and leave as full stack once enough arrive. (v21 text) |
| C-2 | Full stack = N = min(belt stack size (O-3), item prototype `stack_size`). With belt stack 4: 4 iron plates of one quality on one lane = full. Belt stack 1 (no research) → every item leaves at once, lane kept (pass-through look). Quality does not change N. |
| C-3 | When a kind reaches full stack in a lane store, that stack may leave on its own lane. (v21 text) |
| C-4 | Order of leaving. Engine way: none promised. Script way: kinds by time kind first entered lane store (tie: name, quality); full stacks of one kind leave together. (v21 text) |
| C-5 | Item arriving while its kind already has a full stack waiting adds to that kind. (v21 text) |
| C-6 | Script way only: per lane, packer stops taking a kind once it holds one full item stack of it (resumes at half a stack); items already in hidden inserter hands still arrive, a kind never uses more than 2 slots per lane. Engine way: no such rule, a lane store may fill with one kind. Runtime `prototypes.item[name].stack_size` followed. (v21 text) |

## 4. Lanes

| ID | Requirement |
|----|-------------|
| L-1 | Lane-preserving. Item picked from input left lane only ever leaves on output left lane; same for right. |
| L-2 | Each lane owns its own lane store: 24 slots (`N.STORE_SLOTS`; 12 in v1.15..v1.20). Slot use = stacks stored. (v21 text) |
| L-3 | Each lane output runs independently; blocked left lane does not stall right lane output. Blocked lane never stops other lane input or output (author 2026-09-28). |

## 5. Storage full — flush rule

| ID | Requirement |
|----|-------------|
| F-1 | If item arrives, needs new slot, and its lane's 24 slots are used: oldest leftover of same lane is flushed (oldest = kind that started waiting earliest). Script way: it leaves first, also while full stacks wait. Engine way: lane whose hidden out inserters all hold leftovers is "steered": out inserters take only kinds with a full stack, leftovers wait in store, 3 slots kept free by flushing oldest leftovers at each look (every 30 ticks). Jam rule: leftovers also leave when lane store holds 16 belt stacks or more, or is unchanged with full stacks at three looks while front has room. (v21 text) |
| F-2 | Flushed leftover leaves on its own lane as one smaller belt item. (v21 text) |
| F-3 | While lane has no slot free (flushed stack still leaving), that lane input stops; belt lane behind backs up. No items lost, no items dropped. |
| F-4 | If all 24 slots of lane hold ready stacks (output blocked), that lane input stops until its output frees slot. Other lane unaffected. Old saves: §18. |

## 6. Output

| ID | Requirement |
|----|-------------|
| O-1 | Output as stacked belt items on matching lane of front belt: by hidden out inserters (engine way) or `LuaTransportLine.insert_at_back(items, belt_stack_size)` (script way, flushes). (v21 text) |
| O-2 | One belt item holds one kind only. (v21 text) |
| O-3 | Belt stack size = `1 + force.belt_stack_size_bonus`, capped only by engine max `max_belt_stack_size` (4 vanilla, raised by mods; author 2026-09-27: "packer must release whatever the research (modded or not) set"). Follows research live (re-read when research completes). Early game = 1. v10 (V10-6): no stacking research in game (no space-age, no stacking mod) → bonus 0 → N = 1, items leave one by one. Box never stacks above what research set. |
| O-4 | Output speed per E-4: about 1.6 x own belt rate at most. Front belt of slower tier limits flow. (v21 text) |
| O-5 | Full stack leaves as one belt item of N. Flushed partial (F-1, S-1, N-4) leaves as one smaller belt item. Research raise changes N for stacks started after it. |

## 7. Settings

| ID | Requirement |
|----|-------------|
| S-1 | Flush timeout: leftover older than N seconds is flushed even if lane store not full; leaves N to N + 5 seconds after it started waiting. 0 = off. (v21 text) |
| S-2 | Global map setting = default timeout for new boxes. Per-entity GUI override (use global / custom value). |
| S-3 | Item filter (pass-through list, 10 entries), per entity, set in GUI: row of 10 slots like vanilla logistic filters; selected slot opens editor line (item, comparator, quality/any). Listed items never stored; go straight to output on same lane. Sections of packer window (E-6): lanes, Items to skip, Flush timeout, Circuit network. (v21 text) |
| S-4 | Per-entity settings survive copy-paste (`on_entity_settings_pasted`), blueprints (tags on build), undo/redo, cloning (`on_entity_cloned`). Blueprint holds belt body with tags; ghost and blueprint preview show packer with hood (v20). Old blueprints (chest variants) build belt bodies. (v21 text) |

## 8. Pass-through (filter)

| ID | Requirement |
|----|-------------|
| P-1 | Filter = item + quality rule like vanilla splitter: comparator (`=`, `≠`, `>`, `<`, `≥`, `≤`) + quality, or any quality. Match compares `LuaQualityPrototype.level`. v10 (V10-5): game with one non-hidden quality (no `quality` mod) → no comparator and no quality picker, filter = item only (vanilla splitter). |
| P-2 | Items to skip are not held for stacking: they leave lane store at next visit, before stacks, unstacked. (v21 text) |
| P-3 | Packer with items to skip works script way (E-11). No separate hold. (v21 text) |

## 9. Circuit network

| ID | Requirement |
|----|-------------|
| N-1 | Connect red/green wire to belt body, as to a belt. (v21 text) |
| N-2 | Read contents (belt's own setting, on by default, can be switched off): all items inside packer, both lanes summed, per quality, plus items lying on belt body. Carried by copy-paste, blueprint, upgrade planner. (v21 text) |
| N-3 | Enable/disable condition (belt's own setting, shown in packer window): when false, input AND output stop; contents kept. Checked at each look (up to 30 ticks late). (v21 text) |
| N-4 | Flush signal (in GUI Circuit network section): configurable signal; when > 0, all partials are queued for output (rising edge, one flush per edge). |

## 10. Unlock and recipes

| ID | Requirement |
|----|-------------|
| U-1 | One tech per tier `sushi-packer-<tier>`. Prerequisites: matching belt tech + previous tier tech + every tech whose effects unlock an ingredient recipe (scanned from `data.raw.technology` at data stage). Cost: `count` = belt tech count × 1.5, `time` = belt tech time, `ingredients` = union of science packs over direct prerequisites. v11: root tier (M-4) has no previous tier tech. |
| U-2 | Recipe per tier, chained, crafted in `crafting` category (hand + assembler). yellow 30 s: 1 `steel-chest`, 1 `splitter`, 2 `inserter`, 5 `electronic-circuit`. red 45 s: 1 yellow box, 1 `fast-splitter`, 2 `fast-inserter`, 5 `advanced-circuit`. blue 60 s: 1 red box, 1 `express-splitter`, 2 `bulk-inserter`, 5 `processing-unit`. turbo 120 s: 1 blue box, 1 `turbo-splitter`, 2 `stack-inserter`, 2 `quantum-processor`. Modded tiers: M-5. v10: turbo recipe exists only with space-age (E-4). |
| U-3 | Upgrade planner: yellow → red → blue → turbo (→ modded tiers, M-4), same direction. v11: follows each tier chain (M-4); no upgrade across chains. Upgraded box keeps settings, stored items, circuit wires. (v21 text) |
| U-4 | Item weight 20 kg (50 per rocket). No surface conditions (works on space platforms). v10: Space Exploration space tiles allowed (`se_allow_in_space`). Space Age recycler recipes exist per tier (auto-generated). |
| U-5 | Every item, entity, technology, recipe and setting has locale name + description. One tips-and-tricks entry explains lanes and stacks. v11: locales `en` + `de`, same keys (guard test). German terms: vanilla tiers use vanilla German (`base`/`space-age` `de`); mod tiers use that mod's own German; mod without German → its English word + hyphen + German noun ("Elite-Sushi-Packer"). Noun "Sushi-Packer". In-game text only; portal page + README stay English. |
| U-7 | Names follow vanilla belt series: Sushi packer, Fast sushi packer, Express sushi packer, Turbo sushi packer (internal `sushi-packer`, `fast-sushi-packer`, `express-sushi-packer`, `turbo-sushi-packer`). Own crafting-menu row after belts, sorted yellow, red, blue, turbo, then modded tiers (M-8). Old names migrated. |
| U-8 | Factoriopedia page and tip show live scene: mixed items in, 4-stacks sorted per lane out, real box logic (simulation `mods`). |
| U-6 | Release zip ships `thumbnail.png` (144×144), `changelog.txt`; repo has `README.md`. Release `info.json` has no test-only dependency. |

## 11. Performance

| ID | Requirement |
|----|-------------|
| R-1 | v16 (author 2026-10-01): script time at least x10 below v1.14 on every bench row with stacking feature (row = 200 packers at full flow, belt stacks 1-4 of mixed items, belt stack 4, output free; rows yellow, red, blue, turbo, fastest live extra tier per FV). Later releases: no row slower than previous release beyond noise, except by author's word with numbers: V17-11 (v1.17, fastest mod belt script 0.38 → 0.45 ms), V21-3 (v1.21, fastest mod belt whole tick about +12 %). (v21 text) |
| R-3 | v14 (author 2026-10-01): every release runs `make bench-all` on both FV, numbers go in `docs/STEPS.md`; no row slower than previous release beyond noise band. |
| R-2 | Idle boxes (empty input, nothing queued) skip work. Update cadence per tier may batch work (`on_nth_tick`) as long as O-4 throughput holds. |

## 12. Status LED

| ID | Requirement |
|----|-------------|
| V-1 | Each box shows one status LED on its crossbar (visible in all 4 directions). |
| V-2 | Green = both lane stores empty and nothing waiting in hidden inserter hands. (v21 text) |
| V-3 | Yellow = items waiting, no lane store full. (v21 text) |
| V-4 | Red = a lane store full: its 24 slots used. (v21 text) |
| V-5 | State recalculated at each look (every 30 ticks, script way at each visit); items in hidden inserter hands are known only at hand looks: LED may lag up to 5 seconds. Stopped packer shows store state. (v21 text) |
| V-6 | LED drawn by script: one `rendering.draw_sprite` per box, targeted on entity. On state change only, write `LuaRenderObject.sprite` (RW) to new colour sprite. No write when state same. |
| V-7 | LED visible at night: small `rendering.draw_light` in LED colour, colour updated with sprite. |
| V-8 | Render object destroyed with entity; recreated on load if missing (`on_configuration_changed`). |

## 13. Graphics

| ID | Requirement |
|----|-------------|
| G-1 | Design: twin-lane hood (one hood per lane, steel spine), w2-medium wear. |
| G-2 | Per-tier paint + wear matched to vanilla undergrounds of same tier: yellow 192,150,60 wear 0.65; red 178,52,44 wear 0.50; blue 60,150,200 wear 0.40; turbo 140,176,60 wear 0.60. Modded tiers: M-7. |
| G-3 | Entity sprites HR only: 64 px per tile, `scale = 0.5`, frame 128x128 (2 tiles, room for shadow), tile centre = frame centre, `shift = {0, 0}`. |
| G-4 | 4 directions (north, east, south, west). Direction = side items leave. Per-direction files + one 4-frame sheet per tier. |
| G-5 | Separate shadow layer, `draw_as_shadow = true`, same frame size. |
| G-6 | Entity sprite has dark LED lens. LED colour sprites (green / yellow / red) separate per direction, same frame, drawn by script (V-6). |
| G-7 | Belt under hood not baked in; vanilla belt drawn from `__base__`/`__space-age__` belt sprites where needed. |
| G-8 | Icon per tier: 64 px, custom mipmaps 64+32+16+8 in one 120x64 file, `icon_size = 64`. |
| G-9 | Remnant per tier: wrecked hood, 128x128 frame, `scale = 0.5`, with shadow. |

## 14. Out of scope v1

- Factorio 1.1. (Base game without Space Age is supported since v10.)
- Multi-tile or splitter-style variants.
- Stack size override (release at custom count other than item stack size).

## 15. Open questions

| ID | Question |
|----|----------|
| Q-1 | ANSWERED 2026-09-26: chained recipes, own tech per tier (U-1, U-2). |
| Q-2 | Tier differences besides speed: health, inventory size (all 48 now)? |
| Q-3 | Timeout clock: from first item arrival (proposed) or from last item arrival? |
| Q-4 | Enabled=false: should input still fill storage (only output stops)? Current spec: both stop. |
| Q-5 | Flush signal: partials only (proposed), or also items in pass-through hold? |
| Q-6 | ANSWERED 2026-09-26: `dev-vm`, 5 ms/tick for 200 boxes (R-1). |
| Q-7 | Mod name / internal prefix. Working name `sushi-packer`. |
| Q-8 | ANSWERED 2026-09-26: 4 container variants swapped by script. Superseded v17: belt body rotated by game (E-7). |
| Q-9 | ANSWERED 2026-09-26: LED off (sprite + light hidden) while circuit disables box. |

## 16. API references

- `LuaTransportLine.insert_at_back(items, belt_stack_size?)`, `can_insert_at_back()` — https://lua-api.factorio.com/latest/classes/LuaTransportLine.html
- `LuaRendering.draw_sprite`, `draw_light`; `LuaRenderObject.sprite` / `.color` RW — https://lua-api.factorio.com/latest/classes/LuaRenderObject.html
- `Sprite4Way` — https://lua-api.factorio.com/latest/types/Sprite4Way.html ; `IconData` mipmaps — https://lua-api.factorio.com/latest/types/IconData.html
- Rotatable container workaround — https://forums.factorio.com/viewtopic.php?f=25&t=7432
- `LuaForce.belt_stack_size_bonus` — https://lua-api.factorio.com/latest/classes/LuaForce.html
- Events `on_entity_settings_pasted`, `on_player_setup_blueprint`, `on_entity_cloned`, `on_nth_tick` — https://lua-api.factorio.com/latest/events.html
- Loader prototype (rejected alternative, `max_belt_stack_size`) — https://lua-api.factorio.com/latest/prototypes/LoaderPrototype.html
- Similar mods: Belt Buffer https://mods.factorio.com/mod/belt_buffer_up, Stacked Items https://mods.factorio.com/mod/stacked-items, Belt Sorter https://mods.factorio.com/mod/beltSorter, Miniloader https://github.com/mspielberg/factorio-miniloader

## 17. Modded belt tiers (v9)

| ID | Requirement |
|----|-------------|
| M-1 | Extra tier per supported modded belt (table `N.EXTRA`): Planetaris Arig hyper, Krastorio 2 / K2SO superior, Bob's ultimate, Ultimate Belts Space Age ×5, Better Belts ultra; v10: Advanced Belts 2.0 ×4 (elite, extreme, supreme, ultimate; 2.0 only), Space Exploration deep space; v11: Space Exploration space (`se-space-transport-belt`, own role, 2.0 + 2.1). Tier exists only if one of its owner mods is loaded (v10, V10-2), its belt prototype exists and is not hidden, its splitter exists (v10), and its belt tech exists with science `unit`. Else skipped, logged, no error. |
| M-2 | Vanilla (no belt mod): with space-age exactly 4 tiers; names, recipes, techs same as v8 (v10 adds only `se_allow_in_space` on containers). Without space-age: yellow, red, blue. |
| M-3 | Extra tiers built in `data-final-fixes`. Supported mods listed as visible optional dependencies (`? <mod>`, shown on portal and in-game mod list; author 2026-09-28). |
| M-4 | Order + upgrade chain = belt `speed` ascending after top vanilla tier present (turbo with space-age, blue without; v10); tie by table order. Belt speed ≤ top vanilla belt → no extra tier unless row marked own role (v10, V10-3). Own chain; belt `next_upgrade` ignored. v11: row may name its previous row (`after`); named previous row absent → tier skipped. Row with own role and no `after` = root tier (no previous box, no previous tech). SE chain: space (root) → deep space (`after` space); every other extra tier stays in main chain by speed. Crafting-menu order stays speed order, all chains together (space right after blue). |
| M-5 | Recipe: previous tier box 1, own belt splitter 1, `stack-inserter` 2, `quantum-processor` 2, 120 s. v11: root tier replaces previous box with `steel-chest` 1 and doubles inserters + circuits; SE space: `steel-chest` 1, `se-space-splitter` 1, `bulk-inserter` 4, `processing-unit` 10, 60 s. v10: without `stack-inserter` / `quantum-processor` items → `bulk-inserter` 2, `processing-unit` 5, 60 s. Tech per U-1 with own belt tech. |
| M-6 | Every tier (vanilla too) rate = live belt prototype speed (E-4, O-4 same meaning); settings that change belt speed followed. Output never above belt rate. Engine places several belt items per tick per lane, full rate up to 270/s (FND-0022). |
| M-7 | Graphics: same hood as G-1..G-9; paint = mod's own underground-belt icon colour calibrated to G-2 (hue kept, V ×1.21, S +0.06); wear 0.40 unless author changes on preview. v11: icon without hue (SE deep space, SE space) → hand-picked from icon median, no V boost; SE space = light grey. |
| M-8 | Names mirror belt names ("Hyper sushi packer", ...), own row order after top vanilla tier. v10: Elite, Extreme, Supreme, Ultimate sushi packer (Advanced Belts 2.0), Deep space sushi packer (Space Exploration). v11: Space sushi packer (Space Exploration). |
| M-9 | Mod removed from save: its boxes vanish per Factorio rule; no script error. |

## 18. Old saves and blueprints (v21 text)

| ID | Requirement |
|----|-------------|
| X-1 | Packers of saves made with any earlier version are converted at load: items, settings and player wires kept; nothing lost, nothing on ground, lanes kept. Items that do not fit lane stores wait in hidden spare stores that empty themselves. Proven per release by loading saves of earlier versions (v1.14 onward) in headless game. |
| X-2 | Conversion works for any number of packers in save (count sweep test). |
| X-3 | Read contents is on after conversion. |

## 19. Intake (v21, author 2026-10-02)

| ID | Requirement |
|----|-------------|
| I-1 | Belt behind packer must not back up while front is free: packer line takes in at least 98 % of what a free belt of same tier carries (same feed, side by side), on yellow, red, blue, turbo and on fastest belt of every supported mod set, engine way and script way. Feeds: full stacks; mixed stacks of 3 kinds; single items of 7 kinds; steady and thin trickle of 21 rare kinds; trickle of 60 rare kinds (more kinds than slots). |
| I-2 | Known exceptions by author's decision: belt faster than turbo carrying more kinds than 24 per lane, engine way, takes 0.52 (270 items/s) .. 0.97 of a free belt (V21-4: extra looks would cost about 3.5 x script time); fully stacked 270 items/s belt lets about 1 stack in 150 leave smaller than full (V21-3). |
| I-3 | One hidden in inserter of every four holds 1 item, the others 4 (an inserter holding fewer items than its size waits about 20 ticks for more of that kind). Belts faster than 144 items/s carry 12 hidden out inserters per lane, others 8. |

