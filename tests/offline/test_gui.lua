local gui

local function fixture()
  package.loaded["scripts.gui"] = nil
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
  local player = { gui = { relative = root } }
  game = { players = { [1] = player } }
  storage = { boxes = { [7] = { unit_number = 7, settings = {
    filters = { { name = "iron-plate", quality = "rare", comparator = "≥" }, false },
    timeout_mode = "global", timeout_s = 30,
    circuit = { enable = false, cond = { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 5 }, flush = false, flush_signal = nil },
  } } } }
  prototypes = { quality = {
    normal = { level = 0, hidden = false }, uncommon = { level = 1, hidden = false }, rare = { level = 2, hidden = false }, legendary = { level = 5, hidden = false }, ["quality-unknown"] = { level = 0, hidden = true },
  } }
  defines = { relative_gui_type = { container_gui = 1 }, relative_gui_position = { right = 2 } }
  gui.on_opened({ entity = { valid = true, unit_number = 7 }, player_index = 1 })
  return player, storage.boxes[7]
end

local function click(player, el, name)
  gui.on_event({ name = name or 1, element = el, player_index = 1 })
end

describe("gui", function()
  it("anchored right of container", function()
    local p = fixture()
    local f = p.gui.relative.sushi_packer_frame
    eq(f.anchor.gui, 1); eq(f.anchor.position, 2); eq(#f.anchor.names, 16)
  end)
  it("sections order skip timeout circuit", function()
    local p = fixture(); local f = p.gui.relative.sushi_packer_frame
    local captions = {}
    for _, x in ipairs(f.children) do if x.type == "frame" then captions[#captions + 1] = x.children[1].caption[1] end end
    eq(captions, { "gui.filters", "gui.timeout", "gui.circuit-network" })
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
