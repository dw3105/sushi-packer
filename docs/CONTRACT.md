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
rec = {
  entity = LuaEntity,                            -- container variant
  unit_number = uint,
  tier = "yellow"|"red"|"blue"|"turbo",
  dir = "north"|"east"|"south"|"west",           -- side items leave
  box = <core box>,                              -- owned by scripts/core.lua, opaque to others
  settings = {
    timeout_mode = "global"|"custom",            -- S-2
    timeout_s = 0,                               -- used when custom; 0 = off
    filters = { {name = "iron-plate", quality = "normal"|nil}, ... },  -- S-3, P-1 (nil quality = any)
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
  out_credit = { 0, 0 },                         -- belt-items allowed per lane, owned by scripts/tick.lua
  in_credit = { 0, 0 },
  next_poll = 0,                                 -- idle skip (R-2), owned by scripts/tick.lua
  belt = { behind = LuaEntity|nil, front = LuaEntity|nil, scan = 0 },  -- cached neighbours, owned by scripts/belt_io.lua (PERF-1)
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
| `core.accept(box, name, quality, lane, count, stack_size, tick, passthrough) -> accepted` | `passthrough=false`: add to buffer (C-1..C-5), full stack → ready FIFO of `lane` (C-3, C-4). Needs new slot and none free → flush oldest partial (F-1, F-2) and accept 0 (F-3). All slots ready → accept 0 (F-4). May accept part. `passthrough=true`: one belt item into lane hold (P-3), `count` whole or 0 when hold busy. Returns accepted count. |
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
