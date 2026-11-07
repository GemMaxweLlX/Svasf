-- Space Age: ship tiers, registered through Cargo Ships' ship definition API (mod-data
-- "cargo-ships.ship-definition"), so Cargo Ships places and couples them like its own ships.
--   * fast cargo ship (Vulcanus): 1.5x speed
--   * heavy cargo ship (Aquilo): 2x hold, a bit slower
-- Runs in data-updates (after FF's inventory-sizes.lua has set the cargo ship hold).

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end

local ship = data.raw["cargo-wagon"]["cargo_ship"]
local engine = data.raw["locomotive"]["cargo_ship_engine"]
local ship_item = data.raw["item-with-entity-data"]["cargo_ship"]
local engine_item = data.raw["item-with-entity-data"]["cargo_ship_engine"]
if not (ship and engine and ship_item and engine_item and data.raw.recipe["cargo_ship"]) then return end

local function power_kw(power)
  local value, unit = tostring(power):match("^([%d%.]+)(%a+)$")
  value = tonumber(value) or 0
  local scale = {W = 0.001, kW = 1, MW = 1000, GW = 1000000}
  return value * (scale[unit] or 1)
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

local function make_ship(params)
  local body = table.deepcopy(ship)
  body.name = params.name
  body.localised_name = {"entity-name." .. params.name}
  body.localised_description = {"entity-description." .. params.name}
  body.icons = tinted(ship, params.tint)
  body.icon = nil
  body.minable = {mining_time = 1, result = params.name}
  body.max_speed = ship.max_speed * params.speed
  body.inventory_size = math.floor(ship.inventory_size * params.hold)
  body.placeable_by = nil

  local motor = table.deepcopy(engine)
  motor.name = params.name .. "-engine"
  motor.localised_name = body.localised_name
  motor.max_speed = engine.max_speed * params.speed
  motor.max_power = (power_kw(engine.max_power) * params.power) .. "kW"
  motor.placeable_by = nil

  local item = table.deepcopy(ship_item)
  item.name = params.name
  item.localised_name = body.localised_name
  item.localised_description = body.localised_description
  item.icons = tinted(ship_item, params.tint)
  item.icon = nil
  item.place_result = params.name
  item.order = (ship_item.order or "") .. params.order

  local motor_item = table.deepcopy(engine_item)
  motor_item.name = params.name .. "-engine"
  motor_item.place_result = params.name .. "-engine"
  motor_item.hidden = true

  data:extend{
    body, motor, item, motor_item,
    {
      type = "mod-data",
      name = params.name,
      data_type = "cargo-ships.ship-definition",
      data = {
        name = params.name,
        engine = params.name .. "-engine",
        engine_scale = 1,
        engine_at_front = false,
      },
    },
    {
      type = "recipe",
      name = params.name,
      enabled = false,
      energy_required = 20,
      ingredients = params.ingredients,
      results = {{type = "item", name = params.name, amount = 1}},
    },
    {
      type = "technology",
      name = params.name,
      localised_name = {"technology-name." .. params.name},
      localised_description = {"technology-description." .. params.name},
      icons = tinted(data.raw.technology["cargo_ships"] or ship_item, params.tint),
      effects = {{type = "unlock-recipe", recipe = params.name}},
      prerequisites = params.prerequisites,
      unit = params.unit,
    },
  }
end

if data.raw.technology["metallurgic-science-pack"] and data.raw.item["tungsten-carbide"] then
  make_ship{
    name = "ff-fast-cargo-ship",
    order = "-a",
    tint = {r = 1, g = 0.75, b = 0.6, a = 1},
    speed = 1.5,
    power = 1.6,
    hold = 1,
    ingredients = {
      {type = "item", name = "cargo_ship", amount = 1},
      {type = "item", name = "tungsten-carbide", amount = 40},
      {type = "item", name = "electric-engine-unit", amount = 40},
    },
    prerequisites = {"cargo_ships", "metallurgic-science-pack"},
    unit = {
      count = 500,
      ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
        "space-science-pack", "metallurgic-science-pack"),
      time = 60,
    },
  }
end

if data.raw.technology["cryogenic-science-pack"] and data.raw.item["lithium-plate"] then
  make_ship{
    name = "ff-heavy-cargo-ship",
    order = "-b",
    tint = {r = 0.7, g = 0.8, b = 1, a = 1},
    speed = 0.85,
    power = 1.5,
    hold = 2,
    ingredients = {
      {type = "item", name = "cargo_ship", amount = 1},
      {type = "item", name = "lithium-plate", amount = 100},
      {type = "item", name = "ff-titansteel-plate", amount = 20},
    },
    prerequisites = {"cargo_ships", "cryogenic-science-pack"},
    unit = {
      count = 800,
      ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
        "space-science-pack", "cryogenic-science-pack"),
      time = 60,
    },
  }
end
