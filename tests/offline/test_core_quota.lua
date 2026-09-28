local core = require("scripts.core")

local function box() return core.new_box() end
local function accept(b, name, lane, count, size, tick)
  return core.accept(b, name, "normal", lane, count, size, tick or 1, false)
end

describe("quota", function()
  it("blocked lane never takes 25th slot", function()
    local b = box()
    local accepted = 0
    for i = 1, 30 do accepted = accepted + accept(b, "item" .. i, 1, 1, 1, i) end
    eq(accepted, 24)
    eq(b.lane_used[1], 24)
  end)

  it("other lane keeps 24 slots", function()
    local b = box()
    for i = 1, 24 do eq(accept(b, "left" .. i, 1, 1, 1, i), 1) end
    for i = 1, 24 do eq(accept(b, "right" .. i, 2, 1, 1, i), 1) end
    eq(accept(b, "right25", 2, 1, 1, 25), 0)
    eq(b.lane_used, { 24, 24 })
  end)

  it("flush picks oldest partial same lane", function()
    local b = box()
    accept(b, "old2", 2, 1, 50, 1)
    for i = 2, 25 do accept(b, "left" .. i, 1, 1, 50, i) end
    eq(accept(b, "extra", 1, 1, 50, 99), 0)
    eq(core.peek_out(b, 1).name, "left2")
    eq(core.peek_out(b, 2), nil)
    eq(b.lane_used, { 24, 1 })
  end)

  it("led red when one lane full", function()
    local b = box()
    for i = 1, 24 do accept(b, "left" .. i, 1, 1, 1, i) end
    eq(core.led_state(b), "red")
    core.take_out(b, 1, 1)
    eq(core.led_state(b), "yellow")
  end)

  it("old box over quota drains", function()
    local b = box()
    for i = 1, 30 do core.adopt_external(b, "external" .. i, "normal", 1, 1, i) end
    b.lane_used, b.held = nil, nil
    eq(accept(b, "blocked", 1, 1, 1, 40), 0)
    eq(b.lane_used[1], 30)
    eq(accept(b, "right", 2, 1, 1, 41), 1)
    for i = 1, 7 do core.take_out(b, 1, 1) end
    eq(b.lane_used[1], 23)
    eq(accept(b, "resumed", 1, 1, 1, 42), 1)
  end)
end)
