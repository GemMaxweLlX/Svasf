-- Space Age: a full refrigerated or cryo container that spoils turns into a container of whatever its contents spoil
-- into (spoilage, or ore for bacteria), the same amount. Unloading it gives that back plus the empty container
-- of the same kind. Contents that just disappear leave an empty container.

local M = {}

--- Creates (once) the spoiled version of a filled container and its unloading recipe.
--- params: prefix ("ff-reefer-"), empty (empty container item), item (contents prototype), amount,
---         icons_for(content_icons) -> icons, item_icons(prototype) -> icons, weight, unlocks (list to add to)
--- Returns the spoiled item name (to use as spoil_result of the filled container).
function M.make(params)
  local item = params.item
  local spoil_name = item.spoil_result
  local spoil_item = spoil_name and (data.raw.item[spoil_name] or data.raw.tool[spoil_name] or data.raw.capsule[spoil_name])
  local name = params.prefix .. "spoiled-" .. item.name
  if data.raw.item[name] then return name end

  local results = {{type = "item", name = params.empty, amount = 1,
                    independent_probability = 1 - settings.startup["ic-container-loss-chance"].value}}
  if spoil_item then results[2] = {type = "item", name = spoil_name, amount = params.amount} end
  local content_name = spoil_item and (spoil_item.localised_name or {"item-name." .. spoil_name}) or {"", "-"}
  local icons = params.icons_for(spoil_item and params.item_icons(spoil_item) or nil)

  data:extend{
    {
      type = "item",
      name = name,
      localised_name = {"item-name.ff-spoiled-container", {"item-name." .. params.empty}, tostring(params.amount), content_name},
      icons = icons,
      subgroup = params.subgroup,
      order = "b[" .. item.name .. "]",
      stack_size = 1,
      weight = params.weight,
      ic_create_container = false,  -- no container in a container
    },
    {
      type = "recipe",
      name = params.prefix .. "unload-spoiled-" .. item.name,
      localised_name = {"recipe-name.ff-spoiled-container-unload", {"item-name." .. params.empty}, content_name},
      categories = {"packing"},
      subgroup = params.unload_subgroup,
      order = "z[" .. item.name .. "]",
      icons = icons,
      enabled = false,
      energy_required = 2,
      ingredients = {{type = "item", name = name, amount = 1}},
      results = results,
      main_product = spoil_item and spoil_name or params.empty,
      hide_from_player_crafting = true,
      allow_decomposition = false,
      allow_as_intermediate = false,
    },
  }
  table.insert(params.unlocks, {type = "unlock-recipe", recipe = params.prefix .. "unload-spoiled-" .. item.name})
  return name
end

return M
