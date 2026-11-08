-- Subsea pipeline (all games except classic mode). Runs in data-updates, after sea-infrastructure.
-- Two pipeline landings facing each other across the water; a pipeline is laid along the seabed between them
-- (scripts/subsea-pipeline.lua). Until it is laid a landing reaches only its neighbour; when the pipeline is done
-- both landings are swapped to their "laid" twins, whose underground connection reaches MAX_DISTANCE tiles.
--   * pipeline landing: built on the vanilla pipe to ground, 1 pipeline segment per tile
--   * duct landing (with Fluid Must Flow): built on the big duct to ground, 4 segments per tile, huge throughput
-- Each kind has its own connection category, so a landing never joins an ordinary pipe to ground underground.

if settings.startup["ff-classic-mode"].value then return end

local util = require("__FreightForwarding__.prototypes.data-util")
local PLANET = mods["space-age"] and {{property = "gravity", min = 0.1}} or nil
local MAX_DISTANCE = 255  -- the engine limit for underground pipes
local TINT = {r = 0.35, g = 0.75, b = 1, a = 1}

local function tinted(prototype, tint)
  local icons = table.deepcopy(prototype.icons or {{icon = prototype.icon, icon_size = prototype.icon_size or 64}})
  for _, icon in pairs(icons) do icon.tint = tint end
  return icons
end

local function tint_sprites(t, tint)
  if type(t) ~= "table" then return end
  if (t.filename or t.filenames or t.stripes) and not t.draw_as_shadow and not t.draw_as_light then t.tint = tint end
  for _, v in pairs(t) do tint_sprites(v, tint) end
end

local function underground(entity, category, distance)
  for _, connection in pairs(entity.fluid_box.pipe_connections) do
    if connection.connection_type == "underground" then
      connection.connection_category = category
      connection.max_underground_distance = distance
    end
  end
end

local effects = {}

local function landing(base_name, name, category, segments, order, ingredients)
  local base = data.raw["pipe-to-ground"][base_name]
  local base_item = data.raw.item[base_name]
  if not (base and base_item) then return false end
  for _, ingredient in pairs(ingredients) do
    if not data.raw.item[ingredient.name] then return false end
  end
  local description = {"entity-description.ff-pipeline-landing", tostring(MAX_DISTANCE), tostring(segments)}

  local entity = table.deepcopy(base)
  entity.name = name
  entity.localised_name = {"entity-name." .. name}
  entity.localised_description = description
  entity.icons = tinted(base, TINT)
  entity.icon = nil
  entity.minable = {mining_time = 1, result = name}
  entity.next_upgrade = nil
  entity.fast_replaceable_group = nil
  entity.max_health = (base.max_health or 150) * 2
  entity.surface_conditions = PLANET
  tint_sprites(entity.pictures, TINT)
  underground(entity, category, 2)

  local laid = table.deepcopy(entity)
  laid.name = name .. "-laid"
  laid.localised_name = {"entity-name.ff-pipeline-landing-laid", {"entity-name." .. name}}
  laid.placeable_by = {item = name, count = 1}
  laid.hidden_in_factoriopedia = true
  underground(laid, category, MAX_DISTANCE)

  local item = table.deepcopy(base_item)
  item.name = name
  item.localised_name = {"entity-name." .. name}
  item.localised_description = description
  item.icons = tinted(base_item, TINT)
  item.icon = nil
  item.place_result = name
  item.order = (base_item.order or "") .. order
  item.stack_size = 10

  data:extend{entity, laid, item, {
    type = "recipe", name = name, enabled = false, energy_required = 10, ingredients = ingredients,
    results = {{type = "item", name = name, amount = 1}},
  }}
  effects[#effects + 1] = {type = "unlock-recipe", recipe = name}
  return true
end

-- Pipeline segment: what is laid along the seabed
local pipe_item = data.raw.item["pipe"]
data:extend{
  {
    type = "item",
    name = "ff-pipeline-segment",
    localised_name = {"item-name.ff-pipeline-segment"},
    localised_description = {"item-description.ff-pipeline-segment"},
    icons = tinted(pipe_item, TINT),
    subgroup = pipe_item.subgroup,
    order = (pipe_item.order or "") .. "-ff-segment",
    stack_size = 100,
    weight = 10 * 1000,
  },
  {
    type = "recipe",
    name = "ff-pipeline-segment",
    enabled = false,
    energy_required = 2,
    ingredients = {
      {type = "item", name = "pipe", amount = 2},
      {type = "item", name = "steel-plate", amount = 1},
      {type = "item", name = data.raw.item["plastic-bar"] and "plastic-bar" or "iron-plate", amount = 1},
    },
    results = {{type = "item", name = "ff-pipeline-segment", amount = 1}},
  },
}
effects[#effects + 1] = {type = "unlock-recipe", recipe = "ff-pipeline-segment"}

landing("pipe-to-ground", "ff-pipeline-landing", "ff-subsea-pipe", 1, "-ff-a", {
  {type = "item", name = "pipe-to-ground", amount = 2},
  {type = "item", name = "steel-plate", amount = 10},
  {type = "item", name = "pump", amount = 1},
})
local duct = landing("duct-underground", "ff-duct-landing", "ff-subsea-duct", 4, "-ff-b", {
  {type = "item", name = "duct-underground", amount = 2},
  {type = "item", name = "steel-plate", amount = 40},
  {type = "item", name = "pump", amount = 4},
})

local prerequisites = {"fluid-handling", "ff-sea-infrastructure"}
if duct and data.raw.technology["ducts"] then prerequisites[#prerequisites + 1] = "ducts" end
for i = #prerequisites, 1, -1 do
  if not data.raw.technology[prerequisites[i]] then table.remove(prerequisites, i) end
end

data:extend{{
  type = "technology",
  name = "ff-subsea-pipeline",
  localised_name = {"technology-name.ff-subsea-pipeline"},
  localised_description = {"technology-description.ff-subsea-pipeline", tostring(MAX_DISTANCE)},
  icons = {{icon = "__base__/graphics/technology/fluid-handling.png", icon_size = 256, tint = TINT}},
  effects = effects,
  prerequisites = prerequisites,
  unit = {
    count = 250,
    ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}},
    time = 30,
  },
}}
