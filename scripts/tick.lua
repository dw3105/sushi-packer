-- tick: S0 stub. Contract in docs/CONTRACT.md. Lane replaces bodies, never signatures.
local M = {}

function M.on_research(a) end -- event handler stub: no-op until lane lands
function M.on_tick(a) end -- event handler stub: no-op until lane lands
function M.timeout_ticks(a) error("stub: tick.timeout_ticks") end

return M
