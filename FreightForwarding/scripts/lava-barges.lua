-- Space Age: ships on lava burn unless they are lava barges (heat-shielded, see prototypes/ship-tiers.lua).
-- Checked once a second on surfaces that have lava.

local DAMAGE_PER_SECOND = 300
local BARGES = {["ff-lava-barge"] = true, ["ff-lava-barge-engine"] = true}

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

local function on_second()
  local surface = game.surfaces["vulcanus"]
  if not surface then return end
  local names = get_ship_names()
  if #names == 0 then return end
  for _, ship in pairs(surface.find_entities_filtered{name = names}) do
    local tile = surface.get_tile(ship.position.x, ship.position.y)
    if tile.valid and tile.prototype.collision_mask.layers.lava_tile then
      ship.damage(DAMAGE_PER_SECOND, "neutral", "fire")
    end
  end
end

---@type ScriptLib
local LavaBarges = {}

LavaBarges.on_nth_tick = {
  [60] = function()
    if script.active_mods["space-age"] then on_second() end
  end,
}

return LavaBarges
