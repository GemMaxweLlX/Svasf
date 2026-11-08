-- Classic mode with Space Age: Freight Forwarding as in 1.x on Nauvis.
-- Space Age rewrites the rocket part recipe and the rocket silo technology in its data-updates, so the original
-- FF changes are re-applied here (FF's data-updates run after Space Age's).
-- Other planets are left as in vanilla Space Age; rocket silos can be built anywhere there
-- (on Nauvis only in rocket silo holes, scripts/rocket-silo.lua).

if not (mods["space-age"] and settings.startup["ff-classic-mode"].value) then return end

local util = require("__FreightForwarding__.prototypes.data-util")

-- Rocket parts: titansteel rocket frame instead of low density structure, plus a charged battery pack
-- (1.x: rocket control units needed battery packs). Space Age parts are 1/10 of a base-game part.
util.replace_ingredient("rocket-part", "low-density-structure", "ff-rocket-frame")
util.add_ingredient("rocket-part", "ff-charged-battery-pack", 1)

util.add_unlock("rocket-silo", "ff-rocket-frame")
util.add_prerequisite("rocket-silo", "ff-titansteel-processing")
util.add_prerequisite("rocket-silo", "ff-battery-pack")
