-- Test-only (staged by tools/stage.sh test mode, never in release zip): modded engine max belt stack.
-- 20 = author save 2026-09-27.
data.raw["utility-constants"]["default"].max_belt_stack_size = 20
-- Test-only fast belts (v9 S0 probe P2 + modded-tier tests): 90, 135, 270 items/s (speed x 480).
for _, t in ipairs({ { "sp-test-belt-90", 0.1875 }, { "sp-test-belt-135", 0.28125 }, { "sp-test-belt-270", 0.5625 } }) do
  local b = table.deepcopy(data.raw["transport-belt"]["express-transport-belt"])
  b.name, b.speed, b.next_upgrade, b.related_underground_belt = t[1], t[2], nil, nil
  b.minable = nil
  data:extend({ b })
end
-- Test-only loader (v14 S0 feed probe): 1x1, never slower than any test belt, may stack on belt.
do
  local l = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
  l.name, l.speed, l.max_belt_stack_size, l.adjustable_belt_stack_size = "sp-test-loader", 1, 4, true
  l.minable, l.next_upgrade = nil, nil
  data:extend({ l })
end
-- Test-only (v14 rung 2 probes, FND-0039): engine movers. Two 1x1 loaders reaching a chest on their own tile,
-- output loader waits for full belt stacks, optional per-lane filters; chest without collision.
do
  local function loader(name, fields)
    local l = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
    l.name, l.speed, l.minable, l.next_upgrade = name, 1, nil, nil
    l.container_distance = 0
    l.max_belt_stack_size, l.adjustable_belt_stack_size = 4, true
    for k, v in pairs(fields) do l[k] = v end
    data:extend({ l })
  end
  -- Engine rule (probe 2026-10-01): every belt-connectable must collide with every other one -> one loader per tile.
  loader("sp-test-r2-in", {})
  loader("sp-test-r2-out", { wait_for_full_stack = true })
  local c = table.deepcopy(data.raw.container["steel-chest"])
  c.name, c.minable, c.next_upgrade = "sp-test-r2-chest", nil, nil
  c.collision_mask = { layers = {} }
  data:extend({ c })
end
-- Test-only (v14 P1 probes, Way A "arms"): hidden inserter that may be locked to one belt lane at runtime
-- (LuaEntity.pickup_from_left_lane / pickup_from_right_lane). Settings after Miniloader Redux prototypes/functions.lua.
do
  local a = table.deepcopy(data.raw.inserter["bulk-inserter"])
  a.name, a.minable, a.next_upgrade = "sp-test-arm", nil, nil
  a.allow_custom_vectors, a.chases_belt_items = true, false
  a.uses_inserter_stack_size_bonus, a.stack_size_bonus, a.bulk = false, 11, true
  a.rotation_speed, a.extension_speed = 0.5, 1
  a.energy_source = { type = "void" }
  a.energy_per_movement, a.energy_per_rotation = "1J", "1J"
  a.collision_mask = { layers = {} }
  a.flags = { "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable" }
  a.filter_count = 0
  data:extend({ a })
  for _, s in ipairs({ 0.5625, 2, 4 }) do
    local l = table.deepcopy(data.raw["loader-1x1"]["sp-test-r2-in"])
    l.name, l.speed = "sp-test-r2-in-" .. tostring(s):gsub("%.", "_"), s
    data:extend({ l })
  end
end
