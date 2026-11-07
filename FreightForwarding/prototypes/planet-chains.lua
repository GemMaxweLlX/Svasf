-- Space Age: every planet produces something only it can, so freight has to move between planets.
--   Nauvis:   titanium, lead, seabed nodules (ferrous/cupric), offshore oil
--   Vulcanus: cobalt (dredged from cobalt vents in lava lakes), titansteel smelting (prototypes/planet-vulcanus.lua)
--   Fulgora:  cobalt-holmium battery pack production (charging works on any planet); charged packs slowly discharge
--   Aquilo:   lithium battery pack production
-- Batteries are fuel tiers: a charged battery burns into its empty version, which is charged again.
--   1. lead-acid battery (anywhere)  2. cobalt-holmium battery pack (Fulgora)  3. lithium battery pack (Aquilo)
-- Runs in data-updates.

if not mods["space-age"] then return end

local util = require("__FreightForwarding__.prototypes.data-util")
local N = require("__FreightForwarding__.resource-autoplace.noise-util")

local NAUVIS = {{property = "pressure", min = 1000, max = 1000}}
local VULCANUS = {{property = "pressure", min = 4000, max = 4000}}
local FULGORA = {{property = "magnetic-field", min = 99, max = 99}}

local function restrict(recipe_name, conditions)
  local recipe = data.raw.recipe[recipe_name]
  if recipe then recipe.surface_conditions = conditions end
end

local function add_science(tech_name, science_tech, science_pack)
  if not (data.raw.technology[tech_name] and data.raw.technology[science_tech]) then return end
  util.add_prerequisite(tech_name, science_tech)
  util.add_research_ingredient(tech_name, "space-science-pack")
  util.add_research_ingredient(tech_name, science_pack)
end

---------------------------------------------------------------------------------------------------
-- Vulcanus: cobalt vents in lava lakes

local seamount = data.raw.resource["ff-seamount"]
local vulcanus = data.raw.planet and data.raw.planet["vulcanus"]
if seamount and vulcanus and vulcanus.map_gen_settings then
  local vent = table.deepcopy(seamount)
  vent.name = "ff-cobalt-vent"
  vent.localised_name = {"entity-name.ff-cobalt-vent"}
  vent.localised_description = {"entity-description.ff-cobalt-vent"}
  vent.map_color = {1, 0.45, 0.1}
  vent.autoplace = nil  -- placed through Vulcanus' map gen settings below
  local sheet = vent.stages and vent.stages.sheet
  if sheet then sheet.tint = {a = 0.5, r = 0.6, g = 0.25, b = 0.1} end
  -- collision mask is set in data-final-fixes together with the seamount's

  data:extend{
    vent,
    {
      type = "autoplace-control",
      name = "ff-cobalt-vent",
      localised_name = {"", "[entity=ff-cobalt-vent] ", {"entity-name.ff-cobalt-vent"}},
      richness = false,
      order = "z-d",
      category = "resource",
    },
    {
      type = "noise-expression",
      name = "ff_vulcanus_cobalt_vent_probability",
      -- Collision limits vents to lava; keep the landing site clear
      expression = N.num(4 / (64 * 64 ^ 2)) .. " * " .. N.control("ff-cobalt-vent", "frequency") .. " * (distance > 200)",
    },
  }

  local mgs = vulcanus.map_gen_settings
  mgs.property_expression_names = mgs.property_expression_names or {}
  mgs.property_expression_names["entity:ff-cobalt-vent:probability"] = "ff_vulcanus_cobalt_vent_probability"
  mgs.autoplace_controls = mgs.autoplace_controls or {}
  mgs.autoplace_controls["ff-cobalt-vent"] = {}
  if mgs.autoplace_settings and mgs.autoplace_settings.entity and mgs.autoplace_settings.entity.settings then
    mgs.autoplace_settings.entity.settings["ff-cobalt-vent"] = {}
  end
  -- the resource needs an autoplace specification to be placed at all; its probability comes from the planet
  vent.autoplace = {control = "ff-cobalt-vent", order = "c", probability_expression = "0", richness_expression = "10"}
end

-- The dredger mines cobalt crust only on Vulcanus, seabed nodules only on Nauvis
restrict("ff-cobalt-crust", VULCANUS)
restrict("ff-ferrous-nodule", NAUVIS)
restrict("ff-cupric-nodule", NAUVIS)
add_science("ff-cobalt-processing", "metallurgic-science-pack", "metallurgic-science-pack")

---------------------------------------------------------------------------------------------------
-- Fulgora: battery packs are made only there; they can be charged anywhere

restrict("ff-battery-pack", FULGORA)
add_science("ff-battery-pack", "electromagnetic-science-pack", "electromagnetic-science-pack")

-- Tier 2 is a cobalt-holmium battery pack: holmium from Fulgora
util.add_ingredient("ff-battery-pack", "holmium-plate", 2)
for _, name in pairs{"ff-battery-pack", "ff-charged-battery-pack"} do
  local item = data.raw.item[name]
  if item then
    item.localised_name = {"item-name." .. name .. "-cobalt-holmium"}
  end
end

-- Charged battery packs slowly discharge back into empty packs
local charged_pack = data.raw.item["ff-charged-battery-pack"]
if charged_pack and data.raw.item["ff-battery-pack"] then
  charged_pack.spoil_ticks = 60 * 60 * 60  -- 1 hour
  charged_pack.spoil_result = "ff-battery-pack"
end

---------------------------------------------------------------------------------------------------
-- Aquilo: lithium battery packs (tier 3)

local AQUILO = {{property = "pressure", min = 300, max = 300}}
local pack = data.raw.item["ff-battery-pack"]
local charged = data.raw.item["ff-charged-battery-pack"]
if pack and charged and data.raw.item["lithium-plate"] and data.raw.technology["lithium-processing"] then
  local lithium_tint = {r = 0.75, g = 0.95, b = 0.75, a = 1}
  local function icons_of(item, tint)
    local icons = table.deepcopy(item.icons or {{icon = item.icon, icon_size = item.icon_size}})
    for _, icon in pairs(icons) do
      icon.tint = tint and {
        r = (icon.tint and icon.tint.r or 1) * tint.r,
        g = (icon.tint and icon.tint.g or 1) * tint.g,
        b = (icon.tint and icon.tint.b or 1) * tint.b,
        a = 1,
      } or icon.tint
    end
    return icons
  end

  local lithium_pack = table.deepcopy(pack)
  lithium_pack.name = "ff-lithium-battery-pack"
  lithium_pack.localised_name = {"item-name.ff-lithium-battery-pack"}
  lithium_pack.icons = icons_of(pack, lithium_tint)
  lithium_pack.icon = nil
  lithium_pack.order = (pack.order or "") .. "-l"

  local charged_lithium = table.deepcopy(charged)
  charged_lithium.name = "ff-charged-lithium-battery-pack"
  charged_lithium.localised_name = {"item-name.ff-charged-lithium-battery-pack"}
  charged_lithium.icons = icons_of(charged, lithium_tint)
  charged_lithium.icon = nil
  charged_lithium.order = (charged.order or "") .. "-l"
  charged_lithium.fuel_value = "25MJ"
  charged_lithium.fuel_acceleration_multiplier = 2.2
  charged_lithium.fuel_top_speed_multiplier = 1.7
  charged_lithium.burnt_result = "ff-lithium-battery-pack"
  charged_lithium.spoil_ticks = nil  -- lithium packs hold their charge
  charged_lithium.spoil_result = nil

  local charge_recipe = table.deepcopy(data.raw.recipe["ff-charge-battery-pack"])
  charge_recipe.name = "ff-charge-lithium-battery-pack"
  charge_recipe.localised_name = nil
  charge_recipe.ingredients = {{type = "item", name = "ff-lithium-battery-pack", amount = 1}}
  charge_recipe.results = {{type = "item", name = "ff-charged-lithium-battery-pack", amount = 1, independent_probability = 0.998}}
  charge_recipe.energy_required = 25
  charge_recipe.surface_conditions = nil
  charge_recipe.enabled = false

  data:extend{
    lithium_pack,
    charged_lithium,
    charge_recipe,
    {
      type = "recipe",
      name = "ff-lithium-battery-pack",
      categories = {"cryogenics"},
      enabled = false,
      energy_required = 10,
      ingredients = {
        {type = "item", name = "lithium-plate", amount = 3},
        {type = "item", name = "ff-battery-pack", amount = 1},
        {type = "item", name = "processing-unit", amount = 1},
      },
      results = {{type = "item", name = "ff-lithium-battery-pack", amount = 1}},
      surface_conditions = AQUILO,
      allow_productivity = true,
    },
    {
      type = "technology",
      name = "ff-lithium-battery-pack",
      localised_name = {"technology-name.ff-lithium-battery-pack"},
      localised_description = {"technology-description.ff-lithium-battery-pack"},
      icons = table.deepcopy(data.raw.technology["ff-battery-pack"].icons) or {{
        icon = data.raw.technology["ff-battery-pack"].icon,
        icon_size = data.raw.technology["ff-battery-pack"].icon_size,
        tint = lithium_tint,
      }},
      effects = {
        {type = "unlock-recipe", recipe = "ff-lithium-battery-pack"},
        {type = "unlock-recipe", recipe = "ff-charge-lithium-battery-pack"},
      },
      prerequisites = {"ff-battery-pack", "lithium-processing", "cryogenic-science-pack"},
      unit = {
        count = 1000,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
          {"utility-science-pack", 1},
          {"space-science-pack", 1},
          {"electromagnetic-science-pack", 1},
          {"cryogenic-science-pack", 1},
        },
        time = 60,
      },
    },
  }
end
