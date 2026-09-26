local N = require("scripts.names")

data:extend({
  {
    type = "int-setting",
    name = N.SETTING_TIMEOUT,
    setting_type = "runtime-global",
    default_value = 0,
    minimum_value = 0,
    maximum_value = 3600,
    order = "a",
  },
})
