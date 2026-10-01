-- v15 arms box: pure rules (no game API). What leaves a lane store, in what order. Seam: docs/CONTRACT.md.
local N = require("scripts.names")
local M = {}
local EMPTY = {}

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

local function plan_full(state, lane, contents, opts)
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

  -- F-1: only when an arriving item needs a slot (caller may say need_slot = false: nothing new waits).
  if not priority_output and not timed_output and not flush_all and opts.slots_used >= opts.slots and opts.need_slot ~= false then
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

-- v15 perf: called every lane visit; most visits nothing leaves. One pass, no table, no string made: update first-seen
-- clocks, find out whether anything may leave; only then run the full planner. EMPTY is shared: callers never write it.
local key_cache = {}
local function key_of(name, quality)
  local by = key_cache[name]
  if not by then by = {}; key_cache[name] = by end
  local key = by[quality]
  if not key then key = name .. "\0" .. quality; by[quality] = key end
  return key
end
local OUT, POOL = {}, {}          -- reused result list + piece tables: result is valid until next plan call
local cand, cand_first = {}, {}   -- scratch: indexes of kinds with a full stack, their first-seen ticks
function M.plan(state, lane, contents, opts)
  local seen = state.seen[lane]
  local n = #contents
  local sizes = state.size
  if not sizes then sizes = { 0, 0 }; state.size = sizes end
  local tick, bss, stack_size, skip, timeout = opts.tick, opts.bss, opts.stack_size, opts.skip, opts.timeout_ticks
  local complex = false
  local cn = 0
  for i = 1, n do
    local item = contents[i]
    local name, quality = item.name, item.quality
    local by = key_cache[name]
    if not by then by = {}; key_cache[name] = by end
    local key = by[quality]
    if not key then key = name .. "\0" .. quality; by[quality] = key end
    local first = seen[key]
    if first == nil then first = tick; seen[key] = tick; sizes[lane] = sizes[lane] + 1 end
    local size = stack_size(name)
    if bss < size then size = bss end
    if item.count >= size then cn = cn + 1; cand[cn] = i; cand_first[cn] = first end
    if (skip and skip(name, quality)) or (timeout > 0 and tick - first >= timeout) then complex = true end
  end
  if sizes[lane] ~= n then  -- some kind left the store: forget its clock
    local present = {}
    for i = 1, n do present[key_of(contents[i].name, contents[i].quality)] = true end
    for key in pairs(seen) do if not present[key] then seen[key] = nil end end
    sizes[lane] = n
  end
  if n == 0 then return EMPTY end
  if complex or opts.flush_all or (cn == 0 and opts.slots_used >= opts.slots and opts.need_slot ~= false) then
    return plan_full(state, lane, contents, opts)
  end
  if cn == 0 then return EMPTY end
  -- common case: only full stacks leave. Order by first seen, then name, then quality (few candidates: insertion sort).
  for a = 2, cn do
    local ia, fa = cand[a], cand_first[a]
    local na, qa = contents[ia].name, contents[ia].quality
    local b = a - 1
    while b >= 1 do
      local ib, fb = cand[b], cand_first[b]
      local before
      if fa ~= fb then before = fa < fb
      elseif na ~= contents[ib].name then before = na < contents[ib].name
      else before = qa < contents[ib].quality end
      if not before then break end
      cand[b + 1], cand_first[b + 1] = ib, fb
      b = b - 1
    end
    cand[b + 1], cand_first[b + 1] = ia, fa
  end
  local k = 0
  for a = 1, cn do
    local item = contents[cand[a]]
    local name, quality = item.name, item.quality
    local size = stack_size(name)
    if bss < size then size = bss end
    for _ = 1, math.floor(item.count / size) do
      k = k + 1
      local piece = POOL[k]
      if not piece then piece = {}; POOL[k] = piece end
      piece.name, piece.quality, piece.count = name, quality, size
      OUT[k] = piece
    end
  end
  for extra = k + 1, #OUT do OUT[extra] = nil end
  return OUT
end

-- C-6 (V15-3): kinds a lane must stop taking, with memory: a kind is blocked once the lane store holds one full
-- inventory stack of it and stays blocked until it is down to half a stack. One fixed limit toggled the arm filter on
-- every item and starved output (rate test 2026-10-01: blue 187 of 225). Items already in arm hands still arrive,
-- so a store may hold somewhat more than one stack (bound: arms of lane x hand size).
function M.hoard(state, lane, contents, stack_size)
  local hoards = state.hoard
  if not hoards then hoards = { {}, {} }; state.hoard = hoards end
  local blocked = hoards[lane]
  local n = #contents
  local any = next(blocked) ~= nil
  if not any then
    for i = 1, n do
      local item = contents[i]
      if item.count >= stack_size(item.name) then any = true; break end
    end
    if not any then return EMPTY end  -- common case, no table made
  end
  local present = {}
  local names, qualities, counts, indices = {}, {}, {}, {}
  for i = 1, n do
    local item = contents[i]
    local key = key_of(item.name, item.quality)
    present[key] = true
    local size = stack_size(item.name)
    if item.count >= size then blocked[key] = true
    elseif blocked[key] and item.count <= size / 2 then blocked[key] = nil end
    if blocked[key] then
      names[i], qualities[i], counts[i] = item.name, item.quality, item.count
      indices[#indices + 1] = i
    end
  end
  for key in pairs(blocked) do if not present[key] then blocked[key] = nil end end
  if #indices == 0 then return EMPTY end
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

-- v16 seam stubs (lane 049 fills): docs/CONTRACT.md "v16 engine output seam".
function M.scan(state, lane, contents, opts) error("stub: ledger.scan") end
function M.hands(state, lane, held, opts) error("stub: ledger.hands") end

function M.led(used_left, used_right, slots)
  if used_left >= slots or used_right >= slots then return "red" end
  if used_left == 0 and used_right == 0 then return "green" end
  return "yellow"
end

return M
