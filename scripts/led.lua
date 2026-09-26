local M = {}
local N = require("scripts.names")
local GREEN = { r = 0.2, g = 1, b = 0.2 }
local COLORS = {
  green = GREEN,
  yellow = { r = 1, g = 0.85, b = 0.1 },
  red = { r = 1, g = 0.1, b = 0.1 },
}

function M.create(rec)
  local entity = rec.entity
  local sprite = rendering.draw_sprite({ sprite = N.led("green", rec.dir), target = entity,
    surface = entity.surface, render_layer = "higher-object-under" })
  local light = rendering.draw_light({ sprite = "utility/light_small", target = entity,
    surface = entity.surface, color = GREEN, scale = 0.3, intensity = 0.5 })
  rec.led = { sprite = sprite, light = light, state = "green", visible = true }
end

function M.set(rec, state, visible)
  local l = rec.led
  if not l then return end
  if l.state ~= state then
    l.sprite.sprite = N.led(state, rec.dir)
    l.light.color = COLORS[state]
    l.state = state
  end
  if l.visible ~= visible then
    l.sprite.visible = visible
    l.light.visible = visible
    l.visible = visible
  end
end

function M.destroy(rec)
  if not rec or not rec.led then return end
  for _, obj in ipairs({ rec.led.sprite, rec.led.light }) do
    if obj and obj.valid then obj.destroy() end
  end
  rec.led = nil
end

function M.ensure(rec)
  local l = rec.led
  if not l or not l.sprite or not l.sprite.valid or not l.light or not l.light.valid then
    local state, visible = l and l.state or "green", l and l.visible
    if visible == nil then visible = true end
    M.create(rec)
    M.set(rec, state, visible)
  end
end

return M
