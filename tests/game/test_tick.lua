-- End-to-end behaviour on the real engine: placer -> box, belts behind and in front, real tick glue.
-- Integrator-owned (SP-02 v0.2): headless only at merge and release.
local N = require("scripts.names")
local intake = require("tests.game.intake_rig")

local NORTH = defines.direction.north

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -40, -40 }, { 40, 40 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

-- v17: packer = belt body (transport-belt kind) on the tile; lane stores, arms, hood sit on the same tile.
local function find_box(surface, position)
  for _, e in ipairs(surface.find_entities_filtered({ position = position, type = "transport-belt" })) do
    if N.BODIES[e.name] then return e end
  end
end

-- v16: items waiting in arm hands of a lane (in arms and out arms). Leftovers below one belt stack wait in an
-- out-arm hand, not in the lane store (V16-3).
local function hands(rec, lane, name)
  local n = 0
  for _, group in ipairs({ rec.arms[lane], rec.out[lane], rec.mop[lane] }) do
    for _, arm in ipairs(group) do
      local h = arm.held_stack
      if h.valid_for_read and (name == nil or h.name == name) then n = n + h.count end
    end
  end
  return n
end

local function lane_count(rec, lane, name) return rec.invs[lane].get_item_count(name) + hands(rec, lane, name) end

-- v16: items a box holds = both lane stores + arm hands + box container (extra / outside items).
local function stored(rec, name)
  return lane_count(rec, 1, name) + lane_count(rec, 2, name)
    + rec.entity.get_transport_line(1).get_item_count(name) + rec.entity.get_transport_line(2).get_item_count(name)
end

local function used_slots(rec, lane)
  return #rec.invs[lane] - rec.invs[lane].count_empty_stacks()
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
  local box = find_box(surface, { x + 0.5, 0.5 })
  assert.is_not_nil(box, "placer became box")
  assert.are_equal(N.body(opts.tier or "yellow"), box.name)
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
    -- C-2 v6 + author: no belt capacity research -> every item leaves at once, lane kept.
    -- v15 (V15-1): items leave ordered by kind (first seen), not by single-item arrival -> same items per lane, any order.
    force.belt_stack_size_bonus = 0
    local _, rec, feed, front = build(surface, force, {})
    local q = { "iron-ore", "copper-ore", "iron-ore", "coal", "copper-ore" }
    run_until(feeder(feed, { { table.unpack(q) }, {} }), function() return total(output(front, 1)) >= 5 end, 1200, function()
      local seq = output(front, 1)
      local names = {}
      for _, s in ipairs(seq) do assert.are_equal(1, s.count, "nothing stacked"); names[#names + 1] = s.name end
      local want = { table.unpack(q) }
      table.sort(want); table.sort(names)
      assert.are.same(want, names)
      assert.are_equal(0, total(output(front, 2)), "lane kept")
      assert.are_equal(0, stored(rec), "nothing held back")
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
          assert.are_equal(0, stored(rec), "no intake while marked")
          local waiting = 0
          for _, b in ipairs(surface.find_entities_filtered({ type = "transport-belt", area = { { 0, 1 }, { 1, 4 } } })) do
            waiting = waiting + b.get_transport_line(1).get_item_count("iron-ore")
          end
          assert.are_equal(8, waiting, "fed items wait on belt behind box")
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
      function() return total(output(front, 1)) >= 48 and lane_count(rec, 1, "iron-ore") == 2 end, 3400, function()
      local counts = {}
      for _, s in ipairs(output(front, 1)) do counts[#counts + 1] = s.count end
      assert.are.same(rep(4, 12), counts)
      assert.are_equal(2, lane_count(rec, 1, "iron-ore"), "partial held in left lane (store or out-arm hand)")
      assert.are_equal(2, stored(rec), "nothing else held")
    end)
  end)
  it("full box flushes oldest partial and loses nothing", function()
    -- F-1, F-3 on lane stores (24 slots per lane since v1.21, V21-2; 12 in v1.15..v1.20): no front belt -> nothing
    -- leaves; one distinct partial per slot fills every slot, one kind more on left lane must wait on the belt. Front
    -- belt appears -> oldest partial of each lane leaves first, as one smaller belt item; waiting kind gets its slot.
    local SLOTS = N.STORE_SLOTS
    assert.are_equal(24, SLOTS)
    local box, rec, feed = build(surface, force, { front = 0 })
    local names = {}
    for name, p in pairs(prototypes.item) do
      if p.type == "item" and p.stack_size > 1 and not p.hidden and not p.parameter then names[#names + 1] = name end
    end
    table.sort(names)
    local q1, q2 = {}, {}
    for i = 1, 2 * SLOTS do if i % 2 == 1 then q1[#q1 + 1] = names[i] else q2[#q2 + 1] = names[i] end end
    local extra_name = names[2 * SLOTS + 1]
    local feed_step = feeder(feed, { q1, q2 })
    local extra_sent, sent_at = false, nil
    local function behind_count()
      local n = 0
      for _, b in ipairs(surface.find_entities_filtered({ type = "transport-belt", area = { { 0, 1 }, { 1, 4 } } })) do
        n = n + b.get_transport_line(1).get_item_count() + b.get_transport_line(2).get_item_count()
      end
      return n
    end
    run_until(function()
      feed_step()
      if not extra_sent and used_slots(rec, 1) == SLOTS and used_slots(rec, 2) == SLOTS then
        extra_sent = feed.get_transport_line(1).insert_at_back({ name = extra_name, count = 1 })
        if extra_sent then sent_at = game.tick end
      end
    end, function() return extra_sent and game.tick - sent_at >= 240 end, 3000, function()
      assert.is_true(extra_sent, "both lane stores filled")
      assert.are_equal(SLOTS, used_slots(rec, 1)); assert.are_equal(SLOTS, used_slots(rec, 2))
      assert.are_equal(1, behind_count(), "13th kind waits on belt (F-3)")
      assert.are_equal(0, rec.invs[1].get_item_count(extra_name) + rec.invs[2].get_item_count(extra_name))
      assert.are_equal(2 * SLOTS, rec.invs[1].get_item_count() + rec.invs[2].get_item_count(), "nothing lost")
      assert.are_equal(0, box.get_transport_line(1).get_item_count() + box.get_transport_line(2).get_item_count(), "belt body stays empty")
      assert.are_equal("red", rec.led.state)
      local front = front_belts(surface, force, 0, 20, "transport-belt")
      -- v16: front belt appears -> out arms wake at next look and take leftovers into their hands (8 per lane):
      -- store slots come free, waiting 13th kind gets in. Nothing needs a flush, nothing is lost.
      run_until(function() end, function() return lane_count(rec, 1, extra_name) == 1 end, 900, function()
        after_ticks(120, function()
          local left, right = output(front, 1), output(front, 2)
          assert.are_equal(1, lane_count(rec, 1, extra_name), "waiting kind got into left lane")
          assert.are_equal(0, behind_count(), "belt behind is free again")
          assert.are_equal(0, lane_count(rec, 2, names[1]) + total(right, names[1]), "lane kept")
          for _, s in ipairs(left) do assert.are_equal(1, s.count, "only single leftovers could leave") end
          local kept = lane_count(rec, 1) + lane_count(rec, 2)
          assert.are_equal(2 * SLOTS + 1, kept + total(left) + total(right) + behind_count(), "nothing lost, nothing made")
          assert.are_equal(0, box.get_transport_line(1).get_item_count() + box.get_transport_line(2).get_item_count(), "belt body stays empty")
        end)
      end)
    end)
  end)

  it("filtered item passes between stacks", function()
    -- P-3 + v6: coal passes through, never stored; iron leaves only as full 4-stacks, coal between them.
    local box, rec, feed, front = build(surface, force, {})
    rec.settings.filters = { { name = "coal" } }
    local q = rep("iron-ore", 10); q[#q + 1] = "coal"; for i = 1, 40 do q[#q + 1] = "iron-ore" end
    -- v17: last two ore may still ride the belt behind when the 49th item is out: wait until they are inside
    run_until(feeder(feed, { q, {} }), function() return total(output(front, 1)) >= 49 and stored(rec) >= 2 end, 3400, function()
      local seq = output(front, 1)
      assert.are_equal(1, total(seq, "coal")); assert.are_equal(48, total(seq, "iron-ore"))
      for _, s in ipairs(seq) do
        if s.name == "iron-ore" then assert.are_equal(4, s.count, "iron only in full stacks") end
      end
      assert.are_equal(0, stored(rec, "coal"), "coal not kept")
      local behind_n = 0
      for _, b in ipairs(surface.find_entities_filtered({ area = { { 0, 1 }, { 1, 5 } }, type = "transport-belt" })) do
        behind_n = behind_n + b.get_transport_line(1).get_item_count() + b.get_transport_line(2).get_item_count()
      end
      assert.are_equal(2, stored(rec), "only iron partial kept; store=" .. rec.invs[1].get_item_count() .. "/" .. rec.invs[2].get_item_count()
        .. " hands=" .. hands(rec, 1) .. "/" .. hands(rec, 2) .. " behind=" .. behind_n .. " out=" .. total(seq) .. " ground="
        .. #surface.find_entities_filtered({ type = "item-entity" }))
      -- P-3: coal is its own belt item, never inside an iron stack run piece
      for _, s in ipairs(seq) do if s.name == "coal" then assert.are_equal(1, s.count) end end
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
      assert.are_equal(0, stored(rec), "no intake while disabled")
      local waiting = 0
      for _, b in ipairs(surface.find_entities_filtered({ type = "transport-belt", area = { { 0, 1 }, { 1, 4 } } })) do
        waiting = waiting + b.get_transport_line(1).get_item_count("iron-ore")
      end
      assert.are_equal(5, waiting, "fed items wait on belt behind box")
      assert.are_equal(0, total(output(front, 1)))
      assert.is_false(rec.led.visible)
      assert.is_false(rec.led.sprite.visible)
    end)
  end)

  it("led green then yellow", function()
    local _, rec, feed = build(surface, force, {})
    after_ticks(5, function()
      assert.are_equal("green", rec.led.state)
      feed.get_transport_line(1).insert_at_back({ name = "iron-ore", count = 1 })
      after_ticks(360, function() -- 3 belt tiles ~96 ticks, then item waits in an out-arm hand: LED sees it at next hand look (<= 120 ticks)
        assert.are_equal("yellow", rec.led.state)
        assert.is_true(rec.led.visible)
      end)
    end)
  end)

  it("player removal reconciles next tick", function()
    -- E-6 on v15 arms box (old D-1 reconcile is gone): player takes items out of a lane store by hand; box carries
    -- on with what is left: pushes only what is really there, loses nothing, makes nothing.
    local box, rec, feed = build(surface, force, { front = 0 })  -- no front belt so all 10 stay in left lane store
    run_until(feeder(feed, { rep("iron-ore", 10), {} }),
      function() return rec.invs[1].get_item_count("iron-ore") >= 10 end, 1200, function()
      assert.are_equal(10, rec.invs[1].get_item_count("iron-ore"))
      game.players[1].teleport({ 2.5, 0.5 }) -- within reach, or opening is refused
      game.players[1].opened = box
      local opened = game.players[1].opened
      assert.are_equal("sushi_packer_frame", opened and opened.object_name == "LuaGuiElement" and opened.name, "player has packer window open")
      assert.are_equal(4, rec.invs[1].remove({ name = "iron-ore", count = 4 }))
      local front = front_belts(surface, force, 0, 20, "transport-belt")
      run_until(function() end, function() return total(output(front, 1)) >= 4 end, 600, function()
        after_ticks(360, function() -- LED learns of items in arm hands at a hand look: every 300 ticks
          game.players[1].opened = nil
          local seq = output(front, 1)
          assert.are.same({ { name = "iron-ore", count = 4 } }, seq, "one full stack of what was left went out")
          assert.are_equal(2, lane_count(rec, 1, "iron-ore"), "rest stays as partial")
          assert.are_equal(2, stored(rec), "nothing else held")
          assert.are_equal(0, total(output(front, 2)), "lane kept")
          assert.are_equal("yellow", rec.led.state)
        end)
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

  it("rare leftovers do not jam a busy lane", function()
    -- V16-3 (probe FND-0046: without script every out arm ends up holding a rare leftover and lane stops dead).
    -- Turbo box, full belt of mixed stacks 1..4 of 5 kinds; 8 rare kinds (1..3 items each) pass once early.
    -- Jam rule must keep lane near belt rate; rare leftovers leave as partial stacks or wait in hands.
    local KINDS = { "iron-plate", "copper-plate", "iron-gear-wheel", "electronic-circuit", "steel-plate" }
    local RARE = { "copper-cable", "advanced-circuit", "sulfur", "battery", "explosives", "iron-ore", "copper-ore", "concrete" }
    local _, rec, feed, front = build(surface, force, { tier = "turbo", belt = "turbo-transport-belt", front = 6 })
    local sink = front[#front]
    local k, fed, out, partial, t = 0, 0, 0, 0, 0
    run_until(function()
      t = t + 1
      local line = feed.get_transport_line(1)
      local tries = 0
      while tries < 4 and line.can_insert_at_back() do
        tries = tries + 1; k = k + 1
        local c = (k * 7) % 4 + 1
        local name = KINDS[(k * 5) % 5 + 1]
        if t < 300 and k % 9 == 0 then name = RARE[(k / 9) % 8 + 1]; c = (k / 9) % 3 + 1 end
        line.insert_at_back({ name = name, count = c }, c)
        if t > 600 then fed = fed + c end
      end
      local s = sink.get_transport_line(1)
      if #s > 0 then
        if t > 600 then
          for _, d in ipairs(s.get_detailed_contents()) do out = out + d.stack.count; if d.stack.count < 4 then partial = partial + 1 end end
        end
        s.clear()
      end
    end, function() return t >= 1800 end, 2000, function()
      local msg = string.format("fed=%d out=%d partial=%d store=%d hands=%d", fed, out, partial, rec.invs[1].get_item_count(), hands(rec, 1))
      assert.is_true(fed > 1000, msg)
      assert.is_true(out >= 0.95 * fed, msg)
      assert.is_true(rec.invs[1].count_empty_stacks() > 0, "store not full: " .. msg)
    end)
  end)

  it("more kinds than out arms: stacks in store do not wait forever", function()
    -- Old-save run 2026-10-02 (v1.15 save, 16 kinds on left lane): every out arm held a leftover of another kind,
    -- store kept full stacks, belt behind was empty, nothing left the box any more (front1=7 of 137).
    local names = {}
    for name, p in pairs(prototypes.item) do
      if p.type == "item" and p.stack_size >= 50 and not p.hidden and not p.parameter then names[#names + 1] = name end
    end
    table.sort(names)
    local q = {}
    for round = 1, 9 do for i = 1, 16 do q[#q + 1] = names[i] end end  -- 16 kinds x 9 = 144 items, one by one
    local _, rec, feed, front = build(surface, force, { tier = "turbo", belt = "turbo-transport-belt", front = 6 })
    local sink = front[#front]
    local out, t, feed_step = 0, 0, feeder(feed, { q, {} })
    run_until(function()
      t = t + 1
      feed_step()
      local s = sink.get_transport_line(1)
      if #s > 0 then out = out + s.get_item_count(); s.clear() end
    end, function() return t >= 2400 end, 2500, function()
      local held = lane_count(rec, 1)
      local msg = string.format("out=%d held=%d store=%d", out, held, rec.invs[1].get_item_count())
      assert.are_equal(144, out + held, "nothing lost: " .. msg)
      -- 9 of each kind = 2 full stacks out + 1 leftover per kind. Leftovers wait in hands / store; a jam flush
      -- (V16-3 a: every arm holds a leftover while stacks wait) may send the 8 held in hands out as singles. Which of
      -- the two happens depends on look phase (full suite 2026-10-02: out=136 held=8; alone: out=128 held=16).
      assert.is_true(out >= 128, "every full stack left: " .. msg)
      -- v1.20: such a lane is steered: leftovers wait in store (12 slots, 3 kept free: oldest leave as singles)
      assert.is_true(held <= 16, "at most one leftover per kind stays: " .. msg)
    end)
  end)

  it("arms holding leftovers do not block later stacks on an idle belt", function()
    -- 8 kinds, one item each: each out arm ends up holding one leftover. Later 5 other kinds, 8 items each, then
    -- nothing more: store holds full stacks (40 items, below pile mark), belt behind empty, flush timer off.
    local names = {}
    for name, p in pairs(prototypes.item) do
      if p.type == "item" and p.stack_size >= 50 and not p.hidden and not p.parameter then names[#names + 1] = name end
    end
    table.sort(names)
    local q1, q2 = {}, {}
    for i = 1, 8 do q1[#q1 + 1] = names[i] end
    for i = 9, 13 do for _ = 1, 8 do q2[#q2 + 1] = names[i] end end
    local _, rec, feed, front = build(surface, force, { tier = "turbo", belt = "turbo-transport-belt", front = 6 })
    local sink = front[#front]
    local out, t = 0, 0
    local step1, step2 = feeder(feed, { q1, {} }), feeder(feed, { q2, {} })
    run_until(function()
      t = t + 1
      if t < 400 then step1() else step2() end
      local s = sink.get_transport_line(1)
      if #s > 0 then out = out + s.get_item_count(); s.clear() end
    end, function() return t >= 2400 end, 2500, function()
      local msg = string.format("out=%d held=%d store=%d hands=%d", out, lane_count(rec, 1), rec.invs[1].get_item_count(), hands(rec, 1))
      assert.are_equal(48, out + lane_count(rec, 1), "nothing lost: " .. msg)
      assert.is_true(out >= 40, "five kinds x 8 = 10 full stacks must leave: " .. msg)
    end)
  end)

  it("output about tier speed on a faster belt", function()
    -- V16-2 / V16-9: exact tier cap is gone; out arms of a tier move about 1.6 x its lane rate (8 arms, one swing
    -- per N.out_swing ticks). Backlog while no front belt; then turbo front belt appears.
    local _, rec, feed = build(surface, force, { belt = "turbo-transport-belt", front = 0 })
    local front
    local opened_at
    -- 3 kinds x 64 = 192 items = 48 belt stacks of 4 in left lane store. 100-tick window: yellow arms
    -- 8 / 40 per tick -> 20 stacks, + 8 hands; fast arms (one swing per 2 ticks) would move all 48.
    -- v23: kinds of stack size 100, so kind cap (C-6, one item stack per kind) never bites at 64.
    local q = rep("iron-plate", 64)
    for _, name in ipairs({ "copper-plate", "steel-plate" }) do for _, x in ipairs(rep(name, 64)) do q[#q + 1] = x end end
    local step = feeder(feed, { q, {} })
    run_until(function()
      step()
      if not front and #q == 0 and rec.invs[1].get_item_count() == 192 then
        front = front_belts(surface, force, 0, 30, "turbo-transport-belt"); opened_at = game.tick
      end
    end, function() return opened_at and game.tick - opened_at >= 100 end, 5000, function()
      assert.is_not_nil(front, "backlog built")
      local pieces = #output(front, 1)
      local cap = math.ceil(100 * N.OUT_ARMS / N.out_swing(0.03125)) + N.OUT_ARMS
      assert.is_true(pieces > 0, "something left")
      assert.is_true(pieces <= cap, "belt items " .. pieces .. " cap " .. cap)
    end)
  end)

  it("red tier twice yellow throughput", function()
    -- E-4 / O-4 on v15 arms box: tier caps output in belt items per lane. Feed = 4-stacks on turbo belt (120 items/s
    -- per lane), more than either tier may release, so each box runs at its own cap: yellow 7.5, red 15 belt items/s.
    -- (Old feed of single items = 30 items/s = 7.5 stacks/s: no longer above yellow cap, both tiers moved the same.)
    -- 40 front tiles hold 640 items per lane: never full inside the 400-tick window.
    -- v16: caps are approximate (out arm speed per tier, V16-9): yellow 12, red 24 belt stacks/s per lane.
    local _, _, yfeed, yfront = build(surface, force, { x = 0, belt = "turbo-transport-belt", front = 60 })
    local _, _, rfeed, rfront = build(surface, force, { x = 6, tier = "red", belt = "turbo-transport-belt", front = 60 })
    local function stacks(feed)
      return function()
        local line = feed.get_transport_line(1)
        if line.can_insert_at_back() then line.insert_at_back({ name = "iron-ore", count = 4 }, 4) end
      end
    end
    local ys, rs = stacks(yfeed), stacks(rfeed)
    run_until(function() ys(); rs() end, function(t) return t >= 400 end, 500, function()
      local y, r = total(output(yfront, 1)), total(output(rfront, 1))
      local cap = math.ceil(400 * N.OUT_ARMS / N.out_swing(0.03125)) + N.OUT_ARMS
      assert.is_true(y > 0, "yellow moved")
      assert.is_true(#output(yfront, 1) <= cap, "yellow belt items " .. #output(yfront, 1) .. " over tier cap " .. cap)
      assert.is_true(r < 0.9 * 960, "red front belt (dead end, holds 960) never filled up: " .. r)
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
    assert.is_not_nil(find_box(surface, { 0.5, 0.5 }), "box built")
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
      local rec = storage.boxes[find_box(surface, { 0.5, 0.5 }).unit_number]
      local kept = {}
      for lane = 1, 2 do
        for _, x in ipairs(rec.invs[lane].get_contents()) do kept[#kept + 1] = "lane" .. lane .. " " .. x.name .. "=" .. x.count end
      end
      force.belt_stack_size_bonus = 3; storage.belt_stack = {}
      assert.is_true(l > 0 and r > 0, "left=" .. l .. " right=" .. r .. " stored " .. table.concat(kept, ","))
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
  -- v17 belt body (V17-1, V17-2, V17-5): behaviours of the packer as a belt piece, on final code.
  -- last field: tiles of that belt before packer's front tile (0 = belt starts there and is laid as a curve)
  for _, c in ipairs({ { "east", defines.direction.east, 1, 2, 0 }, { "west", defines.direction.west, -1, 1, 0 },
      { "east (straight, passing by)", defines.direction.east, 1, 2, 3 }, { "west (straight, passing by)", defines.direction.west, -1, 1, 3 } }) do
    it("belt running " .. c[1] .. " across in front gets both lanes on its near lane, stacked", function()
      force.belt_stack_size_bonus = 3
      local _, rec, feed = build(surface, force, { front = 0 })
      local across = {}
      for k = -c[5], 12 do across[#across + 1] = surface.create_entity({ name = "transport-belt", position = { 0.5 + k * c[3], -0.5 }, direction = c[2], force = force }) end
      local near, far = c[4], 3 - c[4]
      local function on(lane, name)
        local n, small = 0, 0
        for _, b in ipairs(across) do
          for _, d in ipairs(b.get_transport_line(lane).get_detailed_contents()) do
            if name == nil or d.stack.name == name then n = n + d.stack.count end
            if d.stack.count < 4 then small = small + 1 end
          end
        end
        return n, small
      end
      run_until(feeder(feed, { rep("iron-ore", 16), rep("copper-ore", 16) }), function() return on(near) >= 32 end, 1500, function()
        local n, small = on(near)
        local st = {}
        for lane = 1, 2 do
          for _, a in ipairs(rec.out[lane]) do
            local k; for name, v in pairs(defines.entity_status) do if v == a.status then k = name end end
            k = lane .. ":" .. tostring(k) .. (a.held_stack.valid_for_read and (":" .. a.held_stack.name .. "x" .. a.held_stack.count) or "")
            st[k] = (st[k] or 0) + 1
          end
        end
        local parts = {}; for k, v in pairs(st) do parts[#parts + 1] = k .. "=" .. v end; table.sort(parts)
        local msg = string.format("near=%d far=%d inside=%d store=%d/%d front_was=%s aim=%s arms[%s]", n, on(far), stored(rec), rec.invs[1].get_item_count(), rec.invs[2].get_item_count(),
          tostring(rec.front_was), tostring(rec.aim), table.concat(parts, " "))
        assert.are_equal(32, n, "all items on near lane: " .. msg)
        assert.are_equal(16, on(near, "iron-ore"), msg); assert.are_equal(16, on(near, "copper-ore"), msg)
        assert.are_equal(0, on(far), "far lane untouched: " .. msg)
        assert.are_equal(0, small, "only full belt stacks: " .. msg)
        assert.are_equal("across", rec.aim, msg)
        assert.are_equal(0, #surface.find_entities_filtered({ type = "item-entity" }), "nothing on ground")
      end)
    end)
  end

  it("belt pointing at packer flank puts nothing in", function()
    local box, rec = build(surface, force, { front = 6 })
    local side = {}
    for k = 3, 1, -1 do side[#side + 1] = surface.create_entity({ name = "transport-belt", position = { 0.5 - k, 0.5 }, direction = defines.direction.east, force = force }) end
    local fed = 0
    run_until(function()
      for lane = 1, 2 do
        local line = side[1].get_transport_line(lane)
        if line.can_insert_at_back() and line.insert_at_back({ name = "stone", count = 1 }) then fed = fed + 1 end
      end
    end, function(t) return t >= 600 end, 700, function()
      local on_side = 0
      for _, b in ipairs(side) do on_side = on_side + b.get_transport_line(1).get_item_count() + b.get_transport_line(2).get_item_count() end
      assert.is_true(fed > 0, "side belt was fed")
      assert.are_equal(fed, on_side, "every item still on side belt")
      assert.are_equal(0, stored(rec), "nothing inside packer")
      assert.are_equal(0, box.get_transport_line(1).get_item_count() + box.get_transport_line(2).get_item_count(), "nothing on belt body")
    end)
  end)

  it("outside inserters act as with belt: drop gets packed, take never reaches stored items", function()
    force.belt_stack_size_bonus = 3
    local box, rec, _, front = build(surface, force, { front = 12 })
    surface.create_entity({ name = "electric-energy-interface", position = { 6.5, 6.5 }, force = force })
    surface.create_entity({ name = "substation", position = { 3.5, 4.5 }, force = force })
    -- giver west of packer: chest (-1.5, 0.5) -> inserter (-0.5, 0.5) drops east onto packer tile
    local chest_in = surface.create_entity({ name = "steel-chest", position = { -1.5, 0.5 }, force = force })
    chest_in.get_inventory(defines.inventory.chest).insert({ name = "plastic-bar", count = 24 })
    local giver = surface.create_entity({ name = "bulk-inserter", position = { -0.5, 0.5 }, direction = defines.direction.west, force = force })
    -- taker east of packer: takes from packer tile into chest (2.5, 0.5)
    local chest_out = surface.create_entity({ name = "steel-chest", position = { 2.5, 0.5 }, force = force })
    local taker = surface.create_entity({ name = "bulk-inserter", position = { 1.5, 0.5 }, direction = defines.direction.west, force = force })
    rec.invs[1].insert({ name = "iron-plate", count = 3 })  -- leftover: stays inside, taker must not get it
    local function plastic_out() return total(output(front, 1), "plastic-bar") + total(output(front, 2), "plastic-bar") end
    run_until(function() end, function() return plastic_out() + chest_out.get_item_count("plastic-bar") >= 24 end, 1800, function()
      local msg = string.format("giver.drop_target=%s taker.pickup_target=%s out=%d taken=%d inside=%d chest_in=%d", tostring(giver.drop_target and giver.drop_target.name),
        tostring(taker.pickup_target and taker.pickup_target.name), plastic_out(), chest_out.get_item_count(), stored(rec), chest_in.get_item_count())
      assert.are_equal(box.name, giver.drop_target and giver.drop_target.name, msg)
      assert.are_equal(box.name, taker.pickup_target and taker.pickup_target.name, msg)
      assert.are_equal(24, plastic_out() + chest_out.get_item_count("plastic-bar") + stored(rec, "plastic-bar"), "no plastic lost: " .. msg)
      assert.are_equal(0, chest_out.get_item_count("iron-plate"), "stored items never taken by outside inserter: " .. msg)
      assert.are_equal(3, stored(rec, "iron-plate"), msg)
      assert.are_equal(0, #surface.find_entities_filtered({ type = "item-entity" }), "nothing on ground")
    end)
  end)

  it("packer feeding packer: nothing lost, lanes kept", function()
    force.belt_stack_size_bonus = 3
    local _, rec, feed = build(surface, force, { front = 0 })
    surface.create_entity({ name = N.placer("yellow"), position = { 0.5, -0.5 }, direction = NORTH, force = force, raise_built = true })
    local second = storage.boxes[find_box(surface, { 0.5, -0.5 }).unit_number]
    local front = {}
    for i = 1, 12 do front[i] = surface.create_entity({ name = "transport-belt", position = { 0.5, -0.5 - i }, direction = NORTH, force = force }) end
    run_until(feeder(feed, { rep("iron-ore", 40), rep("copper-ore", 40) }), function() return total(output(front, 1)) + total(output(front, 2)) >= 80 end, 3000, function()
      local l, r = output(front, 1), output(front, 2)
      local msg = string.format("out=%d/%d first=%d second=%d", total(l), total(r), stored(rec), stored(second))
      assert.are_equal(80, total(l) + total(r) + stored(rec) + stored(second), "nothing lost: " .. msg)
      assert.are_equal(40, total(l, "iron-ore"), msg); assert.are_equal(40, total(r, "copper-ore"), msg)
      assert.are_equal(0, total(l, "copper-ore") + total(r, "iron-ore"), "lanes kept: " .. msg)
      assert.are_equal(0, #surface.find_entities_filtered({ type = "item-entity" }), "nothing on ground")
    end)
  end)
  -- v1.21 (FND-0053; author on v1.20: belt in front of packer input jerks). Packer line beside a free belt of the
  -- same tier, same feed, all running west (author's layout); engine way and script way (skip list) each own line.
  -- Bar (author 2026-10-02): packer line takes in at least 98 % of what the free belt carries.
  -- Replaces the v1.20 trickle tests (same hard feed, bars were 85 % engine, 75 % script).
  local function intake_case(feed)
    local rows = {}
    for _, tier in ipairs(N.TIERS) do
      for _, mode in ipairs({ "free", "engine", "script" }) do rows[#rows + 1] = { tier = tier, mode = mode, feed = feed } end
    end
    intake.run(surface, force, rows, function(rigs) intake.verdict(surface, rigs, 0.98) end)
  end
  it("belt behind packer does not jerk: steady trickle of rare kinds", function() intake_case("hard") end)
  it("belt behind packer does not jerk: more kinds than store slots", function() intake_case("many") end)
  it("belt behind packer does not jerk: thin trickle of rare kinds", function() intake_case("thin") end)
  it("belt behind packer does not jerk: single items of seven kinds", function() intake_case("seven") end)
  it("belt behind packer does not jerk: full stacks", function() intake_case("fours") end)
  it("belt behind packer does not jerk: mixed stacks of three kinds", function() intake_case("plain") end)
end)
