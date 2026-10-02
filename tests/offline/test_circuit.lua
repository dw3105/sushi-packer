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

describe("circuit v17", function()
  local function fixture(settings, behavior)
    local writes={}
    local cb=behavior
    if cb then
      setmetatable(cb,{__newindex=function(t,k,v) writes[k]=v; rawset(t,k,v) end})
    end
    local entity={get_control_behavior=function() return cb end,get_or_create_control_behavior=function() return cb end}
    local rec={entity=entity,settings={circuit=settings}}
    return rec,cb,writes
  end
  it("sync reads belt settings", function()
    local S={type="virtual",name="signal-A"}
    local cond={first_signal=S,comparator="<",constant=7}
    local rec,cb=fixture({enable=true,cond=cond,read=false},
      {circuit_enable_disable=true,circuit_condition=cond,read_contents=false})
    circuit.sync(rec); eq(rec.settings.circuit.enable,true); eq(rec.settings.circuit.cond,cond); eq(rec.settings.circuit.read,false)
    local incomplete={comparator="<",constant=7}
    rec,cb=fixture({enable=false,cond=incomplete,read=true},
      {circuit_enable_disable=true,circuit_condition=incomplete,read_contents=true})
    circuit.sync(rec); eq(rec.settings.circuit.cond,incomplete)
    rec=fixture({enable=true,cond=cond,read=false},nil)
    circuit.sync(rec); eq(rec.settings.circuit,{enable=true,cond=cond,read=false})
  end)
  it("apply writes belt settings", function()
    defines={control_behavior={transport_belt={content_read_mode={hold=17}}}}
    local cond={first_signal={type="virtual",name="signal-A"},comparator="<",constant=7}
    for _,read in ipairs({false,true}) do
      local rec,cb,writes=fixture({enable=true,cond=cond,read=read}, {})
      circuit.apply(rec)
      eq(cb.circuit_enable_disable,true); eq(cb.circuit_condition,cond); eq(cb.read_contents,read ~= false)
      if read then eq(cb.read_contents_mode,17) end
      eq(writes.connect_to_logistic_network,nil); eq(writes.logistic_condition,nil)
    end
  end)
  it("apply then sync round trip", function()
    defines={control_behavior={transport_belt={content_read_mode={hold=17}}}}
    local cond={first_signal={type="virtual",name="signal-A"},comparator="<",constant=7}
    local rec,cb=fixture({enable=true,cond=cond,read=true}, {})
    circuit.apply(rec); circuit.sync(rec)
    eq(rec.settings.circuit,{enable=true,cond=cond,read=true})
  end)
end)
