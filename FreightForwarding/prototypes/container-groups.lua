-- Recipe tabs for containers: one packing tab and one unpacking tab per container kind (normal, refrigerated,
-- light, cryo). Filled containers of every kind go to Intermodal Containers' container tab. Runs in data-final-fixes,
-- after container-tiers.lua.

local load_group = data.raw["item-group"]["ic-load-container"]
local unload_group = data.raw["item-group"]["ic-unload-container"]
if not (load_group and unload_group) then return end

local FAMILIES = {
  {prefix = "ff-reefer-", tint = {r = 0.55, g = 0.85, b = 1, a = 1}, order = "b"},
  {prefix = "ff-light-", tint = {r = 0.8, g = 0.85, b = 0.95, a = 1}, order = "c"},
  {prefix = "ff-cryo-", tint = {r = 0.6, g = 1, b = 1, a = 1}, order = "d"},
}

local function group_icons(base, tint)
  local icons = table.deepcopy(base.icons)
  if icons[2] then icons[2].tint = tint end  -- the coloured mask layer of IC's group icon
  return icons
end

for _, family in pairs(FAMILIES) do
  local containers = data.raw["item-subgroup"][family.prefix .. "containers"]
  local load = data.raw["item-subgroup"][family.prefix .. "load"]
  local unload = data.raw["item-subgroup"][family.prefix .. "unload"]
  if containers and load and unload then
    local load_name = family.prefix .. "load-group"
    local unload_name = family.prefix .. "unload-group"
    data:extend{
      {
        type = "item-group",
        name = load_name,
        localised_name = {"item-group-name." .. load_name},
        order = (load_group.order or "y-1") .. family.order,
        icons = group_icons(load_group, family.tint),
      },
      {
        type = "item-group",
        name = unload_name,
        localised_name = {"item-group-name." .. unload_name},
        order = (unload_group.order or "y-2") .. family.order,
        icons = group_icons(unload_group, family.tint),
      },
    }
    load.group = load_name
    unload.group = unload_name
    if data.raw["item-group"]["ic-containers"] then
      containers.group = "ic-containers"
      containers.order = "0-" .. family.order
    end
  end
end
