-- Optional modded belt tiers, selected from the final data.raw after all mods have loaded.
local M = {}
local N = require("scripts.names")

local function skip(key, reason)
  log("sushi-packer: skip tier " .. key .. ": " .. reason)
end

local function vanilla_belt(raw, key)
  local T = N.TIER[key]
  local belt = raw["transport-belt"] and raw["transport-belt"][T.belt]
  local tech = raw.technology and raw.technology[T.tech]
  return belt and tech and tech.unit and belt or nil
end

function M.top_vanilla(raw)
  for index = #N.TIERS, 1, -1 do
    local key = N.TIERS[index]
    if vanilla_belt(raw, key) then return key end
  end
end

function M.tiers(raw, mods)
  mods = mods or _G.mods or {}
  local top = M.top_vanilla(raw)
  local top_proto = top and vanilla_belt(raw, top)
  local top_speed = top_proto and top_proto.speed or 0
  local candidates = {}
  for row_index, row in ipairs(N.EXTRA) do
    local belt = raw["transport-belt"] and raw["transport-belt"][row.belt]
    local splitter = raw.splitter and raw.splitter[row.splitter] or raw.item and raw.item[row.splitter]
    local tech = raw.technology and raw.technology[row.tech]
    local owner_loaded = false
    for _, owner in ipairs(row.owners or {}) do if mods[owner] ~= nil then owner_loaded = true; break end end
    if not owner_loaded then
      skip(row.key, "owner mod not loaded")
    elseif not belt then
      skip(row.key, "belt prototype missing")
    elseif belt.hidden then
      skip(row.key, "belt prototype hidden")
    elseif not splitter then
      skip(row.key, "splitter prototype missing")
    elseif not tech then
      skip(row.key, "technology prototype missing")
    elseif tech.hidden then
      skip(row.key, "technology prototype hidden")
    elseif not tech.unit then
      skip(row.key, "technology has no research unit")
    elseif belt.speed <= top_speed and not row.own_role then
      skip(row.key, "belt speed not above top vanilla tier")
    else
      candidates[#candidates + 1] = { key = row.key, speed = belt.speed, row_index = row_index }
    end
  end
  table.sort(candidates, function(a, b)
    if a.speed == b.speed then return a.row_index < b.row_index end
    return a.speed < b.speed
  end)
  local out, previous = {}, top
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
      local top = M.top_vanilla(raw)
      if top then raw.container[N.variant(top, dir)].next_upgrade = N.variant(rows[1].key, dir) end
    end
  end
end

return M
