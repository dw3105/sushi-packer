local N=require("scripts.names")
local tick=require("scripts.tick")
local belt=require("scripts.belt_io")
local circuit=require("scripts.circuit")
local ledger=require("scripts.ledger")
local arms=require("scripts.arms")
local led=require("scripts.led")

local function inv(contents)
  local x={items=contents or {},reads=0,removed={}}
  function x.get_contents() x.reads=x.reads+1; local a={}; for i,v in ipairs(x.items) do a[i]={name=v.name,quality=v.quality,count=v.count} end; return a end
  function x.count_empty_stacks() return 12-#x.items end
  function x.remove(v) x.removed[#x.removed+1]=v; return v.count end
  x.inserted={}; x.room=1000
  function x.insert(v) local n=math.min(v.count,x.room); x.inserted[#x.inserted+1]={name=v.name,quality=v.quality,count=v.count}; return n end
  function x.is_empty() return #x.items==0 end
  return setmetatable(x,{__len=function() return 12 end})
end
local function fixture()
  defines={inventory={chest=1},gui_type={entity=1}}
  storage={boxes={},belt_stack={[1]=4}}
  settings={global={[N.SETTING_TIMEOUT]={value=7}}}
  prototypes={item={iron={stack_size=100},gear={stack_size=100}},quality={normal={level=0}},entity=require("tests.offline.belts")}
  game={connected_players={}}
  local box=inv()
  local rec={entity={valid=true,unit_number=30,force={index=1},get_inventory=function() return box end},unit_number=30,tier="yellow",settings={filters={},circuit={},timeout_mode="global",timeout_s=0},stores={{valid=true},{valid=true}},invs={inv(),inv()},arms={{},{}},out={{},{}},paused={false,false},out_paused={false,false},skip={"",""},ledger=ledger.new(),used={0,0},out_credit={0,0},next_poll=0,last_poll=0,extra=nil,led={state="green",visible=true}}
  storage.boxes[30]=rec
  local orig={front=belt.front_ok,can=belt.can_push,push=belt.push,bss=belt.belt_stack_size,eval=circuit.evaluate,scan=ledger.scan,hands=ledger.hands,plan=ledger.plan,hoard=ledger.hoard,pause=arms.pause,pause_out=arms.pause_out,hand=arms.hand,held=arms.held,clear=arms.clear_held,skip=arms.skip,need=arms.need_slot,behind=belt.behind_kinds,led=ledger.led,set=led.set}
  local f={hand_merges={},rec=rec,box=box,pushes={},scans={},evals=0,plans=0,hoards=0,pauses={},outs={},hands={},held_calls={},clears={},skips={},need_calls={},ledcalls={},front=true,enabled=true,flush=false,flushes={{},{}},wants={false,false},held_values={{},{}},hand_indices={{},{}},can_pushes=0}
  belt.front_ok=function() return f.front end; belt.can_push=function() f.can_pushes=f.can_pushes+1; return true end
  belt.belt_stack_size=function() return 4 end
  belt.push=function(r,l,p,bss) f.pushes[#f.pushes+1]={lane=l,piece={name=p.name,quality=p.quality,count=p.count},bss=bss}; if f.fail_at==#f.pushes then return 0 end; return p.count end
  circuit.evaluate=function() f.evals=f.evals+1; return f.enabled,f.flush end
  ledger.scan=function(state,lane,contents,opts) local copy={}; for k,v in pairs(opts) do copy[k]=v end; f.scans[#f.scans+1]={lane=lane,contents=contents,opts=opts,snapshot=copy}; return f.flushes[lane],f.wants[lane] end
  ledger.hands=function(state,lane,held,opts) f.hands[#f.hands+1]={lane=lane,held=held,opts=opts}; return f.hand_indices[lane] or {}, f.hand_merges[lane] or {} end
  ledger.plan=function() f.plans=f.plans+1; return {} end; ledger.hoard=function() f.hoards=f.hoards+1; return {} end
  arms.pause=function(r,l,p) f.pauses[#f.pauses+1]={l,p} end
  arms.pause_out=function(r,l,p) f.outs[#f.outs+1]={l,p} end
  arms.hand=function(r,n) f.hand_size=n end
  arms.held=function(r,l) f.held_calls[#f.held_calls+1]=l; return f.held_values[l] end
  arms.clear_held=function(r,l,k) f.clears[#f.clears+1]={l,k} end
  arms.skip=function(r,l,k) f.skips[#f.skips+1]={l,k} end
  arms.need_slot=function(r,l,c) f.need_calls[#f.need_calls+1]=l; return l==1 end
  belt.behind_kinds=function() return {} end
  ledger.led=function(a,b) return a+b==0 and "green" or "yellow" end
  led.set=function(r,s,v) f.ledcalls[#f.ledcalls+1]={s,v}; r.led={state=s,visible=v} end
  function f.run(t) tick.on_tick({tick=t}) end
  function f.restore() belt.front_ok=orig.front; belt.can_push=orig.can; belt.push=orig.push; belt.belt_stack_size=orig.bss; belt.behind_kinds=orig.behind; circuit.evaluate=orig.eval; ledger.scan=orig.scan; ledger.hands=orig.hands; ledger.plan=orig.plan; ledger.hoard=orig.hoard; ledger.led=orig.led; arms.pause=orig.pause; arms.pause_out=orig.pause_out; arms.hand=orig.hand; arms.held=orig.held; arms.clear_held=orig.clear; arms.skip=orig.skip; arms.need_slot=orig.need; led.set=orig.set end
  return f
end

describe("tick look",function()
  it("engine box is looked at once per N.LOOK ticks",function() local f=fixture(); for t=1,29 do f.run(t) end; eq(f.evals,0); eq(f.rec.invs[1].reads,0); f.run(30); eq(f.evals,1); eq(f.rec.invs[1].reads,1); eq(f.rec.invs[2].reads,1); f.restore() end)
  it("look never plans or hoards",function() local f=fixture(); f.run(30); eq(f.plans,0); eq(f.hoards,0); eq(#f.pushes,0); f.restore() end)
  it("look sets hand and pauses",function()
    local f=fixture(); f.run(30); eq(f.hand_size,4); eq(f.pauses,{{1,false},{2,false}}); eq(f.outs,{{1,false},{2,false}})
    f.pauses={}; f.outs={}; f.enabled=false; f.run(60); eq(f.pauses,{{1,true},{2,true}}); eq(f.outs,{{1,true},{2,true}}); eq(f.rec.invs[1].reads,2, "stopped box still reads store for LED (INT)"); eq(#f.scans,2, "no scan while circuit is off")
    f.pauses={}; f.outs={}; f.enabled=true; f.rec.decon=true; f.run(90); eq(f.outs,{{1,true},{2,true}}); f.rec.decon=false
    f.pauses={}; f.outs={}; f.front=false; f.run(120); eq(f.pauses,{{1,false},{2,false}}); eq(f.outs,{{1,true},{2,true}}); f.restore()
  end)
  it("scan gets contents and options",function() local f=fixture(); f.run(30); local x=f.scans[1]; eq(x.lane,1); eq(x.snapshot.tick,30); eq(x.snapshot.bss,4); eq(x.snapshot.timeout_ticks,420); eq(x.snapshot.slots,N.STORE_SLOTS); eq(x.snapshot.n_out,0); ok(type(x.snapshot.stack_size)=="function"); eq(f.scans[2].lane,2); f.restore() end)
  it("flush pieces are pushed and removed",function() local f=fixture(); f.flushes[1]={{name="iron",quality="normal",count=3},{name="gear",quality="normal",count=1}}; f.run(30); eq(#f.pushes,2); eq(#f.rec.invs[1].removed,2); f.restore(); local g=fixture(); g.flushes[1]={{name="iron",quality="normal",count=3},{name="gear",quality="normal",count=1}}; g.fail_at=1; g.run(30); eq(#g.pushes,1); eq(#g.rec.invs[1].removed,0); g.restore() end)
  it("hands are read only when wanted",function() local f=fixture(); f.run(30); eq(#f.held_calls,0); f.wants[1]=true; f.held_values[1]={{arm=2,name="iron",quality="rare",count=2},{arm=5,name="gear",quality="normal",count=1}}; f.hand_indices[1]={2,5}; f.run(60); eq(f.held_calls,{1}); eq(#f.hands,1); eq(f.pushes[1].piece,{name="iron",quality="rare",count=2}); eq(f.clears,{{1,2},{1,5}}); f.restore(); local g=fixture(); g.wants[1]=true; g.held_values[1]={{arm=2,name="iron",quality="rare",count=2}}; g.hand_indices[1]={2}; g.fail_at=1; g.run(30); eq(#g.clears,0); g.restore() end)
  it("need_slot only asked when store is full",function() local f=fixture(); local contents={}; for i=1,12 do contents[i]={name="iron",quality="q"..i,count=4} end; f.rec.invs[1]=inv(contents); f.rec.invs[1].count_empty_stacks=function() return 0 end; f.run(30); eq(f.need_calls,{1}); eq(f.scans[1].snapshot.need_slot,true); f.restore() end)
  it("extra items leave first",function() local f=fixture(); f.rec.extra={{name="iron",quality="normal",count=5,lane=1}}; f.rec.next_poll=0; f.run(1); eq(f.outs[1],{1,true}); eq(#f.scans,1); eq(f.scans[1].lane,2); f.restore() end)
  it("led and used slots",function() local f=fixture(); f.rec.invs[1]=inv({{name="iron",quality="normal",count=5}}); f.run(30); eq(f.rec.used[1],1); eq(f.ledcalls,{{"yellow",true}}); f.restore() end)
  it("mode switch",function() local f=fixture(); f.run(30); f.rec.settings.filters={{name="iron"}}; f.rec.next_poll=30; f.run(31); eq(f.outs[#f.outs],{2,true}); f.rec.settings.filters={}; f.skips={}; f.run(60); eq(f.skips,{{1,{}},{2,{}}}); eq(f.outs[#f.outs],{2,false}); f.restore() end)
  it("look reuses option table",function() local f=fixture(); f.run(30); local o=f.scans[1].opts; f.run(60); eq(f.scans[3].opts,o); f.restore() end)
  it("merge pushes one full stack clears hands and returns rest to store",function()
    local f=fixture(); f.wants[1]=true
    f.held_values[1]={{arm=1,name="iron",quality="normal",count=2},{arm=3,name="iron",quality="normal",count=3},{arm=4,name="gear",quality="normal",count=1}}
    f.hand_merges[1]={{name="iron",quality="normal",total=5,arms={1,3}}}; f.hand_indices[1]={4}
    f.run(30)
    eq(f.pushes[1].piece,{name="iron",quality="normal",count=4}); eq(f.pushes[2].piece,{name="gear",quality="normal",count=1})
    eq(f.clears,{{1,1},{1,3},{1,4}}); eq(f.rec.invs[1].inserted,{{name="iron",quality="normal",count=1}})
    f.restore()
  end)
  it("merge does nothing when belt refuses",function()
    local f=fixture(); f.wants[1]=true; f.fail_at=1
    f.held_values[1]={{arm=1,name="iron",quality="normal",count=2},{arm=3,name="iron",quality="normal",count=3}}
    f.hand_merges[1]={{name="iron",quality="normal",total=5,arms={1,3}}}
    f.run(30); eq(#f.clears,0); eq(#f.rec.invs[1].inserted,0); f.restore()
  end)
  it("merge rest that store refuses goes to box container",function()
    local f=fixture(); f.wants[1]=true; f.rec.invs[1].room=0
    f.held_values[1]={{arm=1,name="iron",quality="normal",count=3},{arm=3,name="iron",quality="normal",count=3}}
    f.hand_merges[1]={{name="iron",quality="normal",total=6,arms={1,3}}}
    f.run(30); eq(f.rec.entity.get_inventory().inserted,{{name="iron",quality="normal",count=2}}); f.restore()
  end)
  it("stopped box still counts used slots for led",function()
    local f=fixture(); f.front=false; f.rec.invs[1]=inv({{name="iron",quality="normal",count=5}})
    f.run(30); eq(f.rec.used[1],1); eq(#f.scans,0); eq(f.ledcalls,{{"yellow",true}}); f.restore()
  end)
  it("items waiting in out arm hands keep led yellow",function()
    local f=fixture(); f.wants[1]=true; f.held_values[1]={{arm=2,name="iron",quality="normal",count=2}}
    f.run(30); eq(f.rec.hands[1],1); eq(f.ledcalls,{{"yellow",true}})
    f.held_values[1]={}; f.run(60); eq(f.rec.hands[1],0); eq(f.ledcalls[#f.ledcalls],{"green",true}); f.restore()
  end)
  it("no space travel flag and belt stack above 1: script path stacks, out arms paused",function()
    -- out arms can not stack without the feature flag (engine refuses the prototype fields), script insert can (FND-0047)
    local f=fixture(); script={feature_flags={space_travel=false}}; tick._reset_flags()
    f.rec.next_poll=0; f.rec.last_poll=0; f.rec.invs[1]=inv({{name="iron",quality="normal",count=5}}); f.run(1)
    eq(f.outs,{{1,true},{2,true}}); ok(f.plans>0, "script path planned"); eq(#f.scans,0)
    storage.belt_stack[1]=1; f.outs={}; f.plans=0; f.run(30)
    eq(#f.scans,2, "belt stack 1: engine path needs no stacking"); eq(f.plans,0)
    script=nil; tick._reset_flags(); f.restore()
  end)
  it("counters count looks",function() local f=fixture(); tick.counters_on(); f.run(30); eq(storage.sp_counters.visits,1); f.restore() end)
end)
