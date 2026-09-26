local N = require("scripts.names")

local function read(path)
  local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s
end

local locale = read("locale/en/locale.cfg")
local function has(section, key)
  local current
  for line in locale:gmatch("[^\r\n]+") do
    local name = line:match("^%[(.-)%]$")
    if name then current = name
    elseif current == section and line:sub(1, #key + 1) == key .. "=" then return true end
  end
  return false
end
local function value(section, key)
  local current
  for line in locale:gmatch("[^\r\n]+") do
    local name = line:match("^%[(.-)%]$")
    if name then current = name
    elseif current == section then
      local k, v = line:match("^([^=]+)=(.*)$")
      if k == key then return v end
    end
  end
end

describe("locale", function()
  it("vanilla style names", function()
    local expected = { "Sushi packer", "Fast sushi packer", "Express sushi packer", "Turbo sushi packer" }
    for i, tier in ipairs(N.TIERS) do
      local name = expected[i]
      for _, section in ipairs({ "item-name", "recipe-name", "technology-name" }) do
        assert(value(section, N.item(tier)) == name, section .. ": " .. tier)
      end
      for _, key in ipairs({ N.placer(tier), N.variant(tier, "north"), N.variant(tier, "east"), N.variant(tier, "south"), N.variant(tier, "west") }) do
        assert(has("entity-name", key), key)
      end
      assert(has("entity-name", N.remnant(tier)), N.remnant(tier))
      for _, key in ipairs({ N.placer(tier), N.variant(tier, "north"), N.variant(tier, "east"), N.variant(tier, "south"), N.variant(tier, "west") }) do
        assert(value("entity-name", key) == name, key)
      end
      assert(value("entity-name", N.remnant(tier)) == name .. " remnants", N.remnant(tier))
    end
  end)

  it("every prototype has name and description", function()
    for _, tier in ipairs(N.TIERS) do
      assert(has("item-name", N.item(tier)) and has("item-description", N.item(tier)), "item locale: " .. tier)
      assert(has("technology-name", N.tech(tier)) and has("technology-description", N.tech(tier)), "tech locale: " .. tier)
      assert(has("entity-name", N.placer(tier)) and has("entity-description", N.placer(tier)), "placer locale: " .. tier)
      for _, dir in ipairs(N.DIRS) do
        assert(has("entity-name", N.variant(tier, dir)) and has("entity-description", N.variant(tier, dir)), "variant locale")
      end
      assert(has("entity-name", N.remnant(tier)) and has("entity-description", N.remnant(tier)), "remnant locale")
    end
    local expected = "collects items per lane until one kind fills a belt stack"
    assert(locale:lower():find(expected, 1, true), "item/tech locale must explain lane collection")
    assert(locale:lower():find("up to 4 with research", 1, true), "locale must explain research stack capacity")
  end)
  it("recipes and setting described", function()
    assert(has("recipe-name", N.item("yellow"))); assert(has("recipe-description", N.item("yellow")))
    assert(has("mod-setting-description", N.SETTING_TIMEOUT))
    for _, tier in ipairs(N.TIERS) do
      assert(has("recipe-name", N.item(tier)) and has("recipe-description", N.item(tier)), "recipe locale: " .. tier)
    end
  end)
  it("tips entry has locale and prototype", function()
    F = require("tests.offline.fake_data"); F.reset(); dofile("prototypes/tips.lua")
    local item = F.raw["tips-and-tricks-item"][N.TIPS]
    assert(item and item.trigger and item.trigger.type == "research" and item.trigger.technology == N.tech("yellow"))
    assert(has("tips-and-tricks-item-name", N.TIPS) and has("tips-and-tricks-item-description", N.TIPS))
    assert(has("tips-and-tricks-item-category-name", "sushi-packer"))
  end)
  it("mod name and description", function()
    assert(has("mod-name", N.MOD) and has("mod-description", N.MOD))
  end)
end)
