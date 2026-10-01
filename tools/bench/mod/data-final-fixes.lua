local loader = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
loader.name = "sushi-packer-bench-loader"
loader.speed = 1
loader.max_belt_stack_size = 4
loader.adjustable_belt_stack_size = true
loader.minable = nil
loader.next_upgrade = nil
data:extend({ loader })
