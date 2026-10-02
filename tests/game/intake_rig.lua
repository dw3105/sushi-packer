-- v1.21 (FND-0053): intake share rig, shared by test_tick and test_modtiers. Integrator-owned.
-- Packer line and free belt of same tier side by side, all running west, same feed (every belt spot of the far
-- feed tile offered an item each tick). Intake share = fed into packer line / fed into free belt.
local N = require("scripts.names")
local M = {}

local W = defines.direction.west
local ITEMS = { "copper-plate", "copper-cable", "electronic-circuit", "advanced-circuit", "steel-plate", "iron-gear-wheel", "iron-plate" }
local QUALITIES = { "uncommon", "rare", "epic" }
local SPOTS = { 0.75, 0.5, 0.25, 0 }
M.WARM, M.RUN = 300, 3000

-- Feeds: every = 0 (no rare kinds) or n (each nth belt spot one single item of a rare kind).
-- shape: nil = 3 kinds in stacks of 1..4; "ones" = singles; "fours" = full stacks; "seven" = 7 kinds, singles.
-- rare = number of rare kinds: 21 (qualities when game has them) or 60 (plain items, more kinds than store slots).
M.FEEDS = {
  hard = { every = 9, rare = 21 },
  many = { every = 9, rare = 60 },
  thin = { every = 30, rare = 21 },
  seven = { every = 0, shape = "seven" },
  fours = { every = 0, shape = "fours" },
  plain = { every = 0 },
}

local function plain_names()
  local names = {}
  for name, p in pairs(prototypes.item) do
    if p.type == "item" and p.stack_size >= 50 and not p.hidden and not p.parameter then names[#names + 1] = name end
  end
  table.sort(names)
  return names
end

local function find_box(surface, position)
  for _, e in ipairs(surface.find_entities_filtered({ position = position, type = "transport-belt" })) do
    if N.BODIES[e.name] then return e end
  end
end

-- Fastest live tier of this game (belt speed), first in N.active() order on a tie.
function M.top_tier()
  local best, speed
  for _, tier in ipairs(N.active()) do
    local s = prototypes.entity[N.TIER[tier].belt].belt_speed
    if not speed or s > speed then best, speed = tier, s end
  end
  return best
end

-- rows = { { tier = , mode = "free" | "engine" | "script", feed = <key of M.FEEDS> }, ... } (at most 12).
-- check(results) runs after M.WARM + M.RUN ticks; results[i] = row + { fed, fedn, out, small, rec, speed, front }.
function M.run(surface, force, rows, check)
  local q_ok = prototypes.quality["uncommon"] ~= nil and prototypes.quality["epic"] ~= nil
  local plain = plain_names()
  local commons = q_ok and ITEMS or plain
  local many = {}
  do
    local skip = {}
    for i = 1, 7 do skip[commons[i]] = true end
    for _, n in ipairs(plain) do if not skip[n] and #many < 60 then many[#many + 1] = n end end
  end
  local rigs = {}
  for r, row in ipairs(rows) do
    local y = -32.5 + 5 * r
    local belt = N.TIER[row.tier].belt
    local feed
    for x = 6, 1, -1 do
      local b = surface.create_entity({ name = belt, position = { x + 0.5, y }, direction = W, force = force })
      feed = feed or b
    end
    local front = {}
    for x = 1, 12 do front[x] = surface.create_entity({ name = belt, position = { 0.5 - x, y }, direction = W, force = force }) end
    local rec
    if row.mode == "free" then
      surface.create_entity({ name = belt, position = { 0.5, y }, direction = W, force = force })
    else
      surface.create_entity({ name = N.placer(row.tier), position = { 0.5, y }, direction = W, force = force, raise_built = true })
      local box = find_box(surface, { 0.5, y })
      assert.is_not_nil(box, "packer built " .. row.tier)
      rec = storage.boxes[box.unit_number]
      if row.mode == "script" then rec.settings.filters = { { name = "coal" } }; storage.sched = nil end
    end
    local f = M.FEEDS[row.feed]
    assert.is_not_nil(f, "feed " .. tostring(row.feed))
    if f.rare == 60 then assert.are_equal(60, #many, "60 plain items for feed many") end
    rigs[r] = { tier = row.tier, mode = row.mode, feed = row.feed, f = f, belt = feed, sink = front[#front], front = front, rec = rec,
      speed = prototypes.entity[belt].belt_speed, fed = { 0, 0 }, fedn = { 0, 0 }, out = { 0, 0 }, small = { 0, 0 }, k = { 0, 0 } }
  end
  local t = 0
  on_tick(function()
    t = t + 1
    for _, g in ipairs(rigs) do
      local f = g.f
      for lane = 1, 2 do
        local line = g.belt.get_transport_line(lane)
        for _, p in ipairs(SPOTS) do
          if line.can_insert_at(p) then
            local i = g.k[lane] + 1
            local c, name, q = (i * 7 + lane) % 4 + 1, commons[(i * 5 + lane) % 3 + 1], nil
            if f.shape == "ones" then c = 1 elseif f.shape == "fours" then c = 4
            elseif f.shape == "seven" then c, name = 1, commons[(i * 5 + lane) % 7 + 1] end
            if f.every > 0 and i % f.every == 0 then
              local j = i / f.every
              if f.rare == 60 then name = many[j % 60 + 1]
              elseif q_ok then name, q = ITEMS[j % #ITEMS + 1], QUALITIES[j % #QUALITIES + 1]
              else name = plain[4 + j % 21] end
              c = 1
            end
            if line.insert_at(p, { name = name, count = c, quality = q }, c) then
              g.k[lane] = i
              if t > M.WARM then g.fed[lane] = g.fed[lane] + c; g.fedn[lane] = g.fedn[lane] + 1 end
            end
          end
        end
        local s = g.sink.get_transport_line(lane)
        if #s > 0 then
          if t > M.WARM then
            for _, d in ipairs(s.get_detailed_contents()) do
              g.out[lane] = g.out[lane] + d.stack.count
              if d.stack.count < 4 then g.small[lane] = g.small[lane] + 1 end
            end
          end
          s.clear()
        end
      end
    end
    if t < M.WARM + M.RUN then return end
    check(rigs)
    return false
  end)
end

-- Standard verdict: every packer row takes in at least `bar` of its free row (same tier, same feed), what comes in
-- goes out, nothing on ground, free belt really was full.
-- bars (optional): { [feed] = bar } overrides `bar` for engine-way rows of that feed (named known shortfall).
function M.verdict(surface, rigs, bar, bars)
  local ref = {}
  for _, g in ipairs(rigs) do if g.mode == "free" then ref[g.tier .. "/" .. g.feed] = g end end
  local lines, bad = {}, {}
  local ground = #surface.find_entities_filtered({ type = "item-entity" })
  for _, g in ipairs(rigs) do
    local f = ref[g.tier .. "/" .. g.feed]
    assert.is_not_nil(f, "free row for " .. g.tier .. "/" .. g.feed)
    if g.mode == "free" then
      local fill = (g.fedn[1] + g.fedn[2]) / (2 * g.speed * 4 * M.RUN)
      if fill < 0.99 then bad[#bad + 1] = string.format("free belt %s/%s not full: %.3f", g.tier, g.feed, fill) end
    else
      local rec = g.rec
      local line = string.format("%s/%s/%s fed=%d/%d of %d/%d out=%d/%d small=%d/%d store=%d/%d free slots=%d/%d", g.tier, g.feed, g.mode,
        g.fed[1], g.fed[2], f.fed[1], f.fed[2], g.out[1], g.out[2], g.small[1], g.small[2],
        rec.invs[1].get_item_count(), rec.invs[2].get_item_count(), rec.invs[1].count_empty_stacks(), rec.invs[2].count_empty_stacks())
      lines[#lines + 1] = line
      log("intake " .. line)  -- numbers of green runs stay readable in factorio-current.log
      for lane = 1, 2 do
        local under_way = 0
        for _, b in ipairs(g.front) do under_way = under_way + b.get_transport_line(lane).get_item_count() end
        local want = (bars and g.mode == "engine" and bars[g.feed]) or bar
        if g.fed[lane] < want * f.fed[lane] then bad[#bad + 1] = "belt behind packer backs up, lane " .. lane .. ": " .. line end
        if g.out[lane] + under_way < 0.95 * g.fed[lane] then bad[#bad + 1] = "what comes in does not go out, lane " .. lane .. ": " .. line end
      end
    end
  end
  if ground > 0 then bad[#bad + 1] = "items on ground: " .. ground end
  assert.are_equal(0, #bad, table.concat(bad, "\n") .. "\nall rows:\n" .. table.concat(lines, "\n"))
  return lines
end

return M
