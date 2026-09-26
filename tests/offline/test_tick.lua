local N = require("scripts.names")
local core = require("scripts.core")
local belt_io = require("scripts.belt_io")
local circuit = require("scripts.circuit")
local led = require("scripts.led")
local tick = require("scripts.tick")

local function fixture(tier)
  defines = {direction={north=0,east=4,south=8,west=12},inventory={chest=1},wire_connector_id={circuit_red=1,circuit_green=2}}
  storage = {boxes={},belt_stack={}}
  settings = {global={[N.SETTING_TIMEOUT]={value=0}}}
  prototypes = {item={iron={stack_size=100},copper={stack_size=100}}}
  game = {connected_players={}}
  local inv={contents={}}
  function inv.insert(x)
    local n=x.count; if inv.limit then n=math.min(n,inv.limit) end
    local key=x.name.."/"..tostring(x.quality); local found
    for _,v in ipairs(inv.contents) do if v.name==x.name and v.quality==x.quality then found=v end end
    if found then found.count=found.count+n else if n>0 then inv.contents[#inv.contents+1]={name=x.name,quality=x.quality,count=n} end end
    return n
  end
  function inv.remove(x)
    local left=x.count
    for i=#inv.contents,1,-1 do local v=inv.contents[i]; if v.name==x.name and v.quality==x.quality then local n=math.min(left,v.count); v.count=v.count-n; left=left-n; if v.count==0 then table.remove(inv.contents,i) end end end
    return x.count-left
  end
  function inv.get_contents() local a={}; for i,v in ipairs(inv.contents) do a[i]={name=v.name,quality=v.quality,count=v.count} end; return a end
  local ent={valid=true,unit_number=1,position={x=0,y=0},surface={},force={index=1,belt_stack_size_bonus=0}}
  function ent.get_inventory() return inv end
  local rec={entity=ent,unit_number=1,tier=tier or "yellow",dir="north",box=core.new_box(),settings={timeout_mode="global",timeout_s=0,filters={},circuit={}},enabled=true,out_credit={0,0},in_credit={0,0},next_poll=0}
  storage.boxes[1]=rec
  local original={pull=belt_io.pull,push=belt_io.push,bss=belt_io.belt_stack_size,evaluate=circuit.evaluate,set=led.set}
  local feeds, pushes, blocked, verdict, ledcalls={},{{},{}},{}, {true,false},{}
  belt_io.belt_stack_size=function(force) return 1+(force.belt_stack_size_bonus or 0) end
  belt_io.pull=function(r,budget,sink)
    local taken={0,0}
    for l=1,2 do local f=feeds[l]; if f and budget[l]>0 then local n=sink(f.name,f.quality,l,f.count); if n>0 then taken[l]=1 end end end
    return taken
  end
  belt_io.push=function(r,l,piece,bss) if blocked[l] then return 0 end; pushes[l][#pushes[l]+1]={name=piece.name,quality=piece.quality,count=piece.count}; return piece.count end
  circuit.evaluate=function() return verdict[1],verdict[2] end
  led.set=function(r,s,v) ledcalls[#ledcalls+1]={state=s,visible=v} end
  return rec,inv,feeds,pushes,blocked,verdict,ledcalls,original
end
local function run(t, rec) if rec then rec.next_poll=0 end; tick.on_tick({tick=t or 1}) end

describe("tick", function()
 it("timeout ticks custom and global", function()
   local rec=fixture(); rec.settings.timeout_mode="custom"; rec.settings.timeout_s=3; eq(tick.timeout_ticks(rec),180); rec.settings.timeout_mode="global"; settings.global[N.SETTING_TIMEOUT].value=7; eq(tick.timeout_ticks(rec),420)
 end)
 it("on research caches belt stack size", function() local _,_,_,_,_,_,_,o=fixture(); belt_io.belt_stack_size=function(f) return f.index+2 end; tick.on_research({research={force={index=4}}}); eq(storage.belt_stack[4],6); belt_io.belt_stack_size=o.bss end)
 it("invalid entity drops rec", function() local r=fixture(); r.entity.valid=false; run(1); eq(storage.boxes[1],nil) end)
 it("disabled box moves nothing and hides led", function() local r,inv,f,p,b,v,l,o=fixture(); v[1]=false; f[1]={name="iron",quality="normal",count=1}; run(1,r); eq(r.box.stored_count,0); eq(#p[1],0); eq(#l,1); eq(l[1].visible,false); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("flush signal queues partials", function() local r,inv,f,p,b,v,l,o=fixture(); core.accept(r.box,"iron","normal",1,2,100,1,false); inv.insert({name="iron",quality="normal",count=2}); v[2]=true; run(1,r); eq(#r.box.ready[1],1); eq(#r.box.partials,0); eq(r.box.stored_count,2); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("intake budget follows tier rate", function() local r,inv,f,p,b,v,l,o=fixture("yellow"); f[1]={name="iron",quality="normal",count=1}; run(1,r); eq(r.in_credit,{0.125,0.125}); r.next_poll=0; run(2,r); eq(r.in_credit,{0.25,0.25}); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("stored item goes to core and chest", function() local r,inv,f,p,b,v,l,o=fixture(); f[1]={name="iron",quality="normal",count=1}; for t=1,9 do run(t,r) end; eq(r.box.stored_count,1); eq(inv.get_contents(),{{name="iron",quality="normal",count=1}}); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("filtered item goes to hold not chest", function() local r,inv,f,p,b,v,l,o=fixture(); r.settings.filters={{name="iron",quality="normal"}}; b[1]=true; f[1]={name="iron",quality="normal",count=1}; for t=1,9 do run(t,r) end; eq(core.hold_items(r.box),{{name="iron",quality="normal",count=1}}); eq(inv.get_contents(),{}); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("filter without quality matches any quality", function() local r,inv,f,p,b,v,l,o=fixture(); r.settings.filters={{name="iron"}}; b[1]=true; f[1]={name="iron",quality="legendary",count=1}; for t=1,9 do run(t,r) end; eq(core.hold_items(r.box),{{name="iron",quality="legendary",count=1}}); eq(inv.get_contents(),{}); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("output piece capped at belt stack size", function() local r,inv,f,p,b,v,l,o=fixture(); storage.belt_stack[1]=2; core.accept(r.box,"iron","normal",1,5,5,1,false); core.flush_partials(r.box,1); inv.insert({name="iron",quality="normal",count=5}); r.out_credit[1]=1; run(1,r); eq(p[1],{{name="iron",quality="normal",count=2}}); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("output removes stored items from chest", function() local r,inv,f,p,b,v,l,o=fixture(); core.accept(r.box,"iron","normal",1,1,1,1,false); core.flush_partials(r.box,1); inv.insert({name="iron",quality="normal",count=1}); r.out_credit[1]=1; run(1,r); eq(inv.get_contents(),{}); eq(r.box.stored_count,0); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("passthrough output leaves chest alone", function() local r,inv,f,p,b,v,l,o=fixture(); core.accept(r.box,"iron","normal",1,1,100,1,true); r.out_credit[1]=1; run(1,r); eq(inv.get_contents(),{}); eq(p[1],{{name="iron",quality="normal",count=1}}); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("output rate never above tier rate", function() local r,inv,f,p,b,v,l,o=fixture("yellow"); core.adopt_external(r.box,"iron","normal",100,100,1); inv.insert({name="iron",quality="normal",count=100}); for t=1,40 do run(t,r) end; local pushed=0; for _,piece in ipairs(p[1]) do pushed=pushed+piece.count end; ok(pushed <= N.TIER[r.tier].lane_rate * 40); eq(p[2],{}); eq(core.totals(r.box),{{name="iron",quality="normal",count=100-pushed}}); eq(inv.get_contents(),{{name="iron",quality="normal",count=100-pushed}}); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("blocked lane does not stall other lane", function() local r,inv,f,p,b,v,l,o=fixture(); b[1]=true; for lane=1,2 do core.accept(r.box,lane==1 and "iron" or "copper","normal",lane,1,1,1,false); core.flush_partials(r.box,1); inv.insert({name=lane==1 and "iron" or "copper",quality="normal",count=1}); r.out_credit[lane]=1 end; run(1,r); eq(#p[1],0); eq(p[2],{{name="copper",quality="normal",count=1}}); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("led follows core state", function() local r,inv,f,p,b,v,l,o=fixture(); core.adopt_external(r.box,"iron","normal",1,100,1); run(1,r); eq(l[#l].state,core.led_state(r.box)); eq(l[#l].visible,true); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("opened box reconciles next tick", function() local r,inv,f,p,b,v,l,o=fixture(); core.adopt_external(r.box,"iron","normal",3,100,1); inv.insert({name="iron",quality="normal",count=1}); game.connected_players={{opened=r.entity}}; run(1,r); eq(r.box.stored_count,1); eq(inv.get_contents(),{{name="iron",quality="normal",count=1}}); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("closed box reconciles every 60 ticks", function() local r,inv,f,p,b,v,l,o=fixture(); core.adopt_external(r.box,"iron","normal",3,100,1); inv.insert({name="iron",quality="normal",count=1}); run(58,r); eq(r.box.stored_count,3); run(59,r); eq(r.box.stored_count,1); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("idle box sleeps 30 ticks", function() local r,inv,f,p,b,v,l,o=fixture(); run(1,r); eq(r.next_poll,31); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
 it("belt stack computed when cache empty", function() local r,inv,f,p,b,v,l,o=fixture(); r.entity.force.belt_stack_size_bonus=2; core.accept(r.box,"iron","normal",1,4,4,1,false); core.flush_partials(r.box,1); inv.insert({name="iron",quality="normal",count=4}); r.out_credit[1]=1; run(1,r); eq(storage.belt_stack[1],3); eq(p[1],{{name="iron",quality="normal",count=3}}); belt_io.pull=o.pull; belt_io.push=o.push; circuit.evaluate=o.evaluate; led.set=o.set end)
end)
