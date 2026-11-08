-- Improved machines and quality-of-life additions. Runs in data-updates.
--   * fuel depot (all games): trains and ships stopped next to it refuel and drop off burnt fuel
--   * dredger can be mined and moved (all games, see scripts/dredging-platform.lua)
--   Space Age only:
--   * containerization machine tier 4 (Fulgora)
--   * dredging productivity (Vulcanus)
--   * fast charging station (Fulgora)
--   * seismic scanner Mk2 and sonar buoy Mk2 (Aquilo)

local util = require("__FreightForwarding__.prototypes.data-util")

local space_age = mods["space-age"] ~= nil and not settings.startup["ff-classic-mode"].value
local FULGORA = {{property = "magnetic-field", min = 99, max = 99}}
local AQUILO = {{property = "pressure", min = 300, max = 300}}

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

---------------------------------------------------------------------------------------------------
-- Fuel depot

local chest = data.raw.container["steel-chest"]
local depot_tint = {r = 1, g = 0.8, b = 0.4, a = 1}
local depot = table.deepcopy(chest)
depot.name = "ff-fuel-depot"
depot.localised_name = {"entity-name.ff-fuel-depot"}
depot.localised_description = {"entity-description.ff-fuel-depot"}
depot.icons = tinted(chest, depot_tint)
depot.icon = nil
depot.minable = {mining_time = 0.2, result = "ff-fuel-depot"}
depot.next_upgrade = nil
depot.fast_replaceable_group = nil
if depot.picture and depot.picture.layers and depot.picture.layers[1] then
  depot.picture.layers[1].tint = depot_tint
end

local depot_item = table.deepcopy(data.raw.item["steel-chest"])
depot_item.name = "ff-fuel-depot"
depot_item.localised_name = {"entity-name.ff-fuel-depot"}
depot_item.localised_description = {"entity-description.ff-fuel-depot"}
depot_item.icons = tinted(data.raw.item["steel-chest"], depot_tint)
depot_item.icon = nil
depot_item.place_result = "ff-fuel-depot"
depot_item.order = (depot_item.order or "") .. "-ff"

data:extend{
  depot,
  depot_item,
  {
    type = "recipe",
    name = "ff-fuel-depot",
    enabled = false,
    energy_required = 1,
    ingredients = {
      {type = "item", name = "steel-chest", amount = 1},
      {type = "item", name = "electronic-circuit", amount = 5},
      {type = "item", name = "fast-inserter", amount = 2},
    },
    results = {{type = "item", name = "ff-fuel-depot", amount = 1}},
  },
}
util.add_unlock("ff-battery-charging", "ff-fuel-depot")

---------------------------------------------------------------------------------------------------
-- Dredger can be mined (and rebuilt elsewhere); the script restores the seamount and water

local dredger = data.raw["assembling-machine"]["ff-dredger"]
if dredger then
  dredger.minable = {mining_time = 2, result = "ff-dredging-platform"}
  local flags = {}
  for _, flag in pairs(dredger.flags or {}) do
    if flag ~= "not-deconstructable" then flags[#flags + 1] = flag end
  end
  dredger.flags = flags
  dredger.placeable_by = {item = "ff-dredging-platform", count = 1}
end

if not space_age then return end

---------------------------------------------------------------------------------------------------
-- Containerization machine tier 4 (Fulgora)

if intermodal_containers and intermodal_containers.add_tier and data.raw["assembling-machine"]["ic-containerization-machine-3"]
    and data.raw.item["superconductor"] then
  intermodal_containers.add_tier{
    tier = 4,
    colour = {r = 170, g = 90, b = 220},
    speed = 4,
    energy = "1MW",
    drain = "20kW",
    health = 450,
    ingredients = {
      {type = "item", name = "ic-containerization-machine-3", amount = 1},
      {type = "item", name = "superconductor", amount = 20},
      {type = "item", name = "holmium-plate", amount = 20},
      {type = "item", name = "processing-unit", amount = 10},
    },
    prerequisites = {"ic-containerization-3", "electromagnetic-science-pack"},
    unit = {
      count = 500,
      ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
        "space-science-pack", "electromagnetic-science-pack"),
      time = 30,
    },
  }
  data.raw["assembling-machine"]["ic-containerization-machine-3"].next_upgrade = "ic-containerization-machine-4"
  local machine4 = data.raw["assembling-machine"]["ic-containerization-machine-4"]
  if machine4 then machine4.module_slots = math.max(machine4.module_slots or 0, 4) end
  if data.raw.recipe["ic-containerization-machine-4"] then
    data.raw.recipe["ic-containerization-machine-4"].surface_conditions = FULGORA
  end
end

---------------------------------------------------------------------------------------------------
-- Dredging productivity (Vulcanus)

if data.raw.technology["metallurgic-science-pack"] then
  local dredging_recipes = {"ff-ferrous-nodule", "ff-cupric-nodule", "ff-cobalt-crust"}
  local dredging_tech = data.raw.technology["ff-dredging"]
  for level = 1, 3 do
    local effects = {}
    for _, recipe in pairs(dredging_recipes) do
      if data.raw.recipe[recipe] then
        effects[#effects + 1] = {type = "change-recipe-productivity", recipe = recipe, change = 0.2}
      end
    end
    local prerequisites = level == 1 and {"ff-dredging", "metallurgic-science-pack"} or {"ff-dredging-productivity-" .. (level - 1)}
    data:extend{
      {
        type = "technology",
        name = "ff-dredging-productivity-" .. level,
        localised_name = {"technology-name.ff-dredging-productivity"},
        localised_description = {"technology-description.ff-dredging-productivity"},
        icons = dredging_tech and (dredging_tech.icons or {{icon = dredging_tech.icon, icon_size = dredging_tech.icon_size}}),
        effects = effects,
        prerequisites = prerequisites,
        upgrade = true,
        unit = {
          count = 300 * level,
          ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
            "space-science-pack", "metallurgic-science-pack"),
          time = 60,
        },
      },
    }
  end
end

---------------------------------------------------------------------------------------------------
-- Fast charging station (Fulgora)

local station = data.raw.furnace["ff-charging-station"]
if station and data.raw.item["superconductor"] and data.raw.technology["electromagnetic-science-pack"] then
  local fast_tint = {r = 0.75, g = 0.6, b = 1, a = 1}
  local fast = table.deepcopy(station)
  fast.name = "ff-fast-charging-station"
  fast.localised_name = {"entity-name.ff-fast-charging-station"}
  fast.localised_description = {"entity-description.ff-fast-charging-station"}
  fast.icons = tinted(station, fast_tint)
  fast.icon = nil
  fast.icon_size = nil
  fast.crafting_speed = 3
  fast.energy_usage = "2400kW"
  fast.energy_source = table.deepcopy(station.energy_source)
  fast.energy_source.buffer_capacity = "60MJ"
  fast.energy_source.input_flow_limit = "30MW"
  fast.minable = {mining_time = 0.1, result = "ff-fast-charging-station"}
  station.next_upgrade = "ff-fast-charging-station"

  local fast_item = table.deepcopy(data.raw.item["ff-charging-station"])
  fast_item.name = "ff-fast-charging-station"
  fast_item.localised_name = {"entity-name.ff-fast-charging-station"}
  fast_item.icons = fast.icons
  fast_item.icon = nil
  fast_item.icon_size = nil
  fast_item.place_result = "ff-fast-charging-station"
  fast_item.order = (fast_item.order or "") .. "-b"

  data:extend{
    fast,
    fast_item,
    {
      type = "recipe",
      name = "ff-fast-charging-station",
      enabled = false,
      energy_required = 10,
      ingredients = {
        {type = "item", name = "ff-charging-station", amount = 1},
        {type = "item", name = "superconductor", amount = 10},
        {type = "item", name = "supercapacitor", amount = 5},
      },
      results = {{type = "item", name = "ff-fast-charging-station", amount = 1}},
      surface_conditions = FULGORA,
    },
    {
      type = "technology",
      name = "ff-fast-charging",
      localised_name = {"technology-name.ff-fast-charging"},
      localised_description = {"technology-description.ff-fast-charging"},
      icons = data.raw.technology["ff-battery-charging"] and tinted(data.raw.technology["ff-battery-charging"], fast_tint),
      effects = {{type = "unlock-recipe", recipe = "ff-fast-charging-station"}},
      prerequisites = {"ff-battery-charging", "electromagnetic-science-pack"},
      unit = {
        count = 300,
        ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
          "space-science-pack", "electromagnetic-science-pack"),
        time = 30,
      },
    },
  }
end

---------------------------------------------------------------------------------------------------
-- Seismic scanner Mk2 and sonar buoy Mk2 (Aquilo): twice the range (scripts read it from the name)

if data.raw.technology["cryogenic-science-pack"] and data.raw.item["lithium-plate"] then
  local mk2_tint = {r = 0.7, g = 1, b = 0.85, a = 1}
  local unlocks = {}
  local prerequisites = {"cryogenic-science-pack"}
  for _, name in pairs{"ff-seismic-scanner", "ff-sonar-buoy"} do
    local radar = data.raw.radar[name]
    if radar then
      local mk2 = table.deepcopy(radar)
      mk2.name = name .. "-2"
      mk2.localised_name = {"entity-name.ff-mk2", {"entity-name." .. name}}
      mk2.localised_description = {"entity-description." .. name}
      mk2.icons = tinted(radar, mk2_tint)
      mk2.icon = nil
      mk2.minable = {mining_time = 0.1, result = name .. "-2"}
      mk2.energy_per_sector = "500kJ"
      radar.fast_replaceable_group = radar.fast_replaceable_group or name
      mk2.fast_replaceable_group = radar.fast_replaceable_group
      radar.next_upgrade = name .. "-2"

      local item = table.deepcopy(data.raw.item[name])
      item.name = name .. "-2"
      item.localised_name = mk2.localised_name
      item.icons = tinted(data.raw.item[name], mk2_tint)
      item.icon = nil
      item.place_result = name .. "-2"
      item.order = (item.order or "") .. "-2"

      data:extend{
        mk2,
        item,
        {
          type = "recipe",
          name = name .. "-2",
          enabled = false,
          energy_required = 10,
          ingredients = {
            {type = "item", name = name, amount = 1},
            {type = "item", name = "lithium-plate", amount = 10},
            {type = "item", name = "quantum-processor", amount = 2},
          },
          results = {{type = "item", name = name .. "-2", amount = 1}},
          surface_conditions = AQUILO,
        },
      }
      unlocks[#unlocks + 1] = {type = "unlock-recipe", recipe = name .. "-2"}
      if data.raw.technology[name] then prerequisites[#prerequisites + 1] = name end
    end
  end
  if #unlocks > 0 then
    data:extend{
      {
        type = "technology",
        name = "ff-scanners-mk2",
        localised_name = {"technology-name.ff-scanners-mk2"},
        localised_description = {"technology-description.ff-scanners-mk2"},
        icons = tinted(data.raw.technology["ff-seismic-scanner"] or data.raw.technology["ff-sonar-buoy"], mk2_tint),
        effects = unlocks,
        prerequisites = prerequisites,
        unit = {
          count = 500,
          ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
            "space-science-pack", "cryogenic-science-pack"),
          time = 30,
        },
      },
    }
  end
end

---------------------------------------------------------------------------------------------------
-- Space Age (all modes): FF buildings belong on planets, not on space platforms.
-- The underwater pipe lies in the ocean, which doesn't freeze: no heating needed on Aquilo.

if mods["space-age"] then
  local PLANET = {{property = "gravity", min = 0.1}}
  local buildings = {
    ["mining-drill"] = {"ff-dredging-platform"},
    ["assembling-machine"] = {"ff-dredger", "ff-lava-pool", "ff-lava-pool-small"},
    ["furnace"] = {"ff-lava-pool", "ff-lava-pool-small"},
    ["radar"] = {"ff-seismic-scanner", "ff-seismic-scanner-2", "ff-sonar-buoy", "ff-sonar-buoy-2"},
    ["pipe"] = {"ff-underwater-pipe"},
    ["storage-tank"] = {"ff-offshore-storage-tank"},
  }
  for type, names in pairs(buildings) do
    for _, name in pairs(names) do
      local prototype = data.raw[type] and data.raw[type][name]
      if prototype and not prototype.surface_conditions then prototype.surface_conditions = PLANET end
    end
  end
  local underwater_pipe = data.raw.pipe["ff-underwater-pipe"]
  if underwater_pipe then underwater_pipe.heating_energy = nil end
end
