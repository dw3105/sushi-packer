local ledger = require("scripts.ledger")

describe("ledger", function()
  local function opts(t)
    t = t or {}
    return { tick=t.tick or 100, bss=t.bss or 4, stack_size=t.stack_size or function() return 100 end,
      timeout_ticks=t.timeout_ticks or 0, slots_used=t.slots_used or 1, slots=t.slots or 12,
      skip=t.skip, flush_all=t.flush_all, need_slot=t.need_slot }
  end
  local function pieces(list)
    local out = {}
    for _, p in ipairs(list) do out[#out+1] = {p.name,p.quality,p.count} end
    return out
  end
  local function c(name,count,quality) return {name=name,quality=quality or "normal",count=count} end
  it("full stacks leave partial stays", function()
    eq(pieces(ledger.plan(ledger.new(),1,{c("iron",9)},opts())),{{"iron","normal",4},{"iron","normal",4}})
  end)
  it("belt stack follows bss and item stack size", function()
    eq(pieces(ledger.plan(ledger.new(),1,{c("iron",5)},opts({bss=2}))),{{"iron","normal",2},{"iron","normal",2}})
    eq(pieces(ledger.plan(ledger.new(),1,{c("iron",3)},opts({stack_size=function() return 1 end}))),{{"iron","normal",1},{"iron","normal",1},{"iron","normal",1}})
    eq(pieces(ledger.plan(ledger.new(),1,{c("iron",3)},opts({bss=1}))),{{"iron","normal",1},{"iron","normal",1},{"iron","normal",1}})
  end)
  it("order by first seen then name then quality", function()
    local s=ledger.new()
    ledger.plan(s,1,{c("zinc",4)},opts({tick=10}))
    ledger.plan(s,1,{c("zinc",4),c("iron",4)},opts({tick=20}))
    eq(pieces(ledger.plan(s,1,{c("iron",4),c("zinc",4)},opts({tick=21}))),{{"zinc","normal",4},{"iron","normal",4}})
    eq(pieces(ledger.plan(ledger.new(),1,{c("zinc",4),c("iron",4)},opts())),{{"iron","normal",4},{"zinc","normal",4}})
    eq(pieces(ledger.plan(ledger.new(),1,{c("iron",4,"rare"),c("iron",4,"normal")},opts())),{{"iron","normal",4},{"iron","rare",4}})
    eq(pieces(ledger.plan(ledger.new(),1,{c("zinc",8),c("iron",8)},opts())),pieces(ledger.plan(ledger.new(),1,{c("iron",8),c("zinc",8)},opts())))
  end)
  it("kind gone is forgotten", function()
    local s=ledger.new(); ledger.plan(s,1,{c("iron",1)},opts({tick=5})); ledger.plan(s,1,{},opts({tick=8}))
    eq(s.seen[1]["iron\0normal"],nil)
    ledger.plan(s,1,{c("iron",1)},opts({tick=9})); eq(s.seen[1]["iron\0normal"],9)
    ledger.plan(s,2,{c("iron",1)},opts({tick=20})); eq(s.seen[2]["iron\0normal"],20); eq(s.seen[1]["iron\0normal"],9)
  end)
  it("timer flushes leftover after its stacks", function()
    local s=ledger.new(); ledger.plan(s,1,{c("iron",5)},opts({tick=0,timeout_ticks=60}))
    eq(pieces(ledger.plan(s,1,{c("iron",5)},opts({tick=59,timeout_ticks=60}))),{{"iron","normal",4}})
    eq(pieces(ledger.plan(s,1,{c("iron",5)},opts({tick=60,timeout_ticks=60}))),{{"iron","normal",4},{"iron","normal",1}})
    eq(pieces(ledger.plan(s,1,{c("iron",5)},opts({tick=1000,timeout_ticks=0}))),{{"iron","normal",4}})
  end)
  it("flush all sends every leftover", function()
    local s=ledger.new(); ledger.plan(s,1,{c("iron",2)},opts({tick=1})); ledger.plan(s,1,{c("iron",2),c("copper",3)},opts({tick=2}))
    eq(pieces(ledger.plan(s,1,{c("copper",3),c("iron",2)},opts({flush_all=true}))),{{"iron","normal",2},{"copper","normal",3}})
  end)
  it("full store flushes oldest only", function()
    local s=ledger.new(); ledger.plan(s,1,{c("iron",2)},opts({tick=1})); ledger.plan(s,1,{c("iron",2),c("copper",3)},opts({tick=2})); ledger.plan(s,1,{c("iron",2),c("copper",3),c("coal",1)},opts({tick=3}))
    eq(pieces(ledger.plan(s,1,{c("iron",2),c("copper",3),c("coal",1)},opts({slots_used=12}))),{{"iron","normal",2}})
    eq(pieces(ledger.plan(ledger.new(),1,{c("iron",4),c("copper",2)},opts({slots_used=12}))),{{"iron","normal",4}})
  end)
  -- integrator, v15 INT (red first): F-1 = flush only when an arriving item needs a slot; C-6 slack for items in arm hands
  it("full store without waiting new kind flushes nothing", function()
    local s=ledger.new()
    eq(pieces(ledger.plan(s,1,{c("iron",2),c("copper",3)},opts({slots_used=12,need_slot=false}))),{})
    eq(pieces(ledger.plan(s,1,{c("iron",2),c("copper",3)},opts({slots_used=12,need_slot=true}))),{{"copper","normal",3}})
  end)
  it("hoard blocks at one stack and frees at half", function()
    local function names(k) local o={}; for i,x in ipairs(k) do o[i]=x.name end; return o end
    local size=function() return 50 end
    local st=ledger.new()
    eq(names(ledger.hoard(st,1,{c("ore",49)},size)),{})
    eq(names(ledger.hoard(st,1,{c("ore",50)},size)),{"ore"})
    eq(names(ledger.hoard(st,1,{c("ore",26)},size)),{"ore"})   -- still blocked above half
    eq(names(ledger.hoard(st,1,{c("ore",25)},size)),{})        -- freed at half
    eq(names(ledger.hoard(st,1,{c("ore",49)},size)),{})        -- and free until a full stack again
    eq(names(ledger.hoard(st,2,{c("ore",60)},size)),{"ore"}); eq(names(ledger.hoard(st,1,{c("ore",30)},size)),{})  -- lanes apart
    eq(names(ledger.hoard(st,2,{c("coal",3)},size)),{})        -- kind gone from store: forgotten
    eq(names(ledger.hoard(st,2,{c("ore",30)},size)),{})
  end)
  it("skip kinds leave first whole", function()
    eq(pieces(ledger.plan(ledger.new(),1,{c("iron",4),c("coal",6)},opts({skip=function(n) return n=="coal" end}))),{{"coal","normal",4},{"coal","normal",2},{"iron","normal",4}})
  end)
  it("quality is separate kind", function()
    eq(pieces(ledger.plan(ledger.new(),1,{c("iron",3),c("iron",4,"rare")},opts())),{{"iron","rare",4}})
  end)
  it("plan never changes contents", function()
    local x={c("iron",9),c("copper",2)}; local before={{name="iron",quality="normal",count=9},{name="copper",quality="normal",count=2}}
    ledger.plan(ledger.new(),1,x,opts({flush_all=true})); eq(x,before)
  end)
  it("hoard lists kinds at one inventory stack", function()
    local got=ledger.hoard(ledger.new(),1,{c("iron",100),c("copper",99),c("gear",250)},function() return 100 end)
    eq(#got,2); eq(got[1].name,"gear"); eq(got[2].name,"iron"); eq(got[1].quality,"normal")
    local many={}; for i=1,7 do many[i]=c("k"..i,100+i) end
    local five=ledger.hoard(ledger.new(),1,many,function() return 100 end)
    eq(#five,5); eq(five[1].name,"k3"); eq(five[5].name,"k7")  -- largest five, then sorted by name
  end)
  it("led states", function()
    eq(ledger.led(0,0,12),"green"); eq(ledger.led(3,0,12),"yellow"); eq(ledger.led(12,1,12),"red"); eq(ledger.led(0,12,12),"red")
  end)
  it("state is plain data", function()
    local s=ledger.new(); ledger.plan(s,1,{c("iron",4)},opts())
    local function walk(v) local t=type(v); ok(t=="table" or t=="string" or t=="number"); if t=="table" then for k,x in pairs(v) do ok(type(k)=="string" or type(k)=="number"); walk(x) end end end
    walk(s)
  end)
end)
