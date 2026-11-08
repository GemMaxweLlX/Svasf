-- Sea infrastructure (all games except classic mode). Runs in data-updates.
--   * port crane: a big bulk inserter with long reach for loading ships from the quay (and back)
--   * cable terminal: a pole on the shore whose wires reach far across the sea, but only to other terminals
--   * cable landing + subsea cable: a cable laid along the seabed between two landings, any distance (takes time)
--   * offshore wind turbine: power on water; output follows the wind (scripts/sea-power.lua)
--   * tidal generator: power on shallow water; output follows the tide (scripts/sea-power.lua)
-- Collision masks of the turbine and the tidal generator are set in data-final-fixes (like the offshore tank).

if settings.startup["ff-classic-mode"].value then return end

local util = require("__FreightForwarding__.prototypes.data-util")
local NAUVIS = mods["space-age"] and {{property = "pressure", min = 1000, max = 1000}} or nil
local PLANET = mods["space-age"] and {{property = "gravity", min = 0.1}} or nil

local function tinted(prototype, tint)
  local icons = table.deepcopy(prototype.icons or {{icon = prototype.icon, icon_size = prototype.icon_size or 64}})
  for _, icon in pairs(icons) do icon.tint = tint end
  return icons
end

local function tint_sprites(t, tint)
  if type(t) ~= "table" then return end
  if (t.filename or t.filenames or t.stripes) and not t.draw_as_shadow and not t.draw_as_light then t.tint = tint end
  for _, v in pairs(t) do tint_sprites(v, tint) end
end

local function scale_sprites(t, k)
  if type(t) ~= "table" then return end
  if t.filename or t.filenames or t.stripes then
    t.scale = (t.scale or 1) * k
    if t.shift then t.shift = {(t.shift[1] or t.shift.x) * k, (t.shift[2] or t.shift.y) * k} end
  end
  for _, v in pairs(t) do scale_sprites(v, k) end
end

local function item_for(name, base_item, tint, order)
  local item = table.deepcopy(base_item)
  item.name = name
  item.localised_name = {"entity-name." .. name}
  item.localised_description = {"entity-description." .. name}
  item.icons = tinted(base_item, tint)
  item.icon = nil
  item.place_result = name
  item.order = (base_item.order or "") .. order
  return item
end

local function recipe(name, ingredients)
  for _, ingredient in pairs(ingredients) do
    if not data.raw.item[ingredient.name] then return nil end
  end
  return {type = "recipe", name = name, enabled = false, energy_required = 10, ingredients = ingredients,
          results = {{type = "item", name = name, amount = 1}}}
end

local effects = {}
local function add(proto_list, unlock)
  data:extend(proto_list)
  if unlock then effects[#effects + 1] = {type = "unlock-recipe", recipe = unlock} end
end

---------------------------------------------------------------------------------------------------
-- Port crane

local long = data.raw.inserter["long-handed-inserter"]
local bulk = data.raw.inserter["bulk-inserter"]
if long and bulk and data.raw.item["long-handed-inserter"] then
  local tint = {r = 1, g = 0.7, b = 0.25, a = 1}
  local crane = table.deepcopy(long)
  crane.name = "ff-port-crane"
  crane.localised_name = {"entity-name.ff-port-crane"}
  crane.localised_description = {"entity-description.ff-port-crane"}
  crane.icons = tinted(long, tint)
  crane.icon = nil
  crane.minable = {mining_time = 0.5, result = "ff-port-crane"}
  crane.pickup_position = {0, -3.2}
  crane.insert_position = {0, 3.2}
  crane.bulk = true
  crane.stack_size_bonus = 6
  crane.rotation_speed = bulk.rotation_speed * 1.25
  crane.extension_speed = bulk.extension_speed * 1.5
  crane.energy_per_movement = "40kJ"
  crane.energy_per_rotation = "40kJ"
  crane.energy_source = table.deepcopy(bulk.energy_source)
  crane.next_upgrade = nil
  crane.fast_replaceable_group = nil
  crane.surface_conditions = PLANET
  for _, key in pairs{"hand_base_picture", "hand_closed_picture", "hand_open_picture", "platform_picture"} do
    tint_sprites(crane[key], tint)
  end
  local r = recipe("ff-port-crane", {
    {type = "item", name = "bulk-inserter", amount = 1},
    {type = "item", name = "steel-plate", amount = 20},
    {type = "item", name = "electric-engine-unit", amount = 4},
  })
  if r then add({crane, item_for("ff-port-crane", data.raw.item["long-handed-inserter"], tint, "-ff"), r}, "ff-port-crane") end
end

---------------------------------------------------------------------------------------------------
-- Cable terminal

local big_pole = data.raw["electric-pole"]["big-electric-pole"]
if big_pole and data.raw.item["big-electric-pole"] then
  local tint = {r = 0.45, g = 0.6, b = 1, a = 1}
  local terminal = table.deepcopy(big_pole)
  terminal.name = "ff-cable-terminal"
  terminal.localised_name = {"entity-name.ff-cable-terminal"}
  terminal.localised_description = {"entity-description.ff-cable-terminal"}
  terminal.icons = tinted(big_pole, tint)
  terminal.icon = nil
  terminal.minable = {mining_time = 0.5, result = "ff-cable-terminal"}
  terminal.maximum_wire_distance = 64  -- a wire only spans the shorter reach of the two poles: long only between terminals
  terminal.supply_area_distance = 1
  terminal.next_upgrade = nil
  terminal.fast_replaceable_group = nil
  terminal.surface_conditions = PLANET
  tint_sprites(terminal.pictures, tint)
  local r = recipe("ff-cable-terminal", {
    {type = "item", name = "big-electric-pole", amount = 1},
    {type = "item", name = "copper-cable", amount = 200},
    {type = "item", name = "lead-plate", amount = 50},
    {type = "item", name = "plastic-bar", amount = 20},
  })
  if r then add({terminal, item_for("ff-cable-terminal", data.raw.item["big-electric-pole"], tint, "-ff"), r}, "ff-cable-terminal") end
end

---------------------------------------------------------------------------------------------------
-- Subsea cable: cable landings on two shores, connected by a cable laid along the seabed (scripts/subsea-cable.lua).
-- The cable is an item, one per tile of distance; laying takes time. Then it is a normal copper wire.

local medium_pole = data.raw["electric-pole"]["medium-electric-pole"]
if medium_pole and data.raw.item["medium-electric-pole"] then
  local tint = {r = 0.35, g = 0.85, b = 0.75, a = 1}
  local landing = table.deepcopy(medium_pole)
  landing.name = "ff-cable-landing"
  landing.localised_name = {"entity-name.ff-cable-landing"}
  landing.localised_description = {"entity-description.ff-cable-landing"}
  landing.icons = tinted(medium_pole, tint)
  landing.icon = nil
  landing.minable = {mining_time = 0.5, result = "ff-cable-landing"}
  landing.maximum_wire_distance = 9
  landing.supply_area_distance = 2
  landing.next_upgrade = nil
  landing.fast_replaceable_group = nil
  landing.surface_conditions = PLANET
  tint_sprites(landing.pictures, tint)
  local cable_icon = data.raw.item["copper-cable"]
  local landing_recipe = recipe("ff-cable-landing", {
    {type = "item", name = "medium-electric-pole", amount = 2},
    {type = "item", name = "steel-plate", amount = 10},
    {type = "item", name = "concrete", amount = 20},
  })
  if landing_recipe and cable_icon and data.raw.item["lead-plate"] and data.raw.item["plastic-bar"] then
    add({landing, item_for("ff-cable-landing", data.raw.item["medium-electric-pole"], tint, "-ff-b"), landing_recipe}, "ff-cable-landing")
    add({
      {
        type = "item",
        name = "ff-subsea-cable",
        icons = tinted(cable_icon, {r = 0.5, g = 0.6, b = 0.7, a = 1}),
        subgroup = cable_icon.subgroup,
        order = (cable_icon.order or "") .. "-ff",
        stack_size = 200,
        weight = 5000,
      },
      {
        type = "recipe",
        name = "ff-subsea-cable",
        enabled = false,
        energy_required = 1,
        ingredients = {
          {type = "item", name = "copper-cable", amount = 4},
          {type = "item", name = "lead-plate", amount = 1},
          {type = "item", name = "plastic-bar", amount = 1},
        },
        results = {{type = "item", name = "ff-subsea-cable", amount = 2}},
      },
    }, "ff-subsea-cable")
  end
end

---------------------------------------------------------------------------------------------------
-- Offshore wind turbine and tidal generator (electric energy interfaces driven by script)

local solar = data.raw["solar-panel"]["solar-panel"]
local pump = data.raw.pump["pump"]
local function generator(name, size, power, picture, animation, tint, base_item, ingredients, conditions)
  local half = size / 2
  local entity = {
    type = "electric-energy-interface",
    name = name,
    localised_name = {"entity-name." .. name},
    localised_description = {"entity-description." .. name},
    icons = tinted(base_item, tint),
    flags = {"placeable-neutral", "player-creation"},
    minable = {mining_time = 1, result = name},
    max_health = 300,
    corpse = "medium-remnants",
    collision_box = {{-half + 0.1, -half + 0.1}, {half - 0.1, half - 0.1}},
    selection_box = {{-half, -half}, {half, half}},
    energy_source = {
      type = "electric",
      usage_priority = "primary-output",
      buffer_capacity = power,  -- one second of full output, see scripts/sea-power.lua
      output_flow_limit = power,
      input_flow_limit = "0W",
      render_no_power_icon = false,
    },
    energy_production = "0W",
    picture = picture,
    animation = animation,
    surface_conditions = conditions,
    gui_mode = "none",
  }
  local r = recipe(name, ingredients)
  if r then add({entity, item_for(name, base_item, tint, "-ff"), r}, name) end
end

if solar and data.raw.item["solar-panel"] then
  local picture = table.deepcopy(solar.picture)
  scale_sprites(picture, 1)
  tint_sprites(picture, {r = 0.7, g = 0.85, b = 1, a = 1})
  generator("ff-offshore-wind-turbine", 3, "1MW", picture, nil, {r = 0.7, g = 0.85, b = 1, a = 1},
    data.raw.item["solar-panel"], {
      {type = "item", name = "steel-plate", amount = 30},
      {type = "item", name = "iron-gear-wheel", amount = 40},
      {type = "item", name = "copper-cable", amount = 40},
      {type = "item", name = "concrete", amount = 50},
    }, PLANET)
end

if pump and pump.animations and pump.animations.north and data.raw.item["pump"] then
  local animation = table.deepcopy(pump.animations.north)
  scale_sprites(animation, 1.4)
  tint_sprites(animation, {r = 0.5, g = 0.9, b = 0.8, a = 1})
  generator("ff-tidal-generator", 2, "600kW", nil, animation, {r = 0.5, g = 0.9, b = 0.8, a = 1},
    data.raw.item["pump"], {
      {type = "item", name = "pump", amount = 2},
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "electric-engine-unit", amount = 5},
      {type = "item", name = "concrete", amount = 30},
    }, NAUVIS)
end

---------------------------------------------------------------------------------------------------

if #effects > 0 then
  local cargo_tech = data.raw.technology["cargo_ships"] and "cargo_ships" or nil
  local prerequisites = {"electric-energy-distribution-2", "bulk-inserter"}
  if cargo_tech then table.insert(prerequisites, cargo_tech) end
  for i = #prerequisites, 1, -1 do
    if not data.raw.technology[prerequisites[i]] then table.remove(prerequisites, i) end
  end
  data:extend{{
    type = "technology",
    name = "ff-sea-infrastructure",
    localised_name = {"technology-name.ff-sea-infrastructure"},
    localised_description = {"technology-description.ff-sea-infrastructure"},
    icons = table.deepcopy(data.raw.technology["cargo_ships"] and (data.raw.technology["cargo_ships"].icons
      or {{icon = data.raw.technology["cargo_ships"].icon, icon_size = data.raw.technology["cargo_ships"].icon_size or 256}})
      or {{icon = "__base__/graphics/technology/electric-energy-distribution-2.png", icon_size = 256}}),
    effects = effects,
    prerequisites = prerequisites,
    unit = {
      count = 300,
      ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}},
      time = 30,
    },
  }}
end
