local builder = require("__sushi-packer__.tests.game.bench_builder")

script.on_init(function()
  game.forces.player.belt_stack_size_bonus = 3
  builder.build(
    game.surfaces[1], game.forces.player,
    settings.startup["sushi-packer-bench-boxes"].value, { 0, 0 }, {
      tier = settings.startup["sushi-packer-bench-tier"].value,
      flow = settings.startup["sushi-packer-bench-flow"].value,
      seed = settings.startup["sushi-packer-bench-seed"].value,
      box = settings.startup["sushi-packer-bench-box"].value,
    }
  )
  remote.call("sushi-packer", "counters_on")
end)

script.on_nth_tick(600, function()
  local c = remote.call("sushi-packer", "counters")
  if type(c) == "table" then
    log(string.format("sushi-packer-bench counters tick=%d visits=%d reads=%d pulls=%d pushes=%d items_in=%d items_out=%d", game.tick, c.visits, c.reads, c.pulls, c.pushes, c.items_in, c.items_out))
  end
end)
