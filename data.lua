local N = require("scripts.names")

require("prototypes.packer")

local leds = {}
for _, state in ipairs(N.LED_STATES) do
  for _, dir in ipairs(N.DIRS) do
    leds[#leds + 1] = {
      type = "sprite",
      name = N.led(state, dir),
      filename = "__sushi-packer__/graphics/entity/sushi-packer/led/sushi-packer-led-" .. state .. "-" .. dir .. ".png",
      width = 128, height = 128, scale = 0.5,
    }
  end
end
data:extend(leds)

data:extend({
  { type = "custom-input", name = N.INPUT_ROTATE, key_sequence = "", linked_game_control = "rotate" },
  { type = "custom-input", name = N.INPUT_REVERSE_ROTATE, key_sequence = "", linked_game_control = "reverse-rotate" },
})
