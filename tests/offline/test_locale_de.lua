local N = require("scripts.names")

local function read(path)
  local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s
end

local function entries(path)
  local found, section = {}, nil
  for line in read(path):gmatch("[^\r\n]+") do
    local name = line:match("^%[(.-)%]$")
    if name then section = name
    else
      local key, value = line:match("^([^=]+)=(.*)$")
      if key then found[section .. "/" .. key] = value end
    end
  end
  return found
end

local function value(path, section, key)
  return entries(path)[section .. "/" .. key]
end

describe("locale de", function()
  it("same keys as en", function()
    for _, name in ipairs({ "locale.cfg", "gui.cfg" }) do
      local en, de = entries("locale/en/" .. name), entries("locale/de/" .. name)
      local missing, extra = {}, {}
      for key in pairs(en) do if de[key] == nil then missing[#missing + 1] = key end end
      for key in pairs(de) do if en[key] == nil then extra[#extra + 1] = key end end
      table.sort(missing); table.sort(extra)
      assert(#missing == 0 and #extra == 0,
        name .. " missing: " .. table.concat(missing, ", ") .. "; extra: " .. table.concat(extra, ", "))
    end
  end)

  it("no empty value", function()
    for _, name in ipairs({ "locale.cfg", "gui.cfg" }) do
      for key, val in pairs(entries("locale/de/" .. name)) do
        assert(val:match("%S"), name .. " empty value: " .. key)
      end
    end
  end)

  it("tier names end with Sushi-Packer", function()
    for _, tier in ipairs(N.ALL) do
      local key = N.item(tier)
      local name = value("locale/de/locale.cfg", "item-name", key)
      assert(name and name:sub(-12) == "Sushi-Packer", key .. ": " .. tostring(name))
    end
  end)

  it("names follow table", function()
    local expected = {
      ["sushi-packer"] = "Sushi-Packer", ["fast-sushi-packer"] = "Schneller Sushi-Packer",
      ["express-sushi-packer"] = "Express-Sushi-Packer", ["se-space-sushi-packer"] = "Space-Sushi-Packer",
      ["ab-elite-sushi-packer"] = "Elite-Sushi-Packer", ["kr-superior-sushi-packer"] = "Überlegener Sushi-Packer",
    }
    for key, name in pairs(expected) do
      assert(value("locale/de/locale.cfg", "item-name", key) == name, key)
    end
  end)

  it("same parameters as en", function()
    for _, name in ipairs({ "locale.cfg", "gui.cfg" }) do
      local en, de = entries("locale/en/" .. name), entries("locale/de/" .. name)
      for key, text in pairs(en) do
        local expected = {}
        for parameter in text:gmatch("(__%d+__)") do expected[parameter] = true end
        for parameter in pairs(expected) do
          assert((de[key] or ""):find(parameter, 1, true), name .. " " .. key .. " missing " .. parameter)
        end
      end
    end
  end)
  it("vanilla German terms", function()
    -- integrator review v11: vanilla de says Fließbandseite (lane), Stapelhöhe (belt stack), tech Fließband-Kapazität;
    -- no per-entity remnant names in vanilla -> "Überreste: <Name>" avoids adjective declension.
    local de = entries("locale/de/locale.cfg")
    for key, v in pairs(de) do
      for _, bad in ipairs({ "Spur", "spur", "Bandstapel", "Bandkapazität", "Entspricht dem" }) do
        ok(not v:find(bad, 1, true), key .. " uses non-vanilla term " .. bad)
      end
      if key:match("^entity%-name/.*%-remnants$") then ok(v:sub(1, #"Überreste: ") == "Überreste: ", key .. " remnant pattern") end
    end
    ok(de["tips-and-tricks-item-description/sushi-packer-tips"]:find("Fließbandseiten", 1, true), "tips use Fließbandseiten")
  end)
end)
