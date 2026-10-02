# Contract — frozen seams (SP-01)

Changes only by integrator decision recorded in `docs/DECISIONS.md`. Guard tests: `tests/offline/test_guard.lua` (names, function arity), `tests/game/test_guard.lua` (prototypes, wiring).

## Rules for every module

- Module file returns one table `M`. Load touches no game global (`game`, `storage`, `defines`, `rendering`, `prototypes`, `settings`, `script`, `helpers`). Globals only inside functions.
- No state outside `storage` (SP-05). No function values in `storage`.
- Iterate arrays with `ipairs` or numeric `for`. Never let `pairs` order decide logic.
- Lane never edits another lane's file, this contract, `scripts/names.lua`, `control.lua`, guard tests.
- Lanes use each other only through the signatures below. In lane tests, fake the other side (callbacks, hand-built `rec`).

## Storage layout

```lua
storage.boxes = { [unit_number] = rec }        -- one rec per placed box
storage.belt_stack = { [force_index] = n }      -- cached 1 + belt_stack_size_bonus, max 4 (O-3)
storage.sp_counters = nil | { visits = n, reads = n, pulls = n, pushes = n, items_in = n, items_out = n }  -- v14 bench seam, nil = off (normal play), owned by scripts/tick.lua
storage.upgrade_stash = { [key] = { rec = rec, tick = uint, force = uint } }  -- U-3, key = surface_index..":"..x..":"..y, owned by scripts/registry.lua
rec = {
  entity = LuaEntity,                            -- container variant
  unit_number = uint,
  tier = "yellow"|"red"|"blue"|"turbo"|<N.EXTRA key>,  -- v9: any key of N.ALL
  dir = "north"|"east"|"south"|"west",           -- side items leave
  box = <core box>,                              -- owned by scripts/core.lua, opaque to others
  settings = {
    timeout_mode = "global"|"custom",            -- S-2
    timeout_s = 0,                               -- used when custom; 0 = off
    filters = { {name = "iron-plate", quality = "normal"|nil, comparator = "="|"≠"|">"|"<"|"≥"|"≤"|nil}, ... },  -- S-3, P-1 v6 (nil quality = any, nil comparator = "="); array index = GUI slot 1..10, empty slot = false
    circuit = {
      enable = false,                            -- N-3 condition on/off
      cond = { first_signal = SignalID|nil, comparator = ">"|"<"|"="|"≥"|"≤"|"≠", constant = 0 },
      flush = false,                             -- N-4 on/off
      flush_signal = SignalID|nil,
    },
  },
  circuit_state = { last_flush = false },        -- owned by scripts/circuit.lua
  led = { sprite = LuaRenderObject, light = LuaRenderObject, state = "green", visible = true },  -- owned by scripts/led.lua
  enabled = true,                                -- last circuit verdict, written by scripts/tick.lua
  decon = false,                                 -- E-8: marked for deconstruction, written by tick.on_decon
  out_credit = { 0, 0 },                         -- belt-items allowed per lane, owned by scripts/tick.lua
  in_credit = { 0, 0 },
  next_poll = 0,                                 -- idle skip (R-2), owned by scripts/tick.lua
  belt = { behind = LuaEntity|nil, front = LuaEntity|nil, scan = { behind = tick, front = tick } },  -- cached neighbours, owned by scripts/belt_io.lua (PERF-1)
}
```

Default settings = `copy.default_settings()`.

## Lanes

Measured facts (S0 probes, `tests/game/test_probe.lua`, green on 2.0.77 and 2.1.20):
- Lane index 1 = left, 2 = right, facing belt motion (`LuaEntity.get_transport_line(i)`). Box input lane i ↔ output lane i (L-1).
- `LuaTransportLine` `position` shrinks toward exit. Front-most item (next to enter box) = LOWEST `position`; on a belt end it rests at 0 (FND-0004).
- `insert_at_back({name, count=4}, 4)` with `force.belt_stack_size_bonus = 3` makes one belt item of count 4.
- Placer `simple-entity-with-owner` keeps `direction`; blueprint of placer built with `direction = east` turns ghost east → south (D-4).
- Test world: 1 connected player with character (`game.players[1]`): GUI via `player.opened`, mining via `player.mine_entity`.
- In-game test full name = `<describe> > <it>`; FactorioTest path = `tests.game.<file> > <describe> > <it>`.

## scripts/core.lua — pure engine (lane A). No game API at all.

Item key = (name, quality, lane). `quality` is a string (`"normal"`, ...).

| Signature | Does |
|---|---|
| `core.new_box() -> box` | empty box, plain tables only |
| `core.accept(box, name, quality, lane, count, stack_size, tick, passthrough, item_stack) -> accepted` | `passthrough=false`: add to buffer (C-1..C-5), at most `item_room` (C-6), full stack → ready FIFO of `lane` (C-3, C-4). Needs new slot and lane has none (`lane_room` false) → flush oldest partial of lane (F-1, F-2) and accept 0 (F-3). All lane slots ready → accept 0 (F-4). May accept part. `passthrough=true`: one belt item into lane hold (P-3), `count` whole or 0 when hold busy. Returns accepted count. |
| `core.lane_room(box, lane) -> bool` | v8 L-2: lane may take one more slot (lane owns `N.SLOTS / 2`) |
| `core.item_room(box, name, quality, lane, item_stack) -> n` | v8 C-6: `item_stack - held` for (name, quality, lane); `item_stack` nil = `math.huge` |
| `core.used_slots(box) -> n` | sum over buffers `ceil(count/stack_size)` incl. ready stacks (L-2). Hold not counted (P-2). |
| `core.free_slots(box) -> n` | `48 - used_slots` |
| `core.on_tick(box, tick, timeout_ticks)` | partial with first arrival `<= tick - timeout_ticks` queued (S-1, Q-3). `timeout_ticks = 0` = off. |
| `core.flush_partials(box, tick)` | queue every partial (N-4, Q-5) in first-arrival order |
| `core.peek_out(box, lane) -> {name, quality, count, passthrough}\|nil` | what leaves next on `lane`: head ready stack remainder, or hold item when no stack run in progress (P-3, O-2) |
| `core.take_out(box, lane, n)` | remove `n` from that head (O-5 last belt item may be smaller) |
| `core.remove_external(box, name, quality, n) -> removed` | D-1 deficit: newest partial first, then back of ready queues |
| `core.adopt_external(box, name, quality, n, stack_size, tick) -> adopted` | D-1 surplus: as left-lane arrival |
| `core.hold_items(box) -> { {name, quality, count}, ... }` | items in pass-through holds (D-3, for mine/spill) |
| `core.clear_hold(box)` | empty holds after returning them |
| `core.totals(box) -> { {name, quality, count}, ... }` | stored items summed over lanes, sorted by name then quality (hold excluded) |
| `core.led_state(box) -> "green"\|"yellow"\|"red"` | V-2..V-4 from counters only (V-5) |
| `core.is_idle(box) -> bool` | nothing stored, nothing queued, holds empty |

## scripts/belt_io.lua — belt adapter (lane D)

| Signature | Does |
|---|---|
| `belt_io.behind(entity, dir) -> LuaEntity\|nil` | belt-like entity on tile behind, moving into box (`transport-belt`, `underground-belt` output side) |
| `belt_io.front(entity, dir) -> LuaEntity\|nil` | belt-like entity on tile in front, not facing back into box |
| `belt_io.pull(rec, budget, sink) -> {n1, n2}` | per lane `i`, up to `budget[i]` belt items: take front-most item at end of behind line, call `sink(name, quality, lane, count) -> accepted`, remove accepted from belt. Stop lane on 0 accepted. Returns belt items taken per lane. |
| `belt_io.push(rec, lane, item, belt_stack_size) -> pushed` | one belt item `{name, quality, count}` (`count <= belt_stack_size`) via `insert_at_back(item, belt_stack_size)` on front line `lane` (O-1). 0 when blocked or no front belt. |
| `belt_io.behind_kinds(rec, lane) -> contents\|nil` | v15 (V15-2): `get_contents()` of cached behind line of `lane` (array `{name, quality, count}`), nil without belt behind |
| `belt_io.lane_rate(tier) -> r` | v9 M-6: belt items per lane per tick = live `prototypes.entity[N.TIER[tier].belt].belt_speed * 4` (cached per load, prototype-derived) |
| `belt_io.belt_stack_size(force) -> n` | `min(4, 1 + force.belt_stack_size_bonus)` (O-3) |

## scripts/led.lua — LED (lane C)

| Signature | Does |
|---|---|
| `led.create(rec)` | `rendering.draw_sprite` targeted on entity + `draw_light`, green, visible (V-1, V-6, V-7); stores `rec.led` |
| `led.set(rec, state, visible)` | write `sprite`/`color`/`visible` only when changed (V-6, Q-9) |
| `led.destroy(rec)` | destroy render objects |
| `led.ensure(rec)` | recreate when missing or invalid (V-8) |

## scripts/registry.lua — lifecycle (lane C)

| Signature | Does |
|---|---|
| `registry.on_built(e)` | placer → variant by `direction` (D-4); variant built direct (clone, revive, undo) → register; apply `e.tags` settings via `copy.import`; `led.create` |
| `registry.on_removed(e)` | mined (`e.buffer` present): hold items into buffer; any removal: `led.destroy`, drop rec |
| `registry.on_died(e)` | spill inventory + hold on ground (E-5), drop rec |
| `registry.on_rotate_input(e, reverse)` | `player.selected` box → `registry.swap` to next/prev dir |
| `registry.swap(rec, new_dir) -> rec` | copy inventory + wires, destroy old, create new variant, rekey storage, LED recreated |
| `registry.get(entity) -> rec\|nil` | lookup by `unit_number` |
| `registry.new_rec(entity) -> rec` | rec with `core.new_box()` and `copy.default_settings()` (used by on_built and swap) |
| `registry.on_configuration_changed(data)` | `led.ensure` every rec; drop recs with invalid entity |
| `registry.stash(rec)` | U-3: keep rec (settings, box, hold) in `storage.upgrade_stash` at entity key, current tick; LED destroyed; rec dropped from `storage.boxes` |
| `registry.take_stash(entity) -> rec\|nil` | U-3: stash at entity key with same tick + force → rec rebound to entity (tier/dir from name, rekeyed); removes entry; prunes entries of older ticks |

## scripts/copy.lua — settings copy (lane C)

| Signature | Does |
|---|---|
| `copy.default_settings() -> settings` | per layout above, `timeout_mode="global"` |
| `copy.export(rec) -> settings` | deep copy, plain values |
| `copy.import(rec, settings)` | deep copy into `rec.settings` |
| `copy.on_setup_blueprint(e)` | variants → placer + `direction` + tag `sushi_packer` = export (D-4, S-4) |
| `copy.on_settings_pasted(e)` | source → destination settings (S-4) |
| `copy.on_cloned(e)` | clone rec: settings + core box deep copy, new LED (S-4) |

## scripts/gui.lua — entity GUI (lane E)

| Signature | Does |
|---|---|
| `gui.on_opened(e)` | box opened → relative frame on container GUI: timeout (global/custom + seconds), filter list (item + quality or any, P-1), circuit enable condition, flush signal |
| `gui.on_closed(e)` | destroy frame |
| `gui.on_event(e)` | any element event of our frame → write `rec.settings` |

## scripts/circuit.lua — circuit (lane F)

| Signature | Does |
|---|---|
| `circuit.compare(a, comparator, b) -> bool` | pure |
| `circuit.evaluate(rec) -> enabled, flush_now` | read red+green via `entity.get_signal`; `enabled` = true when condition off or holds (N-3); `flush_now` true once per rising edge of flush signal > 0 (N-4) |

N-2 read contents = container's native circuit output (items live in inventory, D-1).

## scripts/tick.lua — glue (lane G, wave 2)

| Signature | Does |
|---|---|
| `tick.on_tick(e)` | per box: circuit → pull → core → push → LED; idle skip; reconcile every 60 ticks |
| `tick.on_research(e)` | refresh `storage.belt_stack[force.index]` |
| `tick.timeout_ticks(rec) -> n` | global setting or custom × 60 |
| `tick.counters_on()` | v14: `storage.sp_counters` = all six fields 0 (restart from 0 when already on) |
| `tick.counters() -> table\|nil` | v14: plain copy of `storage.sp_counters`, nil when off |
| `tick.on_decon(e, marked)` | E-8: rec of `e.entity` → `rec.decon = marked`; while true visit skips pull + push, LED hidden |

Counters (v14, only while `storage.sp_counters` is a table; nil = no count, no table write): `visits` +1 per box visit that passes the poll gate in `tick.on_tick` (circuit evaluated); `reads` +1 per `get_detailed_contents()` call in `belt_io.pull`; `pulls` +1 per belt item taken off belt; `items_in` + its accepted item count; `pushes` +1 per belt item put on belt; `items_out` + its item count. `belt_io` reads `storage.sp_counters` itself (no new argument). Remote: `remote.call("sushi-packer", "counters_on")`, `remote.call("sushi-packer", "counters")`.

## Bench seam (v14) - tests/game/bench_builder.lua, tools/bench/

| Thing | Rule |
|---|---|
| `builder.build(surface, force, n, origin, opts) -> positions` | `opts` nil or `{}` = old scene, byte-same entity list as v1.14 (yellow, `single`). `opts.tier` = key of `N.TIER` (default `"yellow"`): feed belts, box placer, splitters follow `N.TIER[tier].belt` / `.splitter`, `N.placer(tier)`. `opts.flow` = `"single"` (default) or `"stacks"`. `opts.seed` = integer (default 1). `opts.box = false` (V14-5) = control scene: tier belt at box tile, no packer. `opts.loader` = loader entity name (default: `"loader-1x1"` when tier yellow + flow single, else `"sushi-packer-bench-loader"`). Returns box positions, one per box, as before. |
| flow `single` | one infinity chest -> output loader -> belts -> box -> belts -> input loader -> void chest (old scene). Engine fact: loader takes only first chest item, belt stack 1 -> single `iron-plate` only (FND-0036). |
| flow `stacks` | per box 4 infinity chests (one item each, `at-least`) -> 4 output loaders with `loader_belt_stack_size_override` 1, 2, 3, 4 -> 2 tier splitters -> 1 tier splitter -> belts -> box. Engine gives full belt rate, belt stacks 1..4 in even shares, fixed cycle (FND-0036). Seed picks, per box, which 4 of 5 item names and which loader row carries which stack size. No script feed. |
| bench mod startup settings | `sushi-packer-bench-boxes` (int, 1..1000, default 200), `sushi-packer-bench-tier` (string, default `yellow`), `sushi-packer-bench-flow` (string, `single` \| `stacks`, default `single`), `sushi-packer-bench-seed` (int, default 1), `sushi-packer-bench-box` (bool, default true; `run.sh --belt-only` sets false) |
| bench mod prototype | `sushi-packer-bench-loader`: `loader-1x1` copy, `speed = 1`, `max_belt_stack_size = 4`, `adjustable_belt_stack_size = true`, made in bench mod `data-final-fixes.lua` |
| bench mod log line | every 600 ticks: `sushi-packer-bench counters tick=<game.tick> visits=<n> reads=<n> pulls=<n> pushes=<n> items_in=<n> items_out=<n>` via `log()` |
| `tools/bench/run.sh` result line | `bench FV=<fv> boxes=<n> ticks=<n> script_ms_avg=<f> whole_ms_avg=<f> tier=<key> modset=<set\|none> flow=<flow> ms_per_box=<f> items_in=<n> us_per_item=<f\|na> load1=<f> box=<yes\|no>` (old five fields first, unchanged) |

## scripts/filter.lua — pass-through rule (lane 015, v6)

| Signature | Does |
|---|---|
| `filter.match(filters, name, quality, levels) -> bool` | pure; skips entries that are not tables (`false` = empty slot); true when any filter has same `name` and quality rule holds: `quality == nil` → any; else compare `levels[quality]` to `levels[filter.quality]` with `comparator` (nil = `"="`) |

## scripts/sim.lua — simulation scene (lane 018, v6)

| Signature | Does |
|---|---|
| `sim.scene(kind)` | `kind = "factoriopedia"\|"tips"`: on `game.surfaces[1]` set bonus 3, build infinity chest → `loader-1x1` → 4 belts → box east (placer, `raise_built`) → 4 belts → `loader-1x1` → void infinity chest; camera on box. Called by simulation init via `remote.call(N.SIM_INTERFACE, "scene", kind)` |


## prototypes/extra.lua — v9 modded tiers (lane 024), v10 owner gate + no-SA chain (lane 028), data stage

| Signature | Rule |
|---|---|
| `extra.top_vanilla(raw) -> key` | v10: last of `N.TIERS` that is built: always for strict tiers; `N.OPTIONAL_VANILLA` tier only when its belt (`raw["transport-belt"]`) and tech (`raw.technology`, with `unit`) exist. `"turbo"` with space-age, `"blue"` without. |
| `extra.tiers(raw, mods) -> { {key=, prev=, speed=}, ... }` | active `N.EXTRA` rows. v10 (Q11): some `row.owners[i]` loaded (`mods[name]`), belt exists + not `hidden`, splitter exists, tech exists + not `hidden` + has `unit` (M-1); belt `speed` > top vanilla belt speed unless `row.own_role` (Q7). Sorted by belt `speed`, tie by row order (M-4); `prev` = previous entry key, first = `top_vanilla(raw)`. v11 (M-4, V11-2): row with `after` -> `prev = row.after` (target not active -> row skipped); `own_role` row without `after` -> `prev = nil` (root); both leave main chain, other rows keep speed chain. Every skip `log()`s key + reason. `mods` = data-stage global `mods`. |
| `extra.build(raw)` | for each of `tiers(raw, mods)`: item, recipe (M-5; v10: `N.EXTRA_RECIPE` when items `stack-inserter` + `quantum-processor` exist, else `N.EXTRA_RECIPE_NOSA`), tech (U-1 rule), placer, 4 variants, remnant via `prototypes/tier.lua`; top vanilla variants + each extra `next_upgrade` = next in chain, same direction. v11: root (`prev = nil`) recipe = `N.EXTRA_RECIPE_ROOT.base` 1 + inserters and circuits × `mult`, no previous tier tech; `next_upgrade` only within one chain (U-3). Called by `data-final-fixes.lua`. |

## v15 arms box seam (V15-1) - frozen for lanes 040..046

Box = visible container variant (unchanged prototype, 48 slots: holds only extra items of old saves and items put in from outside) + hidden parts on same tile: 2 lane stores (`N.STORE`, `N.STORE_SLOTS` = 12 slots) + n arms per lane (`N.ARM`, n = `arms.count(belt speed)`). Arms take items from tile behind box, each arm from one belt lane only, into its lane store. Script moves nothing in; it only pushes belt stacks out of each lane store onto same lane of front belt (`belt_io.push`).

Lane index: 1 = left, 2 = right, facing belt motion (as everywhere). Kind = (item name, quality name). Belt stack N for a kind = `min(bss, item stack_size)`.

### rec fields (new, in `storage.boxes[unit_number]`)

```lua
rec.stores = { LuaEntity, LuaEntity }          -- lane stores, owned by scripts/arms.lua
rec.invs = { LuaInventory, LuaInventory }      -- their chest inventories (cached), owned by scripts/arms.lua
rec.arms = { { LuaEntity, ... }, { ... } }     -- arms per lane, owned by scripts/arms.lua
rec.paused = { bool, bool }                    -- last pause state per lane, owned by scripts/arms.lua
rec.skip = { string, string }                  -- signature of last skip-kind filter set per lane, owned by scripts/arms.lua
rec.ledger = <ledger state>                    -- owned by scripts/ledger.lua, plain data
rec.extra = { { name=, quality=, count=, lane= }, ... } | nil   -- old-save items still in box container, leave first (V14-11); owned by scripts/registry.lua (made) and scripts/tick.lua (drained)
```

`rec.box` (old core box) exists only in recs of old saves until migrated, then nil. `rec.in_credit` unused. Other fields as above.

### scripts/ledger.lua - pure, no game global, plain data only (lane 041)

| Signature | Does |
|---|---|
| `ledger.new() -> state` | `{ seen = { {}, {} } }`: per lane map `name .. "\0" .. quality` -> tick kind was first seen in store |
| `ledger.plan(state, lane, contents, opts) -> list` | `contents` = array `{ name=, quality=, count= }` (shape of `LuaInventory.get_contents()`), `opts = { tick=, bss=, stack_size = function(name) -> n, timeout_ticks = n (0 = off), slots_used = n, slots = n, skip = function(name, quality) -> bool or nil, flush_all = bool }`. First updates `state.seen[lane]`: kind present and unknown -> `tick`; kind no longer present -> removed. Returns belt items to push, in order, each `{ name=, quality=, count= }` with `count <= N`: (1) skip-list kinds (`opts.skip` true): whole count, pieces of N, last piece smaller, kinds ordered by first seen then name then quality; (2) full stacks: kinds with `count >= N`, `floor(count / N)` pieces of N each, kinds ordered by first seen, tie name then quality; (3) flush pieces (`count % N`, after that kind's full stacks): every kind when `opts.flush_all`; kinds with `timeout_ticks > 0 and tick - seen >= timeout_ticks`; and when `slots_used >= slots`, `opts.need_slot ~= false` and steps 1-2 gave nothing: oldest kind only. Never changes `contents`. Same input -> same output (no `pairs` order in result). |
| `ledger.hoard(state, lane, contents, stack_size) -> kinds` | C-6 (V15-3): with memory in `state.hoard[lane]`: kind blocked once `count >= stack_size(name)`, freed when `count <= stack_size / 2` or kind gone; items already in arm hands still land (bound arms of lane x `N.ARM_HAND`): array `{ name=, quality= }`, sorted by name then quality, at most `N.ARM_FILTERS` (largest count first when more) |
| `ledger.led(used_left, used_right, slots) -> "green"\|"yellow"\|"red"` | used slots per lane store: both 0 -> green; either `>= slots` -> red; else yellow (V-2..V-4 on lane stores) |

### scripts/arms.lua - hidden parts adapter (lane 042)

| Signature | Does |
|---|---|
| `arms.count(speed) -> n` | arms per lane from `N.ARMS`: first row with `max >= speed` |
| `arms.create(rec)` | needs `rec.entity`, `rec.tier`, `rec.dir`. Lane stores: reuse valid `rec.stores[lane]`, else `surface.create_entity{ name = N.STORE, position = box position, force = box force }`; `rec.invs[lane] = store.get_inventory(defines.inventory.chest)`. Destroys old arms, then per lane `arms.count(prototypes.entity[N.TIER[rec.tier].belt].belt_speed)` arms: `create_entity{ name = N.ARM, position = box position, force = }`, `pickup_position` = centre of tile behind box (opposite `rec.dir`), `drop_position` = box position, `pickup_from_left_lane = lane == 1`, `pickup_from_right_lane = lane == 2`, `drop_target = rec.stores[lane]`. Every part: `destructible = false`. Wires: for `defines.wire_connector_id.circuit_red` and `circuit_green`: `store.get_wire_connector(id, true).connect_to(rec.entity.get_wire_connector(id, true), false, defines.wire_origin.script)`. Resets `rec.paused = { false, false }`, `rec.skip = { "", "" }`. |
| `arms.destroy(rec, keep_stores)` | destroys arms; stores too unless `keep_stores`; clears the rec fields it destroyed. Never moves items. |
| `arms.pause(rec, lane, paused)` | when `rec.paused[lane] ~= paused`: every arm of lane `disabled_by_script = paused`; remembers. No engine call when unchanged. |
| `arms.skip(rec, lane, kinds)` | `kinds` = array from `ledger.hoard`. Builds signature string; unchanged -> no engine call. Else every arm of lane: `use_filters = (#kinds > 0)`, `inserter_filter_mode = "blacklist"`, slots 1..`N.ARM_FILTERS`: `set_filter(i, kinds[i] and { name =, quality = , comparator = "=" } or nil)`. |
| `arms.need_slot(rec, lane, contents) -> bool` | F-1 (V15-2): some arm of lane holds (`held_stack`) a kind not in `contents`. Called only when lane store is full. |
| `arms.ensure(rec) -> rebuilt` | any store or arm missing / invalid, or arm count differs from `arms.count` for tier -> `arms.create(rec)`, true; else false |

Engine facts (FND-0040, FND-0042, both versions): all writes above accepted; lane lock exact; works behind belt, underground exit, splitter, loader, any box direction; blacklist filter makes lane wait at skipped kind; `disabled_by_script` stops arms within 30 ticks; box connector reads sum of box + both stores.

### prototypes/hidden.lua (lane 040)

`hidden.make() -> { arm prototype, store prototype }`, data stage, needs `data.raw.inserter["bulk-inserter"]` and `data.raw.container["steel-chest"]`.

### tick visit (lane 044), lifecycle (lane 045), window (lane 043)

- `tick.on_tick`: per due box: `circuit.evaluate`; lane paused when circuit off, `rec.decon`, or lane has `rec.extra` items (`arms.pause`); per lane: extra items of that lane first (out of box container), then `ledger.plan` on `rec.invs[lane].get_contents()` -> pieces pushed in order with `belt_io.push(rec, lane, piece, bss)` while it returns > 0 and `rec.out_credit[lane] >= 1` (credit rule unchanged), each pushed piece removed from its inventory; `arms.skip(rec, lane, ledger.hoard(...))`; LED from `ledger.led` with used slots = `#inv - inv.count_empty_stacks()`. Counters: `visits`, `pushes`, `items_out` as today, `items_in` += pushed item count, `pulls` / `reads` stay 0.
- `registry`: `arms.create(rec)` after every rec is made or rebound (build, rotate swap, upgrade, clone); mined box: store items into `e.buffer`; died box: store items spilled; old saves (`rec.box` present, `rec.stores` nil): items of box container stay there, `rec.extra` built from old core box records (lane known) + old pass-through hold, `rec.ledger = ledger.new()`, `rec.box = nil`.
- `gui`: existing relative frame gains section "Lanes": two rows of `N.STORE_SLOTS` slot buttons (lane 1, lane 2) showing `rec.invs[lane]` stacks; click moves that stack to player (`player.insert`, rest stays). Box container grid (native) shows extra items.

## v16 engine output seam (V16-1) - frozen for lanes 048..051

Box of v15 plus hidden OUT arms: `N.OUT_ARMS` (8) inserters `N.OUT` per lane on box tile. Each takes from its lane store and drops belt stacks on its lane of front tile. Engine moves items out. Script does not touch items in normal flow; it looks at each box once per `N.LOOK` (30) ticks ("slow look").

Two modes per box, chosen at every look:
- **script mode**: box has pass-through filters (`rec.settings.filters[1] ~= nil`). v15 visit loop unchanged (`ledger.plan`, `ledger.hoard`, pushes by script); out arms of both lanes paused.
- **engine mode**: every other box. Out arms run. Rules dropped in this mode by author (V16-2): hoarding rule C-6, exact tier rate cap, order of leaving.

Leftover of a kind = fewer items than one belt stack `S(kind) = min(bss, stack_size(name))`. Out arm takes last slot first and waits with a partial hand until hand is full ("partial hand"); that hand is where a leftover normally waits. Engine facts (FND-0046, both versions): `pickup_target` picks store among several on tile; drop lane by `drop_position` (front tile centre +- 0.25 across travel); `inserter_stack_size_override = bss` gives stacks of exactly bss (2, 4, 20) and no waiting at bss 1; front may be belt, splitter half, underground entrance, loader; arm also drops on a sideways belt (so script must pause out arms when `belt_io.front_ok(rec)` is false).

### rec fields (new)

```lua
rec.out = { { LuaEntity, ... }, { ... } }      -- out arms per lane, owned by scripts/arms.lua
rec.out_paused = { bool, bool }                -- last pause state of out arms per lane, owned by scripts/arms.lua
rec.hand = n | nil                             -- hand size last written to out arms, owned by scripts/arms.lua
rec.ledger.left / .ready / .sweep / .held      -- slow-look memory, owned by scripts/ledger.lua (made lazily: v15 saves lack them)
```

### scripts/arms.lua (lane 048)

| Signature | Does |
|---|---|
| `arms.create(rec)` | as v15, plus: before destroying any old arm (in `rec.arms`, out `rec.out`) that holds items (`held_stack.valid_for_read`): insert them into `rec.invs[lane]` when that store is valid, rest into `rec.entity.get_inventory(defines.inventory.chest)`, rest spilled (`surface.spill_item_stack{ position = box position, stack = { name=, count=, quality= } }`). Then destroys old out arms and per lane makes `N.OUT_ARMS` arms: `create_entity{ name = N.OUT, position = box position, force = box force }`, `destructible = false`, `pickup_position = box position`, `pickup_target = rec.stores[lane]`, `drop_position = { x = px + fx + fy * s, y = py + fy - fx * s }` with `(fx, fy)` = unit step of `rec.dir` (north `0,-1`, east `1,0`, south `0,1`, west `-1,0`), `s = 0.25` lane 1, `-0.25` lane 2. Sets `rec.out_paused = { false, false }`, `rec.hand = nil`. |
| `arms.destroy(rec, keep_stores)` | as v15, plus destroys out arms, clears `rec.out`, `rec.out_paused`, `rec.hand`. Never moves items (caller drains hands first). |
| `arms.pause_out(rec, lane, paused)` | like `pause` for out arms: when `rec.out_paused[lane] ~= paused`: each valid out arm of lane `disabled_by_script = paused`; remember. No engine call when unchanged. |
| `arms.hand(rec, bss)` | when `rec.hand ~= bss`: every valid out arm of both lanes `inserter_stack_size_override = bss`; `rec.hand = bss`. No engine call when unchanged. |
| `arms.held(rec, lane) -> list` | out arms of lane holding items: array of `{ arm = k, name =, quality = <quality name>, count = }` in arm order (`held_stack.valid_for_read`, `.name`, `.quality.name`, `.count`). List and its entries are reused by next call (caller must not keep them). |
| `arms.clear_held(rec, lane, k)` | `rec.out[lane][k].held_stack.clear()` when arm valid. |
| `arms.drain_hands(rec) -> items` | fresh array `{ name =, quality =, count =, lane = }` for every valid arm (in and out, both lanes) that holds items; clears each such hand. Nil / invalid parts skipped. |
| `arms.ensure(rec) -> rebuilt` | as v15, plus broken when `rec.out` missing, an out arm invalid, or count per lane `~= N.OUT_ARMS` (v15 saves have no `rec.out`). |

### scripts/ledger.lua (lane 049) - pure, plain data

`opts = { tick =, bss =, stack_size = function(name) -> n, timeout_ticks = n (0 = off), slots =, slots_used =, need_slot = bool, flush_all = bool, n_out = n }`. `S(name) = min(bss, stack_size(name))`. Key of kind = `name .. "\0" .. quality`.

| Signature | Does |
|---|---|
| `ledger.scan(state, lane, contents, opts) -> flush, want_hands` | `contents` = `get_contents()` shape. Makes missing memory tables. Clock `state.left[lane][key]`: set to `tick` when kind first seen with `count < S`; removed when kind gone or `count >= S`. `flush` (reused array of reused pieces `{ name=, quality=, count= }`, valid until next call) = leftovers (`count < S`) that must leave now: all of them when `flush_all`; those with `timeout_ticks > 0 and tick - clock >= timeout_ticks`; plus, when `need_slot and slots_used >= slots`, the oldest leftover (smallest clock, tie name then quality) if not listed yet. Flushed kinds lose their clock. `state.ready[lane]`: looks in a row with some kind `count >= S` (reset to 0 otherwise). `want_hands = flush_all or state.ready[lane] >= 2 or tick >= (state.sweep[lane] or 0)`. |
| `ledger.hands(state, lane, held, opts) -> arms` | called only when `want_hands`. `held` = list of `arms.held`. Partial hand = `count < S(name)`. Returns reused ascending array of arm indexes whose hand must be flushed: all partial hands when `flush_all`; all partial hands when `state.ready[lane] >= 2 and #held >= n_out` (every arm busy: jam); and, when `tick >= (state.sweep[lane] or 0)` (sweep): partial hands whose key equals `state.held[lane][arm]` remembered at previous sweep (only when `timeout_ticks > 0`). At a sweep, memory `state.held[lane]` is rewritten to the partial hands not flushed (arm -> key) and `state.sweep[lane] = tick + max(60, floor(timeout_ticks / 2))` (`tick + 600` when `timeout_ticks == 0`). |

`plan`, `hoard`, `led`, `new` unchanged (script mode, LED).

### tick (lane 050), lifecycle (lane 051), belt_io (integrator)

- `belt_io.front_ok(rec) -> bool` (integrator, done): front belt-like entity exists by push rules.
- `tick.on_tick`: script-mode boxes: v15 path + `arms.pause_out(rec, lane, true)`. Engine-mode box is looked at when `(tick + rec.unit_number) % N.LOOK == 0`, or by v15 interval rule while `rec.extra` exists. Look: `circuit.evaluate`; `stopped = not enabled or rec.decon or not belt_io.front_ok(rec)`; `arms.hand(rec, bss)`; per lane: extra items first as v15 (in and out arms of lane paused while lane has extra); else `arms.pause(rec, lane, circuit off or decon)`, `arms.pause_out(rec, lane, stopped)`, `arms.skip(rec, lane, {})`; not stopped: `contents = rec.invs[lane].get_contents()`, slots as v15, `flush, want = ledger.scan(...)`; each flush piece: `belt_io.push(rec, lane, piece, bss) > 0` then `rec.invs[lane].remove(piece)`, stop at first failed push; when `want`: `held = arms.held(rec, lane)`, each index of `ledger.hands(...)`: push `{ name, quality, count }` of that hand, on success `arms.clear_held`. `rec.used[lane]`, LED as v15.
- `registry`: mined box: `arms.drain_hands(rec)` items join store items in `e.buffer`; died box: spilled with store items. Called before `arms.destroy`.

### v16 seam amendments made at integration (integrator, V16-8..13; code and offline tests are the reference)

- `names`: `N.OUT_MARGIN`, `N.out_swing(speed)`, `N.out_name(speed)`; `hidden.finalize(raw)` makes out-arm prototypes per tier belt speed.
- `arms.create`: out arm = `N.out_name(belt speed)` when that prototype exists; `pickup_position` = box position - 0.3 x drop vector; `inserter_stack_size_override` = force belt stack written at creation, `rec.hand` set.
- `belt_io.front_ok(rec)` (as above); no `behind_empty`.
- `ledger.scan`: `want_hands` = `flush_all`, or jam (`state.piled[lane]`: 16 belt stacks or more with full stacks at two looks; or store same at three looks with full stacks and `opts.can_push == true`), or sweep due (`state.sweep[lane]`, 480 ticks later while store shows a full stack).
- `ledger.hands(state, lane, held, opts) -> flush, merge`: `merge` = list of `{ name, quality, total, arms }` (partial hands of one kind reaching one belt stack; one per kind per call); jam flushes every partial hand that can not merge; timeout by clock `state.since`; next sweep `tick + 300`, sooner at timer end of oldest remembered hand, `tick + 30` when another full stack of a merged kind waits.
- `tick`: schedule `storage.sched`; front check cached 120 ticks (`rec.front_was`, `rec.front_at`); `rec.hands` for LED; counter `full`; script path also when engine can not stack (V16-10).

## v17 belt body seam (V17-1..5) - frozen for lanes 052..056

Packer of v16 with one change of body: the entity player sees is no chest any more but a belt-kind entity ("body", `N.body(tier)`, prototype type `transport-belt`, copy of tier's belt). Body is kept shut by script (nothing ever rides onto it from belts). Item path is v16: in arms take from tile behind into lane stores, out arms push belt stacks to front. Facts proven in real game on 2.0 + 2.1: `docs/FINDINGS.md` FND-0048. Sections "v15 arms box seam" and "v16 engine output seam" hold for everything this section does not change.

Words: **body** = belt-kind entity `rec.entity`; **legacy box** = chest entity of saves / blueprints up to v1.16 (`N.VARIANTS`); **hood** = unselectable picture entity over body; **mop arms** = in arms on own tile taking what outside inserters drop onto body.

Engine facts (FND-0048), same on 2.0 and 2.1:
- Belt with `get_or_create_control_behavior().connect_to_logistic_network = true` and `logistic_condition = N.SHUT` is disabled with and without a logistic network: nothing enters from belt behind or from side, items on it stay, inserters still drop onto it and pick from it. Player's `circuit_condition` stays free. `control_behavior.disabled` is true for either reason (can not tell them apart).
- Outside inserter aimed at packer tile targets body (belt), never lane stores. Arm with `pickup_target = body`, lane flags and `drop_target = store` moves items from body lane into that store.
- Stores wired by script wire to body connector: network shows store contents; belt `read_contents` (hold) adds items lying on body.
- Out arm `drop_position` at near side of a belt running across (front tile centre - 0.25 along packer travel): both packer lanes land on near lane of that belt, stacked.
- Game rotates body (`rotate`, R key); upgrade by fast-replace and blueprints carry body's control behaviour (shut condition and player's circuit condition).
- Plain belt can not replace body (own fast-replace group); placer (belt group) replaces plain belt.

### names (integrator, done)

`N.body(tier)`, `N.hood(tier)`, `N.BODIES[name] = tier`, `N.MOP_ARMS` (2), `N.SHUT` (condition table), `N.INPUT_OPEN`, `N.dir_name(direction) -> "north"|"east"|"south"|"west"`. `N.VARIANTS` = legacy boxes only. `N.PLACERS` unchanged (item still places placer).

### rec fields (changed / new)

```lua
rec.entity            -- body (transport-belt kind). rec.dir = N.dir_name(body.direction), kept in step by registry
rec.hood              -- LuaEntity N.hood(tier), owned by scripts/arms.lua
rec.mop = { {arm, ...}, {arm, ...} }   -- mop arms per lane, owned by scripts/arms.lua
rec.aim               -- "ahead" | "across": last out-arm aim written, owned by scripts/arms.lua
rec.wired             -- bool: stores wired to body connector, owned by scripts/arms.lua
rec.settings.circuit  -- { enable, cond = { first_signal, comparator, constant }, read (bool, default true), flush, flush_signal }
                      -- enable, cond, read mirror body's control behaviour (circuit.sync / circuit.apply)
```
No chest inventory anywhere: `rec.entity.get_inventory` must not be called. `rec.extra` is gone (migration puts old items into lane stores).

### prototypes (lane 052) - `prototypes/tier.lua`, `prototypes/extra.lua`

`tier.make(tier, opts)` returns, beside item / recipe / technology / placer / remnant as today:
- body `N.body(tier)`: `table.deepcopy(data.raw["transport-belt"][N.TIER[tier].belt])` with: `name`; `icon` / `icon_size` of packer; `localised_name = { "entity-name." .. N.placer(tier) }`; `minable = { mining_time = 0.2, result = N.item(tier) }`; `placeable_by = { item = N.item(tier), count = 1 }`; `fast_replaceable_group = N.FAST_REPLACE_GROUP`; `next_upgrade = opts.next and N.body(opts.next) or nil`; `related_underground_belt = nil`; `corpse = N.remnant(tier)`; `max_health = 350`; `se_allow_in_space = true`; `factoriopedia_simulation` (was on north legacy box); `hidden_in_factoriopedia = false`. Speed, belt animation set, collision, circuit connector stay belt's own. No `icons` left over from belt (set `icons = nil`).
- hood `N.hood(tier)`: `simple-entity-with-owner`, `picture` = same 4-direction picture as placer, `collision_mask = { layers = {} }`, `selectable_in_game = false`, `hidden = true`, `hidden_in_factoriopedia = true`, flags `not-on-map`, `not-blueprintable`, `not-deconstructable`, `not-upgradable`, `not-flammable`, `not-in-kill-statistics`, `not-repairable`, `placeable-neutral`; no `minable`; `max_health = 350`; `render_layer = "object"`.
- legacy boxes `N.variant(tier, dir)`: stay as `container` (old saves need them), now `hidden = true`, `hidden_in_factoriopedia = true`, `next_upgrade = nil`, no `factoriopedia_simulation`; `minable`, `placeable_by`, `inventory_size`, picture, circuit connector unchanged.
- `extra.build(raw)`: chain fix-ups (first extra tier after top vanilla, one collision box and mask per chain) apply to bodies in `raw["transport-belt"]`, no longer to containers.

### scripts/arms.lua (lane 053)

| Signature | Does |
|---|---|
| `arms.create(rec)` | as v16 on body: stores, in arms from tile behind, out arms. Changes: hands of old arms that do not fit the lane store are spilled at body position (no chest). Plus per lane `N.MOP_ARMS` mop arms (`N.ARM` at body position, `pickup_position = drop_position = body position`, lane flags, `pickup_target = rec.entity`, `drop_target = rec.stores[lane]`, `destructible = false`) in `rec.mop[lane]`; old mop arms are replaced like in arms (hands saved first). Plus hood: when `rec.hood` missing or invalid create `N.hood(rec.tier)` at body position with `direction = defines.direction[rec.dir]`, `destructible = false`; when valid and direction differs write `rec.hood.direction`. Calls `arms.shut(rec.entity)`. Sets `rec.aim = nil` then `arms.aim_out(rec, "ahead")`. Sets `rec.wired = nil` then `arms.wire(rec, rec.settings.circuit.read ~= false)`. No wires to a chest. |
| `arms.shut(entity)` | `local cb = entity.get_or_create_control_behavior()`; `cb.connect_to_logistic_network = true`; `cb.logistic_condition = N.SHUT`. |
| `arms.aim_out(rec, kind)` | `kind` = `"ahead"` or `"across"`. When `rec.aim == kind`: nothing. Else for each valid out arm of lane (s = +0.25 lane 1, -0.25 lane 2; f = unit vector of `rec.dir`; a = (f.y, -f.x)): ahead: drop = pos + f + a * s; across: drop = pos + 0.75 * f + a * (0.4 * s). `pickup_position` = pos - 0.3 * (drop - pos). Then `rec.aim = kind`. `arms.create` uses the same formula. |
| `arms.wire(rec, on)` | when `rec.wired == on`: nothing. For red and green: body connector `rec.entity.get_wire_connector(id, true)`, store connector same call; `on`: `store_connector.connect_to(body_connector, false, defines.wire_origin.script)`; off: `store_connector.disconnect_from(body_connector, defines.wire_origin.script)`. `rec.wired = on`. |
| `arms.pause(rec, lane, paused)` | as v15, and same write on mop arms of lane. |
| `arms.destroy(rec, keep_stores)` | as v16, plus mop arms and hood destroyed, `rec.mop`, `rec.hood`, `rec.aim`, `rec.wired` cleared. |
| `arms.drain_hands(rec)` | as v16, plus mop arms. |
| `arms.need_slot(rec, lane, contents)` | as v15, plus mop arms. |
| `arms.ensure(rec)` | as v16, plus broken when `rec.mop` missing, a mop arm invalid, count per lane `~= N.MOP_ARMS`, or hood missing / invalid. |

`skip`, `pause_out`, `hand`, `held`, `clear_held`, `count` unchanged (mop arms get no skip filters).

### scripts/belt_io.lua, scripts/circuit.lua (lane 054)

| Signature | Does |
|---|---|
| `belt_io.front_kind(rec) -> "ahead" \| "across" \| nil` | `"ahead"`: front neighbour by today's push rules (same direction belt, underground entrance, splitter half, loader, linked belt). `"across"`: entity on front tile is a `transport-belt` whose direction is box direction turned 90 degrees either way. Else nil (also belt facing packer). Cached with the front cache like `front_ok`. |
| `belt_io.front_ok(rec)` | `front_kind(rec) ~= nil`. |
| `belt_io.can_push(rec, lane)`, `belt_io.push(rec, lane, item, bss)` | ahead: as today. Across: both packer lanes use near lane of that belt: line index 2 when its direction == (box direction + 4) % 16, else 1; `can_push` = `line.can_insert_at(0.5)`; `push` = `line.insert_at(0.5, stack, bss)`; counters as today. |
| `circuit.sync(rec)` | body -> settings. `cb = rec.entity.get_control_behavior()`; nil: nothing. Else `c = rec.settings.circuit`: `c.enable = cb.circuit_enable_disable == true`; when `cb.circuit_condition` has `first_signal`: `c.cond = { first_signal =, comparator =, constant = }` (constant nil -> 0); `c.read = cb.read_contents == true`. |
| `circuit.apply(rec)` | settings -> body. `cb = rec.entity.get_or_create_control_behavior()`: `cb.circuit_enable_disable = c.enable == true`; `cb.circuit_condition = { first_signal = c.cond.first_signal, comparator = c.cond.comparator, constant = c.cond.constant }`; `cb.read_contents = c.read ~= false`; when reading: `cb.read_contents_mode = defines.control_behavior.transport_belt.content_read_mode.hold`. Never touches `connect_to_logistic_network` / `logistic_condition`. |

`circuit.evaluate(rec)` unchanged (reads `rec.settings.circuit`, signals via `rec.entity.get_signal`).

### scripts/gui.lua (lane 055)

Own window, no chest window to hang on: frame `sushi_packer_frame` in `player.gui.screen`, `player.opened = frame`, `frame.auto_center = true`, title bar with close button.

| Signature | Does |
|---|---|
| `gui.open(player, rec)` | builds frame (old one destroyed first): lane views (read-only: click takes nothing), items to skip, flush timeout, circuit section; sets `player.opened`. |
| `gui.on_opened(e)` | game opened body's own belt window (`e.entity` valid with rec): `gui.open(player, rec)` (replaces it). Else nothing. |
| `gui.on_open_input(e)` | `player.selected` has a rec, `player.opened == nil` (`opened_gui_type == defines.gui_type.none`), `player.can_reach_entity(selected)`: `gui.open(player, rec)`. |
| `gui.on_closed(e)` | `e.element` is our frame: destroy it. |
| `gui.on_event(e)` | as today. Circuit section fields: `circuit.enable`, `circuit.cond.*`, `circuit.read` (new checkbox "read contents"), `circuit.flush`, `circuit.flush_signal`. After a change of enable / cond / read: `circuit.apply(rec)`; after `read` change also `arms.wire(rec, c.read)`. Lane slot click: nothing (no hand take). |

### scripts/registry.lua, scripts/copy.lua (lane 056)

| Signature | Does |
|---|---|
| `registry.new_rec(entity)` | for body (`N.BODIES[entity.name]`): `tier` from name, `dir = N.dir_name(entity.direction)`; rest as today (no `in_credit` change). Nil for other names. |
| `registry.on_built(e)` | placer -> destroyed, body of that tier created at same position with same `direction`, force, quality, `last_user`. Legacy box (`N.VARIANTS`, e.g. old blueprint ghost revived) -> same swap with direction of variant. Body: rec = existing / stash / new; `arms.create` when created or recovered; tags imported; then `circuit.sync(rec)` when `entity.get_control_behavior()` is non-nil (blueprint, upgrade carried it) else `circuit.apply(rec)`; then `arms.wire(rec, rec.settings.circuit.read ~= false)`; LED as today. |
| `registry.on_removed(e)`, `registry.on_died(e)` | as v16 without chest inventory (store items + drained hands only; items lying on body are returned by engine). |
| `registry.on_rotated(e)` | `e.entity` with rec: `rec.dir = N.dir_name(e.entity.direction)`; `arms.create(rec)`; LED destroyed and created (sprite is per direction), state kept. No rec: nothing. |
| `registry.migrate(rec)` | rec whose `rec.entity` is a legacy box: read player's wires of chest connector (red, green; skip script-origin wires), chest items; create body `N.body(rec.tier)` at same position, `direction = defines.direction[rec.dir]`, force, quality; chest items -> lane 1 store, rest spilled; `arms.destroy(rec, true)` before chest is destroyed (hands saved by `arms.drain_hands` -> stores / spill); destroy chest; re-key `storage.boxes`; `rec.extra` items -> their lane store, rest spilled, `rec.extra = nil`; reconnect player's wires to body connector; `rec.settings.circuit.read = true`; `circuit.apply(rec)`; `arms.create(rec)`; LED re-created with old state; `storage.sched = nil`. Returns rec, or nil when body could not be created (rec dropped, items spilled). |
| `registry.on_configuration_changed(data)` | as today, plus: every rec with valid legacy box -> (v1.14 `rec.box` path first, as today) -> `registry.migrate(rec)`. Body recs: `arms.ensure`, `led.ensure`. |
| `registry.stash`, `registry.take_stash` | as today for bodies (`N.BODIES`); `rec.dir` from new entity direction. |
| `registry.swap`, `registry.on_rotate_input` | left as they are (legacy, no caller after integration; integrator removes). |
| `copy.default_settings()` | `circuit.read = true` added. |
| `copy.on_setup_blueprint(e)` | bodies (`N.BODIES[ent.name]`): name and direction kept, `tags.sushi_packer = export(rec)`. Legacy names no longer mapped. |
| `copy.on_settings_pasted(e)` | import as today, then `circuit.sync(dst)` (engine already pasted belt control behaviour), `arms.wire(dst, dst.settings.circuit.read ~= false)`. |
| `copy.on_cloned(e)` | as today for bodies (`N.BODIES`, dir from direction); after `arms.create`: `circuit.sync(rec)`. |

### integrator at INT

`control.lua` (filters over body, placer, legacy names; `on_player_rotated_entity` / `on_player_flipped_entity` -> `registry.on_rotated`; rotate inputs removed), `scripts/tick.lua` (no chest inventory; `belt_io.front_kind` -> `arms.aim_out`; mop pause), `scripts/sim.lua`, `scripts/led.lua`, locale, `tests/game/*`, bench.

### v17 seam amendments made at integration (integrator, V17-6..10; code and tests are the reference)

- `arms.aim_out` / `arms.create`: after writing `pickup_position` of an out arm write `pickup_target = rec.stores[lane]` again (engine re-picks target at that spot: belt body). Out arms are made with `disabled_by_script = true`, `rec.out_paused = { true, true }`. Hood re-made when `rec.hood.name ~= N.hood(rec.tier)`.
- Hood prototype: flags add `placeable-off-grid`, `collision_box` one tile, `icon`.
- `belt_io`: across belt kept beside front cache (`rec.belt.across`, `.across_line`, `.across_at`, `.across_scan`), looked for at most once per 60 ticks; `front_kind` = `cached front` -> "ahead", else across -> "across", else nil. `push` / `can_push` try ahead first, then across.
- `circuit.sync`: `cond` copied only when `circuit_condition.first_signal` is set, constant nil -> 0; `circuit.apply` uses `get_or_create_control_behavior`.
- `registry`: on_built order (V17-9); `on_rotated` clears `rec.belt`, `rec.front_was`; `migrate`: items named by `rec.extra` go to their lane once (never also as chest contents), overflow to `rec.spare` (V17-6), `arms.create` before `circuit.apply`; removal paths return and destroy spare stores.
- `tick`: `rec.front_was` holds front kind; `arms.aim_out(rec, front)` at every look; `refill(rec, lane)` while `rec.spare`; merge rest that store refuses is spilled at packer.
- `gui`: frame carries `tags.sushi_packer = unit`; `gui._refresh_open(player)`.

### v20 amendments (V20-1..3)

- `ledger.steer(state, lane) -> kinds | nil`; `ledger.scan` keeps `state.steer`, flushes several oldest leftovers on a steered lane (3 slots free); `ledger.hands` switches steering on at a jam with six or more leftover kinds in hands.
- `arms.steer(rec, lane, kinds) -> changed`; `rec.steer[lane]` = signature of list; `arms.create` clears it.
- `belt_io.push(rec, lane, item, bss, spot)`: `spot` 1..3 = further belt spots of front tile (ahead only).
- `tier._hood_layer(tier, set)`; body `connector_frame_sprites = nil`.
- gui lane slots: `quality`, `elem_tooltip`.
