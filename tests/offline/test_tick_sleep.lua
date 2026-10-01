local N=require("scripts.names")
local tick=require("scripts.tick")
local belt_io=require("scripts.belt_io")
local circuit=require("scripts.circuit")
local led=require("scripts.led")
local ledger=require("scripts.ledger")
local arms=require("scripts.arms")

local function inv()
  local x={reads=0,items={}}
  function x.is_empty() return #x.items==0 end
  function x.get_contents() x.reads=x.reads+1; return {} end
  function x.remove() return 0 end
  function x.count_empty_stacks() return 12 end
  return setmetatable(x,{__len=function() return 12 end})
end
local function fixture(unit,tier,due)
  defines={inventory={chest=1},gui_type={entity=1}}
  storage={boxes={},belt_stack={[1]=1}}
  settings={global={[N.SETTING_TIMEOUT]={value=0}}}
  prototypes={item={iron={stack_size=100}},quality={normal={level=0}},entity=require("tests.offline.belts")}
  game={connected_players={}}
  local reads,data={}, {valid=true,unit_number=unit,force={index=1}}
  local entity=setmetatable({}, {__index=function(_,k) reads[k]=(reads[k] or 0)+1; return data[k] end})
  local invs={inv(),inv()}
  local rec={entity=entity,unit_number=unit,tier=tier or "yellow",dir="north",settings={filters={{name="__never__"}},circuit={},timeout_mode="global",timeout_s=0},stores={{valid=true},{valid=true}},invs=invs,arms={{},{}},paused={false,false},skip={"",""},ledger=ledger.new(),out_credit={0,0},next_poll=due or 0,last_poll=0,led={state="green",visible=true}}
  storage.boxes[unit]=rec
  local original={push=belt_io.push,rate=belt_io.lane_rate,eval=circuit.evaluate,set=led.set,plan=ledger.plan,pause_out=arms.pause_out}
  local plans,ledcalls={},{}
  belt_io.can_push=function() return true end  -- v15 perf
  arms.pause_out=function() end
  belt_io.push=function() return 0 end
  belt_io.lane_rate=function() return 0.125 end
  circuit.evaluate=function() return true,false end
  ledger.plan=function(_,lane,contents,opts) plans[#plans+1]={lane=lane,tick=opts.tick}; return {} end
  led.set=function(r,s,v) ledcalls[#ledcalls+1]={state=s,visible=v}; r.led={state=s,visible=v} end
  local function restore() belt_io.push=original.push; belt_io.lane_rate=original.rate; circuit.evaluate=original.eval; led.set=original.set; ledger.plan=original.plan; arms.pause_out=original.pause_out end
  return rec,invs,reads,plans,ledcalls,restore,function(v) data.valid=v end
end
local function run(t) tick.on_tick({tick=t}) end

describe("tick sleep",function()
  it("sleeping box costs no engine read",function()
    local r,invs,reads,plans,lc,restore=fixture(9,"yellow",1000)
    for t=1,50 do run(t) end
    local total=0; for _,n in pairs(reads) do total=total+n end
    eq(total,0); eq(invs[1].reads,0); eq(#plans,0); eq(#lc,0); restore()
  end)
  it("due box visits stores at due tick",function()
    local r,invs,reads,plans,lc,restore=fixture(100,"yellow",7)
    for t=1,8 do run(t) end
    eq(plans,{{lane=1,tick=7},{lane=2,tick=7}}); restore()
  end)
  it("decon mark hides led same tick",function()
    local r,invs,reads,plans,lc,restore=fixture(5,"yellow",1000)
    tick.on_decon({entity=r.entity},true); run(1); eq(lc[#lc].visible,false)
    tick.on_decon({entity=r.entity},false); run(2); eq(lc[#lc].visible,true); restore()
  end)
  it("invalid entity dropped when due",function()
    local r,invs,reads,plans,lc,restore,invalidate=fixture(5,"yellow",5)
    invalidate(false); for t=1,4 do run(t) end; eq(storage.boxes[5],r); run(5); eq(storage.boxes[5],nil); restore()
  end)
  it("led set only on state change",function()
    local r,invs,reads,plans,lc,restore=fixture(9,"turbo",0)
    r.led.state="red"
    for t=1,10 do r.next_poll=t-1; run(t) end
    eq(#lc,1); restore()
  end)
end)
