-- Space Age + Intermodal Containers: container tiers. Runs in data-final-fixes, after Intermodal Containers
-- has generated its containers (FF loads after it).
--   1. container (Intermodal Containers)            - Nauvis
--   2. refrigerated container (reefer-containers.lua) - Gleba, spoilable items, spoil 5x slower
--   3. light container                                - Vulcanus, any containerized item, fixed weight (setting, 400 kg)
--   4. cryo container                                 - Aquilo, spoilable items, spoil 20x slower, fixed weight (setting, 400 kg)
-- The fixed weight makes containers worth it for rockets: 2 per rocket by default, whatever is inside.

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end
if not (data.raw.item["ic-container"] and data.raw["recipe-category"]["packing"]) then return end

local kg = 1000
local CONTAINER_WEIGHT = settings.startup["ff-light-container-weight"].value * kg
local VULCANUS = {{property = "pressure", min = 4000, max = 4000}}
local AQUILO = {{property = "pressure", min = 300, max = 300}}

local container_icon = data.raw.item["ic-container"].icon
local container_icon_size = data.raw.item["ic-container"].icon_size or 64

local function item_icons(item)
  if item.icons then return table.deepcopy(item.icons) end
  return {{icon = item.icon, icon_size = item.icon_size or 64}}
end

local function container_icons(tint, content_icons)
  local icons = {{icon = container_icon, icon_size = container_icon_size, tint = tint}}
  for _, icon in pairs(content_icons or {}) do
    local copy = table.deepcopy(icon)
    copy.scale = (copy.scale or (32 / (copy.icon_size or 64))) * 0.55
    copy.shift = {(copy.shift and copy.shift[1] or 0) * 0.55, (copy.shift and copy.shift[2] or 0) * 0.55 - 2}
    icons[#icons + 1] = copy
  end
  return icons
end

local function find_item(name)
  for _, type in pairs{"item", "tool", "capsule", "ammo", "module", "rail-planner", "repair-tool", "item-with-entity-data", "gun", "armor"} do
    if data.raw[type] and data.raw[type][name] then return data.raw[type][name] end
  end
end

--- Creates one container family: an empty container item + recipe, and a filled item with load/unload recipes per
--- content item. Returns the technology effects unlocking all of it.
local function make_family(family)
  data:extend{
    {type = "item-subgroup", name = family.prefix .. "containers", group = "intermediate-products", order = "zz[" .. family.prefix .. "]"},
    {type = "item-subgroup", name = family.prefix .. "load", group = "intermediate-products", order = "zz[" .. family.prefix .. "]-b"},
    {type = "item-subgroup", name = family.prefix .. "unload", group = "intermediate-products", order = "zz[" .. family.prefix .. "]-c"},
    {
      type = "item",
      name = family.empty,
      localised_name = {"item-name." .. family.empty},
      localised_description = {"item-description." .. family.empty},
      icons = container_icons(family.tint),
      subgroup = family.prefix .. "containers",
      order = "a",
      stack_size = 10,
    },
    {
      type = "recipe",
      name = family.empty,
      enabled = false,
      energy_required = 2,
      ingredients = family.ingredients,
      results = {{type = "item", name = family.empty, amount = 1}},
      surface_conditions = family.surface_conditions,
    },
  }
  local effects = {{type = "unlock-recipe", recipe = family.empty}}

  for _, entry in pairs(family.contents) do
    local item, amount = entry.item, entry.amount
    local name = item.name
    local filled = family.prefix .. name
    local icons = container_icons(family.tint, item_icons(item))
    local energy = math.max(1, amount / 30)
    data:extend{
      {
        type = "item",
        name = filled,
        localised_name = {"item-name." .. family.empty .. "-filled", tostring(amount), item.localised_name or {"item-name." .. name}},
        icons = icons,
        subgroup = family.prefix .. "containers",
        order = "c[" .. name .. "]",
        stack_size = 1,
        weight = CONTAINER_WEIGHT,
        spoil_ticks = family.spoil_factor and item.spoil_ticks and item.spoil_ticks * family.spoil_factor or nil,
        spoil_result = family.spoil_factor and family.spoiled or nil,
      },
      {
        type = "recipe",
        name = family.prefix .. "load-" .. name,
        localised_name = {"recipe-name." .. family.empty .. "-load", item.localised_name or {"item-name." .. name}},
        categories = {"packing"},
        subgroup = family.prefix .. "load",
        order = name,
        icons = icons,
        enabled = false,
        energy_required = energy,
        ingredients = {
          {type = "item", name = family.empty, amount = 1},
          {type = "item", name = name, amount = amount},
        },
        results = {{type = "item", name = filled, amount = 1}},
        hide_from_player_crafting = true,
        allow_decomposition = false,
        allow_as_intermediate = false,
      },
      {
        type = "recipe",
        name = family.prefix .. "unload-" .. name,
        localised_name = {"recipe-name." .. family.empty .. "-unload", item.localised_name or {"item-name." .. name}},
        categories = {"packing"},
        subgroup = family.prefix .. "unload",
        order = name,
        icons = icons,
        enabled = false,
        energy_required = energy,
        ingredients = {{type = "item", name = filled, amount = 1}},
        results = {
          {type = "item", name = family.empty, amount = 1},
          {type = "item", name = name, amount = amount},
        },
        main_product = name,
        hide_from_player_crafting = true,
        allow_decomposition = false,
        allow_as_intermediate = false,
      },
    }
    effects[#effects + 1] = {type = "unlock-recipe", recipe = family.prefix .. "load-" .. name}
    effects[#effects + 1] = {type = "unlock-recipe", recipe = family.prefix .. "unload-" .. name}
  end
  return effects
end

local function science(...)
  local ingredients = {}
  for _, name in pairs{...} do ingredients[#ingredients + 1] = {name, 1} end
  return ingredients
end

---------------------------------------------------------------------------------------------------
-- Light containers (Vulcanus): everything Intermodal Containers containerizes, same amount per container

if data.raw.item["tungsten-plate"] and data.raw.technology["metallurgic-science-pack"] then
  local contents = {}
  for name in pairs(data.raw.item) do
    if name:sub(1, 13) == "ic-container-" then
      local base_name = name:sub(14)
      local load = data.raw.recipe["ic-load-" .. base_name]
      local base = find_item(base_name)
      if load and base then
        for _, ingredient in pairs(load.ingredients) do
          if ingredient.name == base_name then
            contents[#contents + 1] = {item = base, amount = ingredient.amount}
          end
        end
      end
    end
  end
  table.sort(contents, function(a, b) return a.item.name < b.item.name end)

  local effects = make_family{
    prefix = "ff-light-",
    empty = "ff-light-container",
    tint = {r = 0.8, g = 0.85, b = 0.95, a = 1},
    ingredients = {
      {type = "item", name = "ic-container", amount = 1},
      {type = "item", name = "tungsten-plate", amount = 2},
    },
    surface_conditions = VULCANUS,
    contents = contents,
  }
  local prerequisites = {"metallurgic-science-pack"}
  if data.raw.technology["ic-containerization-1"] then table.insert(prerequisites, "ic-containerization-1") end
  data:extend{{
    type = "technology",
    name = "ff-light-containers",
    localised_name = {"technology-name.ff-light-containers"},
    localised_description = {"technology-description.ff-light-containers"},
    icons = {{icon = container_icon, icon_size = container_icon_size, tint = {r = 0.8, g = 0.85, b = 0.95, a = 1}, scale = 2}},
    effects = effects,
    prerequisites = prerequisites,
    unit = {
      count = 500,
      ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
        "space-science-pack", "metallurgic-science-pack"),
      time = 30,
    },
  }}
end

---------------------------------------------------------------------------------------------------
-- Cryo containers (Aquilo): spoilable items, like refrigerated containers but much colder

if data.raw.item["ff-reefer-container"] and data.raw.item["lithium-plate"] and data.raw.technology["cryogenic-science-pack"] then
  local contents = {}
  for name in pairs(data.raw.item) do
    if name:sub(1, 10) == "ff-reefer-" and name ~= "ff-reefer-container" and name ~= "ff-reefer-spoilage" then
      local base_name = name:sub(11)
      local load = data.raw.recipe["ff-reefer-load-" .. base_name]
      local base = find_item(base_name)
      if load and base then
        for _, ingredient in pairs(load.ingredients) do
          if ingredient.name == base_name then
            contents[#contents + 1] = {item = base, amount = ingredient.amount}
          end
        end
      end
    end
  end
  table.sort(contents, function(a, b) return a.item.name < b.item.name end)

  local effects = make_family{
    prefix = "ff-cryo-",
    empty = "ff-cryo-container",
    tint = {r = 0.6, g = 1, b = 1, a = 1},
    ingredients = {
      {type = "item", name = "ff-reefer-container", amount = 1},
      {type = "item", name = "lithium-plate", amount = 2},
    },
    surface_conditions = AQUILO,
    contents = contents,
    spoil_factor = 20,
    spoiled = "ff-reefer-spoilage",
  }
  data:extend{{
    type = "technology",
    name = "ff-cryo-containers",
    localised_name = {"technology-name.ff-cryo-containers"},
    localised_description = {"technology-description.ff-cryo-containers"},
    icons = {{icon = container_icon, icon_size = container_icon_size, tint = {r = 0.6, g = 1, b = 1, a = 1}, scale = 2}},
    effects = effects,
    prerequisites = {"ff-refrigerated-containers", "cryogenic-science-pack"},
    unit = {
      count = 1000,
      ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
        "space-science-pack", "agricultural-science-pack", "cryogenic-science-pack"),
      time = 30,
    },
  }}
end
