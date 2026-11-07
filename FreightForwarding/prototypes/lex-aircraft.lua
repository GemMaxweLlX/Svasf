if not mods["lex-aircraft"] then return end

local util = require "__FreightForwarding__.prototypes.data-util"
local bzutil = require "__FreightForwarding__.prototypes.data-util"

-- Hide light gunship
util.hide_technology("lex-flying-gunship-ships")
for _, prototype in pairs{
  data.raw.recipe["lex-flying-gunship"],
  data.raw["item-with-entity-data"]["lex-flying-gunship"],
  data.raw["spider-vehicle"]["lex-flying-gunship"],
} do
  prototype.hidden = true
end
util.remove_prerequisite("lex-flying-heavyship-ships", "lex-flying-gunship-ships")

-- Doesn't have any effect anyway because automatic_weapon_cycling = false, so remove from tooltip
data.raw["spider-vehicle"]["lex-flying-heavyship"].chain_shooting_cooldown_modifier = 1

-- Adjust locale
data.raw["spider-vehicle"]["lex-flying-cargo"].localised_description = {""}
data.raw["spider-vehicle"]["lex-flying-heavyship"].localised_description = {""}

-- Move lex aicraft to lategame
util.add_prerequisite("lex-jet-engine", "hcraft-tech")
util.add_prerequisite("lex-jet-engine", "utility-science-pack")
util.add_prerequisite("lex-jet-engine", "production-science-pack")
util.remove_prerequisite("lex-jet-engine", "automobilism")
util.remove_prerequisite("lex-jet-engine", "robotics")

util.add_research_ingredient("lex-jet-engine", "utility-science-pack")
util.add_research_ingredient("lex-jet-engine", "production-science-pack")
data.raw.technology["lex-jet-engine"].unit.count = 500  -- 350

--util.add_research_ingredient("lex-flying-gunship-ships", "utility-science-pack")
--data.raw.technology["lex-flying-gunship-ships"].unit.count = 1000  -- 500
--util.add_prerequisite("lex-flying-gunship-ships", "mcraft-tech")

util.add_research_ingredient("lex-flying-cargo-ships", "utility-science-pack")
util.add_research_ingredient("lex-flying-cargo-ships", "production-science-pack")
data.raw.technology["lex-flying-cargo-ships"].unit.count = 1500  -- 500
util.add_prerequisite("lex-flying-cargo-ships", "sp-spidertron-automation")

util.add_prerequisite("lex-flying-heavyship-ships", "mcraft-tech")
util.add_prerequisite("lex-flying-heavyship-ships", "lex-jet-engine")
util.remove_prerequisite("lex-flying-heavyship-ships", "lex-flying-cargo-ships")
bzutil.remove_recipe_effect("lex-flying-heavyship-ships", "spidertron-remote")

-- Make spidertron slightly earlier since it is weaker than lex heavy ship
util.remove_prerequisite("efficiency-module-3", "production-science-pack")
util.remove_research_ingredient("efficiency-module-3", "production-science-pack")
util.remove_research_ingredient("spidertron", "production-science-pack")