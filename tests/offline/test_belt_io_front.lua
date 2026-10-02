defines = { direction = { north=0, east=4, south=8, west=12 } }
game = { tick = 1 }
local io = require("scripts.belt_io")

local function make_rec(dir, front)
  local calls = 0
  local line={can_insert_at=function() return true end,can_insert_at_back=function() return true end,
    insert_at=function() return true end,insert_at_back=function() return true end}
  if front and not front.get_transport_line then front.get_transport_line=function() return line end end
  local entity = { valid=true, position={x=0,y=0}, surface={
    find_entities_filtered=function(filter)
      calls = calls + 1
      if filter.position then return front and {front} or {} end
      return front and {front} or {}
    end,
  } }
  local rec = { entity=entity, dir=dir }
  return rec, function() return calls end
end

describe("belt_io front v17", function()
  it("kind ahead for same direction belt", function()
    for _,kind in ipairs({
      {type="transport-belt"}, {type="underground-belt",belt_to_ground_type="input"},
      {type="splitter",position={x=-0.5,y=-1}}, {type="loader-1x1",loader_type="input",position={x=0,y=-1}},
    }) do
      kind.valid=true; kind.direction=0
      local rec=make_rec("north",kind)
      eq(io.front_kind(rec),"ahead")
    end
  end)
  it("kind across for belt turned 90", function()
    local cases={{"west",12,"north",0,2},{"west",12,"south",8,1},{"east",4,"north",0,1},{"east",4,"south",8,2},
      {"north",0,"east",4,2},{"north",0,"west",12,1},{"south",8,"east",4,1},{"south",8,"west",12,2}}
    for _,c in ipairs(cases) do
      local belt={valid=true,type="transport-belt",direction=c[4]}
      local rec=make_rec(c[1],belt); rec.expected_near=c[5]; eq(io.front_kind(rec),"across",c[1].." / "..c[3])
    end
  end)
  it("kind nil", function()
    eq(io.front_kind(make_rec("west",nil)),nil)
    for _,belt in ipairs({
      {valid=true,type="transport-belt",direction=4},
      {valid=true,type="underground-belt",belt_to_ground_type="input",direction=0},
      {valid=true,type="splitter",direction=0,position={x=0.5,y=-1}},
    }) do eq(io.front_kind(make_rec("west",belt)),nil) end
  end)
  it("kind follows a front belt that goes away or turns", function()
    -- INT (review of lane 054): old answer was kept when nothing was found any more
    local belt={valid=true,type="transport-belt",direction=0}
    local rec=make_rec("west",belt)
    io.set_tick(100); eq(io.front_kind(rec),"across")
    belt.valid=false
    io.set_tick(101); eq(io.front_kind(rec),nil,"across belt removed")
    local rec2=make_rec("north",{valid=true,type="transport-belt",direction=0})
    io.set_tick(200); eq(io.front_kind(rec2),"ahead")
    rec2.belt.front.direction=4
    io.set_tick(300); eq(io.front_kind(rec2),"across","front belt turned by player")
  end)
  it("front_ok follows kind", function()
    eq(io.front_ok(make_rec("north",{valid=true,type="transport-belt",direction=0})),true)
    eq(io.front_ok(make_rec("west",{valid=true,type="transport-belt",direction=0})),true)
    eq(io.front_ok(make_rec("west",nil)),false)
  end)
  it("kind is cached like front", function()
    local rec,calls=make_rec("north",{valid=true,type="transport-belt",direction=0})
    eq(io.front_kind(rec),"ahead"); local first=calls()
    eq(io.front_kind(rec),"ahead"); eq(calls(),first)
  end)
  it("across push uses near lane", function()
    for _,dc in ipairs({{12,0,0,2},{12,8,0,1},{4,0,0,1},{4,8,0,2},{0,4,0,2},{0,12,0,1},{8,4,0,1},{8,12,0,2}}) do
      local got={}; local lines={}
      -- INT: back of lane, not a fixed spot (belt fed only by packer is a curve: near lane shorter than 0.5)
      for i=1,2 do lines[i]={can_insert_at_back=function() return true end,insert_at_back=function(stack,bss) got[#got+1]={i,"back",stack.count,bss}; return true end} end
      local belt={valid=true,type="transport-belt",direction=dc[2],get_transport_line=function(i) return lines[i] end}
      local rec=make_rec(({[0]="north",[4]="east",[8]="south",[12]="west"})[dc[1]],belt)
      storage={sp_counters={pushes=0,items_out=0}}
      eq(io.push(rec,1,{name="iron",count=4},4),4); eq(io.push(rec,2,{name="iron",count=4},4),4)
      eq(got,{{dc[4],"back",4,4},{dc[4],"back",4,4}})
      eq(storage.sp_counters,{pushes=2,items_out=8})
    end
  end)
  it("across can_push asks near lane back", function()
    for _,entry in ipairs({{0,2},{8,1}}) do
      local near=entry[2]
      local got={}; local lines={}
      for i=1,2 do lines[i]={can_insert_at_back=function() got[#got+1]={i,"back"}; return true end} end
      local belt={valid=true,type="transport-belt",direction=entry[1],get_transport_line=function(i) return lines[i] end}
      local rec=make_rec("west",belt)
      eq(io.can_push(rec,1),true); eq(io.can_push(rec,2),true)
      eq(got,{{near,"back"},{near,"back"}})
    end
  end)
  it("ahead push unchanged", function()
    local got={}; local lines={}
    for i=1,2 do lines[i]={can_insert_at_back=function() return true end,insert_at_back=function(s,b) got[#got+1]=i; return true end} end
    local rec=make_rec("north",{valid=true,type="transport-belt",direction=0,get_transport_line=function(i) return lines[i] end})
    eq(io.push(rec,2,{name="iron",count=4},4),4); eq(got,{2})
  end)
  it("push to a further spot of front tile", function()
    -- v20: several leftovers in one look
    local got={}
    local line={can_insert_at=function(pos) got[#got+1]={"can",pos}; return true end,insert_at=function(pos,stack,bss) got[#got+1]={"put",pos,stack.count,bss}; return true end,
      can_insert_at_back=function() got[#got+1]={"can_back"}; return true end,insert_at_back=function() got[#got+1]={"put_back"}; return true end}
    local belt={valid=true,type="transport-belt",direction=0,get_transport_line=function() return line end}
    local rec=make_rec("north",belt); storage={sp_counters={pushes=0,items_out=0}}
    eq(io.push(rec,1,{name="iron",count=2},4,2),2)
    eq(got,{{"can",0.25},{"put",0.25,2,4}}); eq(storage.sp_counters,{pushes=1,items_out=2})
    got={}; line.can_insert_at=function() return false end
    eq(io.push(rec,1,{name="iron",count=2},4,3),0)
  end)
end)
