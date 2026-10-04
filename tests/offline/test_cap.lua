local N=require("scripts.names")
local tick=require("scripts.tick")
local belt=require("scripts.belt_io")
local circuit=require("scripts.circuit")
local arms=require("scripts.arms")
local led=require("scripts.led")

local function inventory(items)
  local x={items=items or {},reads=0}
  function x.get_contents() x.reads=x.reads+1; local out={}; for i,v in ipairs(x.items) do out[i]={name=v.name,quality=v.quality,count=v.count} end; return out end
  function x.count_empty_stacks() return 24-#x.items end
  function x.remove() return 0 end
  function x.is_empty() return #x.items==0 end
  return setmetatable(x,{__len=function() return 24 end})
end
local function arm()
  local a={valid=true,filters={},writes=0}
  function a.set_filter(i,v) a.writes=a.writes+1; a.filters[i]=v end
  return a
end
local function fixture(items)
  defines={inventory={chest=1},gui_type={entity=1}}
  storage={boxes={},belt_stack={[1]=4}}
  settings={global={[N.SETTING_TIMEOUT]={value=0}}}
  prototypes={item={iron={stack_size=50},copper={stack_size=50}},quality={normal={level=0},uncommon={level=1}},entity=require("tests.offline.belts")}
  game={connected_players={}}
  script={feature_flags={space_travel=true}}
  local invs={inventory(items),inventory()}
  local rec={unit_number=1,tier="yellow",settings={filters={},circuit={},timeout_mode="global",timeout_s=0},entity={valid=true,unit_number=1,force={index=1}},stores={{valid=true},{valid=true}},invs=invs,arms={{arm()},{arm()}},mop={{arm()},{arm()}},out={{},{}},paused={false,false},out_paused={false,false},skip={"",""},ledger=require("scripts.ledger").new(),enabled=true,used={0,0},led={state="green",visible=true}}
  storage.boxes[1]=rec
  local saved={front=belt.front_kind,front_ok=belt.front_ok,can=belt.can_push,push=belt.push,behind=belt.behind_kinds,eval=circuit.evaluate,pause=arms.pause,pause_out=arms.pause_out,hand=arms.hand,aim=arms.aim_out,set=led.set}
  belt.front_kind=function() return "ahead" end; belt.front_ok=function() return true end
  belt.can_push=function() return true end; belt.push=function() return 0 end; belt.behind_kinds=function() return {} end
  circuit.evaluate=function() return true,false end; arms.pause=function() end; arms.pause_out=function() end; arms.hand=function() end; arms.aim_out=function() end; led.set=function() end
  local f={rec=rec,invs=invs}
  function f.run(t) tick.on_tick({tick=t or 29}) end
  function f.restore() belt.front_kind=saved.front; belt.front_ok=saved.front_ok; belt.can_push=saved.can; belt.push=saved.push; belt.behind_kinds=saved.behind; circuit.evaluate=saved.eval; arms.pause=saved.pause; arms.pause_out=saved.pause_out; arms.hand=saved.hand; arms.aim_out=saved.aim; led.set=saved.set end
  return f
end
local function allarms(f,lane) local a={}; for _,x in ipairs(f.rec.arms[lane]) do a[#a+1]=x end; for _,x in ipairs(f.rec.mop[lane]) do a[#a+1]=x end; return a end

describe("cap",function()
  it("engine look blocks kind at one stack",function() local f=fixture({{name="iron",quality="normal",count=50}}); f.run(); for _,a in ipairs(allarms(f,1)) do eq(a.use_filters,true); eq(a.inserter_filter_mode,"blacklist"); eq(a.filters[1],{name="iron",quality="normal",comparator="="}) end; f.restore() end)
  it("frees at half",function() local f=fixture({{name="iron",quality="normal",count=50}}); f.run(29); f.invs[1].items[1].count=26; f.run(59); eq(f.rec.arms[1][1].use_filters,true); f.invs[1].items[1].count=25; f.run(89); eq(f.rec.arms[1][1].use_filters,false); f.restore() end)
  it("blocked kind written to in arms and mop arms",function() local f=fixture({{name="iron",quality="normal",count=50}}); f.run(); eq(f.rec.mop[1][1].filters[1],{name="iron",quality="normal",comparator="="}); f.restore() end)
  it("no write when blocked set unchanged",function() local f=fixture({{name="iron",quality="normal",count=50}}); tick.counters_on(); f.run(29); local writes=0; for _,a in ipairs(allarms(f,1)) do writes=writes+a.writes end; f.run(59); local second=0; for _,a in ipairs(allarms(f,1)) do second=second+a.writes end; eq(second,writes); eq(tick.counters().filter_writes,1); f.restore() end)
  it("lanes independent",function() local f=fixture({{name="iron",quality="normal",count=50}}); f.invs[2].items={{name="copper",quality="normal",count=10}}; f.run(); eq(f.rec.arms[1][1].use_filters,true); eq(f.rec.arms[2][1].use_filters,nil); f.restore() end)
  it("quality is own kind",function() local f=fixture({{name="iron",quality="normal",count=50},{name="iron",quality="uncommon",count=10}}); f.run(); eq(f.rec.arms[1][1].filters[1],{name="iron",quality="normal",comparator="="}); eq(f.rec.arms[1][1].filters[2],nil); f.restore() end)
  it("look reads contents once per lane",function() local f=fixture({{name="iron",quality="normal",count=1}}); f.run(); eq({f.invs[1].reads,f.invs[2].reads},{1,1}); f.restore() end)
  it("stopped packer keeps cap",function() local f=fixture({{name="iron",quality="normal",count=50}}); f.rec.enabled=false; f.run(); eq(f.rec.arms[1][1].use_filters,true); f.restore() end)
end)
