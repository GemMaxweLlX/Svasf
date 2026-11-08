-- Space Age: icons of tiered things get the tier number in the top right corner and the planet where they are made
-- in the bottom left corner. Runs last in data-final-fixes.

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end

local PLANET_ICONS = {}
for _, planet in pairs{"nauvis", "vulcanus", "fulgora", "gleba", "aquilo"} do
  local p = data.raw.planet[planet]
  if p and p.icon then PLANET_ICONS[planet] = {icon = p.icon, icon_size = p.icon_size or 64} end
end

local function badge_icons(icons, tier, planet)
  icons = table.deepcopy(icons)
  local base_size = icons[1] and icons[1].icon_size or 64
  local k = 64 / base_size  -- badges are drawn relative to a 64 px icon
  if tier then
    table.insert(icons, {icon = "__base__/graphics/icons/signal/signal_" .. tier .. ".png", icon_size = 64,
                         scale = 0.25 * k * (base_size / 64), shift = {9, -9}, floating = true})
  end
  if planet and PLANET_ICONS[planet] then
    table.insert(icons, {icon = PLANET_ICONS[planet].icon, icon_size = PLANET_ICONS[planet].icon_size,
                         scale = 0.2, shift = {-9, 9}, floating = true})
  end
  return icons
end

local function apply(prototype, tier, planet)
  if not prototype then return end
  local icons = prototype.icons or (prototype.icon and {{icon = prototype.icon, icon_size = prototype.icon_size or 64}})
  if not icons then return end
  prototype.icons = badge_icons(icons, tier, planet)
  prototype.icon = nil
end

local ITEM_TYPES = {"item", "item-with-entity-data", "tool", "capsule", "rail-planner"}
local function apply_everywhere(name, tier, planet)
  for _, type in pairs(ITEM_TYPES) do apply(data.raw[type] and data.raw[type][name], tier, planet) end
  for type, prototypes in pairs(data.raw) do
    if type ~= "recipe" and type ~= "technology" and prototypes[name] and prototypes[name].collision_box then
      apply(prototypes[name], tier, planet)
    end
  end
end

local BADGES = {
  -- ships
  ["ff-fast-cargo-ship"] = {2, "vulcanus"}, ["ff-heavy-cargo-ship"] = {3, "aquilo"},
  ["ff-lava-barge"] = {nil, "vulcanus"}, ["ff-swamp-barge"] = {nil, "gleba"}, ["ff-icebreaker"] = {nil, "aquilo"},
  -- trains
  ["ff-locomotive-mk2"] = {2, "fulgora"}, ["ff-locomotive-mk3"] = {3, "aquilo"},
  ["ff-cargo-wagon-mk2"] = {2, "vulcanus"}, ["ff-fluid-wagon-mk2"] = {2, "vulcanus"},
  -- dredgers
  ["ff-dredging-platform"] = {1}, ["ff-dredger"] = {1},
  ["ff-dredging-platform-mk2"] = {2, "vulcanus"}, ["ff-dredger-mk2"] = {2, "vulcanus"},
  ["ff-dredging-platform-mk3"] = {3, "aquilo"}, ["ff-dredger-mk3"] = {3, "aquilo"},
  -- rocket silos
  ["ff-light-rocket-silo"] = {1}, ["rocket-silo"] = {2}, ["ff-heavy-rocket-silo"] = {3, "aquilo"},
  -- battery fuel
  ["ff-battery"] = {1}, ["ff-charged-battery"] = {1},
  ["ff-battery-pack"] = {2, "fulgora"}, ["ff-charged-battery-pack"] = {2, "fulgora"},
  ["ff-lithium-battery-pack"] = {3, "aquilo"}, ["ff-charged-lithium-battery-pack"] = {3, "aquilo"},
  -- machines
  ["ff-seismic-scanner-2"] = {2, "aquilo"}, ["ff-sonar-buoy-2"] = {2, "aquilo"},
  ["ff-fast-charging-station"] = {2, "fulgora"}, ["ic-containerization-machine-4"] = {4, "fulgora"},
  -- empty containers
  ["ic-container"] = {1}, ["ff-reefer-container"] = {2, "gleba"},
  ["ff-light-container"] = {3, "vulcanus"}, ["ff-cryo-container"] = {4, "aquilo"},
}
for name, badge in pairs(BADGES) do apply_everywhere(name, badge[1], badge[2]) end

-- Filled, spoiled and damaged containers get their container's tier
local CONTAINER_PREFIXES = {
  {"ic-container-", 1}, {"ff-reefer-", 2, "gleba"}, {"ff-light-", 3, "vulcanus"}, {"ff-cryo-", 4, "aquilo"},
}
for name, item in pairs(data.raw.item) do
  if not BADGES[name] then
    for _, entry in pairs(CONTAINER_PREFIXES) do
      local is_ic = entry[1] == "ic-container-"
      local member = is_ic and name:sub(1, #entry[1]) == entry[1]
        or (not is_ic and item.subgroup == entry[1] .. "containers")
        or name == "ff-damaged-" .. (is_ic and "ic-container" or entry[1] .. "container")
      if member then
        apply(item, entry[2], entry[3])
        break
      end
    end
  end
end
