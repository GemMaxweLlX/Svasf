-- Mining Space Industries II (MSI). FF loads after MSI ("? Mining-Space-Industries-II" in info.json).
--   * Rocket silo: with MSI the silo stands on the site found in MSI's mission (without Space Age), so FF's rocket silo
--     holes are off (prototypes/rocket-silo.lua, compatibility/rocket-silo-construction) - as in FF 1.x.
--   * Landfill: MSI makes it a red-science starting technology. On FF islands landfill is a big shortcut past ships,
--     so FF's requirement (logistic science) is restored. MSI's own missions are placed on land and need no landfill.

if not mods["Mining-Space-Industries-II"] then return end

local util = require("__FreightForwarding__.prototypes.data-util")

local landfill = data.raw.technology["landfill"]
if landfill and landfill.unit and data.raw.technology["logistic-science-pack"] then
  if not util.contains_research_ingredient("landfill", "logistic-science-pack") then
    util.add_research_ingredient("landfill", "logistic-science-pack")
  end
  util.add_prerequisite("landfill", "logistic-science-pack")
end
