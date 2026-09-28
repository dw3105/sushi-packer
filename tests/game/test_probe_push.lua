-- S0 v9 probes P2 + P3 (SP-10: NOT in index; temporary entry, report via error()). P3 also needs TEMP line in control.lua:
-- _G.SP_PROBE_PROTO = select(2, pcall(function() return prototypes.item["iron-plate"].name end))
-- P2: max belt items per tick per lane our output can place on fast belts.
-- P3: prototypes readable in control.lua main chunk (flag set by temporary line in control.lua).
local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -40, -40 }, { 40, 40 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

local function run(belt_name, method, ticks, done)
  local surface, force = game.surfaces[1], game.forces.player
  clear(surface)
  force.belt_stack_size_bonus = 0
  local belts = {}
  for i = 0, 11 do
    belts[#belts + 1] = surface.create_entity({ name = belt_name, position = { 0.5, 10.5 - i }, direction = defines.direction.north, force = force })
  end
  local first, last = belts[1].get_transport_line(1), belts[#belts]
  local placed, maxtick, t = 0, 0, 0
  local function step()
    t = t + 1
    last.get_transport_line(1).clear()
    local n = 0
    if method == "back" then
      while n < 10 and first.can_insert_at_back() and first.insert_at_back({ name = "iron-plate", count = 1 }) do n = n + 1 end
    else
      local len = first.line_length
      local pos = len
      while n < 10 and pos >= 0 do
        if first.can_insert_at(pos) and first.insert_at(pos, { name = "iron-plate", count = 1 }) then n = n + 1 end
        pos = pos - 0.03125
      end
    end
    if t > 60 then placed = placed + n; if n > maxtick then maxtick = n end end
  end
  return step, function() return placed, maxtick, t - 60 end
end

describe("probe v9", function()
  it("push rate per lane on fast belts", function()
    local report = { "P3 prototypes in main chunk: " .. tostring(_G.SP_PROBE_PROTO) }
    local cases = {}
    for _, b in ipairs({ "turbo-transport-belt", "sp-test-belt-90", "sp-test-belt-135", "sp-test-belt-270" }) do
      for _, m in ipairs({ "back", "at" }) do cases[#cases + 1] = { b, m } end
    end
    local i, step, result = 0, nil, nil
    local function next_case()
      i = i + 1
      if i > #cases then error(table.concat(report, "\n")) end
      step, result = run(cases[i][1], cases[i][2])
      local left = 360
      on_tick(function()
        step()
        left = left - 1
        if left == 0 then
          local placed, maxtick, ticks = result()
          local speed = prototypes.entity[cases[i][1]].belt_speed
          report[#report + 1] = string.format("%s speed=%.5f lane_rate_need=%.3f method=%s placed=%d ticks=%d per_tick=%.3f max_in_tick=%d",
            cases[i][1], speed, speed * 4, cases[i][2], placed, ticks, placed / ticks, maxtick)
          next_case()
          return false
        end
      end)
    end
    async(360 * #cases + 100)
    next_case()
  end)
end)
