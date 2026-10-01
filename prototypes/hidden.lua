-- Hidden arms pull from belt lanes into hidden lane stores; runtime creates both (FND-0040 / FND-0042).
local N = require("scripts.names")
local M = {}

local empty = { filename = "__core__/graphics/empty.png", size = 1 }

local function add_flag(flags, flag)
  for _, existing in ipairs(flags) do if existing == flag then return end end
  flags[#flags + 1] = flag
end

local function hide(p, store)
  p.hidden = true
  p.hidden_in_factoriopedia = true
  p.selectable_in_game = false
  p.minable = nil
  p.next_upgrade = nil
  p.fast_replaceable_group = nil
  p.placeable_by = nil
  p.allow_copy_paste = false
  p.corpse = nil
  p.dying_explosion = nil
  p.open_sound = nil
  p.close_sound = nil
  p.working_sound = nil
  p.flags = p.flags or {}
  for _, flag in ipairs({ "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable",
    "not-upgradable", "not-flammable", "not-in-kill-statistics" }) do add_flag(p.flags, flag) end
  if store then
    add_flag(p.flags, "no-automated-item-removal")
    add_flag(p.flags, "no-automated-item-insertion")
  end
end

function M.make()
  local arm = table.deepcopy(data.raw.inserter["bulk-inserter"])
  arm.name = N.ARM
  arm.allow_custom_vectors = true
  arm.chases_belt_items = false
  arm.uses_inserter_stack_size_bonus = false
  arm.stack_size_bonus = 11
  arm.bulk = true
  arm.rotation_speed = 0.5
  arm.extension_speed = 1
  arm.energy_source = { type = "void" }
  arm.energy_per_movement = "1J"
  arm.energy_per_rotation = "1J"
  arm.collision_mask = { layers = {} }
  arm.filter_count = N.ARM_FILTERS
  arm.draw_held_item = false
  arm.draw_inserter_arrow = false
  for _, field in ipairs({ "platform_picture", "hand_base_picture", "hand_open_picture", "hand_closed_picture",
    "hand_base_shadow", "hand_open_shadow", "hand_closed_shadow" }) do
    arm[field] = table.deepcopy(empty)
  end
  hide(arm, false)

  local store = table.deepcopy(data.raw.container["steel-chest"])
  store.name = N.STORE
  store.inventory_size = N.STORE_SLOTS
  store.collision_mask = { layers = {} }
  store.se_allow_in_space = true
  store.picture = table.deepcopy(empty)
  store.draw_circuit_wires = false
  store.draw_copper_wires = false
  hide(store, true)

  return { arm, store }
end

return M
