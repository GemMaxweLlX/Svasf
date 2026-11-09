-- Shortcut bar buttons for the freight panels (scripts/freight-contract.lua). Runs at the end of data-updates.

local function icons_of(item)
  return table.deepcopy(item.icons or {{icon = item.icon, icon_size = item.icon_size or 64}})
end

local container = data.raw.item["ic-container"]
if container then
  data:extend{{
    type = "shortcut",
    name = "ff-container-panel",
    order = "z[ff]-a",
    action = "lua",
    toggleable = true,
    icons = icons_of(container),
    small_icons = icons_of(container),
  }}
end

local consignment = data.raw.item["ff-freight-consignment"]
if consignment then
  data:extend{{
    type = "shortcut",
    name = "ff-contract-panel",
    order = "z[ff]-b",
    action = "lua",
    toggleable = true,
    icons = icons_of(consignment),
    small_icons = icons_of(consignment),
  }}
end

-- Routes panel (scripts/routes-panel.lua): all trains and ships
local ship_item = data.raw["item-with-entity-data"]["cargo_ship"] or data.raw["item-with-entity-data"]["locomotive"]
if ship_item then
  data:extend{{
    type = "shortcut",
    name = "ff-routes-panel",
    order = "z[ff]-c",
    action = "lua",
    toggleable = true,
    icons = icons_of(ship_item),
    small_icons = icons_of(ship_item),
  }}
end
