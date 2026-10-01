local N = require("scripts.names")
local belt_io = require("scripts.belt_io")
local circuit = require("scripts.circuit")
local ledger = require("scripts.ledger")
local arms = require("scripts.arms")
local led = require("scripts.led")
local tick = require("scripts.tick")

local function inventory(contents)
  local inv = { contents = contents or {}, removes = {}, reads = 0 }
  function inv.get_contents() inv.reads=inv.reads+1; local a={}; for i,x in ipairs(inv.contents) do a[i]={name=x.name,quality=x.quality,count=x.count} end; return a end
  function inv.is_empty() return #inv.contents==0 end
  function inv.remove(x)
    inv.removes[#inv.removes+1]={name=x.name,quality=x.quality,count=x.count}
    local left=x.count
    for i=#inv.contents,1,-1 do local y=inv.contents[i]; if y.name==x.name and y.quality==x.quality then local n=math.min(left,y.count); y.count=y.count-n; left=left-n; if y.count==0 then table.remove(inv.contents,i) end end end
    return x.count-left
  end
  function inv.count_empty_stacks() return 12-#inv.contents end
  return setmetatable(inv,{__len=function() return 12 end})
end

local function fixture(tier)
  defines={inventory={chest=1},gui_type={entity=1}}
  storage={boxes={},belt_stack={[1]=4}}
  settings={global={[N.SETTING_TIMEOUT]={value=0}}}
  prototypes={item={iron={stack_size=100},copper={stack_size=100}},quality={normal={level=0}},entity=require("tests.offline.belts")}
  game={connected_players={}}
  local boxinv=inventory()
  local entity={valid=true,unit_number=1,force={index=1},get_inventory=function() return boxinv end}
  local invs={inventory(),inventory()}
  local rec={entity=entity,unit_number=1,tier=tier or "yellow",dir="north",settings={filters={},circuit={},timeout_mode="global",timeout_s=0},stores={{valid=true},{valid=true}},invs=invs,arms={{},{}},paused={false,false},skip={"",""},ledger=ledger.new(),extra=nil,out_credit={0,0},next_poll=0,last_poll=0,led={state="green",visible=true}}
  storage.boxes[1]=rec
  local orig={push=belt_io.push,rate=belt_io.lane_rate,eval=circuit.evaluate,plan=ledger.plan,hoard=ledger.hoard,ledger_led=ledger.led,pause=arms.pause,skip=arms.skip,set=led.set}
  local pushes, plans, pauses, skips, ledcalls={}, {}, {}, {}, {}
  local blocked_after
  belt_io.lane_rate=function() return 0.125 end
  belt_io.push=function(r,l,piece,bss)
    pushes[#pushes+1]={lane=l,piece={name=piece.name,quality=piece.quality,count=piece.count},inv=r._pushing_inv}
    if blocked_after and #pushes==blocked_after then return 0 end
    if storage.sp_counters then storage.sp_counters.pushes=storage.sp_counters.pushes+1; storage.sp_counters.items_out=storage.sp_counters.items_out+piece.count end
    return piece.count
  end
  circuit.evaluate=function() return true,false end
  ledger.plan=function(_,lane,contents,opts) plans[#plans+1]={lane=lane,contents=contents,opts=opts}; return {} end
  ledger.hoard=function(contents) return #contents>0 and {{name=contents[1].name,quality=contents[1].quality}} or {} end
  ledger.led=function(a,b,slots) return a+b==0 and "green" or "yellow" end
  arms.pause=function(r,l,p) if r.paused[l]~=p then pauses[#pauses+1]={l,p}; r.paused[l]=p end end
  arms.skip=function(r,l,k) skips[#skips+1]={l,k} end
  led.set=function(r,s,v) ledcalls[#ledcalls+1]={s,v}; r.led={state=s,visible=v} end
  local f={rec=rec,invs=invs,boxinv=boxinv,pushes=pushes,plans=plans,pauses=pauses,skips=skips,ledcalls=ledcalls,orig=orig}
  function f.block_after(n) blocked_after=n end
  function f.restore() belt_io.push=orig.push; belt_io.lane_rate=orig.rate; circuit.evaluate=orig.eval; ledger.plan=orig.plan; ledger.hoard=orig.hoard; ledger.led=orig.ledger_led; arms.pause=orig.pause; arms.skip=orig.skip; led.set=orig.set end
  function f.run(t) tick.on_tick({tick=t or 1}) end
  return f
end

describe("tick arms", function()
  it("pushes ledger pieces on own lane and removes them", function()
    local f=fixture(); f.invs[1]=inventory({{name="iron",quality="normal",count=8}}); f.rec.invs=f.invs; f.rec.out_credit[1]=2
    ledger.plan=function(_,lane) if lane==1 then return {{name="iron",quality="normal",count=4},{name="iron",quality="normal",count=4}} end return {} end
    f.run(1); eq(#f.pushes,2); eq(f.pushes[1].lane,1); eq(f.pushes[2].lane,1); eq(#f.invs[1].removes,2); eq(#f.invs[2].removes,0); f.restore()
  end)
  it("stops at blocked lane", function()
    local f=fixture(); f.invs[1]=inventory({{name="iron",quality="normal",count=8}}); f.rec.invs=f.invs; f.rec.out_credit={2,0}; f.blocked_after=2
    ledger.plan=function(_,lane,contents) if lane~=1 then return {} end; if contents[1] and contents[1].count>=8 then return {{name="iron",quality="normal",count=4},{name="iron",quality="normal",count=4}} end; return {{name="iron",quality="normal",count=4}} end
    f.block_after(2); f.run(1); eq(#f.invs[1].removes,1); f.rec.next_poll=0; f.block_after(nil); f.run(9); eq(#f.invs[1].removes,2); f.restore()
  end)
  it("rate cap by credit", function()
    local f=fixture("yellow"); f.invs[1]=inventory({{name="iron",quality="normal",count=100}}); f.rec.invs=f.invs
    ledger.plan=function(_,lane) local a={}; for i=1,100 do a[i]={name="iron",quality="normal",count=1} end; return lane==1 and a or {} end
    for t=1,40 do f.rec.next_poll=0; f.run(t) end
    ok(#f.invs[1].removes<=0.125*40+1); f.restore()
  end)
  it("passes rules to ledger", function()
    local f=fixture(); f.rec.settings.filters={{name="iron"}}; f.invs[1]=inventory({{name="iron",quality="normal",count=4}}); f.rec.invs=f.invs
    ledger.plan=function(_,lane,contents,opts) if lane==1 then f.seen=opts end; return {} end
    circuit.evaluate=function() return true,true end; f.run(1); local o=f.seen
    eq(o.tick,1); eq(o.bss,4); eq(o.timeout_ticks,0); eq(o.slots,N.STORE_SLOTS); eq(o.slots_used,1); eq(o.flush_all,true); ok(o.skip("iron","normal")); eq(o.stack_size("iron"),100); f.restore()
  end)
  it("circuit off pauses both lanes", function()
    local f=fixture(); circuit.evaluate=function() return false,false end; f.run(1); eq(f.pauses,{{1,true},{2,true}}); eq(#f.pushes,0); while #f.pauses>0 do table.remove(f.pauses) end; circuit.evaluate=function() return true,false end; f.rec.next_poll=0; f.run(9); eq(f.pauses,{{1,false},{2,false}}); f.restore()
  end)
  it("hoard kinds go to arms", function()
    local f=fixture(); f.invs[1]=inventory({{name="iron",quality="normal",count=100}}); f.rec.invs=f.invs; f.run(1); eq(f.skips,{{1,{{name="iron",quality="normal"}}},{2,{}}}); f.restore()
  end)
  it("extra leaves first and pauses its lane", function()
    local f=fixture(); f.rec.extra={{name="iron",quality="normal",count=9,lane=1}}; f.boxinv.contents={{name="iron",quality="normal",count=9}}; f.rec.out_credit[1]=4; belt_io.lane_rate=function() return 4 end
    local got={}; belt_io.push=function(r,l,p,bss) got[#got+1]={lane=l,count=p.count,source=p.name=="iron" and f.boxinv or f.invs[l]}; return p.count end
    f.invs[1]=inventory({{name="copper",quality="normal",count=4}}); f.rec.invs=f.invs
    ledger.plan=function(_,lane) return lane==1 and {{name="copper",quality="normal",count=4}} or {} end
    f.run(1); eq(got[1],{lane=1,count=4,source=f.boxinv}); eq(got[2],{lane=1,count=4,source=f.boxinv}); eq(got[3],{lane=1,count=1,source=f.boxinv}); eq(got[4].source,f.invs[1]); eq(f.rec.extra,nil); eq(f.pauses,{{1,true},{1,false}}); f.restore()
  end)
  it("led from used slots", function()
    local f=fixture(); f.invs[1]=inventory({{name="iron",quality="normal",count=1}}); f.rec.invs=f.invs; f.run(1); eq(f.ledcalls,{{"yellow",true}}); f.rec.next_poll=0; f.run(9); eq(#f.ledcalls,1); f.restore()
  end)
  it("empty box sleeps 15 ticks", function() local f=fixture(); f.run(1); eq(f.rec.next_poll,16); f.restore() end)
  it("sleeping box costs no engine read", function()
    local f=fixture(); f.rec.next_poll=100; local reads=0; f.rec.entity=setmetatable({}, {__index=function() reads=reads+1; error("unexpected engine read") end}); for t=1,50 do f.run(t) end; eq(reads,0); f.restore()
  end)
  it("unmigrated rec skipped", function() local f=fixture(); f.rec.stores=nil; local calls=0; circuit.evaluate=function() calls=calls+1; return true,false end; f.run(1); eq(calls,0); eq(#f.pushes,0); f.restore() end)
  it("counters", function()
    local f=fixture(); f.invs[1]=inventory({{name="iron",quality="normal",count=2}}); f.rec.invs=f.invs; f.rec.out_credit={1,0}; storage.sp_counters={visits=0,reads=0,pulls=0,pushes=0,items_in=0,items_out=0}
    ledger.plan=function(_,lane) return lane==1 and {{name="iron",quality="normal",count=2}} or {} end
    f.run(1); eq(storage.sp_counters,{visits=1,reads=0,pulls=0,pushes=1,items_in=2,items_out=2}); f.restore()
  end)
end)

describe("tick", function()
  it("timeout ticks custom and global", function() local r=fixture().rec; r.settings.timeout_mode="custom"; r.settings.timeout_s=3; eq(tick.timeout_ticks(r),180); r.settings.timeout_mode="global"; settings.global[N.SETTING_TIMEOUT].value=7; eq(tick.timeout_ticks(r),420) end)
  it("on research caches belt stack size", function() local f=fixture(); local old=belt_io.belt_stack_size; belt_io.belt_stack_size=function(x) return x.index+2 end; tick.on_research({force={index=4}}); eq(storage.belt_stack[4],6); belt_io.belt_stack_size=old; f.restore() end)
  it("invalid entity drops rec", function() local f=fixture(); f.rec.entity.valid=false; f.run(1); eq(storage.boxes[1],nil); f.restore() end)
  it("decon stops visits and pauses arms", function() local f=fixture(); tick.on_decon({entity=f.rec.entity},true); f.run(1); eq(#f.pushes,0); eq(f.pauses,{{1,true},{2,true}}); eq(f.ledcalls[#f.ledcalls],{"green",false}); f.restore() end)
  -- integrator, v15 INT (red first): gaps seen at merge review + first headless run
  it("decon mark pauses both lanes without a visit", function()
    local f=fixture(); f.rec.next_poll=1000; f.rec.last_poll=0
    tick.on_decon({entity=f.rec.entity},true); f.run(5)
    eq(f.pauses,{{1,true},{2,true}}); f.restore()
  end)
  it("items put into box from outside become extra on lane one", function()
    local f=fixture(); f.rec.unit_number=1; f.rec.next_poll=1000; f.rec.last_poll=0
    f.boxinv.contents={{name="iron",quality="normal",count=5}}
    f.block_after(1)  -- front belt blocked: extra stays visible
    f.run(59)  -- (59 + unit 1) % 60 == 0: slot
    eq(f.rec.extra,{{name="iron",quality="normal",count=5,lane=1}}); eq(f.pauses[1],{1,true})  -- visited same tick, lane 1 paused
    f.boxinv.contents={{name="iron",quality="normal",count=7}}; f.rec.next_poll=1000; f.block_after(#f.pushes+1)
    f.run(119); eq(f.rec.extra,{{name="iron",quality="normal",count=7,lane=1}}); f.restore()
  end)
  it("empty box container costs one cheap check per slot", function()
    local f=fixture(); f.rec.next_poll=1000; f.rec.last_poll=0
    for t=1,120 do f.run(t) end
    eq(f.boxinv.reads,0); eq(f.rec.extra,nil); f.restore()
  end)
  it("visit gap follows belt item gap", function()
    tick._reset_intervals(); prototypes={entity=require("tests.offline.belts")}; eq(tick._interval("yellow"),8); eq(tick._interval("red"),4); eq(tick._interval("blue"),1); eq(tick._interval("turbo"),2)
  end)
end)
