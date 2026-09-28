-- Optional modded belt tiers, selected from the final data.raw after all mods have loaded.
local M = {}
local N = require("scripts.names")

local function skip(key, reason)
  log("sushi-packer: skip tier " .. key .. ": " .. reason)
end

function M.tiers(raw)
  local candidates = {}
  for row_index, row in ipairs(N.EXTRA) do
    local belt = raw["transport-belt"] and raw["transport-belt"][row.belt]
    local tech = raw.technology and raw.technology[row.tech]
    if not belt then
      skip(row.key, "belt prototype missing")
    elseif belt.hidden then
      skip(row.key, "belt prototype hidden")
    elseif not tech then
      skip(row.key, "technology prototype missing")
    elseif tech.hidden then
      skip(row.key, "technology prototype hidden")
    elseif not tech.unit then
      skip(row.key, "technology has no research unit")
    else
      candidates[#candidates + 1] = { key = row.key, speed = belt.speed, row_index = row_index }
    end
  end
  table.sort(candidates, function(a, b)
    if a.speed == b.speed then return a.row_index < b.row_index end
    return a.speed < b.speed
  end)
  local out, previous = {}, "turbo"
  for _, candidate in ipairs(candidates) do
    out[#out + 1] = { key = candidate.key, prev = previous, speed = candidate.speed }
    previous = candidate.key
  end
  return out
end

function M.build(raw)
  local rows = M.tiers(raw)
  local tier = require("prototypes.tier")
  for position, row in ipairs(rows) do
    local next_row = rows[position + 1]
    data:extend(tier.make(row.key, {
      prev = row.prev,
      next = next_row and next_row.key or nil,
      index = #N.TIERS + position,
    }))
  end
  if #rows > 0 then
    for _, dir in ipairs(N.DIRS) do
      raw.container[N.variant("turbo", dir)].next_upgrade = N.variant(rows[1].key, dir)
    end
  end
end

return M
