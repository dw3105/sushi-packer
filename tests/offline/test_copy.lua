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

local function fake_record(fields)
  fields = fields or {}
  fields.object_name = "LuaRecord"
  return setmetatable(fields, { __index = function(_, k)
    error("LuaRecord doesn't contain key " .. tostring(k) .. ".", 2)
  end })
end

local function blueprint_api(entities)
  local written, reads, writes = nil, 0, 0
  return {
    get_blueprint_entities = function() reads = reads + 1; return entities end,
    set_blueprint_entities = function(list) writes = writes + 1; written = list end,
    result = function() return written end,
    calls = function() return reads, writes end,
  }
end

describe("copy", function()
  it("library record does not crash", function()
    storage = { boxes = {} }
    defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
    local api = blueprint_api({ { entity_number = 1, name = N.variant("red", "west"), direction = 0 } })
    local rec = fake_record({ valid = true, valid_for_write = true, type = "blueprint",
      get_blueprint_entities = api.get_blueprint_entities, set_blueprint_entities = api.set_blueprint_entities })
    require("scripts.copy").on_setup_blueprint({ record = rec, mapping = { get = function() return {} end } })
    eq(api.result()[1].name, N.placer("red"))
    eq(api.result()[1].direction, 12)
  end)

  it("library record gets tags", function()
    local settings = { circuit = { enable = true } }
    storage = { boxes = { [42] = { settings = settings } } }
    defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
    local api = blueprint_api({ { entity_number = 1, name = N.variant("blue", "east") } })
    local rec = fake_record({ valid = true, valid_for_write = true, type = "blueprint",
      get_blueprint_entities = api.get_blueprint_entities, set_blueprint_entities = api.set_blueprint_entities })
    require("scripts.copy").on_setup_blueprint({ record = rec,
      mapping = { get = function() return { [1] = { unit_number = 42, valid = true } } end } })
    eq(api.result()[1].tags.sushi_packer, settings)
    eq(api.result()[1].name, N.placer("blue"))
  end)

  it("read-only record skipped", function()
    local api = blueprint_api({})
    local rec = fake_record({ valid = true, valid_for_write = false, type = "blueprint",
      get_blueprint_entities = api.get_blueprint_entities, set_blueprint_entities = api.set_blueprint_entities })
    require("scripts.copy").on_setup_blueprint({ record = rec })
    local reads, writes = api.calls()
    eq(writes, 0)
  end)

  it("non-blueprint record skipped", function()
    local api = blueprint_api({})
    local rec = fake_record({ valid = true, valid_for_write = true, type = "deconstruction-planner",
      get_blueprint_entities = api.get_blueprint_entities, set_blueprint_entities = api.set_blueprint_entities })
    require("scripts.copy").on_setup_blueprint({ record = rec })
    local reads, writes = api.calls()
    eq(reads, 0)
    eq(writes, 0)
  end)

  it("stack still read as stack", function()
    storage = { boxes = {} }
    defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
    local api = blueprint_api({ { entity_number = 1, name = N.variant("red", "west"), direction = 0 } })
    local stack = setmetatable({ object_name = "LuaItemStack", valid_for_read = true, is_blueprint = true,
      get_blueprint_entities = api.get_blueprint_entities, set_blueprint_entities = api.set_blueprint_entities },
      { __index = function(_, k) error("LuaItemStack doesn't contain key " .. tostring(k) .. ".", 2) end })
    require("scripts.copy").on_setup_blueprint({ stack = stack, mapping = { get = function() return {} end } })
    eq(api.result()[1].name, N.placer("red"))
    eq(api.result()[1].direction, 12)
  end)

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
  it("clone owns copied lane store items", function()
    defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
    package.loaded["scripts.copy"] = nil
    package.loaded["scripts.ledger"] = { new = function() return { seen = { {}, {} } } end }
    package.loaded["scripts.arms"] = { create = function(rec)
      rec.invs = { { contents = {}, insert = function(s) rec.invs[1].contents[#rec.invs[1].contents + 1] = s end },
        { contents = {}, insert = function(s) rec.invs[2].contents[#rec.invs[2].contents + 1] = s end } }
    end }
    local copy = require("scripts.copy")
    local led = require("scripts.led")
    local saved = led.create; led.create = function() end
    local src_ent = { valid = true, unit_number = 1, name = "sushi-packer-north" }
    local dst_ent = { valid = true, unit_number = 2, name = "sushi-packer-north" }
    local source_inv = { get_contents = function() return { { name = "iron-plate", quality = "normal", count = 5 } } end }
    local src = { entity = src_ent, unit_number = 1, tier = "yellow", dir = "north", settings = copy.default_settings(),
      invs = { source_inv, { get_contents = function() return {} end } } }
    storage = { boxes = { [1] = src } }
    copy.on_cloned({ source = src_ent, destination = dst_ent })
    led.create = saved
    local dst = storage.boxes[2]
    eq(dst.box, nil)
    eq(dst.invs[1].contents, { { name = "iron-plate", quality = "normal", count = 5 } })
    eq(src.invs[1].get_contents()[1].count, 5)
  end)
end)
