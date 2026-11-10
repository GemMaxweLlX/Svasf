-- Dry dock (extended mode, with Cargo Ships). Runs in data-updates, after ship-tiers.
-- A shore building with a big storage: ships stopped within DOCK_RADIUS tiles are repaired with repair packs from its
-- inventory, and can be swapped to another ship type (e.g. cargo ship -> fast cargo ship) without unloading:
-- put the new ship in the dock and choose it in the panel; cargo, fuel and schedule move over and the old ship
-- goes into the dock (scripts/dry-dock.lua).

if settings.startup["ff-classic-mode"].value then return end
if not (data.raw["cargo-wagon"]["cargo_ship"] and data.raw.technology["cargo_ships"]) then return end

local chest = data.raw.container["steel-chest"]
local chest_item = data.raw.item["steel-chest"]
if not (chest and chest_item) then return end
local TINT = {r = 0.45, g = 0.6, b = 0.75, a = 1}
local PLANET = mods["space-age"] and {{property = "gravity", min = 0.1}} or nil

local function tinted(prototype)
  local icons = table.deepcopy(prototype.icons or {{icon = prototype.icon, icon_size = prototype.icon_size or 64}})
  for _, icon in pairs(icons) do icon.tint = TINT end
  return icons
end

local function tint_sprites(t)
  if type(t) ~= "table" then return end
  if (t.filename or t.filenames or t.stripes) and not t.draw_as_shadow then t.tint = TINT end
  for _, v in pairs(t) do tint_sprites(v) end
end

local dock = table.deepcopy(chest)
dock.name = "ff-dry-dock"
dock.localised_name = {"entity-name.ff-dry-dock"}
dock.localised_description = {"entity-description.ff-dry-dock"}
dock.icons = tinted(chest)
dock.icon = nil
dock.minable = {mining_time = 1, result = "ff-dry-dock"}
dock.inventory_size = 60
dock.max_health = 1000
dock.next_upgrade = nil
dock.fast_replaceable_group = nil
dock.surface_conditions = PLANET
dock.radius_visualisation_specification = {
  sprite = {filename = "__core__/graphics/visualization-construction-radius.png", size = 12},
  distance = 16,
}
tint_sprites(dock.picture)

local item = table.deepcopy(chest_item)
item.name = "ff-dry-dock"
item.localised_name = dock.localised_name
item.localised_description = dock.localised_description
item.icons = tinted(chest_item)
item.icon = nil
item.place_result = "ff-dry-dock"
item.order = (chest_item.order or "") .. "-ff-dock"
item.stack_size = 10

data:extend{
  dock, item,
  {
    type = "recipe", name = "ff-dry-dock", enabled = false, energy_required = 10,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 50},
      {type = "item", name = "iron-gear-wheel", amount = 40},
      {type = "item", name = "electronic-circuit", amount = 20},
      {type = "item", name = "repair-pack", amount = 20},
    },
    results = {{type = "item", name = "ff-dry-dock", amount = 1}},
  },
  {
    type = "technology",
    name = "ff-dry-dock",
    localised_name = {"technology-name.ff-dry-dock"},
    localised_description = {"technology-description.ff-dry-dock"},
    icons = tinted(data.raw.technology["cargo_ships"]),
    effects = {{type = "unlock-recipe", recipe = "ff-dry-dock"}},
    prerequisites = {"cargo_ships"},
    unit = {count = 150, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}}, time = 30},
  },
}
