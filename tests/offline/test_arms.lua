package.path = "./?.lua;" .. package.path
local N = require("scripts.names")
local arms = require("scripts.arms")

local function setup(speed)
  local created, writes, connectors = {}, {}, {}
  local function entity(spec)
    local e = { valid = true, name = spec.name, position = spec.position, force = spec.force, writes = {}, filters = {}, links = {} }
    setmetatable(e, { __index = function(t, k) local w = rawget(t, "_watched"); return w and w[k] end, __newindex = function(t, k, v)
      if k == "disabled_by_script" or k == "use_filters" or k == "inserter_filter_mode" or k == "inserter_stack_size_override" then
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
    e.inventory = { tag = spec.name, insert_calls = 0, room = math.huge }
    function e.inventory.insert(stack)
      e.inventory.insert_calls=e.inventory.insert_calls+1
      local n=math.min(stack.count,e.inventory.room); e.inventory.room=e.inventory.room-n; return n
    end
    e.held_stack={ valid_for_read=false, clear=function() e.held_stack.valid_for_read=false end }
    e.pickup_target=nil
    created[#created+1] = { spec=spec, entity=e }
    return e
  end
  local surface = { create_entity = entity, spills={} }
  function surface.spill_item_stack(spec) surface.spills[#surface.spills+1]=spec end
  local box = entity({ name="box", position={x=10,y=20}, force="force" })
  box.get_inventory=function() return box.inventory end
  local rec = { entity=box, tier="turbo", dir="north" }
  prototypes = { entity = { [N.TIER.turbo.belt] = { belt_speed=speed or 0.125 } } }
  defines = { inventory={chest=1}, wire_connector_id={circuit_red=1,circuit_green=2}, wire_origin={script=3} }
  return rec, surface, created, writes, connectors, entity
end

describe("arms", function()
  it("count from speed table", function()
    eq(arms.count(0.03125),4); eq(arms.count(0.0625),4); eq(arms.count(0.125),4)
    eq(arms.count(0.15625),8); eq(arms.count(0.3),8); eq(arms.count(0.3125),12); eq(arms.count(0.5625),12)
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
  local function set_hand(a,name,count,quality)
    a.held_stack={valid_for_read=true,name=name,count=count,quality={name=quality or "normal"},clear=function() a.held_stack.valid_for_read=false end}
  end
  it("create uses out arm of tier speed when that prototype exists", function()
    local rec, surface, created = setup()
    prototypes.entity[N.OUT .. "-10"] = {}
    rec.entity.surface = surface
    arms.create(rec)
    local tier, plain = 0, 0
    for _, v in ipairs(created) do if v.spec.name == N.OUT .. "-10" then tier = tier + 1 elseif v.spec.name == N.OUT then plain = plain + 1 end end
    eq({ tier, plain }, { 2 * N.OUT_ARMS, 0 })
  end)

  it("create makes out arms per lane", function()
    local rec,s,created=setup(); rec.entity.surface=s; arms.create(rec)
    eq(#rec.out[1],N.OUT_ARMS); eq(#rec.out[2],N.OUT_ARMS); eq(rec.out_paused,{false,false}); eq(rec.hand,nil)
    local n=0; for _,v in ipairs(created) do if v.spec.name==N.OUT then n=n+1; eq(v.entity.destructible,false); eq(v.spec.position,rec.entity.position); eq(v.spec.force,"force") end end
    eq(n,N.OUT_ARMS*2)
  end)
  it("out arm setup per lane and direction", function()
    local expected={north={{10.25,19.5},{10.75,19.5}},east={{11.5,20.25},{11.5,20.75}},south={{10.75,21.5},{10.25,21.5}},west={{9.5,20.75},{9.5,20.25}}}
    for _,dir in ipairs({"north","east","south","west"}) do
      local rec,s=setup(); rec.entity.surface=s; rec.entity.position={x=10.5,y=20.5}; rec.dir=dir; arms.create(rec)
      for lane=1,2 do local a=rec.out[lane][1]; eq(a.pickup_position,rec.entity.position); eq(a.pickup_target,rec.stores[lane]); eq(a.drop_position,{x=expected[dir][lane][1],y=expected[dir][lane][2]}) end
    end
  end)
  it("create saves hands of old arms", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec)
    set_hand(rec.arms[1][1],"iron-plate",3); rec.invs[1].room=1
    set_hand(rec.out[2][1],"copper-plate",2); rec.invs[2].room=2; rec.entity.inventory.room=0
    local oldin,oldout=rec.arms[1][1],rec.out[2][1]; arms.create(rec)
    eq(oldin.valid,false); eq(oldout.valid,false); eq(rec.invs[1].insert_calls,1); eq(rec.invs[2].insert_calls,1)
    eq(rec.entity.inventory.insert_calls,1); eq(#s.spills,1); eq(s.spills[1].position,rec.entity.position); eq(s.spills[1].stack,{name="iron-plate",count=2,quality="normal"})
    local r,s2=setup(); r.entity.surface=s2; arms.create(r); arms.create(r); eq(r.invs[1].insert_calls,0); eq(r.entity.inventory.insert_calls,0); eq(#s2.spills,0)
  end)
  it("destroy removes out arms", function()
    for _,keep in ipairs({false,true}) do local rec,s=setup(); rec.entity.surface=s; arms.create(rec); local a=rec.out[1][1]; arms.destroy(rec,keep); eq(a.valid,false); eq(rec.out,nil); eq(rec.out_paused,nil); eq(rec.hand,nil) end
    arms.destroy({arms={{},{}},out={{nil,{valid=false}},{}},stores={{valid=false},nil},invs={}})
  end)
  it("pause_out writes only on change", function()
    local rec,s,_,writes=setup(); rec.entity.surface=s; arms.create(rec); arms.pause_out(rec,1,true); local n=writes.disabled_by_script
    arms.pause_out(rec,1,true); eq(writes.disabled_by_script,n); eq(n,#rec.out[1]); eq(rec.out[2][1].disabled_by_script,nil); eq(rec.arms[1][1].disabled_by_script,nil)
    arms.pause_out(rec,1,false); eq(writes.disabled_by_script,2*n)
  end)
  it("hand writes only on change", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); arms.hand(rec,4)
    for lane=1,2 do for _,a in ipairs(rec.out[lane]) do eq(a.writes.inserter_stack_size_override,1); eq(a.inserter_stack_size_override,4) end end
    arms.hand(rec,4); for lane=1,2 do for _,a in ipairs(rec.out[lane]) do eq(a.writes.inserter_stack_size_override,1) end end
    arms.hand(rec,2); for lane=1,2 do for _,a in ipairs(rec.out[lane]) do eq(a.writes.inserter_stack_size_override,2); eq(a.inserter_stack_size_override,2) end end
    eq(rec.arms[1][1].inserter_stack_size_override,nil)
    rec.out[1][1].valid=false; arms.hand(rec,3)
  end)
  it("held lists out arm hands", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); set_hand(rec.out[1][2],"iron-plate",3); set_hand(rec.out[1][5],"copper-plate",4,"rare")
    local a=arms.held(rec,1); eq(a,{{arm=2,name="iron-plate",quality="normal",count=3},{arm=5,name="copper-plate",quality="rare",count=4}}); eq(arms.held(rec,2),{})
    local again=arms.held(rec,1); eq(again,a); eq(again[1].count,3)
  end)
  it("clear_held clears one hand", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); local a=rec.out[1][2]; set_hand(a,"iron-plate",3); set_hand(rec.out[1][3],"coal",1)
    arms.clear_held(rec,1,2); eq(a.held_stack.valid_for_read,false); eq(rec.out[1][3].held_stack.valid_for_read,true); arms.clear_held(rec,8,1); arms.clear_held(rec,1,99)
  end)
  it("drain_hands returns and clears all hands", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); set_hand(rec.arms[1][1],"iron-plate",3); set_hand(rec.out[2][1],"copper-plate",2)
    eq(arms.drain_hands(rec),{{name="iron-plate",quality="normal",count=3,lane=1},{name="copper-plate",quality="normal",count=2,lane=2}}); eq(rec.arms[1][1].held_stack.valid_for_read,false); eq(rec.out[2][1].held_stack.valid_for_read,false); eq(arms.drain_hands(rec),{})
    eq(arms.drain_hands({arms=nil,out={{}, {}}}),{}); eq(arms.drain_hands({arms={{},{}},out=nil}),{})
  end)
  it("ensure rebuilds when out arms missing", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); rec.out=nil; eq(arms.ensure(rec),true); eq(#rec.out[1],N.OUT_ARMS); eq(arms.ensure(rec),false)
    rec.out[1][1].valid=false; eq(arms.ensure(rec),true); rec.out[1]={}; eq(arms.ensure(rec),true)
  end)
end)
