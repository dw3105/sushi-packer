local N = require("scripts.names")
local gui = require("scripts.gui")

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -30, -30 }, { 30, 30 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

local function element(root, field)
  for _, child in pairs(root.children) do
    if child.name == field or (child.tags and child.tags.field == field) then return child end
    local found = element(child, field)
    if found then return found end
  end
end

describe("gui", function()
  local surface, player, box, rec
  before_each(function()
    surface, player = game.surfaces[1], game.players[1]
    clear(surface)
    player.opened = nil
    local force = game.forces.player
    box = surface.create_entity({ name = N.variant("yellow", "north"), position = { 0.5, 0.5 }, force = force })
    rec = { entity = box, unit_number = box.unit_number, tier = "yellow", dir = "north", settings = {
      timeout_mode = "global", timeout_s = 0, filters = {},
      circuit = { enable = false, cond = { first_signal = nil, comparator = ">", constant = 0 }, flush = false, flush_signal = nil },
    } }
    storage.boxes = { [box.unit_number] = rec }
  end)
  after_each(function() player.opened = nil end)

  it("opening box shows frame", function()
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    assert.is_not_nil(player.gui.relative.sushi_packer_frame)
  end)

  it("closing removes frame", function()
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    gui.on_closed({ player_index = player.index })
    assert.is_nil(player.gui.relative.sushi_packer_frame)
  end)

  it("frame reflects current settings", function()
    rec.settings.timeout_mode, rec.settings.timeout_s = "custom", 42
    rec.settings.filters = { { name = "iron-plate", quality = "normal" } }
    rec.settings.circuit.enable = true
    rec.settings.circuit.cond = { first_signal = { type = "item", name = "copper-plate" }, comparator = "≥", constant = 19 }
    rec.settings.circuit.flush = true
    rec.settings.circuit.flush_signal = { type = "virtual", name = "signal-A" }
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    local f = player.gui.relative.sushi_packer_frame
    assert.are_equal("custom", element(f, "timeout_mode").switch_state and "custom" or "global")
    assert.are_equal("42", element(f, "timeout_s").text)
    assert.are_equal("iron-plate", element(f, "filter_item_1").elem_value.name)
    assert.is_true(element(f, "circuit_enable").state)
    assert.are_equal("copper-plate", element(f, "circuit_signal").elem_value.name)
    assert.are_equal(4, element(f, "circuit_comparator").selected_index)
    assert.are_equal("19", element(f, "circuit_constant").text)
    assert.is_true(element(f, "circuit_flush").state)
    assert.are_equal("signal-A", element(f, "flush_signal").elem_value.name)
  end)

  it("custom timeout written to settings", function()
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    element(player.gui.relative.sushi_packer_frame, "timeout_mode").switch_state = "right"
    gui.on_event({ player_index = player.index, element = element(player.gui.relative.sushi_packer_frame, "timeout_mode"), name = defines.events.on_gui_switch_state_changed })
    local field = element(player.gui.relative.sushi_packer_frame, "timeout_s"); field.text = "37"
    gui.on_event({ player_index = player.index, element = field, name = defines.events.on_gui_text_changed })
    assert.are_equal("custom", storage.boxes[box.unit_number].settings.timeout_mode)
    assert.are_equal(37, storage.boxes[box.unit_number].settings.timeout_s)
  end)

  it("global timeout mode written", function()
    rec.settings.timeout_mode = "custom"
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    local field = element(player.gui.relative.sushi_packer_frame, "timeout_mode"); field.switch_state = "left"
    gui.on_event({ player_index = player.index, element = field, name = defines.events.on_gui_switch_state_changed })
    assert.are_equal("global", storage.boxes[box.unit_number].settings.timeout_mode)
  end)

  it("bad timeout text ignored", function()
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    local field = element(player.gui.relative.sushi_packer_frame, "timeout_s"); field.text = "-2x"
    gui.on_event({ player_index = player.index, element = field, name = defines.events.on_gui_text_changed })
    assert.are_equal(0, storage.boxes[box.unit_number].settings.timeout_s)
  end)

  it("filter item any quality written", function()
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    local f = player.gui.relative.sushi_packer_frame
    element(f, "filter_item_1").elem_value = { name = "iron-plate", quality = "normal" }
    gui.on_event({ player_index = player.index, element = element(f, "filter_item_1"), name = defines.events.on_gui_elem_changed })
    element(f, "filter_any_1").state = true
    gui.on_event({ player_index = player.index, element = element(f, "filter_any_1"), name = defines.events.on_gui_checked_state_changed })
    local filters = storage.boxes[box.unit_number].settings.filters
    assert.are_equal("iron-plate", filters[1].name)
    assert.is_nil(filters[1].quality)
  end)

  it("filter item with quality written", function()
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    local f = player.gui.relative.sushi_packer_frame
    element(f, "filter_item_1").elem_value = { name = "iron-plate", quality = "rare" }
    gui.on_event({ player_index = player.index, element = element(f, "filter_item_1"), name = defines.events.on_gui_elem_changed })
    local filters = storage.boxes[box.unit_number].settings.filters
    assert.are_equal("iron-plate", filters[1].name)
    assert.are_equal("rare", filters[1].quality)
  end)

  it("clearing filter removes entry", function()
    rec.settings.filters = { { name = "iron-plate", quality = "normal" } }
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    local field = element(player.gui.relative.sushi_packer_frame, "filter_item_1"); field.elem_value = nil
    gui.on_event({ player_index = player.index, element = field, name = defines.events.on_gui_elem_changed })
    assert.are_equal(0, #storage.boxes[box.unit_number].settings.filters)
  end)

  it("circuit condition written", function()
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    local f = player.gui.relative.sushi_packer_frame
    local enable = element(f, "circuit_enable"); enable.state = true
    gui.on_event({ player_index = player.index, element = enable, name = defines.events.on_gui_checked_state_changed })
    local signal = element(f, "circuit_signal"); signal.elem_value = { type = "item", name = "iron-plate" }
    gui.on_event({ player_index = player.index, element = signal, name = defines.events.on_gui_elem_changed })
    local cmp = element(f, "circuit_comparator"); cmp.selected_index = 2
    gui.on_event({ player_index = player.index, element = cmp, name = defines.events.on_gui_selection_state_changed })
    local value = element(f, "circuit_constant"); value.text = "12"
    gui.on_event({ player_index = player.index, element = value, name = defines.events.on_gui_text_changed })
    local c = storage.boxes[box.unit_number].settings.circuit
    assert.is_true(c.enable); assert.are_equal("iron-plate", c.cond.first_signal.name)
    assert.are_equal("<", c.cond.comparator); assert.are_equal(12, c.cond.constant)
  end)

  it("flush signal written", function()
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    local f = player.gui.relative.sushi_packer_frame
    local flush = element(f, "circuit_flush"); flush.state = true
    gui.on_event({ player_index = player.index, element = flush, name = defines.events.on_gui_checked_state_changed })
    local signal = element(f, "flush_signal"); signal.elem_value = { type = "virtual", name = "signal-A" }
    gui.on_event({ player_index = player.index, element = signal, name = defines.events.on_gui_elem_changed })
    local c = storage.boxes[box.unit_number].settings.circuit
    assert.is_true(c.flush); assert.are_equal("signal-A", c.flush_signal.name)
  end)

  it("foreign gui events ignored", function()
    gui.on_event({ player_index = player.index, element = player.gui.screen, name = defines.events.on_gui_click })
    assert.are_equal("global", storage.boxes[box.unit_number].settings.timeout_mode)
  end)
end)
