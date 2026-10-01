local N = require("scripts.names")
local core = require("scripts.core")
local belt_io = require("scripts.belt_io")
local circuit = require("scripts.circuit")
local led = require("scripts.led")
local tick = require("scripts.tick")

local function fixture(unit, tier, due)
  defines = {inventory={chest=1},gui_type={entity=1}}
  storage = {boxes={},belt_stack={[1]=1}}
  settings = {global={[N.SETTING_TIMEOUT]={value=0}}}
  prototypes = {item={iron={stack_size=100},copper={stack_size=100}},quality={normal={level=0}},entity=require("tests.offline.belts")}
  game = {connected_players={}}
  local inv={contents={}, gets=0}
  function inv.insert(x) inv.contents[#inv.contents+1]={name=x.name,quality=x.quality,count=x.count}; return x.count end
  function inv.remove() return 0 end
  function inv.get_contents() inv.gets=inv.gets+1; local a={}; for i,x in ipairs(inv.contents) do a[i]={name=x.name,quality=x.quality,count=x.count} end; return a end
  local reads={}
  local data={valid=true, unit_number=unit, force={index=1,belt_stack_size_bonus=0}}
  local ent=setmetatable({}, {__index=function(_,k) reads[k]=(reads[k] or 0)+1; local v=data[k]; if type(v)=="function" then return v end; return v end})
  data.get_inventory=function() return inv end
  local rec={entity=ent,unit_number=unit,tier=tier or "yellow",dir="north",box=core.new_box(),settings={timeout_mode="global",timeout_s=0,filters={},circuit={}},enabled=true,out_credit={0,0},in_credit={0,0},next_poll=due or 0,last_poll=0,led={state="green",visible=true}}
  storage.boxes[unit]=rec
  local original={pull=belt_io.pull,push=belt_io.push,speed=belt_io.speed,bss=belt_io.belt_stack_size,evaluate=circuit.evaluate,set=led.set}
  local pulls, ledcalls={},{}
  belt_io.belt_stack_size=function() return 1 end
  belt_io.pull=function(r,budget,sink) pulls[#pulls+1]={tick=worldtick}; return {0,0} end
  belt_io.push=function() return 0 end
  circuit.evaluate=function() return true,false end
  led.set=function(r,s,v) ledcalls[#ledcalls+1]={tick=worldtick,state=s,visible=v}; r.led={state=s,visible=v} end
  return rec,inv,reads,pulls,ledcalls,original,function(value) data.valid=value end
end
worldtick=0
local function run(t) worldtick=t; tick.on_tick({tick=t}) end
local function restore(o) belt_io.pull=o.pull; belt_io.push=o.push; belt_io.speed=o.speed; belt_io.belt_stack_size=o.bss; circuit.evaluate=o.evaluate; led.set=o.set end

describe("tick sleep", function()
  it("sleeping box costs no engine read", function()
    local r,inv,reads,pulls,lc,o=fixture(9,"yellow",1000)
    for t=1,50 do run(t) end
    local total=0; for _,n in pairs(reads) do total=total+n end
    eq(total,0); eq(#lc,0); restore(o)
  end)
  it("sleeping box still reconciles on its 60 tick slot", function()
    local r,inv,reads,pulls,lc,o=fixture(1,"yellow",1000)
    local expected=0
    for t=1,120 do run(t); if (t+1)%60==0 then expected=expected+1 end end
    eq(inv.gets,expected); restore(o)
  end)
  it("opened sleeping box reconciles every tick", function()
    local r,inv,reads,pulls,lc,o=fixture(3,"yellow",1000)
    game.connected_players={{opened=r.entity,opened_gui_type=defines.gui_type.entity}}
    for t=1,5 do run(t) end
    eq(inv.gets,5); restore(o)
  end)
  it("due box visited same tick as before", function()
    local r,inv,reads,pulls,lc,o=fixture(100,"yellow",7)
    for t=1,8 do run(t) end
    eq(pulls,{{tick=7}}); restore(o)
  end)
  it("decon mark hides led same tick", function()
    local r,inv,reads,pulls,lc,o=fixture(5,"yellow",1000)
    tick.on_decon({entity=r.entity},true); run(1); eq(lc[#lc].visible,false)
    tick.on_decon({entity=r.entity},false); run(2); eq(lc[#lc].visible,true); restore(o)
  end)
  it("invalid entity dropped when due", function()
    local r,inv,reads,pulls,lc,o,invalidate=fixture(5,"yellow",5)
    local dataReads=reads
    -- invalid is an engine field, switched without adding a mock read.
    invalidate(false)
    for t=1,4 do run(t) end
    local total=0; for _,n in pairs(dataReads) do total=total+n end
    eq(total,0); run(5); eq(storage.boxes[5],nil); restore(o)
    local sleeping,inv2,reads2,pulls2,lc2,o2,invalidate2=fixture(1,"yellow",1000)
    invalidate2(false); run(59); eq(storage.boxes[1],nil); restore(o2)
  end)
  it("led set only on state change", function()
    local r,inv,reads,pulls,lc,o=fixture(9,"turbo",0)
    r.led.state="red"
    for t=1,10 do r.next_poll=t-1; run(t) end
    eq(#lc,1); restore(o)
  end)
  it("same trace as v114 tick", function()
    local old=require("tests.offline.fixtures.tick_v114")
    local original={pull=belt_io.pull,push=belt_io.push,speed=belt_io.speed,bss=belt_io.belt_stack_size,rate=belt_io.lane_rate,evaluate=circuit.evaluate,set=led.set}
    local worlds={}
    for wi=1,2 do
      local boxes,stack={},{}
      local w={storage={boxes=boxes,belt_stack={[1]=1}},recs={},invs={},pulls={},pushes={},leds={},seed=7919}
      worlds[wi]=w
      for i,tier in ipairs({"yellow","red","blue","turbo","yellow","red","blue","turbo","yellow","red","blue","turbo"}) do
        local inv={contents={}}
        function inv.insert(x) inv.contents[#inv.contents+1]={name=x.name,quality=x.quality,count=x.count}; return x.count end
        function inv.remove(x) local left=x.count; for j=#inv.contents,1,-1 do local y=inv.contents[j]; if y.name==x.name and y.quality==x.quality then local n=math.min(left,y.count); y.count=y.count-n; left=left-n; if y.count==0 then table.remove(inv.contents,j) end end end; return x.count-left end
        function inv.get_contents() local a={}; for j,x in ipairs(inv.contents) do a[j]={name=x.name,quality=x.quality,count=x.count} end; return a end
        local ent={valid=true,unit_number=i,force={index=1}}
        function ent.get_inventory() return inv end
        local rec={entity=ent,unit_number=i,tier=tier,dir="north",box=core.new_box(),settings={timeout_mode="global",timeout_s=0,filters={},circuit={}},enabled=true,out_credit={0,0},in_credit={0,0},next_poll=0}
        boxes[i]=rec; w.recs[i]=rec; w.invs[i]=inv
        if i%3==1 then core.adopt_external(rec.box,"iron","normal",i,100,i); inv.insert({name="iron",quality="normal",count=i}) end
        rec.led={state=core.led_state(rec.box),visible=true}
      end
    end
    local active,now
    local function random_int() active.seed=(active.seed*48271)%2147483647; return active.seed end
    defines={inventory={chest=1},gui_type={entity=1}}; settings={global={[N.SETTING_TIMEOUT]={value=0}}}
    prototypes={item={iron={stack_size=100},copper={stack_size=100}},quality={normal={level=0}},entity=require("tests.offline.belts")}; game={connected_players={}}
    belt_io.belt_stack_size=function() return 1 end
    belt_io.lane_rate=function(t) return ({yellow=0.125,red=0.25,blue=0.375,turbo=0.5})[t] end
    belt_io.speed=function() return nil end
    circuit.evaluate=function() return true,false end
    led.set=function(r,s,v) active.leds[#active.leds+1]={u=r.unit_number,state=s,visible=v,t=now}; r.led={state=s,visible=v} end
    belt_io.pull=function(r,budget,sink)
      active.pulls[#active.pulls+1]={u=r.unit_number,t=now,b={budget[1],budget[2]}}
      local got={0,0}
      if random_int()%7==0 and budget[1]>0 then local n=sink("copper","normal",1,1); got[1]=n>0 and 1 or 0 end
      return got
    end
    belt_io.push=function(r,l,piece)
      active.pushes[#active.pushes+1]={u=r.unit_number,t=now,l=l,n=piece.name,c=piece.count}
      if random_int()%5==0 then return 0 end
      return piece.count
    end
    local function snapshot(w)
      local out={}
      for i,r in ipairs(w.recs) do
        local contents={}; for j,x in ipairs(w.invs[i].get_contents()) do contents[j]={name=x.name,quality=x.quality,count=x.count} end
        out[i]={next_poll=r.next_poll,last_poll=r.last_poll,in_credit={r.in_credit[1],r.in_credit[2]},out_credit={r.out_credit[1],r.out_credit[2]},enabled=r.enabled,contents=contents,totals=core.totals(r.box)}
      end
      return out
    end
    local traces={{},{}}
    for t=1,600 do
      now=t
      for wi=1,2 do
        active=worlds[wi]; storage=active.storage; local mod=wi==1 and tick or old
        mod.on_tick({tick=t})
        traces[wi][t]={state=snapshot(active),pulls=#active.pulls,pushes=#active.pushes,leds=#active.leds}
      end
      for i=1,12 do eq(traces[1][t].state[i],traces[2][t].state[i]) end
      if traces[1][t].pulls~=traces[2][t].pulls then error("pull count differs at tick "..t..": "..traces[1][t].pulls.." vs "..traces[2][t].pulls) end
      if traces[1][t].pushes~=traces[2][t].pushes then error("push count differs at tick "..t..": "..traces[1][t].pushes.." vs "..traces[2][t].pushes) end
      if traces[1][t].leds~=traces[2][t].leds then error("LED count differs at tick "..t..": "..traces[1][t].leds.." vs "..traces[2][t].leds) end
    end
    eq(worlds[1].pulls,worlds[2].pulls); eq(worlds[1].pushes,worlds[2].pushes); eq(worlds[1].leds,worlds[2].leds)
    belt_io.pull=original.pull; belt_io.push=original.push; belt_io.speed=original.speed; belt_io.belt_stack_size=original.bss; belt_io.lane_rate=original.rate; circuit.evaluate=original.evaluate; led.set=original.set
  end)
end)
