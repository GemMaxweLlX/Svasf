-- Intermodal Containers machines rebalanced for FF
local util = require "__FreightForwarding__.prototypes.data-util"

local IC_PREFIX = "ic-containerization-"

local function set_tech(name, prerequisites, count)
  local technology = data.raw.technology[name]
  if not technology then return end
  local existing = {}
  for _, prerequisite in pairs(prerequisites) do
    if data.raw.technology[prerequisite] then existing[#existing + 1] = prerequisite end
  end
  technology.prerequisites = existing
  if technology.unit then technology.unit.count = count end
end

util.set_ingredients(IC_PREFIX .. "machine-1", {
  {"engine-unit", 2},
  {"fast-inserter", 4},
  {"steel-plate", 5},
})
-- Original: {"automation", "stack-inserter"}
set_tech(IC_PREFIX .. "1", {"engine", "fast-inserter"}, 100)

util.set_ingredients(IC_PREFIX .. "machine-2", {
  {IC_PREFIX .. "machine-1", 1},
  {"electric-engine-unit", 2},
  {"bulk-inserter", 2},  -- 1.1 "stack-inserter"
  {"steel-plate", 20},
})
-- Original: {"automation-2", IC_PREFIX.."1"},
set_tech(IC_PREFIX .. "2", {"electric-engine", "bulk-inserter", IC_PREFIX .. "1"}, 200)

util.set_ingredients(IC_PREFIX .. "machine-3", {
  {IC_PREFIX .. "machine-2", 1},
  {"electric-engine-unit", 8},
  {"advanced-circuit", 8},
  {"steel-plate", 30},
})
-- Original: {"automation-3", IC_PREFIX.."2"}
set_tech(IC_PREFIX .. "3", {"automation-3", IC_PREFIX .. "2"}, 300)
