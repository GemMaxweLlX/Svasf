-- Logistics quality of life. Runs in data-updates.
--   * spoilage sensor (Space Age): a combinator next to a train stop that outputs how spoiled the stopped train's
--     cargo is, for wait conditions (scripts/spoilage-sensor.lua)
--   * packing / unpacking depots (Intermodal Containers): logistic chests that pack loose items into containers,
--     or unpack containers, by themselves (scripts/container-depots.lua)

local util = require("__FreightForwarding__.prototypes.data-util")

local function tinted(prototype, tint)
  local icons = table.deepcopy(prototype.icons or {{icon = prototype.icon, icon_size = prototype.icon_size}})
  for _, icon in pairs(icons) do icon.tint = tint end
  return icons
end

local function copy_entity(type, base_name, name, tint, changes)
  local base = data.raw[type][base_name]
  local base_item = data.raw.item[base_name]
  if not (base and base_item) then return false end
  local entity = table.deepcopy(base)
  entity.name = name
  entity.localised_name = {"entity-name." .. name}
  entity.localised_description = {"entity-description." .. name}
  entity.icons = tinted(base, tint)
  entity.icon = nil
  entity.minable = {mining_time = base.minable and base.minable.mining_time or 0.1, result = name}
  entity.next_upgrade = nil
  entity.fast_replaceable_group = nil
  if changes then changes(entity) end
  local item = table.deepcopy(base_item)
  item.name = name
  item.localised_name = entity.localised_name
  item.localised_description = entity.localised_description
  item.icons = tinted(base_item, tint)
  item.icon = nil
  item.place_result = name
  item.order = (base_item.order or "") .. "-ff"
  data:extend{entity, item}
  return true
end

---------------------------------------------------------------------------------------------------
-- Spoilage sensor (Space Age)

if mods["space-age"] then
  local spoil_icon = data.raw.item["spoilage"] and data.raw.item["spoilage"].icon
  data:extend{
    {
      type = "virtual-signal",
      name = "ff-spoilage-max",
      localised_name = {"virtual-signal-name.ff-spoilage-max"},
      icons = {{icon = spoil_icon, icon_size = 64}, {icon = "__base__/graphics/icons/signal/signal_M.png", icon_size = 64, scale = 0.25, shift = {8, 8}}},
      subgroup = "virtual-signal",
      order = "z[ff]-a",
    },
    {
      type = "virtual-signal",
      name = "ff-spoilage-average",
      localised_name = {"virtual-signal-name.ff-spoilage-average"},
      icons = {{icon = spoil_icon, icon_size = 64}, {icon = "__base__/graphics/icons/signal/signal_A.png", icon_size = 64, scale = 0.25, shift = {8, 8}}},
      subgroup = "virtual-signal",
      order = "z[ff]-b",
    },
  }
  if copy_entity("constant-combinator", "constant-combinator", "ff-spoilage-sensor", {r = 0.6, g = 1, b = 0.5, a = 1}) then
    data:extend{{
      type = "recipe",
      name = "ff-spoilage-sensor",
      enabled = false,
      energy_required = 1,
      ingredients = {
        {type = "item", name = "constant-combinator", amount = 1},
        {type = "item", name = "electronic-circuit", amount = 5},
      },
      results = {{type = "item", name = "ff-spoilage-sensor", amount = 1}},
    }}
    local tech = data.raw.technology["ff-refrigerated-containers"] and "ff-refrigerated-containers" or "agricultural-science-pack"
    util.add_unlock(tech, "ff-spoilage-sensor")
  end
end

---------------------------------------------------------------------------------------------------
-- Packing and unpacking depots (Intermodal Containers)

if data.raw.item["ic-container"] and data.raw["logistic-container"]["storage-chest"] then
  local packing_ok = copy_entity("logistic-container", "storage-chest", "ff-packing-depot", {r = 1, g = 0.75, b = 0.4, a = 1})
  local unpacking_ok = copy_entity("logistic-container", "passive-provider-chest", "ff-unpacking-depot", {r = 0.6, g = 0.8, b = 1, a = 1})
  local effects = {}
  for _, name in pairs{"ff-packing-depot", "ff-unpacking-depot"} do
    if (name == "ff-packing-depot" and packing_ok) or (name == "ff-unpacking-depot" and unpacking_ok) then
      data:extend{{
        type = "recipe",
        name = name,
        enabled = false,
        energy_required = 5,
        ingredients = {
          {type = "item", name = name == "ff-packing-depot" and "storage-chest" or "passive-provider-chest", amount = 1},
          {type = "item", name = "ic-containerization-machine-1", amount = 1},
          {type = "item", name = "advanced-circuit", amount = 10},
        },
        results = {{type = "item", name = name, amount = 1}},
      }}
      effects[#effects + 1] = {type = "unlock-recipe", recipe = name}
    end
  end
  if #effects > 0 and data.raw.technology["ic-containerization-1"] and data.raw.technology["logistic-robotics"] then
    data:extend{{
      type = "technology",
      name = "ff-container-depots",
      localised_name = {"technology-name.ff-container-depots"},
      localised_description = {"technology-description.ff-container-depots"},
      icons = tinted(data.raw.technology["logistic-robotics"], {r = 1, g = 0.85, b = 0.6, a = 1}),
      effects = effects,
      prerequisites = {"ic-containerization-1", "logistic-robotics"},
      unit = {
        count = 200,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
        },
        time = 30,
      },
    }}
  end
end
