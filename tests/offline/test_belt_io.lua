defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
local belt_io = require("scripts.belt_io")

local function find(dir, sign, belts)
  local e = { position = { x = 0, y = 0 }, surface = {
    find_entities_filtered = function(filter)
      local p = filter.position
      if not p then return {} end  -- area query (splitter search)
      local expected = sign == 1 and { x = 0, y = -1 } or { x = 0, y = 1 }
      if p.x == expected.x and p.y == expected.y then return belts end
      return {}
    end,
  } }
  return sign == 1 and belt_io.front(e, dir) or belt_io.behind(e, dir)
end

describe("belt_io", function()
  local function eta_rec(lines, speed)
    defines = { direction = { north=0, east=4, south=8, west=12 } }; game={tick=1}
    prototypes = { entity={ ["yellow-belt"]={belt_speed=speed or 0.03125} } }
    local belt={valid=true,type="transport-belt",direction=0,name="yellow-belt"}
    function belt.get_transport_line(lane) return lines[lane] end
    local entity={valid=true,position={x=0,y=0},surface={find_entities_filtered=function() return {belt} end}}
    return {entity=entity,dir="north"}
  end
  local function eta_line(stack, exit, position, detailed)
    local line={}
    if stack then line[1]=stack end
    setmetatable(line,{__len=function() return stack and 1 or 0 end})
    function line.can_insert_at(pos) return not (pos==0 and exit) end
    function line.remove_item() end
    function line.get_detailed_contents() if detailed then detailed() end; return {{position=position or 0.5}} end
    return line
  end
  it("belt stack follows research up to engine max", function()
    -- author 2026-09-27: release at research-set belt stack, modded or not (no literal 4).
    local saved = prototypes
    prototypes = { utility_constants = { max_belt_stack_size = 8 } }
    package.loaded["scripts.belt_io"] = nil
    local io = require("scripts.belt_io")
    eq(io.belt_stack_size({ belt_stack_size_bonus = 0 }), 1)
    eq(io.belt_stack_size({ belt_stack_size_bonus = 7 }), 8)
    eq(io.belt_stack_size({ belt_stack_size_bonus = 12 }), 8)
    prototypes = saved; package.loaded["scripts.belt_io"] = nil; belt_io = require("scripts.belt_io")
  end)
  local function splitter_rec(sp_pos, lines)
    defines = { direction = { north=0, east=4, south=8, west=12 } }; game = { tick = 1 }
    prototypes = { entity = { ["turbo-splitter"] = { belt_speed = 0.125 } } }
    local sp = { valid = true, type = "splitter", direction = 0, name = "turbo-splitter", position = sp_pos }
    function sp.get_transport_line(i) return lines[i] end
    local entity = { valid = true, position = { x = 0, y = 0 }, surface = {
      find_entities_filtered = function(f) if f.area then return { sp } end return {} end } }
    return { entity = entity, dir = "north" }
  end
  it("splitter in front takes output into its input half", function()
    -- FND-0015 probe: left half in = lines 1/2, right half in = 3/4.
    local got = {}
    local lines = {}
    for i = 1, 8 do
      lines[i] = { can_insert_at_back = function() return true end,
        insert_at_back = function(item) got[#got + 1] = i .. ":" .. item.name; return true end }
    end
    local io = require("scripts.belt_io")
    io.push(splitter_rec({ x = 0.5, y = -1 }, lines), 2, { name = "coal", count = 4 }, 4)
    io.push(splitter_rec({ x = -0.5, y = -1 }, lines), 1, { name = "ice", count = 4 }, 4)
    eq(got, { "2:coal", "3:ice" })
  end)
  local function area_rec(ent, dir)
    defines = { direction = { north=0, east=4, south=8, west=12 } }; game = { tick = 1 }
    local entity = { valid = true, position = { x = 0, y = 0 }, surface = {
      find_entities_filtered = function(f) if f.area then return { ent } end return {} end } }
    return { entity = entity, dir = dir or "west" }
  end
  it("loaders and linked belts connect like belts", function()
    -- FND-0016 (author blueprint 2026-09-27): 1x1 loaders around west box; probe: loader lines 1/2 = lanes.
    local io = require("scripts.belt_io")
    local W = 12
    eq(io.behind(area_rec({ valid = true, type = "loader-1x1", loader_type = "output", direction = W, position = { x = 1, y = 0 } }).entity, "west") ~= nil, true, "1x1 output loader behind")
    eq(io.front(area_rec({ valid = true, type = "loader-1x1", loader_type = "input", direction = W, position = { x = -1, y = 0 } }).entity, "west") ~= nil, true, "1x1 input loader in front")
    eq(io.behind(area_rec({ valid = true, type = "loader", loader_type = "output", direction = W, position = { x = 1.5, y = 0 } }).entity, "west") ~= nil, true, "2x1 output loader behind")
    eq(io.front(area_rec({ valid = true, type = "loader", loader_type = "input", direction = W, position = { x = -1.5, y = 0 } }).entity, "west") ~= nil, true, "2x1 input loader in front")
    eq(io.behind(area_rec({ valid = true, type = "linked-belt", linked_belt_type = "output", direction = W, position = { x = 1, y = 0 } }).entity, "west") ~= nil, true, "linked belt output behind")
    eq(io.behind(area_rec({ valid = true, type = "loader-1x1", loader_type = "input", direction = W, position = { x = 1, y = 0 } }).entity, "west"), nil, "input loader behind does not feed")
    eq(io.front(area_rec({ valid = true, type = "loader-1x1", loader_type = "input", direction = 4, position = { x = -1, y = 0 } }).entity, "west"), nil, "loader facing other way")
  end)
  it("front accepts same direction belt", function()
    ok(find("north", 1, { { valid = true, type = "transport-belt", direction = 0 } }) ~= nil)
  end)
  it("front refuses sideways belt", function()
    eq(find("north", 1, { { valid = true, type = "transport-belt", direction = 4 } }), nil)
  end)
  it("front refuses belt facing box", function()
    eq(find("north", 1, { { valid = true, type = "transport-belt", direction = 8 } }), nil)
  end)
  it("front accepts underground input same direction", function()
    ok(find("north", 1, { { valid = true, type = "underground-belt", belt_to_ground_type = "input", direction = 0 } }) ~= nil)
  end)
  it("behind still requires belt moving into box", function()
    ok(find("north", -1, { { valid = true, type = "transport-belt", direction = 0 } }) ~= nil)
    eq(find("north", -1, { { valid = true, type = "transport-belt", direction = 4 } }), nil)
  end)
end)
