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
  it("pull reports eta of front item per lane", function()
    local a,b=eta_line({name="iron",count=1},false,0.1),eta_line({name="copper",count=1},false,0.2)
    local got,eta=require("scripts.belt_io").pull(eta_rec({a,b}),{0,0},function() return 0 end)
    eq(got,{0,0}); eq(eta,{4,7})
  end)
  it("eta zero when item at exit, nil when lane empty", function()
    local a,b=eta_line({name="iron",count=1},true),eta_line(nil,false)
    local _,eta=require("scripts.belt_io").pull(eta_rec({a,b}),{0,0},function() return 0 end)
    eq(eta,{0,nil})
  end)
  it("eta computed when budget empty", function()
    local calls=0; local a=eta_line({name="iron",count=1},false,0.03125,function() calls=calls+1 end)
    local _,eta=require("scripts.belt_io").pull(eta_rec({a,eta_line(nil,false)}),{0,0},function() return 0 end)
    eq(eta,{1,nil}); eq(calls,1)
  end)
  it("no eta read on lane that took an item", function()
    -- PERF-3 bench: next item sits >= 0.25 tile behind a taken one, so it never beats next tier visit.
    local calls=0; local a=eta_line({name="iron",count=1},true,0.25,function() calls=calls+1 end)
    local rm=a.remove_item; function a.remove_item(x) rm(x); a.can_insert_at=function() return true end end
    local got,eta=require("scripts.belt_io").pull(eta_rec({a,eta_line(nil,false)}),{1,0},function() return 1 end)
    eq(got,{1,0}); eq(calls,0); eq(eta,{nil,nil})
  end)
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
  it("full box shares freed slot between lanes", function()
    -- FND-0011 (author 2026-09-27, repro 16 epic recyclers overloaded): full box freed one slot per poll, lane 1
    -- always asked first and took it; lane 2 (10-stack) refused forever -> right output lane dead.
    local a, b = eta_line({ name = "coal", count = 1 }, true), eta_line({ name = "ice", count = 10 }, true)
    local rec = eta_rec({ a, b })
    local got = { 0, 0 }
    for poll = 1, 10 do
      local free = 1  -- one slot freed by output each poll
      require("scripts.belt_io").pull(rec, { 1, 1 }, function(_, _, lane, count)
        if free < 1 then return 0 end
        free = free - 1; got[lane] = got[lane] + 1; return count
      end)
    end
    ok(got[1] >= 4 and got[2] >= 4, "lane1=" .. got[1] .. " lane2=" .. got[2])
  end)
  it("full box shares slot freed every fourth poll", function()
    -- FND-0011 repro cap 4 + first fix: slot freed every 8 ticks (4 polls); flipping order on all-refused polls
    -- gave the slot to the same lane every time (parity lock).
    local a, b = eta_line({ name = "coal", count = 1 }, true), eta_line({ name = "ice", count = 1 }, true)
    local rec = eta_rec({ a, b })
    local got, free = { 0, 0 }, 0
    for poll = 1, 40 do
      if poll % 4 == 0 then free = free + 1 end
      require("scripts.belt_io").pull(rec, { 1, 1 }, function(_, _, lane, count)
        if free < 1 then return 0 end
        free = free - 1; got[lane] = got[lane] + 1; return count
      end)
    end
    ok(got[1] >= 4 and got[2] >= 4, "lane1=" .. got[1] .. " lane2=" .. got[2])
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
  it("splitter behind feeds from its output half", function()
    -- FND-0015 (author blueprint 2026-09-27): splitter behind box; probe: left half out = lines 5/6, right = 7/8.
    local lines = {}
    for i = 1, 8 do lines[i] = eta_line(nil, false) end
    lines[5] = eta_line({ name = "coal", count = 1 }, true); lines[6] = eta_line({ name = "stone", count = 1 }, true)
    lines[7] = eta_line({ name = "ice", count = 1 }, true); lines[8] = eta_line({ name = "wood", count = 1 }, true)
    local seen = {}
    local io = require("scripts.belt_io")
    io.pull(splitter_rec({ x = 0.5, y = 1 }, lines), { 1, 1 }, function(name, _, lane) seen[lane] = name; return 1 end)
    eq(seen, { "coal", "stone" }, "box in front of left half reads lines 5/6")
    seen = {}
    io.pull(splitter_rec({ x = -0.5, y = 1 }, lines), { 1, 1 }, function(name, _, lane) seen[lane] = name; return 1 end)
    eq(seen, { "ice", "wood" }, "box in front of right half reads lines 7/8")
  end)
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
