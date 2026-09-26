local N = require("scripts.names")
local M = {}

-- Each cell uses a westbound belt through the box. Loaders and infinity chests
-- sit at the two ends of the straight run.
function M.build(surface, force, n, origin)
  local positions = {}
  local ox, oy = origin[1] or origin.x or 0, origin[2] or origin.y or 0
  local cols = 20
  for i = 1, n do
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    local x, y = ox + 10 + col * 12, oy + 10 + row * 12
    local names = { "iron-plate", "copper-plate", "iron-gear-wheel", "electronic-circuit", "coal" }
    local source = surface.create_entity({ name = "infinity-chest", position = { x + 9.5, y - 0.5 }, force = force })
    local source_filters = {}
    local sink_filters = {}
    for slot, name in ipairs(names) do
      source_filters[slot] = { index = slot, name = name, count = 1000000, mode = "at-least" }
      sink_filters[slot] = { index = slot, name = name, count = 0, mode = "at-most" }
    end
    source.infinity_container_filters = source_filters
    for bx = x + 6, x + 8 do
      surface.create_entity({ name = "transport-belt", position = { bx + 0.5, y + 0.5 }, direction = defines.direction.west, force = force })
    end
    for bx = x + 1, x + 4 do
      surface.create_entity({ name = "transport-belt", position = { bx + 0.5, y + 0.5 }, direction = defines.direction.west, force = force })
    end
    surface.create_entity({ name = "loader", position = { x + 9.5, y + 0.5 }, direction = defines.direction.west, force = force, type = "output" })
    surface.create_entity({ name = "loader", position = { x + 0.5, y + 0.5 }, direction = defines.direction.west, force = force, type = "input" })
    local sink = surface.create_entity({ name = "infinity-chest", position = { x + 0.5, y - 0.5 }, force = force })
    sink.infinity_container_filters = sink_filters
    -- Prime the transport lanes with a mixed sample while the loader brings in the continuous supply.
    local input_belt = surface.find_entity("transport-belt", { x + 6.5, y + 0.5 })
    for lane = 1, 2 do
      local line = input_belt.get_transport_line(lane)
      for _, name in ipairs(names) do line.insert_at_back({ name = name, count = 1 }) end
    end
    local placer = surface.create_entity({ name = N.placer("yellow"), position = { x + 5.5, y + 0.5 }, direction = defines.direction.west, force = force, raise_built = true })
    positions[#positions + 1] = { x = x + 5.5, y = y + 0.5 }
  end
  return positions
end

return M
