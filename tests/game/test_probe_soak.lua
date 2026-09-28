-- FND-0021 soak probe (author 2026-09-28: RAM grows, UPS drops over time). NOT in tests/game/index.lua (SP-10):
-- add temporary index entry, `make test-one`, remove entry before commit. Reports via print (SOAK lines).
-- 200 yellow boxes at full flow (bench builder) + churn every 600 ticks: mine+rebuild, rotate x4, die+rebuild,
-- clone+destroy clone. Every 3600 ticks: storage node count per branch, rec count vs live boxes, stash size,
-- render object count, collectgarbage("count") after collect (if allowed), profiler wall ms of window.
local N = require("scripts.names")
local builder = require("tests.game.bench_builder")
local registry = require("scripts.registry")

local TICKS = tonumber(os and os.getenv and os.getenv("SOAK_TICKS") or nil) or 108000

local function walk(value, seen)
  if type(value) ~= "table" or seen[value] then return 0, 0 end
  seen[value] = true
  local tables, keys = 1, 0
  for k, v in pairs(value) do
    keys = keys + 1
    local t, n = walk(v, seen); tables = tables + t; keys = keys + n
    t, n = walk(k, seen); tables = tables + t; keys = keys + n
  end
  return tables, keys
end

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -40, -40 }, { 300, 200 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

describe("probe", function()
  it("soak storage and render objects bounded", function()
    async(TICKS + 20000)
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    storage.upgrade_stash = {}
    force.belt_stack_size_bonus = 3; storage.belt_stack = {}
    local positions = builder.build(surface, force, 200, { 0, 0 })
    local variants = {}
    for name in pairs(N.VARIANTS) do variants[#variants + 1] = name end
    local function box_at(p) return surface.find_entities_filtered({ position = { p.x, p.y }, type = "container" })[1] end
    local function rebuild(p)
      surface.create_entity({ name = N.placer("yellow"), position = { p.x, p.y }, direction = defines.direction.west, force = force, raise_built = true })
    end
    local gc_ok = pcall(collectgarbage, "count")
    local start, cycle = game.tick, 0
    local profiler = helpers.create_profiler()
    local function report(t)
      profiler.stop()
      local branches = {}
      for k, v in pairs(storage) do
        local tables, keys = walk(v, {})
        branches[#branches + 1] = string.format("%s=%d/%d", tostring(k), tables, keys)
      end
      table.sort(branches)
      local live = #surface.find_entities_filtered({ name = variants })
      local renders = #rendering.get_all_objects(N.MOD)
      local kb = "n/a"
      if gc_ok then collectgarbage("collect"); kb = string.format("%.0f", collectgarbage("count")) end
      local stash = 0
      for _ in pairs(storage.upgrade_stash or {}) do stash = stash + 1 end
      local partials, ready, stored = 0, 0, 0
      for _, rec in pairs(storage.boxes) do
        partials = partials + #rec.box.partials
        ready = ready + #rec.box.ready[1] + #rec.box.ready[2]
        stored = stored + rec.box.stored_count
      end
      log(string.format("SOAK t=%d recs=%d live=%d renders=%d stash=%d partials=%d ready=%d stored=%d luaKB=%s storage[%s]",
        t, table_size(storage.boxes), live, renders, stash, partials, ready, stored, kb, table.concat(branches, " ")))
      log({ "", "SOAK t=" .. t .. " window ", profiler })
      profiler.reset()
    end
    report(0)
    on_tick(function()
      local t = game.tick - start
      if t > 0 and t % 600 == 0 then
        print("SOAK-progress t=" .. t)  -- CLI watchdog: output every < 15 s
        cycle = cycle + 1
        local p = positions[(cycle - 1) % #positions + 1]
        local e = box_at(p)
        local action = cycle % 4
        if e and e.valid then
          if action == 0 then
            e.destroy({ raise_destroy = true }); rebuild(p)
          elseif action == 1 then
            local rec = storage.boxes[e.unit_number]
            for _, dir in ipairs({ "north", "east", "south", "west" }) do rec = registry.swap(rec, dir) end
          elseif action == 2 then
            e.die(); rebuild(p)
          else
            surface.clone_entities({ entities = { e }, destination_offset = { 0, 5 } })
            for _, c in ipairs(surface.find_entities_filtered({ position = { p.x, p.y + 5 }, type = "container" })) do
              c.destroy({ raise_destroy = true })
            end
          end
        end
      end
      if t > 0 and t % 3600 == 0 then report(t) end
      if t >= TICKS then done(); return false end
    end)
  end)
end)
