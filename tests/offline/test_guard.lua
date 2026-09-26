-- Guard (SP-01): contract names + arity, names table, modules load with no game globals.
local C = require("tests.offline.contract")

describe("guard", function()
  it("contract frozen", function()
    local mods = {}
    for m in pairs(C) do mods[#mods + 1] = m end
    table.sort(mods)
    eq(mods, { "belt_io", "circuit", "copy", "core", "gui", "led", "registry", "tick" }, "modules")
    for _, m in ipairs(mods) do
      package.loaded["scripts." .. m] = nil
      local M = require("scripts." .. m)
      for fn, arity in pairs(C[m]) do
        ok(type(M[fn]) == "function", m .. "." .. fn .. " missing")
        eq(debug.getinfo(M[fn], "u").nparams, arity, m .. "." .. fn .. " arity")
      end
      for fn in pairs(M) do ok(C[m][fn] ~= nil or fn:sub(1, 1) == "_", m .. "." .. fn .. " not in contract (private names start with _)") end
    end
  end)

  it("names frozen", function()
    local N = require("scripts.names")
    eq(N.TIERS, { "yellow", "red", "blue", "turbo" })
    eq(N.DIRS, { "north", "east", "south", "west" })
    eq(N.SLOTS, 48)
    eq(N.MAX_BELT_STACK, 4)
    eq(N.variant("red", "west"), "sushi-packer-red-west")
    eq(N.placer("blue"), "sushi-packer-blue-placer")
    eq(N.led("yellow", "south"), "sushi-packer-led-yellow-south")
    eq(N.SETTING_TIMEOUT, "sushi-packer-flush-timeout")
    eq(N.TIER.turbo.lane_rate, 0.5)
    eq(N.TIER.turbo.circuit, "quantum-processor")
    eq(N.TIER.blue.inserter, "bulk-inserter")
    eq(N.TIER.red.splitter, "fast-splitter")
    eq(N.TIER.yellow.craft_s, 30)
    eq(N.RECIPE_BASE, "steel-chest")
    eq(N.TECH_COST_FACTOR, 1.5)
    eq(N.ITEM_WEIGHT, 20000)
    eq(N.TIPS, "sushi-packer-tips")
  end)
end)
