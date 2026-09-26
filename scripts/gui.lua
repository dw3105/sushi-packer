local N = require("scripts.names")
local M = {}

local FRAME = "sushi_packer_frame"
local COMPARATORS = { ">", "<", "=", "≥", "≤", "≠" }

local function tags(unit, field, row)
  return { sushi_packer = unit, field = field, row = row }
end

local function add(parent, spec, unit, field, row)
  spec.tags = tags(unit, field, row)
  return parent.add(spec)
end

local function frame_for(player)
  local f = player.gui.relative[FRAME]
  if f and f.valid then return f end
end

local function add_rows(frame, unit, settings)
  for i = 1, 10 do
    local filter = settings.filters[i]
    local row = frame.add({ type = "flow", direction = "horizontal" })
    row.add({ type = "label", caption = tostring(i) })
    local item = add(row, { type = "choose-elem-button", elem_type = "item-with-quality", name = "filter_item_" .. i }, unit, "filters", i)
    if filter then item.elem_value = { name = filter.name, quality = filter.quality or "normal" } end
    local any = add(row, { type = "checkbox", caption = { "gui.any-quality" }, state = filter ~= nil and filter.quality == nil, name = "filter_any_" .. i }, unit, "filters", i)
    any.tooltip = { "gui.any-quality-tooltip" }
  end
end

local function signal_elem(value)
  if value then return { type = value.type, name = value.name, quality = value.quality } end
end

local function build(player, rec)
  local old = frame_for(player)
  if old then old.destroy() end
  local variant_names = {}
  for _, tier in ipairs(N.TIERS) do
    for _, dir in ipairs(N.DIRS) do variant_names[#variant_names + 1] = N.variant(tier, dir) end
  end
  local frame = player.gui.relative.add({
    type = "frame", name = FRAME, direction = "vertical", caption = { "gui.title" },
    anchor = { gui = defines.relative_gui_type.container_gui, position = defines.relative_gui_position.right, names = variant_names },
  })
  local s, unit = rec.settings, rec.unit_number
  local timeout = frame.add({ type = "flow", direction = "horizontal" })
  timeout.add({ type = "label", caption = { "gui.timeout" } })
  add(timeout, { type = "switch", name = "timeout_mode", left_label_caption = { "gui.global" }, right_label_caption = { "gui.custom" }, switch_state = s.timeout_mode == "custom" and "right" or "left" }, unit, "timeout_mode")
  add(timeout, { type = "textfield", name = "timeout_s", text = tostring(s.timeout_s or 0), numeric = true, allow_decimal = false, allow_negative = false }, unit, "timeout_s")

  frame.add({ type = "label", caption = { "gui.filters" } })
  add_rows(frame, unit, s)

  local c = s.circuit
  frame.add({ type = "label", caption = { "gui.circuit" } })
  local circuit = frame.add({ type = "flow", direction = "horizontal" })
  add(circuit, { type = "checkbox", name = "circuit_enable", caption = { "gui.enable" }, state = c.enable }, unit, "circuit.enable")
  local circuit_signal = add(circuit, { type = "choose-elem-button", elem_type = "signal", name = "circuit_signal" }, unit, "circuit.cond.first_signal")
  if c.cond.first_signal then circuit_signal.elem_value = signal_elem(c.cond.first_signal) end
  local selected = 1
  for i, comparator in ipairs(COMPARATORS) do if comparator == c.cond.comparator then selected = i end end
  add(circuit, { type = "drop-down", name = "circuit_comparator", items = COMPARATORS, selected_index = selected }, unit, "circuit.cond.comparator")
  add(circuit, { type = "textfield", name = "circuit_constant", text = tostring(c.cond.constant or 0), numeric = true, allow_decimal = false, allow_negative = true }, unit, "circuit.cond.constant")
  local flush = frame.add({ type = "flow", direction = "horizontal" })
  add(flush, { type = "checkbox", name = "circuit_flush", caption = { "gui.flush" }, state = c.flush }, unit, "circuit.flush")
  local flush_signal = add(flush, { type = "choose-elem-button", elem_type = "signal", name = "flush_signal" }, unit, "circuit.flush_signal")
  if c.flush_signal then flush_signal.elem_value = signal_elem(c.flush_signal) end
end

function M.on_opened(e)
  if not e.entity or not e.entity.valid then return end
  local rec = storage.boxes and storage.boxes[e.entity.unit_number]
  if not rec then return end
  build(game.players[e.player_index], rec)
end

function M.on_closed(e)
  local player = game.players[e.player_index]
  if not player then return end
  local frame = frame_for(player)
  if frame then frame.destroy() end
end

local function rebuild_filters(frame, settings)
  local filters = {}
  for i = 1, 10 do
    local item, any
    for _, el in pairs(frame.children) do
      if el.type == "flow" then
        for _, child in pairs(el.children) do
          local t = child.tags
          if t and t.field == "filters" and t.row == i then
            if child.name == "filter_item_" .. i then item = child end
            if child.name == "filter_any_" .. i then any = child end
          end
        end
      end
    end
    local value = item and item.elem_value
    if value and value.name then
      local filter = { name = value.name }
      if not (any and any.state) then filter.quality = value.quality or "normal" end
      filters[#filters + 1] = filter
    end
  end
  settings.filters = filters
end

local function timeout_number(text, maximum)
  if type(text) ~= "string" or not text:match("^%d+$") then return nil end
  local n = tonumber(text)
  if not n or n > maximum then return nil end
  return n
end

function M.on_event(e)
  local el = e.element
  if not el or not el.valid or not el.tags or not el.tags.sushi_packer then return end
  local unit, field = el.tags.sushi_packer, el.tags.field
  local rec = storage.boxes and storage.boxes[unit]
  if not rec or not rec.settings then return end
  local s, c = rec.settings, rec.settings.circuit
  if field == "timeout_mode" then
    s.timeout_mode = el.switch_state == "right" and "custom" or "global"
  elseif field == "timeout_s" then
    local n = timeout_number(el.text, 3600); if n then s.timeout_s = n end
  elseif field == "filters" then
    local player = game.players[e.player_index]
    local frame = player and frame_for(player)
    if frame then rebuild_filters(frame, s) end
  elseif field == "circuit.enable" then
    c.enable = el.state
  elseif field == "circuit.cond.first_signal" then
    c.cond.first_signal = el.elem_value
  elseif field == "circuit.cond.comparator" then
    c.cond.comparator = COMPARATORS[el.selected_index] or c.cond.comparator
  elseif field == "circuit.cond.constant" then
    local n = timeout_number(el.text, 2147483647)
    if not n and el.text:match("^%-%d+$") then n = tonumber(el.text) end
    if n then c.cond.constant = n end
  elseif field == "circuit.flush" then
    c.flush = el.state
  elseif field == "circuit.flush_signal" then
    c.flush_signal = el.elem_value
  end
end

return M
