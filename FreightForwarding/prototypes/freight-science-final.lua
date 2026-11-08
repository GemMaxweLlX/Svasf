-- Space Age: technologies researched with cryogenic science also need interplanetary freight science.
-- Runs in data-final-fixes, after every mod has added its technologies.

if not data.raw.technology["ff-freight-science-pack"] then return end

local util = require("__FreightForwarding__.prototypes.data-util")

-- Technologies the freight science technology depends on can't require its pack
local ancestors = {["ff-freight-science-pack"] = true}
local function mark_ancestors(name)
  local technology = data.raw.technology[name]
  for _, prerequisite in pairs(technology and technology.prerequisites or {}) do
    if not ancestors[prerequisite] then
      ancestors[prerequisite] = true
      mark_ancestors(prerequisite)
    end
  end
end
mark_ancestors("ff-freight-science-pack")

for name, technology in pairs(data.raw.technology) do
  if not ancestors[name] and technology.unit
      and util.contains_research_ingredient(name, "cryogenic-science-pack")
      and not util.contains_research_ingredient(name, "ff-freight-science-pack")
      and util.lab_accepts(util.research_packs(name, "ff-freight-science-pack")) then
    table.insert(technology.unit.ingredients, {"ff-freight-science-pack", 1})
    util.add_prerequisite(name, "ff-freight-science-pack")
  end
end
