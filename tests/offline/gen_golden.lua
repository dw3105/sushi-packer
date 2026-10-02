package.path = "./?.lua;" .. package.path
local F = require("tests.offline.fake_data")
F.reset()
dofile("prototypes/packer.lua")

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

local file = assert(io.open("tests/offline/golden_vanilla.lua", "w"))
file:write("return " .. string.format("%q", dump(F.extended)) .. "\n")
file:close()
