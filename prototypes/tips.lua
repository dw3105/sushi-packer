-- U-5: explain lane sorting and stacked output in Tips and Tricks.
local N = require("scripts.names")
local simulation = {
  mods = { N.SIM_INTERFACE },
  init = 'remote.call("' .. N.SIM_INTERFACE .. '", "scene", "tips")',
  init_update_count = 0,
  checkboard = true,
}
data:extend({
  { type = "tips-and-tricks-item-category", name = "sushi-packer", order = "z[sushi-packer]" },
  { type = "tips-and-tricks-item", name = N.TIPS, category = "sushi-packer", order = "a[sushi-packer]",
    trigger = { type = "research", technology = N.tech("yellow") }, simulation = simulation },
})
