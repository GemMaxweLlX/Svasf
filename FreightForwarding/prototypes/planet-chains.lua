-- Space Age: every planet produces something only it can, so freight has to move between planets.
--   Nauvis:   titanium, lead, seabed nodules (ferrous/cupric), offshore oil
--   Vulcanus: cobalt (dredged from cobalt vents in lava lakes), titansteel smelting (prototypes/planet-vulcanus.lua)
--   Fulgora:  battery pack assembly and charging (lightning); charged packs slowly discharge
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
-- Fulgora: battery packs

restrict("ff-battery-pack", FULGORA)
restrict("ff-charge-battery-pack", FULGORA)
add_science("ff-battery-pack", "electromagnetic-science-pack", "electromagnetic-science-pack")

-- Charged battery packs slowly discharge back into empty packs
local charged_pack = data.raw.item["ff-charged-battery-pack"]
if charged_pack and data.raw.item["ff-battery-pack"] then
  charged_pack.spoil_ticks = 60 * 60 * 60  -- 1 hour
  charged_pack.spoil_result = "ff-battery-pack"
end
