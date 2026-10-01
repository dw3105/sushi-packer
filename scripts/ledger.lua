-- v15 arms box: pure rules (no game API). What leaves a lane store, in what order. Seam: docs/CONTRACT.md.
local N = require("scripts.names")
local M = {}

function M.new()
  return { seen = { {}, {} } }
end

local function before(a, b, seen, names, qualities)
  local ta, tb = seen[a], seen[b]
  if ta ~= tb then return ta < tb end
  if names[a] ~= names[b] then return names[a] < names[b] end
  return qualities[a] < qualities[b]
end

local function append_pieces(out, name, quality, count, size)
  while count > 0 do
    local n = count < size and count or size
    out[#out + 1] = { name = name, quality = quality, count = n }
    count = count - n
  end
end

function M.plan(state, lane, contents, opts)
  local seen = state.seen[lane]
  local names, qualities, counts, sizes, ticks = {}, {}, {}, {}, {}
  local present, indices = {}, {}
  for i = 1, #contents do
    local item = contents[i]
    local name, quality = item.name, item.quality
    local key = name .. "\0" .. quality
    names[i], qualities[i], counts[i] = name, quality, item.count
    present[key] = true
    local first = seen[key]
    if first == nil then first = opts.tick; seen[key] = first end
    ticks[i] = first
    local size = opts.bss
    local item_size = opts.stack_size(name)
    if item_size < size then size = item_size end
    sizes[i] = size
    indices[i] = i
  end
  for key in pairs(seen) do
    if not present[key] then seen[key] = nil end
  end
  table.sort(indices, function(a, b) return before(a, b, ticks, names, qualities) end)

  local out, skip = {}, {}
  for _, i in ipairs(indices) do
    if opts.skip and opts.skip(names[i], qualities[i]) then
      skip[#skip + 1] = i
    end
  end
  for _, i in ipairs(skip) do
    append_pieces(out, names[i], qualities[i], counts[i], sizes[i])
  end

  for _, i in ipairs(indices) do
    if not (opts.skip and opts.skip(names[i], qualities[i])) then
      local n = math.floor(counts[i] / sizes[i])
      if n > 0 then
        for _ = 1, n do out[#out + 1] = { name = names[i], quality = qualities[i], count = sizes[i] } end
      end
    end
  end

  local priority_output = #out > 0
  local flush_all = opts.flush_all
  local timeout = opts.timeout_ticks
  local timed_output = false
  for _, i in ipairs(indices) do
    if not (opts.skip and opts.skip(names[i], qualities[i])) then
      local rem = counts[i] % sizes[i]
      if rem > 0 and (flush_all or (timeout > 0 and opts.tick - ticks[i] >= timeout)) then
        out[#out + 1] = { name = names[i], quality = qualities[i], count = rem }
        if timeout > 0 and opts.tick - ticks[i] >= timeout then timed_output = true end
      end
    end
  end

  if not priority_output and not timed_output and not flush_all and opts.slots_used >= opts.slots then
    -- Store pressure flushes one oldest leftover, but never competes with a full/skip/timed flush.
    for _, i in ipairs(indices) do
      if not (opts.skip and opts.skip(names[i], qualities[i])) then
        local rem = counts[i] % sizes[i]
        if rem > 0 then
          out[#out + 1] = { name = names[i], quality = qualities[i], count = rem }
          break
        end
      end
    end
  end
  return out
end

function M.hoard(contents, stack_size)
  local names, qualities, counts = {}, {}, {}
  local indices = {}
  for i = 1, #contents do
    local item = contents[i]
    if item.count >= stack_size(item.name) then
      names[i], qualities[i], counts[i] = item.name, item.quality, item.count
      indices[#indices + 1] = i
    end
  end
  table.sort(indices, function(a, b)
    if counts[a] ~= counts[b] then return counts[a] > counts[b] end
    if names[a] ~= names[b] then return names[a] < names[b] end
    return qualities[a] < qualities[b]
  end)
  while #indices > N.ARM_FILTERS do indices[#indices] = nil end
  table.sort(indices, function(a, b)
    if names[a] ~= names[b] then return names[a] < names[b] end
    return qualities[a] < qualities[b]
  end)
  local out = {}
  for _, i in ipairs(indices) do out[#out + 1] = { name = names[i], quality = qualities[i] } end
  return out
end

function M.led(used_left, used_right, slots)
  if used_left >= slots or used_right >= slots then return "red" end
  if used_left == 0 and used_right == 0 then return "green" end
  return "yellow"
end

return M
