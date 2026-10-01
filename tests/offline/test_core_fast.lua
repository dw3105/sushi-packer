package.path = "./?.lua;" .. package.path

local core = require("scripts.core")
local base = require("tests.offline.fixtures.core_v114")

local function clone(x)
  if type(x) ~= "table" then return x end
  local y = {}
  for k, v in pairs(x) do y[clone(k)] = clone(v) end
  return y
end

local function eqcall(a, b, label)
  local aa, ar = pcall(a)
  local ba, br = pcall(b)
  eq(aa, ba, label .. " success")
  if aa then eq(ar, br, label .. " result") else eq(tostring(ar), tostring(br), label .. " error") end
end

local function snapshot(m, box)
  return {totals=m.totals(box), used=m.used_slots(box), free=m.free_slots(box), led=m.led_state(box), idle=m.is_idle(box),
    lane1=m.lane_room(box,1), lane2=m.lane_room(box,2), held=clone(box.held), lane_used=clone(box.lane_used)}
end

local function rng()
  local s = 73129
  return function(n)
    s = (s * 48271) % 2147483647
    return (s % n) + 1
  end
end

describe("core fast", function()
  it("same trace as v114", function()
    local r = rng()
    local a, b = core.new_box(), base.new_box()
    local names, qualities = {"iron", "copper", "gear", "plate", "wire"}, {"normal", "rare"}
    for step=1,20000 do
      local op, lane, name, quality = r(8), r(2), names[r(5)], qualities[r(2)]
      local count, tick = r(4), math.floor(step / 5)
      local args = {name, quality, lane, count, 4, tick, r(5)==1, 100}
      local take_n, timeout, remove_n, adopt_n = r(4), ({0,600})[r(2)], r(8), r(4)
      local function invoke(m, box)
        if op == 1 then return m.accept(box, unpack(args))
        elseif op == 2 then
          local v = m.peek_out(box,lane)
          if v then m.take_out(box,lane,math.min(v.count,take_n)) end
          return v
        elseif op == 3 then return m.on_tick(box,tick,timeout)
        elseif op == 4 then return m.flush_partials(box,tick)
        elseif op == 5 then return m.remove_external(box,name,quality,remove_n)
        elseif op == 6 then return m.adopt_external(box,name,quality,adopt_n,4,tick)
        elseif op == 7 then local v=m.hold_items(box); m.clear_hold(box); return v
        else return m.hold_items(box) end
      end
      local aa, ar = pcall(invoke, core, a)
      local ba, br = pcall(invoke, base, b)
      eq(aa, ba, "step "..step.." success")
      if aa then eq(ar,br,"step "..step.." result") else eq(tostring(ar),tostring(br),"step "..step.." error") end
      if step % 500 == 0 then eq(snapshot(core,a),snapshot(base,b),"step "..step.." snapshot") end
    end
  end)

  it("keys built once per item", function()
    local b=core.new_box()
    local before=core._key_builds()
    for i=1,1000 do
      core.accept(b,"iron","normal",1,1,4,i,false,100)
      core.flush_partials(b,i)
      while core.peek_out(b,1) do local v=core.peek_out(b,1); core.take_out(b,1,v.count) end
    end
    ok(core._key_builds()-before <= 1,"key constructions exceeded 1")
  end)

  it("take out does not rebuild head table", function()
    local b=core.new_box(); core.accept(b,"iron","normal",1,4,4,1,false,100)
    local peek=core.peek_out; local calls=0
    core.peek_out=function(...) calls=calls+1; return peek(...) end
    local good, err=pcall(core.take_out,b,1,1)
    core.peek_out=peek
    if not good then error(err) end
    eq(calls,0)
  end)

  it("full stack leaves partial list without scan", function()
    local b=core.new_box()
    for i=1,20 do core.accept(b,"item"..i,"normal",1,1,4,i,false,100) end
    local original=b.partials; local reads=0
    local proxy=setmetatable({}, {__len=function() return #original end, __index=function(_,k) reads=reads+1; return original[k] end})
    b.partials=proxy
    local remove=table.remove
    table.remove=function(t, i) if t==proxy then return remove(original,i) end return remove(t,i) end
    core.accept(b,"item20","normal",1,3,4,21,false,100)
    table.remove=remove
    ok(reads <= 4,"partial reads "..reads)
  end)

  it("faster than v114", function()
    local names={"iron","copper","gear","plate","wire"}
    local function workload(m)
      local b=m.new_box()
      for i=1,200000 do
        local lane=((i-1)%2)+1
        local name=names[((i-1)%5)+1]
        m.accept(b,name,"normal",lane,((i-1)%4)+1,4,i,false,100000)
        local v=m.peek_out(b,lane)
        if v and v.count==4 then m.take_out(b,lane,4) end
      end
    end
    local function measure(m)
      local t=os.clock(); workload(m); return os.clock()-t
    end
    local a,b
    for round=1,5 do
      if round % 2 == 1 then
        local av, bv = measure(base), measure(core)
        a = a and math.min(a,av) or av; b = b and math.min(b,bv) or bv
      else
        local bv, av = measure(core), measure(base)
        a = math.min(a,av); b = math.min(b,bv)
      end
    end
    ok(b <= 0.70*a, ("new %.4fs baseline %.4fs ratio %.3f"):format(b,a,b/a))
  end)
end)
