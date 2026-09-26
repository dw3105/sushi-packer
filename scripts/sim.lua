-- U-8: Factoriopedia + tips simulation scene. Lane 018 (task 018) fills.
local M = {}
local N = require("scripts.names")

-- kind: "factoriopedia" | "tips". Builds scene on game.surfaces[1]; called from simulation init via
-- remote.call(N.SIM_INTERFACE, "scene", kind).
function M.scene(kind)
  local zoom
  if kind == "factoriopedia" then
    zoom = 1.8
  elseif kind == "tips" then
    zoom = 1.4
  else
    error("unknown simulation scene: " .. tostring(kind))
  end

  local surface = game.surfaces[1]
  local force = game.forces.player
  local east = defines.direction.east
  local function position(x) return { x + 0.5, 0.5 } end
  local function create(name, x, extra)
    local spec = { name = name, position = position(x), force = force }
    for key, value in pairs(extra or {}) do spec[key] = value end
    return surface.create_entity(spec)
  end

  force.belt_stack_size_bonus = 3

  local source = create("infinity-chest", -5)
  for i, name in ipairs({ "iron-plate", "copper-plate", "iron-gear-wheel", "electronic-circuit" }) do
    source.set_infinity_container_filter(i, { name = name, count = 50, mode = "exactly" })
  end
  create("loader-1x1", -4, { direction = east, type = "output" })  -- create_entity loader param is `type`
  for x = -3, -1 do create("transport-belt", x, { direction = east }) end
  create(N.placer("yellow"), 0, { direction = east, raise_built = true })
  for x = 1, 3 do create("transport-belt", x, { direction = east }) end
  create("loader-1x1", 4, { direction = east, type = "input" })
  local sink = create("infinity-chest", 5)
  sink.remove_unfiltered_items = true  -- entity property, not a create_entity param

  if game.simulation then  -- nil outside a simulation (in-game test world)
    game.simulation.camera_position = { 0.5, 0.5 }
    game.simulation.camera_zoom = zoom
  end
end

return M
