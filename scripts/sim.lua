-- U-8: Factoriopedia + tips simulation scene.
local M = {}
local N = require("scripts.names")

M._CAMERA = {
  factoriopedia = { position = { 0.5, 0.5 }, zoom = 2.0 },
  tips = { position = { 0.5, 0.5 }, zoom = 2.4 },
}

-- kind: "factoriopedia" | "tips". Builds scene on game.surfaces[1]; called from simulation init via
-- remote.call(N.SIM_INTERFACE, "scene", kind).
function M.scene(kind)
  local camera = M._CAMERA[kind]
  if not camera then error("unknown simulation scene: " .. tostring(kind)) end

  local surface = game.surfaces[1]
  local force = game.forces.player
  local direction = defines.direction
  local function position(x, y) return { x + 0.5, y + 0.5 } end
  local function create(name, x, y, extra)
    local spec = { name = name, position = position(x, y), force = force }
    for key, value in pairs(extra or {}) do spec[key] = value end
    return surface.create_entity(spec)
  end

  force.belt_stack_size_bonus = 3
  force.inserter_stack_size_bonus = 0

  local sources = {
    { x = -15, y = -2, item = "iron-plate" },
    { x = -13, y = -2, item = "copper-plate" },
    { x = -16, y = 2, item = "coal" },
    { x = -14, y = 2, item = "electronic-circuit" },
  }
  for _, source in ipairs(sources) do
    local chest = create("infinity-chest", source.x, source.y)
    chest.set_infinity_container_filter(1, { name = source.item, count = 50, mode = "exactly" })
  end

  create("inserter", -15, -1, { direction = direction.north })
  create("inserter", -13, -1, { direction = direction.north })
  create("inserter", -16, 1, { direction = direction.south })
  create("inserter", -14, 1, { direction = direction.south })
  create("medium-electric-pole", -12, -1)
  create("medium-electric-pole", -12, -9)
  local power = create("electric-energy-interface", -12, -10)
  power.power_production = 1e9
  power.electric_buffer_size = 1e9
  power.energy = 1e9

  for x = -17, -1 do create("transport-belt", x, 0, { direction = direction.east }) end
  create(N.placer("yellow"), 0, 0, { direction = direction.east, raise_built = true })
  for x = 1, 11 do create("transport-belt", x, 0, { direction = direction.east }) end
  create("loader-1x1", 12, 0, { direction = direction.east, type = "input" })
  local sink = create("infinity-chest", 13, 0)
  sink.remove_unfiltered_items = true

  if game.simulation then  -- nil outside a simulation (in-game test world)
    game.simulation.camera_position = camera.position
    game.simulation.camera_zoom = camera.zoom
  end
end

return M
