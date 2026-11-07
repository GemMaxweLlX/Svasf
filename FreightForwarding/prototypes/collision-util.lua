-- Collision mask helpers for Factorio 2.x.
-- In 2.x a collision mask is `{layers = {name = true, ...}, ...}` and custom layers are
-- `collision-layer` prototypes (1.1 used numbered "layer-N" strings from get_first_unused_layer()).

local collision_mask_util = require("__core__.lualib.collision-mask-util")

local C = {}

-- 1.1 layer name -> 2.x layer name
C.legacy_layer_names = {
  ["ground-tile"] = "ground_tile",
  ["water-tile"] = "water_tile",
  ["resource-layer"] = "resource",
  ["doodad-layer"] = "doodad",
  ["floor-layer"] = "floor",
  ["rail-layer"] = "rail",
  ["transport-belt-layer"] = "transport_belt",
  ["item-layer"] = "item",
  ["ghost-layer"] = "ghost",
  ["object-layer"] = "object",
  ["player-layer"] = "player",
  ["train-layer"] = "train",
}

--- Defines (once) a custom collision layer and returns its name.
function C.layer(name)
  if not (data.raw["collision-layer"] and data.raw["collision-layer"][name]) then
    data:extend{{ type = "collision-layer", name = name }}
  end
  return name
end

--- Builds a 2.x mask from a list of (1.1 or 2.x) layer names.
function C.mask(layers)
  local mask = { layers = {} }
  for _, layer in pairs(layers) do
    mask.layers[C.legacy_layer_names[layer] or layer] = true
  end
  return mask
end

--- Returns a copy of the prototype's effective collision mask.
function C.get_mask(prototype)
  local mask = prototype.collision_mask
  if not mask then
    mask = collision_mask_util.get_default_mask(prototype.type)
  end
  mask = table.deepcopy(mask)
  mask.layers = mask.layers or {}
  return mask
end

function C.has_layer(prototype, layer)
  return C.get_mask(prototype).layers[layer] == true
end

function C.add_layer(prototype, layer)
  local mask = C.get_mask(prototype)
  mask.layers[layer] = true
  prototype.collision_mask = mask
end

function C.remove_layer(prototype, layer)
  local mask = C.get_mask(prototype)
  mask.layers[layer] = nil
  prototype.collision_mask = mask
end

--- Same as add_layer for other mask-typed fields (e.g. offshore pump `center_collision_mask`).
function C.add_layer_to_field(prototype, field, layer)
  local mask = table.deepcopy(prototype[field] or { layers = {} })
  mask.layers = mask.layers or {}
  mask.layers[layer] = true
  prototype[field] = mask
end

return C
