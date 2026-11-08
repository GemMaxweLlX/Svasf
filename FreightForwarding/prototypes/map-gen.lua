-- Island terrain ("x-continents" elevation).
-- Originally taken from the IslandStart mod by Yehn (itself based on vanilla 1.1 elevation), modified by Xorimuth.
-- Ported to Factorio 2.x string noise expressions: the maths is the same as the 1.1 Lua noise tree,
-- just written out as text. Map gen variables that no longer exist in 2.x (water_level,
-- wlc_elevation_offset, ...) are recreated below from the "water" autoplace control.

local N = require("__FreightForwarding__.resource-autoplace.noise-util")
local num, p, call, clamp, min, max = N.num, N.p, N.call, N.clamp, N.min, N.max

local function basis(x, y, seed1, input_scale, output_scale)
  return call("basis_noise", {
    x = x, y = y,
    seed0 = "map_seed", seed1 = seed1,
    input_scale = input_scale, output_scale = output_scale,
  })
end

--- Sum of basis noise octaves with an optionally variable persistence.
--- Same construction as 1.1 `simple_variable_persistence_multioctave_noise`.
---@param persistence string|number expression, may vary over the map
local function simple_variable_persistence_multioctave_noise(params)
  local octave_count = params.octave_count or 1
  local octave0_output_scale = params.octave0_output_scale or 1
  local octave0_input_scale = params.octave0_input_scale or 1
  local persistence = params.persistence or 0.5

  local largest_octave_scale = 2 ^ octave_count
  local inscale = octave0_input_scale / largest_octave_scale
  local outscale = octave0_output_scale * largest_octave_scale
  local terms = {}
  for oct = 1, octave_count do
    local amplitude
    if oct == 1 then
      amplitude = num(outscale)
    else
      amplitude = num(outscale) .. " * " .. p(persistence) .. " ^ " .. num(oct - 1)
    end
    terms[oct] = basis(params.x, params.y, params.seed1, inscale, 1) .. " * " .. p(amplitude)
    inscale = inscale * 2
  end
  return p(table.concat(terms, " + "))
end

--- Same as 1.1 `simple_amplitude_corrected_multioctave_noise` (persistence must be a number here).
local function simple_amplitude_corrected_multioctave_noise(params)
  local amplitude = params.amplitude or 1
  local persistence = params.persistence or 0.5
  local octave_count = params.octave_count or 1
  local multiplier = (1 - persistence) / (2 ^ octave_count) / (1 - persistence ^ octave_count)
  return simple_variable_persistence_multioctave_noise{
    x = params.x, y = params.y,
    seed1 = params.seed1,
    octave_count = octave_count,
    octave0_input_scale = params.octave0_input_scale,
    octave0_output_scale = multiplier * amplitude,
    persistence = persistence,
  }
end

-- How strongly the "Water coverage" slider shifts elevation (IslandStart's wlc multiplier)
local IS_wlc_mult = 1.75

data:extend{
  -- Replacement for 1.1's `finite_water_level`: 10 * log2(water coverage), 0 at 100%.
  {
    type = "noise-expression",
    name = "ff_water_level",
    expression = "10 * log2(max(var('control:water:size'), 1/1024))",
  },
  -- Vanilla-1.1-like starting lake, so the player has water close to spawn.
  {
    type = "noise-expression",
    name = "ff_starting_lake_elevation",
    local_expressions = {
      starting_lake_distance = call("distance_from_nearest_point", {
        x = "x", y = "y", points = "starting_lake_positions", maximum_distance = 1024,
      }),
      minimal_starting_lake_bottom = "starting_lake_distance / 4 - 7 + " .. basis("x", "y", 123, 1/8, 1.5),
      -- 1.1 multioctave_noise with persistence 0.75, 5 octaves, octave0_input_scale 1/8
      starting_lake_noise = call("quick_multioctave_noise", {
        x = "x", y = "y",
        seed0 = "map_seed", seed1 = 14,
        input_scale = (1/8) * (1/2) ^ 4,
        output_scale = 2 ^ 4,
        octaves = 5,
        octave_output_scale_multiplier = 0.75,
        octave_input_scale_multiplier = 2,
      }),
    },
    expression = min(
      "minimal_starting_lake_bottom",
      min(
        "-1 + starting_lake_distance / 16 + starting_lake_noise / 16",
        max(2, "2 + starting_lake_distance / 16 + starting_lake_noise / 2")
      )
    ),
  },
}

local terrain_octaves = 10
local roughness_persistence = 0.7
local blotchiness = 2.75
local starting_plateau_octaves = 6

-- opts: bias (higher, closer to 0: lower water level, bigger islands), starting_plateau_bias, island_scale (starting
-- island size), empty_radius (no other islands within this radius of spawn), lakes_scale (higher: more, smaller islands)
local function continents(name, opts)
  local bias = opts.bias
  local starting_plateau_bias = opts.starting_plateau_bias
  local island_scale = opts.island_scale
  local empty_radius = opts.empty_radius
  return {
    -- Similar to vanilla 1.1, but with a big starting island and smaller islands around it.
    -- Name kept from 1.x so existing map exchange strings / presets keep working.
    type = "noise-expression",
    name = name,
    intended_property = "elevation",
    local_expressions = {
      -- Move the point where 'fractal similarity' is obvious off into the boonies
      xs = "x + 20000",
      xb = "x / " .. num(blotchiness),
      yb = "y / " .. num(blotchiness),
      roughness = simple_amplitude_corrected_multioctave_noise{
        x = "xs", y = "y", seed1 = 1,
        octave_count = terrain_octaves - 2,
        amplitude = 1/2,
        octave0_input_scale = (1/2) * 1.8,
        persistence = roughness_persistence,
      },
      persistence = clamp("roughness + 0.3", 0.1, 0.9),
      roughness_start = simple_amplitude_corrected_multioctave_noise{
        x = "xb", y = "yb", seed1 = 1,
        octave_count = terrain_octaves - 2,
        amplitude = 1/2,
        octave0_input_scale = 1/2,
        persistence = roughness_persistence,
      },
      persistence_start = clamp("roughness_start + 0.35", 0.45, 0.7),
      lakes = simple_variable_persistence_multioctave_noise{
        x = "xs", y = "y", seed1 = 1,
        octave_count = terrain_octaves,
        octave0_input_scale = opts.lakes_scale,  -- Higher number means more islands
        octave0_output_scale = 1/8,
        persistence = "persistence",
      },
      starting_plateau_basis = simple_variable_persistence_multioctave_noise{
        x = "xb", y = "yb", seed1 = 2,
        octave_count = starting_plateau_octaves,
        octave0_input_scale = 1/2,
        octave0_output_scale = 1/12,
        persistence = "persistence_start",
      },
      starting_plateau = "starting_plateau_basis + " .. num(starting_plateau_bias)
        .. " + ff_water_level * " .. num(IS_wlc_mult)
        .. " - distance / " .. num(island_scale * 15),
      -- 0 near spawn so that generated continents don't merge with the starting island
      avoid_starting_island = clamp("(distance - " .. num(empty_radius) .. ") / " .. num(empty_radius + 400), 0, 1) .. " ^ 3",
      island_elevation = max(
        "((lakes + " .. num(bias + 80) .. ") * avoid_starting_island - 80) / 8",
        "starting_plateau"
      ),
      -- Water coverage slider: more water lowers everything except the starting plateau
      -- (which was raised by the same amount above).
      water_corrected = "island_elevation - ff_water_level * " .. num(IS_wlc_mult),
    },
    expression = min("water_corrected", "ff_starting_lake_elevation"),
  }
end

data:extend{
  continents("x-continents", {bias = -60, starting_plateau_bias = 20, island_scale = 2.1, empty_radius = 850, lakes_scale = 1}),
  -- Archipelago (scenario and map preset): a small starting island and many small islands close by
  continents("ff-archipelago", {bias = -56, starting_plateau_bias = 8, island_scale = 0.6, empty_radius = 100, lakes_scale = 3}),
  {
    -- Cliffs follow FF's elevation instead of vanilla's (used through the map gen preset / planet settings).
    type = "noise-expression",
    name = "ff_cliff_elevation",
    expression = "elevation",
  },
}

-- Tile placement: same shape as 1.1 `make_water_autoplace_settings(max_elevation, influence)`
data:extend{
  {
    type = "noise-function",
    name = "ff_water_autoplace",
    parameters = {"max_elevation", "influence"},
    expression = "influence * min(max_elevation - elevation, 1)",
  },
}
