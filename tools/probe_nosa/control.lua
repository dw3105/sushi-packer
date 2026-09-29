-- FND-0025 probe: belt stacking with/without space-age mod. Standalone mod "sp-probe" (not sushi-packer).
local function one(s, f, bonus, x)
  f.belt_stack_size_bonus = bonus
  local b = s.create_entity{name = "transport-belt", position = {x + 0.5, 0.5}, direction = defines.direction.north, force = f}
  local line = b.get_transport_line(1)
  local ins = line.insert_at_back({name = "iron-plate", count = 4}, 4)
  local counts = {}
  for _, d in pairs(line.get_detailed_contents()) do counts[#counts + 1] = d.stack.count end
  return "bonus=" .. bonus .. " insert=" .. tostring(ins) .. " belt_items=[" .. table.concat(counts, ",") .. "]"
end
local function run()
  local s = game.create_surface("sp-probe")
  s.request_to_generate_chunks({0, 0}, 1); s.force_generate_chunk_requests()
  local tiles = {}
  for x = -4, 4 do for y = -4, 4 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
  s.set_tiles(tiles)
  for _, e in pairs(s.find_entities_filtered{area = {{-4, -4}, {4, 4}}}) do e.destroy() end
  local mods = {}
  for n in pairs(script.active_mods) do mods[#mods + 1] = n end
  table.sort(mods)
  local f = game.forces.player
  log("SP-PROBE mods=" .. table.concat(mods, ",") .. " | " .. one(s, f, 0, -2) .. " | " .. one(s, f, 3, 2))
end
script.on_event(defines.events.on_tick, function()
  if storage.done then return end
  storage.done = true
  local ok, err = pcall(run)
  if not ok then log("SP-PROBE ERROR " .. tostring(err)) end
end)
