local N = require("scripts.names")

local function setup()
  package.loaded["scripts.sim"] = nil
  local created, filters = {}, {}
  local force = {}
  local surface = {}
  function surface.create_entity(spec)
    created[#created + 1] = spec
    local entity = {
      valid = true,
      name = spec.name,
      set_infinity_container_filter = function(i, filter)
        filters[#filters + 1] = { entity = spec, index = i, filter = filter }
      end,
    }
    spec.entity = entity
    return entity
  end
  game = { surfaces = { [1] = surface }, forces = { player = force }, simulation = {} }
  defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
  return require("scripts.sim"), created, filters, force, game
end

local function find(created, name, position)
  for _, spec in ipairs(created) do
    if spec.name == name and (not position or
      (spec.position[1] == position[1] and spec.position[2] == position[2])) then return spec end
  end
end

describe("sim", function()
  it("four infinity chests two above two below", function()
    local sim, created, filters = setup()
    sim.scene("factoriopedia")
    local expected = {
      { "iron-plate", { -3.5, -1.5 } }, { "copper-plate", { -1.5, -1.5 } },
      { "coal", { -3.5, 2.5 } }, { "electronic-circuit", { -1.5, 2.5 } },
    }
    local sources = {}
    for _, item in ipairs(expected) do
      local chest = find(created, "infinity-chest", item[2])
      ok(chest ~= nil, "missing chest " .. item[1])
      sources[chest] = true
      local filter
      for _, call in ipairs(filters) do if call.entity == chest and call.index == 1 then filter = call.filter end end
      eq(filter, { name = item[1], count = 50, mode = "exactly" })
    end
    local source_count = 0
    for _ in pairs(sources) do source_count = source_count + 1 end
    eq(source_count, 4)
  end)

  it("inserters between chests and belt", function()
    local sim, created = setup()
    sim.scene("factoriopedia")
    local expected = {
      { { -3.5, -0.5 }, defines.direction.north }, { { -1.5, -0.5 }, defines.direction.north },
      { { -3.5, 1.5 }, defines.direction.south }, { { -1.5, 1.5 }, defines.direction.south },
    }
    local got = {}
    for _, spec in ipairs(created) do if spec.name == "inserter" then got[#got + 1] = { spec.position, spec.direction } end end
    eq(got, expected)
  end)

  it("visible pole and hidden power", function()
    local sim, created = setup()
    sim.scene("factoriopedia")
    local poles = {}
    for _, spec in ipairs(created) do if spec.name == "medium-electric-pole" then poles[#poles + 1] = spec end end
    eq(#poles, 2)
    eq(poles[1].position, { -2.5, -0.5 })
    eq(poles[2].position, { -2.5, -8.5 })
    local eei = find(created, "electric-energy-interface", { -2.5, -9.5 })
    ok(eei ~= nil, "missing hidden power interface")
    eq(eei.entity.power_production, 1e9)
    eq(eei.entity.electric_buffer_size, 1e9)
    eq(eei.entity.energy, 1e9)
  end)

  it("inserter hand size one", function()
    local sim, _, _, force = setup()
    sim.scene("factoriopedia")
    eq(force.inserter_stack_size_bonus, 0)
  end)

  it("belt box and sink", function()
    local sim, created, _, force = setup()
    sim.scene("factoriopedia")
    eq(force.belt_stack_size_bonus, 3)
    eq(find(created, N.placer("yellow"), { 0.5, 0.5 }).direction, defines.direction.east)
    local box = find(created, N.placer("yellow"), { 0.5, 0.5 })
    eq(box.raise_built, true)
    local loader = find(created, "loader-1x1", { 4.5, 0.5 })
    eq(loader.direction, defines.direction.east)
    eq(loader.type, "input")
    local sink = find(created, "infinity-chest", { 5.5, 0.5 })
    eq(sink.entity.remove_unfiltered_items, true)
    local belt_count = 0
    for _, spec in ipairs(created) do
      if spec.name == "transport-belt" then
        belt_count = belt_count + 1
        eq(spec.direction, defines.direction.east)
      end
    end
    eq(belt_count, 8)
    for x = -5, -1 do ok(find(created, "transport-belt", { x + 0.5, 0.5 }) ~= nil, "missing belt x=" .. x) end
    for x = 1, 3 do ok(find(created, "transport-belt", { x + 0.5, 0.5 }) ~= nil, "missing belt x=" .. x) end
  end)

  it("camera constants per kind", function()
    local sim = setup()
    eq(sim._CAMERA, {
      factoriopedia = { position = { -0.5, 0.5 }, zoom = 2.0 },
      tips = { position = { -0.5, 0.5 }, zoom = 2.4 },
    })
    sim.scene("factoriopedia")
    eq(game.simulation.camera_position, { -0.5, 0.5 })
    eq(game.simulation.camera_zoom, 2.0)
    sim.scene("tips")
    eq(game.simulation.camera_position, { -0.5, 0.5 })
    eq(game.simulation.camera_zoom, 2.4)
  end)

  it("unknown kind errors", function()
    local sim = setup()
    eq(pcall(function() sim.scene("other") end), false)
  end)
end)
