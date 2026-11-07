if not mods["beautiful_bridge_railway_Cargoships"] then return end

-- Modifications to beautiful_bridge_railway_Cargoships
-- Recipe changes are in data-final-fixes

local C = require "__FreightForwarding__.prototypes.collision-util"
local deep_water_layer = C.layer("ff_deep_water")

-- Prevent bridges being placed on deep water
for _, bridge_type in pairs({"wood", "iron", "brick"}) do
  -- 2.x rail types: straight-rail, curved-rail-a, curved-rail-b, half-diagonal-rail
  for _, rail_type in pairs({"straight-rail", "curved-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail"}) do
    local prototype = data.raw[rail_type] and data.raw[rail_type]["bbr-" .. rail_type .. "-" .. bridge_type]
    if prototype then
      C.add_layer(prototype, deep_water_layer)
      prototype.localised_description = {"item-description.bbr-rail-common"}
    end
  end
end

-- Increase selection priority of vehicles so that they can be selected over bridges
for _, type in pairs({"car", "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon", "spider-vehicle"}) do
  for _, prototype in pairs(data.raw[type] or {}) do
    if not prototype.selection_priority or prototype.selection_priority == 50 then
      prototype.selection_priority = 51
    end
  end
end
