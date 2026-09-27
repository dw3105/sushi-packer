local circuit = require("scripts.circuit")
local belt_io = require("scripts.belt_io")
local core = require("scripts.core")
local tick = require("scripts.tick")
local N = require("scripts.names")

describe("perf", function()
  it("circuit off makes no network calls", function()
    local calls = 0
    defines = { wire_connector_id = { circuit_red = 1, circuit_green = 2 } }
    local rec = { entity = { get_circuit_network = function() calls = calls + 1 end }, settings = { circuit = {} } }
    eq(circuit.evaluate(rec), true); eq(calls, 0); eq(rec.circuit_state.last_flush, false)
  end)

  local function cache_rec(surface, dir)
    return { entity = { valid = true, position = {x=0,y=0}, surface = surface }, dir = dir or "north" }
  end
  local function found_belt(kind, direction, extra)
    local b = { valid = true, type = kind or "transport-belt", direction = direction or 0 }
    for k,v in pairs(extra or {}) do b[k]=v end
    return b
  end
  it("behind belt looked up once while valid", function()
    defines = { direction = {north=0,east=4,south=8,west=12} }; game={tick=1}
    local calls, belt = 0, found_belt()
    local r=cache_rec({find_entities_filtered=function() calls=calls+1; return {belt} end})
    local line={get_detailed_contents=function() return {} end}
    function belt.get_transport_line() return line end
    belt_io.pull(r,{1,0},function() return 0 end); belt_io.pull(r,{1,0},function() return 0 end)
    eq(calls,1)
  end)
  it("missing belt rescanned at most every 60 ticks", function()
    defines={direction={north=0,east=4,south=8,west=12}}; game={tick=1}
    local calls=0; local r=cache_rec({find_entities_filtered=function() calls=calls+1; return {} end})
    belt_io.pull(r,{1,0},function() return 0 end); game.tick=59; belt_io.pull(r,{1,0},function() return 0 end)
    eq(calls,1); game.tick=61; belt_io.pull(r,{1,0},function() return 0 end); eq(calls,2)
  end)
  it("rotated cached belt is dropped", function()
    defines={direction={north=0,east=4,south=8,west=12}}; game={tick=1}
    local calls=0; local belt=found_belt()
    local r=cache_rec({find_entities_filtered=function() calls=calls+1; return {belt} end})
    local line={get_detailed_contents=function() return {} end}; function belt.get_transport_line() return line end
    belt_io.pull(r,{1,0},function() return 0 end); belt.direction=4; game.tick=61
    belt_io.pull(r,{1,0},function() return 0 end); eq(calls,2); eq(r.belt.behind,nil)
  end)
  it("pull with zero budget reads eta without calling sink", function()
    defines={direction={north=0,east=4,south=8,west=12}}; game={tick=1}
    prototypes={entity={ ["yellow-belt"]={belt_speed=0.03125} }}
    local belt=found_belt(); belt.name="yellow-belt"
    local line={}; setmetatable(line,{__len=function() return 1 end}); line[1]={name="iron",count=1}
    function line.can_insert_at() return true end
    function line.get_detailed_contents() return {{position=0.25}} end
    function belt.get_transport_line() return line end
    local r=cache_rec({find_entities_filtered=function() return {belt} end})
    local calls=0; local got,eta=belt_io.pull(r,{0,0},function() calls=calls+1; return 0 end)
    eq(got,{0,0}); eq(eta,{8,8}); eq(calls,0)
  end)

  local function tick_fixture(tier, unit)
    local old={pull=belt_io.pull,push=belt_io.push,bss=belt_io.belt_stack_size,evaluate=require("scripts.circuit").evaluate,set=require("scripts.led").set}
    defines={inventory={chest=1},gui_type={entity=1,item=3},direction={north=0,east=4,south=8,west=12},wire_connector_id={circuit_red=1,circuit_green=2}}
    settings={global={[N.SETTING_TIMEOUT]={value=0}}}; prototypes={item={iron={stack_size=100}}}
    local calls={pull=0,pull_unit={},push=0,led=0,inventory=0,players=0}
    local inv={contents={}}
    function inv.insert(x) inv.contents[1]=inv.contents[1] or {name=x.name,quality=x.quality,count=0}; inv.contents[1].count=inv.contents[1].count+x.count; return x.count end
    function inv.remove(x) if not inv.contents[1] then return 0 end; local n=math.min(x.count,inv.contents[1].count); inv.contents[1].count=inv.contents[1].count-n; return n end
    function inv.get_contents() local out={}; for i,x in ipairs(inv.contents) do out[i]={name=x.name,quality=x.quality,count=x.count} end; return out end
    local ent={valid=true,unit_number=unit,position={x=0,y=0},force={index=1,belt_stack_size_bonus=0}}
    function ent.get_inventory() calls.inventory=calls.inventory+1; return inv end
    local rec={entity=ent,unit_number=unit,tier=tier,dir="north",box=core.new_box(),settings={timeout_mode="global",filters={},circuit={}},enabled=true,in_credit={0,0},out_credit={0,0},next_poll=0}
    belt_io.pull=function(r) calls.pull=calls.pull+1; calls.pull_unit[r.unit_number]=(calls.pull_unit[r.unit_number] or 0)+1; return {0,0} end
    belt_io.push=function(_,_,p) calls.push=calls.push+1; return p.count end
    belt_io.belt_stack_size=function() return 1 end
    circuit.evaluate=function() return true,false end
    require("scripts.led").set=function() calls.led=calls.led+1 end
    storage={boxes={[unit]=rec},belt_stack={[1]=1}}; game={connected_players={}}
    calls.inv=inv
    return rec,calls,old
  end
  local function restore(old)
    belt_io.pull=old.pull; belt_io.push=old.push; belt_io.belt_stack_size=old.bss
    circuit.evaluate=old.evaluate; require("scripts.led").set=old.set
  end
  it("yellow box visited every 8 ticks", function()
    local r,c,o=tick_fixture("yellow",1); core.accept(r.box,"iron","normal",1,1,100,0,false); for t=1,16 do tick.on_tick({tick=t}) end
    eq(c.pull,2); restore(o)
  end)
  it("turbo box visited every 2 ticks", function()
    local r,c,o=tick_fixture("turbo",1); core.accept(r.box,"iron","normal",1,1,100,0,false); for t=1,10 do tick.on_tick({tick=t}) end
    eq(c.pull,5); restore(o)
  end)
  it("visits staggered by unit number", function()
    local r,c,o=tick_fixture("yellow",1); core.accept(r.box,"iron","normal",1,1,100,0,false); local other={}; for k,v in pairs(r) do other[k]=v end
    other.unit_number=2; other.entity={valid=true,unit_number=2,force=r.entity.force,get_inventory=r.entity.get_inventory}; other.box=core.new_box(); other.in_credit={0,0}; other.out_credit={0,0}
    core.accept(other.box,"iron","normal",1,1,100,0,false); storage.boxes[2]=other; for t=1,8 do tick.on_tick({tick=t}) end
    eq(c.pull_unit[1],1); eq(c.pull_unit[2],1); eq(other.in_credit,{1,1}); eq(r.in_credit,{1,1}); restore(o)
  end)
  it("credits per visit keep tier rate over 800 ticks", function()
    for _,tier in ipairs({"yellow","red","blue","turbo"}) do
      local r,c,o=tick_fixture(tier,1); local pushed=0
      belt_io.push=function(_,_,p) pushed=pushed+p.count; return p.count end
      local total=800; local amount=N.TIER[tier].lane_rate*total
      core.adopt_external(r.box,"iron","normal",1000,1000,1); core.flush_partials(r.box,1); c.inv.insert({name="iron",quality="normal",count=1000})
      for t=1,total do tick.on_tick({tick=t}) end
      ok(pushed <= amount+2, tier.." exceeded rate"); ok(pushed >= amount-2, tier.." below rate")
      restore(o)
    end
  end)
  it("led checked every tick", function()
    local r,c,o=tick_fixture("yellow",1); for t=1,11 do r.next_poll=0; tick.on_tick({tick=t}) end
    eq(c.led,11); restore(o)
  end)
  it("opened set built once per tick", function()
    local r,c,o=tick_fixture("yellow",1); local n=0
    game.connected_players=setmetatable({{opened={unit_number=99},opened_gui_type=1}},{__pairs=function(t) n=n+1; return next,t,nil end})
    for t=1,5 do r.next_poll=0; tick.on_tick({tick=t}) end
    eq(n,5); restore(o)
  end)
end)

describe("perf scan", function()
  it("front rescan not starved by missing behind", function()
    -- both neighbours missing; behind asks first every visit; front must still get its own rescan
    defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
    local calls = { front = 0 }
    local surface = {}
    function surface.find_entities_filtered(f)
      if f.position.y < 0 then calls.front = calls.front + 1 end
      return {}
    end
    local rec = { entity = { valid = true, position = { x = 0.5, y = 0.5 }, surface = surface }, dir = "north" }
    local belt_io = require("scripts.belt_io")
    for t = 0, 600, 8 do
      game = { tick = t }
      belt_io.pull(rec, { 1, 1 }, function() return 0 end)
      belt_io.push(rec, 1, { name = "iron-plate", count = 1, quality = "normal" }, 1)
    end
    ok(calls.front >= 9, "front rescans over 600 ticks: " .. calls.front)
  end)
end)
