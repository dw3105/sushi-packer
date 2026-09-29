-- v10 probe (SP-10: NOT in index; temporary entry only): do vanilla boxes reach full belt rate? FND-0030.
local N = require("scripts.names")
local NORTH = defines.direction.north
local function chain() return script.active_mods["space-age"] and { "yellow", "red", "blue", "turbo" } or { "yellow", "red", "blue" } end
describe("probe v10 rate", function()
  local surface, force
  before_each(function()
    surface, force = game.surfaces[1], game.forces.player
    for _, e in ipairs(surface.find_entities_filtered({ area = { { -60, -60 }, { 60, 60 } } })) do if e.valid and e.type ~= "character" then e.destroy() end end
    storage.boxes = {}
    storage.belt_stack = {}
  end)
  it("vanilla box output vs belt rate", function()
    -- Per tier (turbo = control): 3 own belts behind, box, 12 own belts in front, north. Belt stack 1 = every item
    -- leaves at once (C-2). Both lanes saturated from far behind; last front tile emptied each tick and counted.
    -- Warm-up 180 ticks, measure 600. Want belt items per lane = belt_speed * 4 * 600 (M-6), within 3 % + 2.
    force.belt_stack_size_bonus = 0
    local rigs = {}
    for i, key in ipairs(chain()) do
      local x, belt = (i - 1) * 4, N.TIER[key].belt
      local behind = {}
      for j = 1, 3 do behind[j] = surface.create_entity({ name = belt, position = { x + 0.5, 0.5 + j }, direction = NORTH, force = force }) end
      local front = {}
      for j = 1, 12 do front[j] = surface.create_entity({ name = belt, position = { x + 0.5, 0.5 - j }, direction = NORTH, force = force }) end
      surface.create_entity({ name = N.placer(key), position = { x + 0.5, 0.5 }, direction = NORTH, force = force, raise_built = true })
      rigs[#rigs + 1] = { key = key, feed = behind[3], last = front[12], got = { 0, 0 },
        want = prototypes.entity[belt].belt_speed * 4 * 600 }
    end
    local names = { "iron-plate", "copper-plate", "coal", "stone" }
    local t, n = 0, 0
    on_tick(function()
      t = t + 1
      for _, r in ipairs(rigs) do
        for lane = 1, 2 do
          local line = r.feed.get_transport_line(lane)
          local k = 0
          while k < 4 and line.can_insert_at_back() do
            n = n + 1; k = k + 1
            line.insert_at_back({ name = names[n % #names + 1], count = 1 })
          end
          local out = r.last.get_transport_line(lane)
          if t > 180 then for _, s in ipairs(out.get_contents()) do r.got[lane] = r.got[lane] + s.count end end
          out.clear()
        end
      end
      if t >= 780 then
        local report = {}
        for _, r in ipairs(rigs) do
          for lane = 1, 2 do
            local ok = math.abs(r.got[lane] - r.want) <= r.want * 0.03 + 2
            report[#report + 1] = string.format("%s lane%d got=%d want=%.1f %s", r.key, lane, r.got[lane], r.want, ok and "ok" or "BAD")
          end
        end
        local text = table.concat(report, "; ")
        log("v10 probe rate: " .. text)  -- green run keeps numbers (build/<FV>/ftdata*/factorio-current.log)
        assert.is_nil(text:find("BAD", 1, true), text)
        return false
      end
    end)
  end)
end)
