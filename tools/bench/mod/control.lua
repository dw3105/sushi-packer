local builder = require("__sushi-packer__.tests.game.bench_builder")

script.on_init(function()
  game.forces.player.belt_stack_size_bonus = 3
  builder.build(
    game.surfaces[1], game.forces.player,
    settings.startup["sushi-packer-bench-boxes"].value, { 0, 0 }
  )
end)
