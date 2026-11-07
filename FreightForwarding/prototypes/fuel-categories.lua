local util = require "__FreightForwarding__.prototypes.data-util"

-- Everything that can burn chemical fuel can also burn "advanced-chemical" (rocket fuel, nuclear fuel),
-- except locomotives (batteries) and entities marked with `ff_no_advanced_fuel`.
local entity_types = {"assembling-machine", "beacon", "boiler", "burner-generator", "car", "spider-vehicle", "furnace", "inserter", "lab", "locomotive", "mining-drill", "reactor", "generator-equipment", "agricultural-tower", "asteroid-collector", "fusion-generator"}

for _, type in pairs(entity_types) do
  for _, prototype in pairs(data.raw[type] or {}) do
    if not prototype.ff_no_advanced_fuel then
      local energy_source = prototype.burner or prototype.energy_source
      if energy_source and energy_source.type == "burner" then
        if energy_source.fuel_category then  -- 1.1 style
          energy_source.fuel_categories = {energy_source.fuel_category}
          energy_source.fuel_category = nil
        end
        -- 2.x default is {"chemical"}
        energy_source.fuel_categories = energy_source.fuel_categories or {"chemical"}
        if util.contains(energy_source.fuel_categories, "chemical")
            and not util.contains(energy_source.fuel_categories, "advanced-chemical") then
          table.insert(energy_source.fuel_categories, "advanced-chemical")
        end
      end
    end
  end
end
