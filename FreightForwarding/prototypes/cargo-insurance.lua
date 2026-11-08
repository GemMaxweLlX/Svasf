-- Cargo insurance (all games except classic mode). Runs in data-updates.
-- An insurance office is a chest: when a cargo wagon, ship, boat or spidertron of its force is destroyed, part of the
-- cargo (setting ff-insurance-payout) is paid out into the nearest office on the same surface (scripts/cargo-insurance.lua).

if settings.startup["ff-classic-mode"].value then return end

local chest = data.raw.container["steel-chest"]
local chest_item = data.raw.item["steel-chest"]
if not (chest and chest_item) then return end
local TINT = {r = 0.55, g = 0.85, b = 0.45, a = 1}

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

local office = table.deepcopy(chest)
office.name = "ff-insurance-office"
office.localised_name = {"entity-name.ff-insurance-office"}
office.localised_description = {"entity-description.ff-insurance-office"}
office.icons = tinted(chest)
office.icon = nil
office.minable = {mining_time = 0.5, result = "ff-insurance-office"}
office.inventory_size = 96
office.next_upgrade = nil
office.fast_replaceable_group = nil
tint_sprites(office.picture)

local item = table.deepcopy(chest_item)
item.name = "ff-insurance-office"
item.localised_name = office.localised_name
item.localised_description = office.localised_description
item.icons = tinted(chest_item)
item.icon = nil
item.place_result = "ff-insurance-office"
item.order = (chest_item.order or "") .. "-ff-insurance"

local prerequisites = {}
for _, name in pairs{"cargo_ships", "railway"} do
  if data.raw.technology[name] then prerequisites[#prerequisites + 1] = name end
end

data:extend{
  office, item,
  {
    type = "recipe", name = "ff-insurance-office", enabled = false, energy_required = 5,
    ingredients = {
      {type = "item", name = "steel-chest", amount = 1},
      {type = "item", name = "electronic-circuit", amount = 10},
      {type = "item", name = "iron-gear-wheel", amount = 10},
    },
    results = {{type = "item", name = "ff-insurance-office", amount = 1}},
  },
  {
    type = "technology",
    name = "ff-cargo-insurance",
    localised_name = {"technology-name.ff-cargo-insurance"},
    localised_description = {"technology-description.ff-cargo-insurance"},
    icons = {{icon = "__base__/graphics/technology/steel-processing.png", icon_size = 256, tint = TINT}},
    effects = {{type = "unlock-recipe", recipe = "ff-insurance-office"}},
    prerequisites = prerequisites,
    unit = {
      count = 100,
      ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}},
      time = 30,
    },
  },
}
