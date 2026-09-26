local N = require("scripts.names")

local function setup()
  package.loaded["scripts.sim"] = nil
  local created, filters = {}, {}
  local force = {}
  local surface = {}
  function surface.create_entity(spec)
    created[#created + 1] = spec
    return {
      valid = true,
      name = spec.name,
      set_infinity_container_filter = function(i, filter)
        filters[#filters + 1] = { index = i, filter = filter }
      end,
    }
  end
  game = { surfaces = { [1] = surface }, forces = { player = force }, simulation = {} }
  defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
  return require("scripts.sim"), created, filters, force, game
end

local function count_name(created, name)
  local n = 0
  for _, spec in ipairs(created) do if spec.name == name then n = n + 1 end end
  return n
end

describe("sim", function()
  it("builds belts box and feed", function()
    local sim, created = setup()
    sim.scene("factoriopedia")
    eq(count_name(created, "loader-1x1"), 2, "loaders")
    eq(count_name(created, "transport-belt"), 6, "belts")
    eq(count_name(created, N.placer("yellow")), 1, "box")
    local by_x = {}
    for _, spec in ipairs(created) do by_x[spec.position[1]] = spec end
    eq(by_x[-4.5].name, "infinity-chest", "source")
    eq(by_x[-3.5].loader_type, "output", "source loader")
    eq(by_x[4.5].loader_type, "input", "sink loader")
    eq(by_x[5.5].name, "infinity-chest", "sink")
    for x = -5, 5 do eq(by_x[x + 0.5].position, { x + 0.5, 0.5 }, "position x=" .. x) end
  end)

  it("sets belt stack bonus", function()
    local sim, _, _, force = setup()
    sim.scene("factoriopedia")
    eq(force.belt_stack_size_bonus, 3)
  end)

  it("source chest holds four item kinds", function()
    local sim, created, filters = setup()
    sim.scene("factoriopedia")
    eq(created[1].name, "infinity-chest")
    local got = {}
    for _, call in ipairs(filters) do
      got[call.index] = call.filter
    end
    eq(got, {
      [1] = { name = "iron-plate", count = 50, mode = "exactly" },
      [2] = { name = "copper-plate", count = 50, mode = "exactly" },
      [3] = { name = "iron-gear-wheel", count = 50, mode = "exactly" },
      [4] = { name = "electronic-circuit", count = 50, mode = "exactly" },
    })
  end)

  it("sink chest removes everything", function()
    local sim, created = setup()
    sim.scene("tips")
    local sink = created[#created]
    eq(sink.name, "infinity-chest")
    eq(sink.remove_unfiltered_items, true)
  end)

  it("box built through placer with raise_built", function()
    local sim, created = setup()
    sim.scene("factoriopedia")
    local box
    for _, spec in ipairs(created) do if spec.name == N.placer("yellow") then box = spec end end
    ok(box ~= nil, "yellow placer missing")
    eq(box.direction, defines.direction.east)
    eq(box.raise_built, true)
    eq(box.position, { 0.5, 0.5 })
  end)

  it("factoriopedia and tips differ only in camera", function()
    local sim, created, _, _, g = setup()
    sim.scene("factoriopedia")
    eq(g.simulation.camera_position, { 0.5, 0.5 })
    eq(g.simulation.camera_zoom, 1.8)
    local first = created
    sim, created, _, _, g = setup()
    sim.scene("tips")
    eq(g.simulation.camera_position, { 0.5, 0.5 })
    eq(g.simulation.camera_zoom, 1.4)
    eq(created, first, "scene entity specs")
  end)

  it("unknown kind errors", function()
    local sim = setup()
    local success = pcall(function() sim.scene("other") end)
    eq(success, false)
  end)
end)
