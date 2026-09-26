-- copy: S0 stub. Contract in docs/CONTRACT.md. Lane replaces bodies, never signatures.
local M = {}

function M.default_settings() error("stub: copy.default_settings") end
function M.export(a) error("stub: copy.export") end
function M.import(a, b) error("stub: copy.import") end
function M.on_cloned(a) end -- event handler stub: no-op until lane lands
function M.on_settings_pasted(a) end -- event handler stub: no-op until lane lands
function M.on_setup_blueprint(a) end -- event handler stub: no-op until lane lands

return M
