local M = {}

function M.compare(a, comparator, b)
  if comparator == ">" then return a > b end
  if comparator == "<" then return a < b end
  if comparator == "=" then return a == b end
  if comparator == "≥" then return a >= b end
  if comparator == "≤" then return a <= b end
  if comparator == "≠" then return a ~= b end
  return false
end

function M.evaluate(rec)
  local circuit = rec.settings.circuit
  rec.circuit_state = rec.circuit_state or { last_flush = false }
  if circuit.enable ~= true and circuit.flush ~= true then
    rec.circuit_state.last_flush = false
    return true, false
  end
  local cond = circuit.cond or {}
  local entity = rec.entity
  local red = defines.wire_connector_id.circuit_red
  local green = defines.wire_connector_id.circuit_green

  local function signal_value(signal)
    if not signal then return 0 end
    if not entity.get_circuit_network(red) and not entity.get_circuit_network(green) then return 0 end
    return entity.get_signal(signal, red, green) or 0
  end

  local enabled = true
  if circuit.enable == true and cond.first_signal then
    enabled = M.compare(signal_value(cond.first_signal), cond.comparator, cond.constant)
  end

  local flush_value = circuit.flush_signal and signal_value(circuit.flush_signal) or 0
  local flush_high = flush_value > 0
  local flush_now = circuit.flush == true and flush_high and not rec.circuit_state.last_flush
  rec.circuit_state.last_flush = flush_high

  return enabled, flush_now
end

function M.sync(rec)
  local cb=rec.entity.get_control_behavior()
  if not cb then return end
  local c=rec.settings.circuit
  c.enable=cb.circuit_enable_disable
  if cb.circuit_condition ~= nil then c.cond=cb.circuit_condition end
  c.read=cb.read_contents
end

function M.apply(rec)
  local cb=rec.entity.get_control_behavior()
  if not cb then return end
  local c=rec.settings.circuit
  cb.circuit_enable_disable=c.enable == true
  if c.cond ~= nil then cb.circuit_condition=c.cond end
  cb.read_contents=c.read ~= false
  if cb.read_contents then
    cb.read_contents_mode=defines.control_behavior.transport_belt.content_read_mode.hold
  end
end

return M
