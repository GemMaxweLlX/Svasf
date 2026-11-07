local legacy = require "__FreightForwarding__.prototypes.legacy"

-- The dredger looks like a 1.3x vanilla pumpjack. Taken from the pumpjack prototype so that sprite
-- sizes always match the game version.
local pumpjack = data.raw["mining-drill"]["pumpjack"]
local dredger_scale = 1.3

local function scale_sprites(t)
  if type(t) ~= "table" then return end
  if t.filename or t.filenames or t.stripes then
    t.scale = (t.scale or 1) * dredger_scale
    if t.shift then
      local x, y = t.shift[1] or t.shift.x, t.shift[2] or t.shift.y
      t.shift = { x * dredger_scale, y * dredger_scale }
    end
  end
  for _, v in pairs(t) do scale_sprites(v) end
end

local dredger_graphics_set = { animation = table.deepcopy(pumpjack.graphics_set.animation) }
scale_sprites(dredger_graphics_set)

local dredger_radius_visualisation = table.deepcopy(pumpjack.radius_visualisation_picture)
if dredger_radius_visualisation then dredger_radius_visualisation.scale = 5 end
-- Dredger includes:
-- mining-drill as place_result of item, that can only be placed on nodule deposits, and includes platform in sprite?
-- assembling-machine which is placed instead of the mining-drill by script
-- tile which is placed around the assembling-machine by script

local sounds = require "__base__.prototypes.entity.sounds"
local hit_effects = require "__base__.prototypes.entity.hit-effects"

legacy.extend{
  {
    type = "recipe-category",
    name = "ff-dredging",
  },
  {
    type = "resource-category",
    name = "ff-seamount",
  },
  {
    type = "technology",
    name = "ff-dredging",
    icon = "__base__/graphics/technology/oil-gathering.png",
    icon_size = 256, icon_mipmaps = 4,
    order = "a",
    prerequisites = {"chemical-science-pack", "ff-battery-charging", "concrete"},
    unit = {
      count = 150,
      ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
      },
      time = 30
    },
    effects = {
      {
        type = "unlock-recipe",
        recipe = "ff-dredging-platform"
      },
      {
        type = "unlock-recipe",
        recipe = "ff-ferrous-nodule"
      },
      {
        type = "unlock-recipe",
        recipe = "ff-cupric-nodule"
      },
      {
        type = "unlock-recipe",
        recipe = "ff-ferrous-nodule-washing"
      },
      {
        type = "unlock-recipe",
        recipe = "ff-cupric-nodule-washing"
      },
    }
  },
  {
    type = "recipe",
    name = "ff-dredging-platform",
    energy_required = 5,
    ingredients =
    {
      {"pumpjack", 1},
      {"landfill", 100},
      {"refined-concrete", 200},
      {"lead-plate", 100},
    },
    result = "ff-dredging-platform",
    enabled = false
  },
  {
    type = "item",
    name = "ff-dredging-platform",
    icon = "__FreightForwarding__/graphics/dredger.png",
    icon_size = 64, icon_mipmaps = 1,
    subgroup = "extraction-machine",
    order = "b[fluids]-d[dredger]",
    place_result = "ff-dredging-platform",
    stack_size = 5
  },
  {
    type = "item",
    name = "ff-dredger-dummy",  -- So that FNEI recognises dredger recipes
    icon = "__FreightForwarding__/graphics/dredger.png",
    icon_size = 64, icon_mipmaps = 1,
    subgroup = "extraction-machine",
    order = "b[fluids]-d[dredger]",
    flags = {"hidden"},
    place_result = "ff-dredger",
    stack_size = 1
  },
  {
    type = "mining-drill",
    name = "ff-dredging-platform",
    icon = "__FreightForwarding__/graphics/dredger.png",
    icon_size = 64, icon_mipmaps = 1,
    flags = {"placeable-neutral", "player-creation"},
    resource_categories = {"ff-seamount"},
    max_health = 200,
    corpse = "pumpjack-remnants",
    dying_explosion = "pumpjack-explosion",
    collision_box = {{ -1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{ -2, -2}, {2, 2}},
    collision_mask = {"object-layer", "train-layer"},
    damaged_trigger_effect = hit_effects.entity(),
    drawing_box = {{-1.6, -2.5}, {1.5, 1.6}},  -- TODO update
    energy_source =
    {
      type = "electric",
      emissions_per_minute = 200,
      usage_priority = "secondary-input"
    },
    energy_usage = "2MW",
    mining_speed = 1,
    resource_searching_radius = 0.5,
    vector_to_place_result = {0, 0},
    radius_visualisation_picture = dredger_radius_visualisation,
    --[[module_specification =
    {
      module_slots = 2
    },]]
    monitor_visualization_tint = {r=78, g=173, b=255},
    graphics_set = dredger_graphics_set,
    vehicle_impact_sound = sounds.generic_impact,
    open_sound = sounds.machine_open,
    close_sound = sounds.machine_close,
    working_sound =
    {
      sound =
      {
        {
          filename = "__base__/sound/pumpjack.ogg",
          volume = 0.7
        },
        --{
        --  filename = "__base__/sound/pumpjack-1.ogg",
        --  volume = 0.43
        --}
      },
      max_sounds_per_type = 3,
      audible_distance_modifier = 0.6,
      fade_in_ticks = 4,
      fade_out_ticks = 10
    },
    created_effect = {
      type = "direct",
      action_delivery = {
        type = "instant",
        source_effects = {
          {
            type = "script",
            effect_id = "ff-dredger-created",
          },
        }
      }
    },
  },
  {
    type = "assembling-machine",
    name = "ff-dredger",
    icon = "__FreightForwarding__/graphics/dredger.png",
    icon_size = 64, icon_mipmaps = 1,
    flags = {"placeable-neutral", "player-creation", "not-blueprintable", "not-deconstructable"},
    crafting_categories = {"ff-dredging"},
    max_health = 200,
    corpse = "pumpjack-remnants",
    dying_explosion = "pumpjack-explosion",
    collision_box = {{ -1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{ -2, -2}, {2, 2}},
    damaged_trigger_effect = hit_effects.entity(),
    drawing_box = {{-1.6, -2.5}, {1.5, 1.6}},  -- TODO update
    energy_source =
    {
      type = "electric",
      emissions_per_minute = 200,
      usage_priority = "secondary-input"
    },
    energy_usage = "2MW",
    crafting_speed = 1,
    resource_searching_radius = 0.49,
    --[[module_specification =
    {
      module_slots = 2
    },]]
    graphics_set = dredger_graphics_set,
    vehicle_impact_sound = sounds.generic_impact,
    open_sound = sounds.machine_open,
    close_sound = sounds.machine_close,
    working_sound =
    {
      sound =
      {
        {
          filename = "__base__/sound/pumpjack.ogg",
          volume = 0.7
        },
        --{
        --  filename = "__base__/sound/pumpjack-1.ogg",
        --  volume = 0.43
        --}
      },
      max_sounds_per_type = 3,
      audible_distance_modifier = 0.6,
      fade_in_ticks = 4,
      fade_out_ticks = 10
    },
  },
  {
    type = "electric-pole",
    name = "ff-dredger-pole",
    icon = "__base__/graphics/icons/substation.png",
    icon_size = 64, icon_mipmaps = 4,
    flags = {"hidden", "not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid"},
    --collision_box = {{-0.7, -0.7}, {0.7, 0.7}},
    --selection_box = {{-1, -1}, {1, 1}},
    maximum_wire_distance = 0,
    supply_area_distance = 14,
    pictures = { filename = "__core__/graphics/empty.png", width = 1, height = 1, direction_count = 1 },
    --vehicle_impact_sound = sounds.generic_impact,
    --open_sound = sounds.electric_network_open,
    --close_sound = sounds.electric_network_close,
    working_sound =
    {
      sound =
      {
        filename = "__base__/sound/substation.ogg",
        volume = 0.4
      },
      max_sounds_per_type = 3,
      audible_distance_modifier = 0.32,
      fade_in_ticks = 30,
      fade_out_ticks = 40,
      use_doppler_shift = false
    },
    connection_points =
    {
      {
        shadow =
        {
          copper = util.by_pixel(136, 8),
          green = util.by_pixel(124, 8),
          red = util.by_pixel(151, 9)
        },
        wire =
        {
          copper = util.by_pixel(0, -86),
          green = util.by_pixel(-21, -82),
          red = util.by_pixel(22, -81)
        }
      },
    },
    radius_visualisation_picture =
    {
      filename = "__base__/graphics/entity/small-electric-pole/electric-pole-radius-visualization.png",
      width = 12,
      height = 12,
      priority = "extra-high-no-scale"
    },
  },
}

-- Dredging platform tile: concrete with a custom texture
local platform = table.deepcopy(data.raw["tile"]["concrete"])
platform.name = "ff-dredging-platform"
platform.order = "a[artificial]-b[tier-2]-a[concrete]"
platform.minable = nil
platform.mined_sound = nil
platform.next_direction = nil
platform.collision_mask = { layers = { ground_tile = true } }  -- Gets added to later
platform.walking_speed_modifier = 1.4
platform.decorative_removal_probability = 0.25
platform.map_color = {r=63, g=61, b=59}
platform.absorptions_per_second = nil
platform.autoplace = nil
platform.variants.material_background = {
  picture = "__FreightForwarding__/graphics/dredging-platform/hr-concrete.png",
  count = 8,
  scale = 0.5,
}
data:extend{platform}

local radar = table.deepcopy(data.raw["radar"]["radar"])
radar.name = "ff-dredger-radar"
radar.flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid"}
radar.hidden = true
radar.minable = nil
radar.connects_to_other_radars = false
radar.circuit_connector = nil
radar.selectable_in_game = false
radar.allow_copy_paste = false
radar.collision_mask = { layers = {} }
radar.collision_box = nil
radar.selection_box = nil
radar.fast_replaceable_group = nil
radar.next_upgrade = nil
radar.pictures = { filename = "__core__/graphics/empty.png", width = 1, height = 1, direction_count = 1 }
radar.max_distance_of_sector_revealed = 0
radar.energy_source = {
  type = "void"
}
radar.energy_usage = "50kW"
radar.water_reflection = nil
radar.working_sound = nil
legacy.extend{radar}
