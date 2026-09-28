-- v9 S0 fixture: vanilla belt entity prototypes (belt_speed tiles/tick; x 480 = items/s). Offline mocks use it as
-- prototypes.entity so belt_io.lane_rate(tier) = belt_speed * 4 matches v8 lane_rate (0.125 .. 0.5).
return {
  ["transport-belt"] = { belt_speed = 0.03125 },
  ["fast-transport-belt"] = { belt_speed = 0.0625 },
  ["express-transport-belt"] = { belt_speed = 0.09375 },
  ["turbo-transport-belt"] = { belt_speed = 0.125 },
}
