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
end)
