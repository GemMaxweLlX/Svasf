-- Aircraft (Aircraft-space-age, 2.x): planes fly over the sea, so like Lex's aircraft in FF 1.x they come late,
-- once island logistics is established (production and utility science, and the hovercraft if present).
if not mods["Aircraft-space-age"] then return end

local util = require "__FreightForwarding__.prototypes.data-util"

local tech = data.raw.technology["advanced-aerodynamics"]
if tech then
  util.remove_prerequisite("advanced-aerodynamics", "automobilism")
  util.remove_prerequisite("advanced-aerodynamics", "robotics")
  for _, prerequisite in pairs{"production-science-pack", "utility-science-pack", "hcraft-tech"} do
    if data.raw.technology[prerequisite] then util.add_prerequisite("advanced-aerodynamics", prerequisite) end
  end
  -- 2.x: the technology is a research trigger (craft flying robot frames); only its prerequisites move it late
end
