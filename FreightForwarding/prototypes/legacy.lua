-- Converts prototype definitions written in the Factorio 1.1 format to the 2.x format.
--
-- FF's own prototypes are passed through `legacy.extend{...}` instead of `data:extend{...}`, so that
-- the large existing definitions (graphics, recipes, ...) keep working without being rewritten by hand.
-- It only converts things FF actually uses; anything already in 2.x format is left as is.

local C = require("__FreightForwarding__.prototypes.collision-util")

local legacy = {}

---------------------------------------------------------------------------------------------------
-- Graphics
---------------------------------------------------------------------------------------------------

-- 2.x ships only the high resolution sprites, and base/core files lost their "hr-" prefix.
local function fix_filename(filename)
  if type(filename) ~= "string" then return filename end
  if filename:find("^__base__/") or filename:find("^__core__/") then
    filename = filename:gsub("/hr%-([^/]+)$", "/%1")
  end
  return filename
end

local function fix_graphics(t, seen)
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  local hr = t.hr_version
  if type(hr) == "table" then
    -- The high resolution version replaces the normal one
    -- (keeping type/name for sprite/animation prototypes that are themselves the sprite)
    for k in pairs(t) do
      if k ~= "type" and k ~= "name" then t[k] = nil end
    end
    for k, v in pairs(hr) do t[k] = v end
  end
  t.icon_mipmaps = nil
  if t.filename then t.filename = fix_filename(t.filename) end
  if type(t.filenames) == "table" then
    for i, f in pairs(t.filenames) do t.filenames[i] = fix_filename(f) end
  end
  if t.icon then t.icon = fix_filename(t.icon) end
  if type(t.picture) == "string" then t.picture = fix_filename(t.picture) end
  for _, v in pairs(t) do
    if type(v) == "table" then fix_graphics(v, seen) end
  end
end

---------------------------------------------------------------------------------------------------
-- Recipes
---------------------------------------------------------------------------------------------------

-- In 1.1 an ingredient/product without `type` was an item; 2.x requires the type.
local function product_type(_)
  return "item"
end

--- `{"iron-plate", 5}` / `{name = "iron-plate", amount = 5}` -> `{type = "item", name = "iron-plate", amount = 5}`
function legacy.ingredient(ingredient)
  if ingredient[1] then
    return { type = product_type(ingredient[1]), name = ingredient[1], amount = ingredient[2] or 1 }
  end
  ingredient.type = ingredient.type or product_type(ingredient.name)
  if ingredient.catalyst_amount then
    ingredient.ignored_by_stats = ingredient.ignored_by_stats or ingredient.catalyst_amount
    ingredient.catalyst_amount = nil
  end
  return ingredient
end

function legacy.product(product)
  if product[1] then
    return { type = product_type(product[1]), name = product[1], amount = product[2] or 1 }
  end
  product.type = product.type or product_type(product.name)
  if product.amount == nil and product.amount_min == nil then
    product.amount = 1
  end
  if product.catalyst_amount then
    product.ignored_by_productivity = product.ignored_by_productivity or product.catalyst_amount
    product.ignored_by_stats = product.ignored_by_stats or product.catalyst_amount
    product.catalyst_amount = nil
  end
  return product
end

function legacy.fix_recipe(recipe)
  -- normal/expensive difficulty was removed: use normal
  local variant = recipe.normal or recipe.expensive
  if type(variant) == "table" then
    for k, v in pairs(variant) do
      if recipe[k] == nil then recipe[k] = v end
    end
  end
  recipe.normal, recipe.expensive = nil, nil

  if recipe.ingredients then
    local ingredients = {}
    for i, ingredient in pairs(recipe.ingredients) do ingredients[i] = legacy.ingredient(ingredient) end
    recipe.ingredients = ingredients
  end

  if recipe.result then
    recipe.results = { { type = product_type(recipe.result), name = recipe.result, amount = recipe.result_count or 1 } }
    recipe.result, recipe.result_count = nil, nil
  elseif recipe.results then
    local results = {}
    for i, product in pairs(recipe.results) do results[i] = legacy.product(product) end
    recipe.results = results
  end
end

---------------------------------------------------------------------------------------------------
-- Entities
---------------------------------------------------------------------------------------------------

local function fix_energy_source(energy_source)
  if type(energy_source) ~= "table" then return end
  if type(energy_source.emissions_per_minute) == "number" then
    energy_source.emissions_per_minute = { pollution = energy_source.emissions_per_minute }
  end
  if energy_source.fuel_category then
    energy_source.fuel_categories = { energy_source.fuel_category }
    energy_source.fuel_category = nil
  end
  if energy_source.fluid_box then legacy.fix_fluid_box(energy_source.fluid_box) end
end

local flow_directions = { ["input-output"] = "input-output", input = "input", output = "output" }

--- Converts 1.1 pipe connections (position one tile outside the entity) to 2.x
--- (position of the tile inside the entity + direction). Needs the owner's collision box.
local function fix_pipe_connection(connection, box)
  if connection.direction or not connection.position then return end
  local x, y = connection.position[1] or connection.position.x, connection.position[2] or connection.position.y
  if connection.type then
    connection.flow_direction = flow_directions[connection.type] or "input-output"
    connection.type = nil
  end
  if connection.max_underground_distance then
    connection.connection_type = "underground"
  end
  local half_w = box and math.ceil(math.max(-box[1][1], box[2][1]) * 2) / 2 or 0.5
  local half_h = box and math.ceil(math.max(-box[1][2], box[2][2]) * 2) / 2 or 0.5
  if y < -half_h then
    connection.direction = defines.direction.north
    y = y + 1
  elseif y > half_h then
    connection.direction = defines.direction.south
    y = y - 1
  elseif x < -half_w then
    connection.direction = defines.direction.west
    x = x + 1
  else
    connection.direction = defines.direction.east
    x = x - 1
  end
  connection.position = { x, y }
end

function legacy.fix_fluid_box(fluid_box, box)
  if type(fluid_box) ~= "table" then return end
  if fluid_box.base_area and not fluid_box.volume then
    fluid_box.volume = fluid_box.base_area * (fluid_box.height or 1) * 100
  end
  fluid_box.base_area, fluid_box.height, fluid_box.base_level = nil, nil, nil
  for _, connection in pairs(fluid_box.pipe_connections or {}) do
    fix_pipe_connection(connection, box)
  end
end

local crafting_machine_graphics = {
  "animation", "idle_animation", "always_draw_idle_animation", "working_visualisations",
  "integration_patch", "default_recipe_tint", "shift_animation_waypoints", "status_colors",
}

local function fix_entity(prototype)
  fix_energy_source(prototype.energy_source)
  fix_energy_source(prototype.burner)

  if prototype.fluid_box then legacy.fix_fluid_box(prototype.fluid_box, prototype.collision_box) end
  if prototype.fluid_boxes then
    for _, fluid_box in pairs(prototype.fluid_boxes) do
      if type(fluid_box) == "table" then legacy.fix_fluid_box(fluid_box, prototype.collision_box) end
    end
  end

  if prototype.module_specification then
    prototype.module_slots = prototype.module_specification.module_slots
    prototype.module_specification = nil
  end

  if prototype.collision_mask and prototype.collision_mask.layers == nil then
    prototype.collision_mask = C.mask(prototype.collision_mask)
  end

  if prototype.circuit_wire_connection_points and not prototype.circuit_connector then
    prototype.circuit_connector = {
      points = prototype.circuit_wire_connection_points,
      sprites = prototype.circuit_connector_sprites,
    }
    prototype.circuit_wire_connection_points, prototype.circuit_connector_sprites = nil, nil
  end

  local t = prototype.type
  if (t == "assembling-machine" or t == "furnace") and not prototype.graphics_set then
    local graphics_set = {}
    for _, key in pairs(crafting_machine_graphics) do
      graphics_set[key] = prototype[key]
      prototype[key] = nil
    end
    prototype.graphics_set = graphics_set
  elseif t == "mining-drill" and prototype.animations and not prototype.graphics_set then
    prototype.graphics_set = { animation = prototype.animations }
    prototype.animations = nil
  end
end

---------------------------------------------------------------------------------------------------

local entity_types = {
  ["assembling-machine"] = true, ["furnace"] = true, ["mining-drill"] = true, ["radar"] = true,
  ["storage-tank"] = true, ["pipe"] = true, ["electric-pole"] = true, ["burner-generator"] = true,
  ["resource"] = true, ["rocket-silo"] = true, ["explosion"] = true, ["container"] = true,
}

--- Converts a single prototype in place and returns it.
function legacy.fix(prototype)
  fix_graphics(prototype, {})

  if prototype.flags then
    local flags = {}
    for _, flag in pairs(prototype.flags) do
      if flag == "hidden" then
        prototype.hidden = true
      else
        flags[#flags + 1] = flag
      end
    end
    prototype.flags = flags
  end

  local t = prototype.type
  if t == "recipe" then
    legacy.fix_recipe(prototype)
  elseif t == "tile" then
    if prototype.pollution_absorption_per_second then
      prototype.absorptions_per_second = { pollution = prototype.pollution_absorption_per_second }
      prototype.pollution_absorption_per_second = nil
    end
    if prototype.collision_mask and prototype.collision_mask.layers == nil then
      prototype.collision_mask = C.mask(prototype.collision_mask)
    end
  elseif t == "item" or t == "tool" or t == "item-with-entity-data" then
    if prototype.rocket_launch_product then
      local product = prototype.rocket_launch_product
      prototype.rocket_launch_products = { legacy.product(product) }
      prototype.rocket_launch_product = nil
    end
    if prototype.place_as_tile and prototype.place_as_tile.condition and prototype.place_as_tile.condition.layers == nil then
      prototype.place_as_tile.condition = C.mask(prototype.place_as_tile.condition)
    end
  elseif entity_types[t] then
    fix_entity(prototype)
  end
  return prototype
end

--- Drop-in replacement for `data:extend` that converts 1.1-style prototypes first.
function legacy.extend(prototypes)
  for _, prototype in pairs(prototypes) do
    legacy.fix(prototype)
  end
  data:extend(prototypes)
end

return legacy
