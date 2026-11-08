-- Space Age: what the seas of other planets do to ships. Ships are found through the train manager (Cargo Ships'
-- ships are trains), which is much cheaper than searching whole surfaces.
--   Vulcanus: ships on lava burn, except lava barges (heat-shielded)
--   Gleba:    ships crawl through wetlands, except swamp barges (flat-bottomed)
--   Aquilo:   icebreakers turn the ice around them into brash ice, on which waterways can be built
--   Fulgora:  at night lightning storms sweep the oil sea: ships go at half speed, and moving ships can be struck by
--             lightning unless a lightning rod or collector is near

local LAVA_DAMAGE = 300  -- per second
local LAVA_BARGES = {["ff-lava-barge"] = true, ["ff-lava-barge-engine"] = true}
local SWAMP_BARGES = {["ff-swamp-barge"] = true, ["ff-swamp-barge-engine"] = true}
local ICEBREAKERS = {["ff-icebreaker"] = true, ["ff-icebreaker-engine"] = true}
local ICE_RADIUS = 7
local ICE_TILES = {"ice-smooth", "ice-rough"}
local STORM_DARKNESS = 0.6
local STORM_SPEED = 0.5
local STRIKE_CHANCE = 0.03  -- per moving ship carriage and second
local STRIKE_DAMAGE = 150
local ROD_RADIUS = 25

local ship_names
local function is_ship(name)
  if not ship_names then
    ship_names = {}
    for _, entry in pairs(prototypes.mod_data) do
      if entry.data_type == "cargo-ships.ship-definition" then
        for _, n in pairs{entry.data.name, entry.data.engine} do
          if n then ship_names[n] = true end
        end
      end
    end
  end
  return ship_names[name]
end

--- Ship trains on a surface, with their carriages
local function ship_trains(surface)
  local result = {}
  if not surface then return result end
  for _, train in pairs(game.train_manager.get_trains{surface = surface}) do
    local carriages = train.carriages
    if carriages[1] and is_ship(carriages[1].name) then
      result[#result + 1] = {train = train, carriages = carriages}
    end
  end
  return result
end

local function has_any(carriages, names)
  for _, carriage in pairs(carriages) do
    if names[carriage.name] then return true end
  end
  return false
end

local function cap_speed(train, factor)
  local limit = train.max_forward_speed * factor
  if train.speed > limit then train.speed = limit
  elseif train.speed < -limit then train.speed = -limit end
end

---------------------------------------------------------------------------------------------------

local function gleba_wetlands()
  local surface = game.surfaces["gleba"]
  if not surface then return end
  local factor = settings.startup["ff-swamp-ship-speed"].value
  for _, ship in pairs(ship_trains(surface)) do
    if not has_any(ship.carriages, SWAMP_BARGES) then
      local front = ship.train.front_stock
      local tile = front and surface.get_tile(front.position.x, front.position.y)
      if tile and tile.valid and tile.name:sub(1, 8) == "wetland-" then cap_speed(ship.train, factor) end
    end
  end
end

local function storm_active(surface)
  return surface and surface.darkness > STORM_DARKNESS
end

local function fulgora_storm_speed()
  local surface = game.surfaces["fulgora"]
  if not storm_active(surface) then return end
  for _, ship in pairs(ship_trains(surface)) do cap_speed(ship.train, STORM_SPEED) end
end

local function fulgora_storm_strikes()
  local surface = game.surfaces["fulgora"]
  if not surface then return end
  local active = storm_active(surface)
  storage.ff_fulgora_storm = storage.ff_fulgora_storm or false
  if active ~= storage.ff_fulgora_storm then
    storage.ff_fulgora_storm = active
    for _, player in pairs(game.connected_players) do
      if player.surface == surface then player.print({active and "ff-hazard.storm-start" or "ff-hazard.storm-end"}) end
    end
  end
  if not active then return end
  for _, ship in pairs(ship_trains(surface)) do
    if ship.train.speed ~= 0 then
      for _, carriage in pairs(ship.carriages) do
        if math.random() < STRIKE_CHANCE then
          local protected = surface.count_entities_filtered{type = "lightning-attractor", position = carriage.position,
                                                            radius = ROD_RADIUS, limit = 1} > 0
          if not protected then
            carriage.damage(STRIKE_DAMAGE, "neutral", "electric")
            if not carriage.valid then break end
          end
        end
      end
    end
  end
end

local function vulcanus_lava()
  local surface = game.surfaces["vulcanus"]
  if not surface then return end
  for _, ship in pairs(ship_trains(surface)) do
    for _, carriage in pairs(ship.carriages) do
      if carriage.valid and not LAVA_BARGES[carriage.name] then
        local tile = surface.get_tile(carriage.position.x, carriage.position.y)
        if tile.valid and tile.prototype.collision_mask.layers.lava_tile then
          carriage.damage(LAVA_DAMAGE, "neutral", "fire")
        end
      end
    end
  end
end

local function aquilo_ice()
  local surface = game.surfaces["aquilo"]
  if not (surface and prototypes.tile["brash-ice"]) then return end
  for _, ship in pairs(ship_trains(surface)) do
    for _, carriage in pairs(ship.carriages) do
      if ICEBREAKERS[carriage.name] then
        local ice = surface.find_tiles_filtered{position = carriage.position, radius = ICE_RADIUS, name = ICE_TILES}
        if #ice > 0 then
          local tiles = {}
          for i, tile in pairs(ice) do tiles[i] = {name = "brash-ice", position = tile.position} end
          surface.set_tiles(tiles, true, "abort_on_collision")
        end
      end
    end
  end
end

---@type ScriptLib
local ShipHazards = {}

ShipHazards.on_nth_tick = {
  [10] = function()
    if not script.active_mods["space-age"] then return end
    gleba_wetlands()
    fulgora_storm_speed()
  end,
  [30] = function()
    if script.active_mods["space-age"] then aquilo_ice() end
  end,
  [60] = function()
    if not script.active_mods["space-age"] then return end
    vulcanus_lava()
    fulgora_storm_strikes()
  end,
}

return ShipHazards
