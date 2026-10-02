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
  -- "upgrade events" probe (FND-0006, chest body) retired in v17: lifecycle > upgrade keeps state covers belt body.

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
    local boxes = surface.find_entities_filtered({ position = pos, radius = 0.4, name = N.body("yellow") })
    local belts = surface.find_entities_filtered({ position = pos, radius = 0.4, name = "transport-belt" })
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
    surface.create_entity({ name = N.body("yellow"), position = pos, direction = defines.direction.east, force = force, raise_built = true })
    player.cursor_stack.set_stack({ name = "transport-belt", count = 1 })
    local can = player.can_build_from_cursor({ position = pos, direction = defines.direction.east })
    player.build_from_cursor({ position = pos, direction = defines.direction.east })
    local boxes = surface.find_entities_filtered({ position = pos, radius = 0.4, name = N.body("yellow") })
    local belts = surface.find_entities_filtered({ position = pos, radius = 0.4, name = "transport-belt" })
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
  it("splitter transport line numbering", function()
    -- FND-0015 probe (author blueprint 2026-09-27): which splitter line index = which half, input/output, lane.
    local N_ = defines.direction.north
    local names = {}
    for k, v in pairs(defines.transport_line or {}) do names[#names + 1] = k .. "=" .. v end
    table.sort(names)
    -- inputs: belt behind LEFT half only (north splitter at x 0..2, left half = x 0..1), items on its left lane only
    local sp = surface.create_entity({ name = "turbo-splitter", position = { 1, 0.5 }, direction = N_, force = force })
    local feed = surface.create_entity({ name = "turbo-transport-belt", position = { 0.5, 1.5 }, direction = N_, force = force })
    feed.get_transport_line(1).insert_at(0.5, { name = "iron-plate", count = 1 })
    local res = {}
    local snaps = {}
    for t = 1, 8 do after_ticks(t, function()
      local row = {}
      for i = 1, 8 do if #sp.get_transport_line(i) > 0 then row[#row + 1] = i end end
      snaps[#snaps + 1] = "t" .. t .. ":" .. table.concat(row, "/")
    end) end
    after_ticks(9, function()
      assert.are_equal("t1: t2: t3: t4:1 t5:1 t6:1 t7:1 t8:1", table.concat(snaps, " "), "left half left lane input = line 1")
      -- outputs: clear, front belt only at LEFT half, put one item per output index in turn
      feed.destroy()
      for i = 1, 8 do sp.get_transport_line(i).clear() end
      local fl = surface.create_entity({ name = "turbo-transport-belt", position = { 0.5, -0.5 }, direction = N_, force = force })
      local idx = 5
      local function try()
        for lane = 1, 2 do fl.get_transport_line(lane).clear() end
        sp.get_transport_line(idx).insert_at(0.3, { name = "copper-plate", count = 1 })
        after_ticks(20, function()
          local want = ({ [5] = { 1, 0, 0 }, [6] = { 0, 1, 0 }, [7] = { 0, 0, 1 }, [8] = { 0, 0, 1 } })[idx]
          assert.are_same(want, { #fl.get_transport_line(1), #fl.get_transport_line(2), #sp.get_transport_line(idx) }, "output line " .. idx)
          sp.get_transport_line(idx).clear()
          idx = idx + 1
          if idx <= 8 then try() else
            fl.destroy(); sp.destroy()
            assert.are_equal(1, defines.transport_line.left_line); assert.are_equal(5, defines.transport_line.left_split_line)
          end
        end)
      end
      try()
    end)
  end)
  it("loader transport line numbering", function()
    -- FND-0016 probe (author blueprint 2026-09-27: 1x1 loaders around west box).
    local W = defines.direction.west
    local out = {}
    for _, name in ipairs({ "loader-1x1" }) do
      -- output loader facing west at x=1, chest east of it at x=2: items leave loader toward x=0
      local chest = surface.create_entity({ name = "infinity-chest", position = { 2.5, 0.5 }, force = force })
      chest.set_infinity_container_filter(1, { name = "iron-plate", count = 50, mode = "exactly" })
      local l = surface.create_entity({ name = name, position = { 1.5, 0.5 }, direction = W, type = "output", force = force })
      out[#out + 1] = name .. " max=" .. l.get_max_transport_line_index() .. " type=" .. l.type .. " ltype=" .. l.loader_type
      local snaps = {}
      for t = 10, 40, 30 do after_ticks(t, function()
        local row = {}
        for i = 1, l.get_max_transport_line_index() do
          local line = l.get_transport_line(i)
          row[#row + 1] = i .. "=" .. #line .. (line.can_insert_at(0) and "" or "@exit") .. string.format("/len%.2f", line.line_length)
        end
        snaps[#snaps + 1] = "t" .. t .. " " .. table.concat(row, " ")
      end) end
      after_ticks(45, function()
        l.destroy(); chest.destroy()
        -- input loader facing west at x=1 into chest at x=0: insert into each line, see which reaches chest
        local sink = surface.create_entity({ name = "wooden-chest", position = { 0.5, 0.5 }, force = force })
        local li = surface.create_entity({ name = name, position = { 1.5, 0.5 }, direction = W, type = "input", force = force })
        local ok = {}
        for i = 1, li.get_max_transport_line_index() do
          local r = li.get_transport_line(i).insert_at_back({ name = "copper-plate", count = 1 })
          ok[#ok + 1] = i .. (r and "+" or "-")
        end
        after_ticks(30, function()
          local got = sink.get_item_count("copper-plate")
          li.destroy(); sink.destroy()
          assert.are_equal("loader-1x1 max=2 type=loader-1x1 ltype=output", table.concat(out, " "))
          assert.is_true(snaps[2]:find("1=2@exit", 1, true) ~= nil and snaps[2]:find("2=2@exit", 1, true) ~= nil, table.concat(snaps, " | "))
          assert.are_equal("1+,2+", table.concat(ok, ","))
          assert.are_equal(2, got)
        end)
      end)
    end
  end)
  it("library record reachable", function()
    -- FND-0033 S0 (2.0.77 + 2.1.20, 2026-09-30): test game has empty libraries, no cursor record; no API creates
    -- a LuaRecord. So library-record tests use offline fake (tests/offline/test_copy.lua). Red here = real record
    -- became reachable: move repro to game test.
    assert.are_equal(0, #game.blueprints)
    for _, pl in pairs(game.players) do
      assert.are_equal(0, #pl.blueprints)
      assert.is_nil(pl.cursor_record)
    end
  end)
end)

