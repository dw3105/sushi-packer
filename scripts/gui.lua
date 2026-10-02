local N = require("scripts.names")
local circuit_api = require("scripts.circuit")
local arms = require("scripts.arms")
local M = {}

local FRAME = "sushi_packer_frame"
local LANE_COLUMNS = 12
local FILTER_COMPARATORS = { "=", "≠", ">", "<", "≥", "≤" }
local CIRCUIT_COMPARATORS = { ">", "<", "=", "≥", "≤", "≠" }

local function tags(unit, field, row)
  return { sushi_packer = unit, field = field, row = row }
end

local function add(parent, spec, unit, field, row)
  spec.tags = tags(unit, field, row)
  return parent.add(spec)
end

-- LuaGuiElement.tags returns a copy: read, change, write back.
local function set_tag(el, key, value)
  local t = el.tags or {}
  t[key] = value
  el.tags = t
end

local function frame_for(player)
  local f = player.gui.screen[FRAME]
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

local function has_quality_picker()
  local count = 0
  for _, quality in pairs(prototypes.quality) do
    if not quality.hidden then count = count + 1 end
  end
  return count > 1
end

-- filters is an ipairs array (scripts/filter.lua): empty slots before `slot` must be false, never nil.
local function pad(filters, slot)
  for i = 1, slot - 1 do if filters[i] == nil then filters[i] = false end end
end

local function write_filter(frame, editor, settings)
  local slot = frame.tags.selected_slot or 1
  pad(settings.filters, slot)
  local item = editor.filter_item and editor.filter_item.elem_value  -- elem_type "item": string or nil
  if not item then
    settings.filters[slot] = false
    return
  end
  local filter = { name = item }
  if has_quality_picker() then
    local quality_choice = editor.filter_quality.selected_index or 1
    filter.comparator = FILTER_COMPARATORS[editor.filter_comparator.selected_index or 1]
    if quality_choice ~= 1 then filter.quality = editor.filter_quality.items[quality_choice] end
  end
  settings.filters[slot] = filter
end

local function show_filter_editor(frame, box, settings, slot)
  set_tag(frame, "selected_slot", slot)
  local filter = settings.filters[slot]
  if filter == false then filter = nil end
  box.filter_editor.slot_label.caption = { "gui.slot", slot }
  box.filter_editor.filter_item.elem_value = filter and filter.name or nil
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
  local picker_visible = has_quality_picker()
  add(editor, { type = "drop-down", name = "filter_comparator", style = "circuit_condition_comparator_dropdown", items = FILTER_COMPARATORS, selected_index = 1, visible = picker_visible }, unit, "filter_comparator")
  local qualities = quality_items()
  add(editor, { type = "drop-down", name = "filter_quality", items = qualities, selected_index = 1, visible = picker_visible }, unit, "filter_quality")
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

local function lane_stack(inv, slot)
  if not inv then return nil end
  local stack = inv[slot]
  if stack and stack.valid_for_read then return stack end
end

local function set_if_changed(element, field, value)
  if element[field] ~= value then element[field] = value end
end

local function refresh_lane_buttons(frame, rec)
  if not frame or not frame.valid or not frame.lanes_section then return end
  for lane = 1, 2 do
    local row = frame.lanes_section["lane_" .. lane]
    if row then
      for slot = 1, N.STORE_SLOTS do
        local button = row["lane_slot_" .. slot]
        local stack = lane_stack(rec.invs and rec.invs[lane], slot)
        if button then
          if stack then
            local name = stack.name
            local quality = stack.quality and stack.quality.name or nil
            set_if_changed(button, "sprite", "item/" .. name)
            set_if_changed(button, "number", stack.count)
            set_if_changed(button, "quality", quality)
            local tooltip = button.elem_tooltip
            if not tooltip or tooltip.name ~= name or tooltip.quality ~= quality then  -- engine reads type back as "item"
              button.elem_tooltip = { type = "item-with-quality", name = name, quality = quality }
            end
          else
            set_if_changed(button, "sprite", nil)
            set_if_changed(button, "number", nil)
            set_if_changed(button, "quality", nil)
            set_if_changed(button, "elem_tooltip", nil)
          end
        end
      end
    end
  end
end

function M._refresh(player, rec)
  if not player or not rec then return end
  refresh_lane_buttons(frame_for(player), rec)
end

local function build_lanes(frame, unit, rec)
  local box = section(frame, { "gui.lanes" }, "lanes_section")
  for lane = 1, 2 do
    local row = box.add({ type = "table", name = "lane_" .. lane, column_count = LANE_COLUMNS })
    row.style.horizontal_spacing = 0
    row.style.vertical_spacing = 0
    for slot = 1, N.STORE_SLOTS do
      local button = add(row, { type = "sprite-button", name = "lane_slot_" .. slot, style = "slot_button" }, unit, "lane_slot")
      set_tag(button, "lane", lane)
      set_tag(button, "slot", slot)
    end
  end
  refresh_lane_buttons(frame, rec)
end

local function build(player, rec)
  local old = frame_for(player)
  if old then old.destroy() end
  local frame = player.gui.screen.add({ type = "frame", name = FRAME, direction = "vertical", auto_center = true,
    tags = { sushi_packer = rec.unit_number } })
  local titlebar = frame.add({ type = "flow", name = "titlebar", direction = "horizontal" })
  titlebar.drag_target = frame
  titlebar.add({ type = "label", caption = { "gui.title" }, style = "frame_title" })
  titlebar.add({ type = "empty-widget", style = "draggable_space", ignored_by_interaction = true })
  add(titlebar, { type = "sprite-button", name = "close", sprite = "utility/close", tooltip = { "gui.close" }, style = "frame_action_button" }, rec.unit_number, "close")
  local settings, unit = rec.settings, rec.unit_number
  build_lanes(frame, unit, rec)
  local filters = section(frame, { "gui.filters" }, "filters_section"); build_filters(filters, frame, unit, settings)
  local timeout = section(frame, { "gui.timeout" }, "timeout_section"); build_timeout(timeout, unit, settings)
  local circuit = section(frame, { "gui.circuit-network" }, "circuit_section"); build_circuit(circuit, unit, settings.circuit)
  add(circuit, { type = "checkbox", name = "circuit_read", caption = { "gui.read-contents" }, state = settings.circuit.read ~= false }, unit, "circuit.read")
  player.opened = frame
  return frame
end

-- Open window shows live lane stores (tick calls this every 30 ticks per connected player). Packer gone: window closes.
function M._refresh_open(player)
  local frame = frame_for(player)
  if not frame then return end
  local unit = frame.tags and frame.tags.sushi_packer
  local rec = unit and storage.boxes and storage.boxes[unit]
  if rec then M._refresh(player, rec) else frame.destroy() end
end

function M.open(player, rec)
  if player and rec then return build(player, rec) end
end

function M.on_opened(e)
  if not e.entity or not e.entity.valid then return end
  local rec = storage.boxes and storage.boxes[e.entity.unit_number]
  if not rec then return end
  M.open(game.players[e.player_index], rec)
end

function M.on_open_input(e)
  local player = game.players[e.player_index]
  if not player or player.opened ~= nil or player.opened_gui_type ~= defines.gui_type.none then return end
  if player.is_cursor_empty and not player.is_cursor_empty() then return end  -- building with item in hand: no window
  local entity = player.selected
  if not entity or not entity.valid or not player.can_reach_entity(entity) then return end
  local rec = storage.boxes and storage.boxes[entity.unit_number]
  if rec then M.open(player, rec) end
end

function M.on_closed(e)
  local player = game.players[e.player_index]
  if not player then return end
  local frame = frame_for(player)
  if frame and e.element == frame then
    frame.destroy()
    if player.opened == frame then player.opened = nil end
  end
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
  local player = game.players[e.player_index]
  local frame = player and frame_for(player)
  if field == "close" and frame then frame.destroy(); if player.opened == frame then player.opened = nil end; return end
  local rec = storage.boxes and storage.boxes[unit]
  if not rec or not rec.settings then return end
  local s, c = rec.settings, rec.settings.circuit
  if field == "lane_slot" then
    return
  elseif field == "timeout_mode" then
    s.timeout_mode = el.switch_state == "right" and "custom" or "global"
  elseif field == "timeout_s" then
    local n = timeout_number(el.text, 3600); if n then s.timeout_s = n end
  elseif field == "filter_slot" then
    local player = game.players[e.player_index]
    local frame = player and frame_for(player)
    local slot = el.tags.row
    if e.name == defines.events.on_gui_elem_changed then
      -- Item picked (or cleared) straight in grid slot: save it, keep rule when same item.
      local old = s.filters[slot]
      pad(s.filters, slot)
      if not el.elem_value then s.filters[slot] = false
      elseif not (old and old.name == el.elem_value) then s.filters[slot] = { name = el.elem_value } end
    end
    if frame then show_filter_editor(frame, frame.filters_section, s, slot) end
  elseif field == "filter_item" or field == "filter_comparator" or field == "filter_quality" then
    local player = game.players[e.player_index]
    local frame = player and frame_for(player)
    if frame then
      local slot = frame.tags.selected_slot or 1
      local section_box = frame.filters_section
      write_filter(frame, section_box.filter_editor, s)
      local button = section_box.filter_grid["filter_slot_" .. slot]
      button.elem_value = section_box.filter_editor.filter_item.elem_value
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
  elseif field == "circuit.read" then
    c.read = el.state
    circuit_api.apply(rec)
    arms.wire(rec, c.read)
  end
  if field == "circuit.enable" or field == "circuit.cond.first_signal" or field == "circuit.cond.comparator" or field == "circuit.cond.constant" then circuit_api.apply(rec) end
end

return M
