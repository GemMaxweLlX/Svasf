-- Space Age: lava pools are on Vulcanus instead of Nauvis, so titansteel is smelted there.
-- Titanium and cobalt still come from Nauvis (outer islands and seabed), so titansteel needs an
-- interplanetary supply chain.

if not mods["space-age"] then return end

local vulcanus = data.raw.planet and data.raw.planet["vulcanus"]
if not (vulcanus and vulcanus.map_gen_settings and data.raw.resource["ff-lava-pool-resource"]) then return end

local resource_autoplace = require("__FreightForwarding__.resource-autoplace.resource-autoplace")

-- Same pool shape as on Nauvis 1.x, but closer to the landing site (Vulcanus has no starting island to leave)
-- and without the resource spread zones, which follow Nauvis' terrain.
local autoplace = resource_autoplace.resource_autoplace_settings{
  name = "ff-lava-pool-vulcanus",
  autoplace_control_name = "ff-lava-pool",
  patch_set_name = "ff-lava-pool-vulcanus",
  order = "a",
  base_density = 8.2,
  base_spots_per_km2 = 1,
  random_probability = 1/48,
  random_spot_size_minimum = 0.8,
  random_spot_size_maximum = 1.2,
  size_multiplier_coefficient = 4,
  has_starting_area_placement = false,
  regular_rq_factor_multiplier = 1,
  starting_resource_placement_radius = 300,
  regular_patch_fade_in_distance_start = 400,
  regular_patch_fade_in_distance = 400,
}

data:extend{
  {
    type = "noise-expression",
    name = "ff_vulcanus_lava_pool_probability",
    expression = autoplace.probability_expression,
  },
  {
    type = "noise-expression",
    name = "ff_vulcanus_lava_pool_richness",
    expression = autoplace.richness_expression,
  },
}

local mgs = vulcanus.map_gen_settings
mgs.property_expression_names = mgs.property_expression_names or {}
mgs.property_expression_names["entity:ff-lava-pool-resource:probability"] = "ff_vulcanus_lava_pool_probability"
mgs.property_expression_names["entity:ff-lava-pool-resource:richness"] = "ff_vulcanus_lava_pool_richness"
mgs.autoplace_controls = mgs.autoplace_controls or {}
mgs.autoplace_controls["ff-lava-pool"] = {}
if mgs.autoplace_settings and mgs.autoplace_settings.entity and mgs.autoplace_settings.entity.settings then
  mgs.autoplace_settings.entity.settings["ff-lava-pool-resource"] = {}
end

-- Titansteel processing becomes a Vulcanus technology
local util = require("__FreightForwarding__.prototypes.data-util")
if data.raw.technology["ff-titansteel-processing"] and data.raw.technology["metallurgic-science-pack"] then
  util.add_prerequisite("ff-titansteel-processing", "metallurgic-science-pack")
  util.add_research_ingredient("ff-titansteel-processing", "space-science-pack")
  util.add_research_ingredient("ff-titansteel-processing", "metallurgic-science-pack")
end
