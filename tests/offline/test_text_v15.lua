local function read(path)
  local f = assert(io.open(path, "r"), path .. " missing")
  local s = f:read("*a")
  f:close()
  return s
end

local function locale_values(text, section)
  local body = text:match("%[" .. section .. "%]%s*([^%[]*)") or ""
  local values = {}
  for key, value in body:gmatch("([%w%-_]+)=([^\r\n]*)") do values[key] = value end
  return values
end

describe("text v15", function()
  it("gui lane keys in en and de", function()
    for _, lang in ipairs({ "en", "de" }) do
      local values = locale_values(read("locale/" .. lang .. "/gui.cfg"), "gui")
      for _, key in ipairs({ "lanes", "lane-left", "lane-right" }) do
        ok(values[key] and values[key] ~= "", lang .. " missing [gui] key " .. key)
      end
    end
    local de = locale_values(read("locale/de/gui.cfg"), "gui")
    for _, key in ipairs({ "lanes", "lane-left", "lane-right" }) do
      ok(de[key]:find("Fließbandseite", 1, true), "German " .. key .. " must use Fließbandseite")
    end
  end)

  it("no stale slot counts", function()
    for _, path in ipairs({ "locale/en", "locale/de", "README.md", "portal/description.md" }) do
      local text
      if path:match("^locale/") then
        local p = io.popen("find " .. path .. " -type f -name '*.cfg' -print")
        local chunks = {}
        for file in p:lines() do chunks[#chunks + 1] = read(file) end
        p:close()
        text = table.concat(chunks, "\n")
      else
        text = read(path)
      end
      ok(not text:match("24%s+slots?") and not text:match("48%s+slots?"), path .. " has stale slot count")
      ok(not text:match("24%s+Plätze") and not text:match("48%s+Plätze"), path .. " has stale German slot count")
    end
    for _, path in ipairs({ "README.md", "portal/description.md" }) do
      local text = read(path):lower()
      ok(text:find("12 slots per lane", 1, true) or text:find("each lane has 12 slots", 1, true)
        or text:find("each lane holds 12 slots", 1, true), path .. " must say 12 slots per lane")
    end
  end)

  it("changelog has 0.1.15 and 0.2.15", function()
    local s = read("changelog.txt")
    for _, version in ipairs({ "0.2.15", "0.1.15" }) do
      local at = assert(s:find("Version: " .. version, 1, true), "missing " .. version)
      local next_version = s:find("Version: ", at + 1, true)
      local block = s:sub(at, next_version and next_version - 1 or #s)
      local _, bullets = block:gsub("\n    %- ", "\n    - ")
      assert(bullets >= 3, version .. " needs at least three bullets")
      ok(block:find("lane", 1, true) and block:find("window", 1, true), version .. " must mention lane window")
      ok(block:find("12 slots", 1, true), version .. " must mention 12 slots")
    end
    ok(s:find("Version: 0.2.15", 1, true) < s:find("Version: 0.2.14", 1, true), "0.2.15 must be above older entries")
    ok(s:find("Version: 0.1.15", 1, true) < s:find("Version: 0.1.14", 1, true), "0.1.15 must be above older entries")
  end)

  it("german avoids banned words", function()
    local p = io.popen("find locale/de -type f -name '*.cfg' -print")
    for file in p:lines() do
      local text = read(file)
      ok(not text:find("Spur", 1, true), file .. " contains banned word Spur")
      ok(not text:find("Bandstapel", 1, true), file .. " contains banned word Bandstapel")
    end
    p:close()
  end)
end)
