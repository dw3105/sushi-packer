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

local names = {
  ["planetaris-hyper"] = "Hyper sushi packer", ["bob-ultimate"] = "Ultimate sushi packer",
  ["kr-superior"] = "Superior sushi packer", ["ub-ultra-fast"] = "Ultra fast sushi packer",
  ["bb-ultra"] = "Ultra sushi packer", ["ub-extreme-fast"] = "Extreme fast sushi packer",
  ["ub-ultra-express"] = "Ultra express sushi packer", ["ub-extreme-express"] = "Extreme express sushi packer",
  ["ub-ultimate"] = "Ultimate sushi packer",
  ["ab-elite"] = "Elite sushi packer", ["ab-extreme"] = "Extreme sushi packer",
  ["ab-supreme"] = "Supreme sushi packer", ["ab-ultimate"] = "Ultimate sushi packer",
  ["se-deep-space"] = "Deep space sushi packer",
  ["se-space"] = "Space sushi packer",
}
local function entity_keys(row)
  local out = { N.placer(row.key) }
  for _, dir in ipairs(N.DIRS) do out[#out + 1] = N.variant(row.key, dir) end
  out[#out + 1] = N.remnant(row.key)
  return out
end

describe("locale extra", function()
  it("every extra tier has names and descriptions", function()
    for _, row in ipairs(N.EXTRA) do
      local item, tech = N.item(row.key), N.tech(row.key)
      assert(has("item-name", item) and has("item-description", item), "item locale: " .. row.key)
      assert(has("technology-name", tech) and has("technology-description", tech), "tech locale: " .. row.key)
      for _, key in ipairs(entity_keys(row)) do
        assert(has("entity-name", key) and has("entity-description", key), "entity locale: " .. key)
      end
      assert(has("recipe-name", N.item(row.key)) and has("recipe-description", N.item(row.key)), "recipe locale: " .. row.key)
    end
  end)

  it("names mirror belt names", function()
    for _, row in ipairs(N.EXTRA) do
      local name = names[row.key]
      assert(value("item-name", N.item(row.key)) == name, "item: " .. row.key)
      assert(value("technology-name", N.tech(row.key)) == name, "technology: " .. row.key)
      assert(value("recipe-name", N.item(row.key)) == name, "recipe: " .. row.key)
      for _, key in ipairs({ N.placer(row.key), N.variant(row.key, "north"), N.variant(row.key, "east"), N.variant(row.key, "south"), N.variant(row.key, "west") }) do
        assert(value("entity-name", key) == name, key)
      end
      assert(value("entity-name", N.remnant(row.key)) == name .. " remnants", N.remnant(row.key))
    end
  end)

  it("descriptions name source mod", function()
    for _, row in ipairs(N.EXTRA) do
      local desc = value("item-description", N.item(row.key)) or ""
      assert(desc:find(row.mod, 1, true), "source mod missing from " .. row.key)
    end
  end)

  it("readme and portal list every supported mod", function()
    local mods = {}
    for _, row in ipairs(N.EXTRA) do mods[row.mod] = true end
    for _, path in ipairs({ "README.md", "portal/description.md" }) do
      local page = read(path)
      assert(page:find("## Modded belt tiers", 1, true), path .. " missing section")
      assert(page:find("Hyarion", 1, true), path .. " missing Hyarion note")
      for mod in pairs(mods) do assert(page:find(mod, 1, true), path .. " missing " .. mod) end
    end
  end)

  it("changelog has 0.2.9 and 0.1.9", function()
    local log = read("changelog.txt")
    local sep = string.rep("-", 99)
    assert(log:find("Version: 0.2.9\nDate: 2026%-09%-28"), "missing 0.2.9 block/date")
    assert(log:find("Version: 0.1.9\nDate: 2026%-09%-28"), "missing 0.1.9 block/date")
    assert(log:find(sep, 1, true), "missing 99-dash separator")
    local v19, v18 = log:find("Version: 0.1.9", 1, true), log:find("Version: 0.1.8", 1, true)
    assert(v19 and v18 and v19 < v18, "0.1.9 must precede 0.1.8")
  end)
  it("changelog has 0.2.11 and 0.1.11", function()
    local log = read("changelog.txt")
    local v211, v210 = log:find("Version: 0.2.11\nDate: 2026%-09%-29"), log:find("Version: 0.2.10", 1, true)
    local v111, v110 = log:find("Version: 0.1.11\nDate: 2026%-09%-29"), log:find("Version: 0.1.10", 1, true)
    assert(v211 and v210 and v211 < v210, "0.2.11 must precede 0.2.10")
    assert(v111 and v110 and v111 < v110, "0.1.11 must precede 0.1.10")
  end)
  it("se space name", function()
    assert(value("item-name", "se-space-sushi-packer") == "Space sushi packer")
  end)
  it("changelog has 0.2.12 and 0.1.12", function()
    local log = read("changelog.txt")
    local v212, v211 = log:find("Version: 0.2.12\nDate: 2026%-09%-29"), log:find("Version: 0.2.11", 1, true)
    local v112, v111 = log:find("Version: 0.1.12\nDate: 2026%-09%-29"), log:find("Version: 0.1.11", 1, true)
    assert(v212 and v211 and v212 < v211, "0.2.12 must precede 0.2.11")
    assert(v112 and v111 and v112 < v111, "0.1.12 must precede 0.1.11")
  end)
  it("changelog has 0.2.13 and 0.1.13", function()
    local log = read("changelog.txt")
    local v213, v212 = log:find("Version: 0.2.13\nDate: 2026%-09%-30"), log:find("Version: 0.2.12", 1, true)
    local v113, v112 = log:find("Version: 0.1.13\nDate: 2026%-09%-30"), log:find("Version: 0.1.12", 1, true)
    assert(v213 and v212 and v213 < v212, "0.2.13 must precede 0.2.12")
    assert(v113 and v112 and v113 < v112, "0.1.13 must precede 0.1.12")
    assert(log:find("library", v213, true) and log:find("library", v113, true), "entry names library blueprint fix")
  end)
  it("changelog has 0.2.14 and 0.1.14", function()
    local log = read("changelog.txt")
    local v214, v213 = log:find("Version: 0.2.14\nDate: 2026%-09%-30"), log:find("Version: 0.2.13", 1, true)
    local v114, v113 = log:find("Version: 0.1.14\nDate: 2026%-09%-30"), log:find("Version: 0.1.13", 1, true)
    assert(v214 and v213 and v214 < v213, "0.2.14 must precede 0.2.13")
    assert(v114 and v113 and v114 < v113, "0.1.14 must precede 0.1.13")
    assert(log:find("Mining Drones", v214, true) and log:find("Mining Drones", v114, true), "entry names Mining Drones fix")
  end)
  it("readme lists space tier", function()
    local expected = "| Space sushi packer | Space Exploration | 45/s |"
    for _, path in ipairs({ "README.md", "portal/description.md" }) do
      assert(read(path):find(expected, 1, true), path .. " missing space tier")
    end
  end)
end)
