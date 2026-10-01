local N = require("scripts.names")

local function setup()
  local created, inserts = {}, 0
  local force, surface = {}, {}
  function surface.create_entity(spec)
    created[#created + 1] = spec
    local entity = { name = spec.name, get_transport_line = function()
      return { insert_at_back = function() inserts = inserts + 1 end }
    end }
    spec.entity = entity
    return entity
  end
  function surface.find_entity(name, pos)
    for _, spec in ipairs(created) do
      if spec.name == name and spec.position[1] == pos[1] and spec.position[2] == pos[2] then return spec.entity end
    end
  end
  defines = { direction = { west = 12 } }
  return surface, force, created, function() return inserts end
end

local function shape(created)
  local out = {}
  for _, s in ipairs(created) do out[#out + 1] = { name = s.name, position = s.position, direction = s.direction, type = s.type } end
  return out
end

local function load_builder()
  package.loaded["tests.game.bench_builder"] = nil
  return require("tests.game.bench_builder")
end

describe("bench builder", function()
  it("default scene unchanged", function()
    local builder = load_builder()
    local a, force = setup()
    builder.build(a, force, 2, { 0, 0 })
    local b, _, created = setup()
    builder.build(b, force, 2, { 0, 0 }, {})
    local old_surface, _, old_created = setup()
    builder.build(old_surface, force, 2, { 0, 0 })
    old = shape(old_created)
    eq(shape(created), old)
    local one = {}
    for i = 1, 12 do one[#one + 1] = old[i] end
    eq(one, {
      { name="infinity-chest", position={20.5,10.5} },
      { name="transport-belt", position={16.5,10.5}, direction=12 }, { name="transport-belt", position={17.5,10.5}, direction=12 }, { name="transport-belt", position={18.5,10.5}, direction=12 },
      { name="transport-belt", position={11.5,10.5}, direction=12 }, { name="transport-belt", position={12.5,10.5}, direction=12 }, { name="transport-belt", position={13.5,10.5}, direction=12 }, { name="transport-belt", position={14.5,10.5}, direction=12 },
      { name="loader-1x1", position={19.5,10.5}, direction=12, type="output" }, { name="loader-1x1", position={10.5,10.5}, direction=12, type="input" }, { name="infinity-chest", position={9.5,10.5} },
      { name=N.placer("yellow"), position={15.5,10.5}, direction=12 },
    })
    eq(old[13].position, { 32.5, 10.5 })
  end)

  it("tier sets belt placer loader", function()
    local s, f, c = setup(); load_builder().build(s, f, 1, {0,0}, {tier="turbo"})
    for _, e in ipairs(c) do if e.name:find("belt") then eq(e.name, "turbo-transport-belt") end end
    eq(c[12].name, N.placer("turbo")); eq(c[9].name, "sushi-packer-bench-loader"); eq(c[10].name, "sushi-packer-bench-loader")
  end)
  it("extra tier uses row names", function()
    local s, f, c = setup(); load_builder().build(s, f, 1, {0,0}, {tier="ub-ultimate", flow="stacks"})
    local belts, splitters = 0, 0
    for _, e in ipairs(c) do if e.name == "ultimate-belt" then belts=belts+1 end; if e.name == "original-ultimate-splitter" then splitters=splitters+1 end end
    ok(belts > 0); eq(splitters, 3)
  end)
  it("unknown tier errors", function() local s,f=setup(); local yes,e=pcall(function() load_builder().build(s,f,1,{0,0},{tier="bogus"}) end); eq(yes,false); ok(tostring(e):find("bogus")) end)
  it("unknown flow errors", function() local s,f=setup(); local yes,e=pcall(function() load_builder().build(s,f,1,{0,0},{flow="bogus"}) end); eq(yes,false); ok(tostring(e):find("bogus")) end)
  it("stacks layout", function()
    local s,f,c,inserts=setup(); local b=load_builder(); b.build(s,f,1,{0,0},{flow="stacks"}); local plan=b.plan(1,1)
    local loaders,chests,splitters={}, {}, {}
    for _,e in ipairs(c) do
      if e.type=="output" then loaders[#loaders+1]=e end
      if e.name==N.TIER.yellow.splitter then splitters[#splitters+1]=e end
      if e.name=="infinity-chest" and e.position[1]>20 then chests[#chests+1]=e end
    end
    eq(#loaders,4); eq(#chests,4); eq(#splitters,3); eq(inserts(),0)
    local ys={9.5,10.5,11.5,12.5}
    for i=1,4 do eq(loaders[i].position,{22.5,ys[i]}); eq(loaders[i].entity.loader_belt_stack_size_override,plan[i].size); eq(chests[i].position,{23.5,ys[i]}); eq(chests[i].entity.infinity_container_filters,{{index=1,name=plan[i].item,count=1000,mode="at-least"}}) end
    eq(splitters[1].position,{19.5,11}); eq(splitters[2].position,{21.5,10}); eq(splitters[3].position,{21.5,12})
  end)
  it("stacks column pitch 16", function() local s,f,c=setup(); load_builder().build(s,f,2,{0,0},{flow="stacks"}); local p={}; for _,e in ipairs(c) do if e.name==N.placer("yellow") then p[#p+1]=e.position end end; eq(p[2][1]-p[1][1],16) end)
  it("plan same seed same plan", function()
    local b=load_builder(); for _,seed in ipairs({1,2,7}) do for i=1,200 do local p=b.plan(seed,i); eq(p,b.plan(seed,i)); local sizes,items={},{}; for _,v in ipairs(p) do sizes[#sizes+1]=v.size; items[v.item]=true end; table.sort(sizes); eq(sizes,{1,2,3,4}); local n=0; for _ in pairs(items) do n=n+1 end; eq(n,4) end end
  end)
  it("plan varies across boxes", function()
    local p=load_builder().plan; local orders,items={},{}; for i=1,200 do local row=p(1,i); local sizes={}; for _,v in ipairs(row) do sizes[#sizes+1]=v.size; items[v.item]=true end; orders[table.concat(sizes,",")]=true end; local n,o=0,0; for _ in pairs(items) do n=n+1 end; for _ in pairs(orders) do o=o+1 end; ok(o>=6); eq(n,5)
  end)
  it("control passes settings and logs counters", function()
    local built, calls, handlers, logs={}, {}, {}, {}
    package.loaded["__sushi-packer__.tests.game.bench_builder"]={build=function(...) built={...} end}
    script={on_init=function(fn) handlers.init=fn end,on_nth_tick=function(n,fn) handlers.period=n; handlers.tick=fn end}
    settings={startup={ ["sushi-packer-bench-boxes"]={value=2},["sushi-packer-bench-tier"]={value="blue"},["sushi-packer-bench-flow"]={value="stacks"},["sushi-packer-bench-seed"]={value=5} }}
    game={surfaces={{}},forces={player={}}}; remote={call=function(_,name) calls[#calls+1]=name; if name=="counters" then return {visits=1,reads=2,pulls=3,pushes=4,items_in=5,items_out=6} end end}; log=function(s) logs[#logs+1]=s end
    dofile("tools/bench/mod/control.lua"); handlers.init(); eq(built[5],{tier="blue",flow="stacks",seed=5}); eq(calls,{"counters_on"}); eq(handlers.period,600); game.tick=1200; handlers.tick(); eq(logs[1],"sushi-packer-bench counters tick=1200 visits=1 reads=2 pulls=3 pushes=4 items_in=5 items_out=6")
    remote.call=function(_,name) calls[#calls+1]=name; return nil end; handlers.tick(); eq(#logs,1)
  end)
end)
