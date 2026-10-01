defines = { direction = { north = 0, east = 4, south = 8, west = 12 }, inventory = { chest = 1 }, gui_type = { entity = 1 } }
local tick = require("scripts.tick")
local belt_io = require("scripts.belt_io")

local function belt_rig(items, speed)
  game = { tick = 1 }
  prototypes = { entity = { counter_belt = { belt_speed = speed or 0.1875 } } }
  local calls = 0
  local line = setmetatable({}, { __len = function() return #items end, __index = function(_, k) return items[k] end })
  function line.can_insert_at(pos) return not (pos == 0 and items[1] and items[1].position == 0) end
  function line.remove_item(x) items[1].count = items[1].count - x.count; if items[1].count == 0 then table.remove(items, 1) end; return x.count end
  function line.get_detailed_contents()
    calls = calls + 1
    local out = {}; for i, item in ipairs(items) do out[i] = { position = item.position } end
    return out
  end
  function line.can_insert_at_back() return true end
  function line.insert_at_back() return true end
  local empty = setmetatable({}, { __len = function() return 0 end })
  function empty.can_insert_at() return true end
  function empty.get_detailed_contents() calls = calls + 1; return {} end
  function empty.can_insert_at_back() return true end
  local b = { valid = true, type = "transport-belt", direction = 0, name = "counter_belt" }
  function b.get_transport_line(lane) return lane == 1 and line or empty end
  local ent = { valid = true, position = { x = 0, y = 0 }, surface = { find_entities_filtered = function() return { b } end } }
  return { entity = ent, dir = "north" }, function() return calls end, line
end
local function item(count, position) return { name = "iron", quality = { name = "normal" }, count = count, position = position or 0.1 } end

describe("counters", function()
  it("off by default", function()
    storage = { boxes = {}, belt_stack = {} }
    local rec = belt_rig({ item(1) })
    belt_io.pull(rec, { 1, 0 }, function(_, _, _, c) return c end)
    belt_io.push(rec, 1, { name = "iron", quality = "normal", count = 1 }, 1)
    eq(tick.counters(), nil); eq(storage.sp_counters, nil)
  end)
  it("on starts at zero", function()
    storage = { boxes = {}, belt_stack = {} }; tick.counters_on()
    eq(tick.counters(), { visits=0, reads=0, pulls=0, pushes=0, items_in=0, items_out=0 })
  end)
  it("counters returns copy", function()
    storage = { boxes = {}, belt_stack = {} }; tick.counters_on(); local c = tick.counters(); ok(c ~= storage.sp_counters); c.visits = 9; eq(tick.counters().visits, 0)
  end)
  it("on again resets", function()
    storage = { boxes = {}, belt_stack = {} }; tick.counters_on(); storage.sp_counters.visits = 4; tick.counters_on(); eq(tick.counters().visits, 0)
  end)
  it("pull counts belt items and items", function()
    storage = { boxes = {}, belt_stack = {} }; tick.counters_on(); local rec = belt_rig({ item(3), item(1) }); belt_io.pull(rec, { 2, 0 }, function(_, _, _, c) return c end)
    eq(tick.counters().pulls, 2); eq(tick.counters().items_in, 4); ok(tick.counters().reads >= 1)
  end)
  it("partial accept counts accepted only", function()
    storage = { boxes = {}, belt_stack = {} }; tick.counters_on(); local rec = belt_rig({ item(3) }); belt_io.pull(rec, { 1, 0 }, function() return 2 end)
    eq(tick.counters().pulls, 1); eq(tick.counters().items_in, 2)
  end)
  it("refused item counts nothing", function()
    storage = { boxes = {}, belt_stack = {} }; tick.counters_on(); local rec = belt_rig({ item(3) }); belt_io.pull(rec, { 1, 0 }, function() return 0 end)
    eq(tick.counters().pulls, 0); eq(tick.counters().items_in, 0)
  end)
  it("reads count each detailed call", function()
    storage = { boxes = {}, belt_stack = {} }; tick.counters_on(); local rec, count = belt_rig({ item(1, 0.5) }); belt_io.pull(rec, { 1, 0 }, function() return 0 end)
    eq(tick.counters().reads, count())
  end)
  it("push counts belt item and items", function()
    storage = { boxes = {}, belt_stack = {} }; tick.counters_on(); local rec = belt_rig({}); belt_io.push(rec, 1, { name="iron", quality="normal", count=4 }, 4)
    eq(tick.counters().pushes, 1); eq(tick.counters().items_out, 4)
    local rec2 = belt_rig({}); local _, _, line = belt_rig({}); function line.can_insert_at_back() return false end
    belt_io.push(rec2, 1, { name="iron", quality="normal", count=4 }, 4)
    eq(tick.counters().pushes, 1); eq(tick.counters().items_out, 4)
  end)
  it("visit counted once per gate pass", function()
    local core, circuit, led = require("scripts.core"), require("scripts.circuit"), require("scripts.led")
    storage = { boxes = {}, belt_stack = { [1] = 1 } }; game = { connected_players = {} }
    settings = { global = { [require("scripts.names").SETTING_TIMEOUT] = { value = 0 } } }
    local rec = { unit_number=1, tier="yellow", dir="north", entity={ valid=true, unit_number=1, force={index=1}, get_inventory=function() return { get_contents=function() return {} end } end }, box={}, settings={ timeout_mode="global", filters={} }, in_credit={0,0}, out_credit={0,0}, next_poll=0 }
    storage.boxes[1] = rec
    local saved = { eval=circuit.evaluate, tick=core.on_tick, idle=core.is_idle, state=core.led_state, set=led.set, rate=belt_io.lane_rate, pull=belt_io.pull, push=belt_io.push }
    local calls = 0; circuit.evaluate=function() calls=calls+1; return false,false end
    core.on_tick=function() end; core.is_idle=function() return true end; core.led_state=function() return "idle" end; led.set=function() end
    belt_io.lane_rate=function() return 1 end; belt_io.pull=function() return {0,0},{nil,nil} end; belt_io.push=function() return 0 end
    tick.counters_on(); for t=1,16 do rec.next_poll=0; tick.on_tick({tick=t}) end
    eq(tick.counters().visits, calls)
    circuit.evaluate=saved.eval; core.on_tick=saved.tick; core.is_idle=saved.idle; core.led_state=saved.state; led.set=saved.set
    belt_io.lane_rate=saved.rate; belt_io.pull=saved.pull; belt_io.push=saved.push
  end)
end)
