-- Space Age: tiered rocket silos and landing pads.
--
-- Tier 1 (rocket-silo technology, chemical science):
--   * Light rocket silo: 500 kg lift, 20 rocket parts per launch, cheaper. On Nauvis it can only be built in a
--     rocket silo hole (the classic Freight Forwarding rule, enforced in scripts/rocket-silo.lua); on other
--     planets it can be built anywhere, so the player can always launch home.
--   * Light space platform starter pack: 500 kg, so the light silo can start the first platform.
--   * Small cargo landing pad: 20 slots instead of 80, upgradable in place to the normal one.
-- Tier 2 (one of three "Heavy-lift rockets" technologies, each needing the science of Vulcanus, Fulgora or Gleba):
--   * Normal rocket silo (1 t), built anywhere. Each planet has its own recipe from local materials that can only
--     be crafted there; Nauvis has none, so silos for Nauvis are imported.
--   * Vanilla cargo landing pad and space platform starter pack.
-- Tier 3 (Aquilo, cryogenic science + titansteel):
--   * Heavy rocket silo: 2 t lift. Its rocket parts use titansteel rocket frames. Titansteel is smelted in the lava
--     pools of Vulcanus from Nauvis titanium and cobalt - they have to be shipped across the solar system.
--
-- Runs in data-updates, after Space Age has adjusted the vanilla silo, technology and recipes.

-- Classic mode keeps the original Freight Forwarding (prototypes/... see settings.lua)
if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end


local kg = 1000
local light_tint = {r = 0.75, g = 0.9, b = 1, a = 1}

local function tinted_icons(prototype)
  if prototype.icons then
    local icons = table.deepcopy(prototype.icons)
    for _, icon in pairs(icons) do icon.tint = light_tint end
    return icons
  end
  return {{icon = prototype.icon, icon_size = prototype.icon_size, tint = light_tint}}
end

local function scaled_ingredients(recipe_name, factor)
  local ingredients = table.deepcopy(data.raw.recipe[recipe_name].ingredients)
  for _, ingredient in pairs(ingredients) do
    ingredient.amount = math.max(1, math.floor(ingredient.amount * factor + 0.5))
  end
  return ingredients
end

---------------------------------------------------------------------------------------------------
-- Light rocket silo

local silo = data.raw["rocket-silo"]["rocket-silo"]
silo.fast_replaceable_group = silo.fast_replaceable_group or "rocket-silo"

local light_silo = table.deepcopy(silo)
light_silo.name = "ff-light-rocket-silo"
light_silo.localised_name = {"entity-name.ff-light-rocket-silo"}
light_silo.localised_description = {"entity-description.ff-light-rocket-silo"}
light_silo.icons = tinted_icons(silo)
light_silo.icon = nil
light_silo.lift_weight = 500 * kg
light_silo.rocket_parts_required = 20
light_silo.minable = {mining_time = silo.minable and silo.minable.mining_time or 1, result = "ff-light-rocket-silo"}
light_silo.placeable_by = nil
light_silo.next_upgrade = "rocket-silo"
light_silo.fast_replaceable_group = silo.fast_replaceable_group

local light_silo_item = table.deepcopy(data.raw.item["rocket-silo"])
light_silo_item.name = "ff-light-rocket-silo"
light_silo_item.localised_name = {"entity-name.ff-light-rocket-silo"}
light_silo_item.localised_description = {"entity-description.ff-light-rocket-silo"}
light_silo_item.icons = tinted_icons(data.raw.item["rocket-silo"])
light_silo_item.icon = nil
light_silo_item.order = (light_silo_item.order or "") .. "-a"
light_silo_item.place_result = "ff-light-rocket-silo"

data:extend{
  light_silo,
  light_silo_item,
  {
    type = "recipe",
    name = "ff-light-rocket-silo",
    enabled = false,
    ingredients = scaled_ingredients("rocket-silo", 0.4),
    energy_required = 20,
    results = {{type = "item", name = "ff-light-rocket-silo", amount = 1}},
    requester_paste_multiplier = 1,
  },
}

-- The normal silo item places a normal silo anywhere
data.raw.item["rocket-silo"].place_result = "rocket-silo"

---------------------------------------------------------------------------------------------------
-- Light space platform starter pack

local starter_pack = data.raw["space-platform-starter-pack"]["space-platform-starter-pack"]
local light_pack = table.deepcopy(starter_pack)
light_pack.name = "ff-light-space-platform-starter-pack"
light_pack.localised_name = {"item-name.ff-light-space-platform-starter-pack"}
light_pack.localised_description = {"item-description.ff-light-space-platform-starter-pack"}
light_pack.icons = tinted_icons(starter_pack)
light_pack.icon = nil
light_pack.order = (light_pack.order or "") .. "-a"
light_pack.weight = 500 * kg
for _, item in pairs(light_pack.initial_items or {}) do
  if item.name == "space-platform-foundation" then
    item.amount = math.max(1, math.floor(item.amount / 2))
  end
end

data:extend{
  light_pack,
  {
    type = "recipe",
    name = "ff-light-space-platform-starter-pack",
    enabled = false,
    ingredients = scaled_ingredients("space-platform-starter-pack", 0.5),
    energy_required = 30,
    results = {{type = "item", name = "ff-light-space-platform-starter-pack", amount = 1}},
  },
}

---------------------------------------------------------------------------------------------------
-- Small cargo landing pad

local pad = data.raw["cargo-landing-pad"]["cargo-landing-pad"]
pad.fast_replaceable_group = pad.fast_replaceable_group or "cargo-landing-pad"

local small_pad = table.deepcopy(pad)
small_pad.name = "ff-small-cargo-landing-pad"
small_pad.localised_name = {"entity-name.ff-small-cargo-landing-pad"}
small_pad.localised_description = {"entity-description.ff-small-cargo-landing-pad"}
small_pad.icons = tinted_icons(pad)
small_pad.icon = nil
small_pad.inventory_size = 20
small_pad.radar_range = math.max(1, math.floor((pad.radar_range or 4) / 2))
small_pad.minable = {mining_time = pad.minable and pad.minable.mining_time or 1, result = "ff-small-cargo-landing-pad"}
small_pad.placeable_by = nil
small_pad.next_upgrade = "cargo-landing-pad"
small_pad.fast_replaceable_group = pad.fast_replaceable_group

local small_pad_item = table.deepcopy(data.raw.item["cargo-landing-pad"])
small_pad_item.name = "ff-small-cargo-landing-pad"
small_pad_item.localised_name = {"entity-name.ff-small-cargo-landing-pad"}
small_pad_item.localised_description = {"entity-description.ff-small-cargo-landing-pad"}
small_pad_item.icons = tinted_icons(data.raw.item["cargo-landing-pad"])
small_pad_item.icon = nil
small_pad_item.order = (small_pad_item.order or "") .. "-a"
small_pad_item.place_result = "ff-small-cargo-landing-pad"

data:extend{
  small_pad,
  small_pad_item,
  {
    type = "recipe",
    name = "ff-small-cargo-landing-pad",
    enabled = false,
    ingredients = scaled_ingredients("cargo-landing-pad", 0.4),
    energy_required = 15,
    results = {{type = "item", name = "ff-small-cargo-landing-pad", amount = 1}},
  },
}

---------------------------------------------------------------------------------------------------
-- Technologies

local function replace_unlock(tech_name, old, new)
  local technology = data.raw.technology[tech_name]
  if not technology then return end
  for _, effect in pairs(technology.effects or {}) do
    if effect.type == "unlock-recipe" and effect.recipe == old then
      effect.recipe = new
    end
  end
end

replace_unlock("rocket-silo", "rocket-silo", "ff-light-rocket-silo")
replace_unlock("rocket-silo", "cargo-landing-pad", "ff-small-cargo-landing-pad")
replace_unlock("rocket-silo", "space-platform-starter-pack", "ff-light-space-platform-starter-pack")
data.raw.technology["rocket-silo"].localised_description = {"technology-description.ff-light-rocket-silo"}

-- Three alternative technologies, one per inner planet. Researching any of them completes the other two
-- (scripts/rocket-silo.lua), which unlocks all three planet recipes; each can only be crafted on its planet.
local rocket_silo_tech = data.raw.technology["rocket-silo"]
local heavy_lift_planets = {
  {
    planet = "vulcanus", science = "metallurgic-science-pack",
    surface_conditions = {{property = "pressure", min = 4000, max = 4000}},
    ingredients = {
      {type = "item", name = "tungsten-carbide", amount = 200},
      {type = "item", name = "tungsten-plate", amount = 100},
      {type = "item", name = "steel-plate", amount = 500},
      {type = "item", name = "concrete", amount = 1000},
      {type = "item", name = "processing-unit", amount = 200},
      {type = "item", name = "electric-engine-unit", amount = 100},
    },
  },
  {
    planet = "fulgora", science = "electromagnetic-science-pack",
    surface_conditions = {{property = "magnetic-field", min = 99, max = 99}},
    ingredients = {
      {type = "item", name = "superconductor", amount = 100},
      {type = "item", name = "supercapacitor", amount = 50},
      {type = "item", name = "holmium-plate", amount = 100},
      {type = "item", name = "steel-plate", amount = 500},
      {type = "item", name = "concrete", amount = 1000},
      {type = "item", name = "processing-unit", amount = 200},
    },
  },
  {
    planet = "gleba", science = "agricultural-science-pack",
    surface_conditions = {{property = "pressure", min = 2000, max = 2000}},
    ingredients = {
      {type = "item", name = "carbon-fiber", amount = 200},
      {type = "item", name = "steel-plate", amount = 500},
      {type = "item", name = "concrete", amount = 1000},
      {type = "item", name = "processing-unit", amount = 200},
      {type = "item", name = "pipe", amount = 100},
    },
  },
}

local function has_all_items(ingredients)
  for _, ingredient in pairs(ingredients) do
    if not (data.raw.item[ingredient.name] or data.raw.tool[ingredient.name]) then return false end
  end
  return true
end

local silo_recipe = data.raw.recipe["rocket-silo"]
for i, entry in pairs(heavy_lift_planets) do
  if data.raw.technology[entry.science] and (data.raw.tool[entry.science] or data.raw.item[entry.science])
      and has_all_items(entry.ingredients) then
    local recipe_name = "ff-rocket-silo-" .. entry.planet
    data:extend{
      {
        type = "recipe",
        name = recipe_name,
        localised_name = {"recipe-name.ff-rocket-silo-planet", {"entity-name.rocket-silo"}, {"space-location-name." .. entry.planet}},
        icons = {
          {icon = data.raw.item["rocket-silo"].icon, icon_size = data.raw.item["rocket-silo"].icon_size},
          {icon = data.raw.planet[entry.planet] and data.raw.planet[entry.planet].icon or data.raw.item["rocket-silo"].icon,
           icon_size = data.raw.planet[entry.planet] and data.raw.planet[entry.planet].icon_size or 64,
           scale = 0.25, shift = {-8, -8}},
        },
        subgroup = data.raw.item["rocket-silo"].subgroup,
        order = (data.raw.item["rocket-silo"].order or "") .. "-" .. i,
        enabled = false,
        ingredients = entry.ingredients,
        energy_required = silo_recipe and silo_recipe.energy_required or 30,
        results = {{type = "item", name = "rocket-silo", amount = 1}},
        surface_conditions = entry.surface_conditions,
        requester_paste_multiplier = 1,
      },
      {
        type = "technology",
        name = "ff-heavy-lift-rockets-" .. entry.planet,
        localised_name = {"technology-name.ff-heavy-lift-rockets", {"space-location-name." .. entry.planet}},
        localised_description = {"technology-description.ff-heavy-lift-rockets"},
        icons = rocket_silo_tech.icons or {{icon = rocket_silo_tech.icon, icon_size = rocket_silo_tech.icon_size}},
        effects = {
          {type = "unlock-recipe", recipe = recipe_name},
          {type = "unlock-recipe", recipe = "cargo-landing-pad"},
          {type = "unlock-recipe", recipe = "space-platform-starter-pack"},
        },
        prerequisites = {"rocket-silo", entry.science},
        unit = {
          count = 500,
          ingredients = {
            {"automation-science-pack", 1},
            {"logistic-science-pack", 1},
            {"chemical-science-pack", 1},
            {"space-science-pack", 1},
            {entry.science, 1},
          },
          time = 60,
        },
        order = (rocket_silo_tech.order or "") .. "-b" .. i,
      },
    }
  end
end

---------------------------------------------------------------------------------------------------
-- Heavy rocket silo (tier 3, Aquilo)

if data.raw.recipe["ff-rocket-frame"] and data.raw.technology["cryogenic-science-pack"] then
  local heavy_silo = table.deepcopy(silo)
  heavy_silo.name = "ff-heavy-rocket-silo"
  heavy_silo.localised_name = {"entity-name.ff-heavy-rocket-silo"}
  heavy_silo.localised_description = {"entity-description.ff-heavy-rocket-silo"}
  heavy_silo.icons = {{icon = silo.icon, icon_size = silo.icon_size, tint = {r = 0.55, g = 0.55, b = 0.6, a = 1}}}
  heavy_silo.icon = nil
  heavy_silo.lift_weight = 2000 * kg
  heavy_silo.fixed_recipe = "ff-heavy-rocket-part"
  heavy_silo.minable = {mining_time = silo.minable and silo.minable.mining_time or 1, result = "ff-heavy-rocket-silo"}
  heavy_silo.placeable_by = nil
  heavy_silo.next_upgrade = nil
  heavy_silo.fast_replaceable_group = silo.fast_replaceable_group
  silo.next_upgrade = "ff-heavy-rocket-silo"

  local heavy_item = table.deepcopy(data.raw.item["rocket-silo"])
  heavy_item.name = "ff-heavy-rocket-silo"
  heavy_item.localised_name = {"entity-name.ff-heavy-rocket-silo"}
  heavy_item.localised_description = {"entity-description.ff-heavy-rocket-silo"}
  heavy_item.icons = heavy_silo.icons
  heavy_item.icon = nil
  heavy_item.order = (heavy_item.order or "") .. "-z"
  heavy_item.place_result = "ff-heavy-rocket-silo"

  local rocket_part = data.raw.recipe["rocket-part"]
  local heavy_part = table.deepcopy(rocket_part)
  heavy_part.name = "ff-heavy-rocket-part"
  heavy_part.localised_name = {"recipe-name.ff-heavy-rocket-part"}
  heavy_part.ingredients = {
    {type = "item", name = "processing-unit", amount = 1},
    {type = "item", name = "ff-rocket-frame", amount = 1},
    {type = "item", name = "rocket-fuel", amount = 1},
  }
  heavy_part.enabled = false

  data:extend{
    heavy_silo,
    heavy_item,
    heavy_part,
    {
      type = "recipe",
      name = "ff-heavy-rocket-silo",
      enabled = false,
      ingredients = {
        {type = "item", name = "ff-titansteel-plate", amount = 200},
        {type = "item", name = "lithium-plate", amount = 100},
        {type = "item", name = "quantum-processor", amount = 50},
        {type = "item", name = "refined-concrete", amount = 500},
        {type = "item", name = "electric-engine-unit", amount = 200},
      },
      energy_required = 60,
      results = {{type = "item", name = "ff-heavy-rocket-silo", amount = 1}},
      requester_paste_multiplier = 1,
    },
    {
      type = "technology",
      name = "ff-heavy-rocket-silo",
      localised_name = {"technology-name.ff-heavy-rocket-silo"},
      localised_description = {"technology-description.ff-heavy-rocket-silo"},
      icons = {{icon = rocket_silo_tech.icon, icon_size = rocket_silo_tech.icon_size, tint = {r = 0.55, g = 0.55, b = 0.6, a = 1}}},
      effects = {
        {type = "unlock-recipe", recipe = "ff-heavy-rocket-silo"},
        {type = "unlock-recipe", recipe = "ff-heavy-rocket-part"},
      },
      prerequisites = {"cryogenic-science-pack", "ff-titansteel-processing"},
      unit = {
        count = 1000,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1},
          {"utility-science-pack", 1},
          {"space-science-pack", 1},
          {"cryogenic-science-pack", 1},
        },
        time = 60,
      },
      order = (rocket_silo_tech.order or "") .. "-c",
    },
  }
end
