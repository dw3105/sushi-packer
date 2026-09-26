local N = require("scripts.names")

describe("data", function()
  it("every tier has item placer variants and remnant", function()
    for _, tier in ipairs(N.TIERS) do
      assert.are_equal("item", prototypes.item[N.item(tier)].type)
      assert.are_equal(N.placer(tier), prototypes.item[N.item(tier)].place_result.name)
      assert.are_equal("simple-entity-with-owner", prototypes.entity[N.placer(tier)].type)
      for _, dir in ipairs(N.DIRS) do
        assert.are_equal("container", prototypes.entity[N.variant(tier, dir)].type)
      end
      assert.are_equal("corpse", prototypes.entity[N.remnant(tier)].type)
    end
  end)

  it("variants are 48 slot not rotatable containers", function()
    for _, tier in ipairs(N.TIERS) do
      for _, dir in ipairs(N.DIRS) do
        local p = prototypes.entity[N.variant(tier, dir)]
        assert.are_equal(N.SLOTS, p.get_inventory_size(defines.inventory.chest))
        assert.is_true(p.flags["not-rotatable"])
      end
    end
  end)

  it("variants and placer mine to tier item", function()
    for _, tier in ipairs(N.TIERS) do
      local placer = prototypes.entity[N.placer(tier)]
      assert.are_equal(N.item(tier), placer.mineable_properties.products[1].name)
      for _, dir in ipairs(N.DIRS) do
        local p = prototypes.entity[N.variant(tier, dir)]
        assert.are_equal(N.item(tier), p.mineable_properties.products[1].name)
      end
    end
  end)

  it("placer is item place result", function()
    for _, tier in ipairs(N.TIERS) do
      assert.are_equal(N.placer(tier), prototypes.item[N.item(tier)].place_result.name)
    end
  end)

  it("recipes match table", function()
    -- U-2 v5 (author 2026-09-26), exact names and amounts, both builds.
    local want = {
      yellow = { { "steel-chest", 1 }, { "splitter", 1 }, { "inserter", 2 }, { "electronic-circuit", 5 }, craft = 30 },
      red = { { "sushi-packer-yellow", 1 }, { "fast-splitter", 1 }, { "fast-inserter", 2 }, { "advanced-circuit", 5 }, craft = 45 },
      blue = { { "sushi-packer-red", 1 }, { "express-splitter", 1 }, { "bulk-inserter", 2 }, { "processing-unit", 5 }, craft = 60 },
      turbo = { { "sushi-packer-blue", 1 }, { "turbo-splitter", 1 }, { "stack-inserter", 2 }, { "quantum-processor", 2 }, craft = 120 },
    }
    for _, tier in ipairs(N.TIERS) do
      local r = prototypes.recipe[N.item(tier)]
      assert.are_equal(want[tier].craft, r.energy, tier)
      assert.are_equal(4, #r.ingredients, tier)
      -- Engine reorders ingredients at runtime (measured 2.0.77): match by name, not position.
      local got = {}
      for _, ing in ipairs(r.ingredients) do got[ing.name] = ing.amount end
      for _, w in ipairs(want[tier]) do assert.are_equal(w[2], got[w[1]], tier .. " " .. w[1]) end
      -- 2.1 dropped LuaRecipePrototype.category (measured 2.1.20); accept category or categories.
      local ok1, cat = pcall(function() return r.category end)
      local ok2, cats = pcall(function() return r.categories end)
      local crafting = ok1 and cat == "crafting"
      if not crafting and ok2 and type(cats) == "table" then
        for k, v in pairs(cats) do if k == "crafting" or v == "crafting" then crafting = true end end
      end
      assert.is_true(crafting, tier .. " crafting category")
    end
  end)

  it("every ingredient unlocked by prereq closure", function()
    -- U-1: no box recipe craftable before its ingredients (researching the box tech implies them).
    local function closure(name, seen)
      seen = seen or {}
      if seen[name] then return seen end
      seen[name] = true
      for pre in pairs(prototypes.technology[name].prerequisites) do closure(pre, seen) end
      return seen
    end
    local unlocked_by = {}
    for tname, t in pairs(prototypes.technology) do
      for _, e in ipairs(t.effects) do
        if e.type == "unlock-recipe" then
          unlocked_by[e.recipe] = unlocked_by[e.recipe] or {}
          unlocked_by[e.recipe][#unlocked_by[e.recipe] + 1] = tname
        end
      end
    end
    for _, tier in ipairs(N.TIERS) do
      local seen = closure(N.tech(tier))
      for _, ing in ipairs(prototypes.recipe[N.item(tier)].ingredients) do
        local r = prototypes.recipe[ing.name]
        if r and not r.enabled then
          local ok = false
          for _, tname in ipairs(unlocked_by[ing.name] or {}) do if seen[tname] then ok = true end end
          assert.is_true(ok, tier .. " needs tech unlocking " .. ing.name)
        end
      end
    end
  end)

  it("tech cost is belt tech x 1.5", function()
    local want = { yellow = 30, red = 300, blue = 450, turbo = 750 }
    for _, tier in ipairs(N.TIERS) do
      local tech = prototypes.technology[N.tech(tier)]
      local belt_tech = prototypes.technology[N.TIER[tier].tech]
      assert.are_equal(want[tier], tech.research_unit_count, tier)
      assert.are_equal(belt_tech.research_unit_energy, tech.research_unit_energy, tier)
    end
    local packs = {}
    for _, i in ipairs(prototypes.technology[N.tech("turbo")].research_unit_ingredients) do packs[i.name] = true end
    assert.is_true(packs["cryogenic-science-pack"])
  end)

  it("recycling recipe exists", function()
    for _, tier in ipairs(N.TIERS) do assert.is_not_nil(prototypes.recipe[N.item(tier) .. "-recycling"], tier) end
  end)

  it("upgrade chain weight and no surface limit", function()
    for i, tier in ipairs(N.TIERS) do
      assert.are_equal(N.ITEM_WEIGHT, prototypes.item[N.item(tier)].weight, tier)
      for _, dir in ipairs(N.DIRS) do
        local p = prototypes.entity[N.variant(tier, dir)]
        local nxt = N.TIERS[i + 1]
        if nxt then assert.are_equal(N.variant(nxt, dir), p.next_upgrade and p.next_upgrade.name)
        else assert.is_nil(p.next_upgrade) end
        assert.is_nil(p.surface_conditions)
      end
    end
  end)

  it("tech unlocks its recipe", function()
    for _, tier in ipairs(N.TIERS) do
      local tech = prototypes.technology[N.tech(tier)]
      local found = false
      for _, effect in ipairs(tech.effects) do
        if effect.type == "unlock-recipe" and effect.recipe == N.item(tier) then found = true end
      end
      assert.is_true(found)
    end
  end)

  it("timeout setting defaults to off", function()
    assert.are_equal(0, settings.global[N.SETTING_TIMEOUT].value)
  end)
end)
