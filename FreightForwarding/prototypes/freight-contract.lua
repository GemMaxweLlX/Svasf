-- Space Age: the interstellar freight contract, Freight Forwarding's own victory. Freight consignments are packed
-- from goods of every planet; delivering enough of them to a space platform at the solar system edge (or beyond)
-- wins the game (scripts/freight-contract.lua). Runs in data-updates.

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end

local GOODS = {
  {"ff-titansteel-plate", 10},  -- Nauvis titanium + Vulcanus cobalt
  {"tungsten-carbide", 20},     -- Vulcanus
  {"superconductor", 20},       -- Fulgora
  {"carbon-fiber", 20},         -- Gleba
  {"lithium-plate", 20},        -- Aquilo
}
local ingredients = {}
for _, good in pairs(GOODS) do
  if not data.raw.item[good[1]] then return end
  ingredients[#ingredients + 1] = {type = "item", name = good[1], amount = good[2]}
end
local packaging = data.raw.item["ff-light-container"] and "ff-light-container" or (data.raw.item["ic-container"] and "ic-container")
if packaging then ingredients[#ingredients + 1] = {type = "item", name = packaging, amount = 1} end

local icon_base = data.raw.item[packaging or "ff-titansteel-plate"]
local icons = table.deepcopy(icon_base.icons or {{icon = icon_base.icon, icon_size = icon_base.icon_size or 64}})
for _, icon in pairs(icons) do icon.tint = {r = 1, g = 0.85, b = 0.4, a = 1} end
local promethium = data.raw.item["promethium-asteroid-chunk"]
if promethium then
  table.insert(icons, {icon = promethium.icon, icon_size = promethium.icon_size or 64, scale = 0.25, shift = {-8, -8}})
end

local science = {}
for _, pack in pairs{"automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack",
                     "utility-science-pack", "space-science-pack", "metallurgic-science-pack", "electromagnetic-science-pack",
                     "agricultural-science-pack", "cryogenic-science-pack"} do
  if data.raw.tool[pack] then science[#science + 1] = {pack, 1} end
end

data:extend{
  {
    type = "item",
    name = "ff-freight-consignment",
    icons = icons,
    subgroup = "space-related",
    order = "z[ff-freight-consignment]",
    stack_size = 10,
    weight = 250 * 1000,
    ic_create_container = false,  -- already packed
  },
  {
    type = "recipe",
    name = "ff-freight-consignment",
    enabled = false,
    energy_required = 30,
    ingredients = ingredients,
    results = {{type = "item", name = "ff-freight-consignment", amount = 1}},
    allow_decomposition = false,
  },
  {
    type = "technology",
    name = "ff-interstellar-freight-contract",
    icons = (function()
      local t = table.deepcopy(icons)
      for _, icon in pairs(t) do icon.scale = (icon.scale or 0.5) * 4; if icon.shift then icon.shift = {icon.shift[1] * 4, icon.shift[2] * 4} end end
      return t
    end)(),
    effects = {{type = "unlock-recipe", recipe = "ff-freight-consignment"}},
    prerequisites = {data.raw.technology["stellar-discovery-solar-system-edge"] and "stellar-discovery-solar-system-edge"
                     or "space-science-pack"},
    unit = {count = 1500, ingredients = science, time = 60},
    order = "z[ff-contract]",
  },
}
