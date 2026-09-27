-- End-to-end behaviour on the real engine: placer -> box, belts behind and in front, real tick glue.
-- Integrator-owned (SP-02 v0.2): headless only at merge and release.
local N = require("scripts.names")
local core = require("scripts.core")

local NORTH = defines.direction.north

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -40, -40 }, { 40, 40 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

local function front_belts(surface, force, x, n, belt)
  local front = {}
  for i = 1, n do
    front[i] = surface.create_entity({ name = belt, position = { x + 0.5, 0.5 - i }, direction = NORTH, force = force })
  end
  return front
end

-- Box at (x+0.5, 0.5) facing north; `behind` belt tiles south of it moving north, `front` tiles north of it.
local function build(surface, force, opts)
  local x = opts.x or 0
  local belt = opts.belt or "transport-belt"
  local behind = opts.behind or 3
  for i = 1, behind do
    surface.create_entity({ name = belt, position = { x + 0.5, 0.5 + i }, direction = NORTH, force = force })
  end
  local front = front_belts(surface, force, x, opts.front or 20, belt)
  surface.create_entity({ name = N.placer(opts.tier or "yellow"), position = { x + 0.5, 0.5 }, direction = NORTH, force = force, raise_built = true })
  local box = surface.find_entities_filtered({ position = { x + 0.5, 0.5 }, type = "container" })[1]
  assert.is_not_nil(box, "placer became box")
  local feed = surface.find_entities_filtered({ position = { x + 0.5, 0.5 + behind }, type = "transport-belt" })[1]
  return box, storage.boxes[box.unit_number], feed, front
end

-- Feeds queued items (per lane) onto the far behind belt whenever there is room; returns items left.
local function feeder(feed, queues)
  return function()
    local left = 0
    for lane = 1, 2 do
      local q = queues[lane] or {}
      local line = feed.get_transport_line(lane)
      if #q > 0 and line.can_insert_at_back() then
        line.insert_at_back({ name = table.remove(q, 1), count = 1 })
      end
      left = left + #q
    end
    return left
  end
end

-- Output belt items in leaving order (farthest tile first, lowest position first).
local function output(front, lane)
  local seq = {}
  for i = #front, 1, -1 do
    local items = front[i].get_transport_line(lane).get_detailed_contents()
    table.sort(items, function(a, b) return a.position < b.position end)
    for _, d in ipairs(items) do seq[#seq + 1] = { name = d.stack.name, count = d.stack.count } end
  end
  return seq
end

local function total(seq, name)
  local n = 0
  for _, s in ipairs(seq) do if name == nil or s.name == name then n = n + s.count end end
  return n
end

local function runs(seq)
  local out = {}
  for _, s in ipairs(seq) do
    local last = out[#out]
    if last and last.name == s.name then last.count = last.count + s.count else out[#out + 1] = { name = s.name, count = s.count } end
  end
  return out
end

local function rep(name, n) local t = {} for i = 1, n do t[i] = name end return t end

-- Calls step() every tick until pred() is true or limit ticks pass, then check().
local function run_until(step, pred, limit, check)
  local start = game.tick
  on_tick(function()
    step()
    if pred(game.tick - start) or game.tick - start > limit then check(); return false end
  end)
end

-- FND-0013 (author 2026-09-27: yellow box stutters): longest run of ticks an item rests at belt end behind box.
local function rest_meter(belt)
  local run, max = { 0, 0 }, 0
  return function()
    for lane = 1, 2 do
      local line = belt.get_transport_line(lane)
      if #line > 0 and not line.can_insert_at(0) then
        run[lane] = run[lane] + 1
        if run[lane] > max then max = run[lane] end
      else
        run[lane] = 0
      end
    end
    return max
  end
end

describe("tick", function()
  local surface, force
  before_each(function()
    surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    force.belt_stack_size_bonus = 3
    storage.belt_stack = {}
  end)

  it("releases at belt stack", function()
    -- C-2 v6: belt stack 4 -> box releases as soon as one kind has 4 on a lane (not item stack 50).
    local _, _, feed, front = build(surface, force, {})
    local q = {}
    for i = 1, 8 do q[#q + 1] = "iron-ore"; q[#q + 1] = "copper-ore" end
    run_until(feeder(feed, { q, {} }), function() return total(output(front, 1)) >= 16 end, 1800, function()
      local seq = output(front, 1)
      assert.are_equal(16, total(seq))
      for _, s in ipairs(seq) do assert.are_equal(4, s.count, "every belt item is a full 4-stack of one kind") end
      assert.are_equal(8, total(seq, "iron-ore")); assert.are_equal(8, total(seq, "copper-ore"))
    end)
  end)

  it("releases at modded belt stack 20", function()
    -- author 2026-09-27: release whatever research sets, modded or not. Test env mod raises engine max to 20 (author save).
    assert.are_equal(20, prototypes.utility_constants.max_belt_stack_size, "test env mod loaded")
    force.belt_stack_size_bonus = 19
    storage.belt_stack = {}
    local _, _, feed, front = build(surface, force, {})
    local q = {}
    for i = 1, 40 do q[#q + 1] = "iron-ore"; q[#q + 1] = "copper-ore" end
    run_until(feeder(feed, { q, {} }), function() return total(output(front, 1)) >= 80 end, 3500, function()
      local seq = output(front, 1)
      force.belt_stack_size_bonus = 3; storage.belt_stack = {}
      assert.are_equal(80, total(seq))
      for _, s in ipairs(seq) do assert.are_equal(20, s.count, "every belt item is a full 20-stack of one kind") end
    end)
  end)

  it("belt stack 1 passes through", function()
    -- C-2 v6 + author: no belt capacity research -> every item leaves at once, lane and order kept.
    force.belt_stack_size_bonus = 0
    local _, _, feed, front = build(surface, force, {})
    local q = { "iron-ore", "copper-ore", "iron-ore", "coal", "copper-ore" }
    run_until(feeder(feed, { { table.unpack(q) }, {} }), function() return total(output(front, 1)) >= 5 end, 1200, function()
      local seq = output(front, 1)
      local names = {}
      for _, s in ipairs(seq) do assert.are_equal(1, s.count); names[#names + 1] = s.name end
      assert.are.same(q, names)
      assert.are_equal(0, total(output(front, 2)))
    end)
  end)

  it("decon marked box stops, cancel resumes", function()
    -- E-8: marked for deconstruction -> no intake, no output, LED hidden; cancel -> resumes.
    local box, rec, feed, front = build(surface, force, {})
    box.order_deconstruction(force)
    local fed = feeder(feed, { rep("iron-ore", 8), {} })
    local phase, marked_ticks = 1, 0
    on_tick(function()
      fed()
      if phase == 1 then
        marked_ticks = marked_ticks + 1
        if marked_ticks == 400 then
          assert.are_equal(0, rec.box.stored_count, "no intake while marked")
          assert.are_equal(0, total(output(front, 1)), "no output while marked")
          assert.is_false(rec.led.sprite.visible, "LED off while marked")
          box.cancel_deconstruction(force)
          phase = 2
        end
      elseif total(output(front, 1)) >= 8 then
        assert.is_true(rec.led.sprite.visible, "LED back on")
        return false
      elseif marked_ticks > 2000 then
        error("no output after cancel")
      else
        marked_ticks = marked_ticks + 1
      end
    end)
  end)

  it("lanes kept end to end", function()
    -- v6: 50 per lane -> 12 belt items of 4 leave, 2 stay as partial (no timeout).
    local _, _, feed, front = build(surface, force, {})
    run_until(feeder(feed, { rep("iron-ore", 50), rep("copper-ore", 50) }),
      function() return total(output(front, 1)) >= 48 and total(output(front, 2)) >= 48 end, 3400, function()
      assert.are_equal(48, total(output(front, 1), "iron-ore")); assert.are_equal(0, total(output(front, 1), "copper-ore"))
      assert.are_equal(48, total(output(front, 2), "copper-ore")); assert.are_equal(0, total(output(front, 2), "iron-ore"))
    end)
  end)
  it("output stacked to research size", function()
    -- v6: belt stack 4 -> 50 ore = 12 belt items of 4 out, 2 held as partial.
    local _, rec, feed, front = build(surface, force, {})
    run_until(feeder(feed, { rep("iron-ore", 50), {} }),
      function() return total(output(front, 1)) >= 48 and rec.box.stored_count == 2 end, 3400, function()
      local counts = {}
      for _, s in ipairs(output(front, 1)) do counts[#counts + 1] = s.count end
      assert.are.same(rep(4, 12), counts)
      assert.are_equal(2, rec.box.stored_count)
    end)
  end)
  it("full box flushes oldest partial and loses nothing", function()
    -- no front belt: nothing leaves; 48 distinct partials fill every slot, the 49th item must wait on the belt
    local box, rec, feed = build(surface, force, { front = 0 })
    local names = {}
    for name, p in pairs(prototypes.item) do
      if p.type == "item" and p.stack_size > 1 and not p.hidden and not p.parameter then names[#names + 1] = name end
    end
    table.sort(names)
    local q1, q2 = {}, {}
    for i = 1, 48 do if i % 2 == 1 then q1[#q1 + 1] = names[i] else q2[#q2 + 1] = names[i] end end
    local feed_step = feeder(feed, { q1, q2 })
    local extra_sent = false
    run_until(function()
      feed_step()
      if not extra_sent and core.used_slots(rec.box) == 48 then
        extra_sent = feed.get_transport_line(1).insert_at_back({ name = names[49], count = 1 })
      end
    end, function() return extra_sent and core.peek_out(rec.box, 1) ~= nil end, 3000, function()
      after_ticks(60, function()
        assert.is_true(extra_sent)
        assert.are_equal(48, core.used_slots(rec.box))
        assert.are_equal(names[1], core.peek_out(rec.box, 1).name, "oldest partial queued (F-1)")
        local on_belt = 0
        for _, b in ipairs(surface.find_entities_filtered({ type = "transport-belt", area = { { 0, 1 }, { 1, 4 } } })) do
          on_belt = on_belt + b.get_transport_line(1).get_item_count() + b.get_transport_line(2).get_item_count()
        end
        assert.are_equal(1, on_belt, "49th item waits on belt (F-3)")
        assert.are_equal(48, box.get_inventory(defines.inventory.chest).get_item_count(), "nothing lost")
        assert.are_equal("red", rec.led.state)
      end)
    end)
  end)

  it("filtered item passes between stacks", function()
    -- P-3 + v6: coal passes through, never stored; iron leaves only as full 4-stacks, coal between them.
    local box, rec, feed, front = build(surface, force, {})
    rec.settings.filters = { { name = "coal" } }
    local q = rep("iron-ore", 10); q[#q + 1] = "coal"; for i = 1, 40 do q[#q + 1] = "iron-ore" end
    run_until(feeder(feed, { q, {} }), function() return total(output(front, 1)) >= 49 end, 3400, function()
      local seq = output(front, 1)
      assert.are_equal(1, total(seq, "coal")); assert.are_equal(48, total(seq, "iron-ore"))
      for _, s in ipairs(seq) do
        if s.name == "iron-ore" then assert.are_equal(4, s.count, "iron only in full stacks") end
      end
      assert.are_equal(0, box.get_inventory(defines.inventory.chest).get_item_count("coal"))
    end)
  end)
  it("custom timeout flushes partial", function()
    local _, rec, feed, front = build(surface, force, {})
    rec.settings.timeout_mode, rec.settings.timeout_s = "custom", 2
    run_until(feeder(feed, { rep("iron-ore", 5), {} }), function() return total(output(front, 1)) >= 5 end, 600, function()
      assert.are_equal(5, total(output(front, 1), "iron-ore"))
    end)
  end)

  it("circuit disable stops both ways and hides led", function()
    local box, rec, feed, front = build(surface, force, {})
    local cc = surface.create_entity({ name = "constant-combinator", position = { 3.5, 0.5 }, force = force })
    box.get_wire_connector(defines.wire_connector_id.circuit_red, true).connect_to(cc.get_wire_connector(defines.wire_connector_id.circuit_red, true))
    rec.settings.circuit.enable = true
    rec.settings.circuit.cond = { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 5 }
    run_until(feeder(feed, { rep("iron-ore", 5), {} }), function(t) return t >= 300 end, 400, function()
      assert.are_equal(0, box.get_inventory(defines.inventory.chest).get_item_count())
      assert.are_equal(0, total(output(front, 1)))
      assert.is_false(rec.led.visible)
    end)
  end)

  it("led green then yellow", function()
    local _, rec, feed = build(surface, force, {})
    after_ticks(5, function()
      assert.are_equal("green", rec.led.state)
      feed.get_transport_line(1).insert_at_back({ name = "iron-ore", count = 1 })
      after_ticks(240, function() -- 3 belt tiles ~96 ticks + idle nap up to 30
        assert.are_equal("yellow", rec.led.state)
        assert.is_true(rec.led.visible)
      end)
    end)
  end)

  it("player removal reconciles next tick", function()
    local box, rec, feed = build(surface, force, { front = 0 })  -- v6: no front belt so all 10 stay in chest
    run_until(feeder(feed, { rep("iron-ore", 10), {} }),
      function() return box.get_inventory(defines.inventory.chest).get_item_count("iron-ore") >= 10 end, 1200, function()
      game.players[1].teleport({ 2.5, 0.5 }) -- within reach, or opening is refused
      game.players[1].opened = box
      assert.are_equal(box, game.players[1].opened, "player has box open")
      box.get_inventory(defines.inventory.chest).remove({ name = "iron-ore", count = 4 })
      after_ticks(2, function()
        assert.are.same({ { name = "iron-ore", quality = "normal", count = 6 } }, core.totals(rec.box))
        game.players[1].opened = nil
      end)
    end)
  end)

  it("blocked left lane does not stall right", function()
    local _, _, feed, front = build(surface, force, { front = 1 })
    local l1 = front[1].get_transport_line(1)
    for _, pos in ipairs({ 0, 0.25, 0.5, 0.75 }) do assert.is_true(l1.insert_at(pos, { name = "stone", count = 1 })) end
    assert.is_false(l1.can_insert_at_back(), "left front lane full")
    run_until(feeder(feed, { rep("iron-ore", 50), rep("copper-ore", 50) }),
      function() return front[1].get_transport_line(2).get_item_count("copper-ore") > 0 end, 2400, function()
      assert.is_true(front[1].get_transport_line(2).get_item_count("copper-ore") > 0)
      assert.are_equal(0, l1.get_item_count("iron-ore"))
    end)
  end)

  it("output never faster than tier", function()
    -- backlog of 3 ready stacks (150 items = 38 pieces of 4) while no front belt; then turbo front belt appears.
    -- Uncapped push would move ~0.5 piece/tick; yellow cap is 0.125 piece/lane/tick.
    local _, rec, feed = build(surface, force, { belt = "turbo-transport-belt", front = 0 })
    local front
    local opened_at
    local q = rep("iron-ore", 150)
    local step = feeder(feed, { q, {} })
    run_until(function()
      step()
      if not front and core.is_idle(rec.box) == false and #q == 0 and core.used_slots(rec.box) >= 3 and core.peek_out(rec.box, 1) then
        front = front_belts(surface, force, 0, 30, "turbo-transport-belt"); opened_at = game.tick
      end
    end, function() return opened_at and game.tick - opened_at >= 200 end, 3400, function()
      assert.is_not_nil(front, "backlog built")
      local pieces = #output(front, 1)
      assert.is_true(pieces > 0)
      assert.is_true(pieces <= math.floor(200 * N.TIER.yellow.lane_rate) + 2, "belt items " .. pieces)
    end)
  end)

  it("red tier twice yellow throughput", function()
    local _, _, yfeed, yfront = build(surface, force, { x = 0, belt = "turbo-transport-belt" })
    local _, _, rfeed, rfront = build(surface, force, { x = 6, tier = "red", belt = "turbo-transport-belt" })
    local ys, rs = feeder(yfeed, { rep("iron-ore", 400), {} }), feeder(rfeed, { rep("iron-ore", 400), {} })
    run_until(function() ys(); rs() end, function(t) return t >= 1200 end, 1300, function()
      local y, r = total(output(yfront, 1)), total(output(rfront, 1))
      assert.is_true(y > 0, "yellow moved")
      assert.is_true(r >= 1.6 * y, "yellow " .. y .. " red " .. r)
    end)
  end)

  -- FND-0011 repro matrix (author 2026-09-26: turbo box facing north, only left lane works).
  local function feed_stacked(feed, kinds, stack)
    return function()
      for lane = 1, 2 do
        local line = feed.get_transport_line(lane)
        if line.can_insert_at_back() then
          local k = kinds[lane][(game.tick % #kinds[lane]) + 1]
          line.insert_at_back({ name = k, count = stack }, stack)
        end
      end
      return 1
    end
  end
  local function lanes_report(front)
    return "left=" .. total(output(front, 1)) .. " right=" .. total(output(front, 2))
  end
  local KINDS = { { "iron-plate", "copper-plate" }, { "coal", "stone" } }

  it("north turbo box moves both lanes", function()
    local _, _, feed, front = build(surface, force, { tier = "turbo", belt = "turbo-transport-belt" })
    run_until(feed_stacked(feed, KINDS, 1), function() return false end, 1200, function()
      local r = lanes_report(front)
      assert.is_true(total(output(front, 1)) > 0 and total(output(front, 2)) > 0, r)
    end)
  end)

  it("north turbo box moves both lanes with stacked input", function()
    local _, _, feed, front = build(surface, force, { tier = "turbo", belt = "turbo-transport-belt" })
    run_until(feed_stacked(feed, KINDS, 4), function() return false end, 1200, function()
      local r = lanes_report(front)
      assert.is_true(total(output(front, 1)) > 0 and total(output(front, 2)) > 0, r)
    end)
  end)

  it("north turbo box moves both lanes with curve behind", function()
    -- belt from east turning north into box: tile south of box is a curve (east feed at y=2.5 going west, then north)
    local x = 0
    surface.create_entity({ name = "turbo-transport-belt", position = { x + 0.5, 1.5 }, direction = NORTH, force = force })
    local feed = surface.create_entity({ name = "turbo-transport-belt", position = { x + 1.5, 1.5 }, direction = defines.direction.west, force = force })
    local front = front_belts(surface, force, x, 20, "turbo-transport-belt")
    surface.create_entity({ name = N.placer("turbo"), position = { x + 0.5, 0.5 }, direction = NORTH, force = force, raise_built = true })
    run_until(feed_stacked(feed, KINDS, 4), function() return false end, 1200, function()
      local r = lanes_report(front)
      assert.is_true(total(output(front, 1)) > 0 and total(output(front, 2)) > 0, r)
    end)
  end)

  -- author layout 2026-09-27 (screenshot): turbo belt from WEST turns north on tile behind north turbo box, turbo out.
  -- Box at (0.5, 0.5) facing box_dir; curve tile behind it; feed belts on `side` of curve move toward it.
  local function curve_case(box_dir, side, over_belt)
    local D = defines.direction
    local vec = { [D.north] = { 0, -1 }, [D.east] = { 1, 0 }, [D.south] = { 0, 1 }, [D.west] = { -1, 0 } }
    local opposite = { [D.north] = D.south, [D.south] = D.north, [D.east] = D.west, [D.west] = D.east }
    local f, sv = vec[box_dir], vec[side]
    local function at(k) return { 0.5 + f[1] * k, 0.5 + f[2] * k } end
    local curve_pos = at(-1)
    surface.create_entity({ name = "turbo-transport-belt", position = curve_pos, direction = box_dir, force = force })
    local feed
    for k = 3, 1, -1 do
      feed = feed or surface.create_entity({ name = "turbo-transport-belt", position = { curve_pos[1] + sv[1] * k, curve_pos[2] + sv[2] * k }, direction = opposite[side], force = force })
      if k < 3 then surface.create_entity({ name = "turbo-transport-belt", position = { curve_pos[1] + sv[1] * k, curve_pos[2] + sv[2] * k }, direction = opposite[side], force = force }) end
    end
    local front = {}
    for k = 1, 12 do front[k] = surface.create_entity({ name = "turbo-transport-belt", position = at(k), direction = box_dir, force = force }) end
    if over_belt then  -- E-9: player places box over existing belt tile (fast replace)
      surface.create_entity({ name = "turbo-transport-belt", position = { 0.5, 0.5 }, direction = box_dir, force = force })
      local player = game.players[1]
      player.teleport({ 4.5, 4.5 })
      player.cursor_stack.set_stack({ name = N.item("turbo"), count = 1 })
      player.build_from_cursor({ position = { 0.5, 0.5 }, direction = box_dir })
      player.cursor_stack.clear()
    else
      surface.create_entity({ name = N.placer("turbo"), position = { 0.5, 0.5 }, direction = box_dir, force = force, raise_built = true })
    end
    assert.is_not_nil(surface.find_entities_filtered({ position = { 0.5, 0.5 }, type = "container" })[1], "box built")
    local curve = surface.find_entities_filtered({ position = curve_pos, type = "transport-belt" })[1]
    return feed, front, curve
  end
  local function lanes_moved(front)
    local l, r = 0, 0
    for _, b in ipairs(front) do
      for _, d in ipairs(b.get_transport_line(1).get_detailed_contents()) do l = l + d.stack.count end
      for _, d in ipairs(b.get_transport_line(2).get_detailed_contents()) do r = r + d.stack.count end
    end
    return l, r
  end

  it("north turbo box stacked 20 input both lanes", function()
    -- author save 2026-09-27: belt stack 20, input belt carries 20-stacks.
    force.belt_stack_size_bonus = 19; storage.belt_stack = {}
    local feed, front, curve = curve_case(defines.direction.north, defines.direction.west)
    run_until(feed_stacked(feed, KINDS, 20), function() return false end, 2400, function()
      local l, r = lanes_moved(front)
      local box = surface.find_entities_filtered({ position = { 0.5, 0.5 }, type = "container" })[1]
      local stored = {}
      for _, x in ipairs(box.get_inventory(defines.inventory.chest).get_contents()) do stored[#stored + 1] = x.name .. "=" .. x.count end
      force.belt_stack_size_bonus = 3; storage.belt_stack = {}
      assert.is_true(l > 0 and r > 0, "left=" .. l .. " right=" .. r .. " stored " .. table.concat(stored, ","))
    end)
  end)

  it("north turbo box curve from west", function()
    local feed, front, curve = curve_case(defines.direction.north, defines.direction.west)
    run_until(feed_stacked(feed, KINDS, 4), function() return false end, 1200, function()
      local l, r = lanes_moved(front)
      assert.is_true(curve.belt_shape ~= "straight", "behind tile is curve: " .. tostring(curve.belt_shape))
      assert.is_true(l > 0 and r > 0, "left=" .. l .. " right=" .. r .. " curve lens " .. #curve.get_transport_line(1) .. "/" .. #curve.get_transport_line(2))
    end)
  end)

  for _, dname in ipairs({ "north", "east", "south", "west" }) do
    for _, sname in ipairs({ "left", "right" }) do
      for _, over in ipairs({ false, true }) do
        it("curve behind " .. dname .. " box feed from " .. sname .. (over and " placed over belt" or ""), function()
          local D = defines.direction
          local box_dir = D[dname]
          local l = { [D.north] = D.west, [D.west] = D.south, [D.south] = D.east, [D.east] = D.north }
          local r = { [D.north] = D.east, [D.east] = D.south, [D.south] = D.west, [D.west] = D.north }
          local feed, front, curve = curve_case(box_dir, sname == "left" and l[box_dir] or r[box_dir], over)
          run_until(feed_stacked(feed, KINDS, 4), function() return false end, 1200, function()
            local a, b = lanes_moved(front)
            assert.is_true(a > 0 and b > 0, "left=" .. a .. " right=" .. b .. " shape=" .. tostring(curve.belt_shape))
          end)
        end)
      end
    end
  end

  it("north turbo box moves both lanes with curve in front", function()
    local x = 0
    for i = 1, 3 do surface.create_entity({ name = "turbo-transport-belt", position = { x + 0.5, 0.5 + i }, direction = NORTH, force = force }) end
    local feed = surface.find_entities_filtered({ position = { x + 0.5, 3.5 }, type = "transport-belt" })[1]
    local front = { surface.create_entity({ name = "turbo-transport-belt", position = { x + 0.5, -0.5 }, direction = NORTH, force = force }) }
    front[1] = front[1]
    local turn = surface.create_entity({ name = "turbo-transport-belt", position = { x + 0.5, -1.5 }, direction = defines.direction.east, force = force })
    for i = 1, 10 do front[#front + 1] = surface.create_entity({ name = "turbo-transport-belt", position = { x + 0.5 + i, -1.5 }, direction = defines.direction.east, force = force }) end
    surface.create_entity({ name = N.placer("turbo"), position = { x + 0.5, 0.5 }, direction = NORTH, force = force, raise_built = true })
    run_until(feed_stacked(feed, KINDS, 4), function() return false end, 1200, function()
      local l, r = 0, 0
      for _, b in ipairs(front) do l = l + #b.get_transport_line(1); r = r + #b.get_transport_line(2) end
      l = l + #turn.get_transport_line(1); r = r + #turn.get_transport_line(2)
      assert.is_true(l > 0 and r > 0, "left=" .. l .. " right=" .. r)
    end)
  end)
  local function never_rests(tier, belt, every)
    local _, rec, feed, front = build(surface, force, { tier = tier, belt = belt, behind = 3, front = 12 })
    local behind = surface.find_entities_filtered({ position = { 0.5, 1.5 }, type = "transport-belt" })[1]
    local meter, max, fed = rest_meter(behind), 0, 0
    local kinds = { { "iron-plate", "copper-plate" }, { "coal", "stone" } }
    run_until(function()
      if game.tick % every == 0 then
        for lane = 1, 2 do
          local line = feed.get_transport_line(lane)
          if line.can_insert_at_back() then
            line.insert_at_back({ name = kinds[lane][(fed % 2) + 1], count = 1 }); fed = fed + 1
          end
        end
      end
      for lane = 1, 2 do front[#front].get_transport_line(lane).clear() end
      max = meter()
    end, function() return false end, 1200, function()
      assert.is_true(fed > 20, "fed " .. fed)
      assert.is_true(max <= 2, tier .. " item rested at exit " .. max .. " ticks")
    end)
  end

  it("front item never rests at exit", function() never_rests("yellow", "transport-belt", 37) end)
  it("front item never rests at exit on turbo", function() never_rests("turbo", "turbo-transport-belt", 11) end)
end)
