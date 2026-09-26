local N = require("scripts.names")
local M = {}

local FRAME = "sushi_packer_frame"
local FILTER_COMPARATORS = { "=", "≠", ">", "<", "≥", "≤" }
local CIRCUIT_COMPARATORS = { ">", "<", "=", "≥", "≤", "≠" }

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

local function signal_elem(value)
  if value then return { type = value.type, name = value.name, quality = value.quality } end
end

local function section(frame, caption, name)
  local box = frame.add({ type = "frame", name = name, direction = "vertical", style = "inside_shallow_frame_with_padding" })
  box.add({ type = "label", caption = caption, style = "bold_label" })
  return box
end

local function aligned(parent, name)
  return parent.add({ type = "flow", name = name, direction = "horizontal", style = "player_input_horizontal_flow" })
end

local function select_index(items, value, fallback)
  for i, item in ipairs(items) do if item == value then return i end end
  return fallback or 1
end

local function quality_items()
  local qualities = {}
  for name, quality in pairs(prototypes.quality) do
    if not quality.hidden then qualities[#qualities + 1] = { name = name, level = quality.level } end
  end
  table.sort(qualities, function(a, b)
    if a.level == b.level then return a.name < b.name end
    return a.level < b.level
  end)
  local items = { { "gui.any-quality" } }
  for _, quality in ipairs(qualities) do items[#items + 1] = quality.name end
  return items
end

local function write_filter(frame, editor, settings)
  local slot = frame.tags.selected_slot or 1
  local item = editor.filter_item and editor.filter_item.elem_value
  if not item or not item.name then
    settings.filters[slot] = false
    return
  end
  local quality_choice = editor.filter_quality.selected_index or 1
  local comparator = FILTER_COMPARATORS[editor.filter_comparator.selected_index or 1]
  local filter = { name = item.name, comparator = comparator }
  if quality_choice ~= 1 then filter.quality = editor.filter_quality.items[quality_choice] end
  settings.filters[slot] = filter
end

local function show_filter_editor(frame, box, settings, slot)
  frame.tags.selected_slot = slot
  local filter = settings.filters[slot]
  if filter == false then filter = nil end
  box.filter_editor.slot_label.caption = { "gui.slot", slot }
  box.filter_editor.filter_item.elem_value = filter and { name = filter.name } or nil
  box.filter_editor.filter_comparator.selected_index = select_index(FILTER_COMPARATORS, filter and filter.comparator, 1)
  box.filter_editor.filter_quality.selected_index = filter and filter.quality and select_index(box.filter_editor.filter_quality.items, filter.quality, 1) or 1
end

local function build_filters(box, frame, unit, settings)
  local grid = box.add({ type = "table", name = "filter_grid", column_count = 10 })
  for i = 1, 10 do
    local slot = add(grid, { type = "choose-elem-button", elem_type = "item", name = "filter_slot_" .. i, style = "slot_button" }, unit, "filter_slot", i)
    local filter = settings.filters[i]
    if filter and filter ~= false then slot.elem_value = filter.name end
  end
  local editor = aligned(box, "filter_editor")
  editor.add({ type = "label", name = "slot_label", caption = { "gui.slot", 1 } })
  add(editor, { type = "choose-elem-button", elem_type = "item", name = "filter_item" }, unit, "filter_item")
  add(editor, { type = "drop-down", name = "filter_comparator", style = "circuit_condition_comparator_dropdown", items = FILTER_COMPARATORS, selected_index = 1 }, unit, "filter_comparator")
  local qualities = quality_items()
  add(editor, { type = "drop-down", name = "filter_quality", items = qualities, selected_index = 1 }, unit, "filter_quality")
  show_filter_editor(frame, box, settings, 1)
end

local function build_timeout(box, unit, settings)
  local row = aligned(box, "timeout_row")
  row.add({ type = "label", caption = { "gui.timeout" } })
  add(row, { type = "switch", name = "timeout_mode", left_label_caption = { "gui.global" }, right_label_caption = { "gui.custom" }, switch_state = settings.timeout_mode == "custom" and "right" or "left" }, unit, "timeout_mode")
  add(row, { type = "textfield", name = "timeout_s", text = tostring(settings.timeout_s or 0), numeric = true, allow_decimal = false, allow_negative = false, style = "short_number_textfield" }, unit, "timeout_s")
end

local function build_circuit(box, unit, circuit)
  local condition = aligned(box, "circuit_condition_row")
  add(condition, { type = "checkbox", name = "circuit_enable", caption = { "gui.enable-condition" }, state = circuit.enable }, unit, "circuit.enable")
  local signal = add(condition, { type = "choose-elem-button", elem_type = "signal", name = "circuit_signal" }, unit, "circuit.cond.first_signal")
  if circuit.cond.first_signal then signal.elem_value = signal_elem(circuit.cond.first_signal) end
  add(condition, { type = "drop-down", name = "circuit_comparator", style = "circuit_condition_comparator_dropdown", items = CIRCUIT_COMPARATORS, selected_index = select_index(CIRCUIT_COMPARATORS, circuit.cond.comparator, 3) }, unit, "circuit.cond.comparator")
  add(condition, { type = "textfield", name = "circuit_constant", text = tostring(circuit.cond.constant or 0), numeric = true, allow_decimal = false, allow_negative = true, style = "short_number_textfield" }, unit, "circuit.cond.constant")
  local flush = aligned(box, "circuit_flush_row")
  add(flush, { type = "checkbox", name = "circuit_flush", caption = { "gui.flush-signal" }, state = circuit.flush }, unit, "circuit.flush")
  local flush_signal = add(flush, { type = "choose-elem-button", elem_type = "signal", name = "flush_signal" }, unit, "circuit.flush_signal")
  if circuit.flush_signal then flush_signal.elem_value = signal_elem(circuit.flush_signal) end
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
  frame.tags = frame.tags or {}
  local settings, unit = rec.settings, rec.unit_number
  local filters = section(frame, { "gui.filters" }, "filters_section"); build_filters(filters, frame, unit, settings)
  local timeout = section(frame, { "gui.timeout" }, "timeout_section"); build_timeout(timeout, unit, settings)
  local circuit = section(frame, { "gui.circuit-network" }, "circuit_section"); build_circuit(circuit, unit, settings.circuit)
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
  elseif field == "filter_slot" then
    local player = game.players[e.player_index]
    local frame = player and frame_for(player)
    if frame then show_filter_editor(frame, frame.filters_section, s, el.tags.row) end
  elseif field == "filter_item" or field == "filter_comparator" or field == "filter_quality" then
    local player = game.players[e.player_index]
    local frame = player and frame_for(player)
    if frame then
      local slot = frame.tags.selected_slot or 1
      local section_box = frame.filters_section
      write_filter(frame, section_box.filter_editor, s)
      local button = section_box.filter_grid["filter_slot_" .. slot]
      button.elem_value = section_box.filter_editor.filter_item.elem_value and section_box.filter_editor.filter_item.elem_value.name or nil
    end
  elseif field == "circuit.enable" then
    c.enable = el.state
  elseif field == "circuit.cond.first_signal" then
    c.cond.first_signal = el.elem_value
  elseif field == "circuit.cond.comparator" then
    c.cond.comparator = CIRCUIT_COMPARATORS[el.selected_index] or c.cond.comparator
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
