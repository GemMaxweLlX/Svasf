-- Dredger planner (extended mode): a selection tool from the shortcut bar. Drag over the sea: ghosts of dredging
-- platforms are placed on every seamount / vent in the area that is on the charted map and where a platform fits
-- (scripts/dredger-planner.lua). Normal selection: the first dredger; alt-selection: the best one researched.
-- It only plans: robots or the player build the ghosts from real items.

if settings.startup["ff-classic-mode"].value then return end
if not data.raw["mining-drill"]["ff-dredging-platform"] then return end

local resources = {}
for _, name in pairs{"ff-seamount", "ff-cobalt-vent", "ff-scrap-seamount"} do
  if data.raw.resource[name] then resources[#resources + 1] = name end
end
local ICON = "__FreightForwarding__/graphics/dredger.png"
local icons = {{icon = ICON, icon_size = 64, tint = {r = 0.55, g = 0.85, b = 1, a = 1}}}

data:extend{
  {
    type = "selection-tool",
    name = "ff-dredger-planner",
    localised_name = {"item-name.ff-dredger-planner"},
    localised_description = {"item-description.ff-dredger-planner"},
    icons = icons,
    flags = {"only-in-cursor", "not-stackable", "spawnable"},
    hidden = true,
    subgroup = "tool",
    order = "z[ff-dredger-planner]",
    stack_size = 1,
    select = {
      border_color = {0.3, 0.75, 1},
      cursor_box_type = "entity",
      mode = {"any-entity"},
      entity_filters = resources,
    },
    alt_select = {
      border_color = {0.3, 1, 0.5},
      cursor_box_type = "entity",
      mode = {"any-entity"},
      entity_filters = resources,
    },
  },
  {
    type = "shortcut",
    name = "ff-dredger-planner",
    order = "z[ff]-d",
    action = "spawn-item",
    item_to_spawn = "ff-dredger-planner",
    technology_to_unlock = "ff-dredging",
    unavailable_until_unlocked = true,
    icons = {{icon = ICON, icon_size = 64}},
    small_icons = {{icon = ICON, icon_size = 64}},
  },
}
