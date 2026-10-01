local function setup()
  for _, name in ipairs({"scripts.registry", "scripts.copy", "scripts.names", "scripts.core", "scripts.ledger", "scripts.arms", "scripts.led"}) do package.loaded[name] = nil end
  defines = { direction = { north = 0, east = 4, south = 8, west = 12 }, inventory = { chest = 1 }, wire_connector_id = { circuit_red = 1, circuit_green = 2 } }
  storage, game = { boxes = {} }, { tick = 100 }
  local N = require("scripts.names")
  local ledger = { new = function() return { fresh = true } end }
  package.loaded["scripts.ledger"] = ledger
  local arms = { creates = {}, destroys = {}, ensures = {} }
  local function fake_inv(contents)
    local i = { contents = contents or {}, valid = true }
    function i.get_contents() return i.contents end
    function i.insert(s) i.contents[#i.contents + 1] = s; return s.count end
    return i
  end
  arms.create = function(rec) arms.creates[#arms.creates + 1] = { rec = rec, entity = rec.entity, dir = rec.dir }; if not rec.stores then rec.stores = { {}, {} }; rec.invs = { fake_inv(), fake_inv() } end end
  arms.destroy = function(rec, keep) arms.destroys[#arms.destroys + 1] = { rec = rec, keep = keep } end
  arms.ensure = function(rec) arms.ensures[#arms.ensures + 1] = rec end
  package.loaded["scripts.arms"] = arms
  local led = { create = function() end, destroy = function() end, ensure = function() end, set = function() end }
  package.loaded["scripts.led"] = led
  local function inv(contents) return fake_inv(contents) end
  local id = 10
  local function entity(unit, name)
    id = id + 1
    local e = { valid = true, name = name or N.variant("yellow", "east"), unit_number = unit or id, position = { x=10.5,y=18.5 }, surface = { index=1 }, force = { index=1 }, quality="normal" }
    e.surface.spilled = {}
    e.surface.spill_item_stack = function(spec) e.surface.spilled[#e.surface.spilled + 1] = spec end
    e.surface.create_entity = function(spec) local n = entity(id + 100, spec.name); n.position=spec.position; n.force=spec.force; n.surface=e.surface; return n end
    e.destroy = function() e.valid=false end
    e.get_inventory = function() return inv({}) end
    e.get_wire_connector = function() return { connections={}, connect_to=function() end } end
    return e
  end
  return require("scripts.registry"), require("scripts.copy"), arms, ledger, entity, inv, N
end

describe("lifecycle arms", function()
  it("built box gets ledger and parts", function()
    local r, _, a, _, entity = setup(); local e=entity(1); r.on_built({entity=e}); local rec=r.get(e)
    ok(rec.ledger); eq(rec.box,nil); eq(#a.creates,1); eq(a.creates[1].rec,rec)
  end)
  it("rotate keeps stores and rebuilds arms", function()
    local r, _, a, _, entity = setup(); local e=entity(1); local rec=r.new_rec(e); rec.stores={"s1","s2"}; rec.invs={"i1","i2"}; r.swap(rec,"south")
    eq(#a.creates,1); eq(a.creates[1].dir,"south"); eq(a.creates[1].entity,rec.entity); eq(rec.invs[1],"i1"); eq(#a.destroys,0)
  end)
  it("mined box returns store items", function()
    local r, _, a, _, entity = setup(); local e=entity(1); local rec=r.new_rec(e); rec.invs={ {contents={{name="iron",count=2,quality="rare"}}}, {contents={{name="copper",count=3,quality="normal"}}} }; local got={}
    r.on_removed({entity=e,buffer={insert=function(s) got[#got+1]=s end}}); eq(#got,2); eq(got[1],{name="iron",count=2,quality="rare"}); eq(got[2].name,"copper"); eq(#a.destroys,1)
  end)
  it("died box spills store items", function()
    local r, _, a, _, entity = setup(); local e=entity(1); local rec=r.new_rec(e); rec.invs={ {contents={{name="iron",count=2,quality="rare"}}}, {contents={}} }; r.on_died({entity=e}); eq(#e.surface.spilled,1); eq(e.surface.spilled[1].stack.quality,"rare"); eq(#a.destroys,1)
  end)
  it("upgrade carries stores", function()
    local r, _, a, _, entity = setup(); local e=entity(1); local rec=r.new_rec(e); rec.invs={{contents={{name="iron",count=2}}},{contents={}}}; r.on_removed({entity=e,robot={},buffer={insert=function() error("store returned") end}}); local n=entity(2,"fast-sushi-packer-south"); n.position=e.position; r.on_built({entity=n}); eq(r.get(n),rec); eq(#a.creates,1); eq(#a.destroys,0)
  end)
  it("clone gets own parts and copies items", function()
    local _, c, a, _, entity = setup(); local s,d=entity(1),entity(2); local src={entity=s,unit_number=1,tier="yellow",dir="east",settings=c.default_settings(),stores={"a","b"},invs={{contents={{name="iron",count=4,quality="rare"}}},{contents={}}}}; storage.boxes[1]=src
    c.on_cloned({source=s,destination=d}); local dst=storage.boxes[2]; eq(#a.creates,1); eq(dst.invs[1].contents[1],{name="iron",count=4,quality="rare"}); eq(src.invs[1].contents[1].count,4)
  end)
  it("old save becomes extra", function()
    local r, _, a, _, entity, inv = setup(); local e=entity(1); e.get_inventory=function() return inv() end; local rec={entity=e,unit_number=1,tier="yellow",dir="east",box={partials={{name="iron",quality="normal",lane=1,count=2},{name="iron",quality="normal",lane=1,count=3}},ready={{ {name="copper",quality="rare",lane=2,count=4} },{}},hold={ [2]={name="fish",quality="normal",count=1} } }}; storage.boxes[1]=rec
    r.on_configuration_changed({}); eq(rec.box,nil); ok(rec.ledger); eq(rec.extra,{{name="iron",quality="normal",lane=1,count=5},{name="copper",quality="rare",lane=2,count=4},{name="fish",quality="normal",lane=2,count=1}}); eq(#a.creates,1); eq(#e.get_inventory().contents,0)
  end)
  it("migrated rec only ensured", function()
    local r, _, a = setup(); local e={valid=true,unit_number=1}; local rec={entity=e,unit_number=1,stores={},invs={},arms={},box=nil}; storage.boxes[1]=rec; r.on_configuration_changed({}); r.on_configuration_changed({}); eq(#a.ensures,2); eq(rec.extra,nil); eq(#a.creates,0)
  end)
  it("stale stash cleans its parts", function()
    local r, _, a, _, entity = setup(); local e=entity(1); local rec={entity=e,unit_number=1,invs={{contents={{name="iron",count=2}}},{contents={}}}}; storage.upgrade_stash={stale={rec=rec,tick=99,force=1}}; game.tick=100; r.take_stash(entity(2)); eq(#a.destroys,1); eq(#e.surface.spilled,1)
  end)
end)
