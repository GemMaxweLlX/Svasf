local legacy = require "__FreightForwarding__.prototypes.legacy"
local util = require "__FreightForwarding__.prototypes.data-util"

legacy.extend{
  {
    type = "fuel-category",
    name = "advanced-chemical"
  },
}
data.raw.item["rocket-fuel"].fuel_category = "advanced-chemical"
data.raw.item["nuclear-fuel"].fuel_category = "advanced-chemical"

local locomotive = data.raw["locomotive"]["locomotive"]
-- 2.x: locomotives use `energy_source` instead of `burner`
local locomotive_burner = locomotive.energy_source or locomotive.burner

if data.raw["locomotive"]["mini-locomotive"] then
  -- Won't get "advanced-chemical" added
  data.raw["locomotive"]["mini-locomotive"].ff_no_advanced_fuel = true
end
if not settings.startup["ff-revert-locomotive-fuel-category"].value then
  locomotive_burner.fuel_categories = {"battery"}
else
  locomotive_burner.fuel_categories = {"chemical", "battery"}
end
locomotive_burner.fuel_category = nil
locomotive_burner.fuel_inventory_size = 3
locomotive_burner.burnt_inventory_size = 3
locomotive_burner.ff_no_double_inventory_size = true

-- Integrate mini trains, move regular trains to later in the tech tree
if mods["Mini_Trains"] and data.raw.item["mini-locomotive"] then
  util.hide_technology("mini-trains")
  local railway_tech = data.raw.technology["railway"]
  railway_tech.icon = "__Mini_Trains__/data/icons/tech256.png"
  railway_tech.icon_size = 256
  railway_tech.icons = nil
  util.remove_recipe_effect("railway", "locomotive")
  util.remove_recipe_effect("railway", "cargo-wagon")
  util.add_unlock("railway", "mini-locomotive")
  util.add_unlock("railway", "mini-cargo-wagon")

  local fluid_wagon_tech = data.raw.technology["fluid-wagon"]
  fluid_wagon_tech.icon = "__Mini_Trains__/data/icons/fluid256.png"
  fluid_wagon_tech.icon_size = 256
  fluid_wagon_tech.icons = nil
  util.remove_recipe_effect("fluid-wagon", "fluid-wagon")
  util.add_unlock("fluid-wagon", "mini-fluid-wagon")

  for _, name in pairs{"mini-locomotive", "mini-cargo-wagon", "mini-fluid-wagon"} do
    local item = util.get_item(name)
    if item then item.subgroup = "train-transport" end
  end
  local function set_order(name, order)
    local item = util.get_item(name)
    if item then item.order = order end
  end
  set_order("mini-locomotive", "a[train-system]-ef[mini]-a[locomotive]")
  set_order("mini-cargo-wagon", "a[train-system]-ef[mini]-b[cargo-wagon]")
  set_order("mini-fluid-wagon", "a[train-system]-ef[mini]-c[fluid-wagon]")

  util.set_ingredient("mini-locomotive", "engine-unit", 15)  -- Was 5
  util.set_ingredient("mini-cargo-wagon", "iron-plate", 20)  -- Was 5
  util.set_ingredient("mini-fluid-wagon", "pipe", 4)  -- Was 20
  util.add_ingredient("mini-fluid-wagon", "storage-tank", 1)

  legacy.extend{
    {
      type = "technology",
      name = "ff-advanced-railway",
      icon_size = 256,
      icon = "__base__/graphics/technology/railway.png",
      effects =
      {
        { type = "unlock-recipe", recipe = "locomotive" },
        { type = "unlock-recipe", recipe = "cargo-wagon" },
        { type = "unlock-recipe", recipe = "fluid-wagon" },
      },
      prerequisites = {"ff-battery-charging", "electric-engine", "fluid-wagon"},
      unit =
      {
        count = 150,
        ingredients =
        {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
        },
        time = 30
      },
      order = "c-g-a"
    },
  }
end

--[[ Vanilla locomotive ingredients:
  {"engine-unit", 20}, {"electronic-circuit", 10}, {"steel-plate", 30}
]]
util.set_ingredients("locomotive", {
  {"electric-engine-unit", 20},
  {"advanced-circuit", 10},
  {"steel-plate", 50}
})

util.set_ingredients("cargo-wagon", {
  {"iron-gear-wheel", 20},
  {"iron-plate", 40},
  {"steel-plate", 40}
})

util.set_ingredients("fluid-wagon", {
  {"iron-gear-wheel", 20},
  {"steel-plate", 32},
  {"pipe", 16},
  {"storage-tank", 1}
})

data.raw["cargo-wagon"]["cargo-wagon"].inventory_size = 50  -- was 40, will become 5 later on
