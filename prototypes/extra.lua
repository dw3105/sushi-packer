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
      candidates[#candidates + 1] = { key = row.key, speed = belt.speed, row_index = row_index, after = row.after,
        root = row.key == "se-space" and row.own_role and not row.after }
    end
  end
  table.sort(candidates, function(a, b)
    if a.speed == b.speed then return a.row_index < b.row_index end
    return a.speed < b.speed
  end)
  local active = {}; for _, c in ipairs(candidates) do active[c.key] = c end
  local main, out = {}, {}
  for _, c in ipairs(candidates) do
    if c.after and not active[c.after] then
      skip(c.key, "previous tier " .. c.after .. " not active")
    elseif not c.after and not c.root then main[#main + 1] = c end
  end
  local main_prev = top
  for _, c in ipairs(main) do
    out[#out + 1] = { key = c.key, prev = main_prev, speed = c.speed }; main_prev = c.key
  end
  for _, c in ipairs(candidates) do
    if c.root then out[#out + 1] = { key = c.key, speed = c.speed }
    elseif c.after and active[c.after] then out[#out + 1] = { key = c.key, prev = c.after, speed = c.speed } end
  end
  table.sort(out, function(a,b) if a.speed == b.speed then
    local ai,bi; for i,r in ipairs(N.EXTRA) do if r.key==a.key then ai=i elseif r.key==b.key then bi=i end end; return ai<bi
  end; return a.speed<b.speed end)
  return out
end

function M.build(raw)
  local rows = M.tiers(raw)
  local tier = require("prototypes.tier")
  local successor = {}
  local main = {}; for _, row in ipairs(rows) do
    local meta; for _, r in ipairs(N.EXTRA) do if r.key == row.key then meta=r; break end end
    if meta and not meta.after and not (meta.key == "se-space" and meta.own_role) then main[#main+1]=row end
    if meta and meta.after then successor[meta.after]=row.key end
  end
  for i=1,#main-1 do successor[main[i].key]=main[i+1].key end
  for _, row in ipairs(rows) do
    local meta; for _, r in ipairs(N.EXTRA) do if r.key == row.key then meta=r; break end end
    if meta and meta.key == "se-space" and meta.own_role and not meta.after then
      for _, r in ipairs(N.EXTRA) do if r.after==row.key and successor[row.key]==nil then successor[row.key]=r.key end end
    end
  end
  for position, row in ipairs(rows) do
    data:extend(tier.make(row.key, {
      prev = row.prev,
      next = successor[row.key], root = row.prev == nil,
      index = #N.TIERS + position,
    }))
  end
  if #rows > 0 then
    local top = M.top_vanilla(raw)
    local first_main
    for _, row in ipairs(rows) do
      local meta; for _, r in ipairs(N.EXTRA) do if r.key == row.key then meta=r; break end end
      if meta and not meta.after and not (meta.key == "se-space" and meta.own_role) then first_main=row.key; break end
    end
    for _, dir in ipairs(N.DIRS) do
      local base = top and raw.container[N.variant(top, dir)]
      if base then
        base.next_upgrade = first_main and N.variant(first_main, dir) or nil
        -- FND-0029: other mods may resize our containers before this runs (aai-containers resize-1x1);
        -- upgrade chain needs one bounding box, so extras copy the top vanilla box.
        for _, row in ipairs(rows) do
          raw.container[N.variant(row.key, dir)].collision_box = table.deepcopy(base.collision_box)
        end
      end
    end
  end
end

return M
