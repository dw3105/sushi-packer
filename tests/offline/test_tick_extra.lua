local belt_io=require("scripts.belt_io")
local tick=require("scripts.tick")
local circuit=require("scripts.circuit")
local led=require("scripts.led")
local ledger=require("scripts.ledger")
local N=require("scripts.names")

describe("tick extra",function()
  it("lane rate is belt speed times 4",function()
    belt_io._reset_rates(); prototypes={entity={["turbo-transport-belt"]={belt_speed=0.125},["kr-superior-transport-belt"]={belt_speed=0.1875}}}
    eq(belt_io.lane_rate("turbo"),0.5); eq(belt_io.lane_rate("kr-superior"),0.75)
  end)
  it("missing belt prototype falls back to table rate",function()
    belt_io._reset_rates(); prototypes={entity={}}; eq(belt_io.lane_rate("turbo"),0.5); eq(belt_io.lane_rate("kr-superior"),0)
  end)
  it("modded vanilla speed followed",function()
    belt_io._reset_rates(); prototypes={entity={["transport-belt"]={belt_speed=0.0625}}}; eq(belt_io.lane_rate("yellow"),0.25)
  end)

  local function fixture(tier,belt_name,speed)
    local arms=require("scripts.arms")
    local old={push=belt_io.push,rate=belt_io.lane_rate,eval=circuit.evaluate,set=led.set,plan=ledger.plan,hoard=ledger.hoard,led=ledger.led,pause_out=arms.pause_out}
    belt_io._reset_rates(); defines={inventory={chest=1},gui_type={entity=1}}
    settings={global={[N.SETTING_TIMEOUT]={value=0}}}
    prototypes={entity={[belt_name]={belt_speed=speed}},item={iron={stack_size=100}},quality={normal={level=0}}}
    local inv={items={{name="iron",quality="normal",count=3000}}}
    function inv.get_contents() local a={}; for i,x in ipairs(inv.items) do a[i]={name=x.name,quality=x.quality,count=x.count} end; return a end
    function inv.is_empty() return #inv.items==0 end
    function inv.count_empty_stacks() return 11 end
    function inv.remove(x) local y=inv.items[1]; if not y then return 0 end; local n=math.min(x.count,y.count); y.count=y.count-n; return n end
    setmetatable(inv,{__len=function() return 12 end})
    local inv2={get_contents=function() return {} end,is_empty=function() return true end,count_empty_stacks=function() return 12 end,remove=function() return 0 end}
    setmetatable(inv2,{__len=function() return 12 end})
    local emptybox={is_empty=function() return true end,get_contents=function() return {} end}
    tick._reset_intervals()
    local rec={entity={valid=true,unit_number=1,force={index=1},get_inventory=function() return emptybox end},unit_number=1,tier=tier,settings={filters={{name="__never__"}},circuit={},timeout_mode="global",timeout_s=0},stores={{valid=true},{valid=true}},invs={inv,inv2},arms={{},{}},paused={false,false},skip={"",""},ledger=ledger.new(),out_credit={0,0},next_poll=0,last_poll=0,led={state="green",visible=true}}
    arms.pause_out=function() end
    belt_io.can_push=function() return true end  -- v15 perf (never restored: every case in this file fakes it)
    belt_io.push=function(r,l,p) r.pushed=(r.pushed or 0)+p.count; return p.count end
    circuit.evaluate=function() return true,false end
    ledger.plan=function(state,lane,contents)
      local out={}; if lane==1 and contents[1] then for _=1,contents[1].count do out[#out+1]={name="iron",quality="normal",count=1} end end; return out
    end
    ledger.hoard=function() return {} end; ledger.led=function() return "yellow" end; led.set=function(r,s,v) r.led={state=s,visible=v} end
    storage={boxes={[1]=rec},belt_stack={[1]=1}}; game={connected_players={}}
    return rec,function() belt_io.push=old.push; belt_io.lane_rate=old.rate; circuit.evaluate=old.eval; led.set=old.set; ledger.plan=old.plan; ledger.hoard=old.hoard; ledger.led=old.led; arms.pause_out=old.pause_out end
  end

  local function rate_case(tier,name,speed,expected,title)
    it(title,function()
      local rec,restore=fixture(tier,name,speed)
      for t=1,800 do tick.on_tick({tick=t}) end
      if expected<=800 then ok(rec.pushed>=expected-2,tier.." below rate") end
      ok(rec.pushed<=expected+2,tier.." exceeded rate"); restore()
    end)
  end
  rate_case("planetaris-hyper","planetaris-hyper-transport-belt",0.15625,500,"75 per s tier keeps rate over 800 ticks")
  rate_case("kr-superior","kr-superior-transport-belt",0.1875,600,"90 per s tier keeps rate over 800 ticks")
  rate_case("ub-ultimate","ultimate-belt",0.5625,1800,"270 per s tier keeps rate over 800 ticks")
  it("extra tier visits every tick",function()  -- v15 INT: 0.25 / 0.1875 = 1.33 ticks per belt item, not whole -> gap 1
    local rec,restore=fixture("kr-superior","kr-superior-transport-belt",0.1875)
    tick.counters_on()
    for t=1,10 do tick.on_tick({tick=t}) end
    eq(tick.counters().visits,10); storage.sp_counters=nil; restore()  -- v15 perf: plan is not called on a visit that cannot push
  end)
end)
