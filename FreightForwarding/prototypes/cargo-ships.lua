local util = require "__FreightForwarding__.prototypes.data-util"

local or_pole = data.raw["electric-pole"]["or_pole"]
if or_pole then
  or_pole.supply_area_distance = 12.5  -- 4.5
end

-- Floating electric poles are replaced by FF's underwater/offshore logistics
for _, prototype in pairs{
  data.raw["electric-pole"]["floating-electric-pole"],
  data.raw["item"]["floating-electric-pole"],
  data.raw["recipe"]["floating-electric-pole"],
} do
  prototype.hidden = true
end
util.hide_technology("oversea-energy-distribution")

local boat = data.raw["car"]["indep-boat"]
if boat and boat.friction then
  boat.friction = boat.friction * 0.75
end
