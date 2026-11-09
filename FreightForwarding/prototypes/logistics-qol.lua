-- Logistics quality of life. Runs in data-updates.
--   * spoilage sensor (Space Age): a combinator next to a train stop that outputs how spoiled the stopped train's
--     cargo is, for wait conditions (scripts/spoilage-sensor.lua)
--   * cargo sensor (extended mode, with Intermodal Containers): a combinator next to a train stop or port that outputs
--     what the containers in the stopped train or ship hold, unpacked (scripts/cargo-sensor.lua)

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
-- Cargo sensor (extended mode)

if not settings.startup["ff-classic-mode"].value and data.raw.item["ic-container"] then
  local container_icon = data.raw.item["ic-container"]
  local base_icons = container_icon.icons or {{icon = container_icon.icon, icon_size = container_icon.icon_size or 64}}
  local function signal(name, letter, order)
    local icons = table.deepcopy(base_icons)
    icons[#icons + 1] = {icon = "__base__/graphics/icons/signal/signal_" .. letter .. ".png", icon_size = 64, scale = 0.25, shift = {8, 8}}
    return {type = "virtual-signal", name = name, localised_name = {"virtual-signal-name." .. name}, icons = icons,
            subgroup = "virtual-signal", order = "z[ff]-c" .. order}
  end
  data:extend{signal("ff-cargo-containers", "C", "a"), signal("ff-cargo-fill", "F", "b"), signal("ff-cargo-vehicles", "V", "c")}
  if copy_entity("constant-combinator", "constant-combinator", "ff-cargo-sensor", {r = 0.55, g = 0.75, b = 1, a = 1}) then
    data:extend{{
      type = "recipe",
      name = "ff-cargo-sensor",
      enabled = false,
      energy_required = 1,
      ingredients = {
        {type = "item", name = "constant-combinator", amount = 1},
        {type = "item", name = "electronic-circuit", amount = 5},
        {type = "item", name = "ic-container", amount = 1},
      },
      results = {{type = "item", name = "ff-cargo-sensor", amount = 1}},
    }}
    local tech = data.raw.technology["circuit-network"] and "circuit-network" or "ic-containerization-1"
    util.add_unlock(tech, "ff-cargo-sensor")
  end
end
