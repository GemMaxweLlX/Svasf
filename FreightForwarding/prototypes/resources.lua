-- Resource placement for the FF island world.
local resource_autoplace = require("__FreightForwarding__.resource-autoplace.resource-autoplace")
local N = require("__FreightForwarding__.resource-autoplace.noise-util")
local call, clamp = N.call, N.clamp

-- Large-scale noise deciding which ores appear where (replaces vanilla 'aux' for FF resources).
-- 0.4 affects size of features. Smaller number means bigger 'islands'.
data:extend{
  {
    type = "noise-expression",
    name = "ff_resource_spread",
    expression = clamp("0.5 + " .. call("quick_multioctave_noise", {
      x = "x + 20000", y = "y",
      seed0 = "map_seed", seed1 = 7,
      input_scale = (1/2048) * 0.4,
      output_scale = 1/4,
      octaves = 4,
      octave_output_scale_multiplier = 1/2,
      octave_input_scale_multiplier = 3,
    }), 0, 1),
  },
}

local function set_autoplace(resource_name, params)
  local resource = data.raw.resource[resource_name]
  if not resource then
    log("[FreightForwarding] resource " .. resource_name .. " not found, autoplace not changed")
    return
  end
  resource.autoplace = resource_autoplace.resource_autoplace_settings(params)
end

-- Redefine base resources so that they pick up modified defaults from config.lua
set_autoplace("iron-ore", {
  -- iron-ore has a hardcoded special case in resource-autoplace.lua so that it appears both
  -- in the starting area and at the edge of the starting island
  name = "iron-ore",
  order = "b",
  base_density = 10,
  starting_amount = 40000,
  has_starting_area_placement = true,
  regular_rq_factor_multiplier = 1.1,
  starting_rq_factor_multiplier = 1.3,
  candidate_spot_count = 22,
  ideal_aux = 0.15,
  aux_range = 0.1,
})
set_autoplace("copper-ore", {
  name = "copper-ore",
  order = "b",
  base_density = 8,
  has_starting_area_placement = true,
  regular_rq_factor_multiplier = 1.1,
  starting_rq_factor_multiplier = 1.2,
  candidate_spot_count = 22,
  ideal_aux = 0.8,
  aux_range = 0.1,
})
set_autoplace("coal", {
  name = "coal",
  order = "b",
  base_density = 8,
  has_starting_area_placement = true,
  regular_rq_factor_multiplier = 1.0,
  starting_rq_factor_multiplier = 1.2,
  ideal_aux = 0.4,
})
set_autoplace("stone", {
  name = "stone",
  order = "b",
  base_density = 4,
  has_starting_area_placement = true,
  regular_rq_factor_multiplier = 1.0,
  starting_rq_factor_multiplier = 1.1,
  ideal_aux = 0.6,
})

local empty_radius = 1800

set_autoplace("uranium-ore", {
  name = "uranium-ore",
  order = "c",
  base_density = 0.9,
  base_spots_per_km2 = 1.25,
  has_starting_area_placement = false,
  random_spot_size_minimum = 2,
  random_spot_size_maximum = 4,
  regular_rq_factor_multiplier = 1,
  regular_patch_fade_in_distance_start = empty_radius,
  regular_patch_fade_in_distance = empty_radius + 100,
  ideal_aux = 0.3,
})

if mods["bzlead"] then
  -- override BZ's autoplace, but keeping same values for richness
  set_autoplace("lead-ore", {
    name = "lead-ore",
    order = "b-z",
    base_density = 6,
    base_spots_per_km2 = 1,
    has_starting_area_placement = true,
    regular_rq_factor_multiplier = 1.2,
    starting_rq_factor_multiplier = 1.7,
    starting_resource_placement_ring_radius = 775,  -- Spawns the starting patch somewhere at distance from the center
    starting_resource_placement_radius = 1200,
    regular_patch_fade_in_distance_start = 1200,
    regular_patch_fade_in_distance = 1200,
    ideal_aux = 0.7,
  })
end

if mods["bztitanium"] then
  set_autoplace("titanium-ore", {
    name = "titanium-ore",
    order = "b-z",
    base_density = 3,
    has_starting_area_placement = false,
    regular_rq_factor_multiplier = 0.7,
    regular_patch_fade_in_distance_start = empty_radius,
    regular_patch_fade_in_distance = empty_radius + 100,
    ideal_aux = 0.5,
    aux_range = 0.1,
  })
end

-- Seamounts: in deep ocean only
data:extend{
  {
    type = "autoplace-control",
    name = "ff-seamount",
    localised_name = {"entity-name.ff-seamount"},
    richness = false,
    order = "z-a",
    category = "resource",
  },
}

data.raw.resource["ff-seamount"].autoplace = {
  control = "ff-seamount",
  order = "c",
  -- 0.8 seamounts per 64x64 area of deep (elevation < -20) ocean, scaled by the frequency slider
  probability_expression = N.num(0.8 / (64 * 64 ^ 2)) .. " * " .. N.control("ff-seamount", "frequency") .. " * (elevation < -20)",
  richness_expression = "10",  -- Overwritten in control by script trigger
}

-- Lava pools
data:extend{
  {
    type = "autoplace-control",
    name = "ff-lava-pool",
    localised_name = {"", "[entity=ff-lava-pool] ", {"entity-name.ff-lava-pool"}},
    richness = false,
    order = "z-b",
    category = "resource",
  },
}

resource_autoplace.initialize_patch_set("ff-lava-pool", false)
data.raw.resource["ff-lava-pool-resource"].autoplace = resource_autoplace.resource_autoplace_settings{
  name = "ff-lava-pool",
  order = "a", -- Other resources are "b"; lava will override if something else is already there.
  base_density = 8.2,
  base_spots_per_km2 = 2,
  random_probability = 1/48,
  random_spot_size_minimum = 0.8,
  random_spot_size_maximum = 1.2,
  size_multiplier_coefficient = 4,
  has_starting_area_placement = false,
  regular_rq_factor_multiplier = 1,
  starting_resource_placement_radius = 3000,
  regular_patch_fade_in_distance_start = 3000,
  regular_patch_fade_in_distance = 3000,
  ideal_aux = 0.9,
}

if data.raw.resource["ff-rocket-silo-hole"] then
  data:extend{
    {
      type = "autoplace-control",
      name = "ff-rocket-silo-hole",
      localised_name = {"entity-name.ff-rocket-silo-hole"},
      richness = false,
      order = "z-c",
      category = "resource",
    },
  }

  data.raw.resource["ff-rocket-silo-hole"].autoplace = {
    control = "ff-rocket-silo-hole",
    order = "a",
    -- Only on high ground (elevation > 8), far from spawn (> 4000 tiles), away from lava pools
    probability_expression = N.num(1.4 / (64 * 64 ^ 2)) .. " * " .. N.control("ff-rocket-silo-hole", "frequency")
      .. " * (elevation > 8) * (distance > 4000) * (ff_resource_spread < 0.6)",
    richness_expression = "10",  -- Overwritten in control by script trigger
  }
end
