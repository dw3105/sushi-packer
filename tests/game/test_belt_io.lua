local N = require("scripts.names")
local io = require("scripts.belt_io")

local vectors = {
  north = { x = 0, y = -1 }, east = { x = 1, y = 0 },
  south = { x = 0, y = 1 }, west = { x = -1, y = 0 },
}
local dirs = { north = defines.direction.north, east = defines.direction.east,
  south = defines.direction.south, west = defines.direction.west }
local opposite = { north = "south", east = "west", south = "north", west = "east" }

describe("belt_io", function()
  local surface, force
  local function create(name, x, y, direction, extra)
    local spec = { name = name, position = { x = x + 0.5, y = y + 0.5 }, direction = direction, force = force }
    if extra then for k, v in pairs(extra) do spec[k] = v end end
    return surface.create_entity(spec)
  end
  local function setup(dir)
    dir = dir or "north"
    local d, v = dirs[dir], vectors[dir]
    local bx, by = 0, 0
    local box = create(N.variant("yellow", dir), bx, by, d)
    local behind = create("transport-belt", bx - v.x, by - v.y, d)
    local front = create("transport-belt", bx + v.x, by + v.y, d)
    return { entity = box, dir = dir }, behind, front
  end
  before_each(function()
    surface, force = game.surfaces[1], game.forces.player
    for _, e in ipairs(surface.find_entities_filtered({ area = { { -5, -5 }, { 5, 5 } } })) do
      if e.valid and e.type ~= "character" then e.destroy() end
    end
    force.belt_stack_size_bonus = 0
  end)

  it("behind finds belt moving into box", function()
    local rec, belt = setup("north")
    assert.are_equal(belt, io.behind(rec.entity, rec.dir))
  end)
  it("behind ignores belt moving away", function()
    local rec, initial = setup("north")
    initial.destroy()
    local wrong = create("transport-belt", 0, 1, defines.direction.south)
    assert.is_nil(io.behind(rec.entity, rec.dir))
    assert.is_true(wrong.valid)
  end)
  it("behind accepts underground output", function()
    local rec, initial = setup("north")
    initial.destroy()
    local belt = create("underground-belt", 0, 1, defines.direction.north, { type = "output" })
    assert.are_equal(belt, io.behind(rec.entity, rec.dir))
  end)
  it("front finds belt not facing back", function()
    local rec, _, belt = setup("north")
    assert.are_equal(belt, io.front(rec.entity, rec.dir))
  end)
  it("front ignores belt facing box", function()
    local rec, _, initial = setup("north")
    initial.destroy()
    create("transport-belt", 0, -1, defines.direction.south)
    assert.is_nil(io.front(rec.entity, rec.dir))
  end)

  it("push inserts stacked item on matching lane", function()
    local rec, _, belt = setup("north")
    force.belt_stack_size_bonus = 3
    local n = io.push(rec, 2, { name = "iron-plate", quality = "normal", count = 4 }, 4)
    assert.are_equal(4, n)
    local contents = belt.get_transport_line(2).get_detailed_contents()
    assert.are_equal(1, #contents); assert.are_equal(4, contents[1].stack.count)
  end)
  it("push returns zero when front blocked", function()
    local rec, _, belt = setup("north")
    local line = belt.get_transport_line(1)
    for _ = 1, 32 do
      if not line.can_insert_at_back() then break end
      assert.is_true(line.insert_at_back({ name = "iron-plate", count = 1 }, 1))
    end
    assert.is_true(not line.can_insert_at_back())
    assert.are_equal(0, io.push(rec, 1, { name = "copper-plate", quality = "normal", count = 1 }, 1))
  end)
  it("push returns zero without front belt", function()
    local rec, _, initial = setup("north")
    initial.destroy()
    assert.are_equal(0, io.push(rec, 1, { name = "iron-plate", quality = "normal", count = 1 }, 1))
  end)
  it("belt stack size follows research capped at engine max", function()
    -- O-3 v7 (author 2026-09-27): cap = utility constant max_belt_stack_size (test env mod: 20), never literal 4.
    local max = prototypes.utility_constants.max_belt_stack_size
    force.belt_stack_size_bonus = 0; assert.are_equal(1, io.belt_stack_size(force))
    force.belt_stack_size_bonus = 5; assert.are_equal(6, io.belt_stack_size(force))
    force.belt_stack_size_bonus = max + 5; assert.are_equal(max, io.belt_stack_size(force))
    force.belt_stack_size_bonus = 3
  end)
  it("works in all four directions", function()
    for _, dir in ipairs(N.DIRS) do
      local rec, behind, front = setup(dir)
      assert.are_equal(behind, io.behind(rec.entity, rec.dir), dir .. " input")
      assert.are_equal(front, io.front(rec.entity, rec.dir), dir .. " output")
      behind.destroy(); front.destroy(); rec.entity.destroy()
    end
  end)
end)
