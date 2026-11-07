-- Data stage helpers. All functions are defensive: if the prototype they refer to doesn't exist
-- (e.g. a dependency renamed it in its 2.x version) they log and do nothing instead of crashing.

local legacy = require("__FreightForwarding__.prototypes.legacy")

local data_util = {}

local function warn(message)
  log("[FreightForwarding] " .. message)
end

---------------------------------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------------------------------

local item_types = { "item", "tool", "ammo", "capsule", "module", "item-with-entity-data", "rail-planner", "repair-tool", "armor", "gun", "spidertron-remote", "selection-tool" }

function data_util.get_item(name)
  for _, type in pairs(item_types) do
    local item = data.raw[type] and data.raw[type][name]
    if item then return item end
  end
end

function data_util.set_stack_size(item_name, stack_size)
  local item = data_util.get_item(item_name)
  if not item then return end
  item.stack_size = stack_size or 50
end

---------------------------------------------------------------------------------------------------
-- Technologies
---------------------------------------------------------------------------------------------------

function data_util.add_prerequisite(tech_name, prerequisite)
  local technology = data.raw.technology[tech_name]
  if not technology then return warn("add_prerequisite: no technology " .. tech_name) end
  if not data.raw.technology[prerequisite] then return warn("add_prerequisite: no technology " .. prerequisite) end
  technology.prerequisites = technology.prerequisites or {}
  for _, name in pairs(technology.prerequisites) do
    if name == prerequisite then return end
  end
  table.insert(technology.prerequisites, prerequisite)
end

function data_util.remove_prerequisite(tech_name, prerequisite)
  local technology = data.raw.technology[tech_name]
  if not (technology and technology.prerequisites) then return end
  for i = #technology.prerequisites, 1, -1 do
    if technology.prerequisites[i] == prerequisite then
      table.remove(technology.prerequisites, i)
    end
  end
end

local function ingredient_name(ingredient)
  return ingredient[1] or ingredient.name
end

function data_util.add_research_ingredient(tech_name, ingredient)
  local technology = data.raw.technology[tech_name]
  if not (technology and technology.unit) then return end
  for _, existing in pairs(technology.unit.ingredients) do
    if ingredient_name(existing) == ingredient then return end
  end
  table.insert(technology.unit.ingredients, { ingredient, 1 })
end

function data_util.remove_research_ingredient(tech_name, ingredient)
  local technology = data.raw.technology[tech_name]
  if not (technology and technology.unit) then return end
  local ingredients = technology.unit.ingredients
  for i = #ingredients, 1, -1 do
    if ingredient_name(ingredients[i]) == ingredient then
      table.remove(ingredients, i)
    end
  end
end

function data_util.contains_research_ingredient(tech_name, ingredient)
  local technology = data.raw.technology[tech_name]
  if not (technology and technology.unit) then return false end
  for _, existing in pairs(technology.unit.ingredients) do
    if ingredient_name(existing) == ingredient then return true end
  end
  return false
end

function data_util.is_descendant_of(tech_name, ancestor, visited)
  visited = visited or {}
  if visited[tech_name] then return false end
  visited[tech_name] = true
  local technology = data.raw.technology[tech_name]
  if not (technology and technology.prerequisites) then return false end
  for _, name in pairs(technology.prerequisites) do
    if name == ancestor or data_util.is_descendant_of(name, ancestor, visited) then
      return true
    end
  end
  return false
end

function data_util.add_unlock(tech_name, recipe_name, position)
  local technology = data.raw.technology[tech_name]
  if not technology then return warn("add_unlock: no technology " .. tech_name) end
  if not data.raw.recipe[recipe_name] then return warn("add_unlock: no recipe " .. recipe_name) end
  technology.effects = technology.effects or {}
  for _, effect in pairs(technology.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then return end
  end
  local effect = { type = "unlock-recipe", recipe = recipe_name }
  if position and position <= #technology.effects + 1 then
    table.insert(technology.effects, position, effect)
  else
    table.insert(technology.effects, effect)
  end
  data.raw.recipe[recipe_name].enabled = false
end

function data_util.remove_recipe_effect(tech_name, recipe_name)
  local technology = data.raw.technology[tech_name]
  if not (technology and technology.effects) then return end
  for i = #technology.effects, 1, -1 do
    local effect = technology.effects[i]
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      table.remove(technology.effects, i)
    end
  end
end

function data_util.hide_technology(tech_name)
  local technology = data.raw.technology[tech_name]
  if technology then
    technology.hidden = true
  end
end

---------------------------------------------------------------------------------------------------
-- Recipes (2.x format: ingredients are {type, name, amount})
---------------------------------------------------------------------------------------------------

local function get_recipe(recipe_name, caller)
  local recipe = data.raw.recipe[recipe_name]
  if not recipe then
    warn(caller .. ": no recipe " .. recipe_name)
    return nil
  end
  legacy.fix_recipe(recipe)  -- in case another mod left it in an old format
  recipe.ingredients = recipe.ingredients or {}
  return recipe
end

local function find_ingredient(recipe, name)
  for i, ingredient in pairs(recipe.ingredients) do
    if ingredient.name == name then return ingredient, i end
  end
end

function data_util.set_ingredients(recipe_name, ingredients)
  local recipe = get_recipe(recipe_name, "set_ingredients")
  if not recipe then return end
  recipe.ingredients = ingredients
  legacy.fix_recipe(recipe)
end

function data_util.set_ingredient(recipe_name, name, amount)
  local recipe = get_recipe(recipe_name, "set_ingredient")
  if not recipe then return end
  local ingredient = find_ingredient(recipe, name)
  if ingredient then
    ingredient.amount = amount
  else
    table.insert(recipe.ingredients, { type = data.raw.fluid[name] and "fluid" or "item", name = name, amount = amount })
  end
end

function data_util.add_ingredient(recipe_name, name, amount)
  local recipe = get_recipe(recipe_name, "add_ingredient")
  if not recipe then return end
  local ingredient = find_ingredient(recipe, name)
  if ingredient then
    ingredient.amount = ingredient.amount + amount
  else
    table.insert(recipe.ingredients, { type = data.raw.fluid[name] and "fluid" or "item", name = name, amount = amount })
  end
end

function data_util.remove_ingredient(recipe_name, name)
  local recipe = get_recipe(recipe_name, "remove_ingredient")
  if not recipe then return end
  for i = #recipe.ingredients, 1, -1 do
    if recipe.ingredients[i].name == name then
      table.remove(recipe.ingredients, i)
    end
  end
end

function data_util.replace_ingredient(recipe_name, old, new)
  local recipe = get_recipe(recipe_name, "replace_ingredient")
  if not recipe then return end
  local ingredient = find_ingredient(recipe, old)
  if not ingredient then return end
  local existing = find_ingredient(recipe, new)
  if existing then
    existing.amount = existing.amount + ingredient.amount
    data_util.remove_ingredient(recipe_name, old)
  else
    ingredient.name = new
  end
end

function data_util.get_ingredient_amount(recipe_name, name)
  local recipe = get_recipe(recipe_name, "get_ingredient_amount")
  if not recipe then return 0 end
  local ingredient = find_ingredient(recipe, name)
  return ingredient and ingredient.amount or 0
end

function data_util.set_product_amount(recipe_name, name, amount)
  local recipe = get_recipe(recipe_name, "set_product_amount")
  if not recipe then return end
  for _, product in pairs(recipe.results or {}) do
    if product.name == name then
      product.amount = amount
      product.amount_min, product.amount_max = nil, nil
    end
  end
end

function data_util.replace_product(recipe_name, old, new)
  local recipe = get_recipe(recipe_name, "replace_product")
  if not recipe then return end
  for _, product in pairs(recipe.results or {}) do
    if product.name == old then product.name = new end
  end
  if recipe.main_product == old then recipe.main_product = new end
end

function data_util.set_recipe_time(recipe_name, time)
  local recipe = data.raw.recipe[recipe_name]
  if recipe then recipe.energy_required = time end
end

function data_util.set_prerequisite(tech_name, prerequisites)
  local technology = data.raw.technology[tech_name]
  if technology then technology.prerequisites = prerequisites end
end

--- 2.x: productivity is allowed per recipe instead of via module `limitation` lists.
function data_util.allow_productivity(recipe_name)
  local recipe = data.raw.recipe[recipe_name]
  if recipe then
    recipe.allow_productivity = true
  end
end

---------------------------------------------------------------------------------------------------

function data_util.contains(list, value)
  for _, v in pairs(list or {}) do
    if v == value then return true end
  end
  return false
end

function data_util.debug_technology(tech_name)
  local tech = data.raw.technology[tech_name]
  if not tech then log("Unable to find " .. tech_name) return end
  log(serpent.block({
    A_name    = tech.name,
    B_prereq  = tech.prerequisites,
    C_effects = tech.effects
  }))
end

function data_util.set_item_subgroup_order(subgroup_name, order)
  local item_subgroup = data.raw["item-subgroup"][subgroup_name]
  if not item_subgroup then return end
  item_subgroup.order = order
end

return data_util
