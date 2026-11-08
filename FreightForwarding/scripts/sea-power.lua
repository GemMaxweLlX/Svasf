-- Sea power: offshore wind turbines follow the wind of their surface (a slow random walk between 20% and 100%),
-- tidal generators follow the tide (a 20 minute cycle, 10% at low tide). Updated every 10 seconds.

local WIND_TURBINE = "ff-offshore-wind-turbine"
local TIDAL = "ff-tidal-generator"
local POWER = {[WIND_TURBINE] = 1000000, [TIDAL] = 600000}  -- W at full output
local TIDE_PERIOD = 20 * 60 * 60

local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid and POWER[entity.name]) then return end
  storage.ff_sea_power = storage.ff_sea_power or {}
  storage.ff_sea_power[entity.unit_number] = entity
  entity.power_production = 0
end

local function wind_of(surface)
  storage.ff_wind = storage.ff_wind or {}
  local wind = storage.ff_wind[surface.index] or 0.6
  wind = math.max(0.2, math.min(1, wind + (math.random() - 0.5) * 0.2))
  storage.ff_wind[surface.index] = wind
  return wind
end

local function tide()
  return 0.1 + 0.9 * (0.5 + 0.5 * math.sin(2 * math.pi * game.tick / TIDE_PERIOD))
end

local function update()
  local generators = storage.ff_sea_power
  if not generators then return end
  local winds = {}
  local tide_now = tide()
  for unit_number, entity in pairs(generators) do
    if not entity.valid then
      generators[unit_number] = nil
    else
      local factor
      if entity.name == WIND_TURBINE then
        local index = entity.surface.index
        winds[index] = winds[index] or wind_of(entity.surface)
        factor = winds[index]
      else
        factor = tide_now
      end
      entity.power_production = POWER[entity.name] * factor / 60  -- J per tick
    end
  end
end

---@type ScriptLib
local SeaPower = {}

SeaPower.events = {
  [defines.events.on_built_entity] = on_built,
  [defines.events.on_robot_built_entity] = on_built,
  [defines.events.script_raised_built] = on_built,
  [defines.events.script_raised_revive] = on_built,
  [defines.events.on_space_platform_built_entity] = on_built,
}

SeaPower.on_nth_tick = {
  [600] = update,
}

SeaPower.add_remote_interface = function()
  remote.add_interface("ff-sea-power", {
    wind = function(surface_index) return (storage.ff_wind or {})[surface_index] end,
    tide = tide,
  })
end

return SeaPower
