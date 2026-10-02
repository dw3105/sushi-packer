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
local SCAN_OUT, SCAN_POOL = {}, {}
local SCAN_NAMES, SCAN_QUALITIES, SCAN_COUNTS, SCAN_SIZES, SCAN_KIND_KEYS = {}, {}, {}, {}, {}
local SCAN_PRESENT = {}
local HANDS_OUT = {}
local function look_key(name, quality) return name .. "\0" .. quality end
local STEER_OUT, STEER_POOL = {}, {}
local STEER_OFF = 10
local STEER_FREE = 3
-- Kinds out arms of this lane may take, from the scan just made for it: reused array of { name, quality } (may be
-- empty: nothing has a full stack yet), or nil when lane is not steered.
function M.steer(state, lane)
  local steer = state.steer
  if steer and steer[lane] ~= nil then return STEER_OUT end
  return nil
end

function M.scan(state, lane, contents, opts)
  local left = state.left
  if not left then left = { {}, {} }; state.left = left end
  local ready = state.ready
  if not ready then ready = { 0, 0 }; state.ready = ready end
  local sweep = state.sweep
  if not sweep then sweep = { 0, 0 }; state.sweep = sweep end
  local clocks = left[lane]
  local tick, bss, timeout = opts.tick, opts.bss, opts.timeout_ticks
  local n, full, out_n = #contents, false, 0
  local names, qualities, counts, sizes, keys = SCAN_NAMES, SCAN_QUALITIES, SCAN_COUNTS, SCAN_SIZES, SCAN_KIND_KEYS
  local function add(item, size, key)
    out_n = out_n + 1
    local p = SCAN_POOL[out_n]
    if not p then p = {}; SCAN_POOL[out_n] = p end
    p.name, p.quality, p.count = item.name, item.quality, item.count
    SCAN_OUT[out_n] = p
    clocks[key] = nil
  end
  for i = 1, n do
    local item = contents[i]
    local name, quality, count = item.name, item.quality, item.count
    local size = bss
    local item_size = opts.stack_size(name)
    if item_size < size then size = item_size end
    local key = look_key(name, quality)
    names[i], qualities[i], counts[i], sizes[i], keys[i] = name, quality, count, size, key
    SCAN_PRESENT[key] = true
    if count >= size then
      full = true
      clocks[key] = nil
    elseif clocks[key] == nil then
      clocks[key] = tick
    end
  end
  for key in pairs(clocks) do if not SCAN_PRESENT[key] then clocks[key] = nil end end
  for key in pairs(SCAN_PRESENT) do SCAN_PRESENT[key] = nil end
  for i = n + 1, #names do names[i], qualities[i], counts[i], sizes[i], keys[i] = nil, nil, nil, nil, nil end
  ready[lane] = full and (ready[lane] or 0) + 1 or 0

  local flush_all = opts.flush_all
  local pressured = opts.need_slot and opts.slots_used >= opts.slots
  -- v20: steered lane keeps STEER_FREE slots free (leftover kinds wait in store there, new kinds keep arriving):
  -- oldest leftovers leave as they are, several per look
  local steered = state.steer ~= nil and state.steer[lane] ~= nil
  local spare = steered and (opts.slots_used - (opts.slots - STEER_FREE)) or 0
  local oldest_i, oldest_tick
  for i = 1, n do
    if counts[i] < sizes[i] then
      local age = clocks[keys[i]]
      if flush_all or (timeout > 0 and tick - age >= timeout) then
        add(contents[i], sizes[i], keys[i])
      elseif pressured and (oldest_tick == nil or age < oldest_tick or
          (age == oldest_tick and (names[i] < names[oldest_i] or
            (names[i] == names[oldest_i] and qualities[i] < qualities[oldest_i])))) then
        oldest_i, oldest_tick = i, age
      end
    end
  end
  if pressured and oldest_i then
    local already = false
    for i = 1, out_n do if SCAN_OUT[i].name == names[oldest_i] and SCAN_OUT[i].quality == qualities[oldest_i] then already = true; break end end
    if not already then add(contents[oldest_i], sizes[oldest_i], keys[oldest_i]) end
  end
  while spare > 0 do
    local pick, pick_tick
    for i = 1, n do
      if counts[i] < sizes[i] and clocks[keys[i]] ~= nil then
        local age = clocks[keys[i]]
        if pick_tick == nil or age < pick_tick or (age == pick_tick and (names[i] < names[pick] or
            (names[i] == names[pick] and qualities[i] < qualities[pick]))) then pick, pick_tick = i, age end
      end
    end
    if not pick then break end
    add(contents[pick], sizes[pick], keys[pick])  -- clears its clock: not picked twice
    spare = spare - 1
  end
  for i = out_n + 1, #SCAN_OUT do SCAN_OUT[i] = nil end
  -- hand look is costly: only on flush_all, at sweep, or when lane looks jammed (full stacks seen at two looks in a
  -- row AND store piles up: 16 belt stacks or more). A busy healthy lane holds few items (FND-0046).
  local total = 0
  for i = 1, n do total = total + counts[i] end
  local piled = ready[lane] >= 2 and total >= 16 * bss
  -- second jam sign: store holds full stacks and is exactly the same (kinds, items) at three looks in a row while
  -- front belt has room: arms are not taking them, so they all hold leftovers of other kinds.
  local same = state.same
  if not same then same = { 0, 0 }; state.same = same; state.last_n = { -1, -1 }; state.last_total = { -1, -1 } end
  if full and state.last_n[lane] == n and state.last_total[lane] == total then same[lane] = same[lane] + 1 else same[lane] = 0 end
  state.last_n[lane], state.last_total[lane] = n, total
  if not piled and same[lane] >= 2 and opts.can_push == true then piled = true end
  local piles = state.piled
  if not piles then piles = { false, false }; state.piled = piles end
  piles[lane] = piled
  -- v20 steering (V20-1): a lane whose out arms were all found holding leftovers (hands look at a jam, M.hands) gets
  -- out arms that may take only kinds with a full belt stack in store, so no arm picks up a leftover again.
  -- state.steer[lane] = quiet looks in a row, nil = off.
  -- Stays on while store holds leftovers and as many kinds as there are out arms, goes off after STEER_OFF quiet looks.
  local steer = state.steer
  if not steer then steer = {}; state.steer = steer end
  local sn = 0
  if steer[lane] ~= nil then
    local partial = false
    for i = 1, n do
      if counts[i] >= sizes[i] then
        sn = sn + 1
        local k = STEER_POOL[sn]
        if not k then k = {}; STEER_POOL[sn] = k end
        k.name, k.quality = names[i], qualities[i]
        STEER_OUT[sn] = k
      else
        partial = true
      end
    end
    -- needed while leftover kinds could take every out arm: n_out kinds or more in store. Fewer kinds: count quiet looks.
    if partial and n >= (opts.n_out or 8) then steer[lane] = 0 else steer[lane] = steer[lane] + 1 end
    if steer[lane] > STEER_OFF then steer[lane] = nil end
  end
  for i = sn + 1, #STEER_OUT do STEER_OUT[i] = nil end
  -- busy lane (full stack in store now): hands fill by themselves, sweep late
  local due = (sweep[lane] or 0) + (ready[lane] > 0 and 480 or 0)
  local want = flush_all or piled or tick >= due
  return SCAN_OUT, want
end

-- v16 INT (V16-8). Called only when scan wants hands. Returns (both reused, valid until next call):
--   flush: ascending out-arm indexes whose partial hand is pushed out as it is;
--   merge: at most one entry per kind: { name=, quality=, total=, arms = { ascending arm indexes } }: partial hands of
--          one kind that together hold at least one belt stack. Caller clears those hands, pushes one full stack,
--          puts the rest (total - S) back into the lane store.
local SWEEP = 300  -- hand looks cost ~80 us per lane (bench 2026-10-01): rare
local MERGE_OUT, MERGE_POOL = {}, {}
local HAND_SIZE, HAND_KEY, HAND_MERGED, HAND_OK = {}, {}, {}, {}
function M.hands(state, lane, held, opts)
  local ready = state.ready
  if not ready then ready = { 0, 0 }; state.ready = ready end
  local sweep = state.sweep
  if not sweep then sweep = { 0, 0 }; state.sweep = sweep end
  local memories = state.held
  if not memories then memories = { {}, {} }; state.held = memories end
  local sinces = state.since
  if not sinces then sinces = { {}, {} }; state.since = sinces end
  local cmems = state.hcount
  if not cmems then cmems = { {}, {} }; state.hcount = cmems end
  local memory, since, counts_mem = memories[lane], sinces[lane], cmems[lane]
  local tick, timeout, bss, flush_all = opts.tick, opts.timeout_ticks, opts.bss, opts.flush_all
  local n = #held
  local do_sweep = tick >= (sweep[lane] or 0)  -- (scan may call later than this on a busy lane)
  local jam = state.piled ~= nil and state.piled[lane] == true  -- store piles up: arms holding leftovers are lost capacity
  local hostage_kinds = 0

  -- per hand: belt stack size of its kind (0 = full hand, not our business), key
  for i = 1, n do
    local h = held[i]
    local size = bss
    local item_size = opts.stack_size(h.name)
    if item_size < size then size = item_size end
    if h.count < size then HAND_SIZE[i] = size; HAND_KEY[i] = look_key(h.name, h.quality) else HAND_SIZE[i] = 0; HAND_KEY[i] = false end
    HAND_MERGED[i] = false
    if jam and HAND_KEY[i] then  -- distinct leftover kinds in hands
      local seen = false
      for j = 1, i - 1 do if HAND_KEY[j] == HAND_KEY[i] then seen = true; break end end
      if not seen then hostage_kinds = hostage_kinds + 1 end
    end
    -- may this hand be merged now? At every sweep, in a jam, on flush_all.
    HAND_OK[i] = HAND_KEY[i] and (flush_all or jam or do_sweep) or false
  end
  for i = n + 1, #HAND_SIZE do HAND_SIZE[i], HAND_KEY[i], HAND_MERGED[i], HAND_OK[i] = nil, nil, nil, nil end
  -- v20: jam with (nearly) every out arm holding a leftover of another kind: more kinds than arms can carry this way.
  -- From next look on the lane is steered (scan). Few kinds (busy lane, arms simply full): never.
  if jam and hostage_kinds >= (opts.n_out or 8) - 2 then
    local steer = state.steer
    if not steer then steer = {}; state.steer = steer end
    if steer[lane] == nil then steer[lane] = 0 end
  end

  -- merges: first kind (arm order) whose partial hands reach one stack; shortest prefix of its hands
  local merge_n, more = 0, false
  for i = 1, n do
    local key = HAND_KEY[i]
    if key and HAND_OK[i] and not HAND_MERGED[i] then
      local total, last = 0, nil
      for j = i, n do
        if HAND_KEY[j] == key and HAND_OK[j] then
          total = total + held[j].count
          if total >= HAND_SIZE[i] then last = j; break end
        end
      end
      if last then
        merge_n = merge_n + 1
        local m = MERGE_POOL[merge_n]
        if not m then m = { arms = {} }; MERGE_POOL[merge_n] = m end
        local arms, an = m.arms, 0
        for j = i, last do if HAND_KEY[j] == key and HAND_OK[j] then an = an + 1; arms[an] = held[j].arm; HAND_MERGED[j] = true end end
        for j = an + 1, #arms do arms[j] = nil end
        m.name, m.quality, m.total = held[i].name, held[i].quality, total
        MERGE_OUT[merge_n] = m
        -- other hands of this kind wait for a later call: mark them so they are neither merged twice nor flushed now
        local later = total - HAND_SIZE[i]  -- what goes back to store ...
        for j = last + 1, n do if HAND_KEY[j] == key then HAND_MERGED[j] = true; later = later + held[j].count end end
        if later >= HAND_SIZE[i] then more = true end  -- ... plus other hands: another full stack of this kind waits
      end
    end
  end
  for i = merge_n + 1, #MERGE_OUT do MERGE_OUT[i] = nil end

  local out_n = 0
  for i = 1, n do
    local key = HAND_KEY[i]
    if key and not HAND_MERGED[i] then
      local arm = held[i].arm
      local flush = flush_all or jam
      if do_sweep and not flush then
        if memory[arm] == key then
          if timeout > 0 and tick - since[arm] >= timeout then flush = true end
        else
          memory[arm], since[arm] = key, tick
        end
        counts_mem[arm] = held[i].count
      end
      if flush then
        out_n = out_n + 1; HANDS_OUT[out_n] = arm
        memory[arm], since[arm], counts_mem[arm] = nil, nil, nil
      end
    end
  end
  if do_sweep then
    -- forget arms that no longer hold the remembered partial hand
    for arm, key in pairs(memory) do
      local still = false
      for i = 1, n do if held[i].arm == arm and HAND_KEY[i] == key and not HAND_MERGED[i] then still = true; break end end
      if not still then memory[arm], since[arm], counts_mem[arm] = nil, nil, nil end
    end
    -- next sweep: normal pace, or sooner when a remembered hand runs out of time before that (not before next look)
    local next_sweep = tick + (more and 30 or SWEEP)  -- belt takes one push per look: come back for the next stack
    if timeout > 0 then
      for arm in pairs(memory) do
        local ends = since[arm] + timeout
        if ends < next_sweep then next_sweep = ends end
      end
      if next_sweep < tick + 30 then next_sweep = tick + 30 end
    end
    sweep[lane] = next_sweep
  end
  for i = 2, out_n do
    local arm, j = HANDS_OUT[i], i - 1
    while j >= 1 and HANDS_OUT[j] > arm do HANDS_OUT[j + 1] = HANDS_OUT[j]; j = j - 1 end
    HANDS_OUT[j + 1] = arm
  end
  for i = out_n + 1, #HANDS_OUT do HANDS_OUT[i] = nil end
  return HANDS_OUT, MERGE_OUT
end

function M.led(used_left, used_right, slots)
  if used_left >= slots or used_right >= slots then return "red" end
  if used_left == 0 and used_right == 0 then return "green" end
  return "yellow"
end

return M
