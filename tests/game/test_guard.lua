-- Guard (SP-01): prototypes and wiring S0 froze exist in game.
local N = require("scripts.names")

describe("guard", function()
  it("prototypes exist", function()
    local ep, ip = prototypes.entity, prototypes.item
    assert.is_not_nil(ip[N.item("yellow")])
    assert.are_equal("simple-entity-with-owner", ep[N.placer("yellow")].type)
    for _, dir in ipairs(N.DIRS) do
      local p = ep[N.variant("yellow", dir)]
      assert.are_equal("container", p.type)
      assert.are_equal(N.SLOTS, p.get_inventory_size(defines.inventory.chest))
    end
    for _, s in ipairs(N.LED_STATES) do
      for _, dir in ipairs(N.DIRS) do assert.is_true(helpers.is_valid_sprite_path(N.led(s, dir))) end
    end
    assert.is_not_nil(prototypes.custom_input[N.INPUT_OPEN])
    assert.is_not_nil(prototypes.mod_setting[N.SETTING_TIMEOUT])
  end)

  it("storage initialised", function()
    assert.are_equal("table", type(storage.boxes))
    assert.are_equal("table", type(storage.belt_stack))
  end)
end)
