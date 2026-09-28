local F = require("tests.offline.fake_data")
local N = require("scripts.names")
_G.log = _G.log or function() end

local function dump(value)
  if type(value) ~= "table" then
    if type(value) == "string" then return string.format("%q", value) end
    return tostring(value)
  end
  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) < type(b)
  end)
  local parts = {}
  for _, key in ipairs(keys) do parts[#parts + 1] = "[" .. dump(key) .. "]=" .. dump(value[key]) end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function load(set)
  F.reset()
  if set then F.with_mods(set) end
  dofile("prototypes/packer.lua")
  return F.raw
end

local function names(rows)
  local out = {}
  for _, row in ipairs(rows) do out[#out + 1] = row.key end
  return out
end

local function ingredient_pairs(recipe)
  local out = {}
  for _, ingredient in ipairs(recipe.ingredients) do out[#out + 1] = { ingredient.name, ingredient.amount } end
  return out
end

local function includes(rows, expected)
  local found = {}
  for _, row in ipairs(rows) do found[type(row) == "table" and row[1] or row] = true end
  for _, name in ipairs(expected) do ok(found[name], "missing " .. name) end
end

describe("data extra", function()
  it("vanilla prototypes identical to v8", function()
    F.reset()
    dofile("prototypes/packer.lua")
    local golden = dofile("tests/offline/golden_vanilla.lua")
    eq(dump(F.extended), golden)
  end)

  it("no mods no extra tiers", function()
    local raw = load()
    local extra = require("prototypes.extra")
    eq(extra.tiers(raw), {})
    extra.build(raw)
    eq(#F.extended, 37)
    for _, dir in ipairs(N.DIRS) do eq(raw.container[N.variant("turbo", dir)].next_upgrade, nil) end
  end)

  it("arig adds hyper after turbo", function()
    local raw = load("arig")
    eq(require("prototypes.extra").tiers(raw), { { key = "planetaris-hyper", prev = "turbo", speed = 0.15625 } })
  end)

  it("hidden belt skipped", function()
    local logs, saved_log = {}, _G.log; _G.log = function(s) logs[#logs + 1] = s end
    local raw = load("arig-off")
    eq(require("prototypes.extra").tiers(raw), {})
    ok(#logs > 0 and logs[1]:find("planetaris-hyper", 1, true))
    _G.log = saved_log
  end)

  it("k2so hidden advanced belt ignored", function()
    local raw = load("k2so")
    eq(names(require("prototypes.extra").tiers(raw)), { "kr-superior" })
  end)

  it("arig k2so chain turbo hyper superior", function()
    local raw = load("arig-k2so")
    local rows = require("prototypes.extra").tiers(raw)
    eq(names(rows), { "planetaris-hyper", "kr-superior" })
    eq({ rows[1].prev, rows[2].prev }, { "turbo", "planetaris-hyper" })
  end)

  it("all mods sorted by speed tie by row order", function()
    local raw = load("all")
    eq(names(require("prototypes.extra").tiers(raw)), {
      "planetaris-hyper", "bob-ultimate", "kr-superior", "ub-ultra-fast", "bb-ultra",
      "ub-extreme-fast", "ub-ultra-express", "ub-extreme-express", "ub-ultimate",
    })
  end)

  it("belt tech without unit skipped", function()
    local logs, saved_log = {}, _G.log; _G.log = function(s) logs[#logs + 1] = s end
    local raw = load("arig")
    raw.technology["planetaris-hyper-transport-belt"].unit = nil
    raw.technology["planetaris-hyper-transport-belt"].research_trigger = { type = "craft-item", item = "x", count = 1 }
    eq(require("prototypes.extra").tiers(raw), {})
    ok(#logs > 0 and logs[1]:find("planetaris-hyper", 1, true))
    _G.log = saved_log
  end)

  it("missing tech skipped", function()
    local logs, saved_log = {}, _G.log; _G.log = function(s) logs[#logs + 1] = s end
    local raw = load("arig")
    raw.technology["planetaris-hyper-transport-belt"] = nil
    eq(require("prototypes.extra").tiers(raw), {})
    ok(#logs > 0 and logs[1]:find("planetaris-hyper", 1, true))
    _G.log = saved_log
  end)

  it("recipe chains previous tier", function()
    local raw = load("arig-k2so")
    require("prototypes.extra").build(raw)
    eq(ingredient_pairs(raw.recipe[N.item("kr-superior")]), {
      { N.item("planetaris-hyper"), 1 }, { "kr-superior-splitter", 1 }, { "stack-inserter", 2 }, { "quantum-processor", 2 },
    })
    eq(raw.recipe[N.item("kr-superior")].energy_required, 120)
    eq(ingredient_pairs(raw.recipe[N.item("planetaris-hyper")])[1], { "turbo-sushi-packer", 1 })
  end)

  it("tech prereqs belt tech previous tier and ingredient unlocks", function()
    local raw = load("arig-k2so")
    require("prototypes.extra").build(raw)
    includes(raw.technology[N.tech("kr-superior")].prerequisites, {
      "kr-logistic-5", N.tech("planetaris-hyper"), "stack-inserter", "quantum-processor",
    })
  end)

  it("tech cost belt count x 1.5 and pack union", function()
    local raw = load("arig-k2so")
    require("prototypes.extra").build(raw)
    local unit = raw.technology[N.tech("kr-superior")].unit
    eq(unit.count, 3000); eq(unit.time, 60)
    includes(unit.ingredients, { "production-science-pack", "utility-science-pack", "space-science-pack", "kr-singularity-tech-card" })
  end)

  it("next_upgrade chain keeps direction", function()
    local raw = load("arig-k2so")
    require("prototypes.extra").build(raw)
    eq(raw.container[N.variant("turbo", "west")].next_upgrade, N.variant("planetaris-hyper", "west"))
    eq(raw.container[N.variant("planetaris-hyper", "west")].next_upgrade, N.variant("kr-superior", "west"))
    eq(raw.container[N.variant("kr-superior", "west")].next_upgrade, nil)
  end)

  it("item order after turbo in chain order", function()
    local raw = load("arig-k2so")
    require("prototypes.extra").build(raw)
    ok(raw.item[N.item("yellow")].order < raw.item[N.item("red")].order)
    ok(raw.item[N.item("red")].order < raw.item[N.item("blue")].order)
    ok(raw.item[N.item("blue")].order < raw.item[N.item("turbo")].order)
    ok(raw.item[N.item("turbo")].order < raw.item[N.item("planetaris-hyper")].order)
    ok(raw.item[N.item("planetaris-hyper")].order < raw.item[N.item("kr-superior")].order)
  end)

  it("extra graphics paths use tier key", function()
    local raw = load("arig")
    require("prototypes.extra").build(raw)
    local picture = raw.container[N.variant("planetaris-hyper", "north")].picture.layers[1].filename
    ok(picture:find("graphics/entity/sushi-packer/planetaris-hyper/sushi-packer-planetaris-hyper-north.png", 1, true))
    eq(raw.item[N.item("planetaris-hyper")].icon, "__sushi-packer__/graphics/icons/sushi-packer-planetaris-hyper.png")
  end)

  it("info lists belt mods as hidden optional deps", function()
    local file = assert(io.open("info.json", "r"))
    local dependencies = file:read("*a")
    file:close()
    for _, dependency in ipairs({ "(?) planetaris-arig", "(?) Krastorio2", "(?) Krastorio2-spaced-out", "(?) boblogistics >= 2.1.0", "(?) UltimateBeltsSpaceAge", "(?) BetterBelts" }) do
      ok(dependencies:find(dependency, 1, true), "missing " .. dependency)
    end
  end)
end)
