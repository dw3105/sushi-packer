package.path = "./?.lua;" .. package.path
local N = require("scripts.names")
local arms = require("scripts.arms")

local function setup(speed)
  local created, writes, connectors = {}, {}, {}
  if rendering == nil then  -- v22: hood is a render object; plain fake unless a test brings its own
    rendering = { draw_sprite = function(spec)
      local o = { valid = true, object_name = "LuaRenderObject", sprite = spec.sprite, target = spec.target,
        surface = spec.surface, render_layer = spec.render_layer, only_in_alt_mode = spec.only_in_alt_mode,
        orientation = spec.orientation, spec = spec }
      function o.destroy() o.destroyed = true; o.valid = false end
      return o
    end }
  end
  local function entity(spec)
    local e = { valid = true, name = spec.name, position = spec.position, force = spec.force, writes = {}, filters = {}, links = {} }
    setmetatable(e, { __index = function(t, k) local w = rawget(t, "_watched"); return w and w[k] end, __newindex = function(t, k, v)
      if k == "disabled_by_script" or k == "use_filters" or k == "inserter_filter_mode" or k == "inserter_stack_size_override" or k == "pickup_position" or k == "drop_position" then
        writes[k] = (writes[k] or 0) + 1; e.writes[k] = (e.writes[k] or 0) + 1
        e._watched = e._watched or {}; e._watched[k] = v
        -- engine: writing pickup_position re-picks the target at that spot (seen in game 2026-10-02)
        if k == "pickup_position" then rawset(t, "pickup_target", "picked-by-engine") end
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
      function c.connect_to(other, a, origin) c.connections[#c.connections+1] = { other=other, a=a, origin=origin }; c.connect_calls=(c.connect_calls or 0)+1; c.last_origin=origin end
      function c.disconnect_from(other, origin) c.disconnects=(c.disconnects or 0)+1; c.last_other=other; c.last_origin=origin end
      connectors[#connectors+1] = c; e.wire_connectors[id] = c; return c
    end
    e.inventory = { tag = spec.name, insert_calls = 0, room = math.huge }
    function e.inventory.insert(stack)
      e.inventory.insert_calls=e.inventory.insert_calls+1
      local n=math.min(stack.count,e.inventory.room); e.inventory.room=e.inventory.room-n; return n
    end
    e.held_stack={ valid_for_read=false, clear=function() e.held_stack.valid_for_read=false end }
    e.behavior={}
    function e.get_or_create_control_behavior() return e.behavior end
    e.pickup_target=nil
    created[#created+1] = { spec=spec, entity=e }
    return e
  end
  local surface = { create_entity = entity, spills={} }
  function surface.spill_item_stack(spec) surface.spills[#surface.spills+1]=spec end
  local box = entity({ name="box", position={x=10,y=20}, force="force" })
  box.get_inventory=function() return box.inventory end
  local rec = { entity=box, tier="turbo", dir="north" }
  prototypes = { entity = { [N.TIER.turbo.belt] = { belt_speed=speed or 0.0625 } } }
  defines = { direction={north=0,east=4,south=8,west=12}, inventory={chest=1}, wire_connector_id={circuit_red=1,circuit_green=2}, wire_origin={script=3} }
  return rec, surface, created, writes, connectors, entity
end

describe("arms v17", function()
  it("count from speed table", function()
    eq(arms.count(0.03125),4); eq(arms.count(0.0625),4); eq(arms.count(0.09375),4); eq(arms.count(0.125),4)
    eq(arms.count(0.15625),8); eq(arms.count(0.3),8); eq(arms.count(0.3125),12); eq(arms.count(0.5625),12)
  end)
  it("create makes two stores and n arms per lane", function()
    local rec,s,created=setup(); rec.entity.surface=s; arms.create(rec)
    local stores, inserters=0,0
    for _,v in ipairs(created) do if v.spec.name==N.STORE then stores=stores+1 elseif v.spec.name==N.ARM then inserters=inserters+1 end end
    eq(stores,2); eq(inserters,8+N.MOP_ARMS*2); eq(#rec.stores,2); eq(#rec.invs,2); eq(#rec.arms[1],4); eq(#rec.arms[2],4)
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
    local rec,s,_,writes=setup(); rec.entity.surface=s; arms.create(rec); local base=writes.disabled_by_script  -- out arms are made paused (16 writes)
    arms.pause(rec,1,true); local n=writes.disabled_by_script-base
    arms.pause(rec,1,true); eq(writes.disabled_by_script-base,n); eq(n,#rec.arms[1]+N.MOP_ARMS); eq(rec.arms[2][1].disabled_by_script,nil)
    arms.pause(rec,1,false); eq(writes.disabled_by_script-base,2*n)
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
    local rec, surface, created = setup(0.125)
    prototypes.entity[N.OUT .. "-10"] = {}
    rec.entity.surface = surface
    arms.create(rec)
    local tier, plain = 0, 0
    for _, v in ipairs(created) do if v.spec.name == N.OUT .. "-10" then tier = tier + 1 elseif v.spec.name == N.OUT then plain = plain + 1 end end
    eq({ tier, plain }, { 2 * N.OUT_ARMS, 0 })
  end)

  it("create sets out arm hand to belt stack size at once", function()
    -- full suite 2026-10-02: arm made with prototype hand, 1 plate in hand, hand size written at first look ->
    -- arm dropped that single plate as a belt item (front belt {1, 4}, out arm held 3).
    local rec, surface = setup(); rec.entity.surface = surface
    rec.entity.force = { belt_stack_size_bonus = 3 }
    prototypes.utility_constants = { max_belt_stack_size = 20 }
    arms.create(rec)
    eq(rec.hand, 4)
    for lane = 1, 2 do for _, a in ipairs(rec.out[lane]) do eq(a.inserter_stack_size_override, 4) end end
    rec.entity.force = { belt_stack_size_bonus = 50 }; arms.create(rec); eq(rec.hand, 20, "engine max")
    prototypes.utility_constants = nil
  end)

  it("create makes out arms per lane", function()
    local rec,s,created=setup(); rec.entity.surface=s; arms.create(rec)
    eq(#rec.out[1],N.OUT_ARMS); eq(#rec.out[2],N.OUT_ARMS); eq(rec.out_paused,{true,true}); eq(rec.hand,1, "fixture force has no bonus: belt stack 1")
    local n=0; for _,v in ipairs(created) do if v.spec.name==N.OUT then n=n+1; eq(v.entity.destructible,false); eq(v.spec.position,rec.entity.position); eq(v.spec.force,"force") end end
    eq(n,N.OUT_ARMS*2)
  end)
  it("out arm setup per lane and direction", function()
    local expected={north={{10.25,19.5},{10.75,19.5}},east={{11.5,20.25},{11.5,20.75}},south={{10.75,21.5},{10.25,21.5}},west={{9.5,20.75},{9.5,20.25}}}
    for _,dir in ipairs({"north","east","south","west"}) do
      local rec,s=setup(); rec.entity.surface=s; rec.entity.position={x=10.5,y=20.5}; rec.dir=dir; arms.create(rec)
      for lane=1,2 do
        local a=rec.out[lane][1]; eq(a.pickup_target,rec.stores[lane]); eq(a.drop_position,{x=expected[dir][lane][1],y=expected[dir][lane][2]})
        -- INT (V16-9): pickup lies opposite to drop, 0.3 of the way, so every arm turns exactly half a circle in every
        -- box direction (pickup at box centre gave direction-dependent swing time: north box 1.5 x faster than west)
        local dx,dy=expected[dir][lane][1]-10.5,expected[dir][lane][2]-20.5
        ok(math.abs(a.pickup_position.x-(10.5-0.3*dx))<1e-9 and math.abs(a.pickup_position.y-(20.5-0.3*dy))<1e-9, dir.." lane "..lane.." pickup")
      end
    end
  end)
  it("create saves hands of old arms", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec)
    set_hand(rec.arms[1][1],"iron-plate",3); rec.invs[1].room=1
    set_hand(rec.out[2][1],"copper-plate",2); rec.invs[2].room=2; rec.entity.get_inventory=nil
    local oldin,oldout=rec.arms[1][1],rec.out[2][1]; arms.create(rec)
    eq(oldin.valid,false); eq(oldout.valid,false); eq(rec.invs[1].insert_calls,1); eq(rec.invs[2].insert_calls,1)
    eq(#s.spills,1); eq(s.spills[1].position,rec.entity.position); eq(s.spills[1].stack,{name="iron-plate",count=2,quality="normal"})
    local r,s2=setup(); r.entity.surface=s2; arms.create(r); arms.create(r); eq(r.invs[1].insert_calls,0); eq(#s2.spills,0)
  end)
  it("destroy removes out arms", function()
    for _,keep in ipairs({false,true}) do local rec,s=setup(); rec.entity.surface=s; arms.create(rec); local a=rec.out[1][1]; arms.destroy(rec,keep); eq(a.valid,false); eq(rec.out,nil); eq(rec.out_paused,nil); eq(rec.hand,nil) end
    arms.destroy({arms={{},{}},out={{nil,{valid=false}},{}},stores={{valid=false},nil},invs={}})
  end)
  it("pause_out writes only on change", function()
    local rec,s,_,writes=setup(); rec.entity.surface=s; arms.create(rec); local base=writes.disabled_by_script  -- made paused
    arms.pause_out(rec,1,true); eq(writes.disabled_by_script,base,"already paused: no write")
    arms.pause_out(rec,1,false); local n=writes.disabled_by_script-base
    arms.pause_out(rec,1,false); eq(writes.disabled_by_script-base,n); eq(n,#rec.out[1]); eq(rec.out[2][1].disabled_by_script,true); eq(rec.arms[1][1].disabled_by_script,nil)
    arms.pause_out(rec,1,true); eq(writes.disabled_by_script-base,2*n)
  end)
  it("hand writes only on change", function()
    -- create already wrote hand 1 once (fixture force has no bonus)
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); arms.hand(rec,1)
    for lane=1,2 do for _,a in ipairs(rec.out[lane]) do eq(a.writes.inserter_stack_size_override,1, "same size as at create: no write") end end
    arms.hand(rec,4)
    for lane=1,2 do for _,a in ipairs(rec.out[lane]) do eq(a.writes.inserter_stack_size_override,2); eq(a.inserter_stack_size_override,4) end end
    arms.hand(rec,4); for lane=1,2 do for _,a in ipairs(rec.out[lane]) do eq(a.writes.inserter_stack_size_override,2) end end
    arms.hand(rec,2); for lane=1,2 do for _,a in ipairs(rec.out[lane]) do eq(a.writes.inserter_stack_size_override,3); eq(a.inserter_stack_size_override,2) end end
    eq(rec.arms[1][1].inserter_stack_size_override,1, "hand updates do not change in hand sizing")
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

    it("create never reads chest inventory", function()
      local rec, s = setup(); rec.entity.surface = s; arms.create(rec); set_hand(rec.arms[1][1],"iron-plate",3)
      rec.invs[1].room=1; rec.entity.get_inventory = nil; arms.create(rec)
      eq(#s.spills,1); eq(s.spills[1].position,rec.entity.position)
      eq(s.spills[1].stack,{name="iron-plate",count=2,quality="normal"})
    end)
    it("create makes mop arms", function()
      local rec,s=setup(); rec.entity.surface=s; arms.create(rec)
      eq(#rec.mop[1],N.MOP_ARMS); eq(#rec.mop[2],N.MOP_ARMS)
      for lane=1,2 do for _,a in ipairs(rec.mop[lane]) do
        eq(a.name,N.ARM); eq(a.pickup_position,rec.entity.position); eq(a.drop_position,rec.entity.position)
        eq(a.pickup_from_left_lane,lane==1); eq(a.pickup_from_right_lane,lane==2)
        eq(a.pickup_target,rec.entity); eq(a.drop_target,rec.stores[lane]); eq(a.destructible,false)
      end end
    end)
    it("create saves mop hands before replacing", function()
      local rec,s=setup(); rec.entity.surface=s; arms.create(rec); local old=rec.mop[1][1]
      set_hand(old,"iron-plate",3); arms.create(rec)
      eq(rec.invs[1].insert_calls,1); eq(old.valid,false)
    end)
    it("create makes hood once and turns it", function()
      -- v22 (V22-2): hood is a script picture, no hood entity
      local rec,s,created=setup(); rec.entity.surface=s; arms.create(rec); local hood=rec.hood
      eq(hood.object_name,"LuaRenderObject"); eq(hood.sprite,N.hood_sprite(rec.tier,"north"))
      rec.dir="east"; arms.create(rec); eq(rec.hood,hood); eq(hood.sprite,N.hood_sprite(rec.tier,"east"))
      local n=0; for _,v in ipairs(created) do if v.spec.name==N.hood(rec.tier) then n=n+1 end end; eq(n,0)
    end)
    it("shut writes logistic condition", function()
      local rec,s=setup(); rec.entity.surface=s; arms.create(rec); local cb=rec.entity.behavior
      eq(cb.connect_to_logistic_network,true); eq(cb.logistic_condition,N.SHUT); eq(cb.circuit_condition,nil)
    end)
    it("aim ahead and across", function()
      local expected={north={ahead={{9.75,19},{10.25,19}},across={{9.9,19.25},{10.1,19.25}}},east={ahead={{11,19.75},{11,20.25}},across={{10.75,19.9},{10.75,20.1}}},south={ahead={{10.25,21},{9.75,21}},across={{10.1,20.75},{9.9,20.75}}},west={ahead={{9,20.25},{9,19.75}},across={{9.25,20.1},{9.25,19.9}}}}
      for _,dir in ipairs(N.DIRS) do for _,kind in ipairs({"ahead","across"}) do
        local rec,s=setup(); rec.entity.surface=s; rec.dir=dir; arms.create(rec); arms.aim_out(rec,kind)
        for lane=1,2 do local a=rec.out[lane][1]; local d=expected[dir][kind][lane]
          eq(a.drop_position,{x=d[1],y=d[2]}); eq(a.pickup_position,{x=10-0.3*(d[1]-10),y=20-0.3*(d[2]-20)})
        end
      end end
    end)
    it("out arms start paused until a look finds a front", function()
      -- INT 2026-10-02 (game: robot upgrade to red put stored items on ground): fresh out arm with no belt in front
      -- drops on the ground; fast tiers finish a swing before first look (30 ticks)
      local rec,s=setup(); rec.entity.surface=s; arms.create(rec)
      for lane=1,2 do
        eq(rec.out_paused[lane],true)
        for _,a in ipairs(rec.out[lane]) do eq(a.disabled_by_script,true) end
        for _,a in ipairs(rec.arms[lane]) do eq(a.disabled_by_script,nil) end
      end
      arms.pause_out(rec,1,false); eq(rec.out[1][1].disabled_by_script,false); eq(rec.out[2][1].disabled_by_script,true)
    end)
    it("hood follows tier after upgrade", function()
      local rec,s=setup(); rec.entity.surface=s; arms.create(rec); local old=rec.hood
      prototypes.entity[N.TIER.red.belt]={belt_speed=0.0625}; rec.tier="red"; arms.create(rec)
      eq(rec.hood,old); eq(rec.hood.sprite,N.hood_sprite("red",rec.dir))  -- v22: same picture object, new tier
    end)
    it("aim unchanged writes nothing", function()
      local rec,s=setup(); rec.entity.surface=s; arms.create(rec); arms.aim_out(rec,"across")
      local a=rec.out[1][1]; local n=a.writes.drop_position+a.writes.pickup_position
      arms.aim_out(rec,"across"); eq(a.writes.drop_position+a.writes.pickup_position,n)
    end)
    it("wire on off", function()
      local rec,s,_,_,connectors=setup(); rec.entity.surface=s; arms.create(rec)
      local calls=0; for _,c in ipairs(connectors) do calls=calls+(c.connect_calls or 0) end; eq(calls,4)
      arms.wire(rec,true); local n=0; for _,c in ipairs(connectors) do n=n+(c.connect_calls or 0) end; eq(n,calls)
      arms.wire(rec,false); local disconnected=0; for _,c in ipairs(connectors) do disconnected=disconnected+(c.disconnects or 0) end
      eq(disconnected,4); eq(rec.wired,false)
    end)
    it("pause covers mop arms", function()
      local rec,s=setup(); rec.entity.surface=s; arms.create(rec); arms.pause(rec,1,true)
      for _,a in ipairs(rec.mop[1]) do eq(a.disabled_by_script,true) end; eq(rec.mop[2][1].disabled_by_script,nil)
    end)
    it("destroy and drain cover mop arms and hood", function()
      local rec,s=setup(); rec.entity.surface=s; arms.create(rec); set_hand(rec.mop[1][1],"iron-plate",2)
      eq(arms.drain_hands(rec),{{name="iron-plate",quality="normal",count=2,lane=1}})
      local mop,hood=rec.mop[1][1],rec.hood; arms.destroy(rec)
      eq(mop.valid,false); eq(hood.valid,false); eq(rec.mop,nil); eq(rec.hood,nil); eq(rec.aim,nil); eq(rec.wired,nil)
    end)
    it("ensure sees missing mop arms or hood", function()
      local rec,s=setup(); rec.entity.surface=s; arms.create(rec); rec.mop=nil; eq(arms.ensure(rec),true)
      rec.hood.valid=false; eq(arms.ensure(rec),false); ok(rec.hood.valid); eq(arms.ensure(rec),false)  -- v22: picture redrawn, no rebuild
    end)
    it("need_slot sees mop hand", function()
      local rec,s=setup(); rec.entity.surface=s; arms.create(rec); set_hand(rec.mop[1][1],"iron-plate",1)
      eq(arms.need_slot(rec,1,{}),true)
    end)
end)

describe("arms v21", function()
  it("in hands get sizes by pattern", function()
    local rec, s = setup(0.0625); rec.entity.surface = s; arms.create(rec)
    for lane = 1, 2 do
      eq({rec.arms[lane][1].inserter_stack_size_override, rec.arms[lane][2].inserter_stack_size_override,
          rec.arms[lane][3].inserter_stack_size_override, rec.arms[lane][4].inserter_stack_size_override}, {1,4,4,4})
    end
    eq(rec.in_hands, table.concat(N.ARM_HANDS, ","))
    rec, s = setup(0.3); rec.entity.surface = s; arms.create(rec)
    eq({rec.arms[1][1].inserter_stack_size_override, rec.arms[1][2].inserter_stack_size_override,
        rec.arms[1][3].inserter_stack_size_override, rec.arms[1][4].inserter_stack_size_override,
        rec.arms[1][5].inserter_stack_size_override, rec.arms[1][6].inserter_stack_size_override,
        rec.arms[1][7].inserter_stack_size_override, rec.arms[1][8].inserter_stack_size_override}, {1,4,4,4,1,4,4,4})
    local previous = N.ARM_HANDS; N.ARM_HANDS = {2,9}
    rec, s = setup(0.0625); rec.entity.surface = s; arms.create(rec)
    eq({rec.arms[1][1].inserter_stack_size_override, rec.arms[1][2].inserter_stack_size_override,
        rec.arms[1][3].inserter_stack_size_override, rec.arms[1][4].inserter_stack_size_override}, {2,4,2,4})
    eq(rec.in_hands, "2,9"); N.ARM_HANDS = previous
  end)

  it("mop and out hands keep their size", function()
    local rec, s = setup(0.0625); rec.entity.surface = s; rec.entity.force = {belt_stack_size_bonus=2}; arms.create(rec)
    for lane=1,2 do
      for _, a in ipairs(rec.mop[lane]) do eq(a.writes.inserter_stack_size_override, nil) end
      for _, a in ipairs(rec.out[lane]) do eq(a.inserter_stack_size_override, 3) end
    end
  end)

  it("out hand count follows belt speed", function()
    for _, row in ipairs({{0.125,N.OUT_ARMS},{0.3,N.OUT_ARMS},{0.5625,N.OUT_FAST.n}}) do
      local rec, s, created = setup(row[1]); rec.entity.surface=s
      prototypes.entity[N.out_name(row[1])] = {}
      arms.create(rec)
      eq(#rec.out[1],row[2]); eq(#rec.out[2],row[2])
      for lane=1,2 do for _, a in ipairs(rec.out[lane]) do eq(a.name,N.out_name(row[1]) or N.OUT) end end
    end
  end)

  it("ensure sets hand sizes of old packer without rebuild", function()
    local rec,s,created=setup(0.0625); rec.entity.surface=s; arms.create(rec)
    local arms_before = {rec.arms[1][1], rec.arms[1][2], rec.arms[1][3], rec.arms[1][4]}
    for lane=1,2 do for _,a in ipairs(rec.arms[lane]) do a._watched.inserter_stack_size_override=nil end end
    rec.in_hands=nil; local n=#created
    eq(arms.ensure(rec),false); eq(#created,n); eq(rec.arms[1][1],arms_before[1])
    eq({rec.arms[1][1].inserter_stack_size_override,rec.arms[1][2].inserter_stack_size_override,
        rec.arms[1][3].inserter_stack_size_override,rec.arms[1][4].inserter_stack_size_override},{1,4,4,4})
    eq(rec.in_hands,table.concat(N.ARM_HANDS,","))
  end)

  it("ensure rebuilds when out hand count differs", function()
    local rec,s=setup(0.5625); rec.entity.surface=s; arms.create(rec)
    -- Model a save made before fast belts got twelve out hands.
    for lane=1,2 do while #rec.out[lane] > N.OUT_ARMS do table.remove(rec.out[lane]) end end
    local old=rec.arms[1][1]
    old.held_stack={valid_for_read=true,name="iron-plate",count=2,quality={name="normal"}}
    eq(arms.ensure(rec),true); eq(#rec.out[1],N.OUT_FAST.n); eq(#rec.out[2],N.OUT_FAST.n)
    eq(old.valid,false); eq(rec.invs[1].insert_calls,1)
  end)

  it("ensure on current packer writes nothing", function()
    local rec,s,created, writes=setup(0.0625); rec.entity.surface=s; arms.create(rec)
    local before, n=#created, writes.inserter_stack_size_override or 0
    eq(arms.ensure(rec),false); eq(#created,before); eq(writes.inserter_stack_size_override or 0,n)
  end)
end)

describe("arms v20", function()
  local function K(...) local t={} for i,n in ipairs({...}) do t[i]={name=n,quality="normal"} end return t end
  local function filters(arm) local o={} for i=1,N.ARM_FILTERS do o[i]=arm.filters[i] and arm.filters[i].name or false end return o end
  it("steer whitelists kinds on out arms of that lane only", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec)
    arms.steer(rec,1,K("iron","gear"))
    for _,a in ipairs(rec.out[1]) do eq(a.use_filters,true); eq(a.inserter_filter_mode,"whitelist") end
    eq(filters(rec.out[1][1]),{"iron","gear",false,false,false}); eq(filters(rec.out[1][2]),{"gear","iron",false,false,false})
    eq(rec.out[1][1].filters[1],{name="iron",quality="normal",comparator="="})
    eq(rec.out[2][1].use_filters,nil); eq(rec.arms[1][1].use_filters,nil)
  end)
  it("steer with more kinds than slots gives each arm its own window", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec)
    arms.steer(rec,1,K("a","b","c","d","e","f","g"))
    eq(filters(rec.out[1][1]),{"a","b","c","d","e"}); eq(filters(rec.out[1][3]),{"c","d","e","f","g"}); eq(filters(rec.out[1][7]),{"g","a","b","c","d"})
  end)
  it("steer writes only when list changed", function()
    local rec,s,_,writes=setup(); rec.entity.surface=s; arms.create(rec)
    eq(arms.steer(rec,1,K("iron")),true); local n=writes.filters; local u=writes.use_filters
    eq(arms.steer(rec,1,K("iron")),false); eq(writes.filters,n); eq(writes.use_filters,u)
    eq(arms.steer(rec,1,K("gear")),true); ok(writes.filters>n)
  end)
  it("steer with empty list lets arms take nothing", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec)
    arms.steer(rec,1,{}); eq(rec.out[1][1].use_filters,true); eq(rec.out[1][1].inserter_filter_mode,"whitelist"); eq(filters(rec.out[1][1]),{false,false,false,false,false})
  end)
  it("steer nil switches filters off once", function()
    local rec,s,_,writes=setup(); rec.entity.surface=s; arms.create(rec)
    arms.steer(rec,1,nil); eq(writes.use_filters,nil,"never steered: no write")
    arms.steer(rec,1,K("iron")); arms.steer(rec,1,nil); eq(rec.out[1][1].use_filters,false); local u=writes.use_filters
    arms.steer(rec,1,nil); eq(writes.use_filters,u)
  end)
  it("new arms forget steering", function()
    local rec,s=setup(); rec.entity.surface=s; arms.create(rec); arms.steer(rec,1,K("iron")); arms.create(rec)
    eq(rec.steer,nil); eq(rec.out[1][1].use_filters,nil)
  end)
end)

-- v22 (V22-2, FND-0054): hood is a script-drawn picture (render object), not a hidden entity: the entity cost script
-- time on every packer (6 of 6 bench pairs). Rendering faked here.
describe("arms", function()
  local function fake_rendering()
    local drawn = {}
    rendering = { draw_sprite = function(spec)
      local o = { valid = true, object_name = "LuaRenderObject", sprite = spec.sprite, target = spec.target, render_layer = spec.render_layer, orientation = spec.orientation, only_in_alt_mode = spec.only_in_alt_mode, writes = 0, spec = spec }
      setmetatable(o, { __newindex = function(t, k, v) if k == "sprite" or k == "orientation" then rawset(t, "writes", rawget(t, "writes") + 1) end; rawset(t, k, v) end })
      function o.destroy() o.destroyed = true; o.valid = false end
      drawn[#drawn + 1] = o
      return o
    end }
    return drawn
  end
  it("create draws hood picture of tier and direction", function()
    local drawn = fake_rendering(); local rec, s = setup(); rec.entity.surface = s; arms.create(rec)
    eq(#drawn, 2); eq(rec.hood.sprite, N.hood_sprite(rec.tier, rec.dir)); eq(rec.hood.target, rec.entity)
    eq(rec.hood.render_layer, "object")
    for _, v in ipairs(s.created or {}) do ok(v.spec.name ~= N.hood(rec.tier), "no hood entity") end
  end)
  it("turn and upgrade change picture, no second drawing", function()
    local drawn = fake_rendering(); local rec, s = setup(); rec.entity.surface = s; arms.create(rec)
    rec.dir = "east"; arms.create(rec); eq(#drawn, 2); eq(rec.hood.sprite, N.hood_sprite(rec.tier, "east"))
    prototypes.entity[N.TIER.red.belt] = { belt_speed = 0.0625 }; rec.tier = "red"; arms.create(rec); eq(#drawn, 2); eq(rec.hood.sprite, N.hood_sprite("red", "east"))
    local w = rec.hood.writes; arms.create(rec); eq(rec.hood.writes, w, "same picture: no write")
  end)
  it("hood entity of older save is removed and replaced", function()
    local drawn = fake_rendering(); local rec, s = setup(); rec.entity.surface = s; arms.create(rec)
    local old = { valid = true, object_name = "LuaEntity", name = N.hood(rec.tier) }; function old.destroy() old.valid = false end
    rec.hood = old
    eq(arms.ensure(rec), false); eq(old.valid, false); eq(rec.hood.object_name, "LuaRenderObject"); eq(rec.hood.sprite, N.hood_sprite(rec.tier, rec.dir))
  end)
  it("lost picture redrawn by ensure without rebuild", function()
    local drawn = fake_rendering(); local rec, s = setup(); rec.entity.surface = s; arms.create(rec)
    local arm = rec.arms[1][1]; rec.hood.valid = false
    eq(arms.ensure(rec), false); eq(#drawn, 3); ok(rec.hood.valid); eq(rec.arms[1][1], arm)
    eq(arms.ensure(rec), false); eq(#drawn, 3)
  end)
  it("destroy removes picture", function()
    fake_rendering(); local rec, s = setup(); rec.entity.surface = s; arms.create(rec); local h = rec.hood
    arms.destroy(rec); eq(h.valid, false); eq(rec.hood, nil)
  end)
  it("create draws one alt-only arrow per packer", function()
    local drawn = fake_rendering(); local rec, s = setup(); rec.entity.surface = s; arms.create(rec)
    local found = {}
    for _, call in ipairs(drawn) do if call.spec.sprite == "utility/fluid_indication_arrow" then found[#found + 1] = call end end
    eq(#found, 1); eq(found[1].spec.only_in_alt_mode, true); eq(found[1].spec.target, rec.entity)
  end)
  it("arrow orientation per direction", function()
    local expected = { north = 0, east = 0.25, south = 0.5, west = 0.75 }
    for dir, orientation in pairs(expected) do
      local drawn = fake_rendering(); local rec, s = setup(); rec.entity.surface = s; rec.dir = dir; arms.create(rec)
      eq(rec.arrow.orientation, orientation, dir)
    end
  end)
  it("rotate rewrites arrow orientation, no second arrow", function()
    local drawn = fake_rendering(); local rec, s = setup(); rec.entity.surface = s; arms.create(rec); local arrow = rec.arrow
    rec.dir = "east"; arms.create(rec)
    local count = 0; for _, call in ipairs(drawn) do if call.spec.sprite == "utility/fluid_indication_arrow" then count = count + 1 end end
    eq(count, 1); eq(rec.arrow, arrow); eq(arrow.orientation, 0.25)
  end)
  it("destroy removes arrow", function()
    fake_rendering(); local rec, s = setup(); rec.entity.surface = s; arms.create(rec); local arrow = rec.arrow
    arms.destroy(rec); eq(arrow.destroyed, true); eq(rec.arrow, nil)
  end)
  it("ensure redraws invalid arrow", function()
    local drawn = fake_rendering(); local rec, s = setup(); rec.entity.surface = s; arms.create(rec); rec.arrow.valid = false
    arms.ensure(rec)
    local count = 0; for _, call in ipairs(drawn) do if call.spec.sprite == "utility/fluid_indication_arrow" then count = count + 1 end end
    eq(count, 2); ok(rec.arrow.valid)
  end)
end)
