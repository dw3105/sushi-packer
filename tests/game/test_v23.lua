-- v1.23 (V23-2..V23-4, REQUIREMENTS C-6, G-10, G-11, V-8): kind cap in engine way, alt-mode arrow, clean alt-mode.
-- Integrator-owned (SP-02): headless only at merge and release. Written before code, RED on v1.22.
local N = require("scripts.names")
local registry = require("scripts.registry")

local NORTH = defines.direction.north
local ARROW = "utility/fluid_indication_arrow"
local ORIENT = { north = 0, east = 0.25, south = 0.5, west = 0.75 }  -- arrow points side items leave (G-4)

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -40, -40 }, { 40, 40 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

local function find_box(surface, position)
  for _, e in ipairs(surface.find_entities_filtered({ position = position, type = "transport-belt" })) do
    if N.BODIES[e.name] then return e end
  end
end

local function front_belts(surface, force, x, n)
  local front = {}
  for i = 1, n do
    front[i] = surface.create_entity({ name = "transport-belt", position = { x + 0.5, 0.5 - i }, direction = NORTH, force = force })
  end
  return front
end

-- Yellow packer at (x+0.5, 0.5) facing north; `behind` belt tiles south moving north, `front` tiles north.
local function build(surface, force, opts)
  local x = opts.x or 0
  local behind = opts.behind or 6
  for i = 1, behind do
    surface.create_entity({ name = "transport-belt", position = { x + 0.5, 0.5 + i }, direction = NORTH, force = force })
  end
  local front = front_belts(surface, force, x, opts.front or 0)
  surface.create_entity({ name = N.placer("yellow"), position = { x + 0.5, 0.5 }, direction = NORTH, force = force, raise_built = true })
  local box = find_box(surface, { x + 0.5, 0.5 })
  assert.is_not_nil(box, "placer became box")
  local feed = surface.find_entities_filtered({ position = { x + 0.5, 0.5 + behind }, type = "transport-belt" })[1]
  return box, storage.boxes[box.unit_number], feed, front
end

local function feeder(feed, queues)
  return function()
    local left = 0
    for lane = 1, 2 do
      local q = queues[lane] or {}
      local line = feed.get_transport_line(lane)
      if #q > 0 and line.can_insert_at_back() then line.insert_at_back({ name = table.remove(q, 1), count = 1 }) end
      left = left + #q
    end
    return left
  end
end

local function rep(name, n) local t = {} for i = 1, n do t[i] = name end return t end

-- Items of `name` a lane holds: lane store + hands of every arm of that lane.
local function lane_count(rec, lane, name)
  local n = rec.invs[lane].get_item_count(name)
  for _, group in ipairs({ rec.arms[lane], rec.out[lane], rec.mop[lane] }) do
    for _, arm in ipairs(group) do
      local h = arm.held_stack
      if h.valid_for_read and h.name == name then n = n + h.count end
    end
  end
  return n
end

local function slots_of(rec, lane, name)
  local n = 0
  local inv = rec.invs[lane]
  for i = 1, #inv do
    local s = inv[i]
    if s.valid_for_read and s.name == name then n = n + 1 end
  end
  return n
end

-- Items of `name` on belts of an area (behind belts, front belts).
local function on_belts(surface, area, name)
  local n = 0
  for _, b in ipairs(surface.find_entities_filtered({ type = "transport-belt", area = area })) do
    if not N.BODIES[b.name] then
      n = n + b.get_transport_line(1).get_item_count(name) + b.get_transport_line(2).get_item_count(name)
    end
  end
  return n
end

local function run_until(step, pred, limit, check)
  local start = game.tick
  on_tick(function()
    step()
    if pred(game.tick - start) or game.tick - start > limit then check(); return false end
  end)
end

-- Arrows drawn on a packer (any implementation: found through the render API, not through rec fields).
local function arrows(box)
  local out = {}
  for _, o in ipairs(rendering.get_all_objects("sushi-packer")) do
    if o.valid and o.type == "sprite" then
      local s = o.sprite
      local name = type(s) == "table" and s.name or s
      local t = o.target
      if name == ARROW and t and t.entity == box then out[#out + 1] = o end
    end
  end
  return out
end

local ORE = "iron-ore"  -- stack size 50: cap 50, taken again at 25

describe("v23 cap", function()
  local surface, force
  before_each(function()
    surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    force.belt_stack_size_bonus = 3
    storage.belt_stack = {}
  end)

  it("jammed front: one kind stops at one item stack per lane", function()
    -- C-6: no front -> nothing leaves. 150 ore on left lane: packer takes one stack (50) plus what hands already hold,
    -- never more than 2 slots; rest waits on belt behind. Nothing lost.
    local _, rec, feed = build(surface, force, { front = 0 })
    assert.are_equal(50, prototypes.item[ORE].stack_size)
    local step = feeder(feed, { rep(ORE, 150) })
    local max_slots = 0
    run_until(function()
      step()
      local s = slots_of(rec, 1, ORE); if s > max_slots then max_slots = s end
    end, function(t) return t >= 2400 end, 2400, function()
      local held = lane_count(rec, 1, ORE)
      local waiting = on_belts(surface, { { 0, 1 }, { 1, 8 } }, ORE)
      assert.is_true(held >= 50, "one stack taken in: " .. held)
      assert.is_true(max_slots <= 2, "never more than 2 slots: " .. max_slots)
      assert.is_true(held <= 100, "at most 2 stacks incl hands: " .. held)
      assert.is_true(waiting > 0, "rest waits on belt behind: held " .. held .. " waiting " .. waiting)
    end)
  end)

  it("capped kind taken again at half", function()
    -- C-6: front appears -> stacks leave; at half a stack or less ore is taken again; all 150 pass, store never over 2 slots.
    local _, rec, feed = build(surface, force, { front = 0 })
    local step = feeder(feed, { rep(ORE, 150) })
    local max_slots, max_held, front = 0, 0, nil
    run_until(function()
      step()
      local s = slots_of(rec, 1, ORE); if s > max_slots then max_slots = s end
      local h = lane_count(rec, 1, ORE); if h > max_held then max_held = h end
    end, function(t) return t >= 1500 end, 1500, function()
      assert.is_true(max_held <= 100, "capped while jammed: " .. max_held)
      front = front_belts(surface, force, 0, 40)
      run_until(function()
        step()
        local s = slots_of(rec, 1, ORE); if s > max_slots then max_slots = s end
      end, function() return on_belts(surface, { { 0, -41 }, { 1, 0 } }, ORE) == 150 end, 4800, function()
        assert.are_equal(150, on_belts(surface, { { 0, -41 }, { 1, 0 } }, ORE), "all ore passed after jam cleared")
        assert.is_true(max_slots <= 2, "never more than 2 slots: " .. max_slots)
      end)
    end)
  end)

  it("cap on left lane does not touch right lane", function()
    -- L-3 + C-6: left lane capped and waiting; right lane takes all its 40 copper ore (below its cap).
    local _, rec, feed = build(surface, force, { front = 0 })
    local step = feeder(feed, { rep(ORE, 150), rep("copper-ore", 40) })
    run_until(step, function(t) return t >= 2400 end, 2400, function()
      assert.are_equal(40, lane_count(rec, 2, "copper-ore"), "right lane took all its kind")
      assert.is_true(lane_count(rec, 1, ORE) <= 100, "left lane capped: " .. lane_count(rec, 1, ORE))
      assert.are_equal(0, lane_count(rec, 1, "copper-ore") + lane_count(rec, 2, ORE), "lanes kept")
    end)
  end)

  it("items landing on body (mop arms) obey cap", function()
    -- C-6 on mop arms: ore put straight on the belt body, past the in arms; capped kind stays out of the store.
    local box, rec = build(surface, force, { front = 0, behind = 1 })
    assert.are_equal(100, rec.invs[1].insert({ name = ORE, count = 100 }), "left store holds two stacks already")
    local put = 0
    run_until(function()
      local line = box.get_transport_line(1)
      if put < 20 and line.can_insert_at_back() and line.insert_at_back({ name = ORE, count = 1 }) then put = put + 1 end
    end, function(t) return t >= 1200 end, 1200, function()
      assert.are_equal(20, put, "ore put on body")
      assert.are_equal(100, rec.invs[1].get_item_count(ORE), "mop arms took no capped ore into store")
    end)
  end)

  it("free front: no filter write over 3600 ticks of mixed full flow", function()
    -- C-6 cost: cap writes filters only when a kind reaches a stack; free front never lets that happen.
    remote.call("sushi-packer", "counters_on")
    local _, _, feed = build(surface, force, { front = 40 })
    local kinds = { "iron-plate", "copper-plate", "coal", "stone", "iron-ore", "copper-ore", "iron-gear-wheel" }
    local q1, q2 = {}, {}
    for i = 1, 600 do q1[i] = kinds[(i % #kinds) + 1]; q2[i] = kinds[((i + 3) % #kinds) + 1] end
    local step = feeder(feed, { q1, q2 })
    run_until(step, function(t) return t >= 3600 end, 3600, function()
      local c = storage.sp_counters
      assert.is_not_nil(c, "counters on")
      assert.is_true((c.items_in or 0) > 0 or (c.visits or 0) > 0, "packer worked")
      assert.are_equal(0, c.filter_writes, "no filter write while front is free")
      storage.sp_counters = nil
    end)
  end)
end)

describe("v23 alt", function()
  local surface, force
  before_each(function()
    surface, force = game.surfaces[1], game.forces.player
    clear(surface)
  end)

  it("every hidden part prototype has hide-alt-info", function()
    -- G-11: every hidden sushi-packer entity (arms, out arms + swing copies, lane stores, old hood, old chest bodies).
    local seen, missing = 0, {}
    for name, p in pairs(prototypes.entity) do
      if name:find("sushi-packer", 1, true) and p.hidden then
        seen = seen + 1
        if not (p.flags and p.flags["hide-alt-info"]) then missing[#missing + 1] = name end
      end
    end
    table.sort(missing)
    assert.is_true(seen >= 4, "hidden parts found: " .. seen)
    assert.are_equal("", table.concat(missing, " "), "hidden parts without hide-alt-info")
  end)

  it("packer has one alt-only arrow with fluid_indication_arrow", function()
    -- G-10: one arrow per packer, only in alt-mode, pointing side items leave.
    for i, dir in ipairs(N.DIRS) do
      local pos = { i * 3 + 0.5, 0.5 }
      surface.create_entity({ name = N.placer("yellow"), position = pos, direction = defines.direction[dir], force = force, raise_built = true })
      local box = find_box(surface, pos)
      local a = arrows(box)
      assert.are_equal(1, #a, "one arrow on " .. dir .. " packer")
      assert.is_true(a[1].only_in_alt_mode, "arrow only in alt-mode")
      assert.are_equal(ORIENT[dir], a[1].orientation, "arrow points " .. dir)
    end
  end)

  it("arrow turns with rotate", function()
    -- G-10, V-8: rotate (and flip: same handler registry.on_rotated, control.lua) turns arrow, never adds a second.
    surface.create_entity({ name = N.placer("yellow"), position = { 0.5, 0.5 }, direction = NORTH, force = force, raise_built = true })
    local box = find_box(surface, { 0.5, 0.5 })
    assert.is_true(box.rotate())
    registry.on_rotated({ entity = box })
    local a = arrows(box)
    assert.are_equal(1, #a, "still one arrow")
    assert.are_equal(ORIENT.east, a[1].orientation, "arrow now points east")
  end)

  it("arrow back after load (ensure)", function()
    -- V-8: arrow missing (e.g. save of v1.22) -> back after configuration change, one only.
    surface.create_entity({ name = N.placer("yellow"), position = { 0.5, 0.5 }, direction = defines.direction.west, force = force, raise_built = true })
    local box = find_box(surface, { 0.5, 0.5 })
    for _, o in ipairs(arrows(box)) do o.destroy() end
    assert.are_equal(0, #arrows(box))
    registry.on_configuration_changed({})
    local a = arrows(box)
    assert.are_equal(1, #a, "arrow back")
    assert.are_equal(ORIENT.west, a[1].orientation)
  end)

  it("arrow gone when packer mined", function()
    -- V-8: render object destroyed with entity.
    surface.create_entity({ name = N.placer("yellow"), position = { 0.5, 0.5 }, direction = NORTH, force = force, raise_built = true })
    local box = find_box(surface, { 0.5, 0.5 })
    local before = #rendering.get_all_objects("sushi-packer")
    local mine = arrows(box)
    assert.are_equal(1, #mine, "packer has its arrow before mining")
    game.players[1].mine_entity(box, true)
    local left = 0
    for _, o in ipairs(mine) do if o.valid then left = left + 1 end end
    assert.are_equal(0, left, "arrow destroyed with packer")
    assert.is_true(#rendering.get_all_objects("sushi-packer") < before or before == 0, "render objects went away")
  end)
end)
