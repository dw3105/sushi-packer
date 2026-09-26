local N = require("scripts.names")
local core = require("scripts.core")
local belt_io = require("scripts.belt_io")
local circuit = require("scripts.circuit")
local led = require("scripts.led")
local M = {}
local INTERVAL = { yellow = 8, red = 4, blue = 2, turbo = 2 }

function M.timeout_ticks(rec)
  if rec.settings.timeout_mode == "custom" then return rec.settings.timeout_s * 60 end
  return settings.global[N.SETTING_TIMEOUT].value * 60
end

function M.on_research(e)
  local force = e.research and e.research.force or e.force
  storage.belt_stack[force.index] = belt_io.belt_stack_size(force)
end

local function has_filter(filters, name, quality)
  for _, f in ipairs(filters or {}) do
    if f.name == name and (f.quality == nil or f.quality == quality) then return true end
  end
  return false
end

local function reconcile(rec, tick, inv)
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
      core.adopt_external(rec.box, name, quality, inv_count - core_count, prototypes.item[name].stack_size, tick)
    end
  end
end

function M.on_tick(e)
  local opened = {}
  for _, player in pairs(game.connected_players) do
    local entity = player.opened
    if entity and entity.unit_number then opened[entity.unit_number] = true end
  end
  for _, rec in pairs(storage.boxes) do
    if not rec.entity.valid then
      storage.boxes[rec.unit_number] = nil
    else
      local inv
      if opened[rec.unit_number] or (e.tick + rec.unit_number) % 60 == 0 then
        inv = rec.entity.get_inventory(defines.inventory.chest)
        reconcile(rec, e.tick, inv)
      end
      led.set(rec, core.led_state(rec.box), rec.enabled ~= false)
      local interval = INTERVAL[rec.tier] or 1
      if (e.tick + rec.unit_number) % interval == 0 and e.tick >= (rec.next_poll or 0) then
        local enabled, flush_now = circuit.evaluate(rec)
        rec.enabled = enabled
        if not enabled then
          led.set(rec, core.led_state(rec.box), false)
        else
          if flush_now then core.flush_partials(rec.box, e.tick) end
          core.on_tick(rec.box, e.tick, M.timeout_ticks(rec))
          inv = inv or rec.entity.get_inventory(defines.inventory.chest)
          local rate = N.TIER[rec.tier].lane_rate
          local taken_any = false
          local budget = {0, 0}
          for lane = 1, 2 do
            rec.in_credit[lane] = math.min(rec.in_credit[lane] + rate * interval, 2)
            budget[lane] = math.floor(rec.in_credit[lane])
          end
          local function sink(name, quality, input_lane, count)
            if has_filter(rec.settings.filters, name, quality) then
              return core.accept(rec.box, name, quality, input_lane, count, 1, e.tick, true)
            end
            local stack = prototypes.item[name].stack_size
            local accepted = core.accept(rec.box, name, quality, input_lane, count, stack, e.tick, false)
            if accepted <= 0 then return 0 end
            local inserted = inv.insert({name=name, count=accepted, quality=quality})
            if inserted < accepted then core.remove_external(rec.box, name, quality, accepted - inserted) end
            return inserted
          end
          local got = belt_io.pull(rec, budget, sink) or {0, 0}
          for lane = 1, 2 do
            local n = got[lane] or 0
            rec.in_credit[lane] = rec.in_credit[lane] - n
            if n > 0 then taken_any = true end
          end
          local force = rec.entity.force
          local bss = storage.belt_stack[force.index]
          if bss == nil then bss = belt_io.belt_stack_size(force); storage.belt_stack[force.index] = bss end
          for lane = 1, 2 do
            rec.out_credit[lane] = math.min(rec.out_credit[lane] + rate * interval, 2)
            while rec.out_credit[lane] >= 1 do
              local item = core.peek_out(rec.box, lane)
              if not item then break end
              local piece = {name=item.name, quality=item.quality, count=math.min(item.count, bss)}
              local pushed = belt_io.push(rec, lane, piece, bss)
              if pushed == 0 then break end
              if not item.passthrough then inv.remove({name=item.name, count=pushed, quality=item.quality}) end
              core.take_out(rec.box, lane, pushed)
              rec.out_credit[lane] = rec.out_credit[lane] - 1
              taken_any = true
            end
          end
          if core.is_idle(rec.box) and not taken_any then rec.next_poll = e.tick + 30 else rec.next_poll = 0 end
        end
      end
    end
  end
end

return M
