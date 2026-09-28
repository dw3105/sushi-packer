-- Guard (SP-01): contract names + arity, names table, modules load with no game globals.
local C = require("tests.offline.contract")

describe("guard", function()
  it("contract frozen", function()
    local mods = {}
    for m in pairs(C) do mods[#mods + 1] = m end
    table.sort(mods)
    eq(mods, { "belt_io", "circuit", "copy", "core", "filter", "gui", "led", "registry", "sim", "tick" }, "modules")
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
    eq(N.variant("red", "west"), "fast-sushi-packer-west")
    eq(N.placer("blue"), "express-sushi-packer-placer")
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
    eq(N.item("yellow"), "sushi-packer")
    eq(N.item("turbo"), "turbo-sushi-packer")
    eq(N.tech("blue"), "express-sushi-packer")
    eq(N.remnant("red"), "fast-sushi-packer-remnants")
    eq(N.old_item("red"), "sushi-packer-red")
    eq(N.SUBGROUP, "sushi-packer")
    eq(N.SIM_INTERFACE, "sushi-packer")
    eq(N.BELT_GROUP, "transport-belt")
    -- v9 (V9-1): extra tiers table shape; vanilla list unchanged
    eq(#N.ALL, #N.TIERS + #N.EXTRA)
    eq(N.ALL[5], N.EXTRA[1].key)
    eq(N.item("kr-superior"), "kr-superior-sushi-packer")
    eq(N.variant("planetaris-hyper", "west"), "planetaris-hyper-sushi-packer-west")
    eq(N.EXTRA_RECIPE, { inserter = "stack-inserter", inserters = 2, circuit = "quantum-processor", circuits = 2, craft_s = 120 })
    for _, row in ipairs(N.EXTRA) do
      ok(N.TIER[row.key] and N.TIER[row.key].belt == row.belt and N.TIER[row.key].lane_rate == nil, "extra tier row " .. row.key)
      ok(row.splitter and row.tech and row.mod and #row.paint == 3 and row.wear and row.fv, "extra row fields " .. row.key)
      eq(N.VARIANTS[N.variant(row.key, "east")], { tier = row.key, dir = "east" })
    end
  end)
end)
