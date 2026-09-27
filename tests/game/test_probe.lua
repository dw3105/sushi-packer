-- S0 probes: game facts the contract relies on, checked on 2.0 and 2.1 (docs silent or version-sensitive).
local N = require("scripts.names")

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -30, -30 }, { 30, 30 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

describe("probe", function()
  local surface, force
  before_each(function()
    surface = game.surfaces[1]
    force = game.forces.player
    clear(surface)
    force.belt_stack_size_bonus = 0
  end)

  it("line 1 is left lane on north belt", function()
    local belt = surface.create_entity({ name = "transport-belt", position = { 0.5, 0.5 }, direction = defines.direction.north, force = force })
    local left = belt.get_transport_line(1).get_line_item_position(0.5)
    local right = belt.get_transport_line(2).get_line_item_position(0.5)
    assert.is_true(left.x < belt.position.x, "line 1 west of centre on north belt")
    assert.is_true(right.x > belt.position.x, "line 2 east of centre on north belt")
  end)

  it("front-most item has lowest position", function()
    -- Measured 2026-09-26 on 2.0.77: positions shrink toward exit; items stop at 0 on belt end.
    local belt = surface.create_entity({ name = "transport-belt", position = { 0.5, 0.5 }, direction = defines.direction.north, force = force })
    local line = belt.get_transport_line(1)
    assert.is_true(line.insert_at(0.1, { name = "iron-plate", count = 1 }))
    assert.is_true(line.insert_at(0.6, { name = "copper-plate", count = 1 }))
    after_ticks(120, function()
      local front, front_pos, copper_pos = nil, math.huge, nil
      for _, d in ipairs(line.get_detailed_contents()) do
        if d.position < front_pos then front, front_pos = d.stack.name, d.position end
        if d.stack.name == "copper-plate" then copper_pos = d.position end
      end
      assert.are_equal("iron-plate", front)
      assert.are_equal(0, front_pos)
      assert.is_true(copper_pos < 0.6, "copper moved toward exit: position shrinks")
    end)
  end)

  it("insert_at_back makes stacked belt item", function()
    force.belt_stack_size_bonus = 3
    local belt = surface.create_entity({ name = "transport-belt", position = { 0.5, 0.5 }, direction = defines.direction.north, force = force })
    local line = belt.get_transport_line(2)
    assert.is_true(line.can_insert_at_back())
    assert.is_true(line.insert_at_back({ name = "iron-plate", count = 4 }, 4))
    local c = line.get_detailed_contents()
    assert.are_equal(1, #c)
    assert.are_equal(4, c[1].stack.count)
  end)

  it("placer keeps direction", function()
    local p = surface.create_entity({ name = N.placer("yellow"), position = { 2.5, 2.5 }, direction = defines.direction.east, force = force })
    assert.are_equal(defines.direction.east, p.direction)
  end)

  it("rotated blueprint turns placer ghost", function()
    local p = surface.create_entity({ name = N.placer("yellow"), position = { 4.5, 4.5 }, direction = defines.direction.east, force = force })
    local inv = game.create_inventory(1)
    inv.insert({ name = "blueprint" })
    local bp = inv[1]
    bp.create_blueprint({ surface = surface, force = force, area = { { 4, 4 }, { 5, 5 } } })
    assert.are_equal(1, bp.get_blueprint_entity_count())
    p.destroy()
    local ghosts = bp.build_blueprint({ surface = surface, force = force, position = { 10.5, 10.5 }, direction = defines.direction.east })
    assert.are_equal(1, #ghosts)
    assert.are_equal(N.placer("yellow"), ghosts[1].ghost_name)
    assert.are_equal(defines.direction.south, ghosts[1].direction, "east placer + blueprint turned 90 deg = south")
    inv.destroy()
  end)

  it("test world has one player with character", function()
    -- Lanes rely on this: GUI via player.opened, mining via player.mine_entity (measured 2026-09-26).
    assert.are_equal(1, #game.connected_players)
    assert.is_not_nil(game.players[1].character)
  end)

  it("line index 1 is front-most item", function()
    -- PERF-2: belt_io reads line[1] instead of get_detailed_contents; measured, not assumed.
    local belt = surface.create_entity({ name = "transport-belt", position = { 0.5, 0.5 }, direction = defines.direction.north, force = force })
    local line = belt.get_transport_line(1)
    assert.is_true(line.insert_at(0.6, { name = "copper-plate", count = 1 }))
    assert.is_true(line.insert_at(0.1, { name = "iron-plate", count = 1 }))
    assert.are_equal(2, #line)
    assert.are_equal("iron-plate", line[1].name)
    after_ticks(120, function()
      assert.are_equal("iron-plate", line[1].name)
      assert.are_equal("copper-plate", line[2].name)
    end)
  end)

  it("can_insert_at 0 is false only when an item sits at the exit", function()
    -- PERF-2: cheap "front item reached box" test replacing get_detailed_contents position check.
    local belt = surface.create_entity({ name = "transport-belt", position = { 0.5, 0.5 }, direction = defines.direction.north, force = force })
    local line = belt.get_transport_line(1)
    assert.is_true(line.insert_at(0.75, { name = "iron-plate", count = 1 }))
    assert.is_true(line.can_insert_at(0), "item far from exit")
    after_ticks(120, function()
      assert.is_false(line.can_insert_at(0), "item resting at exit")
    end)
  end)
  it("upgrade events", function()
    -- FND-0006: which events fire when construction robots upgrade a box one tier (U-3)?
    -- Records mod handler calls in order; state carried decides registry design.
    local log = {}
    local wrapped = {}
    local evs = {
      on_robot_built_entity = defines.events.on_robot_built_entity,
      on_robot_mined_entity = defines.events.on_robot_mined_entity,
      on_robot_pre_mined = defines.events.on_robot_pre_mined,
      on_marked_for_upgrade = defines.events.on_marked_for_upgrade,
      script_raised_destroy = defines.events.script_raised_destroy,
      on_entity_died = defines.events.on_entity_died,
    }
    for label, id in pairs(evs) do
      local original = script.get_event_handler(id)
      wrapped[id] = original or false
      script.on_event(id, function(e)
        local entity = e.entity
        local buffer = e.buffer and e.buffer.valid and e.buffer.get_item_count("iron-plate") or nil
        log[#log + 1] = { ev = label, upgrading = entity and entity.valid and entity.to_be_upgraded(), tick = game.tick, name = entity and entity.valid and entity.name,
          unit = entity and entity.valid and entity.unit_number, buffer_iron = buffer,
          inv_iron = entity and entity.valid and entity.get_inventory(defines.inventory.chest)
            and entity.get_inventory(defines.inventory.chest).get_item_count("iron-plate") }
        if original then original(e) end
      end)
    end
    local function restore()
      for id, original in pairs(wrapped) do script.on_event(id, original or nil) end
    end
    local sink = surface.create_entity({ name = "electric-energy-interface", position = { 20, 20 }, force = force })
    sink.power_production = 1e9; sink.electric_buffer_size = 1e9; sink.energy = 1e9
    surface.create_entity({ name = "medium-electric-pole", position = { 18, 20 }, force = force })
    local port = surface.create_entity({ name = "roboport", position = { 16, 22 }, force = force })
    port.insert({ name = "construction-robot", count = 4 })
    local store = surface.create_entity({ name = "storage-chest", position = { 13, 20 }, force = force })
    store.insert({ name = N.item("red"), count = 1 })
    local old = surface.create_entity({ name = N.variant("yellow", "east"), position = { 10.5, 18.5 }, force = force, raise_built = true })
    old.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 7 })
    local old_unit = old.unit_number
    storage.boxes[old_unit].settings.timeout_s = 33
    assert.is_true(old.order_upgrade({ target = N.variant("red", "east"), force = force }))
    after_ticks(1200, function()
      restore()
      local found = surface.find_entities_filtered({ position = { 10.5, 18.5 }, radius = 0.4 })
      local names = {}
      for _, e in ipairs(found) do names[#names + 1] = e.name end
      local lines = {}
      for _, l in ipairs(log) do
        lines[#lines + 1] = string.format("%s upgrading=%s tick=%s name=%s unit=%s buffer_iron=%s inv_iron=%s",
          l.ev, tostring(l.upgrading), l.tick, tostring(l.name), tostring(l.unit), tostring(l.buffer_iron), tostring(l.inv_iron))
      end
      local new = surface.find_entities_filtered({ position = { 10.5, 18.5 }, radius = 0.4, name = N.variant("red", "east") })[1]
      local rec = new and storage.boxes[new.unit_number]
      local report = "FND-0006 " .. script.active_mods["base"] .. "\n" .. table.concat(lines, "\n") ..
        "\nat position: " .. table.concat(names, ",") ..
        "\nnew inv iron=" .. tostring(new and new.get_inventory(defines.inventory.chest).get_item_count("iron-plate")) ..
        " rec=" .. tostring(rec ~= nil) .. " rec.timeout_s=" .. tostring(rec and rec.settings.timeout_s) ..
        " old rec left=" .. tostring(storage.boxes[old_unit] ~= nil)
      print(report)
      assert.is_not_nil(new, report)
      assert.are_equal(7, new.get_inventory(defines.inventory.chest).get_item_count("iron-plate"), report)
      -- Measured facts (2.0.77, 2.1.20): mined(old, to_be_upgraded, inventory already moved) then
      -- built(new, inventory carried) in SAME tick; old rec gone before new built.
      local seq = {}
      for _, l in ipairs(log) do
        if l.ev ~= "on_marked_for_upgrade" then seq[#seq + 1] = l.ev end
      end
      assert.are_same({ "on_robot_mined_entity", "on_robot_built_entity" }, seq, report)
      local mined, built = log[#log - 1], log[#log]
      assert.are_equal(mined.tick, built.tick, report)
      assert.is_true(mined.upgrading, report)
      assert.are_equal(0, mined.inv_iron, report)
      assert.is_not_nil(rec, report)
    end)
  end)

  it("placer over belt replaces belt", function()
    -- FND-0009 (E-9): placer in fast_replaceable_group "transport-belt"; variants stay "sushi-packer".
    local player = game.players[1]
    local p0 = player.position
    local pos = { math.floor(p0.x) + 2.5, math.floor(p0.y) + 0.5 }
    local belt = surface.create_entity({ name = "transport-belt", position = pos, direction = defines.direction.east, force = force })
    belt.get_transport_line(1).insert_at(0.5, { name = "iron-plate", count = 1 })
    player.get_main_inventory().clear()
    player.cursor_stack.set_stack({ name = N.item("yellow"), count = 1 })
    local can = player.can_build_from_cursor({ position = pos, direction = defines.direction.east })
    player.build_from_cursor({ position = pos, direction = defines.direction.east })
    local boxes = surface.find_entities_filtered({ position = pos, radius = 0.4, name = N.variant("yellow", "east") })
    local belts = surface.find_entities_filtered({ position = pos, radius = 0.4, type = "transport-belt" })
    local report = "can=" .. tostring(can) .. " boxes=" .. #boxes .. " belts=" .. #belts ..
      " inv_belt=" .. player.get_main_inventory().get_item_count("transport-belt") ..
      " inv_iron=" .. player.get_main_inventory().get_item_count("iron-plate")
    print("FND-0009 " .. report)
    assert.is_true(can, report)
    assert.are_equal(1, #boxes, report)
    assert.are_equal(0, #belts, report)
    assert.are_equal(1, player.get_main_inventory().get_item_count("transport-belt"), report)
    assert.are_equal(1, player.get_main_inventory().get_item_count("iron-plate"), report)
    player.cursor_stack.clear()
  end)

  it("belt over placed box refused", function()
    local player = game.players[1]
    local p0 = player.position
    local pos = { math.floor(p0.x) + 2.5, math.floor(p0.y) + 0.5 }
    surface.create_entity({ name = N.variant("yellow", "east"), position = pos, force = force, raise_built = true })
    player.cursor_stack.set_stack({ name = "transport-belt", count = 1 })
    local can = player.can_build_from_cursor({ position = pos, direction = defines.direction.east })
    player.build_from_cursor({ position = pos, direction = defines.direction.east })
    local boxes = surface.find_entities_filtered({ position = pos, radius = 0.4, name = N.variant("yellow", "east") })
    local belts = surface.find_entities_filtered({ position = pos, radius = 0.4, type = "transport-belt" })
    local report = "can=" .. tostring(can) .. " boxes=" .. #boxes .. " belts=" .. #belts
    print("FND-0009 " .. report)
    assert.is_false(can, report)
    assert.are_equal(1, #boxes, report)
    assert.are_equal(0, #belts, report)
    player.cursor_stack.clear()
  end)

  it("inserter direction picks from chest drops on belt", function()
    -- FND-0012 (U-8 scene): which direction makes an inserter at y=-1 take from chest y=-2 and drop on belt y=0?
    local report = {}
    for _, d in ipairs({ "north", "south" }) do
      local ins = surface.create_entity({ name = "inserter", position = { 10.5, -0.5 }, direction = defines.direction[d], force = force })
      report[#report + 1] = d .. ": pickup=" .. ins.pickup_position.y .. " drop=" .. ins.drop_position.y
      ins.destroy()
    end
    local text = table.concat(report, " | ")
    print("FND-0012 " .. text)
    -- Measured 2026-09-26 (2.0.77): direction = pickup side. north -> pickup -1.5, drop 0.699 (far half of belt tile).
    local ins = surface.create_entity({ name = "inserter", position = { 10.5, -0.5 }, direction = defines.direction.north, force = force })
    assert.is_true(ins.pickup_position.y < -1, text)
    assert.is_true(ins.drop_position.y > 0.5, text)
  end)
  it("max belt stack size readable at runtime", function()
    -- author 2026-09-27: release at research-set belt stack, modded or not; cap = utility constant, not literal 4.
    local ok, value = pcall(function() return prototypes.utility_constants.max_belt_stack_size end)
    print("PROBE max_belt_stack_size ok=" .. tostring(ok) .. " value=" .. tostring(value))
    assert.is_true(ok, tostring(value))
    assert.are_equal(20, value, "test env mod raises engine max 4 -> 20 (author save)")
  end)
end)

