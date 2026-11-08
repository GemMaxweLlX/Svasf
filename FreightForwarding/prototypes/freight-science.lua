-- Space Age: interplanetary freight science pack, the final assembly on Aquilo from components of every planet:
--   transport science (Nauvis), titansteel (Vulcanus), charged battery pack (Fulgora, discharges in transit),
--   refrigerated container (Gleba), lithium (Aquilo).
-- Defines the pack in data-updates; prototypes/freight-science-final.lua adds it to the technologies in
-- data-final-fixes.

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end
if not (data.raw.technology["cryogenic-science-pack"] and data.raw.item["lithium-plate"]) then return end

local AQUILO = {{property = "pressure", min = 300, max = 300}}

local transport_pack = data.raw.tool["ff-transport-science-pack"]
local freight_tint = {r = 0.55, g = 0.9, b = 1, a = 1}

local ingredients = {
  {type = "item", name = "ff-transport-science-pack", amount = 2},
  {type = "item", name = "ff-titansteel-plate", amount = 1},
  {type = "item", name = "ff-charged-battery-pack", amount = 1},
  {type = "item", name = "lithium-plate", amount = 2},
}
if data.raw.item["ff-reefer-container"] then
  table.insert(ingredients, {type = "item", name = "ff-reefer-container", amount = 1})
else
  table.insert(ingredients, {type = "item", name = "carbon-fiber", amount = 2})
end

local prerequisites = {"cryogenic-science-pack", "ff-titansteel-processing", "ff-battery-pack"}
if data.raw.technology["ff-refrigerated-containers"] then table.insert(prerequisites, "ff-refrigerated-containers") end

data:extend{
  {
    type = "tool",
    name = "ff-freight-science-pack",
    localised_name = {"item-name.ff-freight-science-pack"},
    localised_description = {"item-description.ff-freight-science-pack"},
    icons = {{icon = transport_pack.icon, icon_size = transport_pack.icon_size or 64, tint = freight_tint}},
    subgroup = "science-pack",
    order = "j[ff-freight-science-pack]",
    stack_size = 200,
    weight = 1000,  -- 1 kg, like the other Space Age science packs
    durability = 1,
    durability_description_key = "description.science-pack-remaining-amount-key",
    durability_description_value = "description.science-pack-remaining-amount-value",
  },
  {
    type = "recipe",
    name = "ff-freight-science-pack",
    categories = {"cryogenics"},
    enabled = false,
    energy_required = 20,
    ingredients = ingredients,
    results = {{type = "item", name = "ff-freight-science-pack", amount = 2}},
    surface_conditions = AQUILO,
    allow_productivity = true,
  },
  {
    type = "technology",
    name = "ff-freight-science-pack",
    localised_name = {"technology-name.ff-freight-science-pack"},
    localised_description = {"technology-description.ff-freight-science-pack"},
    icons = {{
      icon = data.raw.technology["ff-transport-science-pack"].icon,
      icon_size = data.raw.technology["ff-transport-science-pack"].icon_size,
      tint = freight_tint,
    }},
    effects = {{type = "unlock-recipe", recipe = "ff-freight-science-pack"}},
    prerequisites = prerequisites,
    unit = {
      count = 1000,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"space-science-pack", 1},
        {"cryogenic-science-pack", 1},
      },
      time = 60,
    },
  },
}

-- Every lab that accepts cryogenic science also accepts freight science
for _, lab in pairs(data.raw.lab) do
  local inputs = lab.inputs or {}
  for i, input in pairs(inputs) do
    if input == "cryogenic-science-pack" then
      table.insert(inputs, i + 1, "ff-freight-science-pack")
      break
    end
  end
end
