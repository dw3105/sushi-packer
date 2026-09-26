-- core: S0 stub. Contract in docs/CONTRACT.md. Lane replaces bodies, never signatures.
local M = {}

function M.accept(a, b, c, d, e, f, g, h) error("stub: core.accept") end
function M.adopt_external(a, b, c, d, e, f) error("stub: core.adopt_external") end
function M.clear_hold(a) error("stub: core.clear_hold") end
function M.flush_partials(a, b) error("stub: core.flush_partials") end
function M.free_slots(a) error("stub: core.free_slots") end
function M.hold_items(a) error("stub: core.hold_items") end
function M.is_idle(a) error("stub: core.is_idle") end
function M.led_state(a) error("stub: core.led_state") end
function M.new_box() error("stub: core.new_box") end
function M.on_tick(a, b, c) end -- event handler stub: no-op until lane lands
function M.peek_out(a, b) error("stub: core.peek_out") end
function M.remove_external(a, b, c, d) error("stub: core.remove_external") end
function M.take_out(a, b, c) error("stub: core.take_out") end
function M.totals(a) error("stub: core.totals") end
function M.used_slots(a) error("stub: core.used_slots") end

return M
