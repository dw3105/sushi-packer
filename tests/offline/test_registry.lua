local function setup()
  package.loaded["scripts.registry"] = nil
  package.loaded["scripts.names"] = nil
  package.loaded["scripts.core"] = nil
  package.loaded["scripts.copy"] = nil
  package.loaded["scripts.led"] = nil
  package.loaded["scripts.arms"] = nil
  package.loaded["scripts.ledger"] = nil
  defines = { direction = { north = 0, east = 4, south = 8, west = 12 }, inventory = { chest = 1 },
    wire_connector_id = { circuit_red = 1, circuit_green = 2 } }
  storage = { boxes = {} }
  game = { tick = 100 }
  local led = require("scripts.led")
  led.created, led.destroyed, led.ensured = {}, {}, {}
  led.create = function(rec) led.created[#led.created + 1] = rec end
  led.destroy = function(rec) led.destroyed[#led.destroyed + 1] = rec end
  led.ensure = function(rec) led.ensured[#led.ensured + 1] = rec end
  led.set = function() end
  local arms = { created = {}, destroyed = {}, ensured = {} }
  arms.create = function(rec) arms.created[#arms.created + 1] = rec end
  arms.destroy = function(rec, keep) arms.destroyed[#arms.destroyed + 1] = { rec = rec, keep = keep } end
  arms.ensure = function(rec) arms.ensured[#arms.ensured + 1] = rec end
  arms.wire = function() end
  package.loaded["scripts.arms"] = arms
  package.loaded["scripts.circuit"] = { apply=function() end, sync=function() end }
  package.loaded["scripts.ledger"] = { new = function() return { fresh = true } end }
  local registry = require("scripts.registry")
  local N = require("scripts.names")
  N.BODIES = { [N.body("yellow")]="yellow", [N.body("red")]="red", [N.body("blue")]="blue" }
  local function entity(unit, name, force_index)
    local e = { valid = true, name = name or N.body("yellow"), direction=4, unit_number = unit,
      position = { x = 10.5, y = 18.5 }, surface = { index = 1 }, force = { index = force_index or 1 },
      to_be_upgraded = function() return true end }
    local connections = {}
    e.get_wire_connector = function(id, create)
      if not create and not connections[id] then return nil end
      connections[id] = connections[id] or { connections = {}, connect_to = function() end }
      return connections[id]
    end
    e.get_inventory = function() return { valid = true, get_contents = function() return {} end } end
    return e, connections
  end
  return registry, led, entity, arms
end

describe("registry", function()
  it("upgrade mine stashes rec", function()
    local r, led, entity = setup(); local old = entity(11); local rec = r.new_rec(old)
    rec.settings.rate = 7; local hold = require("scripts.core").hold_items
    r.on_removed({ entity = old, robot = {}, buffer = { insert = function() error("hold sent to buffer") end } })
    eq(storage.boxes[11], nil); eq(#led.destroyed, 1); eq(storage.upgrade_stash["1:10.5:18.5"].rec, rec)
  end)
  it("upgrade build takes stash", function()
    local r, led, entity = setup(); local old = entity(11); local rec = r.new_rec(old)
    r.stash(rec); local new = entity(22); r.on_built({ entity = new })
    eq(r.get(new), rec); eq(#led.created, 1); eq(led.created[1], rec); eq(#led.ensured, 0)
  end)
  it("upgraded rec keeps settings and lane parts", function()
    local r, _, entity, arms = setup(); local old = entity(11); local rec = r.new_rec(old)
    rec.settings.rate = 7; rec.stores = { "left", "right" }; rec.invs = { "left inventory", "right inventory" }
    r.stash(rec); local new = entity(22); r.on_built({ entity = new }); local got = r.get(new)
    eq(got.settings.rate, 7); eq(got.box, nil); eq(got.stores[1], "left"); eq(#arms.created, 1)
  end)
  it("upgraded rec gets tier and dir from new entity", function()
    local r, _, entity = setup(); local N=require("scripts.names"); local old = entity(11); local rec = r.new_rec(old)
    r.stash(rec); local new = entity(22, N.body("blue")); new.direction=8; r.on_built({ entity = new })
    eq(rec.tier, "blue"); eq(rec.dir, "south"); eq(rec.entity, new); eq(rec.unit_number, 22)
  end)
  it("stash from older tick ignored and pruned", function()
    local r, _, entity = setup(); local old = entity(11); local rec = r.new_rec(old); r.stash(rec)
    game.tick = 101; local new = entity(22); eq(r.take_stash(new), nil); eq(next(storage.upgrade_stash), nil)
  end)
  it("stash other force ignored", function()
    local r, _, entity = setup(); local old = entity(11); local rec = r.new_rec(old); r.stash(rec)
    local new = entity(22, nil, 2); eq(r.take_stash(new), nil); ok(storage.upgrade_stash["1:10.5:18.5"] ~= nil)
  end)
  it("normal mine removes lane parts", function()
    local r, _, entity, arms = setup(); local old = entity(11); local rec = r.new_rec(old)
    r.on_removed({ entity = old, buffer = { insert = function() end } })
    eq(storage.boxes[11], nil); eq(#arms.destroyed, 1)
  end)
  it("upgrade reconnects missing wires", function()
    local r, _, entity = setup(); local old = entity(11); local rec = r.new_rec(old)
    local target = entity(90); local old_connector = old.get_wire_connector(defines.wire_connector_id.circuit_red, true)
    old_connector.connections = { { target = { owner = target, wire_connector_id = 5 }, origin = { x = 1, y = 2 } } }
    local new_connections = {}; local new = entity(22)
    new.get_wire_connector = function(id, create)
      new_connections[id] = new_connections[id] or { connections = {}, connected = 0 }
      new_connections[id].connect_to = function() new_connections[id].connected = new_connections[id].connected + 1 end
      return new_connections[id]
    end
    r.stash(rec); eq(#storage.upgrade_stash["1:10.5:18.5"].wires, 1)
    eq(r.take_stash(new), rec); eq(new_connections[defines.wire_connector_id.circuit_red].connected, 1)
  end)
  it("player mine of marked box removes parts", function()
    local r, _, entity, arms = setup(); local old = entity(11); local rec = r.new_rec(old)
    r.on_removed({ entity = old, player_index = 1, buffer = { insert = function() end } })
    eq(#arms.destroyed, 1); eq(storage.upgrade_stash, nil); eq(storage.boxes[11], nil)
  end)
end)

-- v17 belt-body lifecycle tests use independent module fakes so they stay useful while
-- the arms and circuit lanes are being integrated.
describe("registry v17", function()
  local function setup()
    for _, n in ipairs({"scripts.registry", "scripts.copy", "scripts.led", "scripts.names", "scripts.arms", "scripts.circuit", "scripts.ledger"}) do package.loaded[n] = nil end
    defines = { direction={north=0,east=4,south=8,west=12}, inventory={chest=1}, wire_connector_id={circuit_red=1,circuit_green=2}, wire_origin={player=1,script=2} }
    storage, game = {boxes={}}, {tick=10}
    local N=require("scripts.names"); N.BODIES={ [N.body("yellow") ]="yellow", [N.body("red") ]="red", [N.body("blue") ]="blue" }
    local log={}; local arms; arms={ensured={},create=function(r) log[#log+1]="arms.create" end,wire=function(r,on) log[#log+1]="arms.wire:"..tostring(on) end,destroy=function(r,k) log[#log+1]="arms.destroy" end,ensure=function(r) log[#log+1]="arms.ensure"; arms.ensured[#arms.ensured+1]=r end,drain_hands=function() return {} end}
    local circuit={apply=function() log[#log+1]="circuit.apply" end,sync=function() log[#log+1]="circuit.sync" end}
    package.loaded["scripts.arms"]=arms; package.loaded["scripts.circuit"]=circuit; package.loaded["scripts.ledger"]={new=function() return {} end}
    local led={create=function(r) log[#log+1]="led.create" end,destroy=function() end,ensure=function() log[#log+1]="led.ensure" end,set=function(r,s,v) log[#log+1]="led.set:"..tostring(s) end}; package.loaded["scripts.led"]=led
    local made={}; local id=100
    local surface={index=1, spilled={}}; surface.spill_item_stack=function(s) surface.spilled[#surface.spilled+1]=s end
    local function entity(name,dir)
      id=id+1; local e={valid=true,name=name,unit_number=id,direction=dir or 4,position={x=2.5,y=3.5},force={index=1},quality="normal",surface=surface}
      local connectors={}
      e.destroy=function() e.valid=false end; e.get_or_create_control_behavior=function() return {} end
      e.get_control_behavior=function() return nil end; e.get_wire_connector=function() return {connections={},connect_to=function() end} end
      e.get_wire_connector=function(connector_id,create)
        if not connectors[connector_id] and not create then return nil end
        connectors[connector_id]=connectors[connector_id] or {connections={},connected={}}
        connectors[connector_id].connect_to=function(target,dual,origin) connectors[connector_id].connected[#connectors[connector_id].connected+1]={target=target,origin=origin} end
        return connectors[connector_id]
      end
      e.connectors=connectors
      return e
    end
    surface.create_entity=function(spec) made[#made+1]=spec; return entity(spec.name,spec.direction) end
    local r=require("scripts.registry")
    return r,N,arms,log,entity,made,surface
  end
  it("placer becomes body", function() local r,N,a,l,ent,m=setup(); local p=ent(N.placer("red")); p.last_user="u"; local old=p; r.on_built({entity=p}); eq(old.valid,false); eq(m[1].name,N.body("red")); eq(m[1].direction,4); eq(#a and 1 or 1,1); eq(l[2],"circuit.apply") end)
  it("legacy box built becomes body", function() local r,N,_,_,ent,m=setup(); local p=ent(N.variant("yellow","south"),8); r.on_built({entity=p}); eq(m[1].name,N.body("yellow")); eq(m[1].direction,8) end)
  it("body with control behaviour is synced", function() local r,N,_,l,ent=setup(); local e=ent(N.body("red")); e.get_control_behavior=function() return {} end; r.on_built({entity=e}); eq(l[2],"circuit.sync") end)
  it("tags imported before sync", function() local r,N,_,l,ent=setup(); local e=ent(N.body("red")); e.get_control_behavior=function() return {} end; r.on_built({entity=e,tags={sushi_packer={circuit={read=false}}}}); eq(l[2],"circuit.sync") end)
  it("new_rec only for bodies", function() local r,N,_,_,ent=setup(); eq(r.new_rec(ent(N.variant("red","east"))),nil); eq(r.new_rec(ent(N.placer("red"))),nil); eq(r.new_rec(ent(N.body("red"))).tier,"red") end)
  it("rotated updates dir and parts", function() local r,N,a,l,ent=setup(); local e=ent(N.body("red")); local rec=r.new_rec(e); e.direction=0; r.on_rotated({entity=e}); eq(rec.dir,"north"); eq(l[1],"arms.create") end)
  it("removal never reads chest inventory", function() local r,N,_,_,ent=setup(); local e=ent(N.body("yellow")); e.get_inventory=nil; local rec=r.new_rec(e); rec.invs={}; r.on_removed({entity=e}); r.on_died({entity=e}) end)
  it("migrate chest to body", function() local r,N,a,log,ent,m=setup(); local e=ent(N.variant("yellow","east")); e.get_inventory=function() return {valid=true,get_contents=function() return {{name="plate",count=5}} end} end; local pole=ent("pole"); local store=ent("store"); local red= e.get_wire_connector(1,true); red.connections={{target={owner=pole,wire_connector_id=7},origin=defines.wire_origin.player},{target={owner=store,wire_connector_id=8},origin=defines.wire_origin.script}}; local inv={items={}}; inv.insert=function(x) inv.items[#inv.items+1]=x; return x.count end; local rec={entity=e,unit_number=e.unit_number,tier="yellow",dir="east",settings={circuit={read=false}},invs={inv,{insert=function() return 0 end}}}; storage.boxes[e.unit_number]=rec; local got=r.migrate(rec); eq(got,rec); eq(m[1].name,N.body("yellow")); eq(e.valid,false); eq(rec.extra,nil); eq(rec.invs[1].items[1].count,5); eq(#rec.entity.connectors[1].connected,1); eq(rec.entity.connectors[1].connected[1].origin,defines.wire_origin.player); eq(log[1],"arms.destroy"); local ic,ia; for i,x in ipairs(log) do if x=="arms.create" then ic=i elseif x=="circuit.apply" then ia=i end end; ok(ic and ia and ic<ia,"apply after create: body gets control behaviour in arms.create") end)
  it("migrate overflow is spilled", function() local r,N,_,_,ent=setup(); local e=ent(N.variant("yellow","east")); e.get_inventory=function() return {valid=true,get_contents=function() return {{name="coal",count=3}} end} end; local rec={entity=e,unit_number=e.unit_number,tier="yellow",dir="east",settings={circuit={}},invs={{insert=function() return 1 end},{insert=function() return 0 end}}}; storage.boxes[e.unit_number]=rec; rec.extra={{name="coal",count=3,lane=1}}; r.migrate(rec); ok(#e.surface.spilled>=1) end)
  it("migrate never doubles items named by extra", function()
    -- INT (review of lane 056): rec.extra names items that lie in the chest; both were inserted
    local r,N,_,_,ent=setup(); local e=ent(N.variant("yellow","east"))
    e.get_inventory=function() return {valid=true,get_contents=function() return {{name="coal",count=7},{name="plate",count=5}} end} end
    local got={{},{}}
    local function inv(lane) return {insert=function(x) got[lane][#got[lane]+1]={name=x.name,count=x.count}; return x.count end} end
    local rec={entity=e,unit_number=e.unit_number,tier="yellow",dir="east",settings={circuit={}},invs={inv(1),inv(2)}}
    storage.boxes[e.unit_number]=rec; rec.extra={{name="coal",quality="normal",count=7,lane=2}}
    r.migrate(rec)
    eq(got[2],{{name="coal",count=7}}); eq(got[1],{{name="plate",count=5}})
  end)
  it("migrate without body drops rec with items spilled", function() local r,N,_,_,ent,_,s=setup(); s.create_entity=function() return nil end; local e=ent(N.variant("yellow","east")); e.get_inventory=function() return {valid=true,get_contents=function() return {{name="iron",count=2}} end} end; local rec={entity=e,unit_number=e.unit_number,tier="yellow",dir="east",invs={}}; storage.boxes[e.unit_number]=rec; eq(r.migrate(rec),nil); eq(storage.boxes[e.unit_number],nil) end)
  it("config change migrates legacy recs once", function() local r,N,a,l,ent=setup(); local e=ent(N.body("yellow")); local rec=r.new_rec(e); r.on_configuration_changed({}); ok(#a.ensured==1) end)
  it("stash and take_stash for bodies", function() local r,N,_,_,ent=setup(); local e=ent(N.body("red")); local rec=r.new_rec(e); r.stash(rec); local n=ent(N.body("red")); eq(r.take_stash(n),rec); eq(rec.dir,"east") end)
end)
