-- v15 arms box: hidden parts of one box (lane stores, lane-locked arms, wires). Seam: docs/CONTRACT.md.
-- Stub until lane 042.
local N = require("scripts.names")
local M = {}
function M.count(speed) return 2 end
function M.create(rec) end
function M.destroy(rec, keep_stores) end
function M.pause(rec, lane, paused) end
function M.skip(rec, lane, kinds) end
function M.ensure(rec) return false end
return M
