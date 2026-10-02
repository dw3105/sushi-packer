-- v6 GUI (S-3, P-1, N-3, N-4): sections, 10-slot filter grid + editor, circuit section. Real LuaGuiElement API.
local N = require("scripts.names")
local gui = require("scripts.gui")
local registry = require("scripts.registry")

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -30, -30 }, { 30, 30 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

local function find(root, name)
  for _, child in pairs(root.children) do
    if child.name == name then return child end
    local found = find(child, name)
    if found then return found end
  end
end

describe("gui", function()
  local surface, player, box, rec
  local function open()
    gui.on_opened({ player_index = player.index, entity = box, gui_type = defines.gui_type.entity })
    return player.gui.screen.sushi_packer_frame
  end
  local function fire(el, ev) gui.on_event({ player_index = player.index, element = el, name = ev }) end
  before_each(function()
    surface, player = game.surfaces[1], game.players[1]
    clear(surface)
    player.opened = nil
    box = surface.create_entity({ name = N.body("yellow"), position = { 0.5, 0.5 }, direction = defines.direction.north, force = game.forces.player })
    storage.boxes = {}
    rec = registry.new_rec(box)
  end)
  after_each(function()
    player.opened = nil
    local f = player.gui.screen.sushi_packer_frame
    if f then f.destroy() end
  end)

  it("opening box shows four sections", function()
    -- v15 (V14-10, V15-1): lanes section (two lane rows) added on top.
    local f = open()
    assert.is_not_nil(f)
    local names = {}
    for _, c in ipairs(f.children) do names[#names + 1] = c.name end
    assert.are_same({ "lanes_section", "filters_section", "timeout_section", "circuit_section" }, names)
    local lanes = f.lanes_section
    for lane = 1, 2 do
      assert.is_not_nil(lanes["lane_" .. lane], "lane row " .. lane)
      assert.is_not_nil(lanes["lane_" .. lane]["lane_slot_" .. N.STORE_SLOTS], "lane row " .. lane .. " has 12 slots")
    end
  end)

  it("closing removes frame", function()
    open()
    gui.on_closed({ player_index = player.index })
    assert.is_nil(player.gui.screen.sushi_packer_frame)
  end)

  it("item picked in slot saved as filter", function()
    local f = open()
    local slot = find(f, "filter_slot_3")
    slot.elem_value = "iron-plate"
    fire(slot, defines.events.on_gui_elem_changed)
    assert.are_equal("iron-plate", rec.settings.filters[3] and rec.settings.filters[3].name)
    assert.is_nil(rec.settings.filters[3].quality)
  end)

  it("editor sets comparator and quality on selected slot", function()
    local f = open()
    local slot = find(f, "filter_slot_2")
    slot.elem_value = "iron-plate"
    fire(slot, defines.events.on_gui_elem_changed)
    local cmp, q = find(f, "filter_comparator"), find(f, "filter_quality")
    cmp.selected_index = 5  -- "≥"
    fire(cmp, defines.events.on_gui_selection_state_changed)
    for i, item in ipairs(q.items) do if item == "uncommon" then q.selected_index = i end end
    fire(q, defines.events.on_gui_selection_state_changed)
    local fl = rec.settings.filters[2]
    assert.are_equal("iron-plate", fl.name)
    assert.are_equal("≥", fl.comparator)
    assert.are_equal("uncommon", fl.quality)
  end)

  it("editor item change writes selected slot", function()
    local f = open()
    local slot = find(f, "filter_slot_4")
    fire(slot, defines.events.on_gui_click)
    local item = find(f, "filter_item")
    item.elem_value = "copper-plate"
    fire(item, defines.events.on_gui_elem_changed)
    assert.are_equal("copper-plate", rec.settings.filters[4] and rec.settings.filters[4].name)
    assert.are_equal("copper-plate", find(f, "filter_slot_4").elem_value)
  end)

  it("clearing slot writes false", function()
    rec.settings.filters = { { name = "iron-plate" } }
    local f = open()
    assert.are_equal("iron-plate", find(f, "filter_slot_1").elem_value)
    local slot = find(f, "filter_slot_1")
    slot.elem_value = nil
    fire(slot, defines.events.on_gui_elem_changed)
    assert.are_equal(false, rec.settings.filters[1])
  end)

  it("custom timeout written", function()
    local f = open()
    local sw, tf = find(f, "timeout_mode"), find(f, "timeout_s")
    sw.switch_state = "right"; fire(sw, defines.events.on_gui_switch_state_changed)
    tf.text = "42"; fire(tf, defines.events.on_gui_text_changed)
    assert.are_equal("custom", rec.settings.timeout_mode)
    assert.are_equal(42, rec.settings.timeout_s)
  end)

  it("circuit condition and flush written", function()
    local f = open()
    local en, sig, cmp, const = find(f, "circuit_enable"), find(f, "circuit_signal"), find(f, "circuit_comparator"), find(f, "circuit_constant")
    en.state = true; fire(en, defines.events.on_gui_checked_state_changed)
    sig.elem_value = { type = "virtual", name = "signal-A" }; fire(sig, defines.events.on_gui_elem_changed)
    cmp.selected_index = 2; fire(cmp, defines.events.on_gui_selection_state_changed)
    const.text = "7"; fire(const, defines.events.on_gui_text_changed)
    local fl, fs = find(f, "circuit_flush"), find(f, "flush_signal")
    fl.state = true; fire(fl, defines.events.on_gui_checked_state_changed)
    fs.elem_value = { type = "virtual", name = "signal-F" }; fire(fs, defines.events.on_gui_elem_changed)
    local c = rec.settings.circuit
    assert.is_true(c.enable); assert.are_equal("signal-A", c.cond.first_signal.name)
    assert.are_equal("<", c.cond.comparator); assert.are_equal(7, c.cond.constant)
    assert.is_true(c.flush); assert.are_equal("signal-F", c.flush_signal.name)
  end)
end)
