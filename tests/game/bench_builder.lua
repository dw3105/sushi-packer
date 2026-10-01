local N = require("scripts.names")
local M = {}

local ITEMS = { "iron-plate", "copper-plate", "iron-gear-wheel", "electronic-circuit", "coal" }

local function next_random(state)
  return (state * 48271) % 2147483647
end

function M.plan(seed, i)
  local state = (math.floor(seed or 1) * 104729 + math.floor(i or 1) * 13007 + 1) % 2147483647
  if state == 0 then state = 1 end
  local items = { ITEMS[1], ITEMS[2], ITEMS[3], ITEMS[4], ITEMS[5] }
  local sizes = { 1, 2, 3, 4 }
  for j = #items, 2, -1 do
    state = next_random(state)
    local k = state % j + 1
    items[j], items[k] = items[k], items[j]
  end
  for j = #sizes, 2, -1 do
    state = next_random(state)
    local k = state % j + 1
    sizes[j], sizes[k] = sizes[k], sizes[j]
  end
  local result = {}
  for j = 1, 4 do result[j] = { item = items[j], size = sizes[j] } end
  return result
end

function M.build(surface, force, n, origin, opts)
  opts = opts or {}
  local tier = opts.tier or "yellow"
  local flow = opts.flow or "single"
  if not N.TIER[tier] then error("bench_builder: unknown tier " .. tostring(tier)) end
  if flow ~= "single" and flow ~= "stacks" then error("bench_builder: unknown flow " .. tostring(flow)) end
  local belt = N.TIER[tier].belt
  local loader = opts.loader or (tier == "yellow" and flow == "single" and "loader-1x1" or "sushi-packer-bench-loader")
  local positions = {}
  local ox, oy = origin[1] or origin.x or 0, origin[2] or origin.y or 0
  local cols = 20
  local pitch = flow == "stacks" and 16 or 12
  for i = 1, n do
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    local x, y = ox + 10 + col * pitch, oy + 10 + row * 12
    if flow == "single" then
      local names = ITEMS
      local source = surface.create_entity({ name = "infinity-chest", position = { x + 10.5, y + 0.5 }, force = force })
      local source_filters, sink_filters = {}, {}
      for slot, name in ipairs(names) do
        source_filters[slot] = { index = slot, name = name, count = 1000000, mode = "at-least" }
        sink_filters[slot] = { index = slot, name = name, count = 0, mode = "at-most" }
      end
      source.infinity_container_filters = source_filters
      for bx = x + 6, x + 8 do
        surface.create_entity({ name = belt, position = { bx + 0.5, y + 0.5 }, direction = defines.direction.west, force = force })
      end
      for bx = x + 1, x + 4 do
        surface.create_entity({ name = belt, position = { bx + 0.5, y + 0.5 }, direction = defines.direction.west, force = force })
      end
      surface.create_entity({ name = loader, position = { x + 9.5, y + 0.5 }, direction = defines.direction.west, force = force, type = "output" })
      surface.create_entity({ name = loader, position = { x + 0.5, y + 0.5 }, direction = defines.direction.west, force = force, type = "input" })
      local sink = surface.create_entity({ name = "infinity-chest", position = { x - 0.5, y + 0.5 }, force = force })
      sink.infinity_container_filters = sink_filters
      local input_belt = surface.find_entity(belt, { x + 6.5, y + 0.5 })
      for lane = 1, 2 do
        local line = input_belt.get_transport_line(lane)
        for _, name in ipairs(names) do line.insert_at_back({ name = name, count = 1 }) end
      end
    else
      for bx = x + 6, x + 8 do surface.create_entity({ name = belt, position = { bx + 0.5, y + 0.5 }, direction = defines.direction.west, force = force }) end
      local plan = M.plan(opts.seed or 1, i)
      local splitter = N.TIER[tier].splitter
      surface.create_entity({ name = splitter, position = { x + 9.5, y + 1 }, direction = defines.direction.west, force = force })
      surface.create_entity({ name = belt, position = { x + 10.5, y + 0.5 }, direction = defines.direction.west, force = force })
      surface.create_entity({ name = belt, position = { x + 10.5, y + 1.5 }, direction = defines.direction.west, force = force })
      surface.create_entity({ name = splitter, position = { x + 11.5, y + 0 }, direction = defines.direction.west, force = force })
      surface.create_entity({ name = splitter, position = { x + 11.5, y + 2 }, direction = defines.direction.west, force = force })
      for row_index = 1, 4 do
        local yy = y - 0.5 + (row_index - 1)
        local output = surface.create_entity({ name = loader, position = { x + 12.5, yy }, direction = defines.direction.west, force = force, type = "output" })
        output.loader_belt_stack_size_override = plan[row_index].size
        local chest = surface.create_entity({ name = "infinity-chest", position = { x + 13.5, yy }, force = force })
        chest.infinity_container_filters = { { index = 1, name = plan[row_index].item, count = 1000, mode = "at-least" } }
      end
    end
    if flow == "stacks" then
      for bx = x + 1, x + 4 do surface.create_entity({ name = belt, position = { bx + 0.5, y + 0.5 }, direction = defines.direction.west, force = force }) end
      surface.create_entity({ name = loader, position = { x + 0.5, y + 0.5 }, direction = defines.direction.west, force = force, type = "input" })
      local sink = surface.create_entity({ name = "infinity-chest", position = { x - 0.5, y + 0.5 }, force = force })
      local sink_filters = {}
      for slot, name in ipairs(ITEMS) do sink_filters[slot] = { index = slot, name = name, count = 0, mode = "at-most" } end
      sink.infinity_container_filters = sink_filters
    end
    local placer = surface.create_entity({ name = N.placer(tier), position = { x + 5.5, y + 0.5 }, direction = defines.direction.west, force = force, raise_built = true })
    positions[#positions + 1] = { x = x + 5.5, y = y + 0.5 }
  end
  return positions
end

return M
