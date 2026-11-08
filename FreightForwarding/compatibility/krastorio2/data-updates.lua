-- Krastorio 2 (2.1) and Krastorio 2 Spaced Out: data-updates (after K2's own data-updates).
-- Ported from the 1.1 compatibility (see TODO.md); K2 2.x names everything "kr-".
if not mods["Krastorio2"] then return end

local util = require "__FreightForwarding__.prototypes.data-util"
local space_age = mods["space-age"] ~= nil
local classic = settings.startup["ff-classic-mode"].value

local function item(name)
  for _, type in pairs{"item", "tool", "ammo", "capsule", "module", "item-with-entity-data", "rail-planner"} do
    if data.raw[type] and data.raw[type][name] then return data.raw[type][name] end
  end
end

-- Steel pump: some drain, like FF's pumps
if data.raw.pump["kr-steel-pump"] and data.raw.pump["kr-steel-pump"].energy_source then
  data.raw.pump["kr-steel-pump"].energy_source.drain = "1.5kW"
end
-- Steam turbines take FF's 500°C steam (titansteel cooling)
if data.raw.generator["steam-turbine"] then data.raw.generator["steam-turbine"].maximum_temperature = 500 end

-- Matter: iron and copper come from seabed nodules in FF, not from matter
for _, entry in pairs{{"kr-matter-iron-processing", "kr-matter-to-iron-ore"}, {"kr-matter-copper-processing", "kr-matter-to-copper-ore"}} do
  if data.raw.recipe[entry[2]] then
    data.raw.recipe[entry[2]].hidden = true
    util.remove_recipe_effect(entry[1], entry[2])
  end
end

-- Matter: cobalt conversion (ore -> matter) and cobalt ingots from matter (with a stabilizer)
if data.raw.technology["kr-matter-processing"] and data.raw.fluid["kr-matter"] and data.raw.item["ff-cobalt-ore"]
    and data.raw.item["ff-cobalt-ingot"] and data.raw["recipe-category"]["kr-matter-conversion"] then
  local base_tech = data.raw.technology["kr-matter-iron-processing"] or data.raw.technology["kr-matter-processing"]
  local tech = table.deepcopy(base_tech)
  tech.name = "kr-matter-cobalt-processing"
  tech.localised_name = {"technology-name.kr-matter-cobalt-processing"}
  tech.localised_description = nil
  tech.effects = {}
  tech.prerequisites = {"kr-matter-processing"}
  local ore, ingot = data.raw.item["ff-cobalt-ore"], data.raw.item["ff-cobalt-ingot"]
  local function icons(proto) return table.deepcopy(proto.icons or {{icon = proto.icon, icon_size = proto.icon_size or 64}}) end
  data:extend{
    tech,
    {
      type = "recipe",
      name = "kr-ff-cobalt-ore-to-matter",
      localised_name = {"recipe-name.kr-to-matter", {"item-name.ff-cobalt-ore"}},
      icons = icons(ore),
      categories = {"kr-matter-conversion"},
      subgroup = data.raw["item-subgroup"]["kr-matter-conversion"] and "kr-matter-conversion" or nil,
      hide_from_player_crafting = true,
      enabled = false,
      energy_required = 1,
      ingredients = {{type = "item", name = "ff-cobalt-ore", amount = 10}},
      results = {{type = "fluid", name = "kr-matter", amount = 5}},
      allow_as_intermediate = false,
    },
    {
      type = "recipe",
      name = "kr-matter-to-ff-cobalt-ingot",
      localised_name = {"recipe-name.kr-matter-to", {"item-name.ff-cobalt-ingot"}},
      icons = icons(ingot),
      categories = {"kr-matter-deconversion"},
      subgroup = data.raw["item-subgroup"]["kr-matter-deconversion"] and "kr-matter-deconversion" or nil,
      hide_from_player_crafting = true,
      enabled = false,
      energy_required = 2,
      ingredients = {
        {type = "fluid", name = "kr-matter", amount = 7.5},
        {type = "item", name = "kr-charged-matter-stabilizer", amount = 1},
      },
      results = {
        {type = "item", name = "ff-cobalt-ingot", amount = 10},
        {type = "item", name = "kr-matter-stabilizer", amount = 1, independent_probability = 0.99},
      },
      allow_as_intermediate = false,
    },
  }
  util.add_unlock("kr-matter-cobalt-processing", "kr-ff-cobalt-ore-to-matter")
  util.add_unlock("kr-matter-cobalt-processing", "kr-matter-to-ff-cobalt-ingot")
end

-- Transport science becomes a transport tech card, made from blank cards like K2's own cards
local transport = item("ff-transport-science-pack")
if transport and data.raw.item["kr-blank-tech-card"] then
  local card = "__FreightForwarding__/graphics/compatibility/krastorio2/transport-tech-card-item.png"
  transport.icon = card
  transport.icons = nil
  transport.icon_size = 64
  transport.order = "b03[transport-science-pack]"
  transport.localised_name = {"item-name.ff-k2-transport-tech-card"}
  local logistic = item("logistic-science-pack")
  if logistic and logistic.pictures then
    transport.pictures = table.deepcopy(logistic.pictures)
    local layers = transport.pictures.layers or {transport.pictures}
    if layers[1] then layers[1].filename = card end
  end
  local tech = data.raw.technology["ff-transport-science-pack"]
  if tech then
    tech.icon = "__FreightForwarding__/graphics/compatibility/krastorio2/transport-tech-card-technology.png"
    tech.icons = nil
    tech.icon_size = 256
    tech.localised_name = {"item-name.ff-k2-transport-tech-card"}
  end
  util.set_product_amount("ff-transport-science-pack", "ff-transport-science-pack", 5)
  util.set_recipe_time("ff-transport-science-pack", 20)
  util.set_ingredients("ff-transport-science-pack", {
    {type = "item", name = "big-electric-pole", amount = 1},
    {type = "item", name = "rail", amount = 5},
    {type = "item", name = "kr-blank-tech-card", amount = 5},
  })
end

-- Big electric poles from steel beams, like K2's other steel structures
if data.raw.item["kr-steel-beam"] then
  util.remove_ingredient("big-electric-pole", "steel-plate")
  util.set_ingredient("big-electric-pole", "kr-steel-beam", 2)
end

-- The singularity lab is for K2's own cards
if data.raw.lab["kr-singularity-lab"] then
  local inputs = data.raw.lab["kr-singularity-lab"].inputs
  for i = #inputs, 1, -1 do
    if inputs[i] == "ff-transport-science-pack" then table.remove(inputs, i) end
  end
end

-- Stack sizes for K2 items (FF halves them later, in prototypes/stack-sizes.lua)
local stacks = {
  ["wood"] = 50, ["kr-sand"] = 50, ["kr-imersite"] = 30, ["kr-rare-metal-ore"] = 30, ["kr-coke"] = 50,
  ["kr-glass"] = 100, ["kr-fertilizer"] = 100, ["kr-biomass"] = 100, ["kr-quartz"] = 100, ["kr-silicon"] = 100,
  ["kr-rare-metals"] = 100, ["kr-imersium-plate"] = 100, ["kr-enriched-iron"] = 100, ["kr-enriched-copper"] = 100,
  ["kr-enriched-rare-metals"] = 100, ["kr-lithium-chloride"] = 100, ["kr-lithium"] = 100, ["sulfur"] = 100,
  ["kr-lithium-sulfur-battery"] = 100, ["explosives"] = 100, ["kr-imersite-powder"] = 100, ["kr-tritium"] = 100,
  ["kr-fuel"] = 50, ["kr-biofuel"] = 50, ["kr-advanced-fuel"] = 50, ["iron-stick"] = 200, ["iron-gear-wheel"] = 200,
  ["low-density-structure"] = 50, ["rocket-fuel"] = 50, ["kr-matter-stabilizer"] = 50,
  ["kr-charged-matter-stabilizer"] = 50, ["processing-unit"] = 200, ["engine-unit"] = 200,
  ["electric-engine-unit"] = 200, ["flying-robot-frame"] = 200, ["kr-imersite-crystal"] = 200,
  ["uranium-235"] = 200, ["uranium-238"] = 200, ["kr-energy-control-unit"] = 200, ["kr-black-reinforced-plate"] = 100,
  ["kr-white-reinforced-plate"] = 100, ["kr-steel-pipe"] = 100, ["kr-blank-tech-card"] = 100,
  ["kr-biters-research-data"] = 100, ["kr-matter-research-data"] = 100, ["kr-space-research-data"] = 100,
  ["kr-basic-tech-card"] = 100, ["kr-matter-tech-card"] = 100, ["kr-advanced-tech-card"] = 100,
  ["kr-singularity-tech-card"] = 100, ["kr-explosive-turret-rocket"] = 50, ["kr-nuclear-turret-rocket"] = 50,
  ["kr-antimatter-turret-rocket"] = 50, ["artillery-shell"] = 50, ["atomic-bomb"] = 50, ["kr-antimatter-rocket"] = 50,
}
for name, size in pairs(stacks) do
  local proto = item(name)
  if proto then proto.stack_size = size end
end

-- Heavy ammo goes into containers too
for _, name in pairs{"artillery-shell", "atomic-bomb", "kr-antimatter-rocket"} do
  local proto = item(name)
  if proto then proto.ic_create_container = true end
end

-- Vehicles: K2 limits cars to vehicle fuel; boats and mini trains also take chemical fuel
local function add_fuel(energy_source, categories)
  if not energy_source then return end
  local current = energy_source.fuel_categories or {energy_source.fuel_category or "chemical"}
  energy_source.fuel_category = nil
  for _, category in pairs(categories) do
    local present = false
    for _, c in pairs(current) do if c == category then present = true end end
    if not present and data.raw["fuel-category"][category] then table.insert(current, category) end
  end
  energy_source.fuel_categories = current
end
if data.raw.car["indep-boat"] then add_fuel(data.raw.car["indep-boat"].energy_source, {"chemical", "kr-vehicle-fuel", "vehicle-fuel"}) end
if data.raw.locomotive["mini-locomotive"] then add_fuel(data.raw.locomotive["mini-locomotive"].energy_source, {"chemical", "kr-vehicle-fuel", "vehicle-fuel"}) end

-- K2's lithium-sulfur battery becomes FF's battery pack (only where FF's battery packs are the classic ones:
-- in extended mode with Space Age, battery packs are a Fulgora product, see compatibility/krastorio2/space-age.lua)
if not space_age or classic then
  local li = data.raw.item["kr-lithium-sulfur-battery"]
  if li and data.raw.item["ff-battery-pack"] then
    if data.raw.recipe["kr-lithium-sulfur-battery"] then data.raw.recipe["kr-lithium-sulfur-battery"].hidden = true end
    li.hidden = true
    li.ic_create_container = false
    for _, tech in pairs(data.raw.technology) do util.remove_recipe_effect(tech.name, "kr-lithium-sulfur-battery") end
    for _, recipe in pairs(data.raw.recipe) do
      util.replace_ingredient(recipe.name, "kr-lithium-sulfur-battery", "ff-battery-pack")
      util.replace_product(recipe.name, "kr-lithium-sulfur-battery", "ff-battery-pack")
    end
    -- 3 lithium + 3 cobalt ingots + 9 batteries + 1 red circuit = 3 battery packs (K2 uses them for science)
    util.add_ingredient("ff-battery-pack", "kr-lithium", 3)
    util.set_ingredient("ff-battery-pack", "battery", 9)
    util.set_ingredient("ff-battery-pack", "ff-cobalt-ingot", 3)
    util.set_product_amount("ff-battery-pack", "ff-battery-pack", 3)
    util.add_prerequisite("ff-battery-pack", "kr-lithium-processing")
    util.set_ingredient("kr-advanced-tech-card", "ff-battery-pack", 1)
  end
end

-- K2 resources away from the starting island
local resource_autoplace = require "__FreightForwarding__.resource-autoplace.resource-autoplace"
local empty_radius = 1500
local function set_autoplace(name, params)
  local resource = data.raw.resource[name]
  if not resource then return end
  params.name = name
  resource.autoplace = resource_autoplace.resource_autoplace_settings(params)
end
set_autoplace("kr-rare-metal-ore", {
  order = "d", base_density = 1.0, base_spots_per_km2 = 0.75, has_starting_area_placement = false,
  random_spot_size_minimum = 0.25, random_spot_size_maximum = 3, regular_blob_amplitude_multiplier = 1,
  regular_patch_fade_in_distance_start = empty_radius, regular_patch_fade_in_distance = empty_radius + 100,
  regular_rq_factor_multiplier = 0.9, candidate_spot_count = 22,
})
set_autoplace("kr-imersite", {
  order = "f", base_density = 1, richness_multiplier = 1, richness_multiplier_distance_bonus = 1.5,
  base_spots_per_km2 = 0.2, has_starting_area_placement = false, random_spot_size_minimum = 0.01,
  random_spot_size_maximum = 0.1, regular_blob_amplitude_multiplier = 1,
  regular_patch_fade_in_distance_start = empty_radius, regular_patch_fade_in_distance = empty_radius + 100,
  richness_post_multiplier = 1.0, additional_richness = 350000, regular_rq_factor_multiplier = 0.1,
  candidate_spot_count = 22,
})
set_autoplace("kr-mineral-water", {
  order = "c", base_density = 2, base_spots_per_km2 = 0.5, random_probability = 1 / 50,
  random_spot_size_minimum = 1, random_spot_size_maximum = 1, additional_richness = 50000,
  has_starting_area_placement = false, regular_rq_factor_multiplier = 1,
  regular_patch_fade_in_distance_start = empty_radius, regular_patch_fade_in_distance = empty_radius + 100,
})
