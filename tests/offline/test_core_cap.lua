local core = require("scripts.core")

describe("cap", function()
  local function box() return core.new_box() end
  local function accept(b, name, quality, lane, count, release, tick, item_stack)
    return core.accept(b, name, quality, lane, count, release, tick or 1, false, item_stack)
  end
  local function fill50(b, quality)
    for i = 1, 12 do accept(b, "iron-ore", quality, 1, 4, 4, i, 50) end
    accept(b, "iron-ore", quality, 1, 2, 4, 13, 50)
  end

  it("ore stops at 50 per lane", function()
    local b = box(); local total = 0
    while true do
      local n = accept(b, "iron-ore", "normal", 1, 4, 4, total + 1, 50)
      if n == 0 then break end
      total = total + n
    end
    eq(total, 50); eq(accept(b, "iron-ore", "normal", 1, 4, 4, 99, 50), 0)
  end)

  it("other lane same item unaffected", function()
    local b = box()
    fill50(b, "normal")
    local total = 0
    while true do
      local n = accept(b, "iron-ore", "normal", 2, 4, 4, total + 20, 50)
      if n == 0 then break end
      total = total + n
    end
    eq(total, 50)
  end)

  it("modded stack size 7 honored", function()
    local b = box(); local total = 0
    while true do
      local n = accept(b, "mod-ore", "normal", 1, 4, 4, total + 1, 7)
      if n == 0 then break end
      total = total + n
    end
    eq(total, 7); eq(accept(b, "mod-ore", "normal", 1, 4, 4, 99, 7), 0)
  end)

  it("quality separate", function()
    local b = box()
    fill50(b, "normal")
    eq(accept(b, "iron-ore", "normal", 1, 4, 4, 19, 50), 0)
    eq(accept(b, "iron-ore", "rare", 1, 4, 4, 20, 50), 4)
  end)

  it("partial belt item accepted up to cap", function()
    local b = box()
    accept(b, "iron-ore", "normal", 1, 48, 4, 1, 50)
    eq(accept(b, "iron-ore", "normal", 1, 4, 4, 2, 50), 2)
  end)

  it("drain reopens intake", function()
    local b = box()
    fill50(b, "normal")
    eq(accept(b, "iron-ore", "normal", 1, 4, 4, 19, 50), 0)
    core.take_out(b, 1, 4)
    eq(accept(b, "iron-ore", "normal", 1, 4, 4, 20, 50), 4)
  end)

  it("no item stack means no cap", function()
    local b = box(); local total = 0
    while total < 80 do  -- 20 slots of 4: under lane quota 24 (022), over any 50 cap
      local n = accept(b, "iron-ore", "normal", 1, 4, 4, total + 1, nil)
      if n == 0 then break end
      total = total + n
    end
    eq(total, 80)
  end)
end)
