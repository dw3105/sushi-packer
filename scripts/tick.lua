local N = require("scripts.names")
local belt_io = require("scripts.belt_io")
local circuit = require("scripts.circuit")
local led = require("scripts.led")
local filter = require("scripts.filter")
local ledger = require("scripts.ledger")
local arms = require("scripts.arms")
local gui = require("scripts.gui")
local M = {}
-- Visit gap per tier = ticks between two belt items on one lane (0.25 tile / belt speed) when that is a whole number
-- of ticks >= 2 (yellow 8, red 4, turbo 2); any other speed -> every tick (blue 2.67: gap 2 lost rate, 200 of 225).
local intervals, naps = {}, {}
function M._reset_intervals() intervals, naps = {}, {} end  -- tests only: mocks swap prototypes
-- Idle box sleeps about one belt tile of travel (blue 9, turbo 7 ticks), 2..15: first item after a pause is not held long.
function M._nap(tier)
  local n = naps[tier]
  if n == nil then
    local proto = prototypes.entity[N.TIER[tier].belt]
    if not proto then return 15 end
    n = math.floor(1 / proto.belt_speed) - 1
    if n > 15 then n = 15 elseif n < 2 then n = 2 end
    naps[tier] = n
  end
  return n
end
function M._interval(tier)
  local n = intervals[tier]
  if n == nil then
    local proto = prototypes.entity[N.TIER[tier].belt]
    if not proto then return 2 end  -- offline mocks without belt prototypes
    local gap = 0.25 / proto.belt_speed
    n = (gap >= 2 and gap == math.floor(gap)) and gap or 1
    intervals[tier] = n
  end
  return n
end
local stack_sizes = {}
local quality_levels

local function levels()
  if quality_levels == nil then
    quality_levels = {}
    for name, prototype in pairs(prototypes.quality) do quality_levels[name] = prototype.level end
  end
  return quality_levels
end

local function stack_size(name)
  local size = stack_sizes[name]
  if size == nil then size = prototypes.item[name].stack_size; stack_sizes[name] = size end
  return size
end

function M.timeout_ticks(rec)
  if rec.settings.timeout_mode == "custom" then return rec.settings.timeout_s * 60 end
  return settings.global[N.SETTING_TIMEOUT].value * 60
end

function M.on_research(e)
  local force = e.research and e.research.force or e.force
  storage.belt_stack[force.index] = belt_io.belt_stack_size(force)
end

-- v15 perf (bench 2026-10-01: first loop cost 0.077 ms per turbo box, rig 0.012): engine calls per lane visit are
-- can_push (1), get_contents (1), per belt stack out insert + remove. No contents read while lane cannot push, except
-- once per SLOW ticks (hoarding rule, LED, timers). Used slots estimated from contents; engine asked only when the
-- estimate says full.
local SLOW = 30
local LOOK = N.LOOK
local stack_flag  -- nil = not read yet
local function can_stack()
  if stack_flag == nil then stack_flag = not script or not script.feature_flags or script.feature_flags.space_travel == true end
  return stack_flag
end
function M._reset_flags() stack_flag = nil end  -- tests only
local EMPTY = {}
local opts = {}  -- reused per call: ledger.plan reads it, never keeps it
local held_piece = {} -- reused for output hands
local tick_timeout  -- global flush timeout in ticks, read at most once per on_tick

local function timeout_for(rec)
  if rec.settings.timeout_mode == "custom" then return rec.settings.timeout_s * 60 end
  if tick_timeout == nil then tick_timeout = settings.global[N.SETTING_TIMEOUT].value * 60 end
  return tick_timeout
end

-- v17: spare stores (made when an old save is swapped to belt body and lane store could not hold everything) give
-- their items to the lane store as room comes. rec.spare is nil for every other packer.
local function refill(rec, lane)
  local list, inv = rec.spare[lane], rec.invs[lane]
  for i = #list, 1, -1 do
    local spare = list[i]
    if spare.valid then
      local sinv = spare.get_inventory(defines.inventory.chest)
      local contents = sinv.get_contents()
      for k = 1, #contents do
        local c = contents[k]
        local n = inv.insert({ name = c.name, quality = c.quality, count = c.count })
        if n > 0 then sinv.remove({ name = c.name, quality = c.quality, count = n }) end
      end
      if sinv.is_empty() then spare.destroy(); table.remove(list, i) end
    else
      table.remove(list, i)
    end
  end
  if #rec.spare[1] == 0 and #rec.spare[2] == 0 then rec.spare = nil end
end

local skip_filters
local function skip_fn(name, quality) return filter.match(skip_filters, name, quality, levels()) end

-- Returns true when lane store is known empty.
local function visit_lane(rec, lane, tick, bss, rate, elapsed, flush_all, counters)
  local stopped = rec.enabled == false or rec.decon == true
  arms.pause(rec, lane, stopped)
  local cap = 2 * rate
  if cap < 2 then cap = 2 end
  local credit = (rec.out_credit[lane] or 0) + rate * elapsed
  if credit > cap then credit = cap end
  local can = not stopped and credit >= 1 and belt_io.can_push(rec, lane)
  rec.slow = rec.slow or { 0, 0 }
  if not can and not flush_all and tick < rec.slow[lane] then
    rec.out_credit[lane] = credit
    return false  -- nothing can leave now; contents looked at again at slow tick
  end
  rec.slow[lane] = tick + SLOW
  if rec.spare then refill(rec, lane) end
  local inv = rec.invs[lane]
  local contents = inv.get_contents()
  local n = #contents
  rec.used = rec.used or { 0, 0 }
  opts.tick, opts.bss, opts.stack_size, opts.timeout_ticks = tick, bss, stack_size, timeout_for(rec)
  opts.slots, opts.flush_all = N.STORE_SLOTS, flush_all
  if n == 0 then
    opts.slots_used, opts.skip, opts.need_slot = 0, nil, nil
    ledger.plan(rec.ledger, lane, contents, opts)  -- clears first-seen clocks
    arms.skip(rec, lane, EMPTY)
    rec.used[lane] = 0
    rec.out_credit[lane] = credit
    return true
  end
  local used, hoarding = 0, false
  for i = 1, n do
    local c = contents[i]
    local count, size = c.count, stack_size(c.name)
    used = used + math.ceil(count / size)
    if count >= size then hoarding = true end  -- C-6 candidate
  end
  local need_slot
  if used >= N.STORE_SLOTS then
    if inv.count_empty_stacks() == 0 then  -- rare state: full store. New kind in an arm hand or waiting on belt behind?
      used = N.STORE_SLOTS
      need_slot = arms.need_slot(rec, lane, contents)
      if not need_slot then
        for _, w in ipairs(belt_io.behind_kinds(rec, lane) or EMPTY) do
          local found = false
          for i = 1, n do if contents[i].name == w.name and contents[i].quality == w.quality then found = true; break end end
          if not found then need_slot = true; break end
        end
      end
    else
      used = N.STORE_SLOTS - 1
    end
  end
  local filters = rec.settings.filters
  local skip
  if filters and filters[1] ~= nil then skip_filters = filters; skip = skip_fn end
  opts.slots_used, opts.skip, opts.need_slot = used, skip, need_slot
  local plan = ledger.plan(rec.ledger, lane, contents, opts)
  if hoarding or rec.skip[lane] ~= "" then arms.skip(rec, lane, ledger.hoard(rec.ledger, lane, contents, stack_size)) end
  if can then
    local most = math.ceil(rate * elapsed)  -- belt items lane can take since last visit: no push attempt beyond
    for i = 1, #plan do
      if credit < 1 or i > most then break end
      local piece = plan[i]
      local pushed = belt_io.push(rec, lane, piece, bss)
      if pushed <= 0 then break end
      inv.remove(piece)
      if counters then counters.items_in = counters.items_in + pushed end
      credit = credit - 1
    end
  end
  rec.used[lane] = used
  rec.out_credit[lane] = credit
  return false
end

local function engine_look(rec, tick, bss, flush_all)
  -- front belt check costs engine calls: asked once per 120 ticks (V16-6: up to 2 s late after front belt is rotated)
  -- v17: front is "ahead" (belt-like entity running our way), "across" (belt running across: out arms aim at its
  -- near lane, V17-5) or nil
  local front = rec.front_was
  if not front or tick - (rec.front_at or -120) >= 120 then  -- missing front: asked at every look
    front = belt_io.front_kind(rec); rec.front_was, rec.front_at = front, tick
  end
  if front then arms.aim_out(rec, front) end  -- no engine call when aim unchanged (parts re-made by rotation aim ahead)
  local stopped = rec.enabled == false or rec.decon == true or not front
  local hot = false
  arms.hand(rec, bss)
  rec.used = rec.used or { 0, 0 }
  for lane=1,2 do
    arms.skip(rec, lane, EMPTY)
    do
      arms.pause(rec, lane, rec.enabled == false or rec.decon == true)
      arms.pause_out(rec, lane, stopped)
      if rec.spare then refill(rec, lane) end
      local inv = rec.invs[lane]
      local contents = inv.get_contents()
      local n = #contents
      local used = 0
      for i=1,n do used = used + math.ceil(contents[i].count / stack_size(contents[i].name)) end
      if stopped then
        rec.used[lane] = used  -- stopped box still shows what it holds (LED)
      else
        if used >= N.STORE_SLOTS then
          if inv.count_empty_stacks() == 0 then
            used = N.STORE_SLOTS
            local c = storage.sp_counters
            if c then c.full = (c.full or 0) + 1 end  -- bench: lane store seen full at a look (output not keeping up)
            opts.need_slot = arms.need_slot(rec, lane, contents)
            if not opts.need_slot then
              for _, w in ipairs(belt_io.behind_kinds(rec, lane) or EMPTY) do
                local found = false
                for i=1,n do if contents[i].name == w.name and contents[i].quality == w.quality then found=true; break end end
                if not found then opts.need_slot=true; break end
              end
            end
          else
            used = N.STORE_SLOTS - 1
            opts.need_slot = nil
          end
        else
          opts.need_slot = nil
        end
        opts.tick, opts.bss, opts.stack_size, opts.timeout_ticks = tick, bss, stack_size, timeout_for(rec)
        opts.slots, opts.slots_used, opts.flush_all, opts.n_out = N.STORE_SLOTS, used, flush_all, #rec.out[lane]
        opts.skip = nil
        -- front room matters only for the "store unchanged" jam sign: asked when store was same at last look
        local same = rec.ledger.same
        if same and same[lane] >= 1 then opts.can_push = belt_io.can_push(rec, lane) else opts.can_push = nil end
        local flush, want = ledger.scan(rec.ledger, lane, contents, opts)
        local spot = 0
        for i=1,#flush do
          local piece=flush[i]
          local pushed=belt_io.push(rec,lane,piece,bss)
          -- v20: several leftovers in one look (steered lane): further belt spots of the front tile
          while pushed<=0 and spot<3 do spot=spot+1; pushed=belt_io.push(rec,lane,piece,bss,spot) end
          if pushed<=0 then break end
          inv.remove(piece)
        end
        -- v20 (V20-1): steered lane. Out arms take only kinds with a full stack; a partial hand of a kind that is
        -- not allowed any more (count fell below one stack between looks) goes back to the store.
        local allowed = ledger.steer(rec.ledger, lane)
        if allowed ~= nil and used >= N.STORE_SLOTS - N.HOT_FREE then hot = true end
        local changed = arms.steer(rec, lane, allowed)
        if allowed and not flush_all then want = false end
        if allowed and changed and not flush_all then  -- hands are read only when the allowed list changed
          local held = arms.held(rec, lane)
          rec.hands = rec.hands or { 0, 0 }
          rec.hands[lane] = 0
          for i = 1, #held do
            local h = held[i]
            local size = stack_size(h.name); if bss < size then size = bss end
            if h.count < size then
              local ok = false
              for k = 1, #allowed do if allowed[k].name == h.name and allowed[k].quality == h.quality then ok = true; break end end
              if not ok then
                held_piece.name, held_piece.quality, held_piece.count = h.name, h.quality, h.count
                if inv.insert(held_piece) == h.count then arms.clear_held(rec, lane, h.arm) end
              end
            end
          end
        end
        if want then
          local held=arms.held(rec,lane)
          rec.hands = rec.hands or { 0, 0 }
          rec.hands[lane] = #held  -- LED: items waiting in out-arm hands count as held (known only at hand looks)
          local indices, merges=ledger.hands(rec.ledger,lane,held,opts)
          -- V16-8: partial hands of one kind that together make a belt stack leave as one full stack
          for i=1,#merges do
            local m=merges[i]
            local size=stack_size(m.name); if bss<size then size=bss end
            held_piece.name, held_piece.quality, held_piece.count = m.name, m.quality, size
            if belt_io.push(rec,lane,held_piece,bss)<=0 then break end
            for j=1,#m.arms do arms.clear_held(rec,lane,m.arms[j]) end
            local rest=m.total-size
            if rest>0 then
              held_piece.count=rest
              local put=inv.insert(held_piece)
              if put<rest then  -- store full: rest on ground at packer, never lost (no chest body since v17)
                held_piece.count=rest-put
                rec.entity.surface.spill_item_stack({ position = rec.entity.position, stack = held_piece })
              end
            end
          end
          for i=1,#indices do
            local k=indices[i]
            local hand
            for j=1,#held do if held[j].arm==k then hand=held[j]; break end end
            if hand then
              held_piece.name, held_piece.quality, held_piece.count = hand.name, hand.quality, hand.count
              if belt_io.push(rec,lane,held_piece,bss)<=0 then break end
              arms.clear_held(rec,lane,k)
            end
          end
        end
        rec.used[lane] = used
      end
    end
  end
  rec.hot = (not stopped and hot) and true or nil
end

local function update_led(rec)
  local used = rec.used
  local hands = rec.hands
  local u1, u2 = used and used[1] or 0, used and used[2] or 0
  if hands then  -- v16: leftovers wait in out-arm hands, not in store
    if u1 == 0 and hands[1] > 0 then u1 = 1 end
    if u2 == 0 and hands[2] > 0 then u2 = 1 end
  end
  local state = ledger.led(u1, u2, N.STORE_SLOTS)
  local visible = rec.enabled ~= false and not rec.decon
  if not rec.led or rec.led.state ~= state or rec.led.visible ~= visible then led.set(rec, state, visible) end
end

-- v16 schedule (INT, bench 2026-10-01: walking over every box every tick cost 0.38 ms per 200 boxes).
-- storage.sched = { n = box count, buckets = { [1..60] = { unit, ... } }, fast = { [unit] = true } }.
-- Engine-mode box sits in 2 buckets (its look ticks: (tick + unit) % 30 == 0). Box in script mode or with extra
-- items is in `fast` and is checked every tick with the v15 due rule. Rebuilt when box table changes
-- (registry / copy set storage.sched = nil; count checked as second guard).
local size = table_size or function(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

local function is_script_mode(rec)
  local filters = rec.settings.filters
  if filters and filters[1] ~= nil then return true end
  if can_stack() then return false end
  -- engine out arms can not stack without space travel feature flag: box that must stack stays on script path
  local fi = rec.force_index
  local force_bss = fi and storage.belt_stack[fi]
  return force_bss == nil or force_bss > 1  -- unknown yet: script path, it finds out
end

local function build_sched()
  local units, n = {}, 0
  for unit in pairs(storage.boxes) do n = n + 1; units[n] = unit end
  table.sort(units)
  local buckets, fast, hot = {}, {}, {}
  for k = 1, 2 * LOOK do buckets[k] = {} end
  for i = 1, n do
    local unit = units[i]
    local rec = storage.boxes[unit]
    if rec.stores then
      local b = (-unit) % LOOK
      local list = buckets[b + 1]; list[#list + 1] = unit
      list = buckets[b + LOOK + 1]; list[#list + 1] = unit
      if is_script_mode(rec) then fast[unit] = true end
      if rec.hot then hot[unit] = true end
    end
  end
  return { n = n, buckets = buckets, fast = fast, hot = hot }
end

local function visit(rec, tick, script_mode, interval, counters)
  if not rec.entity.valid then
    storage.boxes[rec.unit_number] = nil
    storage.sched = nil
    return
  end
  if counters then counters.visits = counters.visits + 1 end
  local enabled, flush_now = circuit.evaluate(rec)
  rec.enabled = enabled
  local fi = rec.force_index
  if fi == nil then fi = rec.entity.force.index; rec.force_index = fi end
  local bss = storage.belt_stack[fi]
  if bss == nil then bss = belt_io.belt_stack_size(rec.entity.force); storage.belt_stack[fi] = bss end
  if script_mode then
    arms.pause_out(rec, 1, true); arms.pause_out(rec, 2, true)
    local elapsed = tick - (rec.last_poll or (tick - interval))
    local rate = belt_io.lane_rate(rec.tier)
    local empty1 = visit_lane(rec, 1, tick, bss, rate, elapsed, flush_now, counters)
    local empty2 = visit_lane(rec, 2, tick, bss, rate, elapsed, flush_now, counters)
    rec.last_poll = tick
    -- Idle sleep only after stores stayed empty 30 ticks: a busy pass-through box (belt stack 1) empties its
    -- stores on most visits; sleeping 15 ticks there cost 10-25 % of belt rate (rate test, 2026-10-01).
    local idle = false
    if empty1 and empty2 then
      rec.empty_since = rec.empty_since or tick
      idle = tick - rec.empty_since >= 30
    else
      rec.empty_since = nil
    end
    rec.next_poll = tick + (idle and M._nap(rec.tier) or interval)
  else
    engine_look(rec, tick, bss, flush_now)
    local sched = storage.sched
    if sched and sched.hot then
      if rec.hot then sched.hot[rec.unit_number] = true else sched.hot[rec.unit_number] = nil end
    end
    rec.last_poll = tick
    rec.next_poll = tick + (interval or 0)
    rec.empty_since = nil
  end
  update_led(rec)
end

-- Box of `fast` set: every tick, v15 due rule. Leaves the set when it is a plain engine-mode box again.
local function fast_step(sched, rec, unit, tick, counters)
  local script_mode = is_script_mode(rec)
  if not script_mode then
    sched.fast[unit] = nil  -- bucket loop (runs after this, same tick) looks at it when its tick comes
    return
  end
  local interval = M._interval(rec.tier)
  if not rec.decon and tick >= (rec.next_poll or 0) and (rec.last_poll ~= nil or (tick + unit) % interval == 0) then
    visit(rec, tick, script_mode, interval, counters)
  end
end

function M.on_tick(e)
  local counters = storage and storage.sp_counters
  local tick = e.tick
  belt_io.set_tick(tick)
  tick_timeout = nil
  if tick % 30 == 0 then  -- open box windows show live lane stores
    for _, player in pairs(game.connected_players) do
      if player.opened_gui_type == defines.gui_type.custom then gui._refresh_open(player) end  -- v17: own window
    end
  end
  local boxes = storage.boxes
  local sched = storage.sched
  if not sched or sched.n ~= size(boxes) then sched = build_sched(); storage.sched = sched end
  local fast = sched.fast
  for unit in pairs(fast) do
    local rec = boxes[unit]
    if rec and rec.stores then fast_step(sched, rec, unit, tick, counters) else fast[unit] = nil end
  end
  local hot = sched.hot
  for unit in pairs(hot) do
    if storage.sched ~= sched then break end
    local rec = boxes[unit]
    if not rec or not rec.stores or rec.hot ~= true or fast[unit] then hot[unit] = nil
    elseif (tick + unit) % N.HOT_LOOK == 0 and (tick + unit) % LOOK ~= 0 then visit(rec, tick, false, nil, counters) end
  end
  if storage.sched ~= sched then return end
  local list = sched.buckets[tick % (2 * LOOK) + 1]
  for i = 1, #list do
    local unit = list[i]
    local rec = boxes[unit]
    if rec and rec.stores and not fast[unit] then
      if is_script_mode(rec) then
        fast[unit] = true  -- found at its look: from now on checked every tick
        local interval = M._interval(rec.tier)
        if not rec.decon and tick >= (rec.next_poll or 0) then visit(rec, tick, is_script_mode(rec), interval, counters) end
      else
        visit(rec, tick, false, nil, counters)
      end
    end
  end
end
local function zero_counters()
  return { visits=0, reads=0, pulls=0, pushes=0, items_in=0, items_out=0, full=0 }
end
function M.counters_on() storage.sp_counters = zero_counters() end
function M.counters()
  local c = storage and storage.sp_counters
  if not c then return nil end
  return { visits=c.visits, reads=c.reads, pulls=c.pulls, pushes=c.pushes, items_in=c.items_in, items_out=c.items_out, full=c.full or 0 }
end
function M.on_decon(e, marked)
  local entity = e and e.entity
  local rec = entity and entity.unit_number and storage.boxes[entity.unit_number]
  if rec then
    rec.decon=marked; rec.next_poll=0
    if rec.stores then
      for lane=1,2 do
        arms.pause(rec,lane,marked==true or rec.enabled==false)
        arms.pause_out(rec,lane,marked==true or rec.enabled==false or not belt_io.front_ok(rec))
      end
    end
    update_led(rec)
  end
end

return M
