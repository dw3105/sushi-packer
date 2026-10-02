-- Event wiring only. Frozen (SP-01). Logic lives in scripts/*; see docs/CONTRACT.md.
local N = require("scripts.names")
local registry = require("scripts.registry")
local copy = require("scripts.copy")
local gui = require("scripts.gui")
local tick = require("scripts.tick")
local sim = require("scripts.sim")

local function init_storage()
  storage.boxes = storage.boxes or {}
  storage.belt_stack = storage.belt_stack or {}
end

script.on_init(init_storage)
script.on_configuration_changed(function(data)
  init_storage()
  storage.belt_stack = {}  -- mods may change research or engine max belt stack: recompute per force
  registry.on_configuration_changed(data)
end)

-- Build: placers (normal path) and variants (clone/revive/undo/script paths). Active tiers only (v9 M-1:
-- modded tier names without prototype would break filters; FND-0022 P3 prototypes readable here).
local build_filter = {}
local box_filter = {}
for _, tier in ipairs(N.active()) do
  build_filter[#build_filter + 1] = { filter = "name", name = N.placer(tier) }
  for _, dir in ipairs(N.DIRS) do
    build_filter[#build_filter + 1] = { filter = "name", name = N.variant(tier, dir) }
    box_filter[#box_filter + 1] = { filter = "name", name = N.variant(tier, dir) }
  end
end
table.sort(build_filter, function(a, b) return a.name < b.name end)
table.sort(box_filter, function(a, b) return a.name < b.name end)

for _, ev in ipairs({
  defines.events.on_built_entity, defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity, defines.events.script_raised_built,
  defines.events.script_raised_revive,
}) do
  script.on_event(ev, registry.on_built, build_filter)
end

for _, ev in ipairs({
  defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity,
  defines.events.on_space_platform_mined_entity, defines.events.script_raised_destroy,
}) do
  script.on_event(ev, registry.on_removed, box_filter)
end
script.on_event(defines.events.on_entity_died, registry.on_died, box_filter)
script.on_event(defines.events.on_marked_for_deconstruction, function(e) tick.on_decon(e, true) end, box_filter)
script.on_event(defines.events.on_cancelled_deconstruction, function(e) tick.on_decon(e, false) end, box_filter)

script.on_event(N.INPUT_ROTATE, function(e) registry.on_rotate_input(e, false) end)
script.on_event(N.INPUT_REVERSE_ROTATE, function(e) registry.on_rotate_input(e, true) end)

script.on_event(defines.events.on_player_setup_blueprint, copy.on_setup_blueprint)
script.on_event(defines.events.on_entity_settings_pasted, copy.on_settings_pasted)
script.on_event(defines.events.on_entity_cloned, copy.on_cloned, box_filter)

script.on_event(N.INPUT_OPEN, gui.on_open_input)  -- v17: click on belt body (belt kind has no window of its own)
script.on_event(defines.events.on_gui_opened, gui.on_opened)
script.on_event(defines.events.on_gui_closed, gui.on_closed)
for _, ev in ipairs({
  defines.events.on_gui_click, defines.events.on_gui_elem_changed, defines.events.on_gui_text_changed,
  defines.events.on_gui_checked_state_changed, defines.events.on_gui_selection_state_changed,
  defines.events.on_gui_value_changed, defines.events.on_gui_switch_state_changed, defines.events.on_gui_confirmed,
}) do
  script.on_event(ev, gui.on_event)
end

script.on_event(defines.events.on_tick, tick.on_tick)
for _, ev in ipairs({
  defines.events.on_research_finished, defines.events.on_research_reversed,
  defines.events.on_force_reset, defines.events.on_technology_effects_reset,
}) do
  script.on_event(ev, tick.on_research)
end

-- U-8: simulations (Factoriopedia, tips) load this control.lua via `mods`; their init calls scene.
-- v14 bench seam: work counters, off until asked (tools/bench only; no caller in normal play).
remote.add_interface(N.SIM_INTERFACE, {
  scene = function(kind) sim.scene(kind) end,
  counters_on = function() tick.counters_on() end,
  counters = function() return tick.counters() end,
})

-- In-game tests (FactorioTest). Absent in release zip: tests/ not shipped, mod not active.
if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")(require("tests.game.index"), { load_luassert = true })
end
