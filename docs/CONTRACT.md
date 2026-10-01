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
