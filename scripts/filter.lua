-- P-1 v6: skip filters with splitter-style quality rule. Pure: no game API. Lane 015 (task 015) fills.
local M = {}

-- filters: array of { name, quality = string|nil (nil = any), comparator = "="|"≠"|">"|"<"|"≥"|"≤"|nil (nil = "=") }
-- levels: { [quality name] = level } (LuaQualityPrototype.level). Returns true when any filter matches.
local function compare(a, op, b)
  if op == "=" then return a == b end
  if op == "≠" then return a ~= b end
  if op == ">" then return a > b end
  if op == "<" then return a < b end
  if op == "≥" then return a >= b end
  if op == "≤" then return a <= b end
  return false
end

function M.match(filters, name, quality, levels)
  for _, f in ipairs(filters or {}) do
    if type(f) == "table" and f.name == name then
      if f.quality == nil then return true end
      local actual, wanted = levels[quality], levels[f.quality]
      if actual ~= nil and wanted ~= nil and compare(actual, f.comparator or "=", wanted) then return true end
    end
  end
  return false
end

return M
