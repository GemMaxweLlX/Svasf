-- Map tags for rocket silo holes, cobalt vents and big lava pools, added when their chunk is charted.

local TAGGED = {
  ["ff-rocket-silo-hole"] = {icon = {type = "item", name = "rocket-silo"}, text = {"entity-name.ff-rocket-silo-hole"}},
  ["ff-cobalt-vent"] = {icon = {type = "item", name = "ff-cobalt-ore"}, text = {"entity-name.ff-cobalt-vent"}},
  ["ff-lava-pool"] = {icon = {type = "item", name = "ff-titansteel-plate"}, text = {"entity-name.ff-lava-pool"}},
}

local names
local function tagged_names()
  if not names then
    names = {}
    for name in pairs(TAGGED) do
      if prototypes.entity[name] then names[#names + 1] = name end
    end
  end
  return names
end

local function tag_area(surface, force, area)
  local list = tagged_names()
  if #list == 0 then return 0 end
  local entities = surface.find_entities_filtered{name = list, area = area}
  local added = 0
  if #entities == 0 then return 0 end
  storage.ff_map_tags = storage.ff_map_tags or {}
  local done = storage.ff_map_tags
  for _, entity in pairs(entities) do
    local key = force.index .. ":" .. surface.index .. ":" .. entity.position.x .. "," .. entity.position.y
    if not done[key] then
      done[key] = true
      local spec = TAGGED[entity.name]
      local icon = spec.icon
      if not prototypes.item[icon.name] then icon = nil end
      if force.add_chart_tag(surface, {position = entity.position, icon = icon, text = ""}) then
        added = added + 1
      end
    end
  end
  return added
end

local function on_chunk_charted(event)
  if not settings.global["ff-map-tags"].value then return end
  tag_area(game.surfaces[event.surface_index], event.force, event.area)
end

---@type ScriptLib
local MapTags = {}

-- remote.call("FreightForwarding", "add_map_tags", surface_index, force_name, area?) tags an area (default: everything
-- the force has charted on that surface), e.g. after enabling the setting on an existing map.
MapTags.remote_interface_fragment = function()
  return {
    add_map_tags = function(surface_index, force_name, area)
      local surface = game.surfaces[surface_index]
      local force = game.forces[force_name or "player"]
      if not (surface and force) then return 0 end
      if area then return tag_area(surface, force, area) end
      local added = 0
      for chunk in surface.get_chunks() do
        if force.is_chunk_charted(surface, chunk) then
          added = added + tag_area(surface, force, chunk.area)
        end
      end
      return added
    end,
  }
end

MapTags.events = {
  [defines.events.on_chunk_charted] = on_chunk_charted,
}

return MapTags
