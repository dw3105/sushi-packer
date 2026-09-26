-- Every prototype, sprite, setting and input name. Frozen (SP-01): data and control stage both read this file.
local N = {}

N.MOD = "sushi-packer"
N.TIERS = { "yellow", "red", "blue", "turbo" }
N.DIRS = { "north", "east", "south", "west" }
N.LED_STATES = { "green", "yellow", "red" }
N.SLOTS = 48
N.MAX_BELT_STACK = 4

-- Per tier: matching vanilla belt, its tech, circuit for recipe, belt-items per lane per tick (O-4, E-4).
N.TIER = {
  yellow = { belt = "transport-belt",       tech = "logistics",            circuit = "electronic-circuit", lane_rate = 0.125 },
  red    = { belt = "fast-transport-belt",  tech = "logistics-2",          circuit = "advanced-circuit",   lane_rate = 0.25 },
  blue   = { belt = "express-transport-belt", tech = "logistics-3",        circuit = "processing-unit",    lane_rate = 0.375 },
  turbo  = { belt = "turbo-transport-belt", tech = "turbo-transport-belt", circuit = "processing-unit",    lane_rate = 0.5 },
}

function N.item(tier) return "sushi-packer-" .. tier end
function N.placer(tier) return "sushi-packer-" .. tier .. "-placer" end
function N.variant(tier, dir) return "sushi-packer-" .. tier .. "-" .. dir end
function N.remnant(tier) return "sushi-packer-" .. tier .. "-remnants" end
function N.tech(tier) return "sushi-packer-" .. tier end
function N.led(state, dir) return "sushi-packer-led-" .. state .. "-" .. dir end

N.SETTING_TIMEOUT = "sushi-packer-flush-timeout"
N.INPUT_ROTATE = "sushi-packer-rotate"
N.INPUT_REVERSE_ROTATE = "sushi-packer-reverse-rotate"
N.FAST_REPLACE_GROUP = "sushi-packer"

-- Reverse lookups: entity name -> {tier, dir}; placer name -> tier.
N.VARIANTS = {}
N.PLACERS = {}
for _, tier in ipairs(N.TIERS) do
  N.PLACERS[N.placer(tier)] = tier
  for _, dir in ipairs(N.DIRS) do
    N.VARIANTS[N.variant(tier, dir)] = { tier = tier, dir = dir }
  end
end

return N
