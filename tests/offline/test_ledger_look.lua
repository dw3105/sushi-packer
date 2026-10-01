local ledger = require("scripts.ledger")

describe("ledger look", function()
  local function c(name, count, quality) return { name=name, quality=quality or "normal", count=count } end
  local function opts(t)
    local o = { tick=0, bss=4, stack_size=function(name) return name == "tool" and 1 or 100 end,
      timeout_ticks=300, slots=12, slots_used=1, need_slot=false, flush_all=false, n_out=8 }
    for k,v in pairs(t or {}) do o[k]=v end
    return o
  end
  local function pieces(xs)
    local r={}; for i,x in ipairs(xs) do r[i]={name=x.name,quality=x.quality,count=x.count} end; return r
  end
  local function held(counts)
    local r={}; for i=1,#counts do r[i]={arm=i,name="iron",quality="normal",count=counts[i]} end; return r
  end

  it("scan flushes nothing while leftover is young", function()
    local s=ledger.new(); local x={c("iron",3)}
    eq(pieces(ledger.scan(s,1,x,opts({tick=0}))),{})
    eq(pieces(ledger.scan(s,1,x,opts({tick=299}))),{})
  end)
  it("scan flushes leftover after timeout", function()
    local s=ledger.new(); local x={c("iron",3)}
    ledger.scan(s,1,x,opts({tick=0}))
    eq(pieces(ledger.scan(s,1,x,opts({tick=300}))),{c("iron",3)})
    eq(pieces(ledger.scan(s,1,x,opts({tick=301}))),{})
  end)
  it("scan clock resets when kind reaches a stack or leaves", function()
    local s=ledger.new(); ledger.scan(s,1,{c("iron",3)},opts({tick=0}))
    ledger.scan(s,1,{c("iron",7)},opts({tick=100}))
    ledger.scan(s,1,{c("iron",2)},opts({tick=200}))
    eq(pieces(ledger.scan(s,1,{c("iron",2)},opts({tick=499}))),{})
    eq(pieces(ledger.scan(s,1,{c("iron",2)},opts({tick=500}))),{c("iron",2)})
    ledger.scan(s,1,{},opts({tick=501})); eq(s.left[1]["iron\0normal"],nil)
  end)
  it("scan never flushes full stacks", function()
    eq(pieces(ledger.scan(ledger.new(),1,{c("iron",9)},opts({timeout_ticks=1,tick=999}))),{})
  end)
  it("scan timeout zero means off", function()
    local s=ledger.new(); ledger.scan(s,1,{c("iron",3)},opts({tick=0,timeout_ticks=0}))
    eq(pieces(ledger.scan(s,1,{c("iron",3)},opts({tick=999,timeout_ticks=0}))),{})
  end)
  it("scan flush_all flushes every leftover", function()
    eq(pieces(ledger.scan(ledger.new(),1,{c("iron",3),c("copper",9),c("gear",1)},opts({flush_all=true}))),{c("iron",3),c("gear",1)})
  end)
  it("scan need_slot flushes oldest leftover when store is full", function()
    local s=ledger.new(); ledger.scan(s,1,{c("iron",3)},opts({tick=0})); ledger.scan(s,1,{c("iron",3),c("gear",1)},opts({tick=30}))
    eq(pieces(ledger.scan(s,1,{c("iron",3),c("gear",1)},opts({tick=60,need_slot=true,slots_used=12}))),{c("iron",3)})
    eq(pieces(ledger.scan(s,1,{c("iron",3),c("gear",1)},opts({tick=61,need_slot=true,slots_used=11}))),{})
    eq(pieces(ledger.scan(s,1,{c("iron",4),c("gear",4)},opts({tick=62,need_slot=true,slots_used=12}))),{})
    local t=ledger.new(); ledger.scan(t,1,{c("iron",3),c("iron",2,"rare")},opts({tick=1}))
    eq(pieces(ledger.scan(t,1,{c("iron",3),c("iron",2,"rare")},opts({tick=2,need_slot=true,slots_used=12}))),{c("iron",3)})
  end)
  it("scan S uses item stack size", function()
    eq(pieces(ledger.scan(ledger.new(),1,{c("tool",1)},opts())),{})
  end)
  it("scan ready streak and want_hands", function()
    local s=ledger.new(); s.sweep={10000,10000}; local x={c("iron",4)}
    local _,w=ledger.scan(s,1,x,opts({tick=1})); eq(s.ready[1],1); eq(w,false)
    _,w=ledger.scan(s,1,x,opts({tick=2})); eq(s.ready[1],2); eq(w,true)
    _,w=ledger.scan(s,1,{},opts({tick=3})); eq(s.ready[1],0); eq(w,false)
    _,w=ledger.scan(s,1,{},opts({tick=4,flush_all=true})); eq(w,true)
    _,w=ledger.scan(s,1,{},opts({tick=10000})); eq(w,true)
  end)
  it("scan lanes are separate", function()
    local s=ledger.new(); ledger.scan(s,1,{c("iron",3)},opts({tick=4})); s.sweep={10000,10000}
    ledger.scan(s,2,{c("iron",4)},opts({tick=5})); eq(s.left[1]["iron\0normal"],4); eq(s.left[2]["iron\0normal"],nil)
    ledger.scan(s,1,{c("iron",4)},opts({tick=6})); eq(s.ready[2],1)
  end)
  it("scan reuses its tables", function()
    local s=ledger.new(); local a=ledger.scan(s,1,{c("iron",3)},opts({flush_all=true}))
    local old=a[1]; local b=ledger.scan(s,1,{c("gear",2)},opts({flush_all=true}))
    ok(a==b); ok(old==b[1]); eq(old.name,"gear") -- result pieces are overwritten by the next call
  end)
  it("hands jam flushes every partial hand", function()
    local s=ledger.new(); s.ready={2,0}
    eq(ledger.hands(s,1,held({4,4,2,4,4,2,4,4}),opts()),{3,6})
    eq(ledger.hands(s,1,held({4,4,2,4,4,2,4}),opts({tick=1})),{})
  end)
  it("hands sweep flushes hand stuck since previous sweep", function()
    local s=ledger.new(); local h={{arm=2,name="iron",quality="normal",count=3}}
    eq(ledger.hands(s,1,h,opts({tick=0})),{}); eq(s.held[1][2],"iron\0normal"); eq(s.sweep[1],150)
    eq(ledger.hands(s,1,h,opts({tick=100})),{}); eq(s.held[1][2],"iron\0normal")
    eq(ledger.hands(s,1,h,opts({tick=150})),{2}); eq(s.held[1][2],nil); eq(s.sweep[1],300)
    local t=ledger.new(); eq(ledger.hands(t,1,{{arm=2,name="iron",quality="normal",count=3}},opts({tick=0})),{})
    eq(ledger.hands(t,1,{{arm=2,name="copper",quality="normal",count=1}},opts({tick=150})),{}); eq(t.held[1][2],"copper\0normal")
    eq(ledger.hands(t,1,{{arm=2,name="iron",quality="normal",count=4}},opts({tick=300})),{}); eq(t.held[1][2],nil)
  end)
  it("hands sweep period", function()
    local s=ledger.new(); ledger.hands(s,1,{},opts({tick=7,timeout_ticks=60})); eq(s.sweep[1],67)
    local t=ledger.new(); t.held={ {[1]={[2]="iron\0normal"}}, {} }; ledger.hands(t,1,{},opts({tick=5,timeout_ticks=0}))
    eq(t.sweep[1],605); eq(t.held[1][2],nil)
  end)
  it("hands flush_all flushes all partial hands", function()
    local s=ledger.new(); eq(ledger.hands(s,1,held({4,2,1,4}),opts({flush_all=true})),{2,3})
  end)
  it("hands result is ascending without duplicates and reused", function()
    local s=ledger.new(); s.ready={2,0}; s.held={ {[3]="iron\0normal"}, {} }; s.sweep={0,0}
    local a=ledger.hands(s,1,held({4,4,2,4,4,4,4,4}),opts({tick=0}))
    eq(a,{3}); local b=ledger.hands(s,1,{},opts({tick=1})); ok(a==b)
  end)
end)
