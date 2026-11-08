-- Space Age: icebreakers turn the ice around them into brash ice, on which waterways can be built.
-- Twice a second, around every icebreaker on Aquilo.

local ICEBREAKERS = {"ff-icebreaker", "ff-icebreaker-engine"}
local RADIUS = 7
local ICE_TILES = {"ice-smooth", "ice-rough"}

local function break_ice()
  local surface = game.surfaces["aquilo"]
  if not (surface and prototypes.entity["ff-icebreaker"] and prototypes.tile["brash-ice"]) then return end
  for _, ship in pairs(surface.find_entities_filtered{name = ICEBREAKERS}) do
    local ice = surface.find_tiles_filtered{position = ship.position, radius = RADIUS, name = ICE_TILES}
    if #ice > 0 then
      local tiles = {}
      for i, tile in pairs(ice) do
        tiles[i] = {name = "brash-ice", position = tile.position}
      end
      surface.set_tiles(tiles, true, "abort_on_collision")
    end
  end
end

---@type ScriptLib
local Icebreaker = {}

Icebreaker.on_nth_tick = {
  [30] = function()
    if script.active_mods["space-age"] then break_ice() end
  end,
}

return Icebreaker
