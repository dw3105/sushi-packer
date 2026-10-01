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
local intervals = {}
function M._reset_intervals() intervals = {} end  -- tests only: mocks swap prototypes
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

local function update_led(rec)
  local used1 = #rec.invs[1] - rec.invs[1].count_empty_stacks()
  local used2 = #rec.invs[2] - rec.invs[2].count_empty_stacks()
  local state = ledger.led(used1, used2, N.STORE_SLOTS)
  local visible = rec.enabled ~= false and not rec.decon
  if not rec.led or rec.led.state ~= state or rec.led.visible ~= visible then led.set(rec, state, visible) end
end

local function remove_extra(rec, box_inv, entry, amount)
  box_inv.remove({ name = entry.name, quality = entry.quality, count = amount })
  entry.count = entry.count - amount
  if entry.count <= 0 then
    for i, x in ipairs(rec.extra) do if x == entry then table.remove(rec.extra, i); break end end
  end
  if #rec.extra == 0 then rec.extra = nil end
end

local function drain_extra(rec, lane, bss, credit, counters)
  if not rec.extra then return credit, false end
  local has_lane = false
  for _, entry in ipairs(rec.extra) do if entry.lane == lane and entry.count > 0 then has_lane = true; break end end
  if not has_lane then return credit, false end
  local box_inv = rec.entity.get_inventory(defines.inventory.chest)
  while rec.extra do
    local entry
    for _, candidate in ipairs(rec.extra) do
      if candidate.lane == lane and candidate.count > 0 then entry=candidate; break end
    end
    if not entry then return credit, false end
    local size = math.min(bss, stack_size(entry.name))
    while entry.count > 0 and credit >= 1 do
      local piece = { name=entry.name, quality=entry.quality, count=math.min(entry.count,size) }
      local pushed = belt_io.push(rec,lane,piece,bss)
      if pushed <= 0 then return credit,true end
      remove_extra(rec,box_inv,entry,pushed)
      if counters then counters.items_in=counters.items_in+pushed end
      credit = credit - 1
    end
    if entry.count > 0 then return credit,true end
  end
  return credit,false
end

local function visit_lane(rec, lane, tick, bss, rate, elapsed, flush_all, counters)
  local inv = rec.invs[lane]
  local was_empty = inv.is_empty()
  local contents = inv.get_contents()
  local slots_used = #inv - inv.count_empty_stacks()
  local filters = rec.settings.filters
  local skip
  if filters and filters[1] ~= nil then
    skip = function(name, quality) return filter.match(filters, name, quality, levels()) end
  end
  local need_slot
  if slots_used >= N.STORE_SLOTS then  -- rare state: full store. New kind in an arm hand or waiting on belt behind?
    need_slot = arms.need_slot(rec, lane, contents)
    if not need_slot then
      for _, w in ipairs(belt_io.behind_kinds(rec, lane) or {}) do
        local found = false
        for i = 1, #contents do if contents[i].name == w.name and contents[i].quality == w.quality then found = true; break end end
        if not found then need_slot = true; break end
      end
    end
  end
  local opts = { tick=tick, bss=bss, stack_size=stack_size, timeout_ticks=M.timeout_ticks(rec),
    slots_used=slots_used, slots=N.STORE_SLOTS, skip=skip, flush_all=flush_all, need_slot=need_slot }
  local plan = ledger.plan(rec.ledger, lane, contents, opts)
  local kinds = ledger.hoard(contents, stack_size, #(rec.arms[lane] or {}) * N.ARM_HAND, bss)
  arms.skip(rec, lane, kinds)
  local extra_lane = false
  for _, entry in ipairs(rec.extra or {}) do if entry.lane == lane and entry.count > 0 then extra_lane = true; break end end
  arms.pause(rec, lane, rec.enabled == false or rec.decon == true or extra_lane)

  rec.out_credit[lane] = math.min((rec.out_credit[lane] or 0) + rate * elapsed, math.max(2, 2 * rate))
  local credit = rec.out_credit[lane]
  if rec.enabled ~= false and not rec.decon then credit, extra_lane = drain_extra(rec, lane, bss, credit, counters) end
  if rec.extra == nil or not extra_lane then arms.pause(rec, lane, rec.enabled == false or rec.decon == true or extra_lane) end
  if rec.enabled ~= false and not rec.decon and not extra_lane then
    for _, piece in ipairs(plan) do
      if credit >= 1 then
        local pushed = belt_io.push(rec, lane, piece, bss)
        if pushed <= 0 then break end
        inv.remove({ name=piece.name, quality=piece.quality, count=pushed })
        if counters then counters.items_in = counters.items_in + pushed end
        credit = credit - 1
      else
        break
      end
    end
  end
  rec.out_credit[lane] = credit
  return was_empty and inv.is_empty()
end

function M.on_tick(e)
  local counters = storage and storage.sp_counters
  if e.tick % 30 == 0 then  -- open box windows show live lane stores
    for _, player in pairs(game.connected_players) do
      if player.opened_gui_type == defines.gui_type.entity then
        local entity = player.opened
        local rec = entity and entity.valid and entity.unit_number and storage.boxes[entity.unit_number]
        if rec then gui._refresh(player, rec) end
      end
    end
  end
  for _, rec in pairs(storage.boxes) do
    local interval = M._interval(rec.tier)
    -- Once per 60 ticks per box: items someone put into box container (inserter, robot, player) and that are not
    -- old-save extra yet become extra on lane 1 (D-1 "surplus adopted as left-lane arrival"). Empty container: one call.
    if rec.stores and not rec.decon and (e.tick + rec.unit_number) % 60 == 0 and rec.entity.valid then
      local box_inv = rec.entity.get_inventory(defines.inventory.chest)
      if not box_inv.is_empty() then
        local known = {}
        for _, x in ipairs(rec.extra or {}) do local k = x.name .. "\0" .. x.quality; known[k] = (known[k] or 0) + x.count end
        for _, c in ipairs(box_inv.get_contents()) do
          local more = c.count - (known[c.name .. "\0" .. c.quality] or 0)
          if more > 0 then
            rec.extra = rec.extra or {}
            local hit
            for _, x in ipairs(rec.extra) do if x.lane == 1 and x.name == c.name and x.quality == c.quality then hit = x; break end end
            if hit then hit.count = hit.count + more else rec.extra[#rec.extra + 1] = { name = c.name, quality = c.quality, count = more, lane = 1 } end
            rec.next_poll = e.tick
          end
        end
      end
    end
    local staggered = rec.last_poll ~= nil or (e.tick + rec.unit_number) % interval == 0
    local due = not rec.decon and e.tick >= (rec.next_poll or 0) and staggered
    if due and rec.stores then
      if not rec.entity.valid then
        storage.boxes[rec.unit_number] = nil
      else
        if counters then counters.visits = counters.visits + 1 end
        local enabled, flush_now = circuit.evaluate(rec)
        rec.enabled = enabled
        local force = rec.entity.force
        local bss = storage.belt_stack[force.index]
        if bss == nil then bss = belt_io.belt_stack_size(force); storage.belt_stack[force.index] = bss end
        local elapsed = e.tick - (rec.last_poll or (e.tick - interval))
        local empty1, empty2 = true, true
        for lane = 1, 2 do
          local lane_empty = visit_lane(rec, lane, e.tick, bss, belt_io.lane_rate(rec.tier), elapsed, flush_now, counters)
          if lane == 1 then empty1 = lane_empty else empty2 = lane_empty end
        end
        rec.last_poll = e.tick
        local idle = empty1 and empty2 and rec.extra == nil
        rec.next_poll = e.tick + (idle and 15 or interval)
        update_led(rec)
        rec.led_dirty = nil
      end
    elseif rec.led_dirty then
      if rec.stores then update_led(rec) end
      rec.led_dirty = nil
    end
  end
end

local function zero_counters()
  return { visits=0, reads=0, pulls=0, pushes=0, items_in=0, items_out=0 }
end
function M.counters_on() storage.sp_counters = zero_counters() end
function M.counters()
  local c = storage and storage.sp_counters
  if not c then return nil end
  return { visits=c.visits, reads=c.reads, pulls=c.pulls, pushes=c.pushes, items_in=c.items_in, items_out=c.items_out }
end
function M.on_decon(e, marked)
  local entity = e and e.entity
  local rec = entity and entity.unit_number and storage.boxes[entity.unit_number]
  if rec then
    rec.decon=marked; rec.next_poll=0; rec.led_dirty=true
    if rec.stores then
      for lane=1,2 do
        local has_extra=false
        for _, entry in ipairs(rec.extra or {}) do if entry.lane==lane and entry.count>0 then has_extra=true; break end end
        arms.pause(rec,lane,marked==true or rec.enabled==false or has_extra)
      end
    end
  end
end

return M
