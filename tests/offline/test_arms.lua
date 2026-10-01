package.path = "./?.lua;" .. package.path
local N = require("scripts.names")
local arms = require("scripts.arms")

local function setup(speed)
  local created, writes, connectors = {}, {}, {}
  local function entity(spec)
    local e = { valid = true, name = spec.name, position = spec.position, force = spec.force, writes = {}, filters = {}, links = {} }
    setmetatable(e, { __index = function(t, k) local w = rawget(t, "_watched"); return w and w[k] end, __newindex = function(t, k, v)
      if k == "disabled_by_script" or k == "use_filters" or k == "inserter_filter_mode" then
        writes[k] = (writes[k] or 0) + 1; e.writes[k] = (e.writes[k] or 0) + 1
        e._watched = e._watched or {}; e._watched[k] = v
      else
        rawset(t, k, v)
      end
    end })
    function e.destroy() e.valid = false end
    function e.get_inventory(_) return e.inventory or {} end
    function e.set_filter(i, v) writes.filters = (writes.filters or 0) + 1; e.filters[i] = v end
    e.wire_connectors = {}
    function e.get_wire_connector(id, create)
      if e.wire_connectors[id] then return e.wire_connectors[id] end
      local c = { id = id, create = create, connections = {} }
      function c.connect_to(other, a, origin) c.connections[#c.connections+1] = { other=other, a=a, origin=origin } end
      connectors[#connectors+1] = c; e.wire_connectors[id] = c; return c
    end
    e.inventory = { tag = spec.name }
    created[#created+1] = { spec=spec, entity=e }
    return e
  end
  local surface = { create_entity = entity }
  local box = entity({ name="box", position={x=10,y=20}, force="force" })
  local rec = { entity=box, tier="turbo", dir="north" }
  prototypes = { entity = { [N.TIER.turbo.belt] = { belt_speed=speed or 0.125 } } }
  defines = { inventory={chest=1}, wire_connector_id={circuit_red=1,circuit_green=2}, wire_origin={script=3} }
  return rec, surface, created, writes, connectors, entity
end

describe("arms", function()
  it("count from speed table", function()
    eq(arms.count(0.03125),2); eq(arms.count(0.0625),4); eq(arms.count(0.125),4)
    eq(arms.count(0.15625),8); eq(arms.count(0.5625),8)
  end)
  it("create makes two stores and n arms per lane", function()
    local rec,s,created=setup(); rec.entity.surface=s; arms.create(rec)
    local stores, inserters=0,0
    for _,v in ipairs(created) do if v.spec.name==N.STORE then stores=stores+1 elseif v.spec.name==N.ARM then inserters=inserters+1 end end
    eq(stores,2); eq(inserters,8); eq(#rec.stores,2); eq(#rec.invs,2); eq(#rec.arms[1],4); eq(#rec.arms[2],4)
    for _,v in ipairs(created) do if v.spec.name==N.STORE or v.spec.name==N.ARM then eq(v.entity.destructible,false); eq(v.spec.position,{x=10,y=20}); eq(v.spec.force,"force") end end
  end)
  it("arm setup per lane and direction", function()
    for _,dir in ipairs({"north","east","south","west"}) do
      local rec,s,created=setup(); rec.entity.surface=s; rec.dir=dir; arms.create(rec)
      local delta=({north={0,1},east={-1,0},south={0,-1},west={1,0}})[dir]
      for lane=1,2 do for _,a in ipairs(rec.arms[lane]) do
        eq(a.pickup_position,{x=10+delta[1],y=20+delta[2]}); eq(a.drop_position,{x=10,y=20})
        eq(a.pickup_from_left_lane,lane==1); eq(a.pickup_from_right_lane,lane==2); eq(a.drop_target,rec.stores[lane])
      end end
    end
  end)
  it("wires join stores to box", function()
    local rec,s=setup(); rec.entity.surface=s; local box=rec.entity; arms.create(rec)
    for _,id in ipairs({1,2}) do
      local target=box.wire_connectors[id]
      for _,store in ipairs(rec.stores) do
        local links=store.wire_connectors[id].connections
        eq(#links,1); eq(links[1].other,target); eq(links[1].a,false); eq(links[1].origin,3)
      end
    end
  end)
  it("create reuses valid stores and replaces arms", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); local stores=rec.stores; local invs=rec.invs; local old=rec.arms[1][1]
    rec.dir="east"; arms.create(rec); eq(rec.stores,stores); eq(rec.invs,invs); eq(old.valid,false)
    local previous=rec.stores[1]; previous.valid=false; arms.create(rec); ok(rec.stores[1]~=previous)
  end)
  it("destroy", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); local a=rec.arms[1][1]; local st=rec.stores[1]
    arms.destroy(rec); eq(a.valid,false); eq(st.valid,false); eq(rec.arms,nil); eq(rec.stores,nil); eq(rec.invs,nil)
    arms.create(rec); local keep=rec.stores; arms.destroy(rec,true); eq(keep[1].valid,true); eq(rec.invs~=nil,true)
    arms.destroy({arms={{ {valid=false} },{nil}},stores={{valid=false},nil},invs={}})
  end)
  it("pause writes only on change", function()
    local rec,s,_,writes=setup(); rec.entity.surface=s; arms.create(rec); arms.pause(rec,1,true); local n=writes.disabled_by_script
    arms.pause(rec,1,true); eq(writes.disabled_by_script,n); eq(n,#rec.arms[1]); eq(rec.arms[2][1].disabled_by_script,nil)
    arms.pause(rec,1,false); eq(writes.disabled_by_script,2*n)
  end)
  it("skip sets blacklist only on change", function()
    local rec,s,_,writes=setup(); rec.entity.surface=s; arms.create(rec); local kinds={{name="iron-plate",quality="normal"}}
    arms.skip(rec,1,kinds); local before=writes.filters; local a=rec.arms[1][1]
    eq(a.use_filters,true); eq(a.inserter_filter_mode,"blacklist"); eq(a.filters[1],{name="iron-plate",quality="normal",comparator="="}); eq(a.filters[2],nil)
    arms.skip(rec,1,kinds); eq(writes.filters,before); arms.skip(rec,1,{}); eq(a.use_filters,false); eq(a.filters[1],nil); eq(rec.arms[2][1].use_filters,nil)
  end)
  it("ensure rebuilds broken box", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); eq(arms.ensure(rec),false)
    rec.arms[1][1].valid=false; eq(arms.ensure(rec),true); rec.arms[1]={}; eq(arms.ensure(rec),true)
    rec.stores=nil; eq(arms.ensure(rec),true)
  end)
  it("create resets pause and skip memory", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); rec.paused={true,true}; rec.skip={"x","y"}; arms.create(rec)
    eq(rec.paused,{false,false}); eq(rec.skip,{"",""})
  end)
  -- integrator, v15 INT: engine objects are userdata in Factorio 2.x, never Lua tables
  it("alive check does not ask for a table", function()
    local f=assert(io.open("scripts/arms.lua")); local src=f:read("*a"); f:close()
    ok(not src:find('type%(part%) == "table"'), "arms.lua must not test engine objects with type() == table")
  end)
  it("need slot when an arm holds a kind the store lacks", function()
    local function arm(name, quality) return { valid = true, held_stack = name and { valid_for_read = true, name = name, quality = { name = quality or "normal" } } or { valid_for_read = false } } end
    local rec = { arms = { { arm(), arm("iron-plate") }, { arm("coal") } } }
    eq(arms.need_slot(rec, 1, { { name = "iron-plate", quality = "normal", count = 2 } }), false)
    eq(arms.need_slot(rec, 1, { { name = "copper-plate", quality = "normal", count = 2 } }), true)
    eq(arms.need_slot(rec, 1, { { name = "iron-plate", quality = "rare", count = 2 } }), true)
    eq(arms.need_slot(rec, 2, {}), true)
    eq(arms.need_slot({ arms = { {}, {} } }, 1, {}), false)
  end)
end)
