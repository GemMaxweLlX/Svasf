---------------------------------------------------------------------------------------------------
-- Freight Forwarding resource autoplace, ported to Factorio 2.x string noise expressions.
--
-- Behaviour matches the 1.1 version of this module (itself an extension of vanilla
-- `resource-autoplace.lua`), with the FF-specific extras:
--   * `regular_patch_fade_in_distance_start` - no regular patches before this distance
--   * `starting_resource_placement_ring_radius` - starting patch placed in a ring around spawn
--   * `ideal_aux` / `aux_range` - patches only where `ff_resource_spread` is near ideal_aux
--   * iron ore gets an extra starting patch at the edge of the starting island
--   * regular patches are 15% more spread out (x / 1.15)
---------------------------------------------------------------------------------------------------

local config = require("__FreightForwarding__.resource-autoplace.config")
local N = require("__FreightForwarding__.resource-autoplace.noise-util")

local num, p, call, clamp, min, max = N.num, N.p, N.call, N.clamp, N.min, N.max

---------------------------------------------------------------------------------------------------
-- Patch sets
---------------------------------------------------------------------------------------------------

-- Vanilla's resource-autoplace keeps its patch set bookkeeping in the global
-- `resource_autoplace__patch_metasets`. Sharing it keeps our patch sets from overlapping
-- with resources placed by base/other mods (spot noise `skip_span`/`skip_offset`).
-- If it does not exist (or has an unexpected shape) we fall back to our own.

local function new_patch_metaset(count_expression_name)
  data:extend{{
    type = "noise-expression",
    name = count_expression_name,
    expression = "0",
  }}
  return {
    count_expression_name = count_expression_name,
    next_patch_set_index = 0,
    patch_set_indexes = {},
  }
end

local function valid_metaset(metaset)
  return type(metaset) == "table"
    and type(metaset.count_expression_name) == "string"
    and type(metaset.patch_set_indexes) == "table"
    and type(metaset.next_patch_set_index) == "number"
    and data.raw["noise-expression"][metaset.count_expression_name] ~= nil
end

local metasets
if type(resource_autoplace__patch_metasets) == "table"
    and valid_metaset(resource_autoplace__patch_metasets.regular)
    and valid_metaset(resource_autoplace__patch_metasets.starting) then
  metasets = resource_autoplace__patch_metasets
else
  ff_resource_autoplace__patch_metasets = ff_resource_autoplace__patch_metasets or {
    regular = new_patch_metaset("ff_regular_resource_patch_set_count"),
    starting = new_patch_metaset("ff_starting_resource_patch_set_count"),
  }
  metasets = ff_resource_autoplace__patch_metasets
end

local function get_patch_set_index(metaset, patch_set_name)
  if metaset.patch_set_indexes[patch_set_name] == nil then
    metaset.patch_set_indexes[patch_set_name] = metaset.next_patch_set_index
    metaset.next_patch_set_index = metaset.next_patch_set_index + 1
    data.raw["noise-expression"][metaset.count_expression_name].expression = num(metaset.next_patch_set_index)
  end
  return metaset.patch_set_indexes[patch_set_name]
end

--- Indicate that a patch set exists and optionally that it also needs a separate starting patch set.
local function initialize_patch_set(patch_set_name, has_starting_area_placement)
  get_patch_set_index(metasets.regular, patch_set_name)
  if has_starting_area_placement then
    get_patch_set_index(metasets.starting, patch_set_name)
  end
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

local function basis(seed1, input_scale, output_scale)
  return call("basis_noise", {
    x = "x", y = "y",
    seed0 = "map_seed", seed1 = seed1,
    input_scale = input_scale, output_scale = output_scale,
  })
end

--- Starting spot favourability for a patch placed in a ring of the given radius around spawn.
local function ring_favorability(feasibility, ring_radius)
  return feasibility .. " * 10 * " .. p(N.if_else_chain(
    "distance < " .. num(ring_radius - 300), 0,
    num(ring_radius + 100) .. " < distance", 0,
    "distance < " .. num(ring_radius - 150), "0.1 + " .. N.random(0.1, 2),
    "distance < " .. num(ring_radius - 50), "0.4 + " .. N.random(0.1, 3),
    num(ring_radius + 50) .. " < distance", "0.4 + " .. N.random(0.1, 4),
    "1 + " .. N.random(0.2, 5)
  ))
end

---------------------------------------------------------------------------------------------------
-- Resource autoplace magic
---------------------------------------------------------------------------------------------------

--- Creates and returns an AutoplaceSpecification that will generate spot-based ore patches.
--- See README.md for the parameters.
local function resource_autoplace_settings(params)
  local default = config.presets[params.preset_name] or config.presets.default
  local function param(name, default_name)
    local v = params[name]
    if v == nil then v = default[default_name or name] end
    return v
  end

  local name = params.name
  local ident = N.ident(name)
  local order = param("order")
  local patch_set_name = params.patch_set_name or name
  local control_name = params.autoplace_control_name or name

  local base_density = param("base_density")
  local random_probability = param("random_probability")
  local base_spots_per_km2 = param("base_spots_per_km2")
  local random_spot_size_minimum = param("random_spot_size_minimum")
  local random_spot_size_maximum = param("random_spot_size_maximum")
  local regular_blob_amplitude_multiplier = 1/8 * (params.regular_blob_amplitude_multiplier or default.blob_amplitude_multiplier)
  local starting_blob_amplitude_multiplier = 1/8 * (params.starting_blob_amplitude_multiplier or default.blob_amplitude_multiplier)

  -- Values from the map generator sliders. These are constants for a given map, so the engine folds them.
  local control_frequency = N.control(control_name, "frequency")
  local control_size = N.control(control_name, "size")
  local control_richness = N.control(control_name, "richness")

  local freq_coefficient = param("freq_multiplier_coefficient")
  local size_coefficient = param("size_multiplier_coefficient")
  local frequency_multiplier = p(num(freq_coefficient) .. " * " .. control_frequency)
  local size_multiplier = p(num(size_coefficient) .. " * " .. control_size)
  local density_multiplier = p(frequency_multiplier .. " * " .. size_multiplier)

  local additional_richness = param("additional_richness")
  local minimum_richness = param("minimum_richness")
  local richness_post_multiplier = p(num(param("richness_post_multiplier")) .. " * " .. control_richness)

  local seed1 = params.seed1 or default.seed

  local regular_rq_factor = param("regular_rq_factor_multiplier") / 10 * param("regular_rq_factor_coefficient")
  local starting_rq_factor = param("starting_rq_factor_multiplier") / 7 * param("starting_rq_factor_coefficient")

  local starting_resource_placement_radius = param("starting_resource_placement_radius")
  local starting_resource_placement_ring_radius = params.starting_resource_placement_ring_radius

  local regular_patch_fade_in_distance = param("regular_patch_fade_in_distance")
  local regular_patch_fade_in_distance_start = param("regular_patch_fade_in_distance_start")

  local has_starting = params.has_starting_area_placement

  -- "distance"-dependent helpers return expression strings
  local function regular_ns_multiplier_at(dist)
    if has_starting == nil then return "1" end
    return clamp(p(dist .. " - " .. num(regular_patch_fade_in_distance_start)) .. " / " .. num(regular_patch_fade_in_distance), 0, 1)
  end

  local double_density_distance = param("double_density_distance")
  local regular_blob_amplitude_maximum_distance = double_density_distance
  local spot_enlargement_maximum_distance = regular_blob_amplitude_maximum_distance

  local function size_effective_distance_at(dist)
    if has_starting == nil then return dist end
    return p(dist .. " - " .. num(regular_patch_fade_in_distance))
  end

  local function regular_density_at(dist)
    local effective_distance = clamp(size_effective_distance_at(dist), 0, spot_enlargement_maximum_distance)
    local distance_density_multiplier = p("1 + " .. effective_distance .. " / " .. num(double_density_distance))
    return num(base_density) .. " * " .. density_multiplier .. " * " .. distance_density_multiplier .. " * " .. regular_ns_multiplier_at(dist)
  end

  local spots_per_km2_near_start = p(num(base_spots_per_km2) .. " * " .. frequency_multiplier)
  local candidate_spot_count = param("candidate_spot_count")
  local base_quantity = param("base_quantity")

  local function regular_spot_quantity_base_at(dist)
    return p(p(regular_density_at(dist)) .. " * " .. num(base_quantity) .. " / " .. spots_per_km2_near_start)
  end
  local average_random_size_multiplier = (random_spot_size_minimum + random_spot_size_maximum) / 2
  local function regular_spot_height_typical_at(dist)
    local typical_quantity = p(num(average_random_size_multiplier) .. " * " .. regular_spot_quantity_base_at(dist))
    return p(typical_quantity .. " ^ (1/3) / " .. num((math.pi / 3) * regular_rq_factor ^ 2))
  end

  local regular_density_expression = regular_density_at("distance")
  local regular_spot_quantity_expression =
    N.random_between(random_spot_size_minimum, random_spot_size_maximum, seed1) .. " * " .. regular_spot_quantity_base_at("distance")
  local regular_spot_radius_expression =
    min(param("min_radius_expression"), num(regular_rq_factor) .. " * " .. p(regular_spot_quantity_expression) .. " ^ (1/3)")

  if has_starting ~= nil then
    regular_blob_amplitude_maximum_distance = regular_blob_amplitude_maximum_distance + regular_patch_fade_in_distance
  end
  local function regular_blob_amplitude_at(dist)
    return num(regular_blob_amplitude_multiplier) .. " * " .. min(
      regular_spot_height_typical_at(num(regular_blob_amplitude_maximum_distance)),
      regular_spot_height_typical_at(dist)
    )
  end
  local regular_blob_amplitude_maximum = p(regular_blob_amplitude_at(num(regular_blob_amplitude_maximum_distance)))
  local regular_blob_amplitude_expression = p(regular_blob_amplitude_at("distance"))

  -- Starting spots
  local starting_frequency_multiplier = p("(" .. frequency_multiplier .. " - 1) * 0.5 + 1")
  local starting_amount = p(num(param("starting_amount")) .. " * " .. num(base_density) .. " * " .. starting_frequency_multiplier .. " * " .. size_multiplier)

  local function starting_values(placement_radius)
    local area = math.pi * placement_radius * placement_radius
    local values = {}
    values.density = p(starting_amount .. " / " .. num(area))
    -- 1 inside the starting placement radius, 0 outside (1.1 used infinite sharpness)
    values.modulation = p("distance < " .. num(placement_radius))
    -- Allow resources at lower elevations for starting
    values.feasibility = p(clamp("(elevation - 1) / 10", 0, 1) .. " * " .. values.modulation)
    return values
  end
  local starting = starting_values(starting_resource_placement_radius)

  local minimum_favorability_for_full_placement = 1/4
  local starting_spot_count = frequency_multiplier
  local starting_area_spot_quantity = p(starting_amount .. " / " .. num(minimum_favorability_for_full_placement) .. " / " .. starting_spot_count)
  local starting_spot_height = p(starting_area_spot_quantity .. " ^ (1/3) / " .. num((math.pi / 3) * starting_rq_factor ^ 2))
  local starting_blob_amplitude = p(num(starting_blob_amplitude_multiplier) .. " * " .. starting_spot_height)

  local basement_value = min("-6 * " .. regular_blob_amplitude_maximum, "-6 * " .. starting_blob_amplitude)

  local spot_favorability_expression = "1"
  if params.ideal_aux then
    local aux_range = params.aux_range or 0.05
    spot_favorability_expression = N.if_else_chain(
      "ff_resource_spread < " .. num(params.ideal_aux - aux_range), 0,
      num(params.ideal_aux + aux_range) .. " < ff_resource_spread", 0,
      1
    )
  end

  local regular_spots = call("spot_noise", {
    x = "x / 1.15",  -- Make resources more spread out but bigger
    y = "y / 1.15",
    seed0 = "map_seed",
    seed1 = seed1,
    region_size = 1024,
    candidate_spot_count = candidate_spot_count,
    suggested_minimum_candidate_point_spacing = 45.254833995939045,
    skip_span = metasets.regular.count_expression_name,
    skip_offset = get_patch_set_index(metasets.regular, patch_set_name),
    density_expression = regular_density_expression,
    spot_quantity_expression = regular_spot_quantity_expression,
    hard_region_target_quantity = 0,
    spot_radius_expression = regular_spot_radius_expression,
    spot_favorability_expression = spot_favorability_expression,
    basement_value = basement_value,
    maximum_spot_basement_radius = 128,
  })

  local starting_patch_set_index = 0
  if has_starting == true then
    starting_patch_set_index = get_patch_set_index(metasets.starting, patch_set_name)
  end

  local starting_spot_favorability_expression
  if starting_resource_placement_ring_radius then
    starting_spot_favorability_expression = ring_favorability(starting.feasibility, starting_resource_placement_ring_radius)
  else
    starting_spot_favorability_expression = starting.feasibility .. " * 2 - distance / " .. num(starting_resource_placement_radius) .. " + " .. N.random(0.5, 6)
  end

  local function starting_spot_noise(seed_offset, values, placement_radius, favorability)
    return call("spot_noise", {
      x = "x",
      y = "y",
      seed0 = "map_seed",
      seed1 = seed1 + seed_offset,
      skip_span = metasets.starting.count_expression_name,
      skip_offset = starting_patch_set_index,
      region_size = placement_radius * 2,
      candidate_spot_count = starting_resource_placement_ring_radius and 128 or 32,
      suggested_minimum_candidate_point_spacing = 32,
      density_expression = "3 * " .. values.density .. " * " .. values.modulation,
      spot_quantity_expression = starting_area_spot_quantity,
      hard_region_target_quantity = 1,
      spot_radius_expression = num(starting_rq_factor) .. " * " .. starting_area_spot_quantity .. " ^ (1/3)",
      spot_favorability_expression = favorability,
      basement_value = basement_value,
      maximum_spot_basement_radius = 128,
    })
  end

  local starting_spots = starting_spot_noise(1, starting, starting_resource_placement_radius, starting_spot_favorability_expression)

  local starting_ring_spots = nil
  if name == "iron-ore" then
    -- Iron ore also appears at the edge of the starting island
    local ring_radius = 775
    local ring_placement_radius = 1200
    local ring = starting_values(ring_placement_radius)
    starting_ring_spots = starting_spot_noise(2, ring, ring_placement_radius, ring_favorability(ring.feasibility, ring_radius))
  end

  -- Blobbiness
  local blobs0 = p(basis(seed1, 1/8, 1) .. " + " .. basis(seed1, 1/24, 1))
  local blobs0f = p(blobs0 .. " - 1/4")
  local blobs1 = p(blobs0 .. " + " .. basis(seed1, 1/64, 1.5))
  local blobs1f = p(blobs1 .. " - 1/3")

  local regular_patches = regular_spots .. " + " .. blobs1f .. " * " .. regular_blob_amplitude_expression
  local all_patches
  if has_starting == true then
    local starting_patches = starting_spots .. " + " .. blobs0f .. " * " .. starting_blob_amplitude
    all_patches = max(starting_patches, regular_patches)
    if starting_ring_spots then
      all_patches = max(all_patches, starting_ring_spots .. " + " .. blobs0f .. " * " .. starting_blob_amplitude)
    end
  else
    all_patches = regular_patches
  end

  -- Shared between probability and richness through a named expression
  local patches_name = "ff_" .. ident .. "_patches"
  data:extend{{
    type = "noise-expression",
    name = patches_name,
    expression = all_patches,
  }}

  local probability_expression = clamp(patches_name, 0, 1)
  local richness_expression = patches_name
  if random_probability < 1 then
    richness_expression = p(richness_expression) .. " / " .. num(random_probability)
    probability_expression = probability_expression .. " * " .. call("random_penalty", {
      x = "x", y = "y", seed = seed1, source = 1, amplitude = 1 / random_probability,
    })
  end
  if additional_richness > 0 then
    richness_expression = p(richness_expression .. " + " .. num(additional_richness))
  end
  if minimum_richness > 0 then
    richness_expression = max(richness_expression, minimum_richness)
  end

  local ddd = double_density_distance
  local semd = spot_enlargement_maximum_distance
  local richness_distance_multiplier = max(1, p(num(ddd) .. " + " .. size_effective_distance_at("distance")) .. " / " .. num(ddd + semd))

  richness_expression = p(richness_expression) .. " * " .. richness_distance_multiplier .. " * " .. richness_post_multiplier

  return {
    order = order,
    control = control_name,
    probability_expression = probability_expression,
    richness_expression = richness_expression,
  }
end

---------------------------------------------------------------------------------------------------

return {
  initialize_patch_set = initialize_patch_set,
  resource_autoplace_settings = resource_autoplace_settings,
}
