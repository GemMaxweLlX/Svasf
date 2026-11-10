-- Mining Space Industries II: smaller rocket delivery requests by default (3-6 containers in MSI). Still adjustable.
if not mods["Mining-Space-Industries-II"] then return end
local min = data.raw["int-setting"]["msi_cargo_request_min"]
local max = data.raw["int-setting"]["msi_cargo_request_max"]
if min then min.default_value = 2 end
if max then max.default_value = 4 end
