-- Caravan exchange (extended mode, with Intermodal Containers). Runs in data-updates.
-- A trading post: containers of basic goods put into it are exchanged for containers of another basic good at the
-- caravan's current prices (scripts/caravan-exchange.lua). A way to get a resource your island doesn't have.

if settings.startup["ff-classic-mode"].value then return end
if not data.raw.item["ic-container"] then return end

local chest = data.raw.container["steel-chest"]
local chest_item = data.raw.item["steel-chest"]
if not (chest and chest_item) then return end
local TINT = {r = 1, g = 0.8, b = 0.3, a = 1}

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

local exchange = table.deepcopy(chest)
exchange.name = "ff-caravan-exchange"
exchange.localised_name = {"entity-name.ff-caravan-exchange"}
exchange.localised_description = {"entity-description.ff-caravan-exchange"}
exchange.icons = tinted(chest)
exchange.icon = nil
exchange.minable = {mining_time = 0.5, result = "ff-caravan-exchange"}
exchange.inventory_size = 48
exchange.next_upgrade = nil
exchange.fast_replaceable_group = nil
tint_sprites(exchange.picture)

local item = table.deepcopy(chest_item)
item.name = "ff-caravan-exchange"
item.localised_name = exchange.localised_name
item.localised_description = exchange.localised_description
item.icons = tinted(chest_item)
item.icon = nil
item.place_result = "ff-caravan-exchange"
item.order = (chest_item.order or "") .. "-ff-exchange"

local prerequisites = {}
for _, name in pairs{"ic-containerization-1", "logistic-science-pack"} do
  if data.raw.technology[name] then prerequisites[#prerequisites + 1] = name end
end

data:extend{
  exchange, item,
  {
    type = "recipe", name = "ff-caravan-exchange", enabled = false, energy_required = 5,
    ingredients = {
      {type = "item", name = "steel-chest", amount = 2},
      {type = "item", name = "electronic-circuit", amount = 20},
      {type = "item", name = "ic-container", amount = 10},
    },
    results = {{type = "item", name = "ff-caravan-exchange", amount = 1}},
  },
  {
    type = "technology",
    name = "ff-caravan-exchange",
    localised_name = {"technology-name.ff-caravan-exchange"},
    localised_description = {"technology-description.ff-caravan-exchange"},
    icons = {{icon = "__base__/graphics/technology/logistics-1.png", icon_size = 256, tint = TINT}},
    effects = {{type = "unlock-recipe", recipe = "ff-caravan-exchange"}},
    prerequisites = prerequisites,
    unit = {count = 100, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}}, time = 30},
  },
}
