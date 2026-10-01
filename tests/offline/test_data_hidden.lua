local N = require("scripts.names")

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[copy(k)] = copy(v) end
  return out
end

local function fixture()
  local arm = {
    type = "inserter", name = "bulk-inserter", icon = "arm.png", icon_size = 64,
    minable = { mining_time = 0.1 }, next_upgrade = "stack-inserter", fast_replaceable_group = "inserter",
    platform_picture = { filename = "platform.png", size = 64 },
    hand_base_picture = { filename = "base.png", size = 64 },
    hand_open_picture = { filename = "open.png", size = 64 },
    hand_closed_picture = { filename = "closed.png", size = 64 },
    hand_base_shadow = { filename = "base-shadow.png", size = 64 },
    hand_open_shadow = { filename = "open-shadow.png", size = 64 },
    hand_closed_shadow = { filename = "closed-shadow.png", size = 64 },
  }
  local store = {
    type = "container", name = "steel-chest", icon = "chest.png", icon_size = 64,
    minable = { mining_time = 0.2 }, next_upgrade = "logistic-chest-storage", fast_replaceable_group = "container",
    picture = { filename = "chest.png", size = 64 }, draw_circuit_wires = true, draw_copper_wires = true,
    circuit_connector = { { wire = { red = { 1, 2 } } } }, circuit_wire_max_distance = 9,
  }
  _G.data = { raw = { inserter = { ["bulk-inserter"] = arm }, container = { ["steel-chest"] = store } } }
  table.deepcopy = copy
  return arm, store
end

local function parts()
  fixture()
  return require("prototypes.hidden").make()
end

local function has_flag(p, name)
  for _, flag in ipairs(p.flags or {}) do if flag == name then return true end end
  return false
end

local empty = { filename = "__core__/graphics/empty.png", size = 1 }

describe("data hidden", function()
  it("makes arm and store", function()
    local result = parts()
    eq(#result, 3)
    eq({ result[1].type, result[1].name }, { "inserter", N.ARM })
    eq({ result[2].type, result[2].name }, { "container", N.STORE })
    eq({ result[3].type, result[3].name }, { "inserter", N.OUT })
  end)

  it("arm fields", function()
    local result = parts()
    local arm = result[1]
    eq(arm.allow_custom_vectors, true)
    eq(arm.chases_belt_items, false)
    eq(arm.uses_inserter_stack_size_bonus, false)
    eq(arm.stack_size_bonus, N.ARM_HAND - 1)
    eq(arm.bulk, true)
    eq(arm.rotation_speed, 0.5)
    eq(arm.extension_speed, 1)
    eq(arm.energy_source, { type = "void" })
    eq(arm.energy_per_movement, "1J")
    eq(arm.energy_per_rotation, "1J")
    eq(arm.collision_mask, { layers = {} })
    eq(arm.filter_count, N.ARM_FILTERS)
  end)

  it("store fields", function()
    local store = parts()[2]
    eq(store.inventory_size, N.STORE_SLOTS)
    eq(store.collision_mask, { layers = {} })
    eq(store.se_allow_in_space, true)
  end)

  it("parts are hidden and untouchable", function()
    local result = parts()
    for _, p in ipairs(result) do
      eq(p.hidden, true); eq(p.hidden_in_factoriopedia, true); eq(p.selectable_in_game, false)
      eq(p.minable, nil); eq(p.next_upgrade, nil); eq(p.fast_replaceable_group, nil); eq(p.placeable_by, nil)
      eq(p.allow_copy_paste, false)
      for _, flag in ipairs({ "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable",
        "not-upgradable", "not-flammable", "not-in-kill-statistics" }) do ok(has_flag(p, flag), "missing " .. flag) end
      for _, field in ipairs({ "corpse", "dying_explosion", "open_sound", "close_sound", "working_sound" }) do eq(p[field], nil, field) end
    end
    ok(has_flag(result[2], "no-automated-item-insertion"), "store missing no-automated-item-insertion")
    ok(not has_flag(result[2], "no-automated-item-removal"), "v16: out arms must be able to take from store")
  end)

  it("parts draw nothing", function()
    local result = parts()
    local arm, store = result[1], result[2]
    eq(arm.draw_held_item, false); eq(arm.draw_inserter_arrow, false)
    for _, field in ipairs({ "platform_picture", "hand_base_picture", "hand_open_picture", "hand_closed_picture",
      "hand_base_shadow", "hand_open_shadow", "hand_closed_shadow" }) do
      if arm[field] ~= nil then eq(arm[field], empty, field) end
    end
    eq(store.picture, empty)
    eq(store.draw_circuit_wires, false); eq(store.draw_copper_wires, false)
    ok(store.circuit_connector ~= nil)
    ok(store.circuit_wire_max_distance > 0)
  end)

  it("out arm stacks only with space travel flag", function()
    _G.feature_flags = { space_travel = false }
    local out = parts()[3]
    eq(out.max_belt_stack_size, nil); eq(out.wait_for_full_hand, nil)
    eq(out.stack_size_bonus, N.MAX_BELT_STACK - 1)
    eq(out.filter_count, N.ARM_FILTERS); eq(out.allow_custom_vectors, true); eq(out.collision_mask, { layers = {} })
    _G.feature_flags = { space_travel = true }
    out = parts()[3]
    eq(out.max_belt_stack_size, N.MAX_BELT_STACK); eq(out.wait_for_full_hand, true); eq(out.grab_less_to_match_belt_stack, true)
    _G.feature_flags = nil
  end)

  it("finalize widens out arm hand to engine max belt stack", function()
    _G.feature_flags = { space_travel = true }
    local out = parts()[3]
    local raw = { inserter = { [N.OUT] = out }, ["utility-constants"] = { default = { max_belt_stack_size = 20 } } }
    require("prototypes.hidden").finalize(raw)
    eq(out.stack_size_bonus, 19); eq(out.max_belt_stack_size, 20)
    raw["utility-constants"].default.max_belt_stack_size = 2
    require("prototypes.hidden").finalize(raw)
    eq(out.stack_size_bonus, N.MAX_BELT_STACK - 1, "never below default hand")
    _G.feature_flags = { space_travel = false }
    local plain = parts()[3]
    require("prototypes.hidden").finalize({ inserter = { [N.OUT] = plain }, ["utility-constants"] = { default = { max_belt_stack_size = 20 } } })
    eq(plain.max_belt_stack_size, nil)
    _G.feature_flags = nil
  end)

  it("out arm swing follows belt speed", function()
    -- 8 arms, one swing = T ticks: 8 * 60 / T belt stacks per second per lane >= 1.6 x lane rate (speed * 240)
    eq(N.out_swing(0.03125), 40); eq(N.out_swing(0.0625), 20); eq(N.out_swing(0.09375), 12); eq(N.out_swing(0.125), 10)
    eq(N.out_swing(0.1875), 6); eq(N.out_swing(0.5625), 2); eq(N.out_swing(2), 2); eq(N.out_swing(0.001), 60)
    eq(N.out_name(0.125), N.OUT .. "-10")
  end)

  it("finalize makes one out arm per tier belt speed", function()
    _G.feature_flags = { space_travel = true }
    local out = parts()[3]
    local raw = { inserter = { [N.OUT] = out }, ["utility-constants"] = { default = { max_belt_stack_size = 4 } },
      ["transport-belt"] = { [N.TIER.yellow.belt] = { speed = 0.03125 }, [N.TIER.turbo.belt] = { speed = 0.125 } } }
    require("prototypes.hidden").finalize(raw)
    local y, t = raw.inserter[N.OUT .. "-40"], raw.inserter[N.OUT .. "-10"]
    ok(y ~= nil and t ~= nil, "per-speed prototypes made")
    eq(y.name, N.OUT .. "-40"); eq(y.rotation_speed, 0.5 / 21); eq(t.rotation_speed, 0.5 / 6)
    eq(y.max_belt_stack_size, 4); eq(y.stack_size_bonus, 3); eq(y.hidden, true)
    eq(raw.inserter[N.OUT .. "-20"], nil, "red belt prototype absent in this fixture: no arm for it")
    ok(raw.inserter[N.OUT] == out and out.rotation_speed == 0.5, "base out arm kept as fast fallback")
    _G.feature_flags = nil
  end)

  it("source prototypes untouched", function()
    local arm, store = fixture()
    local before_arm, before_store = copy(arm), copy(store)
    require("prototypes.hidden").make()
    eq(arm, before_arm); eq(store, before_store)
  end)
end)
