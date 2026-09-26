-- belt_io: S0 stub. Contract in docs/CONTRACT.md. Lane replaces bodies, never signatures.
local M = {}

function M.behind(a, b) error("stub: belt_io.behind") end
function M.belt_stack_size(a) error("stub: belt_io.belt_stack_size") end
function M.front(a, b) error("stub: belt_io.front") end
function M.pull(a, b, c) error("stub: belt_io.pull") end
function M.push(a, b, c, d) error("stub: belt_io.push") end

return M
