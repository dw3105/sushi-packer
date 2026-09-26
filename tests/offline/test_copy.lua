local N = require("scripts.names")

local function setup(entities, mapping)
  storage = { boxes = {} }
  defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
  local written
  local stack = { valid_for_read = true, is_blueprint = true,
    get_blueprint_entities = function() return entities end,
    set_blueprint_entities = function(list) written = list end }
  local copy = require("scripts.copy")
  copy.on_setup_blueprint({ stack = stack, mapping = { get = function() return mapping or {} end } })
  return written
end

describe("copy", function()
  it("blueprint renames variant to placer without mapping", function()
    local result = setup({ { entity_number = 1, name = N.variant("red", "west"), direction = 0 } })
    eq(result[1].name, N.placer("red"))
    eq(result[1].direction, 12)
  end)

  it("blueprint adds tags when rec found", function()
    local entity = { unit_number = 42, valid = true }
    local settings = { circuit = { enable = true } }
    storage = { boxes = { [42] = { settings = settings } } }
    defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
    local list = { { entity_number = 1, name = N.variant("blue", "east") } }
    local stack = { valid_for_read = true, is_blueprint = true,
      get_blueprint_entities = function() return list end,
      set_blueprint_entities = function(value) list = value end }
    require("scripts.copy").on_setup_blueprint({ stack = stack, mapping = { get = function() return { [1] = entity } end } })
    eq(list[1].tags.sushi_packer, settings)
    eq(list[1].name, N.placer("blue"))
  end)

  it("blueprint leaves other entities alone", function()
    local other = { entity_number = 1, name = "stone-furnace", direction = 4 }
    local result = setup({ other })
    eq(result[1], other)
    eq(other.name, "stone-furnace")
  end)
end)
