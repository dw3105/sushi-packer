local gui

local function fixture(one_quality)
  package.loaded["scripts.gui"] = nil
  local applied, wired = 0, 0
  package.loaded["scripts.circuit"] = { apply = function() applied = applied + 1 end }
  package.loaded["scripts.arms"] = { wire = function() wired = wired + 1 end }
  gui = require("scripts.gui")
  local function node(spec, parent)
    local el = {}
    for k, v in pairs(spec or {}) do el[k] = v end
    el.children, el.style, el.tags, el.valid = {}, (spec and spec.style) or {}, (spec and spec.tags) or {}, true
    el.add = function(child_spec)
      local child = node(child_spec, el)
      el.children[#el.children + 1] = child
      if child.name then el[child.name] = child end
      return child
    end
    el.destroy = function()
      el.valid = false
      if parent then for i, child in ipairs(parent.children) do if child == el then table.remove(parent.children, i); break end end end
    end
    return el
  end
  local root = node({})
  local player = { gui = { screen = root, relative = root }, opened_gui_type = 0, can_reach_entity = function() return true end }
  game = { players = { [1] = player } }
  storage = { boxes = { [7] = { unit_number = 7, settings = {
    filters = { { name = "iron-plate", quality = "rare", comparator = "≥" }, false },
    timeout_mode = "global", timeout_s = 30,
    circuit = { enable = false, cond = { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 5 }, read = true, flush = false, flush_signal = nil },
  } } } }
  local qualities = {
    normal = { level = 0, hidden = false }, uncommon = { level = 1, hidden = false }, rare = { level = 2, hidden = false }, legendary = { level = 5, hidden = false }, ["quality-unknown"] = { level = 0, hidden = true },
  }
  if one_quality then qualities = { normal = { level = 0, hidden = false }, ["quality-unknown"] = { level = 0, hidden = true } } end
  prototypes = { quality = qualities, item = { ["sushi-packer"] = {}, ["fast-sushi-packer"] = {}, ["express-sushi-packer"] = {}, ["turbo-sushi-packer"] = {} } }  -- v9: N.active() = vanilla 4
  defines = { gui_type = { none = 0 }, relative_gui_type = { container_gui = 1 }, relative_gui_position = { right = 2 },
    events = { on_gui_click = 1, on_gui_elem_changed = 2, on_gui_selection_state_changed = 3, on_gui_checked_state_changed = 4, on_gui_switch_state_changed = 5, on_gui_text_changed = 6 } }
  local body = { valid = true, unit_number = 7 }; player.selected = body
  gui.on_opened({ entity = body, player_index = 1 })
  return player, storage.boxes[7], function() return applied, wired end, body
end

local function click(player, el, name)
  gui.on_event({ name = name or 1, element = el, player_index = 1 })
end

describe("gui", function()
  it("uses screen frame", function()
    local p = fixture()
    local f = p.gui.relative.sushi_packer_frame
    ok(f ~= nil); eq(f.auto_center, true); ok(p.opened == f)
  end)
  it("sections order skip timeout circuit", function()
    local p = fixture(); local f = p.gui.relative.sushi_packer_frame
    local captions = {}
    for _, x in ipairs(f.children) do if x.type == "frame" then captions[#captions + 1] = x.children[1].caption[1] end end
    eq(captions, { "gui.lanes", "gui.filters", "gui.timeout", "gui.circuit-network" })
  end)
  it("ten slots show filters", function()
    local p = fixture(); local f = p.gui.relative.sushi_packer_frame
    local grid = f.filters_section.filter_grid
    eq(grid.column_count, 10); eq(grid.filter_slot_1.elem_value, "iron-plate"); eq(grid.filter_slot_2.elem_value, nil)
  end)
  it("empty slot shows empty", function()
    local p = fixture(); eq(p.gui.relative.sushi_packer_frame.filters_section.filter_grid.filter_slot_2.elem_value, nil)
  end)
  it("slot click opens editor", function()
    local p = fixture(); local f = p.gui.relative.sushi_packer_frame
    click(p, f.filters_section.filter_grid.filter_slot_2)
    eq(f.tags.selected_slot, 2); eq(f.filters_section.filter_editor.filter_item.elem_value, nil)
  end)
  it("editor writes comparator and quality", function()
    local p, rec = fixture(); local f = p.gui.relative.sushi_packer_frame
    click(p, f.filters_section.filter_grid.filter_slot_1)
    f.filters_section.filter_editor.filter_comparator.selected_index = 5; click(p, f.filters_section.filter_editor.filter_comparator)
    f.filters_section.filter_editor.filter_quality.selected_index = 4; click(p, f.filters_section.filter_editor.filter_quality)
    eq(rec.settings.filters[1].comparator, "≥"); eq(rec.settings.filters[1].quality, "rare")
  end)
  it("any quality clears quality", function()
    local p, rec = fixture(); local f = p.gui.relative.sushi_packer_frame
    click(p, f.filters_section.filter_grid.filter_slot_1); f.filters_section.filter_editor.filter_quality.selected_index = 1; click(p, f.filters_section.filter_editor.filter_quality)
    eq(rec.settings.filters[1].quality, nil)
  end)
  it("clearing slot writes false", function()
    local p, rec = fixture(); local f = p.gui.relative.sushi_packer_frame
    click(p, f.filters_section.filter_grid.filter_slot_1); f.filters_section.filter_editor.filter_item.elem_value = nil; click(p, f.filters_section.filter_editor.filter_item)
    eq(rec.settings.filters[1], false)
  end)
  it("quality list sorted by level with any first", function()
    local p = fixture(); local q = p.gui.relative.sushi_packer_frame.filters_section.filter_editor.filter_quality
    eq(q.items, { { "gui.any-quality" }, "normal", "uncommon", "rare", "legendary" })
  end)
  it("one quality hides picker", function()
    local p = fixture(true)
    click(p, p.gui.relative.sushi_packer_frame.filters_section.filter_grid.filter_slot_2)
    local editor = p.gui.relative.sushi_packer_frame.filters_section.filter_editor
    eq(editor.filter_comparator.visible, false); eq(editor.filter_quality.visible, false)
  end)
  it("quality mod shows picker", function()
    local p = fixture(); local f = p.gui.relative.sushi_packer_frame
    click(p, f.filters_section.filter_grid.filter_slot_2)
    local editor = f.filters_section.filter_editor
    ok(editor.filter_comparator.visible ~= false); ok(editor.filter_quality.visible ~= false)
  end)
  it("one quality filter saves item only", function()
    local p, rec = fixture(true)
    local f = p.gui.relative.sushi_packer_frame
    click(p, f.filters_section.filter_grid.filter_slot_2)
    f.filters_section.filter_editor.filter_item.elem_value = "iron-plate"
    click(p, f.filters_section.filter_editor.filter_item)
    eq(rec.settings.filters[2].name, "iron-plate")
    eq(rec.settings.filters[2].quality, nil); eq(rec.settings.filters[2].comparator, nil)
  end)
  it("one quality stored quality filter loads", function()
    local p = fixture(true)
    local f = p.gui.relative.sushi_packer_frame
    click(p, f.filters_section.filter_grid.filter_slot_1)
    eq(f.filters_section.filter_editor.filter_item.elem_value, "iron-plate")
  end)
  it("timeout switch and seconds written", function()
    local _, rec = fixture(); local f = game.players[1].gui.relative.sushi_packer_frame.timeout_section.timeout_row
    f.timeout_mode.switch_state = "right"; click(game.players[1], f.timeout_mode)
    f.timeout_s.text = "90"; click(game.players[1], f.timeout_s)
    eq(rec.settings.timeout_mode, "custom"); eq(rec.settings.timeout_s, 90)
  end)
  it("bad timeout text ignored", function()
    local _, rec = fixture(); local f = game.players[1].gui.relative.sushi_packer_frame.timeout_section.timeout_row
    f.timeout_s.text = "3601"; click(game.players[1], f.timeout_s); eq(rec.settings.timeout_s, 30)
  end)
  it("circuit enable and condition written", function()
    local _, rec = fixture(); local f = game.players[1].gui.relative.sushi_packer_frame.circuit_section.circuit_condition_row
    eq(f.circuit_enable.tags.field, "circuit.enable"); f.circuit_enable.state = true; click(game.players[1], f.circuit_enable)
    f.circuit_signal.elem_value = { type = "item", name = "iron-plate" }; click(game.players[1], f.circuit_signal)
    f.circuit_comparator.selected_index = 5; click(game.players[1], f.circuit_comparator)
    f.circuit_constant.text = "9"; click(game.players[1], f.circuit_constant)
    eq(rec.settings.circuit.enable, true); eq(rec.settings.circuit.cond.first_signal.name, "iron-plate")
    eq(rec.settings.circuit.cond.comparator, "≤"); eq(rec.settings.circuit.cond.constant, 9)
  end)
  it("flush checkbox and signal written", function()
    local _, rec = fixture(); local f = game.players[1].gui.relative.sushi_packer_frame.circuit_section.circuit_flush_row
    f.circuit_flush.state = true; click(game.players[1], f.circuit_flush)
    f.flush_signal.elem_value = { type = "virtual", name = "signal-green" }; click(game.players[1], f.flush_signal)
    eq(rec.settings.circuit.flush, true); eq(rec.settings.circuit.flush_signal.name, "signal-green")
  end)
  it("foreign gui events ignored", function()
    local _, rec = fixture(); gui.on_event({ name = 1, element = { valid = true, tags = {}, state = true }, player_index = 1 })
    eq(rec.settings.circuit.enable, false)
  end)
  it("rows use aligned styles", function()
    local p = fixture(); local f = p.gui.relative.sushi_packer_frame
    for _, section in ipairs(f.children) do
      if section.type == "frame" then
        eq(section.style, "inside_shallow_frame_with_padding")
        eq(section.children[1].style, "bold_label")
        for _, row in ipairs(section.children) do if row.type == "flow" then eq(row.style, "player_input_horizontal_flow") end end
      end
    end
    eq(f.filters_section.filter_editor.filter_comparator.style, "circuit_condition_comparator_dropdown")
    eq(f.circuit_section.circuit_condition_row.circuit_comparator.style, "circuit_condition_comparator_dropdown")
  end)
end)

describe("gui lanes", function()
  local slots = 12
  local function inventory()
    local inv = { [2] = { valid_for_read = true, name = "iron-plate", count = 7, quality = { name = "rare" } } }
    for i = 1, slots do if not inv[i] then inv[i] = { valid_for_read = false } end end
    for i = 1, slots do
      local stack = inv[i]
      stack.clear = function() stack.valid_for_read = false; stack.count = 0 end
    end
    return inv
  end
  local function lane_fixture()
    local p, rec = fixture()
    rec.invs = { inventory(), inventory() }
    local calls = {}
    p.insert = function(spec) calls[#calls + 1] = spec; return spec.count end
    gui._refresh(p, rec)
    return p, rec, calls
  end
  it("section has two rows of twelve slots", function()
    local p = fixture(); local f = p.gui.relative.sushi_packer_frame
    ok(f.lanes_section ~= nil)
    for lane = 1, 2 do
      local row = f.lanes_section["lane_" .. lane]; ok(row ~= nil)
      eq(#row.children, slots)
      for slot = 1, slots do
        local b = row.children[slot]; eq(b.type, "sprite-button")
        eq(b.tags.sushi_packer, 7); eq(b.tags.field, "lane_slot"); eq(b.tags.lane, lane); eq(b.tags.slot, slot)
      end
    end
  end)
  it("slot shows item count quality", function()
    local p = lane_fixture(); local row = p.gui.relative.sushi_packer_frame.lanes_section.lane_1
    eq(row.children[2].sprite, "item/iron-plate"); eq(row.children[2].number, 7); eq(row.children[2].tooltip, "rare")
    eq(row.children[1].sprite, nil); eq(row.children[1].number, nil)
  end)
  it("click leaves stack in lane", function()
    local p, rec, calls = lane_fixture(); local button = p.gui.relative.sushi_packer_frame.lanes_section.lane_1.children[2]
    click(p, button); eq(calls, {}); eq(rec.invs[1][2].count, 7); eq(button.number, 7)
  end)
  it("slot click never inserts into player", function()
    local p, rec, calls = lane_fixture(); p.insert = function(spec) calls[#calls + 1] = spec; return 0 end
    local button = p.gui.relative.sushi_packer_frame.lanes_section.lane_1.children[2]
    click(p, button); eq(rec.invs[1][2].count, 7); eq(button.number, 7); eq(#calls, 0)
  end)
  it("click on empty slot does nothing", function()
    local p, _, calls = lane_fixture(); local button = p.gui.relative.sushi_packer_frame.lanes_section.lane_1.children[1]
    click(p, button); eq(#calls, 0)
  end)
  it("rec without stores shows empty rows", function()
    local p, rec = fixture(); rec.invs = nil
    gui._refresh(p, rec)
    local row = p.gui.relative.sushi_packer_frame.lanes_section.lane_1
    eq(row.children[1].sprite, nil); click(p, row.children[1])
  end)
  it("refresh updates open window", function()
    local p, rec = fixture(); local f = p.gui.relative.sushi_packer_frame
    local old = f.lanes_section.lane_1.children[2]
    rec.invs = { inventory(), inventory() }; gui._refresh(p, rec)
    ok(p.gui.relative.sushi_packer_frame == f); eq(old.sprite, "item/iron-plate"); eq(old.number, 7)
  end)
end)

describe("gui v17", function()
  it("open builds screen frame and sets opened", function()
    local p, rec = fixture(); rec.settings.filters = rec.settings.filters or {}
    local f = p.gui.screen.sushi_packer_frame
    ok(f and f.lanes_section and f.filters_section and f.timeout_section and f.circuit_section)
    ok(p.opened == f); eq(f.auto_center, true)
  end)
  it("open twice keeps one frame", function()
    local p, rec = fixture(); local f = p.gui.screen.sushi_packer_frame
    gui.open(p, rec); eq(f.valid, false); ok(p.gui.screen.sushi_packer_frame ~= f)
  end)
  it("game belt window is replaced", function()
    local p, _, _, body = fixture(); gui.on_opened({ player_index = 1, entity = body }); ok(p.opened ~= nil)
    storage.boxes[7] = nil; p.opened = nil; gui.on_opened({ player_index = 1, entity = body }); eq(p.opened, nil)
  end)
  it("open input opens for selected packer", function()
    local p, _, _, body = fixture(); p.opened = nil; p.selected = body
    gui.on_open_input({ player_index = 1 }); ok(p.opened ~= nil)
    p.opened = nil; p.can_reach_entity = function() return false end; gui.on_open_input({ player_index = 1 }); ok(p.opened == nil)
    p.can_reach_entity = function() return true end; local other = {}; p.opened = other; gui.on_open_input({ player_index = 1 }); eq(p.opened, other)
  end)
  it("closed destroys own frame only", function()
    local p = fixture(); local f = p.opened; gui.on_closed({ player_index = 1, element = {} }); eq(f.valid, true)
    gui.on_closed({ player_index = 1, element = f }); eq(f.valid, false)
  end)
  it("close button closes", function()
    local p = fixture(); local f = p.opened; local close = f.titlebar.close
    ok(close ~= nil); click(p, close); eq(f.valid, false); eq(p.opened, nil)
  end)
  it("lane slot click takes nothing", function()
    local p, rec = fixture(); rec.invs = { { [1] = { valid_for_read = true, name = "iron-plate", count = 4 } }, {} }
    local button = p.opened.lanes_section.lane_1.lane_slot_1; click(p, button); eq(rec.invs[1][1].count, 4)
  end)
  it("read contents tick", function()
    local p, rec, counts = fixture(); local cb = p.opened.circuit_section.circuit_read
    ok(cb and cb.state == true); cb.state = false; click(p, cb, defines.events.on_gui_checked_state_changed)
    eq(rec.settings.circuit.read, false); local a, w = counts(); eq(a, 1); eq(w, 1)
  end)
  it("enable and condition changes are applied to belt", function()
    local p, rec, counts = fixture(); local row = p.opened.circuit_section.circuit_condition_row
    row.circuit_enable.state = true; click(p, row.circuit_enable)
    row.circuit_signal.elem_value = { type = "virtual", name = "signal-B" }; click(p, row.circuit_signal)
    row.circuit_comparator.selected_index = 1; click(p, row.circuit_comparator)
    row.circuit_constant.text = "12"; click(p, row.circuit_constant)
    local a = counts(); eq(a, 4); eq(rec.settings.circuit.enable, true)
    local timeout = p.opened.timeout_section.timeout_row.timeout_s; timeout.text = "40"; click(p, timeout)
    a = counts(); eq(a, 4)
  end)
end)
