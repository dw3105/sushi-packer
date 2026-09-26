-- registry: S0 stub. Contract in docs/CONTRACT.md. Lane replaces bodies, never signatures.
local M = {}

function M.get(a) error("stub: registry.get") end
function M.new_rec(a) error("stub: registry.new_rec") end
function M.on_built(a) end -- event handler stub: no-op until lane lands
function M.on_configuration_changed(a) end -- event handler stub: no-op until lane lands
function M.on_died(a) end -- event handler stub: no-op until lane lands
function M.on_removed(a) end -- event handler stub: no-op until lane lands
function M.on_rotate_input(a, b) end -- event handler stub: no-op until lane lands
function M.swap(a, b) error("stub: registry.swap") end

return M
