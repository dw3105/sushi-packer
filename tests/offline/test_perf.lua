local circuit=require("scripts.circuit")
local belt_io=require("scripts.belt_io")

describe("perf",function()
  it("circuit off makes no network calls",function()
    local calls=0; defines={wire_connector_id={circuit_red=1,circuit_green=2}}
    local rec={entity={get_circuit_network=function() calls=calls+1 end},settings={circuit={}}}
    eq(circuit.evaluate(rec),true); eq(calls,0); eq(rec.circuit_state.last_flush,false)
  end)
  local function belt()
    local b={valid=true,type="transport-belt",direction=0}
    local line={get_detailed_contents=function() return {} end}
    function b.get_transport_line() return line end
    return b
  end
  local function rec(surface)
    return {entity={valid=true,position={x=0,y=0},surface=surface},dir="north"}
  end
  it("behind belt looked up once while valid",function()
    defines={direction={north=0,east=4,south=8,west=12}}; game={tick=1}
    local calls,b=0,belt(); local r=rec({find_entities_filtered=function() calls=calls+1; return {b} end})
    belt_io.pull(r,{1,0},function() return 0 end); belt_io.pull(r,{1,0},function() return 0 end); eq(calls,1)
  end)
  it("missing belt rescanned at most every 60 ticks",function()
    defines={direction={north=0,east=4,south=8,west=12}}; game={tick=1}; local calls=0
    local r=rec({find_entities_filtered=function(f) if f.position then calls=calls+1 end; return {} end})
    belt_io.pull(r,{1,0},function() return 0 end); game.tick=59; belt_io.pull(r,{1,0},function() return 0 end); eq(calls,1)
    game.tick=61; belt_io.pull(r,{1,0},function() return 0 end); eq(calls,2)
  end)
  it("rotated cached belt is dropped",function()
    defines={direction={north=0,east=4,south=8,west=12}}; game={tick=1}; local calls,b=0,belt()
    local r=rec({find_entities_filtered=function(f) if f.area then return {} end; calls=calls+1; return {b} end})
    belt_io.pull(r,{1,0},function() return 0 end); b.direction=4; game.tick=61
    belt_io.pull(r,{1,0},function() return 0 end); eq(calls,2); eq(r.belt.behind,nil)
  end)
end)

describe("perf scan",function()
  it("front rescan not starved by missing behind",function()
    defines={direction={north=0,east=4,south=8,west=12}}; local calls={front=0}; local surface={}
    function surface.find_entities_filtered(f) if f.position and f.position.y<0 then calls.front=calls.front+1 end; return {} end
    local r={entity={valid=true,position={x=0.5,y=0.5},surface=surface},dir="north"}
    for t=0,600,8 do game={tick=t}; belt_io.pull(r,{1,1},function() return 0 end); belt_io.push(r,1,{name="iron-plate",count=1,quality="normal"},1) end
    ok(calls.front>=9,"front rescans over 600 ticks: "..calls.front)
  end)
end)
