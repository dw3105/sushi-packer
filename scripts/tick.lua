local N = require("scripts.names")
local core = require("scripts.core")
local belt_io = require("scripts.belt_io")
local circuit = require("scripts.circuit")
local led = require("scripts.led")
local filter = require("scripts.filter")
local M = {}
local INTERVAL = { yellow = 8, red = 4, blue = 2, turbo = 2 }
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
  if size == nil then
    size = prototypes.item[name].stack_size
    stack_sizes[name] = size
  end
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

local function reconcile(rec, tick, inv, bss)
  inv = inv or rec.entity.get_inventory(defines.inventory.chest)
  local chest, totals = {}, core.totals(rec.box)
  for _, x in ipairs(inv.get_contents()) do
    local k = x.name .. "\0" .. tostring(x.quality)
    chest[k] = (chest[k] or 0) + x.count
  end
  local keys, items = {}, {}
  for _, x in ipairs(totals) do
    local k = x.name .. "\0" .. tostring(x.quality)
    keys[k] = true; items[k] = x
  end
  for k in pairs(chest) do keys[k] = true end
  for k in pairs(keys) do
    local x = items[k]
    local name, quality
    if x then name, quality = x.name, x.quality else
      local split = string.find(k, "\0", 1, true)
      name = string.sub(k, 1, split - 1)
      quality = string.sub(k, split + 1)
      if quality == "nil" then quality = nil end
    end
    local core_count = x and x.count or 0
    local inv_count = chest[k] or 0
    if inv_count < core_count then core.remove_external(rec.box, name, quality, core_count - inv_count)
    elseif inv_count > core_count then
      core.adopt_external(rec.box, name, quality, inv_count - core_count, math.min(bss, stack_size(name)), tick)
    end
  end
end

local visit = {}
local function inventory()
  if visit.inv == nil then visit.inv = visit.rec.entity.get_inventory(defines.inventory.chest) end
  return visit.inv
end
local function sink(name, quality, input_lane, count)
  local ctx, rec = visit, visit.rec
  local release_size = math.min(ctx.bss, stack_size(name))
  local filters = rec.settings.filters
  if filters and filters[1] ~= nil and filter.match(filters, name, quality, levels()) then
    return core.accept(rec.box, name, quality, input_lane, count, release_size, ctx.tick, true)
  end
  local accepted = core.accept(rec.box, name, quality, input_lane, count, release_size, ctx.tick, false, stack_size(name))
  if accepted <= 0 then return 0 end
  local inserted = inventory().insert({name=name, count=accepted, quality=quality})
  if inserted < accepted then core.remove_external(rec.box, name, quality, accepted - inserted) end
  return inserted
end
local function update_led(rec)
  local state, visible = core.led_state(rec.box), rec.enabled ~= false and not rec.decon
  if not rec.led or rec.led.state ~= state or rec.led.visible ~= visible then led.set(rec, state, visible) end
end

function M.on_tick(e)
  local counters = storage and storage.sp_counters
  local opened = {}
  for _, player in pairs(game.connected_players) do
    if player.opened_gui_type == defines.gui_type.entity then  -- opened may be item stack (blueprint), gui, equipment
      local entity = player.opened
      if entity and entity.valid and entity.unit_number then opened[entity.unit_number] = true end
    end
  end
  for _, rec in pairs(storage.boxes) do
    local do_reconcile = not rec.decon and (opened[rec.unit_number] or (e.tick + rec.unit_number) % 60 == 0)
    local interval = INTERVAL[rec.tier] or 1
    local first_visit = (rec.next_poll == nil or rec.next_poll == 0) and rec.last_poll == nil
    local due = not rec.decon and e.tick >= (rec.next_poll or 0)
      and (not first_visit or (e.tick + rec.unit_number) % interval == 0)
    local first_probe = first_visit and not rec.first_probe_done and not (do_reconcile or due)
    if first_probe then rec.first_probe_done = true end
    if do_reconcile or due then
      if not rec.entity.valid then
        storage.boxes[rec.unit_number] = nil
      else
        local force = rec.entity.force
        local bss = storage.belt_stack[force.index]
        if bss == nil then bss = belt_io.belt_stack_size(force); storage.belt_stack[force.index] = bss end
        local inv
        if do_reconcile then
          inv = rec.entity.get_inventory(defines.inventory.chest)
          reconcile(rec, e.tick, inv, bss)
        end
        if due then
          if counters then counters.visits = counters.visits + 1 end
          local enabled, flush_now = circuit.evaluate(rec)
          rec.enabled = enabled
          if enabled then
            if flush_now then core.flush_partials(rec.box, e.tick) end
            core.on_tick(rec.box, e.tick, M.timeout_ticks(rec))
            visit.rec, visit.inv, visit.bss, visit.tick = rec, inv, bss, e.tick
            local rate = belt_io.lane_rate(rec.tier)
            local credit_cap = math.max(2, 2 * rate)
            local elapsed = e.tick - (rec.last_poll or (e.tick - interval))
            local taken_any = false
            local budget = {0, 0}
            for lane = 1, 2 do
              rec.in_credit[lane] = math.min(rec.in_credit[lane] + rate * elapsed, credit_cap)
              budget[lane] = math.floor(rec.in_credit[lane])
            end
            local got, eta = belt_io.pull(rec, budget, sink)
            got = got or {0, 0}
            for lane = 1, 2 do
              local n = got[lane] or 0
              rec.in_credit[lane] = rec.in_credit[lane] - n
              if n > 0 then taken_any = true end
            end
            for lane = 1, 2 do
              rec.out_credit[lane] = math.min(rec.out_credit[lane] + rate * elapsed, credit_cap)
              while rec.out_credit[lane] >= 1 do
                local item = core.peek_out(rec.box, lane)
                if not item then break end
                local piece = {name=item.name, quality=item.quality, count=math.min(item.count, bss)}
                local pushed = belt_io.push(rec, lane, piece, bss)
                if pushed == 0 then break end
                if not item.passthrough then inventory().remove({name=item.name, count=pushed, quality=item.quality}) end
                core.take_out(rec.box, lane, pushed)
                rec.out_credit[lane] = rec.out_credit[lane] - 1
                taken_any = true
              end
            end
            local arrive  -- soonest front item arrival (eta 0 = resting item, never wakes early)
            if eta then
              for lane = 1, 2 do
                local value = eta[lane]
                if value and value > 0 and (arrive == nil or value < arrive) then arrive = value end
              end
            end
            local gap = interval
            if core.is_idle(rec.box) and not taken_any then
              local speed = belt_io.speed and belt_io.speed(rec)
              gap = math.min(30, speed and math.floor(1 / speed) - 1 or 30)
            end
            if arrive and arrive < gap then gap = arrive end
            rec.next_poll = e.tick + math.max(1, gap)
          end
          rec.last_poll = e.tick
          if not enabled then rec.next_poll = e.tick + interval end
        end
        if due or do_reconcile or rec.led_dirty then update_led(rec); rec.led_dirty = nil end
      end
    elseif first_probe then
      if not rec.entity.valid then storage.boxes[rec.unit_number] = nil
      elseif rec.led_dirty or not rec.led then update_led(rec); rec.led_dirty = nil end
    elseif rec.led_dirty then
      update_led(rec); rec.led_dirty = nil
    elseif e.tick >= (rec.next_poll or 0) and not rec.led then
      update_led(rec)
    end
  end
end

-- v14 bench seam (docs/CONTRACT.md): work counters in storage.sp_counters, nil = off.
local function zero_counters()
  return { visits = 0, reads = 0, pulls = 0, pushes = 0, items_in = 0, items_out = 0 }
end
function M.counters_on() storage.sp_counters = zero_counters() end
function M.counters()
  local counters = storage and storage.sp_counters
  if not counters then return nil end
  return { visits = counters.visits, reads = counters.reads, pulls = counters.pulls,
    pushes = counters.pushes, items_in = counters.items_in, items_out = counters.items_out }
end

-- E-8 v6: marked for deconstruction -> rec.decon, box stops, LED off.
function M.on_decon(e, marked)
  local entity = e and e.entity
  local rec = entity and entity.unit_number and storage.boxes[entity.unit_number]
  if rec then rec.decon = marked; rec.next_poll = 0; rec.led_dirty = true end
end

return M
