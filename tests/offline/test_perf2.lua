local belt_io = require("scripts.belt_io")
local core = require("scripts.core")
local tick = require("scripts.tick")
local circuit = require("scripts.circuit")
local led = require("scripts.led")
local N = require("scripts.names")

describe("perf2", function()
  local function fake_line(stacks, at_exit)
    local line = { removed = {} }
    setmetatable(line, {
      __len = function() return #stacks end,
      __index = function(_, i) return stacks[i] end,
    })
    function line.can_insert_at(pos) return not (pos == 0 and at_exit) end
    function line.remove_item(x) line.removed[#line.removed + 1] = x; return x.count end
    function line.get_detailed_contents() error("detailed contents must not be read") end
    return line
  end
  local function pull_rec(line)
    defines = { direction = {north=0,east=4,south=8,west=12} }; game = {tick=1}
    local belt = {valid=true,type="transport-belt",direction=0}
    function belt.get_transport_line() return line end
    local entity = {valid=true,position={x=0,y=0},surface={find_entities_filtered=function() return {belt} end}}
    return {entity=entity,dir="north"}
  end

  it("pull reads front item without detailed contents", function()
    local line=fake_line({{name="iron",count=1,quality={name="normal"}}},false)
    local calls=0; belt_io.pull(pull_rec(line),{1,0},function() calls=calls+1; return 1 end)
    eq(calls,1)
  end)
  it("pull skips lane when no item at exit", function()
    local line=fake_line({{name="iron",count=1,quality={name="normal"}}},true)
    local calls=0; belt_io.pull(pull_rec(line),{1,0},function() calls=calls+1; return 1 end)
    eq(calls,0)
  end)
  it("pull removes only accepted part of front item", function()
    local line=fake_line({{name="iron",count=5,quality={name="rare"}}},false)
    belt_io.pull(pull_rec(line),{1,0},function(name,q,lane,count) eq({name,q,lane,count},{"iron","rare",1,5}); return 2 end)
    eq(line.removed,{{name="iron",count=2,quality="rare"}})
  end)

  it("stack size looked up once per item name", function()
    local old={pull=belt_io.pull,push=belt_io.push,bss=belt_io.belt_stack_size,evaluate=circuit.evaluate,set=led.set}
    defines={inventory={chest=1},direction={north=0,east=4,south=8,west=12},wire_connector_id={circuit_red=1,circuit_green=2}}
    settings={global={[N.SETTING_TIMEOUT]={value=0}}}; local lookups=0
    prototypes={item=setmetatable({}, {__index=function(_,name) lookups=lookups+1; return {stack_size=100} end})}
    local rec={entity={valid=true,unit_number=7,position={x=0,y=0},force={index=1,belt_stack_size_bonus=0},get_inventory=function() return {get_contents=function() return {} end,insert=function(x) return x.count end} end},unit_number=7,tier="yellow",dir="north",box=core.new_box(),settings={timeout_mode="global",filters={},circuit={}},enabled=true,in_credit={0,0},out_credit={0,0},next_poll=0}
    belt_io.pull=function(_,_,sink) sink("iron","normal",1,1); sink("iron","normal",1,1); return {0,0} end
    belt_io.push=function(_,_,item) return item.count end; belt_io.belt_stack_size=function() return 1 end
    circuit.evaluate=function() return true,false end; led.set=function() end
    storage={boxes={[7]=rec},belt_stack={[1]=1}}; game={connected_players={}}
    tick.on_tick({tick=7}); eq(lookups,1)
    belt_io.pull=old.pull; belt_io.push=old.push; belt_io.belt_stack_size=old.bss; circuit.evaluate=old.evaluate; led.set=old.set
  end)

  it("core finds partial by key with 47 others present", function()
    local b=core.new_box()
    for i=1,47 do core.accept(b,"item-"..i,"normal",1,1,100,1,false) end
    core.accept(b,"target","normal",2,1,100,1,false)
    core.accept(b,"target","normal",2,1,100,2,false)
    local found=0; for _,p in ipairs(b.partials) do if p.name=="target" and p.lane==2 then found=p.count end end
    eq(found,2); eq(b.partial_by_key["target\0normal\0"..2].count,2)
  end)

  it("led set skipped when unchanged", function()
    local old={pull=belt_io.pull,push=belt_io.push,bss=belt_io.belt_stack_size,evaluate=circuit.evaluate,set=led.set}
    defines={inventory={chest=1},direction={north=0,east=4,south=8,west=12},wire_connector_id={circuit_red=1,circuit_green=2}}
    settings={global={[N.SETTING_TIMEOUT]={value=0}}}; prototypes={item={}}
    local rec={entity={valid=true,unit_number=8,position={x=0,y=0},force={index=1,belt_stack_size_bonus=0},get_inventory=function() return {get_contents=function() return {} end} end},unit_number=8,tier="yellow",dir="north",box=core.new_box(),settings={timeout_mode="global",filters={},circuit={}},enabled=true,in_credit={0,0},out_credit={0,0},next_poll=0,led={state="green",visible=true}}
    belt_io.pull=function() return {0,0} end; belt_io.push=function() return 0 end; belt_io.belt_stack_size=function() return 1 end
    circuit.evaluate=function() return true,false end; local calls=0; led.set=function() calls=calls+1 end
    storage={boxes={[8]=rec},belt_stack={[1]=1}}; game={connected_players={}}
    tick.on_tick({tick=1}); eq(calls,0)
    belt_io.pull=old.pull; belt_io.push=old.push; belt_io.belt_stack_size=old.bss; circuit.evaluate=old.evaluate; led.set=old.set
  end)
end)
