defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
local belt_io = require("scripts.belt_io")

local function find(dir, sign, belts)
  local e = { position = { x = 0, y = 0 }, surface = {
    find_entities_filtered = function(filter)
      local p = filter.position
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
