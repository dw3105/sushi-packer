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
  for _, name in ipairs(expected) do ok(found[name], "missing " .. tostring(type(name) == "table" and name[1] or name)) end
end

describe("data extra", function()
  it("chain fix-ups go to bodies", function()
    local raw = load("arig")
    raw["transport-belt"][N.TIER.turbo.belt].collision_box = { { -0.3, -0.3 }, { 0.3, 0.3 } }
    raw["transport-belt"][N.TIER.turbo.belt].collision_mask = { layers = { ground_tile = true } }
    require("prototypes.extra").build(raw)
    eq(raw["transport-belt"][N.body("turbo")].next_upgrade, N.body("planetaris-hyper"))
    eq(raw["transport-belt"][N.body("planetaris-hyper")].collision_box, raw["transport-belt"][N.body("turbo")].collision_box)
    eq(raw["transport-belt"][N.body("planetaris-hyper")].collision_mask, raw["transport-belt"][N.body("turbo")].collision_mask)
    for _, dir in ipairs(N.DIRS) do eq(raw.container[N.variant("turbo", dir)].next_upgrade, nil) end
  end)

  it("source belt missing in raw", function()
    F.reset()
    rawset(F.raw["transport-belt"], "transport-belt", nil)
    local tier = require("prototypes.tier")
    local good, err = pcall(tier.make, "yellow", { strict = true, index = 1 })
    eq(good, false)
    ok(tostring(err):find("yellow", 1, true) and tostring(err):find("transport-belt", 1, true), tostring(err))
  end)
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
    eq(#F.extended, 61)  -- v22: + 16 hood sprites (4 tiers x 4 directions)
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

  it("body next_upgrade chain follows tier chains", function()
    local raw = load("arig-k2so")
    require("prototypes.extra").build(raw)
    eq(raw["transport-belt"][N.body("turbo")].next_upgrade, N.body("planetaris-hyper"))
    eq(raw["transport-belt"][N.body("planetaris-hyper")].next_upgrade, N.body("kr-superior"))
    eq(raw["transport-belt"][N.body("kr-superior")].next_upgrade, nil)
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

  it("info lists belt mods as visible optional deps", function()
    local file = assert(io.open("info.json", "r"))
    local dependencies = file:read("*a")
    file:close()
    for _, dependency in ipairs({ "? planetaris-arig", "? Krastorio2", "? Krastorio2-spaced-out", "? boblogistics >= 2.1.0", "? UltimateBeltsSpaceAge", "? BetterBelts" }) do
      ok(dependencies:find(dependency, 1, true), "missing " .. dependency)
    end
  end)

  local function load_nosa(set)
    F.reset({ sa = false })
    if set then F.with_mods(set) end
    dofile("prototypes/packer.lua")
    return F.raw
  end
  local function logs_for(fn)
    local logs, saved = {}, _G.log
    _G.log = function(message) logs[#logs + 1] = message end
    fn()
    _G.log = saved
    return logs
  end

  it("nosa no turbo tier", function()
    local raw = load_nosa()
    eq(raw.item["turbo-sushi-packer"], nil); eq(raw.recipe["turbo-sushi-packer"], nil); eq(raw.technology["turbo-sushi-packer"], nil)
    for _, dir in ipairs(N.DIRS) do eq(raw.container[N.variant("turbo", dir)], nil); eq(raw.container[N.variant("blue", dir)].next_upgrade, nil) end
  end)
  it("nosa extras chain after blue", function()
    load_nosa("ab")
    local rows = require("prototypes.extra").tiers(F.raw)
    eq(names(rows), { "ab-elite", "ab-extreme", "ab-supreme", "ab-ultimate" }); eq(rows[1].prev, "blue")
  end)
  it("nosa extra recipe bulk inserter processing unit", function()
    local raw = load_nosa("ab"); require("prototypes.extra").build(raw)
    eq(ingredient_pairs(raw.recipe[N.item("ab-elite")]), { {"express-sushi-packer",1},{"elite-splitter",1},{"bulk-inserter",2},{"processing-unit",5} })
    eq(raw.recipe[N.item("ab-elite")].energy_required, 60)
  end)
  it("sa extra recipe unchanged", function()
    local raw = load("arig"); require("prototypes.extra").build(raw)
    eq(ingredient_pairs(raw.recipe[N.item("planetaris-hyper")]), { {"turbo-sushi-packer",1},{"planetaris-hyper-splitter",1},{"stack-inserter",2},{"quantum-processor",2} })
    eq(raw.recipe[N.item("planetaris-hyper")].energy_required, 120)
  end)
  it("owner missing row skipped", function()
    local raw = load("arig"); mods["planetaris-arig"] = nil
    local logs = logs_for(function() eq(require("prototypes.extra").tiers(raw), {}) end)
    ok(logs[1] and logs[1]:find("planetaris-hyper",1,true))
  end)
  it("ab-sa ub-ultimate not live", function()
    local raw = load("ab-sa"); local rows = require("prototypes.extra").tiers(raw)
    for _, row in ipairs(rows) do ok(row.key ~= "ub-ultimate") end
    require("prototypes.extra").build(raw)
  end)
  it("ab-sa ab rows after turbo", function()
    local raw = load("ab-sa"); local rows = require("prototypes.extra").tiers(raw)
    eq(names(rows), {"ab-extreme","ab-supreme","ab-ultimate"}); eq(rows[1].prev,"turbo")
  end)
  it("splitter missing row skipped logged", function()
    local raw = load("arig"); raw.item["planetaris-hyper-splitter"] = nil
    local logs = logs_for(function() eq(require("prototypes.extra").tiers(raw), {}) end)
    ok(logs[1] and logs[1]:find("planetaris-hyper",1,true))
  end)
  it("speed at or below top vanilla skipped", function()
    local raw = load("ab-sa"); local rows = require("prototypes.extra").tiers(raw)
    for _, row in ipairs(rows) do ok(row.key ~= "ab-elite") end
  end)
  it("own_role keeps slow row", function()
    local raw = load("ab-sa"); local index
    for i,row in ipairs(N.EXTRA) do if row.key == "ab-elite" then index=i; break end end
    local old = N.EXTRA[index].own_role; N.EXTRA[index].own_role = true
    local rows = require("prototypes.extra").tiers(raw); N.EXTRA[index].own_role = old
    -- v11 (M-4): own_role without `after` = root tier (prev nil), not main chain; ab-extreme keeps main chain after turbo
    eq(rows[1].key,"ab-elite"); eq(rows[1].prev,nil); eq(rows[2].key,"ab-extreme"); eq(rows[2].prev,"turbo")
  end)
  it("se chain space root then deep space", function()
    -- v11 (V11-2, M-4): space own-role root (prev nil), deep space after space; blue leads nowhere
    load_nosa("se")
    eq(require("prototypes.extra").tiers(F.raw), {{key="se-space",speed=0.09375},{key="se-deep-space",prev="se-space",speed=0.1875}})
  end)
  it("container allowed in se space", function()
    local raw = load("se"); require("prototypes.extra").build(raw)
    for _,tier in ipairs({"yellow","red","blue","se-space","se-deep-space"}) do for _,dir in ipairs(N.DIRS) do eq(raw.container[N.variant(tier,dir)].se_allow_in_space,true) end end
  end)
  it("ab four rows speed order", function()
    load_nosa("ab"); local rows=require("prototypes.extra").tiers(F.raw)
    eq({rows[1].speed,rows[2].speed,rows[3].speed,rows[4].speed},{0.125,0.15625,0.1875,0.21875})
  end)
  it("upgrade chain from top vanilla", function()
    local raw=load("se"); require("prototypes.extra").build(raw)
    eq(raw["transport-belt"][N.body("blue")].next_upgrade,nil)  -- v11 (U-3): no upgrade across chains
    eq(raw["transport-belt"][N.body("se-space")].next_upgrade,N.body("se-deep-space"))
    eq(raw["transport-belt"][N.body("se-deep-space")].next_upgrade,nil)
    raw=load("arig"); require("prototypes.extra").build(raw)
    eq(raw["transport-belt"][N.body("turbo")].next_upgrade,N.body("planetaris-hyper"))
  end)
  it("info lists space-age as optional", function()
    local file=assert(io.open("info.json","r")); local content=file:read("*a"); file:close()
    for _,dep in ipairs({"? space-age","? space-exploration","? AdvancedBeltsUpdated"}) do ok(content:find(dep,1,true)) end
    ok(not content:find('"space-age"',1,true))
  end)
  it("extra box matches resized vanilla box", function()
    -- FND-0029: aai-containers (SE dep, setting aai-containers-resize-1x1) shrinks 1x1 container boxes to +-0.3 in its
    -- data-final-fixes, before ours; next_upgrade target must have the same bounding box or the game refuses to load.
    local raw = load("se")
    for _, tier in ipairs({ "yellow", "red", "blue" }) do
      raw["transport-belt"][N.body(tier)].collision_box = { { -0.3, -0.3 }, { 0.3, 0.3 } }
    end
    require("prototypes.extra").build(raw)
    for _, dir in ipairs(N.DIRS) do
      eq(raw["transport-belt"][N.body("se-deep-space")].collision_box, { { -0.3, -0.3 }, { 0.3, 0.3 } })
    end
  end)
  it("extra box matches mask of vanilla box", function()
    local raw = load("arig")
    local mask = { layers = { item = true, object = true, player = true, water_tile = true, is_object = true, is_lower_object = true, mining_drone = true } }
    for _, tier in ipairs({ "yellow", "red", "blue", "turbo" }) do
      raw["transport-belt"][N.body(tier)].collision_mask = mask
    end
    require("prototypes.extra").build(raw)
    for _, dir in ipairs(N.DIRS) do
      local copied = raw["transport-belt"][N.body("planetaris-hyper")].collision_mask
      eq(copied, mask)
      ok(copied ~= raw["transport-belt"][N.body("turbo")].collision_mask, "mask must be deep-copied")
    end
  end)
  it("extra mask copied into every chain", function()
    local raw = load("se")
    local mask = { layers = { item = true, object = true, player = true, water_tile = true, is_object = true, is_lower_object = true, mining_drone = true } }
    for _, tier in ipairs({ "yellow", "red", "blue" }) do
      raw["transport-belt"][N.body(tier)].collision_mask = mask
    end
    require("prototypes.extra").build(raw)
    for _, tier in ipairs({ "se-space", "se-deep-space" }) do
      eq(raw["transport-belt"][N.body(tier)].collision_mask, mask)
    end
  end)
  it("nil mask stays nil", function()
    local raw = load("arig")
    require("prototypes.extra").build(raw)
    eq(raw["transport-belt"][N.body("planetaris-hyper")].collision_mask, nil)
  end)
  it("se space root recipe", function()
    local raw = load("se"); require("prototypes.extra").build(raw)
    eq(ingredient_pairs(raw.recipe[N.item("se-space")]), {{"steel-chest",1},{"se-space-splitter",1},{"bulk-inserter",4},{"processing-unit",10}})
    eq(raw.recipe[N.item("se-space")].energy_required,60)
  end)
  it("se space root tech", function()
    local raw = load("se"); require("prototypes.extra").build(raw)
    local tech = raw.technology[N.tech("se-space")]
    includes(tech.prerequisites,{"se-space-belt"})
    for _, name in ipairs(tech.prerequisites) do ok(not name:find("^sushi%-packer") and not name:find("%-sushi%-packer$"),name) end
    eq(tech.unit.count,300)
    includes(tech.unit.ingredients,{"se-rocket-science-pack"})
  end)
  it("se deep space recipe needs space box", function()
    local raw = load("se"); require("prototypes.extra").build(raw)
    local recipe = raw.recipe[N.item("se-deep-space")]
    eq(ingredient_pairs(recipe)[1],{N.item("se-space"),1})
    for _, ingredient in ipairs(recipe.ingredients) do ok(ingredient.name ~= "express-sushi-packer") end
    includes(raw.technology[N.tech("se-deep-space")].prerequisites,{N.tech("se-space")})
    for _, name in ipairs(raw.technology[N.tech("se-deep-space")].prerequisites) do ok(name ~= "express-sushi-packer") end
  end)
  it("after target inactive skips row", function()
    local raw=load("se"); raw["transport-belt"]["se-space-transport-belt"]=nil
    local logs=logs_for(function()
      local rows=require("prototypes.extra").tiers(raw)
      for _, row in ipairs(rows) do ok(row.key ~= "se-space" and row.key ~= "se-deep-space") end
    end)
    local found=false; for _,message in ipairs(logs) do if message:find("se-deep-space",1,true) then found=true end end; ok(found)
  end)
  it("se plus k2 two chains", function()
    local raw=load("se")
    raw["transport-belt"]["kr-superior-transport-belt"]={type="transport-belt",name="kr-superior-transport-belt",speed=0.1875}
    raw["transport-belt"]["kr-advanced-transport-belt"]={type="transport-belt",name="kr-advanced-transport-belt",speed=0.125,hidden=true}
    raw.item["kr-superior-splitter"]={}; raw.item["kr-advanced-splitter"]={}
    raw.recipe["kr-superior-splitter"]={}; raw.recipe["kr-advanced-splitter"]={}
    raw.technology["kr-logistic-5"]={unit={count=2000,ingredients={{"production-science-pack",1}}},effects={}}
    raw.technology["kr-logistic-4"]={unit={count=500,ingredients={{"production-science-pack",1}}},effects={}}
    raw.technology["kr-logistic-5"].prerequisites={"turbo-transport-belt"}
    mods["Krastorio2-spaced-out"]="0.0.0"
    local rows=require("prototypes.extra").tiers(raw)
    eq(names(rows),{"se-space","kr-superior","se-deep-space"})
    eq({rows[1].prev,rows[2].prev,rows[3].prev},{nil,"blue","se-space"})
    raw.technology["kr-logistic-5"].prerequisites={}
    require("prototypes.extra").build(raw)
    eq(raw["transport-belt"][N.body("blue")].next_upgrade,N.body("kr-superior"))
    eq(raw["transport-belt"][N.body("se-space")].next_upgrade,N.body("se-deep-space"))
    eq(raw["transport-belt"][N.body("kr-superior")].next_upgrade,nil)
    eq(raw["transport-belt"][N.body("se-deep-space")].next_upgrade,nil)
  end)
  it("yellow recipe unchanged by root rule", function()
    F.reset(); dofile("prototypes/packer.lua")
    eq(ingredient_pairs(F.raw.recipe[N.item("yellow")]),{{"steel-chest",1},{"splitter",1},{"inserter",2},{"electronic-circuit",5}})
    eq(F.raw.recipe[N.item("yellow")].energy_required,30)
  end)
end)
