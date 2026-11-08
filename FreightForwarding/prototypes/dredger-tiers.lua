-- Space Age: bigger dredgers. Runs in data-updates, after qol.lua (which makes the dredger minable).
--   Mk2 (Vulcanus): 6x6, crafting speed 2, 2 module slots
--   Mk3 (Aquilo):   8x8, crafting speed 3, 4 module slots
-- Each tier is a placer (mining drill that only fits on a seamount/vent) and the dredger itself (assembling
-- machine), swapped by scripts/dredging-platform.lua like the normal dredger.

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end

local placer = data.raw["mining-drill"]["ff-dredging-platform"]
local dredger = data.raw["assembling-machine"]["ff-dredger"]
local item = data.raw.item["ff-dredging-platform"]
if not (placer and dredger and item) then return end

local function scale_sprites(t, k)
  if type(t) ~= "table" then return end
  if t.filename or t.filenames or t.stripes then
    t.scale = (t.scale or 1) * k
    if t.shift then
      local x, y = t.shift[1] or t.shift.x, t.shift[2] or t.shift.y
      t.shift = {x * k, y * k}
    end
  end
  for _, v in pairs(t) do scale_sprites(v, k) end
end

local function scale_box(box, k)
  if not box then return nil end
  local a, b = box[1] or box.left_top, box[2] or box.right_bottom
  local function c(p) return {(p[1] or p.x) * k, (p[2] or p.y) * k} end
  return {c(a), c(b)}
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

local function make_tier(p)
  for _, ingredient in pairs(p.ingredients) do
    if not data.raw.item[ingredient.name] then return end
  end
  local size = p.size / 4  -- the normal dredger is 4x4
  local item_name = "ff-dredging-platform-" .. p.suffix
  local dredger_name = "ff-dredger-" .. p.suffix

  local new_placer = table.deepcopy(placer)
  new_placer.name = item_name
  new_placer.localised_name = {"entity-name." .. dredger_name}
  new_placer.localised_description = {"entity-description." .. dredger_name}
  new_placer.icons = tinted(placer, p.tint)
  new_placer.icon = nil
  new_placer.collision_box = {{-p.size / 2 + 0.3, -p.size / 2 + 0.3}, {p.size / 2 - 0.3, p.size / 2 - 0.3}}
  new_placer.selection_box = {{-p.size / 2, -p.size / 2}, {p.size / 2, p.size / 2}}
  new_placer.drawing_box = scale_box(placer.drawing_box, size)
  new_placer.minable = {mining_time = 2, result = item_name}
  new_placer.next_upgrade = nil
  new_placer.fast_replaceable_group = nil
  scale_sprites(new_placer.graphics_set, size)

  local new_dredger = table.deepcopy(dredger)
  new_dredger.name = dredger_name
  new_dredger.localised_name = {"entity-name." .. dredger_name}
  new_dredger.localised_description = {"entity-description." .. dredger_name}
  new_dredger.icons = tinted(dredger, p.tint)
  new_dredger.icon = nil
  new_dredger.collision_box = new_placer.collision_box
  new_dredger.selection_box = new_placer.selection_box
  new_dredger.drawing_box = new_placer.drawing_box
  new_dredger.crafting_speed = p.speed
  new_dredger.energy_usage = p.energy
  new_dredger.module_slots = p.modules
  new_dredger.allowed_effects = {"consumption", "speed", "productivity", "pollution", "quality"}
  new_dredger.minable = {mining_time = 2, result = item_name}
  new_dredger.placeable_by = {item = item_name, count = 1}
  new_dredger.next_upgrade = nil
  new_dredger.fast_replaceable_group = nil
  scale_sprites(new_dredger.graphics_set, size)

  local new_item = table.deepcopy(item)
  new_item.name = item_name
  new_item.localised_name = {"entity-name." .. dredger_name}
  new_item.localised_description = {"entity-description." .. dredger_name}
  new_item.icons = tinted(item, p.tint)
  new_item.icon = nil
  new_item.place_result = item_name
  new_item.order = (item.order or "") .. "-" .. p.suffix

  data:extend{
    new_placer, new_dredger, new_item,
    {
      type = "recipe",
      name = item_name,
      enabled = false,
      energy_required = 20,
      ingredients = p.ingredients,
      results = {{type = "item", name = item_name, amount = 1}},
      surface_conditions = p.surface_conditions,
    },
    {
      type = "technology",
      name = "ff-dredger-" .. p.suffix,
      localised_name = {"technology-name.ff-dredger-" .. p.suffix},
      localised_description = {"technology-description.ff-dredger-" .. p.suffix},
      icons = tinted(data.raw.technology["ff-dredging"], p.tint),
      effects = {{type = "unlock-recipe", recipe = item_name}},
      prerequisites = p.prerequisites,
      unit = p.unit,
    },
  }
end

if data.raw.technology["metallurgic-science-pack"] then
  make_tier{
    suffix = "mk2", size = 6, speed = 2, modules = 2, energy = "4MW",
    tint = {r = 1, g = 0.75, b = 0.55, a = 1},
    ingredients = {
      {type = "item", name = "ff-dredging-platform", amount = 1},
      {type = "item", name = "tungsten-carbide", amount = 50},
      {type = "item", name = "electric-engine-unit", amount = 20},
    },
    surface_conditions = {{property = "pressure", min = 4000, max = 4000}},
    prerequisites = {"ff-dredging", "metallurgic-science-pack"},
    unit = {
      count = 500,
      ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
        "space-science-pack", "metallurgic-science-pack"),
      time = 60,
    },
  }
end

if data.raw.technology["cryogenic-science-pack"] and data.raw.item["ff-dredging-platform-mk2"] then
  make_tier{
    suffix = "mk3", size = 8, speed = 3, modules = 4, energy = "6MW",
    tint = {r = 0.65, g = 0.9, b = 1, a = 1},
    ingredients = {
      {type = "item", name = "ff-dredging-platform-mk2", amount = 1},
      {type = "item", name = "lithium-plate", amount = 50},
      {type = "item", name = "quantum-processor", amount = 10},
      {type = "item", name = "ff-titansteel-plate", amount = 20},
    },
    surface_conditions = {{property = "pressure", min = 300, max = 300}},
    prerequisites = {"ff-dredger-mk2", "cryogenic-science-pack"},
    unit = {
      count = 800,
      ingredients = science("automation-science-pack", "logistic-science-pack", "chemical-science-pack",
        "space-science-pack", "metallurgic-science-pack", "cryogenic-science-pack"),
      time = 60,
    },
  }
end

-- Productivity modules in the bigger dredgers
for _, recipe in pairs(data.raw.recipe) do
  for _, category in pairs(recipe.categories or {recipe.category}) do
    if category == "ff-dredging" then recipe.allow_productivity = true end
  end
end
