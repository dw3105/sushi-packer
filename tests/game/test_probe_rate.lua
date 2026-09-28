-- v9 S2 probe (SP-10: NOT in index; temporary entry, report via error()): where do fast boxes cap at 60/s?
local N = require("scripts.names")
local core = require("scripts.core")
local belt_io = require("scripts.belt_io")
local NORTH = defines.direction.north
describe("probe v9 rate", function()
  it("fast box input vs output", function()
    local surface, force = game.surfaces[1], game.forces.player
    for _, e in ipairs(surface.find_entities_filtered({ area = { { -60, -60 }, { 60, 60 } } })) do if e.valid and e.type ~= "character" then e.destroy() end end
    force.belt_stack_size_bonus = 0
    local key = "planetaris-hyper"
    local belt = N.TIER[key].belt
    local behind = {}
    for j = 1, 3 do behind[j] = surface.create_entity({ name = belt, position = { 0.5, 0.5 + j }, direction = NORTH, force = force }) end
    local front = {}
    for j = 1, 12 do front[j] = surface.create_entity({ name = belt, position = { 0.5, 0.5 - j }, direction = NORTH, force = force }) end
    surface.create_entity({ name = N.placer(key), position = { 0.5, 0.5 }, direction = NORTH, force = force, raise_built = true })
    local box = surface.find_entities_filtered({ position = { 0.5, 0.5 }, type = "container" })[1]
    local rec = storage.boxes[box.unit_number]
    local t, n, out, pulls, pushes, polls = 0, 0, 0, 0, 0, 0

    local opull, opush = belt_io.pull, belt_io.push
    belt_io.pull = function(...) polls = polls + 1; local g, e = opull(...); pulls = pulls + (g[1] or 0); return g, e end
    belt_io.push = function(...) local p = opush(...); if p > 0 then pushes = pushes + 1 end; return p end
    local lines = {}
    on_tick(function()
      t = t + 1
      local line = behind[3].get_transport_line(1)
      local k = 0
      while k < 4 and line.can_insert_at_back() do n = n + 1; k = k + 1; line.insert_at_back({ name = n % 2 == 0 and "iron-plate" or "coal", count = 1 }) end
      local o = front[12].get_transport_line(1)
      if t > 180 then for _, s in ipairs(o.get_contents()) do out = out + s.count end end
      o.clear()
      if t == 180 then pulls, pushes, polls = 0, 0, 0 end
      if t > 180 and t <= 190 then
        local b1 = behind[1].get_transport_line(1)
        local d = b1.get_detailed_contents(); local pos = {}
        for _, x in ipairs(d) do pos[#pos + 1] = string.format("%.3f", x.position) end
        lines[#lines + 1] = string.format("t=%d behind1=[%s] can0=%s used=%d credit_in=%.2f out=%.2f next_poll=%s", t, table.concat(pos, ","),
          tostring(b1.can_insert_at(0)), core.used_slots(rec.box), rec.in_credit[1], rec.out_credit[1], tostring(rec.next_poll - game.tick))
      end
      if t >= 780 then
        belt_io.pull, belt_io.push = opull, opush
        error(string.format("%s belt=%s rate=%.3f lane1 out=%d want=%.0f polls=%d pulls=%d pushes=%d\n%s", key, belt,
          belt_io.lane_rate(key), out, prototypes.entity[belt].belt_speed * 4 * 600, polls, pulls, pushes, table.concat(lines, "\n")))
      end
    end)
  end)
end)
