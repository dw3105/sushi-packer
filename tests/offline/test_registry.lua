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
  package.loaded["scripts.arms"] = arms
  package.loaded["scripts.ledger"] = { new = function() return { fresh = true } end }
  local registry = require("scripts.registry")
  local function entity(unit, name, force_index)
    local e = { valid = true, name = name or "sushi-packer-east", unit_number = unit,
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
    local r, _, entity = setup(); local old = entity(11); local rec = r.new_rec(old)
    r.stash(rec); local new = entity(22, "express-sushi-packer-south"); r.on_built({ entity = new })
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
