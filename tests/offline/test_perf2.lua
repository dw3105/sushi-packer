local belt_io=require("scripts.belt_io")
local core=require("scripts.core")

describe("perf2",function()
  local function fake_line(stacks,at_exit)
    local line={removed={}}
    setmetatable(line,{__len=function() return #stacks end,__index=function(_,i) return stacks[i] end})
    function line.can_insert_at(pos) return not (pos==0 and at_exit) end
    function line.remove_item(x) line.removed[#line.removed+1]=x; return x.count end
    function line.get_detailed_contents() if at_exit then error("detailed contents must not be read for an item at exit") end; return {{position=0.5}} end
    return line
  end
  local function pull_rec(line)
    defines={direction={north=0,east=4,south=8,west=12}}; game={tick=1}
    local belt={valid=true,type="transport-belt",direction=0}; function belt.get_transport_line() return line end
    local entity={valid=true,position={x=0,y=0},surface={find_entities_filtered=function() return {belt} end}}
    return {entity=entity,dir="north"}
  end
  it("pull reads front item without detailed contents",function()
    local line=fake_line({{name="iron",count=1,quality={name="normal"}}},true); local calls=0
    belt_io.pull(pull_rec(line),{1,0},function() calls=calls+1; return 1 end); eq(calls,1)
  end)
  it("pull skips lane when no item at exit",function()
    local line=fake_line({{name="iron",count=1,quality={name="normal"}}},false); local calls=0
    belt_io.pull(pull_rec(line),{1,0},function() calls=calls+1; return 1 end); eq(calls,0)
  end)
  it("pull removes only accepted part of front item",function()
    local line=fake_line({{name="iron",count=5,quality={name="rare"}}},true)
    belt_io.pull(pull_rec(line),{1,0},function(name,q,lane,count) eq({name,q,lane,count},{"iron","rare",1,5}); return 2 end)
    eq(line.removed,{{name="iron",count=2,quality="rare"}})
  end)
  it("core finds partial by key with 47 others present",function()
    local b=core.new_box(); for i=1,47 do core.accept(b,"item-"..i,"normal",1,1,100,1,false) end
    core.accept(b,"target","normal",2,1,100,1,false); core.accept(b,"target","normal",2,1,100,2,false)
    local found=0; for _,p in ipairs(b.partials) do if p.name=="target" and p.lane==2 then found=p.count end end
    eq(found,2); eq(b.partial_by_key["target\0normal\0"..2].count,2)
  end)
end)
