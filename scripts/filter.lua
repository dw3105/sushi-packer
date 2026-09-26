-- P-1 v6: skip filters with splitter-style quality rule. Pure: no game API. Lane 015 (task 015) fills.
local M = {}

-- filters: array of { name, quality = string|nil (nil = any), comparator = "="|"≠"|">"|"<"|"≥"|"≤"|nil (nil = "=") }
-- levels: { [quality name] = level } (LuaQualityPrototype.level). Returns true when any filter matches.
function M.match(filters, name, quality, levels) error("stub: task 015") end

return M
