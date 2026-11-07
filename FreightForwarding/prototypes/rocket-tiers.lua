-- Space Age: tiered rocket silos and landing pads.
--
-- Tier 1 (rocket-silo technology, chemical science):
--   * Light rocket silo: 500 kg lift, 20 rocket parts per launch, cheaper. On Nauvis it can only be built in a
--     rocket silo hole (the classic Freight Forwarding rule).
--   * Light space platform starter pack: 500 kg, so the light silo can start the first platform.
--   * Small cargo landing pad: 20 slots instead of 80, upgradable in place to the normal one.
-- Tier 2 (ff-rocket-silo-2 technology, after space science):
--   * Vanilla rocket silo, starter pack and landing pad. The silo can be built anywhere.
--
-- Runs in data-updates, after Space Age has adjusted the vanilla silo, technology and recipes.

if not mods["space-age"] then return end

local util = require "__FreightForwarding__.prototypes.data-util"

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

local holes_exist = data.raw.resource["ff-rocket-silo-hole"] ~= nil
local dummy = data.raw["mining-drill"]["ff-rocket-silo-dummy"]

local light_silo_item = table.deepcopy(data.raw.item["rocket-silo"])
light_silo_item.name = "ff-light-rocket-silo"
light_silo_item.localised_name = {"entity-name.ff-light-rocket-silo"}
light_silo_item.localised_description = {"entity-description.ff-light-rocket-silo"}
light_silo_item.icons = tinted_icons(data.raw.item["rocket-silo"])
light_silo_item.icon = nil
light_silo_item.order = (light_silo_item.order or "") .. "-a"
-- On Nauvis the light silo goes into a rocket silo hole: the item places the dummy, which only fits on a hole
light_silo_item.place_result = (holes_exist and dummy) and "ff-rocket-silo-dummy" or "ff-light-rocket-silo"

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

if dummy then
  dummy.localised_name = {"entity-name.ff-light-rocket-silo"}
  dummy.localised_description = {"entity-description.ff-light-rocket-silo"}
  dummy.icons = light_silo.icons
  dummy.icon = nil
  dummy.minable = {mining_time = 1, result = "ff-light-rocket-silo"}
  dummy.placeable_by = {item = "ff-light-rocket-silo", count = 1}
  dummy.hidden = nil
end

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

local rocket_silo_tech = data.raw.technology["rocket-silo"]
data:extend{
  {
    type = "technology",
    name = "ff-rocket-silo-2",
    localised_name = {"technology-name.ff-rocket-silo-2"},
    localised_description = {"technology-description.ff-rocket-silo-2"},
    icon = rocket_silo_tech.icon,
    icon_size = rocket_silo_tech.icon_size,
    icons = rocket_silo_tech.icons,
    effects = {
      {type = "unlock-recipe", recipe = "rocket-silo"},
      {type = "unlock-recipe", recipe = "cargo-landing-pad"},
      {type = "unlock-recipe", recipe = "space-platform-starter-pack"},
    },
    prerequisites = {"rocket-silo", "space-science-pack"},
    unit = {
      count = 500,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"space-science-pack", 1},
      },
      time = 60,
    },
    order = (rocket_silo_tech.order or "") .. "-b",
  },
}

-- Anything that required the normal silo technology for travelling to other planets now needs tier 2
for name, technology in pairs(data.raw.technology) do
  if name ~= "ff-rocket-silo-2" and technology.prerequisites then
    for _, prerequisite in pairs(technology.prerequisites) do
      if prerequisite == "space-platform-thruster" then
        util.add_prerequisite(name, "ff-rocket-silo-2")
        break
      end
    end
  end
end
