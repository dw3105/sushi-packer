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

  it("recipe is steel chest belt and circuits", function()
    for _, tier in ipairs(N.TIERS) do
      local ingredients = prototypes.recipe[N.item(tier)].ingredients
      local expected = {
        { name = "steel-chest", amount = 1 },
        { name = N.TIER[tier].belt, amount = 4 },
        { name = N.TIER[tier].circuit, amount = 5 },
      }
      assert.are_equal(#expected, #ingredients)
      for _, ingredient in ipairs(expected) do
        local found
        for _, actual in ipairs(ingredients) do
          if actual.name == ingredient.name then found = actual end
        end
        assert.is_not_nil(found)
        assert.are_equal(ingredient.amount, found.amount)
      end
    end
  end)

  it("tech requires matching belt tech", function()
    for i, tier in ipairs(N.TIERS) do
      local prerequisites = prototypes.technology[N.tech(tier)].prerequisites
      local expected = { N.TIER[tier].tech }
      if i == 1 then
        expected[#expected + 1] = "steel-processing"
      else
        expected[#expected + 1] = N.tech(N.TIERS[i - 1])
      end
      local found = {}
      local count = 0
      for key, value in pairs(prerequisites) do
        count = count + 1
        local name = type(value) == "string" and value or value.name
        if name then found[name] = true end
        if type(key) == "string" and value then found[key] = true end
      end
      assert.are_equal(#expected, count)
      for _, name in ipairs(expected) do assert.is_true(found[name]) end
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

  it("tech cost copies matching belt tech", function()
    for _, tier in ipairs(N.TIERS) do
      local tech = prototypes.technology[N.tech(tier)]
      local belt_tech = prototypes.technology[N.TIER[tier].tech]
      assert.are_equal(belt_tech.research_unit_count, tech.research_unit_count)
      assert.are_equal(#belt_tech.research_unit_ingredients, #tech.research_unit_ingredients)
      for i, ingredient in ipairs(belt_tech.research_unit_ingredients) do
        assert.are_equal(ingredient.name, tech.research_unit_ingredients[i].name)
        assert.are_equal(ingredient.amount, tech.research_unit_ingredients[i].amount)
      end
    end
  end)

  it("timeout setting defaults to off", function()
    assert.are_equal(0, settings.global[N.SETTING_TIMEOUT].value)
  end)
end)
