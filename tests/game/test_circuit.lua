local N = require("scripts.names")
local circuit = require("scripts.circuit")

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -30, -30 }, { 30, 30 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

local function box_at(surface, force, x)
  return surface.create_entity({ name = N.body("yellow"), position = { x, 0.5 }, direction = defines.direction.north, force = force })
end

local function wire(a, b, color)
  local id = color == "green" and defines.wire_connector_id.circuit_green or defines.wire_connector_id.circuit_red
  assert.is_true(a.get_wire_connector(id, true).connect_to(b.get_wire_connector(id, true)))
end

local function combinator(surface, force, x, signal, count, color, target)
  local cc = surface.create_entity({ name = "constant-combinator", position = { x, 0.5 }, force = force })
  local section = cc.get_or_create_control_behavior().add_section()
  section.set_slot(1, { value = { type = "virtual", name = signal, quality = "normal" }, min = count })
  wire(target, cc, color or "red")
  return cc
end

local function rec(entity, settings)
  return { entity = entity, settings = { circuit = settings }, circuit_state = { last_flush = false } }
end

describe("circuit", function()
  local surface, force
  before_each(function()
    surface, force = game.surfaces[1], game.forces.player
    clear(surface)
  end)

  it("wire connects to box", function()
    local box = box_at(surface, force, 0.5)
    local cc = surface.create_entity({ name = "constant-combinator", position = { 2.5, 0.5 }, force = force })
    wire(box, cc, "red")
    after_ticks(2, function()
      assert.is_not_nil(box.get_circuit_network(defines.wire_connector_id.circuit_red))
    end)
  end)

  it("box outputs contents with quality", function()
    -- v17 (V17-1, V17-4): wire on belt body shows all items inside packer (lane stores wired to body), read on by default
    surface.create_entity({ name = N.placer("yellow"), position = { 0.5, 0.5 }, direction = defines.direction.north, force = force, raise_built = true })
    local box = surface.find_entities_filtered({ position = { 0.5, 0.5 }, name = N.body("yellow") })[1]
    local r = storage.boxes[box.unit_number]
    r.invs[1].insert({ name = "iron-plate", count = 2, quality = "uncommon" })
    r.invs[2].insert({ name = "iron-plate", count = 1, quality = "uncommon" })
    local cc = surface.create_entity({ name = "constant-combinator", position = { 2.5, 0.5 }, force = force })
    wire(box, cc, "red")
    after_ticks(2, function()
      local signal = { type = "item", name = "iron-plate", quality = "uncommon" }
      assert.are_equal(3, box.get_signal(signal, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green))
    end)
  end)

  it("condition off means enabled", function()
    local box = box_at(surface, force, 0.5)
    combinator(surface, force, 2.5, "signal-A", 10, "red", box)
    after_ticks(2, function()
      local enabled = circuit.evaluate(rec(box, { enable = false, cond = { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 100 } }))
      assert.is_true(enabled)
    end)
  end)

  it("condition true enables", function()
    local box = box_at(surface, force, 0.5)
    combinator(surface, force, 2.5, "signal-A", 10, "red", box)
    after_ticks(2, function()
      local enabled = circuit.evaluate(rec(box, { enable = true, cond = { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 5 } }))
      assert.is_true(enabled)
    end)
  end)

  it("condition false disables", function()
    local box = box_at(surface, force, 0.5)
    combinator(surface, force, 2.5, "signal-A", 2, "red", box)
    after_ticks(2, function()
      local enabled = circuit.evaluate(rec(box, { enable = true, cond = { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 5 } }))
      assert.is_false(enabled)
    end)
  end)

  it("red and green wires sum", function()
    local box = box_at(surface, force, 0.5)
    combinator(surface, force, 2.5, "signal-A", 3, "red", box)
    combinator(surface, force, 4.5, "signal-A", 4, "green", box)
    after_ticks(2, function()
      local enabled = circuit.evaluate(rec(box, { enable = true, cond = { first_signal = { type = "virtual", name = "signal-A" }, comparator = "=", constant = 7 } }))
      assert.is_true(enabled)
    end)
  end)

  it("flush fires once per rising edge", function()
    local box = box_at(surface, force, 0.5)
    local cc = combinator(surface, force, 2.5, "signal-F", 0, "red", box)
    local r = rec(box, { flush = true, flush_signal = { type = "virtual", name = "signal-F" } })
    local section = cc.get_or_create_control_behavior().get_section(1)
    after_ticks(2, function()
      assert.is_false(select(2, circuit.evaluate(r))) -- 0 -> 0
      section.set_slot(1, { value = { type = "virtual", name = "signal-F", quality = "normal" }, min = 1 })
      after_ticks(2, function()
        assert.is_true(select(2, circuit.evaluate(r))) -- 0 -> 1
        assert.is_false(select(2, circuit.evaluate(r))) -- 1 -> 1
        section.set_slot(1, { value = { type = "virtual", name = "signal-F", quality = "normal" }, min = 0 })
        after_ticks(2, function()
          assert.is_false(select(2, circuit.evaluate(r))) -- 1 -> 0
          section.set_slot(1, { value = { type = "virtual", name = "signal-F", quality = "normal" }, min = 1 })
          after_ticks(2, function()
            assert.is_true(select(2, circuit.evaluate(r))) -- 0 -> 1 again
          end)
        end)
      end)
    end)
  end)

  it("flush off ignores signal", function()
    local box = box_at(surface, force, 0.5)
    combinator(surface, force, 2.5, "signal-F", 10, "red", box)
    after_ticks(2, function()
      local _, flush_now = circuit.evaluate(rec(box, { flush = false, flush_signal = { type = "virtual", name = "signal-F" } }))
      assert.is_false(flush_now)
    end)
  end)

  it("no wire means enabled and no flush", function()
    local box = box_at(surface, force, 0.5)
    local enabled, flush_now = circuit.evaluate(rec(box, {
      enable = true,
      cond = { first_signal = { type = "virtual", name = "signal-A" }, comparator = "=", constant = 0 },
      flush = true,
      flush_signal = { type = "virtual", name = "signal-F" },
    }))
    assert.is_true(enabled)
    assert.is_false(flush_now)
  end)
end)
