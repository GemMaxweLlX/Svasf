--[[
Vanilla collision masks:
  water-shallow =
  {
    -- Character collides only with player-layer and train-layer,
    -- this can have any tile collision masks it doesn't matter for being walkable by character but not buildable.
    -- Having water-tile prevents placing paths, ground-tile prevents placing landfill.
    -- Not sure what other side effects could different combinations of tile masks cause.
    "water-tile",
    --"ground-tile",
    "item-layer",
    "resource-layer",
    "object-layer"
    --"doodad-layer"
  },

  water =
  {
    "water-tile",
    "resource-layer",
    "item-layer",
    "player-layer",
    "doodad-layer"
  },

  landfill = {"ground-tile"},

  landfill item.place_as_tile.condition =  { "ground-tile" }

]]

local C = require "__FreightForwarding__.prototypes.collision-util"
local legacy = require "__FreightForwarding__.prototypes.legacy"

-- Custom collision layers (1.1 used get_first_unused_layer(); 2.x uses collision-layer prototypes)
local non_deep_water_layer = C.layer("ff_non_deep_water")
local deep_water_layer = C.layer("ff_deep_water")

for _, name in pairs{"water-shallow", "water-mud", "water", "water-green"} do
  if data.raw.tile[name] then C.add_layer(data.raw.tile[name], non_deep_water_layer) end
end
for _, name in pairs{"deepwater", "deepwater-green"} do
  if data.raw.tile[name] then C.add_layer(data.raw.tile[name], deep_water_layer) end
end

-- Landfill can't be placed on deep water
local landfill_item = data.raw.item["landfill"]
landfill_item.place_as_tile.condition_size = 1
landfill_item.place_as_tile.condition = C.mask{ deep_water_layer, "ground_tile" }

local landfill_recipe = data.raw.recipe["landfill"]
landfill_recipe.ingredients = {
  { type = "item", name = "stone", amount = 20 },
  { type = "item", name = "wood", amount = 1 },
}

local landfill = data.raw.tile["landfill"]

-- Make landfill minable
landfill.minable = {
  mining_time = 0.1, result = "landfill", count = 1,
}
-- 2.x moved/renamed the landfill sound files, so reuse whatever the tile uses for building
local build_sound = landfill.build_sound
if build_sound then
  landfill.mined_sound = table.deepcopy(build_sound.small or build_sound.medium or build_sound)
end

local waterfill_item = data.raw.item["waterfill-item"]
if waterfill_item then
  waterfill_item.order = "c[landfill]-c[waterfill]"
end

-- Add collision layers to crude oil so that it only appears on deep water (also in the map preview).
-- Not with Space Age: Aquilo has crude oil on ice (ground tiles); Nauvis oil is handled by Cargo Ships' settings there.
if not mods["space-age"] then
  local crude_oil = data.raw.resource["crude-oil"]
  C.add_layer(crude_oil, non_deep_water_layer)
  C.add_layer(crude_oil, "ground_tile")
end
