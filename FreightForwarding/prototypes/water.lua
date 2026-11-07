local legacy = require "__FreightForwarding__.prototypes.legacy"
local C = require "__FreightForwarding__.prototypes.collision-util"

-- Adjust water autoplace (max_elevation, influence), see ff_water_autoplace in map-gen.lua
-- Vanilla 1.1:  Water: (0, 100), Deepwater: (-2, 200)
local function water_autoplace(max_elevation, influence)
  return { probability_expression = "ff_water_autoplace(" .. max_elevation .. ", " .. influence .. ")" }
end

data.raw["tile"]["water-shallow"].autoplace = water_autoplace(0, 25)
data.raw["tile"]["water"].autoplace = water_autoplace(-2.5, 100)
data.raw["tile"]["deepwater"].autoplace = water_autoplace(-8, 200)

local mud_water = data.raw.tile["water-mud"]
mud_water.walking_speed_modifier = 0.7  -- Default 0.8
mud_water.vehicle_friction_modifier = 32

local shallow_water = data.raw.tile["water-shallow"]
shallow_water.walking_speed_modifier = 0.7  -- Default 0.8
shallow_water.vehicle_friction_modifier = 32  -- Default 1
-- doodad stops decoratives spawning on shallow water
shallow_water.collision_mask = C.mask{ "water_tile", "floor", "resource", "doodad" }

-- Allow player to swim in water
local water = data.raw.tile["water"]
local deep_water = data.raw.tile["deepwater"]
water.walking_speed_modifier = 0.25
deep_water.walking_speed_modifier = 0.25

for _, water_tile in pairs{water, deep_water} do
  C.remove_layer(water_tile, "player")
end

legacy.extend{
  {
    type = "sprite",
    name = "ff-life-ring-front",
    filename = "__FreightForwarding__/graphics/life-ring/life-ring-front.png",
    width = 120,
    height = 81,
  },
  {
    type = "sprite",
    name = "ff-life-ring-back",
    filename = "__FreightForwarding__/graphics/life-ring/life-ring-back.png",
    width = 120,
    height = 81,
  },
  {
    type = "sprite",
    name = "ff-life-ring-front-shadow",
    filename = "__FreightForwarding__/graphics/life-ring/life-ring.png",
    width = 120,
    height = 81,
    draw_as_shadow = true,
  },
  {
    type = "sprite",
    name = "ff-water-legs",
    filename = "__FreightForwarding__/graphics/life-ring/water-legs.png",
    width = 100,
    height = 100,
    tint = {a=0.6, r=0.2,g=0.2,b=0.2},
  },
  {
    type = "explosion",
    name = "ff-life-ring-splash",
    localised_name = {"entity-name.water-splash"},
    icon = "__base__/graphics/icons/fluid/water.png",
    icon_size = 64, icon_mipmaps = 4,
    flags = {"not-on-map", "hidden", "placeable-off-grid"},
    subgroup = "fluid-explosions",
    animations = util.empty_sprite(),
    created_effect =
    {
      type = "direct",
      action_delivery =
      {
        type = "instant",
        target_effects =
        {
          type = "create-particle",
          repeat_count = 3,
          repeat_count_deviation = 2,
          particle_name = "tintable-water-particle",  -- 2.x: "deep-water-particle" was removed
          tint = {0.226, 0.341, 0.337, 0.314},
          offsets =
          {
            { 0, 0 }
          },
          offset_deviation = { { -0.15, -0.15 }, { 0.15, 0.15 } },
          initial_height = 0,
          initial_height_deviation = 0.01,
          initial_vertical_speed = 0.02,
          initial_vertical_speed_deviation = 0.005,
          speed_from_center = 0.01,
          speed_from_center_deviation = 0.003,
          frame_speed = 1,
          frame_speed_deviation = 0,
          tail_length = 9,
          tail_length_deviation = 0,
          tail_width = 1
        }
      }
    }
  },
}
