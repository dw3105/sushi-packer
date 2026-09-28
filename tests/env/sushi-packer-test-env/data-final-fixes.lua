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
