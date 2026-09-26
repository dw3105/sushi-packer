local circuit = require("scripts.circuit")

describe("circuit", function()
  it("compare all six comparators", function()
    eq(circuit.compare(3, ">", 2), true)
    eq(circuit.compare(2, "<", 3), true)
    eq(circuit.compare(3, "=", 3), true)
    eq(circuit.compare(3, "≥", 3), true)
    eq(circuit.compare(3, "≤", 3), true)
    eq(circuit.compare(2, "≠", 3), true)
  end)

  it("compare unknown comparator is false", function()
    eq(circuit.compare(1, "??", 1), false)
  end)

  it("compare false cases", function()
    eq(circuit.compare(2, ">", 2), false)
    eq(circuit.compare(3, "<", 2), false)
    eq(circuit.compare(2, "=", 3), false)
    eq(circuit.compare(2, "≥", 3), false)
    eq(circuit.compare(3, "≤", 2), false)
    eq(circuit.compare(2, "≠", 2), false)
  end)

  local function evaluate(enable)
    defines = { wire_connector_id = { circuit_red = 1, circuit_green = 2 } }
    local entity = {
      get_circuit_network = function() return true end,
      get_signal = function() return 3 end,
    }
    return circuit.evaluate({ entity = entity, settings = { circuit = {
      enable = enable, cond = { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 5 },
      flush = false,
    } } })
  end

  it("enable nil means condition off", function()
    eq(evaluate(nil), true)
  end)

  it("enable true applies condition", function()
    eq(evaluate(true), false)
  end)
end)
