local F = require("tests.offline.fake_data")
local N = require("scripts.names")

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[copy(k)] = copy(v) end
  return out
end

local function setup(opts)
  F.reset(opts)
  dofile("prototypes/packer.lua")
  return require("prototypes.tier")
end

local function move_advanced_circuit()
  local old = F.raw.technology["advanced-circuit"]
  for i = #old.effects, 1, -1 do
    local effect = old.effects[i]
    if effect.type == "unlock-recipe" and effect.recipe == "advanced-circuit" then table.remove(old.effects, i) end
  end
  F.raw.technology["basic-electronics"] = {
    type = "technology", name = "basic-electronics", prerequisites = {},
    effects = { { type = "unlock-recipe", recipe = "advanced-circuit" } },
    unit = { count = 50, time = 15, ingredients = { { "automation-science-pack", 1 }, { "py-science-pack-1", 1 } } },
  }
end

local function tech(name) return F.raw.technology[name] end
local function pack_names(unit)
  local out = {}
  for _, ingredient in ipairs(unit.ingredients) do out[#out + 1] = ingredient[1] end
  return out
end

local function vanilla_techs()
  local out = {}
  for _, key in ipairs(N.TIERS) do
    local name = N.tech(key)
    if tech(name) then out[name] = copy(tech(name)) end
  end
  return out
end

describe("data v24", function()
  it("relink follows unlock moved after data stage", function()
    local tier = setup()
    move_advanced_circuit()
    tier.relink(F.raw)
    eq(tech("fast-sushi-packer").prerequisites, { "logistics-2", "sushi-packer", "fast-inserter", "basic-electronics" })
    eq(pack_names(tech("fast-sushi-packer").unit), { "automation-science-pack", "logistic-science-pack", "py-science-pack-1" })
  end)

  it("relink keeps count and time", function()
    local tier = setup()
    move_advanced_circuit()
    tier.relink(F.raw)
    eq(tech("fast-sushi-packer").unit.count, 300)
    eq(tech("fast-sushi-packer").unit.time, 30)
    eq(tech("fast-sushi-packer").effects, { { type = "unlock-recipe", recipe = "fast-sushi-packer" } })
  end)

  it("relink without move changes nothing", function()
    local tier = setup()
    local before = vanilla_techs()
    tier.relink(F.raw)
    for name, old in pairs(before) do
      eq(tech(name).prerequisites, old.prerequisites, name .. " prerequisites")
      eq(tech(name).unit, old.unit, name .. " unit")
    end
  end)

  it("relink twice equals once", function()
    local tier = setup()
    move_advanced_circuit()
    tier.relink(F.raw)
    local once = vanilla_techs()
    tier.relink(F.raw)
    for name, old in pairs(once) do
      eq(tech(name).prerequisites, old.prerequisites, name .. " prerequisites")
      eq(tech(name).unit, old.unit, name .. " unit")
    end
  end)

  it("relink without space-age skips turbo", function()
    local tier = setup({ sa = false })
    tier.relink(F.raw)
    eq(tech("turbo-sushi-packer"), nil)
    eq(tech("express-sushi-packer").prerequisites, { "logistics-3", "fast-sushi-packer", "bulk-inserter", "processing-unit" })
  end)

  it("final fixes relinks before extra tiers", function()
    local file = assert(io.open("data-final-fixes.lua", "r"))
    local source = file:read("*a")
    file:close()
    local relink = assert(string.find(source, 'require("prototypes.tier").relink(data.raw)', 1, true))
    local extra = assert(string.find(source, "prototypes.extra", 1, true))
    ok(relink < extra)
  end)
end)
