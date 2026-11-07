-- Spread Nauvis enemies out: every reference to `distance` and `starting_area_radius` in the enemy
-- autoplace expressions is replaced by the value divided by `distance_scale`, so enemy bases get
-- bigger/more frequent 2.5 times further away from spawn than in vanilla.
-- (1.1 did the same by walking the noise expression tree; in 2.x expressions are strings.)

local distance_scale = 2.5
local replaced_identifiers = { "distance", "starting_area_radius" }

--- Replaces whole-word identifiers in a noise expression string, skipping named arguments (`distance = ...`).
local function scale_identifiers(expression)
  if type(expression) ~= "string" then return expression end
  for _, identifier in pairs(replaced_identifiers) do
    local result, position = {}, 1
    while true do
      local s, e = expression:find("%f[%w_]" .. identifier .. "%f[^%w_]", position)
      if not s then break end
      local rest = expression:sub(e + 1)
      local is_named_argument = rest:match("^%s*=") and not rest:match("^%s*==")
      local is_var_string = expression:sub(s - 1, s - 1) == "'" or expression:sub(s - 1, s - 1) == '"'
      result[#result + 1] = expression:sub(position, s - 1)
      if is_named_argument or is_var_string then
        result[#result + 1] = identifier
      else
        result[#result + 1] = "(" .. identifier .. " / " .. distance_scale .. ")"
      end
      position = e + 1
    end
    result[#result + 1] = expression:sub(position)
    expression = table.concat(result)
  end
  return expression
end

local function update_expression_holder(holder, keys)
  if not holder then return end
  for _, key in pairs(keys) do
    holder[key] = scale_identifiers(holder[key])
  end
  if holder.local_expressions then
    for name, expression in pairs(holder.local_expressions) do
      holder.local_expressions[name] = scale_identifiers(expression)
    end
  end
end

local autoplace_keys = { "probability_expression", "richness_expression" }

-- Only Nauvis enemies (other planets' enemies, e.g. Gleba's, have their own expressions and are left alone)
local nauvis_enemy_types = { "unit-spawner", "turret" }
for _, type in pairs(nauvis_enemy_types) do
  for _, prototype in pairs(data.raw[type] or {}) do
    local autoplace = prototype.autoplace
    if autoplace and not (autoplace.probability_expression or ""):find("gleba", 1, true) then
      update_expression_holder(autoplace, autoplace_keys)
    end
  end
end

-- Shared named expressions/functions used by those autoplaces
for _, type in pairs{ "noise-expression", "noise-function" } do
  for name, prototype in pairs(data.raw[type] or {}) do
    if name:sub(1, 5) == "enemy" then
      update_expression_holder(prototype, { "expression" })
    end
  end
end
