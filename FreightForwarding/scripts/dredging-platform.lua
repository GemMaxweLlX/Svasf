-- Dredger: the dredging platform item places a mining drill that only fits on a seamount (or a cobalt vent on
-- Vulcanus). It is replaced here by the dredger (assembling machine), a hidden pole and radar, and a concrete
-- platform. Mining the dredger gives the platform back and restores the seamount/vent and the original tiles.

local RESOURCES = {"ff-seamount", "ff-cobalt-vent", "ff-scrap-seamount"}
-- placer (mining drill placed by the item) -> dredger (assembling machine); Mk2/Mk3 are bigger (prototypes/dredger-tiers.lua)
local DREDGERS = {
  ["ff-dredging-platform"] = "ff-dredger",
  ["ff-dredging-platform-mk2"] = "ff-dredger-mk2",
  ["ff-dredging-platform-mk3"] = "ff-dredger-mk3",
}
local IS_DREDGER = {}
for _, name in pairs(DREDGERS) do IS_DREDGER[name] = true end
-- Half the width of the square platform: 18x18, Mk2 24x24, Mk3 30x30
local PLATFORM_HALF = {["ff-dredger"] = 9, ["ff-dredger-mk2"] = 12, ["ff-dredger-mk3"] = 15}
-- The platform is not laid where it would cut a waterway/railway or strand a ship/train
local KEEP_CLEAR = {
  "straight-rail", "half-diagonal-rail", "curved-rail-a", "curved-rail-b", "legacy-straight-rail", "legacy-curved-rail",
  "rail-signal", "rail-chain-signal", "train-stop", "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon",
}

local function add_square(x, y, tiles)
  for i = 0, 1 do
    for j = 0, 1 do
      table.insert(tiles, {name = "ff-dredging-platform", position = {x + i, y + j}})
    end
  end
end

local function platform_tiles(position, half)
  half = half or 9
  local x = position.x
  local y = position.y
  local tiles = {}
  for i = -half, half - 1 do
    for j = -half, half - 1 do
      table.insert(tiles, {name = "ff-dredging-platform", position = {x + i, y + j}})
    end
  end
  -- Add 'piers'
  for _, i in pairs({-half, -1, half - 2}) do
    for _, j in pairs({-half - 2, half}) do
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
  local dredger_name = DREDGERS[dredger.name] or "ff-dredger"
  local quality = dredger.quality  -- a quality dredger works faster (crafting speed)
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
    name = dredger_name,
    position = position,
    force = force,
    quality = quality,
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

  local tiles = {}
  -- Remember what was there, so that it can be restored when the dredger is removed
  local original = {}
  for _, tile in pairs(platform_tiles(position, PLATFORM_HALF[dredger_name])) do
    local tx, ty = tile.position[1], tile.position[2]
    local clear = surface.count_entities_filtered{area = {{tx, ty}, {tx + 1, ty + 1}}, type = KEEP_CLEAR, limit = 1} == 0
    if clear then
      tiles[#tiles + 1] = tile
      local t = surface.get_tile(tx, ty)
      if t.name ~= "ff-dredging-platform" then
        original[#original + 1] = {name = t.name, position = tile.position}
      end
    end
  end
  storage.dredgers = storage.dredgers or {}
  storage.dredgers[created.unit_number] = {resource = resource_name or "ff-seamount", tiles = original}

  surface.set_tiles(tiles, true, false)
end

local function on_dredger_removed(event)
  local entity = event.entity
  if not (entity and entity.valid and IS_DREDGER[entity.name]) then return end
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
    for _, tile in pairs(platform_tiles(position, PLATFORM_HALF[entity.name])) do
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
