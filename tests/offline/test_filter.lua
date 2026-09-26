local filter = require("scripts.filter")

describe("filter", function()
  local levels = {normal=0, uncommon=1, rare=2, epic=3, legendary=5}
  it("≥ uncommon matches rare not normal", function()
    local f = {{name="iron", quality="uncommon", comparator="≥"}}
    eq(filter.match(f, "iron", "rare", levels), true)
    eq(filter.match(f, "iron", "normal", levels), false)
  end)
  it("nil quality matches any", function()
    eq(filter.match({{name="iron"}}, "iron", "legendary", levels), true)
  end)
  it("nil comparator means equals", function()
    eq(filter.match({{name="iron", quality="rare"}}, "iron", "normal", levels), false)
    eq(filter.match({{name="iron", quality="rare"}}, "iron", "rare", levels), true)
  end)
  it("all six comparators", function()
    local cases = {
      {"=", "rare", true}, {"≠", "normal", true}, {">", "legendary", true},
      {"<", "uncommon", true}, {"≥", "rare", true}, {"≤", "uncommon", true},
    }
    for _, f in ipairs(cases) do
      eq(filter.match({{name="iron",quality="rare",comparator=f[1]}}, "iron", f[2], levels), f[3], f[1])
    end
  end)
  it("other item never matches", function()
    eq(filter.match({{name="copper"}}, "iron", "normal", levels), false)
  end)
  it("empty slot false skipped", function()
    eq(filter.match({false,{name="iron"}}, "iron", "normal", levels), true)
    eq(filter.match({false}, "iron", "normal", levels), false)
  end)
end)
