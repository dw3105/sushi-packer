# Sushi Packer — Requirements

Factorio mod. 1x1 belt-inline box. Takes mixed ("sushi") items off belt, holds them until one item type reaches full stack, then pushes that stack out as stacked belt items. Output = sorted, compressed runs of single item type.

Status: v4, 2026-09-26. Source: Q&A with author. v2 adds status LED (§12) and graphics spec (§13). v3 (author 2026-09-26): T-1 two builds 2.0 + 2.1; Q-8, Q-9 answered. v4 (author 2026-09-26): R-1 budget 5 ms on `dev-vm`; Q-6 answered. v5 (author 2026-09-26): chained recipes + tech rule (U-1, U-2, Q-1 answered), upgrade planner, weight, locale, tips, release files (U-3..U-6); no stack gate (O-3 unchanged). v6 (author play-test 2026-09-26): release at belt stack (C-2, O-5), vanilla-style names + own row (U-7), live Factoriopedia/tips scene (U-8), splitter-style quality filter (P-1), GUI sections (S-3, N-3, N-4), decon stops box (E-8), box placed over belt (E-9). v7 (author 2026-09-27): O-3 belt stack follows research up to engine max; E-10 added, then dropped same day.

## 1. Target

| ID | Requirement |
|----|-------------|
| T-1 | Factorio 2.0 and 2.1: two builds from one source (2.0 → `0.1.x`, 2.1 → `0.2.x`), only API present in both. Hard dependency on `space-age` (belt stacking, quality). |
| T-2 | Multiplayer-safe, save/load-safe. All state in `storage`. No desync sources. |

## 2. Entity

| ID | Requirement |
|----|-------------|
| E-1 | 1x1 entity, rotatable (4 directions). Input side = back, output side = front, like belt segment. |
| E-2 | Built as scripted 1x1 container with 48-slot inventory (steel chest size). Lua moves items; no hidden loaders. |
| E-3 | Takes items from belt tile behind it (lane-preserving, see §4). Writes items onto belt tile in front. No belt in front → output stalls; input continues until storage full (§5). |
| E-4 | Tier per belt: yellow, red, blue, turbo. Tier sets max input and output rate = matching belt throughput. Tier does NOT set belt stack size (see O-3). |
| E-5 | Mining entity returns stored items to player (spill on ground if inventory full). Destroyed entity spills contents on ground. |
| E-6 | Player GUI shows contents. Player may take items out manually; script state reconciles on next tick. |
| E-8 | Box marked for deconstruction stops: no input, no output, LED off. Cancel → resumes. |
| E-10 | DROPPED by author 2026-09-27 ("E-10 - drop") after v2 host probes (FND-0017, FND-0018). Was: box works like belt tile for every input/output, no side-load into box. Box keeps v1 belt I/O (E-3, FND-0015, FND-0016). |
| E-9 | Box item placed over belt replaces that belt (belt + its items to player), like splitter. One way: belt never replaces placed box. |
| E-7 | `ContainerPrototype` cannot rotate. Rotation must come from 4 container variants (one per direction, swapped by script on build/rotate) or other rotatable host. Choice = Q-8: 4 container variants + rotatable placer entity (item `place_result`, carries direction in hand and in blueprints). |

## 3. Core behavior — accumulate and release

| ID | Requirement |
|----|-------------|
| C-1 | Buffer key = (item name, quality, lane). Each quality is separate type. Same item on left and right lane = two separate buffers. |
| C-2 | Full stack = N = min(belt stack size (O-3), item prototype `stack_size`). With belt stack 4: 4 iron plates of one quality on one lane = full. Belt stack 1 (no research) → every item leaves at once, lane kept (pass-through look). Quality does not change N. |
| C-3 | When buffer reaches full stack, that stack is marked ready and queued for output on its own lane. |
| C-4 | Output queue per lane is FIFO by time stack became ready. |
| C-5 | Item arriving while its buffer already has queued ready stack starts new partial. |

## 4. Lanes

| ID | Requirement |
|----|-------------|
| L-1 | Lane-preserving. Item picked from input left lane only ever leaves on output left lane; same for right. |
| L-2 | Two lanes share one 48-slot pool. Slot use = sum over buffers of `ceil(count / stack_size)`, including ready-but-not-yet-output stacks. |
| L-3 | Each lane output runs independently; blocked left lane does not stall right lane output. |

## 5. Storage full — flush rule

| ID | Requirement |
|----|-------------|
| F-1 | If item arrives, needs new slot, and all 48 slots used: flush oldest partial. Oldest = partial whose first item arrived earliest (across both lanes). |
| F-2 | Flushed partial is queued on its own lane like ready stack (joins FIFO at flush time). |
| F-3 | While no slot free (flushed stack still leaving), input stops; belt behind backs up. No items lost, no items dropped. |
| F-4 | If all 48 slots hold ready stacks (output blocked), input stops until output frees slot. |

## 6. Output

| ID | Requirement |
|----|-------------|
| O-1 | Output as stacked belt items via `LuaTransportLine.insert_at_back(items, belt_stack_size)` (or equivalent) on matching lane of front belt. |
| O-2 | One stack leaves fully before next queued stack on same lane starts. No interleave of types inside one lane's stack run (except P-3). |
| O-3 | Belt stack size = `1 + force.belt_stack_size_bonus`, capped only by engine max `max_belt_stack_size` (4 vanilla, raised by mods; author 2026-09-27: "packer must release whatever the research (modded or not) set"). Follows research live (re-read when research completes). Early game = 1. |
| O-4 | Output rate never exceeds tier belt throughput (E-4). Front belt faster tier → still limited by box tier. |
| O-5 | Full stack leaves as one belt item of N. Flushed partial (F-1, S-1, N-4) leaves as one smaller belt item. Research raise changes N for stacks started after it. |

## 7. Settings

| ID | Requirement |
|----|-------------|
| S-1 | Flush timeout: partial older than N seconds is flushed even if storage not full. 0 = off. |
| S-2 | Global map setting = default timeout for new boxes. Per-entity GUI override (use global / custom value). |
| S-3 | Item filter (pass-through list, 10 entries), per entity, set in GUI: row of 10 slots like vanilla logistic filters; selected slot opens editor line (item, comparator, quality/any). Listed items never stored; go straight to output on same lane. GUI frame sits right of container window, aligned sections: Items to skip, Flush timeout, Circuit network. |
| S-4 | Per-entity settings survive copy-paste (`on_entity_settings_pasted`), blueprints (tags on build), undo/redo, cloning (`on_entity_cloned`). |

## 8. Pass-through (filter)

| ID | Requirement |
|----|-------------|
| P-1 | Filter = item + quality rule like vanilla splitter: comparator (`=`, `≠`, `>`, `<`, `≥`, `≤`) + quality, or any quality. Match compares `LuaQualityPrototype.level`. |
| P-2 | Pass-through items take no storage slot. |
| P-3 | Pass-through items go out between stacks, not inside a stack run. If output lane busy with stack, pass-through item waits in small internal hold (max 1 belt item per lane); input on that lane pauses while hold full. |

## 9. Circuit network

| ID | Requirement |
|----|-------------|
| N-1 | Connect red/green wire. |
| N-2 | Read contents: output all stored items (both lanes summed, per quality) as signals. |
| N-3 | Enable/disable condition (in GUI Circuit network section): when false, input AND output stop. Contents kept. |
| N-4 | Flush signal (in GUI Circuit network section): configurable signal; when > 0, all partials are queued for output (rising edge, one flush per edge). |

## 10. Unlock and recipes

| ID | Requirement |
|----|-------------|
| U-1 | One tech per tier `sushi-packer-<tier>`. Prerequisites: matching belt tech + previous tier tech + every tech whose effects unlock an ingredient recipe (scanned from `data.raw.technology` at data stage). Cost: `count` = belt tech count × 1.5, `time` = belt tech time, `ingredients` = union of science packs over direct prerequisites. |
| U-2 | Recipe per tier, chained, crafted in `crafting` category (hand + assembler). yellow 30 s: 1 `steel-chest`, 1 `splitter`, 2 `inserter`, 5 `electronic-circuit`. red 45 s: 1 yellow box, 1 `fast-splitter`, 2 `fast-inserter`, 5 `advanced-circuit`. blue 60 s: 1 red box, 1 `express-splitter`, 2 `bulk-inserter`, 5 `processing-unit`. turbo 120 s: 1 blue box, 1 `turbo-splitter`, 2 `stack-inserter`, 2 `quantum-processor`. |
| U-3 | Upgrade planner: yellow → red → blue → turbo, same direction. Upgraded box keeps settings, stored items, pass-through hold, circuit wires. |
| U-4 | Item weight 20 kg (50 per rocket). No surface conditions (works on space platforms). Space Age recycler recipes exist per tier (auto-generated). |
| U-5 | Every item, entity, technology, recipe and setting has locale name + description. One tips-and-tricks entry explains lanes and stacks. |
| U-7 | Names follow vanilla belt series: Sushi packer, Fast sushi packer, Express sushi packer, Turbo sushi packer (internal `sushi-packer`, `fast-sushi-packer`, `express-sushi-packer`, `turbo-sushi-packer`). Own crafting-menu row after belts, sorted yellow, red, blue, turbo. Old names migrated. |
| U-8 | Factoriopedia page and tip show live scene: mixed items in, 4-stacks sorted per lane out, real box logic (simulation `mods`). |
| U-6 | Release zip ships `thumbnail.png` (144×144), `changelog.txt`; repo has `README.md`. Release `info.json` has no test-only dependency. |

## 11. Performance

| ID | Requirement |
|----|-------------|
| R-1 | Scripted design costs UPS per box. Target: 200 boxes at full flow ≤ 5 ms/tick average script time on reference machine `dev-vm` (4 shared vCPU GCP VM), measured by `make bench FV=2.0`. |
| R-2 | Idle boxes (empty input, nothing queued) skip work. Update cadence per tier may batch work (`on_nth_tick`) as long as O-4 throughput holds. |

## 12. Status LED

| ID | Requirement |
|----|-------------|
| V-1 | Each box shows one status LED on its crossbar (visible in all 4 directions). |
| V-2 | Green = box empty: 0 items stored, nothing queued for output, pass-through hold empty. |
| V-3 | Yellow = box has items waiting, but at least 1 of 48 slots free. |
| V-4 | Red = box full: all 48 slots used (input stopped, F-3 / F-4). |
| V-5 | State recalculated every tick for every box, from counters script already keeps (no inventory scan per tick). |
| V-6 | LED drawn by script: one `rendering.draw_sprite` per box, targeted on entity. On state change only, write `LuaRenderObject.sprite` (RW) to new colour sprite. No write when state same. |
| V-7 | LED visible at night: small `rendering.draw_light` in LED colour, colour updated with sprite. |
| V-8 | Render object destroyed with entity; recreated on load if missing (`on_configuration_changed`). |

## 13. Graphics

| ID | Requirement |
|----|-------------|
| G-1 | Design: twin-lane hood (one hood per lane, steel spine), w2-medium wear. |
| G-2 | Per-tier paint + wear matched to vanilla undergrounds of same tier: yellow 192,150,60 wear 0.65; red 178,52,44 wear 0.50; blue 60,150,200 wear 0.40; turbo 140,176,60 wear 0.60. |
| G-3 | Entity sprites HR only: 64 px per tile, `scale = 0.5`, frame 128x128 (2 tiles, room for shadow), tile centre = frame centre, `shift = {0, 0}`. |
| G-4 | 4 directions (north, east, south, west). Direction = side items leave. Per-direction files + one 4-frame sheet per tier. |
| G-5 | Separate shadow layer, `draw_as_shadow = true`, same frame size. |
| G-6 | Entity sprite has dark LED lens. LED colour sprites (green / yellow / red) separate per direction, same frame, drawn by script (V-6). |
| G-7 | Belt under hood not baked in; vanilla belt drawn from `__base__`/`__space-age__` belt sprites where needed. |
| G-8 | Icon per tier: 64 px, custom mipmaps 64+32+16+8 in one 120x64 file, `icon_size = 64`. |
| G-9 | Remnant per tier: wrecked hood, 128x128 frame, `scale = 0.5`, with shadow. |

## 14. Out of scope v1

- Factorio 1.1, base game without Space Age.
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
| Q-8 | ANSWERED 2026-09-26: 4 container variants swapped by script (placer mechanics in `docs/DECISIONS.md`). |
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
