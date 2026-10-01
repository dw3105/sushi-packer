-- Every prototype, sprite, setting and input name. Frozen (SP-01): data and control stage both read this file.
local N = {}

N.MOD = "sushi-packer"
N.TIERS = { "yellow", "red", "blue", "turbo" }
N.DIRS = { "north", "east", "south", "west" }
N.LED_STATES = { "green", "yellow", "red" }
N.SLOTS = 48
N.MAX_BELT_STACK = 4
-- v15 arms box (V14-9..11, V15-1): hidden parts on box tile. One prototype each for all tiers.
N.ARM = "sushi-packer-arm"                 -- hidden inserter, locked to one belt lane at runtime
N.STORE = "sushi-packer-lane-store"        -- hidden chest, one per lane
N.STORE_SLOTS = 12                         -- slots per lane store (author 2026-10-01)
N.ARM_FILTERS = 5                          -- skip-kind filter slots per arm (engine max)
N.ARM_HAND = 4                             -- items one arm may hold (prototype stack_size_bonus = hand - 1). Was 12: arms kept items
                                           -- in hand until 12 of one kind while lane store ran empty (trace 2026-10-01, blue dip)
-- arms per lane by belt speed (tiles per tick), first row whose `max` >= speed (FND-0042)
-- hand 4: 270/s needs 12 (8 gave 1271 of 1350); yellow needs 4 (2 passed 95.7 % of a belt of mixed stacks, bench 2026-10-01)
N.ARMS = { { max = 0.125, n = 4 }, { max = 0.3, n = 8 }, { max = math.huge, n = 12 } }

-- Per tier: matching vanilla belt, its tech, belt-items per lane per tick (O-4, E-4).
-- Recipe (U-2, author 2026-09-26): base (steel-chest or previous tier box) + 1 splitter + 2 inserter + circuits.
N.TIER = {
  yellow = { belt = "transport-belt",         tech = "logistics",            lane_rate = 0.125,
             splitter = "splitter",         inserter = "inserter",      circuit = "electronic-circuit", circuits = 5, craft_s = 30 },
  red    = { belt = "fast-transport-belt",    tech = "logistics-2",          lane_rate = 0.25,
             splitter = "fast-splitter",    inserter = "fast-inserter",  circuit = "advanced-circuit",  circuits = 5, craft_s = 45 },
  blue   = { belt = "express-transport-belt", tech = "logistics-3",          lane_rate = 0.375,
             splitter = "express-splitter", inserter = "bulk-inserter",  circuit = "processing-unit",   circuits = 5, craft_s = 60 },
  turbo  = { belt = "turbo-transport-belt",   tech = "turbo-transport-belt", lane_rate = 0.5,
             splitter = "turbo-splitter",   inserter = "stack-inserter", circuit = "quantum-processor", circuits = 2, craft_s = 120 },
}
N.RECIPE_BASE = "steel-chest"       -- yellow base; later tiers use previous tier item
N.TECH_COST_FACTOR = 1.5            -- U-1: count = belt tech count x 1.5 (Deadlock pattern)
N.ITEM_WEIGHT = 20000               -- U-4: 20 kg, 50 per rocket
N.TIPS = "sushi-packer-tips"        -- U-5: tips-and-tricks-item
N.SUBGROUP = "sushi-packer"         -- U-7: own item-subgroup row after belts (group logistics)
N.SIM_INTERFACE = "sushi-packer"    -- U-8: remote interface simulations call (scene)
N.BELT_GROUP = "transport-belt"     -- E-9: placer fast_replaceable_group (FND-0009)

-- U-7 (v6, author 2026-09-26): vanilla belt-series names. yellow "sushi-packer", red "fast-sushi-packer",
-- blue "express-sushi-packer", turbo "turbo-sushi-packer". Tier keys (yellow..turbo) stay internal (storage, graphics).
N.PREFIX = { yellow = "", red = "fast-", blue = "express-", turbo = "turbo-" }
function N.item(tier) return N.PREFIX[tier] .. "sushi-packer" end
function N.placer(tier) return N.item(tier) .. "-placer" end
function N.variant(tier, dir) return N.item(tier) .. "-" .. dir end
function N.remnant(tier) return N.item(tier) .. "-remnants" end
function N.tech(tier) return N.item(tier) end
-- v1.1 names, only for migrations/*.json and their test.
function N.old_item(tier) return "sushi-packer-" .. tier end
function N.led(state, dir) return "sushi-packer-led-" .. state .. "-" .. dir end

N.SETTING_TIMEOUT = "sushi-packer-flush-timeout"
N.INPUT_ROTATE = "sushi-packer-rotate"
N.INPUT_REVERSE_ROTATE = "sushi-packer-reverse-rotate"
N.FAST_REPLACE_GROUP = "sushi-packer"

-- v9 (REQUIREMENTS §17, author 2026-09-28): extra tiers for modded belts. Row counts only when its belt
-- prototype exists, is not hidden and its tech has a science unit (M-1); chain order = belt speed, tie by
-- row order (M-4). Names verified from real prototypes per mod set (FND-0023). paint/wear = G-2 for graphics.
-- v10 (Q11): owners = internal mod names; row live only if one is loaded (clash guard, FND-0027). own_role (Q7) =
-- keep row even when not faster than top vanilla tier; unset everywhere in v10.
-- v11 (M-4): `after` = key of previous row (separate chain; target inactive -> row skipped). own_role without
-- `after` = root tier: no previous box, no previous tech.
-- Row: key (tier key = internal prefix), paint RGB + wear (M-7: mod underground icon median, calibrated to G-2
-- hue kept, V x1.21, S +0.06; hyper = whole-metal median, part is grey), belt, splitter, tech, mod (display), fv.
N.EXTRA = {
  { key = "planetaris-hyper", owners = { "planetaris-arig" }, paint = { 179, 158, 150 }, wear = 0.40, belt = "planetaris-hyper-transport-belt", splitter = "planetaris-hyper-splitter",
    tech = "planetaris-hyper-transport-belt", mod = "Planetaris: Arig", fv = { "2.0", "2.1" } },
  { key = "bob-ultimate", owners = { "boblogistics" }, paint = { 51, 166, 52 }, wear = 0.40, belt = "bob-ultimate-transport-belt", splitter = "bob-ultimate-splitter",
    tech = "logistics-5", mod = "Bob's Logistics", fv = { "2.0", "2.1" } },
  { key = "kr-superior", owners = { "Krastorio2-spaced-out", "Krastorio2" }, paint = { 140, 44, 189 }, wear = 0.40, belt = "kr-superior-transport-belt", splitter = "kr-superior-splitter",
    tech = "kr-logistic-5", mod = "Krastorio 2", fv = { "2.0", "2.1" } },
  { key = "ub-ultra-fast", owners = { "UltimateBeltsSpaceAge" }, paint = { 36, 157, 9 }, wear = 0.40, belt = "ultra-fast-belt", splitter = "ultra-fast-splitter",
    tech = "ultra-fast-logistics", mod = "Ultimate Belts Space Age", fv = { "2.0" } },
  { key = "bb-ultra", owners = { "BetterBelts" }, paint = { 61, 144, 43 }, wear = 0.40, belt = "BetterBelts_ultra-transport-belt", splitter = "BetterBelts_ultra-splitter",
    tech = "BetterBelts_ultra-class", mod = "Better Belts", fv = { "2.0" } },
  { key = "ub-extreme-fast", owners = { "UltimateBeltsSpaceAge" }, paint = { 162, 12, 42 }, wear = 0.40, belt = "extreme-fast-belt", splitter = "extreme-fast-splitter",
    tech = "extreme-fast-logistics", mod = "Ultimate Belts Space Age", fv = { "2.0" } },
  { key = "ub-ultra-express", owners = { "UltimateBeltsSpaceAge" }, paint = { 66, 12, 162 }, wear = 0.40, belt = "ultra-express-belt", splitter = "ultra-express-splitter",
    tech = "ultra-express-logistics", mod = "Ultimate Belts Space Age", fv = { "2.0" } },
  { key = "ub-extreme-express", owners = { "UltimateBeltsSpaceAge" }, paint = { 12, 47, 162 }, wear = 0.40, belt = "extreme-express-belt", splitter = "extreme-express-splitter",
    tech = "extreme-express-logistics", mod = "Ultimate Belts Space Age", fv = { "2.0" } },
  { key = "ub-ultimate", owners = { "UltimateBeltsSpaceAge" }, paint = { 12, 162, 138 }, wear = 0.40, belt = "ultimate-belt", splitter = "original-ultimate-splitter",
    tech = "ultimate-logistics", mod = "Ultimate Belts Space Age", fv = { "2.0" } },
  -- v10 (author 2026-09-29, FND-0028 names from real zips): Advanced Belts 2.0 (no SA) + Space Exploration deep space.
  -- paint (M-7): AB underground icon median calibrated to G-2; SE deep space body grey (icon has no hue). Author "art ok" 2026-09-29.
  { key = "ab-elite", owners = { "AdvancedBeltsUpdated" }, paint = { 139, 179, 72 }, wear = 0.40, belt = "elite-belt", splitter = "elite-splitter",
    tech = "elite-logistics", mod = "Advanced Belts 2.0", fv = { "2.0" } },
  { key = "ab-extreme", owners = { "AdvancedBeltsUpdated" }, paint = { 85, 189, 172 }, wear = 0.40, belt = "extreme-belt", splitter = "extreme-splitter",
    tech = "extreme-logistics", mod = "Advanced Belts 2.0", fv = { "2.0" } },
  { key = "ab-supreme", owners = { "AdvancedBeltsUpdated" }, paint = { 178, 98, 169 }, wear = 0.40, belt = "supreme-belt", splitter = "supreme-splitter",
    tech = "supreme-logistics", mod = "Advanced Belts 2.0", fv = { "2.0" } },
  { key = "ab-ultimate", owners = { "AdvancedBeltsUpdated" }, paint = { 192, 111, 61 }, wear = 0.40, belt = "ultimate-belt", splitter = "ultimate-splitter",
    tech = "ultimate-logistics", mod = "Advanced Belts 2.0", fv = { "2.0" } },
  -- v11 (V11-1..V11-4, author 2026-09-29): SE space belt (45/s ties blue) = own-role root tier; deep space follows it
  -- (`after`), separate SE chain. Paint = SE underground icon light-body median, no V boost (M-7 v11).
  { key = "se-space", owners = { "space-exploration" }, paint = { 215, 215, 215 }, wear = 0.40, belt = "se-space-transport-belt",
    splitter = "se-space-splitter", tech = "se-space-belt", mod = "Space Exploration", fv = { "2.0", "2.1" }, own_role = true },
  { key = "se-deep-space", owners = { "space-exploration" }, paint = { 52, 52, 52 }, wear = 0.40, belt = "se-deep-space-transport-belt-black",
    splitter = "se-deep-space-splitter-black", tech = "se-deep-space-transport-belt", mod = "Space Exploration", fv = { "2.0", "2.1" },
    after = "se-space" },
}
-- Extra tier recipe (M-5): previous tier box 1 + own splitter 1 + inserter 2 + circuits, craft_s.
N.EXTRA_RECIPE = { inserter = "stack-inserter", inserters = 2, circuit = "quantum-processor", circuits = 2, craft_s = 120 }
-- v10 (Q6): game without stack-inserter / quantum-processor (no space-age) -> blue tier set.
N.EXTRA_RECIPE_NOSA = { inserter = "bulk-inserter", inserters = 2, circuit = "processing-unit", circuits = 5, craft_s = 60 }
-- v11 (M-5, V11-3): root tier (own_role, no `after`) replaces previous box with `base` and multiplies inserters +
-- circuits of the recipe set in use (SE space: steel-chest 1, bulk-inserter 4, processing-unit 10, 60 s).
N.EXTRA_RECIPE_ROOT = { base = "steel-chest", mult = 2 }
-- v10 (T-1, Q6): vanilla tiers built only when own belt + tech exist (turbo lives in space-age). Others strict.
N.OPTIONAL_VANILLA = { turbo = true }
N.ALL = {}
for _, t in ipairs(N.TIERS) do N.ALL[#N.ALL + 1] = t end
for _, row in ipairs(N.EXTRA) do
  N.ALL[#N.ALL + 1] = row.key
  N.PREFIX[row.key] = row.key .. "-"
  N.TIER[row.key] = { belt = row.belt, tech = row.tech, splitter = row.splitter, inserter = N.EXTRA_RECIPE.inserter,
    circuit = N.EXTRA_RECIPE.circuit, circuits = N.EXTRA_RECIPE.circuits, craft_s = N.EXTRA_RECIPE.craft_s, extra = row }
end

-- Runtime only (control stage, FND-0022 P3: prototypes readable in main chunk): tier keys whose item
-- prototype exists, in N.ALL order. Vanilla game -> exactly N.TIERS.
function N.active()
  local out = {}
  for _, t in ipairs(N.ALL) do
    if prototypes.item[N.item(t)] then out[#out + 1] = t end
  end
  return out
end

-- Reverse lookups: entity name -> {tier, dir}; placer name -> tier. Over N.ALL (names only; a name with no
-- prototype never reaches an event, filters use N.active()).
N.VARIANTS = {}
N.PLACERS = {}
for _, tier in ipairs(N.ALL) do
  N.PLACERS[N.placer(tier)] = tier
  for _, dir in ipairs(N.DIRS) do
    N.VARIANTS[N.variant(tier, dir)] = { tier = tier, dir = dir }
  end
end

return N
