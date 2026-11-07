local legacy = require "__FreightForwarding__.prototypes.legacy"
local util = require "__FreightForwarding__.prototypes.data-util"

legacy.extend{
  {
    type = "tool",
    name = "ff-transport-science-pack",
    localised_description = {"item-description.science-pack"},
    icon = "__FreightForwarding__/graphics/transport-science-pack-item.png",
    icon_size = 64, icon_mipmaps = 4,
    subgroup = "science-pack",
    order = "b[logistic-science-pack]-a[transport-science-pack]",
    stack_size = 100,
    durability = 1,
    durability_description_key = "description.science-pack-remaining-amount-key",
    durability_description_value = "description.science-pack-remaining-amount-value"
  },
  {
    type = "recipe",
    name = "ff-transport-science-pack",
    enabled = false,
    energy_required = 14,
    ingredients =
    {
      {"rail", 1},
      {"big-electric-pole", 1}
    },
    result_count = 2,
    result = "ff-transport-science-pack"
  },
  {
    type = "technology",
    name = "ff-transport-science-pack",
    localised_name = {"technology-name.ff-transport-science-pack"},
    localised_description = {"technology-description.ff-transport-science-pack"},
    icon_size = 256, icon_mipmaps = 4,
    icon = "__FreightForwarding__/graphics/transport-science-pack-technology.png",
    prerequisites = {"railway", "electric-energy-distribution-1"},
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "ff-transport-science-pack"
      }
    },
    unit =
    {
      count = 75,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
      },
      time = 5
    },
    order = "c-a"
  },
}

-- Most tech adjustments are in data-final-fixes.lua

-- Insert FF Science Pack before these techs:
util.add_prerequisite("fluid-handling", "ff-transport-science-pack")
util.add_prerequisite("water_transport", "ff-transport-science-pack")
util.add_prerequisite("automobilism", "ff-transport-science-pack")  -- Can't easily drive to lead ore

-- Simplify tech tree dependencies already covered by FF Science Pack:
util.remove_prerequisite("fluid-handling", "engine")
util.remove_prerequisite("water_transport", "engine")
util.remove_prerequisite("water_transport", "logistics-2")
util.remove_prerequisite("automobilism", "engine")
util.remove_prerequisite("automobilism", "logistics-2")


data.raw.recipe["pipe-to-ground"].enabled = false
util.add_unlock("fluid-handling", "pipe-to-ground", 1)

-- Every lab that accepts logistic science also accepts transport science (incl. Space Age's biolab)
for _, lab in pairs(data.raw.lab) do
  local inputs = lab.inputs or {}
  for i, input in pairs(inputs) do
    if input == "logistic-science-pack" then
      table.insert(inputs, i + 1, "ff-transport-science-pack")
      break
    end
  end
end
util.allow_productivity("ff-transport-science-pack")

-- Merge deep sea oil with pumpjack tech
local deep_sea_oil = data.raw.technology["deep_sea_oil_extraction"]
local oil_processing = data.raw.technology["oil-processing"]
if deep_sea_oil and oil_processing then
  deep_sea_oil.hidden = true
  if deep_sea_oil.icons then
    oil_processing.icons = table.deepcopy(deep_sea_oil.icons)
  else
    oil_processing.icon = deep_sea_oil.icon
    oil_processing.icon_size = deep_sea_oil.icon_size
    oil_processing.icons = nil
  end
  util.add_unlock("oil-processing", "oil_rig", 2)
end
