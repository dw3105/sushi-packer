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

  rec.circuit_state = rec.circuit_state or { last_flush = false }
  local flush_value = circuit.flush_signal and signal_value(circuit.flush_signal) or 0
  local flush_high = flush_value > 0
  local flush_now = circuit.flush == true and flush_high and not rec.circuit_state.last_flush
  rec.circuit_state.last_flush = flush_high

  return enabled, flush_now
end

return M
