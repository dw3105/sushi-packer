-- v15 arms box: pure rules (no game API). What leaves a lane store, in what order. Seam: docs/CONTRACT.md.
-- Stub until lane 041.
local M = {}
function M.new() return { seen = { {}, {} } } end
function M.plan(state, lane, contents, opts) return {} end
function M.hoard(contents, stack_size) return {} end
function M.led(used_left, used_right, slots) return "green" end
return M
