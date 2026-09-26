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

describe("copy clone", function()
  it("cloned box stays consistent after more input", function()
    -- deep copy without memo split partial tables from the core key index (PERF-2)
    defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
    local core = require("scripts.core")
    local copy = require("scripts.copy")
    local led = require("scripts.led")
    local saved = led.create; led.create = function() end
    local src_ent = { valid = true, unit_number = 1, name = "sushi-packer-yellow-north" }
    local dst_ent = { valid = true, unit_number = 2, name = "sushi-packer-yellow-north" }
    local src = { entity = src_ent, unit_number = 1, settings = copy.default_settings(), box = core.new_box() }
    core.accept(src.box, "iron-plate", "normal", 1, 5, 100, 1, false)
    storage = { boxes = { [1] = src } }
    copy.on_cloned({ source = src_ent, destination = dst_ent })
    led.create = saved
    local dst = storage.boxes[2]
    core.accept(dst.box, "iron-plate", "normal", 1, 3, 100, 2, false)
    eq(core.used_slots(dst.box), 1)
    eq(core.totals(dst.box), { { name = "iron-plate", quality = "normal", count = 8 } })
    eq(core.totals(src.box), { { name = "iron-plate", quality = "normal", count = 5 } })
  end)
end)
