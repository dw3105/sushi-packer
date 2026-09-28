-- v9 extra tiers for modded belts (REQUIREMENTS §17). Runs from data-final-fixes.lua (M-3).
-- Frozen seam (docs/CONTRACT.md): M.tiers(raw) -> ordered { {key=, prev=}, ... } of active extra tiers,
-- M.build(raw) creates their prototypes and links turbo -> first extra. S0 stub; lane 024 fills.
local M = {}

function M.tiers(raw)
  return {}
end

function M.build(raw)
end

return M
