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

describe("locale", function()
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
    local expected = "sorts mixed belt items per lane into full stacks"
    assert(locale:lower():find(expected, 1, true), "item/tech locale must explain sorting into full stacks")
    assert(locale:lower():find("belt capacity research", 1, true), "locale must explain stacked output unlock")
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
