local N = require("scripts.names")

local function read(path)
  local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s
end

local function pairs_from(json, kind)
  local start = assert(json:find('"' .. kind .. '"%s*:%s*%['))
  local open = assert(json:find('%[', start))
  local boundary = json:find('\n  "', open + 1)
  local section = json:sub(open + 1, boundary and boundary - 1 or #json)
  local out = {}
  for old, new in section:gmatch('%["([^\"]+)",%s*"([^\"]+)"%]') do out[old] = new end
  return out
end

describe("migration", function()
  it("maps every old name to new", function()
    local json = read("migrations/sushi-packer_0.1.2.json")
    for _, kind in ipairs({ "entity", "item", "recipe", "technology" }) do
      local mapped = pairs_from(json, kind)
      for _, tier in ipairs(N.TIERS) do
        local old = N.old_item(tier)
        local expected = {}
        if kind == "entity" then
          expected = { [old .. "-placer"] = N.placer(tier), [old .. "-remnants"] = N.remnant(tier) }
          for _, dir in ipairs(N.DIRS) do expected[old .. "-" .. dir] = N.variant(tier, dir) end
        elseif kind == "item" or kind == "recipe" or kind == "technology" then expected[old] = N.item(tier) end
        for from, to in pairs(expected) do eq(mapped[from], to, kind .. ": " .. from) end
      end
    end
  end)
  it("both version files identical", function()
    eq(read("migrations/sushi-packer_0.1.2.json"), read("migrations/sushi-packer_0.2.2.json"))
  end)
end)
