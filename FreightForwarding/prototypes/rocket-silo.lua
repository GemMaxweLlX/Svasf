local legacy = require "__FreightForwarding__.prototypes.legacy"
if mods["Mining-Space-Industries-II"] or mods["LunarLandings"] or mods["space-exploration"] then return end

local sounds = require "__base__.prototypes.entity.sounds"

--local rocket_silo = data.raw["rocket-silo"]["rocket-silo"]
--rocket_silo.placeable_by = { item = "rocket-silo", count = 1 }  -- Allows placing rocket silo blueprints outside of holes

data.raw["rocket-silo"]["rocket-silo"].localised_description = {"entity-description.ff-rocket-silo"}
data.raw.technology["rocket-silo"].localised_description = {"technology-description.ff-rocket-silo"}

local rocket_silo = table.deepcopy(data.raw["rocket-silo"]["rocket-silo"])

local rocket_silo_item = data.raw["item"]["rocket-silo"]

-- Placeholder that the rocket silo item places: a mining drill that can only be built on a
-- rocket silo hole. It is replaced by a real silo in scripts/rocket-silo.lua.
-- Built from scratch (copying the 2.x rocket silo drags along fields a mining drill can't have).
local rocket_silo_dummy = {
  type = "mining-drill",
  name = "ff-rocket-silo-dummy",
  localised_name = {"entity-name.rocket-silo"},
  localised_description = rocket_silo.localised_description or {"entity-description.rocket-silo"},
  icon = rocket_silo.icon,
  icon_size = rocket_silo.icon_size,
  icons = rocket_silo.icons,
  flags = {"placeable-player", "player-creation"},
  placeable_by = {item = "rocket-silo", count = 1},
  minable = rocket_silo.minable,
  max_health = rocket_silo.max_health,
  collision_box = rocket_silo.collision_box,
  selection_box = rocket_silo.selection_box,
  collision_mask = { layers = {} },
  energy_source = { type = "void" },
  energy_usage = "1W",
  mining_speed = 1,
  resource_categories = { "ff-rocket-silo" },
  resource_searching_radius = 0.49,
  vector_to_place_result = {0, 0},
  graphics_set = { animation = table.deepcopy(rocket_silo.base_day_sprite) },
  created_effect = {
    type = "direct",
    action_delivery = {
      type = "instant",
      source_effects = {
        {
          type = "script",
          effect_id = "ff-rocket-silo-created",
        },
      }
    }
  },
}
-- TODO give dummy correct energy usage

if mods["space-age"] then
  -- Rocket silos are needed on every planet, but holes only exist on Nauvis: there the restriction
  -- is enforced by script (scripts/rocket-silo.lua) and the item keeps placing a normal silo.
  rocket_silo_dummy.hidden = true
else
  rocket_silo_item.place_result = "ff-rocket-silo-dummy"
end

legacy.extend{
  rocket_silo_dummy,
  {
    type = "resource-category",
    name = "ff-rocket-silo",
  },
  {
    type = "item",
    name = "ff-rocket-silo-hole-dummy",  -- So that the correct words appear when hovering over the patch in map view
    localised_name = {"entity-name.ff-rocket-silo-hole"},
    --icon = "__base__/graphics/icons/assembling-machine-1.png",
    icons = {
      {
        icon = "__base__/graphics/icons/rocket-silo.png",
      },
    },
    icon_size = 64, icon_mipmaps = 4,
    flags = {"hidden"},
    --subgroup = "raw-resource",
    --order = "e[iron-ore]",
    stack_size = 50
  },
  {
    type = "resource",
    name = "ff-rocket-silo-hole",
    icon = "__base__/graphics/icons/rocket-silo.png",
    icon_size = 64, icon_mipmaps = 4,
    flags = {"placeable-neutral"},
    category = "ff-rocket-silo",
    subgroup = "raw-resource",
    order="a-b-c",
    infinite = false,
    highlight = true,
    minimum = 100,  -- Doesn't do anything?
    normal = 100,  -- Doesn't do anything?
    infinite_depletion_amount = 10,
    resource_patch_search_radius = 12,
    tree_removal_probability = 1,
    tree_removal_max_distance = 32 * 32,
    cliff_removal_probability = 1,
    minable =
    {
      mining_time = 1,
      results =
      {
        {
          type = "item",
          name = "ff-rocket-silo-hole-dummy",
          amount = 1,
        }
      }
    },
    --walking_sound = sounds.oil,
    --build_grid_size = 2,
    tile_height = 9, tile_width = 9,
    --collision_box = {{-3.8, -3.2}, {3.8, 3.8}},  -- TODO use smaller collision box, but only if ff-rocket-silo-dummy collides with player
    collision_box = rocket_silo.collision_box,
    selection_box = rocket_silo.selection_box,
    collision_mask = {"resource-layer", "doodad-layer", "player-layer"},
    stage_counts = {0},
    stages =
    {
      sheet =
      {
        filename = "__FreightForwarding__/graphics/rocket-silo/rocket-silo-hole.png",
        priority = "extra-high",
        width = 608,
        height = 596,
        frame_count = 1,
        variation_count = 1,
        scale = 0.5,
        --tint = {a=0.3, r=0.2,g=0.2,b=0.2},
      }
    },
    map_color = {0.1, 0.9, 0.4},
    map_grid = false,
    created_effect = {
      type = "direct",
      action_delivery = {
        type = "instant",
        source_effects = {
          {
            type = "script",
            effect_id = "ff-rocket-silo-hole-created",
          },
        }
      }
    },
  }
}
