local belt_io = require("scripts.belt_io")
local core = require("scripts.core")
local tick = require("scripts.tick")
local circuit = require("scripts.circuit")
local led = require("scripts.led")
local N = require("scripts.names")

describe("tick extra", function()
  it("lane rate is belt speed times 4", function()
    belt_io._reset_rates()
    prototypes = { entity = {
      ["turbo-transport-belt"] = { belt_speed = 0.125 },
      ["kr-superior-transport-belt"] = { belt_speed = 0.1875 },
    } }
    eq(belt_io.lane_rate("turbo"), 0.5)
    eq(belt_io.lane_rate("kr-superior"), 0.75)
  end)

  it("missing belt prototype falls back to table rate", function()
    belt_io._reset_rates()
    prototypes = { entity = {} }
    eq(belt_io.lane_rate("turbo"), 0.5)
    eq(belt_io.lane_rate("kr-superior"), 0)
  end)

  it("modded vanilla speed followed", function()
    belt_io._reset_rates()
    prototypes = { entity = { ["transport-belt"] = { belt_speed = 0.0625 } } }
    eq(belt_io.lane_rate("yellow"), 0.25)
  end)

  local function tick_fixture(tier, unit, belt_name, speed)
    belt_io._reset_rates()
    local old = { pull = belt_io.pull, push = belt_io.push, bss = belt_io.belt_stack_size,
      evaluate = circuit.evaluate, set = led.set }
    defines = { inventory = { chest = 1 }, gui_type = { entity = 1, item = 3 },
      direction = { north = 0, east = 4, south = 8, west = 12 },
      wire_connector_id = { circuit_red = 1, circuit_green = 2 } }
    settings = { global = { [N.SETTING_TIMEOUT] = { value = 0 } } }
    prototypes = { entity = { [belt_name] = { belt_speed = speed } }, item = { iron = { stack_size = 100 } } }
    local calls = { pull = 0, budgets = {}, push = 0, led = 0 }
    local inv = { contents = {} }
    function inv.insert(x)
      inv.contents[1] = inv.contents[1] or { name = x.name, quality = x.quality, count = 0 }
      inv.contents[1].count = inv.contents[1].count + x.count
      return x.count
    end
    function inv.remove(x)
      if not inv.contents[1] then return 0 end
      local n = math.min(x.count, inv.contents[1].count); inv.contents[1].count = inv.contents[1].count - n; return n
    end
    function inv.get_contents()
      local out = {}
      for i, x in ipairs(inv.contents) do out[i] = { name = x.name, quality = x.quality, count = x.count } end
      return out
    end
    local ent = { valid = true, unit_number = unit, position = { x = 0, y = 0 }, force = { index = 1, belt_stack_size_bonus = 0 } }
    function ent.get_inventory() return inv end
    local rec = { entity = ent, unit_number = unit, tier = tier, dir = "north", box = core.new_box(),
      settings = { timeout_mode = "global", filters = {}, circuit = {} }, enabled = true,
      in_credit = { 0, 0 }, out_credit = { 0, 0 }, next_poll = 0 }
    belt_io.pull = function(_, budget) calls.pull = calls.pull + 1; calls.budgets[#calls.budgets + 1] = { budget[1], budget[2] }; return { 0, 0 } end
    belt_io.push = function(_, _, p) calls.push = calls.push + p.count; return p.count end
    belt_io.belt_stack_size = function() return 1 end
    circuit.evaluate = function() return true, false end
    led.set = function() calls.led = calls.led + 1 end
    storage = { boxes = { [unit] = rec }, belt_stack = { [1] = 1 } }
    game = { connected_players = {} }
    return rec, calls, inv, old
  end

  local function restore(old)
    belt_io.pull, belt_io.push, belt_io.belt_stack_size = old.pull, old.push, old.bss
    circuit.evaluate, led.set = old.evaluate, old.set
  end

  local function rate_case(tier, belt, speed, expected, test_name)
    it(test_name, function()
      local r, c, inv, o = tick_fixture(tier, 1, belt, speed)
      belt_io.push = function(_, _, p) c.push = c.push + p.count; return p.count end
      core.adopt_external(r.box, "iron", "normal", 3000, 3000, 1)
      core.flush_partials(r.box, 1); inv.insert({ name = "iron", quality = "normal", count = 3000 })
      for t = 1, 800 do tick.on_tick({ tick = t }) end
      ok(c.push >= expected - 2, tier .. " below rate")
      ok(c.push <= expected + 2, tier .. " exceeded rate")
      restore(o)
    end)
  end

  rate_case("planetaris-hyper", "planetaris-hyper-transport-belt", 0.15625, 500,
    "75 per s tier keeps rate over 800 ticks")
  rate_case("kr-superior", "kr-superior-transport-belt", 0.1875, 600,
    "90 per s tier keeps rate over 800 ticks")
  rate_case("ub-ultimate", "ultimate-belt", 0.5625, 1800,
    "270 per s tier keeps rate over 800 ticks")

  it("input budget reaches 2 per tick at 270 per s", function()
    local r, c, _, o = tick_fixture("ub-ultimate", 1, "ultimate-belt", 0.5625)
    for t = 1, 8 do tick.on_tick({ tick = t }) end
    local reached = false
    for _, b in ipairs(c.budgets) do if b[1] >= 2 or b[2] >= 2 then reached = true end end
    ok(reached, "no input budget reached 2")
    restore(o)
  end)

  it("extra tier visited every tick", function()
    local r, c, _, o = tick_fixture("kr-superior", 1, "kr-superior-transport-belt", 0.1875)
    core.accept(r.box, "iron", "normal", 1, 1, 100, 0, false)
    for t = 1, 10 do tick.on_tick({ tick = t }) end
    eq(c.pull, 10)
    restore(o)
  end)
end)
