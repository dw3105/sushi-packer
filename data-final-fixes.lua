-- v9 (M-3): extra tiers after belt mods settled speeds, hidden flags and techs.
-- v24 (U-1, FND-0058): vanilla tier techs re-scan ingredient unlocks after other mods moved them.
require("prototypes.tier").relink(data.raw)
require("prototypes.extra").build(data.raw)
require("prototypes.hidden").finalize(data.raw)  -- v16 out arm hand
