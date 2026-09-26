local N = require("scripts.names")
local registry = require("scripts.registry")
local copy = require("scripts.copy")
local led = require("scripts.led")
local core = require("scripts.core")

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

describe("lifecycle", function()
  local surface, force, old_new_box
  local saved_core = {}
  local function fake(name, fn)
    if saved_core[name] == nil then saved_core[name] = core[name] end
    core[name] = fn
  end
  before_each(function()
    surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    game.players[1].get_main_inventory().clear()
    old_new_box = core.new_box
    saved_core = {}
  end)
  after_each(function()
    core.new_box = old_new_box
    for name, fn in pairs(saved_core) do core[name] = fn end
  end)

  it("placer becomes variant facing its direction", function()
    for i, dir in ipairs(N.DIRS) do
      local pos = { i * 3, 0 }
      surface.create_entity({ name = N.placer("yellow"), position = pos, direction = defines.direction[dir], force = force, raise_built = true })
      local found = surface.find_entities_filtered({ name = N.variant("yellow", dir), area = { { pos[1] - 1, -1 }, { pos[1] + 1, 1 } } })
      assert.are_equal(1, #found)
    end
  end)

  it("built box gets rec and green led", function()
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force, raise_built = true })
    local rec = registry.get(e)
    assert.is_not_nil(rec)
    assert.are_equal("green", rec.led.state)
    assert.is_true(rec.led.visible)
  end)

  it("build tags apply settings", function()
    local settings = { timeout_mode = "custom", timeout_s = 12, filters = { { name = "iron-plate" } } }
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    registry.on_built({ entity = e, tags = { sushi_packer = settings } })
    local rec = registry.get(e)
    assert.are_equal("custom", rec.settings.timeout_mode)
    assert.are_equal(12, rec.settings.timeout_s)
    assert.are_equal("iron-plate", rec.settings.filters[1].name)
    assert.are_equal(false, rec.settings.circuit.enable)
  end)

  it("swap keeps inventory and settings", function()
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    local rec = registry.new_rec(e); rec.settings.timeout_s = 31
    e.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 5 })
    registry.swap(rec, "east")
    assert.are_equal(31, rec.settings.timeout_s)
    assert.are_equal("east", rec.dir)
    assert.are_equal(5, rec.entity.get_inventory(defines.inventory.chest).get_item_count("iron-plate"))
  end)

  it("swap keeps circuit wires", function()
    local e1 = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    local e2 = surface.create_entity({ name = "steel-chest", position = { 3, 0 }, force = force })
    local rec = registry.new_rec(e1)
    local c1 = e1.get_wire_connector(defines.wire_connector_id.circuit_red, true)
    local c2 = e2.get_wire_connector(defines.wire_connector_id.circuit_red, true)
    c1.connect_to(c2, false)
    registry.swap(rec, "east")
    local newc = rec.entity.get_wire_connector(defines.wire_connector_id.circuit_red, false)
    assert.are_equal(1, #newc.connections)
    assert.are_equal(e2.unit_number, newc.connections[1].target.owner.unit_number)
  end)

  it("rotate input turns selected box", function()
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    registry.new_rec(e)
    local player = game.players[1]; player.selected = e
    registry.on_rotate_input({ player_index = player.index }, false)
    assert.are_equal("east", storage.boxes[next(storage.boxes)].dir)
  end)

  it("mining returns contents and hold to player", function()
    fake("hold_items", function() return { { name = "copper-plate", count = 3 } } end)
    fake("clear_hold", function() end)
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    registry.new_rec(e)
    e.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 4 })
    local player = game.players[1]
    player.mine_entity(e, true)
    assert.are_equal(4, player.get_main_inventory().get_item_count("iron-plate"))
    assert.are_equal(3, player.get_main_inventory().get_item_count("copper-plate"))
  end)

  it("mining with full inventory spills rest", function()
    fake("hold_items", function() return { { name = "copper-plate", count = 10 } } end)
    fake("clear_hold", function() end)
    local player = game.players[1]
    local inv = player.get_main_inventory(); inv.clear()
    inv.insert({ name = "iron-plate", count = 50000 })
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    registry.new_rec(e); player.mine_entity(e, true)
    assert.are_equal(10, dropped_count(surface, "copper-plate"))
  end)

  it("died box spills contents and hold", function()
    fake("hold_items", function() return { { name = "copper-plate", count = 3 } } end)
    fake("clear_hold", function() end)
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    registry.new_rec(e); e.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 4 })
    e.die()
    assert.are_equal(4, dropped_count(surface, "iron-plate"))
    assert.are_equal(3, dropped_count(surface, "copper-plate"))
  end)

  it("led set writes only on change", function()
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
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
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    local rec = registry.new_rec(e); led.create(rec); led.set(rec, "yellow", false)
    assert.is_true(not rec.led.sprite.visible); assert.is_true(not rec.led.light.visible)
  end)

  it("led destroyed with box", function()
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    local rec = registry.new_rec(e); led.create(rec); local sprite = rec.led.sprite
    led.destroy(rec); assert.is_true(not sprite.valid); assert.is_nil(rec.led)
  end)

  it("ensure recreates missing led", function()
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    local rec = registry.new_rec(e); led.create(rec); rec.led.sprite.destroy()
    led.ensure(rec)
    assert.is_true(rec.led.sprite.valid); assert.is_true(rec.led.light.valid)
  end)

  it("blueprint stores placer with tags", function()
    local e = surface.create_entity({ name = N.variant("yellow", "east"), position = { 0, 0 }, force = force })
    local rec = registry.new_rec(e); rec.settings.timeout_s = 47
    local inv = game.create_inventory(1); inv[1].set_stack({ name = "blueprint" })
    inv[1].create_blueprint({ surface = surface, force = force, area = { { -1, -1 }, { 1, 1 } } })
    local mapping = { get = function() return { [1] = e } end }
    copy.on_setup_blueprint({ record = inv[1], mapping = mapping })
    local be = inv[1].get_blueprint_entities()[1]
    assert.are_equal(N.placer("yellow"), be.name)
    assert.are_equal(defines.direction.east, be.direction)
    assert.are_equal(47, be.tags.sushi_packer.timeout_s)
    inv.destroy()
  end)

  it("rotated blueprint builds rotated box with settings", function()
    local e = surface.create_entity({ name = N.variant("yellow", "east"), position = { 0, 0 }, force = force })
    local rec = registry.new_rec(e); rec.settings.timeout_s = 19
    local inv = game.create_inventory(1); inv[1].set_stack({ name = "blueprint" })
    inv[1].create_blueprint({ surface = surface, force = force, area = { { -1, -1 }, { 1, 1 } } })
    copy.on_setup_blueprint({ record = inv[1], mapping = { get = function() return { [1] = e } end } })
    local ghosts = inv[1].build_blueprint({ surface = surface, force = force, position = { 5.5, 5.5 }, direction = defines.direction.east })
    assert.are_equal(1, #ghosts)
    ghosts[1].revive({ raise_revive = true })
    local built = surface.find_entities_filtered({ area = { { 4, 4 }, { 7, 7 } }, name = N.variant("yellow", "south") })
    assert.are_equal(1, #built)
    assert.are_equal(19, registry.get(built[1]).settings.timeout_s)
    inv.destroy()
  end)

  it("paste settings copies settings", function()
    local src = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    local dst = surface.create_entity({ name = N.variant("yellow", "east"), position = { 3, 0 }, force = force })
    registry.new_rec(src).settings.timeout_s = 61; local dr = registry.new_rec(dst)
    copy.on_settings_pasted({ source = src, destination = dst })
    assert.are_equal(61, dr.settings.timeout_s)
  end)

  it("clone copies settings and box state", function()
    local src = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
    local sr = registry.new_rec(src); sr.settings.timeout_s = 7; sr.box.nested = { count = 8 }
    surface.clone_entities({ entities = { src }, destination_offset = { 3, 0 } })
    local found = surface.find_entities_filtered({ name = N.variant("yellow", "north"), area = { { 2, -1 }, { 4, 1 } } })
    assert.are_equal(1, #found)
    local dst = found[1]
    local dr = registry.get(dst)
    assert.are_equal(7, dr.settings.timeout_s); assert.are_equal(8, dr.box.nested.count)
    dr.box.nested.count = 9; assert.are_equal(8, sr.box.nested.count)
  end)

  it("configuration changed drops invalid recs", function()
    local e = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0, 0 }, force = force })
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
    local old = surface.create_entity({ name = N.variant("yellow", "east"), position = { 10.5, 18.5 }, force = force, raise_built = true })
    local rec = registry.get(old)
    rec.settings.timeout_s = 33
    rec.box.hold[1] = { name = "copper-plate", quality = "normal", count = 1 }
    old.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 7 })
    old.get_wire_connector(defines.wire_connector_id.circuit_red, true)
      .connect_to(chest.get_wire_connector(defines.wire_connector_id.circuit_red, true), false)
    assert.is_true(old.order_upgrade({ target = N.variant("red", "east"), force = force }))
    after_ticks(1200, function()
      local new = surface.find_entities_filtered({ position = { 10.5, 18.5 }, radius = 0.4, name = N.variant("red", "east") })[1]
      assert.is_not_nil(new, "upgraded")
      local nr = registry.get(new)
      assert.is_not_nil(nr, "rec carried")
      assert.are_equal(33, nr.settings.timeout_s)
      assert.are_equal("red", nr.tier); assert.are_equal("east", nr.dir)
      assert.are_equal(1, nr.box.hold[1] and nr.box.hold[1].count)
      assert.are_equal(7, new.get_inventory(defines.inventory.chest).get_item_count("iron-plate"))
      local c = new.get_wire_connector(defines.wire_connector_id.circuit_red, false)
      assert.are_equal(1, c and #c.connections or 0)
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
    local box = surface.find_entities_filtered({ position = pos, radius = 0.4, name = N.variant("yellow", "east") })[1]
    assert.is_not_nil(box)
    assert.is_not_nil(registry.get(box))
    assert.are_equal(0, #surface.find_entities_filtered({ position = pos, radius = 0.4, type = "transport-belt" }))
    assert.are_equal(1, player.get_main_inventory().get_item_count("transport-belt"))
    assert.are_equal(1, player.get_main_inventory().get_item_count("iron-plate"))
    player.cursor_stack.clear()
  end)

  it("belt cannot replace box", function()
    local player = game.players[1]
    local p0 = player.position
    local pos = { math.floor(p0.x) + 2.5, math.floor(p0.y) + 0.5 }
    local e = surface.create_entity({ name = N.variant("yellow", "east"), position = pos, force = force, raise_built = true })
    player.cursor_stack.set_stack({ name = "transport-belt", count = 1 })
    assert.is_false(player.can_build_from_cursor({ position = pos, direction = defines.direction.east }))
    player.build_from_cursor({ position = pos, direction = defines.direction.east })
    assert.is_true(e.valid)
    assert.is_not_nil(registry.get(e))
    player.cursor_stack.clear()
  end)
end)

