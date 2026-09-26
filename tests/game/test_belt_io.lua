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

  it("pull keeps lanes", function()
    local rec, belt = setup("north")
    local left, right = belt.get_transport_line(1), belt.get_transport_line(2)
    assert.is_true(left.insert_at(0, { name = "iron-plate", count = 1 }))
    assert.is_true(right.insert_at(0, { name = "copper-plate", count = 1 }))
    local calls = {}
    after_ticks(1, function()
      local got = io.pull(rec, { 1, 1 }, function(name, quality, lane, count)
        calls[#calls + 1] = { name, quality, lane, count }; return count
      end)
      assert.are_equal(1, got[1]); assert.are_equal(1, got[2])
      assert.are_equal("iron-plate", calls[1][1]); assert.are_equal(1, calls[1][3])
      assert.are_equal("copper-plate", calls[2][1]); assert.are_equal(2, calls[2][3])
    end)
  end)
  it("pull takes front-most item only", function()
    local rec, belt = setup("north")
    local line = belt.get_transport_line(1)
    assert.is_true(line.insert_at(0.1, { name = "iron-plate", count = 1 }))
    assert.is_true(line.insert_at(0.6, { name = "copper-plate", count = 1 }))
    after_ticks(1, function()
      local name
      local got = io.pull(rec, { 1, 0 }, function(n) name = n; return 1 end)
      assert.are_equal(1, got[1]); assert.are_equal("iron-plate", name)
      local rest = line.get_detailed_contents(); assert.are_equal(1, #rest)
      assert.are_equal("copper-plate", rest[1].stack.name)
    end)
  end)
  it("pull ignores items not at belt end", function()
    local rec, belt = setup("north")
    assert.is_true(belt.get_transport_line(1).insert_at(0.7, { name = "iron-plate", count = 1 }))
    local called = false
    local got = io.pull(rec, { 1, 0 }, function() called = true; return 1 end)
    assert.are_equal(0, got[1]); assert.is_true(not called)
  end)
  it("pull respects budget", function()
    local rec, belt = setup("north")
    local line = belt.get_transport_line(1)
    assert.is_true(line.insert_at(0, { name = "iron-plate", count = 1 }))
    assert.is_true(line.insert_at(0, { name = "copper-plate", count = 1 }))
    after_ticks(1, function()
      local got = io.pull(rec, { 1, 0 }, function() return 1 end)
      assert.are_equal(1, got[1])
    end)
  end)
  it("pull removes only accepted part of stacked item", function()
    local rec, belt = setup("north")
    local line = belt.get_transport_line(1)
    assert.is_true(line.insert_at_back({ name = "iron-plate", count = 4 }, 4))
    after_ticks(1, function()
      io.pull(rec, { 1, 0 }, function(_, _, _, count) assert.are_equal(4, count); return 2 end)
      local contents = line.get_detailed_contents()
      assert.are_equal(1, #contents); assert.are_equal(2, contents[1].stack.count)
    end)
  end)
  it("pull stops lane on zero accept", function()
    local rec, belt = setup("north")
    local line = belt.get_transport_line(1)
    assert.is_true(line.insert_at(0, { name = "iron-plate", count = 1 }))
    assert.is_true(line.insert_at(0, { name = "copper-plate", count = 1 }))
    after_ticks(1, function()
      local calls = 0
      local got = io.pull(rec, { 2, 0 }, function() calls = calls + 1; return 0 end)
      assert.are_equal(0, got[1]); assert.are_equal(1, calls); assert.are_equal(2, #line.get_detailed_contents())
    end)
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
    for i = 1, 8 do assert.is_true(line.insert_at(i / 10, { name = "iron-plate", count = 1 })) end
    assert.are_equal(0, io.push(rec, 1, { name = "copper-plate", quality = "normal", count = 1 }, 1))
  end)
  it("push returns zero without front belt", function()
    local rec, _, initial = setup("north")
    initial.destroy()
    assert.are_equal(0, io.push(rec, 1, { name = "iron-plate", quality = "normal", count = 1 }, 1))
  end)
  it("belt stack size follows research capped at 4", function()
    force.belt_stack_size_bonus = 0; assert.are_equal(1, io.belt_stack_size(force))
    force.belt_stack_size_bonus = 2; assert.are_equal(3, io.belt_stack_size(force))
    force.belt_stack_size_bonus = 5; assert.are_equal(4, io.belt_stack_size(force))
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
