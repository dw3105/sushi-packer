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
  local function h(arm, name, count, quality) return { arm=arm, name=name, quality=quality or "normal", count=count } end
  local function merges(ms)
    local r={}; for i,m in ipairs(ms) do local a={}; for j,x in ipairs(m.arms) do a[j]=x end; r[i]={name=m.name,quality=m.quality,total=m.total,arms=a} end; return r
  end
  local function copy(a) local r={}; for i,x in ipairs(a) do r[i]=x end; return r end
  -- v16 INT (V16-8): hands of one kind that together hold a full belt stack are merged, never flushed as partials.
  it("hands merges partial hands of one kind into a stack", function()
    local s=ledger.new(); s.sweep={1000,1000}
    local flush, merge = ledger.hands(s,1,{h(1,"iron",2),h(3,"iron",3),h(4,"copper",1),h(6,"iron",1)},opts({tick=0}))
    eq(copy(flush),{}); eq(merges(merge),{{name="iron",quality="normal",total=5,arms={1,3}}})
  end)
  it("hands merge needs a full stack and same quality", function()
    local s=ledger.new(); s.sweep={1000,1000}
    local flush, merge = ledger.hands(s,1,{h(1,"iron",2),h(2,"iron",1),h(3,"iron",2,"rare")},opts({tick=0}))
    eq(copy(flush),{}); eq(merges(merge),{})
    flush, merge = ledger.hands(s,1,{h(1,"iron",4),h(2,"iron",3)},opts({tick=1}))
    eq(merges(merge),{}, "full hands are not merge material")
  end)
  it("hands merge one stack per kind per call, several kinds", function()
    local s=ledger.new(); s.sweep={1000,1000}
    local _, merge = ledger.hands(s,1,{h(1,"iron",3),h(2,"copper",3),h(3,"iron",3),h(4,"copper",2),h(5,"iron",3),h(6,"iron",3)},opts({tick=0}))
    eq(merges(merge),{{name="iron",quality="normal",total=6,arms={1,3}},{name="copper",quality="normal",total=5,arms={2,4}}})
  end)
  it("hands merge uses item stack size", function()
    local s=ledger.new(); s.sweep={1000,1000}
    local _, merge = ledger.hands(s,1,{h(1,"iron",10),h(2,"iron",15)},opts({tick=0,bss=20}))
    eq(merges(merge),{{name="iron",quality="normal",total=25,arms={1,2}}})
  end)
  it("hands jam flushes partial hands that can not merge", function()
    local s=ledger.new(); s.ready={2,0}; s.sweep={1000,1000}
    local held={h(1,"a",4),h(2,"b",4),h(3,"iron",2),h(4,"c",4),h(5,"d",4),h(6,"iron",2),h(7,"gear",1),h(8,"e",4)}
    local flush, merge = ledger.hands(s,1,held,opts({tick=0}))
    eq(copy(flush),{7}); eq(merges(merge),{{name="iron",quality="normal",total=4,arms={3,6}}})
    table.remove(held)  -- one arm free: no jam
    flush = ledger.hands(s,1,held,opts({tick=1})); eq(copy(flush),{})
  end)
  it("hands sweep flushes hand stuck longer than timeout", function()
    local s=ledger.new(); local x={h(2,"iron",3)}
    eq(copy(ledger.hands(s,1,x,opts({tick=0}))),{}); eq(s.held[1][2],"iron\0normal"); eq(s.since[1][2],0); eq(s.sweep[1],120)
    eq(copy(ledger.hands(s,1,x,opts({tick=60}))),{}, "no sweep due: nothing"); eq(s.since[1][2],0)
    eq(copy(ledger.hands(s,1,x,opts({tick=120}))),{}); eq(s.since[1][2],0); eq(s.sweep[1],240)
    eq(copy(ledger.hands(s,1,x,opts({tick=240}))),{})
    eq(copy(ledger.hands(s,1,x,opts({tick=360}))),{2}, "300 ticks passed"); eq(s.held[1][2],nil)
    local t=ledger.new(); ledger.hands(t,1,{h(2,"iron",3)},opts({tick=0}))
    ledger.hands(t,1,{h(2,"copper",1)},opts({tick=120})); eq(t.held[1][2],"copper\0normal"); eq(t.since[1][2],120)
    ledger.hands(t,1,{h(2,"iron",4)},opts({tick=240})); eq(t.held[1][2],nil)
    ledger.hands(t,1,{},opts({tick=360})); eq(t.held[1][2],nil)
  end)
  it("hands timeout zero never sweeps hands out", function()
    local s=ledger.new(); local x={h(2,"iron",3)}
    for _,tick in ipairs({0,120,240,3600}) do eq(copy(ledger.hands(s,1,x,opts({tick=tick,timeout_ticks=0}))),{}) end
  end)
  it("hands sweep comes sooner after a merge", function()
    local s=ledger.new()
    ledger.hands(s,1,{h(1,"iron",2),h(3,"iron",3)},opts({tick=10})); eq(s.sweep[1],40)
    ledger.hands(s,1,{h(1,"iron",2)},opts({tick=40})); eq(s.sweep[1],160)
  end)
  it("hands flush_all flushes all partial hands that can not merge", function()
    local s=ledger.new()
    local flush, merge = ledger.hands(s,1,{h(1,"iron",4),h(2,"iron",2),h(3,"gear",1),h(4,"iron",3)},opts({flush_all=true}))
    eq(copy(flush),{3}); eq(merges(merge),{{name="iron",quality="normal",total=5,arms={2,4}}})
  end)
  it("hands results are ascending and reused", function()
    local s=ledger.new(); s.ready={2,0}
    local held={h(1,"z",1),h(2,"y",1),h(3,"x",1),h(4,"w",1),h(5,"v",1),h(6,"u",1),h(7,"t",1),h(8,"s",1)}
    local a, m = ledger.hands(s,1,held,opts({tick=0}))
    eq(copy(a),{1,2,3,4,5,6,7,8}); local b, m2 = ledger.hands(s,1,{},opts({tick=1})); ok(a==b); ok(m==m2); eq(copy(b),{})
  end)
  it("hands lanes are separate", function()
    local s=ledger.new(); ledger.hands(s,1,{h(2,"iron",3)},opts({tick=0}))
    eq(s.held[2][2],nil); eq(s.sweep[2] or 0,0)
  end)
end)
