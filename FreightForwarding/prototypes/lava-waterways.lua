-- Space Age: allow Cargo Ships waterways on lava (for lava barges).
-- Space Age keeps everything rail-like off lava through the "rail" layer on lava tiles. Here that layer is replaced
-- by "ff_lava_rail", which is added to every prototype that has the "rail" layer except waterways - so rails,
-- rail supports and ramps still can't be built on lava, but waterways can.
-- Runs in data-final-fixes.

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end
if not data.raw["straight-rail"]["straight-waterway"] then return end

local C = require("__FreightForwarding__.prototypes.collision-util")
local lava_rail_layer = C.layer("ff_lava_rail")

local lava_tiles = {}
for _, tile in pairs(data.raw.tile) do
  local layers = tile.collision_mask and tile.collision_mask.layers
  if layers and layers.lava_tile and layers.rail then
    layers.rail = nil
    layers[lava_rail_layer] = true
    lava_tiles[#lava_tiles + 1] = tile.name
  end
end
if #lava_tiles == 0 then return end

local default_masks = require("__core__.lualib.collision-mask-defaults")

local function is_waterway(name)
  return name:find("waterway", 1, true) ~= nil
end

for ptype, list in pairs(data.raw) do
  if ptype ~= "tile" and default_masks[ptype] ~= nil or ptype == "rail-ramp" or ptype == "rail-support" then
    for name, prototype in pairs(list) do
      if type(prototype) == "table" and not is_waterway(name) then
        local mask = prototype.collision_mask
        if not mask then
          local key = ptype
          if prototype.allow_on_deep_oil_ocean and default_masks[ptype .. "/allow_on_deep_oil_ocean"] then
            key = ptype .. "/allow_on_deep_oil_ocean"
          end
          mask = default_masks[key] and table.deepcopy(default_masks[key])
        end
        if mask and mask.layers and mask.layers.rail then
          mask.layers[lava_rail_layer] = true
          prototype.collision_mask = mask
        end
      end
    end
  end
end
