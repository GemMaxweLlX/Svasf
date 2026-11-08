-- Space Age: train tiers. Runs in data-updates, after FF's trains.lua (battery-powered locomotives) and
-- inventory-sizes.lua (smaller wagons).
--   locomotive Mk2 (Fulgora), locomotive Mk3 (Aquilo), cargo wagon Mk2 and fluid wagon Mk2 (Vulcanus, 1.5x by default)

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end

local VULCANUS = {{property = "pressure", min = 4000, max = 4000}}
local FULGORA = {{property = "magnetic-field", min = 99, max = 99}}
local AQUILO = {{property = "pressure", min = 300, max = 300}}
local WAGON_CAPACITY = settings.startup["ff-wagon-mk2-capacity"].value

local function power_kw(power)
  local value, unit = tostring(power):match("^([%d%.]+)(%a+)$")
  local scale = {W = 0.001, kW = 1, MW = 1000, GW = 1000000}
  return (tonumber(value) or 0) * (scale[unit] or 1)
end

local function tinted(prototype, tint)
  local icons = table.deepcopy(prototype.icons or {{icon = prototype.icon, icon_size = prototype.icon_size}})
  for _, icon in pairs(icons) do icon.tint = tint end
  return icons
end

local function science(...)
  local ingredients = {}
  for _, name in pairs{...} do ingredients[#ingredients + 1] = {name, 1} end
  return ingredients
end

local function find_item(name)
  return data.raw["item-with-entity-data"][name] or data.raw.item[name]
end

--- Copies a rolling stock prototype into a new tier with its item, recipe and technology.
local function make_tier(params)
  local base = data.raw[params.type][params.base]
  local base_item = find_item(params.base)
  if not (base and base_item) then return end
  for _, ingredient in pairs(params.ingredients) do
    if not (data.raw.item[ingredient.name] or data.raw["item-with-entity-data"][ingredient.name]) then return end
  end

  local entity = table.deepcopy(base)
  entity.name = params.name
  entity.localised_name = {"entity-name." .. params.name}
  entity.localised_description = {"entity-description." .. params.name}
  entity.icons = tinted(base, params.tint)
  entity.icon = nil
  entity.minable = {mining_time = base.minable and base.minable.mining_time or 0.5, result = params.name}
  entity.placeable_by = nil
  entity.next_upgrade = nil
  params.modify(entity, base)

  local item = table.deepcopy(base_item)
  item.name = params.name
  item.localised_name = entity.localised_name
  item.localised_description = entity.localised_description
  item.icons = tinted(base_item, params.tint)
  item.icon = nil
  item.place_result = params.name
  item.order = (base_item.order or "") .. "-" .. params.name

  local effects = {{type = "unlock-recipe", recipe = params.name}}
  data:extend{
    entity, item,
    {
      type = "recipe",
      name = params.name,
      enabled = false,
      energy_required = 10,
      ingredients = params.ingredients,
      results = {{type = "item", name = params.name, amount = 1}},
      surface_conditions = params.surface_conditions,
    },
  }

  local technology = data.raw.technology[params.technology]
  if technology then
    table.insert(technology.effects, effects[1])
  else
    data:extend{{
      type = "technology",
      name = params.technology,
      localised_name = {"technology-name." .. params.technology},
      localised_description = {"technology-description." .. params.technology},
      icons = tinted(data.raw.technology["railway"], params.tint),
      effects = effects,
      prerequisites = params.prerequisites,
      unit = params.unit,
    }}
  end
end

---------------------------------------------------------------------------------------------------
-- Vulcanus: tungsten wagons with double capacity

if data.raw.technology["metallurgic-science-pack"] then
  local wagon_unit = {
    count = 400,
    ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
      "space-science-pack", "metallurgic-science-pack"),
    time = 30,
  }
  make_tier{
    type = "cargo-wagon", base = "cargo-wagon", name = "ff-cargo-wagon-mk2",
    tint = {r = 1, g = 0.8, b = 0.6, a = 1},
    modify = function(entity, base) entity.inventory_size = math.floor(base.inventory_size * WAGON_CAPACITY) end,
    ingredients = {
      {type = "item", name = "cargo-wagon", amount = 1},
      {type = "item", name = "tungsten-plate", amount = 20},
    },
    surface_conditions = VULCANUS,
    technology = "ff-rolling-stock-mk2",
    prerequisites = {"railway", "metallurgic-science-pack"},
    unit = wagon_unit,
  }
  make_tier{
    type = "fluid-wagon", base = "fluid-wagon", name = "ff-fluid-wagon-mk2",
    tint = {r = 1, g = 0.8, b = 0.6, a = 1},
    modify = function(entity, base) entity.capacity = math.floor((base.capacity or 50000) * WAGON_CAPACITY) end,
    ingredients = {
      {type = "item", name = "fluid-wagon", amount = 1},
      {type = "item", name = "tungsten-plate", amount = 20},
    },
    surface_conditions = VULCANUS,
    technology = "ff-rolling-stock-mk2",
    prerequisites = {"fluid-wagon", "metallurgic-science-pack"},
    unit = wagon_unit,
  }
end

---------------------------------------------------------------------------------------------------
-- Fulgora / Aquilo: locomotives

if data.raw.technology["electromagnetic-science-pack"] then
  make_tier{
    type = "locomotive", base = "locomotive", name = "ff-locomotive-mk2",
    tint = {r = 0.75, g = 0.6, b = 1, a = 1},
    modify = function(entity, base)
      entity.max_speed = base.max_speed * 1.25
      entity.max_power = (power_kw(base.max_power) * 1.6) .. "kW"
      entity.color = {r = 0.55, g = 0.35, b = 0.9, a = 0.5}
    end,
    ingredients = {
      {type = "item", name = "locomotive", amount = 1},
      {type = "item", name = "superconductor", amount = 20},
      {type = "item", name = "holmium-plate", amount = 20},
    },
    surface_conditions = FULGORA,
    technology = "ff-locomotive-mk2",
    prerequisites = {"railway", "electromagnetic-science-pack"},
    unit = {
      count = 500,
      ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
        "space-science-pack", "electromagnetic-science-pack"),
      time = 30,
    },
  }
end

if data.raw.technology["cryogenic-science-pack"] and data.raw.locomotive["ff-locomotive-mk2"] then
  make_tier{
    type = "locomotive", base = "ff-locomotive-mk2", name = "ff-locomotive-mk3",
    tint = {r = 0.6, g = 1, b = 0.85, a = 1},
    modify = function(entity)
      local locomotive = data.raw.locomotive["locomotive"]
      entity.max_speed = locomotive.max_speed * 1.5
      entity.max_power = (power_kw(locomotive.max_power) * 2.2) .. "kW"
      entity.color = {r = 0.3, g = 0.85, b = 0.65, a = 0.5}
    end,
    ingredients = {
      {type = "item", name = "ff-locomotive-mk2", amount = 1},
      {type = "item", name = "lithium-plate", amount = 30},
      {type = "item", name = "quantum-processor", amount = 5},
    },
    surface_conditions = AQUILO,
    technology = "ff-locomotive-mk3",
    prerequisites = {"ff-locomotive-mk2", "cryogenic-science-pack"},
    unit = {
      count = 800,
      ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
        "space-science-pack", "electromagnetic-science-pack", "cryogenic-science-pack"),
      time = 30,
    },
  }
end
