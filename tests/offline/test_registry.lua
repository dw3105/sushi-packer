local function setup()
  package.loaded["scripts.registry"] = nil
  package.loaded["scripts.names"] = nil
  package.loaded["scripts.core"] = nil
  package.loaded["scripts.copy"] = nil
  package.loaded["scripts.led"] = nil
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
  local registry = require("scripts.registry")
  local function entity(unit, name, force_index)
    local e = { valid = true, name = name or "sushi-packer-yellow-east", unit_number = unit,
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
  return registry, led, entity
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
  it("upgraded rec keeps settings box and hold", function()
    local r, _, entity = setup(); local old = entity(11); local rec = r.new_rec(old)
    rec.settings.rate = 7; rec.box.custom = "preserve"; rec.box.hold[1] = { name = "fish", count = 2 }
    r.stash(rec); local new = entity(22); r.on_built({ entity = new }); local got = r.get(new)
    eq(got.settings.rate, 7); eq(got.box.custom, "preserve"); eq(got.box.hold[1].name, "fish"); eq(got.box.hold[1].count, 2)
  end)
  it("upgraded rec gets tier and dir from new entity", function()
    local r, _, entity = setup(); local old = entity(11); local rec = r.new_rec(old)
    r.stash(rec); local new = entity(22, "sushi-packer-blue-south"); r.on_built({ entity = new })
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
  it("normal mine still returns hold to buffer", function()
    local r, _, entity = setup(); local old = entity(11); old.to_be_upgraded = function() return false end; local rec = r.new_rec(old)
    rec.box.hold[1] = { name = "fish", count = 2 }; local inserted
    r.on_removed({ entity = old, buffer = { insert = function(item) inserted = item end } })
    eq(inserted.name, "fish"); eq(inserted.count, 2); eq(storage.boxes[11], nil); eq(rec.box.hold[1], nil)
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
  it("player mine of marked box returns hold", function()
    -- Integrator review: box marked for upgrade but mined by hand must not park hold in stash.
    local r, _, entity = setup(); local old = entity(11); local rec = r.new_rec(old)
    rec.box.hold[1] = { name = "fish", count = 2 }
    local got = {}
    r.on_removed({ entity = old, player_index = 1, buffer = { insert = function(s) got[#got + 1] = s end } })
    eq(#got, 1); eq(got[1].name, "fish"); eq(storage.upgrade_stash, nil); eq(storage.boxes[11], nil)
  end)
end)
