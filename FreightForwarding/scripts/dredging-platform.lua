-- Dredger: the dredging platform item places a mining drill that only fits on a seamount (or a cobalt vent on
-- Vulcanus). It is replaced here by the dredger (assembling machine), a hidden pole and radar, and a concrete
-- platform. Mining the dredger gives the platform back and restores the seamount/vent and the original tiles.

local RESOURCES = {"ff-seamount", "ff-cobalt-vent"}

local function add_square(x, y, tiles)
  for i = 0, 1 do
    for j = 0, 1 do
      table.insert(tiles, {name = "ff-dredging-platform", position = {x + i, y + j}})
    end
  end
end

local function platform_tiles(position)
  local x = position.x
  local y = position.y
  local tiles = {}
  for i = -9, 8 do
    for j = -9, 8 do
      table.insert(tiles, {name = "ff-dredging-platform", position = {x + i, y + j}})
    end
  end
  -- Add 'piers'
  for _, i in pairs({-9, -1, 7}) do
    for _, j in pairs({-11, 9}) do
      add_square(x + i, y + j, tiles)
      add_square(x + j, y + i, tiles)
    end
  end
  return tiles
end

local function on_dredger_created(event)
  if event.effect_id ~= "ff-dredger-created" then return end

  local dredger = event.target_entity
  local force = dredger.force
  local surface = dredger.surface
  local position = dredger.position
  dredger.destroy()

  local resource_name
  for _, name in pairs(RESOURCES) do
    if prototypes.entity[name] then
      local resource = surface.find_entity(name, position)
      if resource then
        resource_name = name
        resource.destroy()
      end
    end
  end

  local created = surface.create_entity{
    name = "ff-dredger",
    position = position,
    force = force,
    create_build_effect_smoke = false,
  }
  created.destructible = false

  local pole = surface.create_entity{
    name = "ff-dredger-pole",
    position = position,
    force = force,
    create_build_effect_smoke = false,
  }
  pole.destructible = false

  local radar = surface.create_entity{
    name = "ff-dredger-radar",
    position = position,
    force = force,
    create_build_effect_smoke = false,
  }
  radar.destructible = false

  local tiles = platform_tiles(position)
  -- Remember what was there, so that it can be restored when the dredger is removed
  local original = {}
  for _, tile in pairs(tiles) do
    local t = surface.get_tile(tile.position[1], tile.position[2])
    if t.name ~= "ff-dredging-platform" then
      original[#original + 1] = {name = t.name, position = tile.position}
    end
  end
  storage.dredgers = storage.dredgers or {}
  storage.dredgers[created.unit_number] = {resource = resource_name or "ff-seamount", tiles = original}

  surface.set_tiles(tiles, true, false)
end

local function on_dredger_removed(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == "ff-dredger") then return end
  local surface = entity.surface
  local position = entity.position
  storage.dredgers = storage.dredgers or {}
  local record = storage.dredgers[entity.unit_number]
  storage.dredgers[entity.unit_number] = nil

  for _, name in pairs{"ff-dredger-pole", "ff-dredger-radar"} do
    for _, helper in pairs(surface.find_entities_filtered{name = name, position = position, radius = 0.5}) do
      helper.destroy()
    end
  end

  -- Restore tiles (dredgers built before this was tracked get the planet's default liquid)
  local tiles = record and record.tiles
  if not tiles then
    local fallback = surface.name == "vulcanus" and "lava" or "deepwater"
    if not prototypes.tile[fallback] then fallback = "deepwater" end
    tiles = {}
    for _, tile in pairs(platform_tiles(position)) do
      tiles[#tiles + 1] = {name = fallback, position = tile.position}
    end
  end
  surface.set_tiles(tiles, true, false)

  local resource = record and record.resource or (surface.name == "vulcanus" and "ff-cobalt-vent" or "ff-seamount")
  if prototypes.entity[resource] then
    surface.create_entity{name = resource, position = position, amount = 1}
  end
end

---@type ScriptLib
local DredgingPlatform = {}

DredgingPlatform.events = {
  [defines.events.on_script_trigger_effect] = on_dredger_created,
  [defines.events.on_player_mined_entity] = on_dredger_removed,
  [defines.events.on_robot_mined_entity] = on_dredger_removed,
  [defines.events.script_raised_destroy] = on_dredger_removed,
}

return DredgingPlatform
