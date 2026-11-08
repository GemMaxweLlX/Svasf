-- Space Age + Intermodal Containers: refrigerated containers (reefers) from Gleba.
--
-- Intermodal Containers skips spoilable items. Reefers carry them instead: a filled reefer spoils 5 times slower
-- than its contents would. Freshness is kept when loading/unloading (normal recipe spoil inheritance).
-- If a filled reefer does spoil, it turns into a reefer full of what its contents spoil into (spoilage, or ore
-- for bacteria), which unloads into that + an empty reefer (prototypes/spoiled-containers.lua).
-- Empty reefers can only be made on Gleba. Runs in data-updates.

-- Classic mode keeps the original Freight Forwarding (prototypes/... see settings.lua)
if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end
if not (data.raw.item["ic-container"] and data.raw["recipe-category"]["packing"]) then return end

local spoiled_containers = require("__FreightForwarding__.prototypes.spoiled-containers")
local SPOIL_SLOWDOWN = 5
-- Like Intermodal Containers: a container is sometimes lost when unloading (1% in FF)
local CONTAINER_RETURN = 1 - settings.startup["ic-container-loss-chance"].value
local kg = 1000
local STACKS_PER_REEFER = 10
local GLEBA = {{property = "pressure", min = 2000, max = 2000}}
local reefer_tint = {r = 0.55, g = 0.85, b = 1, a = 1}

local container_icon = data.raw.item["ic-container"].icon
local container_icon_size = data.raw.item["ic-container"].icon_size or 64

data:extend{
  {
    type = "item-subgroup",
    name = "ff-reefer-containers",
    group = "intermediate-products",
    order = "zz[ff-reefer]",
  },
  {
    type = "item-subgroup",
    name = "ff-reefer-load",
    group = "intermediate-products",
    order = "zz[ff-reefer]-b",
  },
  {
    type = "item-subgroup",
    name = "ff-reefer-unload",
    group = "intermediate-products",
    order = "zz[ff-reefer]-c",
  },
}

local function item_icons(item)
  if item.icons then return table.deepcopy(item.icons) end
  return {{icon = item.icon, icon_size = item.icon_size or 64}}
end

local function scaled(icons, scale, shift)
  local result = {}
  for i, icon in pairs(icons) do
    local copy = table.deepcopy(icon)
    copy.scale = (copy.scale or (32 / (copy.icon_size or 64))) * scale
    copy.shift = {(copy.shift and copy.shift[1] or 0) * scale + shift[1], (copy.shift and copy.shift[2] or 0) * scale + shift[2]}
    result[i] = copy
  end
  return result
end

local function reefer_icons(content_icons)
  local icons = {{icon = container_icon, icon_size = container_icon_size, tint = reefer_tint}}
  if content_icons then
    for _, icon in pairs(scaled(content_icons, 0.55, {0, -2})) do table.insert(icons, icon) end
  end
  return icons
end

---------------------------------------------------------------------------------------------------
-- Empty reefer and the "spoiled" reefer

data:extend{
  {
    type = "item",
    name = "ff-reefer-container",
    localised_name = {"item-name.ff-reefer-container"},
    localised_description = {"item-description.ff-reefer-container"},
    icons = reefer_icons(),
    subgroup = "ff-reefer-containers",
    order = "a",
    stack_size = 10,
  },
  {
    type = "recipe",
    name = "ff-reefer-container",
    enabled = false,
    energy_required = 2,
    ingredients = {
      {type = "item", name = "ic-container", amount = 1},
      {type = "item", name = "carbon-fiber", amount = 2},
      {type = "item", name = "plastic-bar", amount = 4},
      {type = "item", name = "steel-plate", amount = 2},
    },
    results = {{type = "item", name = "ff-reefer-container", amount = 1}},
    surface_conditions = GLEBA,
  },
  {
    type = "item",
    name = "ff-reefer-spoilage",
    localised_name = {"item-name.ff-reefer-filled", {"item-name.spoilage"}},
    icons = reefer_icons(item_icons(data.raw.item["spoilage"])),
    subgroup = "ff-reefer-containers",
    order = "b",
    stack_size = 1,
  },
  {
    type = "recipe",
    name = "ff-reefer-unload-spoilage",
    localised_name = {"recipe-name.ff-reefer-unload", {"item-name.spoilage"}},
    categories = {"packing"},
    subgroup = "ff-reefer-unload",
    icons = reefer_icons(item_icons(data.raw.item["spoilage"])),
    enabled = false,
    energy_required = 2,
    ingredients = {{type = "item", name = "ff-reefer-spoilage", amount = 1}},
    results = {
      {type = "item", name = "ff-reefer-container", amount = 1, independent_probability = CONTAINER_RETURN},
      {type = "item", name = "spoilage", amount = 100},
    },
    hide_from_player_crafting = true,
    allow_decomposition = false,
  },
}

---------------------------------------------------------------------------------------------------
-- One reefer per spoilable item

local unlocks = {
  {type = "unlock-recipe", recipe = "ff-reefer-container"},
  {type = "unlock-recipe", recipe = "ff-reefer-unload-spoilage"},
}

local function is_reefer_cargo(item)
  if not item.spoil_ticks or item.spoil_ticks <= 0 then return false end
  if item.spoil_to_trigger_result then return false end  -- eggs hatch, don't freeze them
  if item.hidden or item.parameter then return false end
  if item.name:sub(1, 9) == "ff-reefer" then return false end
  return true
end

local cargo = {}
for _, type in pairs{"item", "tool", "capsule", "ammo"} do
  for name, item in pairs(data.raw[type] or {}) do
    if is_reefer_cargo(item) then cargo[#cargo + 1] = item end
  end
end
table.sort(cargo, function(a, b) return a.name < b.name end)

for _, item in pairs(cargo) do
  local name = item.name
  local amount = math.min(65535, math.ceil((item.stack_size or 1) * STACKS_PER_REEFER))
  local content_icons = item_icons(item)
  local filled = "ff-reefer-" .. name
  local energy = math.max(1, amount / 30)

  data:extend{
    {
      type = "item",
      name = filled,
      localised_name = {"item-name.ff-reefer-filled-amount", tostring(amount), item.localised_name or {"item-name." .. name}},
      icons = reefer_icons(content_icons),
      subgroup = "ff-reefer-containers",
      order = "c[" .. name .. "]",
      stack_size = 1,
      weight = item.weight and item.weight * amount or nil,
      -- otherwise derived from the loading recipe: container + contents
      ingredient_to_weight_coefficient = 1,
      spoil_ticks = item.spoil_ticks * SPOIL_SLOWDOWN,
      spoil_result = spoiled_containers.make{
        prefix = "ff-reefer-", empty = "ff-reefer-container", item = item, amount = amount,
        icons_for = reefer_icons, item_icons = item_icons, weight = 1000 * kg,
        subgroup = "ff-reefer-containers", unload_subgroup = "ff-reefer-unload", unlocks = unlocks,
      },
    },
    {
      type = "recipe",
      name = "ff-reefer-load-" .. name,
      localised_name = {"recipe-name.ff-reefer-load", item.localised_name or {"item-name." .. name}},
      categories = {"packing"},
      subgroup = "ff-reefer-load",
      order = name,
      icons = reefer_icons(content_icons),
      enabled = false,
      energy_required = energy,
      ingredients = {
        {type = "item", name = "ff-reefer-container", amount = 1},
        {type = "item", name = name, amount = amount},
      },
      results = {{type = "item", name = filled, amount = 1}},
      hide_from_player_crafting = true,
      allow_decomposition = true,  -- lets the game derive the filled reefer weight from this recipe
      allow_as_intermediate = false,
    },
    {
      type = "recipe",
      name = "ff-reefer-unload-" .. name,
      localised_name = {"recipe-name.ff-reefer-unload", item.localised_name or {"item-name." .. name}},
      categories = {"packing"},
      subgroup = "ff-reefer-unload",
      order = name,
      icons = reefer_icons(content_icons),
      enabled = false,
      energy_required = energy,
      ingredients = {{type = "item", name = filled, amount = 1}},
      results = {
        {type = "item", name = "ff-reefer-container", amount = 1, independent_probability = CONTAINER_RETURN},
        {type = "item", name = name, amount = amount},
      },
      main_product = name,
      hide_from_player_crafting = true,
      allow_decomposition = false,
      allow_as_intermediate = false,
    },
  }
  table.insert(unlocks, {type = "unlock-recipe", recipe = "ff-reefer-load-" .. name})
  table.insert(unlocks, {type = "unlock-recipe", recipe = "ff-reefer-unload-" .. name})
end

---------------------------------------------------------------------------------------------------

local prerequisites = {"agricultural-science-pack"}
if data.raw.technology["ic-containerization-1"] then table.insert(prerequisites, "ic-containerization-1") end

data:extend{
  {
    type = "technology",
    name = "ff-refrigerated-containers",
    localised_name = {"technology-name.ff-refrigerated-containers"},
    localised_description = {"technology-description.ff-refrigerated-containers", tostring(SPOIL_SLOWDOWN)},
    icons = {{icon = container_icon, icon_size = container_icon_size, tint = reefer_tint, scale = 2}},
    effects = unlocks,
    prerequisites = prerequisites,
    unit = {
      count = 500,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"space-science-pack", 1},
        {"agricultural-science-pack", 1},
      },
      time = 30,
    },
  },
}
