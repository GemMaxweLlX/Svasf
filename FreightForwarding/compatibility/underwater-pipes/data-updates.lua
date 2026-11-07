if not mods["underwater-pipes"] then return end

local util = require "__FreightForwarding__.prototypes.data-util"

-- Main underwater pipe is now provided by FF, so hide it

for _, prototype in pairs{
  data.raw.pipe["underwater-pipe"],
  data.raw.pipe["underwater-pipe-placer"],
  data.raw.item["underwater-pipe"],
  data.raw.recipe["underwater-pipe"],
} do
  prototype.hidden = true
end

util.set_ingredients("underwater-pipe-to-ground", {
  {"ff-underwater-pipe", 20},
})

util.remove_recipe_effect("underwater-pipes", "underwater-pipe")

-- Revert bztitanium's changes to underwater pipes
util.remove_prerequisite("underwater-pipes", "titanium-processing")
util.add_prerequisite("underwater-pipes", "automated_water_transport")
