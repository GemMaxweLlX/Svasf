-- Mining Space Industries II: the rocket delivery mission ("msi_<item>_container") is made smaller.
--   * each cargo container holds half as much (e.g. 25 000 steel instead of 50 000) and needs 2 MSI containers, not 4;
--   * with Space Age a cargo container weighs 500 kg instead of 1 t, so FF's light rocket silo (500 kg) can launch it:
--     one per light rocket, two per normal rocket, four per heavy rocket.
-- The number of containers per request is lowered in compatibility/mining-space-industries/settings.lua.

if not mods["Mining-Space-Industries-II"] then return end

local CONTENT = 0.5
local MSI_CONTAINERS = 2
local WEIGHT = 500 * 1000  -- 500 kg

for name, item in pairs(data.raw.item) do
  local cargo = name:match("^msi_(.+)_container$")
  if cargo then
    if mods["space-age"] then item.weight = WEIGHT end
    local recipe = data.raw.recipe[name]
    if recipe and recipe.ingredients then
      for _, ingredient in pairs(recipe.ingredients) do
        if ingredient.name == "msi_container" then
          ingredient.amount = MSI_CONTAINERS
        elseif ingredient.name == cargo then
          ingredient.amount = math.max(1, math.ceil(ingredient.amount * CONTENT))
        end
      end
    end
  end
end
