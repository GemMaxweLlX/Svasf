-- Space Age: ships wade through the wetlands of Gleba slowly (40% speed by default), unless they are swamp barges (flat-bottomed,
-- see prototypes/ship-tiers.lua). Checked 6 times a second on Gleba.

local SPEED_FACTOR = settings.startup["ff-swamp-ship-speed"].value
local BARGES = {["ff-swamp-barge"] = true, ["ff-swamp-barge-engine"] = true}

local ship_names
local function get_ship_names()
  if ship_names then return ship_names end
  ship_names = {}
  for _, entry in pairs(prototypes.mod_data) do
    if entry.data_type == "cargo-ships.ship-definition" then
      local definition = entry.data
      for _, name in pairs{definition.name, definition.engine} do
        if name and prototypes.entity[name] and not BARGES[name] then ship_names[#ship_names + 1] = name end
      end
    end
  end
  return ship_names
end

local function slow_down()
  local surface = game.surfaces["gleba"]
  if not surface then return end
  local names = get_ship_names()
  if #names == 0 then return end
  local done = {}
  for _, ship in pairs(surface.find_entities_filtered{name = names}) do
    local train = ship.train
    if train and not done[train.id] then
      done[train.id] = true
      local tile = surface.get_tile(ship.position.x, ship.position.y)
      if tile.valid and tile.name:sub(1, 8) == "wetland-" then
        local limit = train.max_forward_speed * SPEED_FACTOR
        if train.speed > limit then train.speed = limit
        elseif train.speed < -limit then train.speed = -limit end
      end
    end
  end
end

---@type ScriptLib
local SwampBarges = {}

SwampBarges.on_nth_tick = {
  [10] = function()
    if script.active_mods["space-age"] then slow_down() end
  end,
}

return SwampBarges
