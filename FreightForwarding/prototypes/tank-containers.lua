-- Tank containers: fluids in containers, so ships, trains and rockets can carry them without tankers or barrels.
-- One tank holds TANK_VOLUME units; filled and emptied in a chemical plant. Every fluid that can be barrelled gets a
-- tank. Runs at the end of data-updates (after the barrels exist). Not in classic mode.

if settings.startup["ff-classic-mode"].value then return end
if not data.raw.item["ic-container"] then return end

local util = require("__FreightForwarding__.prototypes.data-util")

local TANK_VOLUME = 2000
local TANK_WEIGHT = 500 * 1000  -- 500 kg: two full tanks per rocket
local TINT = {r = 1, g = 0.6, b = 0.25, a = 1}

local container = data.raw.item["ic-container"]
local function base_icons()
  local icons = table.deepcopy(container.icons or {{icon = container.icon, icon_size = container.icon_size or 64}})
  for _, icon in pairs(icons) do icon.tint = TINT end
  return icons
end
local function with_fluid(fluid)
  local icons = base_icons()
  local fluid_icons = table.deepcopy(fluid.icons or {{icon = fluid.icon, icon_size = fluid.icon_size or 64}})
  for _, icon in pairs(fluid_icons) do
    icon.scale = (icon.scale or (32 / (icon.icon_size or 64))) * 0.55
    icon.shift = {0, -2}
    icons[#icons + 1] = icon
  end
  return icons
end

data:extend{
  {type = "item-subgroup", name = "ff-tank-containers", group = data.raw["item-group"]["ic-containers"] and "ic-containers" or "intermediate-products", order = "0-e"},
  {type = "item-subgroup", name = "ff-tank-load", group = data.raw["item-group"]["ic-load-container"] and "ic-load-container" or "intermediate-products", order = "0-e"},
  {type = "item-subgroup", name = "ff-tank-unload", group = data.raw["item-group"]["ic-unload-container"] and "ic-unload-container" or "intermediate-products", order = "0-e"},
  {
    type = "item",
    name = "ff-tank-container",
    icons = base_icons(),
    subgroup = "ff-tank-containers",
    order = "a",
    stack_size = 10,
    ic_create_container = false,
  },
  {
    type = "recipe",
    name = "ff-tank-container",
    enabled = false,
    energy_required = 3,
    ingredients = {
      {type = "item", name = "ic-container", amount = 1},
      {type = "item", name = "steel-plate", amount = 10},
      {type = "item", name = "pipe", amount = 5},
    },
    results = {{type = "item", name = "ff-tank-container", amount = 1}},
  },
}

local effects = {{type = "unlock-recipe", recipe = "ff-tank-container"}}
local fluids = {}
for name, fluid in pairs(data.raw.fluid) do
  if data.raw.item[name .. "-barrel"] and not fluid.hidden then fluids[#fluids + 1] = fluid end
end
table.sort(fluids, function(a, b) return a.name < b.name end)

local function make_tank(fluid, unlocks)
  local name = fluid.name
  local filled = "ff-tank-" .. name
  local icons = with_fluid(fluid)
  local fluid_name = fluid.localised_name or {"fluid-name." .. name}
  data:extend{
    {
      type = "item",
      name = filled,
      localised_name = {"item-name.ff-tank-filled", tostring(TANK_VOLUME), fluid_name},
      icons = icons,
      subgroup = "ff-tank-containers",
      order = "b[" .. name .. "]",
      stack_size = 1,
      weight = TANK_WEIGHT,
      ic_create_container = false,
    },
    {
      type = "recipe",
      name = "ff-tank-load-" .. name,
      localised_name = {"recipe-name.ff-tank-load", fluid_name},
      icons = icons,
      categories = {"chemistry"},
      subgroup = "ff-tank-load",
      order = name,
      enabled = false,
      energy_required = 5,
      ingredients = {
        {type = "item", name = "ff-tank-container", amount = 1},
        {type = "fluid", name = name, amount = TANK_VOLUME},
      },
      results = {{type = "item", name = filled, amount = 1}},
      hide_from_player_crafting = true,
      allow_decomposition = false,
      allow_as_intermediate = false,
    },
    {
      type = "recipe",
      name = "ff-tank-unload-" .. name,
      localised_name = {"recipe-name.ff-tank-unload", fluid_name},
      icons = icons,
      categories = {"chemistry"},
      subgroup = "ff-tank-unload",
      order = name,
      enabled = false,
      energy_required = 5,
      ingredients = {{type = "item", name = filled, amount = 1}},
      results = {
        {type = "item", name = "ff-tank-container", amount = 1},
        {type = "fluid", name = name, amount = TANK_VOLUME},
      },
      main_product = name,
      hide_from_player_crafting = true,
      allow_decomposition = false,
      allow_as_intermediate = false,
    },
  }
  unlocks[#unlocks + 1] = {type = "unlock-recipe", recipe = "ff-tank-load-" .. name}
  unlocks[#unlocks + 1] = {type = "unlock-recipe", recipe = "ff-tank-unload-" .. name}
end

for _, fluid in pairs(fluids) do make_tank(fluid, effects) end

local prerequisites = {}
for _, tech in pairs{"fluid-handling", "ic-containerization-1"} do
  if data.raw.technology[tech] then prerequisites[#prerequisites + 1] = tech end
end
data:extend{{
  type = "technology",
  name = "ff-tank-containers",
  localised_name = {"technology-name.ff-tank-containers"},
  localised_description = {"technology-description.ff-tank-containers", tostring(TANK_VOLUME)},
  icons = {{icon = container.icon, icon_size = container.icon_size or 64, tint = TINT, scale = 2}},
  effects = effects,
  prerequisites = prerequisites,
  unit = {
    count = 150,
    ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}},
    time = 30,
  },
}}

---------------------------------------------------------------------------------------------------
-- Space Age: cryo tanks. Aquilo's fluids that have no barrel get tanks too (with the cryo tanks technology), and
-- cryogenic fluids (below 0 degrees) boil off: a filled tank spoils into a half-empty one after BOIL_TICKS, and that
-- one into an empty tank after another BOIL_TICKS (about 1% a minute). Re-cooling in a cryogenic plant with cold
-- fluoroketone makes the tank fresh again. A planned trip loses a few percent; a forgotten tank is lost.

if not mods["space-age"] then return end
local BOIL_TICKS = 50 * 60 * 60
local AQUILO_FLUIDS = {"ammonia", "fluorine", "lithium-brine"}

local cryo_effects = {}
for _, name in pairs(AQUILO_FLUIDS) do
  local fluid = data.raw.fluid[name]
  if fluid and not data.raw.item["ff-tank-" .. name] then make_tank(fluid, cryo_effects) end
end

local has_cryo_plant = data.raw["recipe-category"]["cryogenics"] and data.raw.fluid["fluoroketone-cold"]
for name, fluid in pairs(data.raw.fluid) do
  local filled = data.raw.item["ff-tank-" .. name]
  if filled and (fluid.default_temperature or 15) < 0 then
    local boiled = "ff-tank-" .. name .. "-boiled"
    local fluid_name = fluid.localised_name or {"fluid-name." .. name}
    local half = math.floor(TANK_VOLUME / 2)
    local icons = table.deepcopy(filled.icons)
    local spoilage = data.raw.item["spoilage"]
    if spoilage and spoilage.icon then
      icons[#icons + 1] = {icon = spoilage.icon, icon_size = spoilage.icon_size or 64, scale = 0.2, shift = {-8, 8}}
    end
    filled.spoil_ticks = BOIL_TICKS
    filled.spoil_result = boiled
    data:extend{
      {
        type = "item",
        name = boiled,
        localised_name = {"item-name.ff-tank-boiled", tostring(half), fluid_name},
        localised_description = {"item-description.ff-tank-boiled"},
        icons = icons,
        subgroup = "ff-tank-containers",
        order = "c[" .. name .. "]",
        stack_size = 1,
        weight = TANK_WEIGHT,
        spoil_ticks = BOIL_TICKS,
        spoil_result = "ff-tank-container",
        ic_create_container = false,
      },
      {
        type = "recipe",
        name = "ff-tank-unload-" .. name .. "-boiled",
        localised_name = {"recipe-name.ff-tank-unload", fluid_name},
        icons = icons,
        categories = {"chemistry"},
        subgroup = "ff-tank-unload",
        order = name .. "-b",
        enabled = false,
        energy_required = 5,
        ingredients = {{type = "item", name = boiled, amount = 1}},
        results = {
          {type = "item", name = "ff-tank-container", amount = 1},
          {type = "fluid", name = name, amount = half},
        },
        main_product = name,
        hide_from_player_crafting = true,
        allow_decomposition = false,
        allow_as_intermediate = false,
      },
    }
    cryo_effects[#cryo_effects + 1] = {type = "unlock-recipe", recipe = "ff-tank-unload-" .. name .. "-boiled"}
    if has_cryo_plant then
      data:extend{{
        type = "recipe",
        name = "ff-tank-recool-" .. name,
        localised_name = {"recipe-name.ff-tank-recool", fluid_name},
        icons = table.deepcopy(filled.icons),
        categories = {"cryogenics"},
        subgroup = "ff-tank-load",
        order = name .. "-r",
        enabled = false,
        energy_required = 2,
        ingredients = {
          {type = "item", name = "ff-tank-" .. name, amount = 1},
          {type = "fluid", name = "fluoroketone-cold", amount = 20},
        },
        results = {
          {type = "item", name = "ff-tank-" .. name, amount = 1, always_fresh = true},
          {type = "fluid", name = "fluoroketone-hot", amount = 20},
        },
        main_product = "ff-tank-" .. name,
        allow_decomposition = false,
        allow_as_intermediate = false,
      }}
      cryo_effects[#cryo_effects + 1] = {type = "unlock-recipe", recipe = "ff-tank-recool-" .. name}
    end
  end
end

if #cryo_effects > 0 and data.raw.technology["cryogenic-science-pack"] then
  data:extend{{
    type = "technology",
    name = "ff-cryo-tanks",
    localised_name = {"technology-name.ff-cryo-tanks"},
    localised_description = {"technology-description.ff-cryo-tanks", tostring(math.floor(BOIL_TICKS / 3600))},
    icons = {{icon = container.icon, icon_size = container.icon_size or 64, tint = {r = 0.6, g = 0.85, b = 1, a = 1}, scale = 2}},
    effects = cryo_effects,
    prerequisites = {"ff-tank-containers", "cryogenic-science-pack"},
    unit = {
      count = 300,
      ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1},
                     {"space-science-pack", 1}, {"cryogenic-science-pack", 1}},
      time = 30,
    },
  }}
end
