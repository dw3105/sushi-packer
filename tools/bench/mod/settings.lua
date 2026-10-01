data:extend({
  { type = "int-setting", name = "sushi-packer-bench-boxes", setting_type = "startup", default_value = 200, minimum_value = 1, maximum_value = 1000, order = "a" },
  { type = "string-setting", name = "sushi-packer-bench-tier", setting_type = "startup", default_value = "yellow", allow_blank = false, order = "b" },
  { type = "string-setting", name = "sushi-packer-bench-flow", setting_type = "startup", default_value = "single", allowed_values = { "single", "stacks" }, order = "c" },
  { type = "int-setting", name = "sushi-packer-bench-seed", setting_type = "startup", default_value = 1, minimum_value = 0, order = "d" },
  { type = "bool-setting", name = "sushi-packer-bench-box", setting_type = "startup", default_value = true, order = "e" },
})
