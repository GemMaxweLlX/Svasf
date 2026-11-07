local legacy = require "__FreightForwarding__.prototypes.legacy"
-- With Space Age the game is won by reaching the solar system edge, so the FF endgame is not used.
if mods["Krastorio2"] or mods["SpaceMod"] or mods["space-age"] then return end

local bzutil = require "__FreightForwarding__.prototypes.data-util"

legacy.extend{
  {
    type = "technology",
    name = "ff-interstellar-communication",
    icon_size = 64, icon_mipmaps = 4,
    icon = "__FreightForwarding__/graphics/item/interstellar-communicator.png",
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "ff-interstellar-communicator"
      }
    },
    unit =
    {
      count = 2000,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1}
      },
      time = 60
    },
    prerequisites = {"space-science-pack"},
    order = "c-a"
  },
  {
    type = "item",
    name = "ff-interstellar-communicator",
    icon = "__FreightForwarding__/graphics/item/interstellar-communicator.png",
    icon_size = 64, icon_mipmaps = 4,
    pictures = {
      layers = {
        {
          size = 64,
          filename = "__FreightForwarding__/graphics/item/interstellar-communicator.png",
          scale = 0.25,
          mipmap_count = 4,
        },
        {
          draw_as_light = true,
          flags = { "light" },
          size = 64,
          filename = "__FreightForwarding__/graphics/item/interstellar-communicator-light.png",
          scale = 0.25,
          mipmap_count = 4,
        },
      },
    },
    subgroup = "space-related",
    order = "n[interstellar-communicator]",
    stack_size = 1,
    rocket_launch_products = {{type = "item", name = "space-science-pack", amount = 1000}}
  },
  {
    type = "recipe",
    name = "ff-interstellar-communicator",
    energy_required = 20,
    enabled = false,
    category = "crafting",
    ingredients =
    {
      {"satellite", 1},
      {"low-density-structure", 50},
      {"processing-unit", 50},  -- 2.x: rocket control units were removed
      {"nuclear-fuel", 10}
    },
    result = "ff-interstellar-communicator",
    requester_paste_multiplier = 1
  },
}
--[[
  satellite recipe:
  {"low-density-structure", 100},
  {"solar-panel", 100},
  {"accumulator", 100},
  {"radar", 5},
  {"processing-unit", 100},
  {"rocket-fuel", 50}
]]
local satellite_item = data.raw.item["satellite"]
if satellite_item then
  satellite_item.rocket_launch_product = nil
  satellite_item.rocket_launch_products = {{type = "item", name = "space-science-pack", amount = 200}}
end

-- Reduce satellite cost
bzutil.set_ingredient("satellite", "low-density-structure", 50)
bzutil.set_ingredient("satellite", "solar-panel", 50)
bzutil.set_ingredient("satellite", "accumulator", 50)  -- Will be replaced by charged battery pack
