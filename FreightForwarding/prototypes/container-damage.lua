-- Containers wear out: when unloading, a container is lost (1%, like Intermodal Containers) or comes back damaged
-- (2%).
-- A damaged container is repaired by hand for a quarter of its materials, or thrown into the recycler (Space Age).
-- Runs in data-final-fixes, after Intermodal Containers and container-tiers.lua. Not in classic mode, which keeps
-- Intermodal Containers' plain 1% loss.

if settings.startup["ff-classic-mode"].value then return end
if not data.raw.item["ic-container"] then return end

local LOSS_CHANCE = 0.01
local DAMAGE_CHANCE = 0.02

local KINDS = {
  {empty = "ic-container", unload_prefix = "ic-unload-"},
  {empty = "ff-reefer-container", unload_prefix = "ff-reefer-unload-"},
  {empty = "ff-light-container", unload_prefix = "ff-light-unload-"},
  {empty = "ff-cryo-container", unload_prefix = "ff-cryo-unload-"},
  {empty = "ff-tank-container", unload_prefix = "ff-tank-unload-"},
}

local repair_icon = data.raw["repair-tool"]["repair-pack"] and data.raw["repair-tool"]["repair-pack"].icon

local function icons_of(item)
  return table.deepcopy(item.icons or {{icon = item.icon, icon_size = item.icon_size or 64}})
end

local function find_unlocking_tech(recipe_name)
  for name, tech in pairs(data.raw.technology) do
    for _, effect in pairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe_name then return name end
    end
  end
end

for _, kind in pairs(KINDS) do
  local empty = data.raw.item[kind.empty]
  local recipe = data.raw.recipe[kind.empty]
  if empty and recipe then
    local damaged_name = "ff-damaged-" .. kind.empty
    local icons = icons_of(empty)
    for _, icon in pairs(icons) do
      local t = icon.tint or {r = 1, g = 1, b = 1}
      icon.tint = {r = (t.r or t[1] or 1) * 0.6, g = (t.g or t[2] or 1) * 0.45, b = (t.b or t[3] or 1) * 0.35, a = 1}
    end
    if repair_icon then
      table.insert(icons, {icon = repair_icon, icon_size = 64, scale = 0.25, shift = {-8, -8}})
    end

    -- Repair: a quarter of the materials (other containers in the recipe are not needed again)
    local repair_ingredients = {{type = "item", name = damaged_name, amount = 1}}
    local recycle_results = {}
    for _, ingredient in pairs(recipe.ingredients or {}) do
      local name, amount = ingredient.name or ingredient[1], ingredient.amount or ingredient[2]
      if name and amount and not name:find("container") then
        repair_ingredients[#repair_ingredients + 1] = {type = "item", name = name, amount = math.max(1, math.floor(amount / 4))}
      end
      if name and amount then
        local share = amount / 4
        if share >= 1 then
          recycle_results[#recycle_results + 1] = {type = "item", name = name, amount = math.floor(share)}
        else
          recycle_results[#recycle_results + 1] = {type = "item", name = name, amount = 1, independent_probability = share}
        end
      end
    end

    data:extend{
      {
        type = "item",
        name = damaged_name,
        localised_name = {"item-name.ff-damaged-container", empty.localised_name or {"item-name." .. kind.empty}},
        localised_description = {"item-description.ff-damaged-container"},
        icons = icons,
        subgroup = empty.subgroup,
        order = (empty.order or "") .. "-damaged",
        stack_size = empty.stack_size or 10,
        weight = empty.weight,
      },
      {
        type = "recipe",
        name = "ff-repair-" .. kind.empty,
        localised_name = {"recipe-name.ff-repair-container", empty.localised_name or {"item-name." .. kind.empty}},
        icons = icons,
        subgroup = empty.subgroup,
        order = (empty.order or "") .. "-repair",
        enabled = false,
        energy_required = 2,
        ingredients = repair_ingredients,
        results = {{type = "item", name = kind.empty, amount = 1}},
        allow_decomposition = false,
      },
    }
    local tech = find_unlocking_tech(kind.empty)
    if tech then
      table.insert(data.raw.technology[tech].effects, {type = "unlock-recipe", recipe = "ff-repair-" .. kind.empty})
    else
      data.raw.recipe["ff-repair-" .. kind.empty].enabled = true
    end
    if data.raw["recipe-category"]["recycling"] and #recycle_results > 0 then
      data:extend{{
        type = "recipe",
        name = damaged_name .. "-recycling",
        localised_name = {"recipe-name.recycling", {"item-name.ff-damaged-container", empty.localised_name or {"item-name." .. kind.empty}}},
        icons = icons,
        categories = {"recycling"},
        subgroup = empty.subgroup,
        enabled = true,
        hidden = true,
        unlock_results = false,
        energy_required = 0.125,
        ingredients = {{type = "item", name = damaged_name, amount = 1}},
        results = recycle_results,
      }}
    end

    -- Unloading: usable container, damaged container or nothing (one roll)
    for name, unload in pairs(data.raw.recipe) do
      if name:sub(1, #kind.unload_prefix) == kind.unload_prefix then
        for _, result in pairs(unload.results or {}) do
          if result.name == kind.empty then
            result.independent_probability = nil
            result.probability = nil
            local usable = 1 - LOSS_CHANCE - DAMAGE_CHANCE
            result.shared_probability = {min = 0, max = usable}
            table.insert(unload.results, {type = "item", name = damaged_name, amount = 1,
                                          shared_probability = {min = usable, max = usable + DAMAGE_CHANCE}})
            break
          end
        end
      end
    end
  end
end
