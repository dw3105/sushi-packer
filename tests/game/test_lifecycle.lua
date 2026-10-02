local N = require("scripts.names")
local registry = require("scripts.registry")
local copy = require("scripts.copy")
local led = require("scripts.led")
local arms = require("scripts.arms")
local circuit = require("scripts.circuit")

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -30, -30 }, { 30, 30 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

local function dropped_count(surface, name)
  local count = 0
  for _, item in ipairs(surface.find_entities_filtered({ type = "item-entity" })) do
    if item.stack.valid_for_read and item.stack.name == name then count = count + item.stack.count end
  end
  return count
end

-- v17: packer = belt body (N.body, transport-belt kind). Hidden parts on its tile: 2 lane stores, in arms + mop arms
-- (both N.ARM), out arms, hood.
local ledger = require("scripts.ledger")
local function body(surface, force, tier, dir, position, raise)
  return surface.create_entity({ name = N.body(tier), position = position, direction = defines.direction[dir], force = force, raise_built = raise })
end
local function in_arms(belt) return arms.count(prototypes.entity[belt].belt_speed) + N.MOP_ARMS end
-- hidden parts (lane stores, arms) on a packer tile.
local function hidden_parts(surface, position)
  return #surface.find_entities_filtered({ position = position, radius = 0.4, name = N.STORE }),
    #surface.find_entities_filtered({ position = position, radius = 0.4, name = N.ARM })
end

-- Wires a player (or blueprint) made on a connector; lane stores hang on the box by script wires (V15-1).
local function player_wires(connector)
  local own, script_targets = {}, {}
  for _, c in ipairs(connector and connector.connections or {}) do
    if c.origin == defines.wire_origin.script then script_targets[#script_targets + 1] = c.target.owner.name
    else own[#own + 1] = c end
  end
  return own, script_targets
end

describe("lifecycle", function()
  local surface, force
  before_each(function()
    surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    game.players[1].get_main_inventory().clear()
  end)

  it("placer becomes body facing its direction", function()
    for i, dir in ipairs(N.DIRS) do
      local pos = { i * 3, 0 }
      surface.create_entity({ name = N.placer("yellow"), position = pos, direction = defines.direction[dir], force = force, raise_built = true })
      local found = surface.find_entities_filtered({ name = N.body("yellow"), area = { { pos[1] - 1, -1 }, { pos[1] + 1, 1 } } })
      assert.are_equal(1, #found)
      assert.are_equal(defines.direction[dir], found[1].direction)
      assert.are_equal(dir, registry.get(found[1]).dir)
      local hood = surface.find_entities_filtered({ name = N.hood("yellow"), area = { { pos[1] - 1, -1 }, { pos[1] + 1, 1 } } })
      assert.are_equal(1, #hood); assert.are_equal(defines.direction[dir], hood[1].direction)
      assert.are.same({ found[1].position.x, found[1].position.y }, { hood[1].position.x, hood[1].position.y }, "hood sits on packer")
    end
  end)

  it("built box gets rec and green led", function()
    local e = body(surface, force, "yellow", "north", { 0, 0 }, true)
    local rec = registry.get(e)
    assert.is_not_nil(rec)
    assert.are_equal("green", rec.led.state)
    assert.is_true(rec.led.visible)
  end)

  it("build tags apply settings", function()
    local settings = { timeout_mode = "custom", timeout_s = 12, filters = { { name = "iron-plate" } } }
    local e = body(surface, force, "yellow", "north", { 0, 0 })
    registry.on_built({ entity = e, tags = { sushi_packer = settings } })
    local rec = registry.get(e)
    assert.are_equal("custom", rec.settings.timeout_mode)
    assert.are_equal(12, rec.settings.timeout_s)
    assert.are_equal("iron-plate", rec.settings.filters[1].name)
    assert.are_equal(false, rec.settings.circuit.enable)
  end)

  it("rotation keeps stores settings and wires", function()
    -- v17: game rotates belt body; hidden parts follow (registry.on_rotated; player event not raised by script rotate)
    local e = body(surface, force, "yellow", "north", { 0.5, 0.5 }, true)
    local e2 = surface.create_entity({ name = "steel-chest", position = { 3.5, 0.5 }, force = force })
    local rec = registry.get(e); rec.settings.timeout_s = 31
    rec.invs[1].insert({ name = "iron-plate", count = 5 })
    e.get_wire_connector(defines.wire_connector_id.circuit_red, true).connect_to(e2.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
    assert.is_true(e.rotate())
    registry.on_rotated({ entity = e })
    assert.are_equal(e.unit_number, rec.unit_number, "same entity, same rec")
    assert.are_equal(31, rec.settings.timeout_s)
    assert.are_equal("east", rec.dir)
    assert.are_equal(5, rec.invs[1].get_item_count("iron-plate"))
    assert.are_equal(defines.direction.east, rec.hood.direction)
    assert.are_equal(N.led(rec.led.state, "east"), rec.led.sprite.sprite)
    local own, script_targets = player_wires(e.get_wire_connector(defines.wire_connector_id.circuit_red, false))
    assert.are_equal(1, #own, "one player wire, as before")
    assert.are_equal(e2.unit_number, own[1].target.owner.unit_number)
    assert.are.same({ N.STORE, N.STORE }, script_targets)
    assert.are.same({ 2, 2 * in_arms("transport-belt") }, { hidden_parts(surface, { 0.5, 0.5 }) })
    -- in arms now take from tile behind new direction (west of packer)
    local p = rec.arms[1][1].pickup_position
    assert.is_true(math.abs(p.x - (-0.5)) < 0.01 and math.abs(p.y - 0.5) < 0.01, "in arm aims behind: " .. p.x .. "," .. p.y)
  end)



  it("mining returns contents to player", function()
    -- E-5 on belt body: lane store items + items lying on body go to player; no part left.
    local e = body(surface, force, "yellow", "north", { 0.5, 0.5 }, true)
    local rec = registry.get(e)
    assert.are.same({ 2, 2 * in_arms("transport-belt") }, { hidden_parts(surface, { 0.5, 0.5 }) })
    assert.are_equal(3, rec.invs[1].insert({ name = "copper-plate", count = 3 }))
    assert.are_equal(5, rec.invs[2].insert({ name = "coal", count = 5 }))
    local player = game.players[1]
    player.mine_entity(e, true)
    assert.are_equal(3, player.get_main_inventory().get_item_count("copper-plate"))
    assert.are_equal(5, player.get_main_inventory().get_item_count("coal"))
    assert.are_equal(1, player.get_main_inventory().get_item_count(N.item("yellow")))
    assert.are.same({ 0, 0 }, { hidden_parts(surface, { 0.5, 0.5 }) }, "lane stores and arms gone with packer")
    assert.are_equal(0, #surface.find_entities_filtered({ name = N.hood("yellow") }), "hood gone")
    assert.is_nil(next(storage.boxes), "rec gone")
    assert.are_equal(0, dropped_count(surface, "copper-plate") + dropped_count(surface, "coal"), "nothing doubled on ground")
  end)

  it("mining with full inventory spills rest", function()
    local player = game.players[1]
    local inv = player.get_main_inventory(); inv.clear()
    inv.insert({ name = "iron-plate", count = 50000 })
    local e = body(surface, force, "yellow", "north", { 0.5, 0.5 }, true)
    local rec = registry.get(e)
    assert.are_equal(10, rec.invs[1].insert({ name = "copper-plate", count = 10 }))
    player.mine_entity(e, true)
    assert.are_equal(10, dropped_count(surface, "copper-plate"))
    assert.are_equal(0, inv.get_item_count("copper-plate"))
    assert.are.same({ 0, 0 }, { hidden_parts(surface, { 0.5, 0.5 }) }, "lane stores and arms gone with box")
  end)

  it("died packer spills contents", function()
    local e = body(surface, force, "yellow", "north", { 0.5, 0.5 }, true)
    local rec = registry.get(e)
    assert.are_equal(3, rec.invs[1].insert({ name = "copper-plate", count = 3 }))
    assert.are_equal(5, rec.invs[2].insert({ name = "coal", count = 5 }))
    e.die()
    assert.are_equal(3, dropped_count(surface, "copper-plate"))
    assert.are_equal(5, dropped_count(surface, "coal"))
    assert.are.same({ 0, 0 }, { hidden_parts(surface, { 0.5, 0.5 }) }, "lane stores and arms gone with packer")
    assert.are_equal(0, #surface.find_entities_filtered({ name = N.hood("yellow") }), "hood gone")
    assert.is_nil(next(storage.boxes), "rec gone")
  end)

  it("led set writes only on change", function()
    local e = body(surface, force, "yellow", "north", { 0, 0 })
    local rec = registry.new_rec(e); led.create(rec)
    local sprite, light = rec.led.sprite, rec.led.light
    local old_sprite, old_color = sprite.sprite, light.color
    led.set(rec, "green", true)
    assert.are_equal(old_sprite, sprite.sprite)
    assert.are_equal(old_color.r, light.color.r); assert.are_equal(old_color.g, light.color.g)
    assert.are_equal(old_color.b, light.color.b); assert.are_equal(old_color.a, light.color.a)
    led.set(rec, "red", false)
    assert.are_equal(N.led("red", "north"), sprite.sprite)
    assert.is_true(not sprite.visible); assert.is_true(not light.visible)
  end)

  it("led hidden when not visible", function()
    local e = body(surface, force, "yellow", "north", { 0, 0 })
    local rec = registry.new_rec(e); led.create(rec); led.set(rec, "yellow", false)
    assert.is_true(not rec.led.sprite.visible); assert.is_true(not rec.led.light.visible)
  end)

  it("led destroyed with box", function()
    local e = body(surface, force, "yellow", "north", { 0, 0 })
    local rec = registry.new_rec(e); led.create(rec); local sprite = rec.led.sprite
    led.destroy(rec); assert.is_true(not sprite.valid); assert.is_nil(rec.led)
  end)

  it("ensure recreates missing led", function()
    local e = body(surface, force, "yellow", "north", { 0, 0 })
    local rec = registry.new_rec(e); led.create(rec); rec.led.sprite.destroy()
    led.ensure(rec)
    assert.is_true(rec.led.sprite.valid); assert.is_true(rec.led.light.valid)
  end)

  it("blueprint stores body with tags and circuit settings", function()
    local e = body(surface, force, "yellow", "east", { 0.5, 0.5 }, true)
    local rec = registry.get(e); rec.settings.timeout_s = 47
    local inv = game.create_inventory(1); inv[1].set_stack({ name = "blueprint" })
    inv[1].create_blueprint({ surface = surface, force = force, area = { { -1, -1 }, { 2, 2 } } })
    local mapping = { get = function() return { [1] = e } end }
    copy.on_setup_blueprint({ stack = inv[1], mapping = mapping })  -- stack, never fake record (FND-0033)
    local list = inv[1].get_blueprint_entities()
    assert.are_equal(1, #list, "hidden parts stay out of blueprint")
    local be = list[1]
    assert.are_equal(N.body("yellow"), be.name)
    assert.are_equal(defines.direction.east, be.direction)
    assert.are_equal(47, be.tags.sushi_packer.timeout_s)
    assert.is_true(be.control_behavior.connect_to_logistic_network, "shut travels with blueprint")
    assert.is_nil(be.wires, "hidden wires to lane stores stay out of blueprint")
    inv.destroy()
  end)

  it("rotated blueprint builds rotated packer with settings", function()
    local e = body(surface, force, "yellow", "east", { 0.5, 0.5 }, true)
    local rec = registry.get(e); rec.settings.timeout_s = 19
    rec.settings.circuit.enable = true; rec.settings.circuit.cond = { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 5 }
    rec.settings.circuit.read = false
    circuit.apply(rec)
    local inv = game.create_inventory(1); inv[1].set_stack({ name = "blueprint" })
    inv[1].create_blueprint({ surface = surface, force = force, area = { { -1, -1 }, { 2, 2 } } })
    copy.on_setup_blueprint({ stack = inv[1], mapping = { get = function() return { [1] = e } end } })
    local ghosts = inv[1].build_blueprint({ surface = surface, force = force, position = { 5.5, 5.5 }, direction = defines.direction.east })
    assert.are_equal(1, #ghosts)
    ghosts[1].revive({ raise_revive = true })
    local built = surface.find_entities_filtered({ area = { { 4, 4 }, { 7, 7 } }, name = N.body("yellow") })
    assert.are_equal(1, #built)
    assert.are_equal(defines.direction.south, built[1].direction)
    local br = registry.get(built[1])
    assert.are_equal("south", br.dir)
    assert.are_equal(19, br.settings.timeout_s)
    assert.is_true(br.settings.circuit.enable); assert.are_equal(5, br.settings.circuit.cond.constant)
    assert.are_equal(false, br.settings.circuit.read)
    local cb = built[1].get_control_behavior()
    assert.is_true(cb.circuit_enable_disable); assert.are_equal(false, cb.read_contents)
    assert.is_true(cb.connect_to_logistic_network, "new packer is shut")
    inv.destroy()
  end)

  it("paste settings copies settings", function()
    local src = body(surface, force, "yellow", "north", { 0.5, 0.5 }, true)
    local dst = body(surface, force, "yellow", "east", { 3.5, 0.5 }, true)
    registry.get(src).settings.timeout_s = 61; local dr = registry.get(dst)
    copy.on_settings_pasted({ source = src, destination = dst })
    assert.are_equal(61, dr.settings.timeout_s)
  end)

  it("clone copies settings and box state", function()
    -- S-4 on v15 arms box: state = settings + lane store contents. Clone gets its own copy of both, own hidden parts.
    local src = body(surface, force, "yellow", "north", { 0.5, 0.5 }, true)
    local sr = registry.get(src); sr.settings.timeout_s = 7; sr.settings.filters = { { name = "coal" } }
    sr.invs[1].insert({ name = "iron-plate", count = 8 }); sr.invs[2].insert({ name = "copper-plate", count = 3 })
    surface.clone_entities({ entities = { src }, destination_offset = { 3, 0 } })
    local found = surface.find_entities_filtered({ name = N.body("yellow"), area = { { 2, -1 }, { 5, 2 } } })
    assert.are_equal(1, #found)
    local dst = found[1]
    local dr = registry.get(dst)
    assert.is_not_nil(dr, "clone registered")
    assert.are_equal(7, dr.settings.timeout_s); assert.are_equal("coal", dr.settings.filters[1].name)
    dr.settings.filters[1].name = "stone"; assert.are_equal("coal", sr.settings.filters[1].name, "settings copied deep")
    assert.are_equal(8, dr.invs[1].get_item_count("iron-plate")); assert.are_equal(0, dr.invs[2].get_item_count("iron-plate"))
    assert.are_equal(3, dr.invs[2].get_item_count("copper-plate")); assert.are_equal(0, dr.invs[1].get_item_count("copper-plate"))
    assert.is_true(dr.stores[1] ~= sr.stores[1] and dr.stores[2] ~= sr.stores[2], "clone owns its lane stores")
    dr.invs[1].remove({ name = "iron-plate", count = 1 })
    assert.are_equal(8, sr.invs[1].get_item_count("iron-plate"), "source state untouched")
    local n = in_arms("transport-belt")
    assert.are.same({ 2, 2 * n }, { hidden_parts(surface, dst.position) })
    assert.are.same({ 2, 2 * n }, { hidden_parts(surface, src.position) })
  end)

  it("configuration changed drops invalid recs", function()
    local e = body(surface, force, "yellow", "north", { 0, 0 })
    local rec = registry.new_rec(e); e.destroy(); registry.on_configuration_changed({})
    assert.is_nil(storage.boxes[rec.unit_number])
  end)

  it("upgrade keeps state", function()
    -- U-3 end to end: robots upgrade yellow east -> red east (FND-0006 path).
    local sink = surface.create_entity({ name = "electric-energy-interface", position = { 20, 20 }, force = force })
    sink.power_production = 1e9; sink.electric_buffer_size = 1e9; sink.energy = 1e9
    surface.create_entity({ name = "medium-electric-pole", position = { 18, 20 }, force = force })
    local port = surface.create_entity({ name = "roboport", position = { 16, 22 }, force = force })
    port.insert({ name = "construction-robot", count = 4 })
    surface.create_entity({ name = "storage-chest", position = { 13, 20 }, force = force }).insert({ name = N.item("red"), count = 1 })
    local chest = surface.create_entity({ name = "steel-chest", position = { 12.5, 16.5 }, force = force })
    local old = body(surface, force, "yellow", "east", { 10.5, 18.5 }, true)
    local rec = registry.get(old)
    rec.settings.timeout_s = 33
    -- state = settings + lane store contents
    assert.are_equal(1, rec.invs[1].insert({ name = "copper-plate", count = 1 }))
    assert.are_equal(6, rec.invs[2].insert({ name = "coal", count = 6 }))
    old.get_wire_connector(defines.wire_connector_id.circuit_red, true)
      .connect_to(chest.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
    assert.is_true(old.order_upgrade({ target = N.body("red"), force = force }))
    after_ticks(1200, function()
      local new = surface.find_entities_filtered({ position = { 10.5, 18.5 }, radius = 0.4, name = N.body("red") })[1]
      assert.is_not_nil(new, "upgraded")
      local nr = registry.get(new)
      assert.is_not_nil(nr, "rec carried")
      assert.are_equal(33, nr.settings.timeout_s)
      assert.are_equal("red", nr.tier); assert.are_equal("east", nr.dir)
      -- store + arm hands: a lone plate may wait in an out-arm hand (leftover, V16-3)
      local function lane_items(r, lane, name)
        local n = r.invs[lane].get_item_count(name)
        for _, group in ipairs({ r.arms[lane], r.out[lane], r.mop[lane] }) do
          for _, arm in ipairs(group) do local h = arm.held_stack; if h.valid_for_read and h.name == name then n = n + h.count end end
        end
        return n
      end
      assert.are_equal(1, lane_items(nr, 1, "copper-plate"), "store=" .. nr.invs[1].get_item_count() .. "/" .. nr.invs[2].get_item_count() .. " body=" .. new.get_transport_line(1).get_item_count() .. "/" .. new.get_transport_line(2).get_item_count()
        .. " ground_cu=" .. dropped_count(surface, "copper-plate") .. " stores_on_tile=" .. #surface.find_entities_filtered({ position = { 10.5, 18.5 }, radius = 0.4, name = N.STORE })
        .. " cu_in_all_stores=" .. (function() local n = 0; for _, st in ipairs(surface.find_entities_filtered({ name = N.STORE })) do n = n + st.get_inventory(defines.inventory.chest).get_item_count("copper-plate") end; return n end)()
        .. " coal_in_all_stores=" .. (function() local n = 0; for _, st in ipairs(surface.find_entities_filtered({ name = N.STORE })) do n = n + st.get_inventory(defines.inventory.chest).get_item_count("coal") end; return n end)()
        .. " stores_valid=" .. tostring(nr.stores[1].valid) .. " inv_is_store=" .. tostring(nr.invs[1] == nr.stores[1].get_inventory(defines.inventory.chest))
        .. " port=" .. (function() local n = 0; for _, c in ipairs(surface.find_entities_filtered({ name = "storage-chest" })) do n = n + c.get_item_count("copper-plate") end; return n end)()); assert.are_equal(0, lane_items(nr, 2, "copper-plate"))
      assert.are_equal(6, lane_items(nr, 2, "coal")); assert.are_equal(0, lane_items(nr, 1, "coal"))
      assert.are_equal(0, dropped_count(surface, "copper-plate") + dropped_count(surface, "coal"), "nothing spilled")
      assert.are_equal(defines.direction.east, new.direction)
      assert.is_true(new.get_control_behavior().connect_to_logistic_network, "upgraded packer still shut")
      local own, script_targets = player_wires(new.get_wire_connector(defines.wire_connector_id.circuit_red, false))
      assert.are_equal(1, #own, "player wire kept")
      assert.are_equal(chest.unit_number, own[1].target.owner.unit_number)
      assert.are.same({ N.STORE, N.STORE }, script_targets)
      -- hidden parts: same two lane stores, arms rebuilt for red belt speed, none left over
      assert.are.same({ 2, 2 * in_arms("fast-transport-belt") }, { hidden_parts(surface, { 10.5, 18.5 }) })
      local hoods = {}
      for _, h in ipairs(surface.find_entities_filtered({ type = "simple-entity-with-owner" })) do hoods[#hoods + 1] = h.name .. "@" .. h.position.x .. "," .. h.position.y end
      assert.are.same({ N.hood("red") .. "@10.5,18.5" }, hoods, "one hood, of new tier")
      assert.are_equal(nr.hood.name, N.hood("red"))
      assert.is_true(nr.led and nr.led.sprite.valid)
      local n = 0
      for _ in pairs(storage.boxes) do n = n + 1 end
      assert.are_equal(1, n, "old rec gone")
    end)
  end)

  it("box placed over belt replaces it", function()
    -- E-9 (FND-0009): box item over belt -> belt + its items to player, box registered.
    local player = game.players[1]
    local p0 = player.position
    local pos = { math.floor(p0.x) + 2.5, math.floor(p0.y) + 0.5 }
    local belt = surface.create_entity({ name = "transport-belt", position = pos, direction = defines.direction.east, force = force })
    belt.get_transport_line(1).insert_at(0.5, { name = "iron-plate", count = 1 })
    player.cursor_stack.set_stack({ name = N.item("yellow"), count = 1 })
    player.build_from_cursor({ position = pos, direction = defines.direction.east })
    local box = surface.find_entities_filtered({ position = pos, radius = 0.4, name = N.body("yellow") })[1]
    assert.is_not_nil(box)
    assert.is_not_nil(registry.get(box))
    assert.are_equal(defines.direction.east, box.direction)
    assert.are_equal(0, #surface.find_entities_filtered({ position = pos, radius = 0.4, name = "transport-belt" }))
    assert.are_equal(1, player.get_main_inventory().get_item_count("transport-belt"))
    assert.are_equal(1, player.get_main_inventory().get_item_count("iron-plate"))
    player.cursor_stack.clear()
  end)

  it("belt cannot replace box", function()
    local player = game.players[1]
    local p0 = player.position
    local pos = { math.floor(p0.x) + 2.5, math.floor(p0.y) + 0.5 }
    local e = body(surface, force, "yellow", "east", pos, true)
    player.cursor_stack.set_stack({ name = "transport-belt", count = 1 })
    assert.is_false(player.can_build_from_cursor({ position = pos, direction = defines.direction.east }))
    player.build_from_cursor({ position = pos, direction = defines.direction.east })
    assert.is_true(e.valid)
    assert.is_not_nil(registry.get(e))
    player.cursor_stack.clear()
  end)

  it("chest packer of old save becomes belt body", function()
    -- v17: saves up to v1.16 hold chest packers; on_configuration_changed swaps them (registry.migrate)
    local e = surface.create_entity({ name = N.variant("yellow", "east"), position = { 0.5, 0.5 }, force = force })
    local pole = surface.create_entity({ name = "medium-electric-pole", position = { 0.5, 2.5 }, force = force })
    local stores, invs = {}, {}
    for lane = 1, 2 do
      stores[lane] = surface.create_entity({ name = N.STORE, position = { 0.5, 0.5 }, force = force })
      invs[lane] = stores[lane].get_inventory(defines.inventory.chest)
      for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
        stores[lane].get_wire_connector(id, true).connect_to(e.get_wire_connector(id, true), false, defines.wire_origin.script)
      end
    end
    e.get_wire_connector(defines.wire_connector_id.circuit_red, true).connect_to(pole.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
    local settings = copy.default_settings(); settings.circuit.read = nil; settings.timeout_s = 23
    settings.circuit.enable = true; settings.circuit.cond = { first_signal = { type = "virtual", name = "signal-B" }, comparator = "<", constant = 9 }
    local rec = { entity = e, unit_number = e.unit_number, tier = "yellow", dir = "east", ledger = ledger.new(), settings = settings, enabled = true,
      circuit_state = { last_flush = false }, out_credit = { 0, 0 }, in_credit = { 0, 0 }, next_poll = 0, stores = stores, invs = invs }
    storage.boxes[e.unit_number] = rec
    invs[1].insert({ name = "copper-plate", count = 3 }); invs[2].insert({ name = "coal", count = 6 })
    e.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 5 })
    e.get_inventory(defines.inventory.chest).insert({ name = "stone", count = 7 })
    rec.extra = { { name = "stone", quality = "normal", count = 7, lane = 2 } }
    local old_unit = e.unit_number
    registry.on_configuration_changed({})
    assert.is_false(e.valid, "chest gone")
    assert.is_nil(storage.boxes[old_unit])
    local b = surface.find_entities_filtered({ position = { 0.5, 0.5 }, name = N.body("yellow") })[1]
    assert.is_not_nil(b, "belt body in its place")
    assert.are_equal(defines.direction.east, b.direction)
    assert.are_equal(rec, registry.get(b))
    assert.are_equal(23, rec.settings.timeout_s)
    assert.are_equal(3, rec.invs[1].get_item_count("copper-plate")); assert.are_equal(5, rec.invs[1].get_item_count("iron-plate"))
    assert.are_equal(6, rec.invs[2].get_item_count("coal")); assert.are_equal(7, rec.invs[2].get_item_count("stone"))
    assert.are_equal(21, rec.invs[1].get_item_count() + rec.invs[2].get_item_count(), "nothing lost, nothing doubled")
    assert.are_equal(0, dropped_count(surface, "stone") + dropped_count(surface, "iron-plate"))
    assert.is_nil(rec.extra)
    local own, script_targets = player_wires(b.get_wire_connector(defines.wire_connector_id.circuit_red, false))
    assert.are_equal(1, #own, "player wire moved to body"); assert.are_equal(pole.unit_number, own[1].target.owner.unit_number)
    assert.are.same({ N.STORE, N.STORE }, script_targets)
    local cb = b.get_control_behavior()
    assert.is_true(cb.connect_to_logistic_network, "shut"); assert.is_true(cb.circuit_enable_disable)
    assert.are_equal("signal-B", cb.circuit_condition.first_signal.name); assert.are_equal(9, cb.circuit_condition.constant)
    assert.is_true(cb.read_contents, "old packers always showed contents")
    assert.are.same({ 2, 2 * in_arms("transport-belt") }, { hidden_parts(surface, { 0.5, 0.5 }) })
    assert.are_equal(0, #surface.find_entities_filtered({ position = { 0.5, 0.5 }, type = "container", name = N.variant("yellow", "east") }))
    assert.is_true(rec.led and rec.led.sprite.valid)
  end)

  it("old save with more items than lane stores hold loses nothing and spills nothing", function()
    -- old-save run 2026-10-02 (v1.14 save): overflow was spilled, some of it onto belts on the wrong lane
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0.5, 0.5 }, force = force })
    for i = 1, 3 do surface.create_entity({ name = "transport-belt", position = { 0.5, 0.5 + i }, direction = defines.direction.north, force = force }) end
    local names = {}
    for name, p in pairs(prototypes.item) do
      if p.type == "item" and p.stack_size >= 50 and not p.hidden and not p.parameter then names[#names + 1] = name end
    end
    table.sort(names)
    local chest, extra, fed = e.get_inventory(defines.inventory.chest), {}, 0
    for i = 1, 30 do  -- 30 kinds, 15 per lane: more than 12 slots of a lane store
      chest.insert({ name = names[i], count = 3 }); fed = fed + 3
      extra[#extra + 1] = { name = names[i], quality = "normal", count = 3, lane = i % 2 + 1 }
    end
    local settings = copy.default_settings(); settings.circuit.read = nil
    local rec = { entity = e, unit_number = e.unit_number, tier = "yellow", dir = "north", ledger = ledger.new(), settings = settings, enabled = true,
      circuit_state = { last_flush = false }, out_credit = { 0, 0 }, in_credit = { 0, 0 }, next_poll = 0, extra = extra }
    storage.boxes[e.unit_number] = rec
    registry.on_configuration_changed({})
    local function inside()
      local n = rec.invs[1].get_item_count() + rec.invs[2].get_item_count()
      for lane = 1, 2 do
        for _, sp in ipairs(rec.spare and rec.spare[lane] or {}) do n = n + sp.get_inventory(defines.inventory.chest).get_item_count() end
        for _, group in ipairs({ rec.arms[lane], rec.out[lane], rec.mop[lane] }) do
          for _, arm in ipairs(group) do if arm.held_stack.valid_for_read then n = n + arm.held_stack.count end end
        end
      end
      return n
    end
    assert.is_not_nil(rec.spare, "overflow sits in spare stores")
    assert.are_equal(fed, inside(), "nothing lost at swap")
    assert.are_equal(0, #surface.find_entities_filtered({ type = "item-entity" }), "nothing on ground")
    local front = {}
    for i = 1, 30 do front[i] = surface.create_entity({ name = "transport-belt", position = { 0.5, 0.5 - i }, direction = defines.direction.north, force = force }) end
    local sink, out = front[#front], { {}, {} }
    local t = 0
    on_tick(function()
      t = t + 1
      for lane = 1, 2 do
        local line = sink.get_transport_line(lane)
        for _, c in ipairs(line.get_contents()) do out[lane][c.name] = (out[lane][c.name] or 0) + c.count end
        line.clear()
      end
      if t < 3000 then return end
      local on_belts, total_out, cross = 0, 0, 0
      for _, b in ipairs(front) do on_belts = on_belts + b.get_transport_line(1).get_item_count() + b.get_transport_line(2).get_item_count() end
      for lane = 1, 2 do
        for name, c in pairs(out[lane]) do
          total_out = total_out + c
          for _, x in ipairs(extra) do if x.name == name and x.lane ~= lane then cross = cross + c end end
        end
      end
      local msg = string.format("out=%d on_belts=%d inside=%d spare=%s", total_out, on_belts, inside(), tostring(rec.spare ~= nil))
      assert.are_equal(fed, total_out + on_belts + inside(), "nothing lost: " .. msg)
      assert.are_equal(0, cross, "lanes kept: " .. msg)
      assert.are_equal(0, #surface.find_entities_filtered({ type = "item-entity" }), "nothing on ground: " .. msg)
      assert.is_nil(rec.spare, "spare stores emptied and gone: " .. msg)
      done()
    end)
  end)

  -- author's save 2026-10-02, 0.1.18: "Error while running event sushi-packer::on_configuration_changed invalid key to 'next'
  -- ... registry.lua:254": box table was re-keyed while being walked. Crash depends on packer count (headless: 15, 16, 31..33,
  -- 63..65, 127, 128, 200 crash; 1..9, 17, 120, 129 do not).
  -- Whether it crashes also depends on the unit numbers in the table, so many counts are tried in one go.
  it("save with any number of chest packers loads: every one becomes belt body", function()
    local sizes = { 127, 128, 200 }
    for n = 1, 66 do sizes[#sizes + 1] = n end
    for _, n in ipairs(sizes) do
      clear(surface); storage.boxes = {}
      for i = 1, n do
        local x, y = (i % 20) * 2 - 19.5, math.floor(i / 20) * 2 - 9.5
        local e = surface.create_entity({ name = N.variant("yellow", "east"), position = { x, y }, force = force })
        e.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 2 })
        local settings = copy.default_settings(); settings.circuit.read = nil
        storage.boxes[e.unit_number] = { entity = e, unit_number = e.unit_number, tier = "yellow", dir = "east", ledger = ledger.new(), settings = settings,
          enabled = true, circuit_state = { last_flush = false }, out_credit = { 0, 0 }, in_credit = { 0, 0 }, next_poll = 0 }
      end
      local ok, err = pcall(registry.on_configuration_changed, {})
      assert.is_true(ok, n .. " packers: " .. tostring(err))
      assert.are_equal(n, #surface.find_entities_filtered({ name = N.body("yellow") }), n .. " packers: every chest became a body")
      assert.are_equal(0, #surface.find_entities_filtered({ name = N.variant("yellow", "east") }), n .. " packers: no chest left")
      local recs, plates = 0, 0
      for unit, rec in pairs(storage.boxes) do
        recs = recs + 1
        assert.is_true(rec.entity.valid and rec.entity.unit_number == unit and N.BODIES[rec.entity.name] ~= nil, "rec keyed by its body")
        plates = plates + rec.invs[1].get_item_count("iron-plate") + rec.invs[2].get_item_count("iron-plate")
        for lane = 1, 2 do
          for _, sp in ipairs(rec.spare and rec.spare[lane] or {}) do plates = plates + sp.get_inventory(defines.inventory.chest).get_item_count("iron-plate") end
        end
      end
      assert.are_equal(n, recs, n .. " packers: one rec each")
      assert.are_equal(2 * n, plates, n .. " packers: no plate lost")
      assert.are_equal(0, #surface.find_entities_filtered({ type = "item-entity" }), n .. " packers: nothing on ground")
    end
  end)

  it("ghost of old blueprint builds belt body", function()
    -- built legacy chest is swapped inside the build event
    surface.create_entity({ name = N.variant("red", "south"), position = { 0.5, 0.5 }, force = force, raise_built = true })
    assert.are_equal(0, #surface.find_entities_filtered({ position = { 0.5, 0.5 }, name = N.variant("red", "south") }))
    local b = surface.find_entities_filtered({ position = { 0.5, 0.5 }, name = N.body("red") })[1]
    assert.is_not_nil(b); assert.are_equal(defines.direction.south, b.direction); assert.are_equal("south", registry.get(b).dir)
  end)
end)

