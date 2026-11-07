local C = require "__FreightForwarding__.prototypes.collision-util"
local util = require "__FreightForwarding__.prototypes.data-util"

-- Collision layers (2.x: named collision-layer prototypes instead of numbered "layer-N")
local non_deep_water_layer = C.layer("ff_non_deep_water")      -- prototypes/landfill.lua
local platform_layer = C.layer("ff_platform")
local water_object_layer = C.layer("ff_water_object")
local substitute_player_layer = C.layer("ff_substitute_player")
local underwater_pipe_layer = C.layer("ff_underwater_pipe")

-- Seamounts: only on deep water
data.raw["resource"]["ff-seamount"].collision_mask = C.mask{ "resource", non_deep_water_layer, "ground_tile" }

-- Nothing that needs to be connected/underground can be built on the dredging platform
C.add_layer(data.raw.tile["ff-dredging-platform"], platform_layer)
local banned_types = { "electric-pole", "underground-belt" }
for _, type in pairs(banned_types) do
  for _, prototype in pairs(data.raw[type]) do
    C.add_layer(prototype, platform_layer)
  end
end
for _, offshore_pump in pairs(data.raw["offshore-pump"]) do
  if offshore_pump.center_collision_mask then  -- 1.1-style placement rules
    C.add_layer_to_field(offshore_pump, "center_collision_mask", platform_layer)
  else
    C.add_layer(offshore_pump, platform_layer)
  end
end

-- Ensure collisions between pump, underwater pipe, oil rig, offshore storage tank, sonar buoy
local pump = data.raw["pump"]["pump"]
C.add_layer(pump, water_object_layer)
C.add_layer(data.raw.pipe["ff-underwater-pipe"], water_object_layer)
C.add_layer(data.raw["radar"]["ff-sonar-buoy"], water_object_layer)
if data.raw["mining-drill"]["oil_rig"] then
  C.add_layer(data.raw["mining-drill"]["oil_rig"], water_object_layer)
end

-- Compatibility for pump upgrade mods
local next_pump = pump.next_upgrade
while next_pump and data.raw.pump[next_pump] do
  data.raw.pump[next_pump].collision_mask = table.deepcopy(pump.collision_mask)
  next_pump = data.raw.pump[next_pump].next_upgrade
end

-- Offshore storage tank: like a pump, but only on water
local offshore_tank_collision = table.deepcopy(pump.collision_mask)
offshore_tank_collision.layers["ground_tile"] = true
data.raw["storage-tank"]["ff-offshore-storage-tank"].collision_mask = offshore_tank_collision

-- Players can swim (player layer removed from water in prototypes/water.lua),
-- but vehicles and units still have to collide with water
local water = data.raw.tile["water"]
local deep_water = data.raw.tile["deepwater"]
for _, water_tile in pairs{ water, deep_water } do
  C.add_layer(water_tile, substitute_player_layer)
end

for _, type in pairs{ "unit", "car", "spider-leg", "segmented-unit", "spider-unit" } do
  for _, prototype in pairs(data.raw[type] or {}) do
    if C.has_layer(prototype, "player") then
      C.add_layer(prototype, substitute_player_layer)
    end
  end
end

-- Underwater pipes can't be placed on ground but also don't collide with ships
for _, tile in pairs(data.raw.tile) do
  if C.has_layer(tile, "ground_tile") then
    C.add_layer(tile, underwater_pipe_layer)
  end
end
C.add_layer(data.raw.pipe["ff-underwater-pipe"], underwater_pipe_layer)

-- Science
for _, tech in pairs(data.raw.technology) do
  if tech.unit and tech.unit.ingredients then
    local ingredients = tech.unit.ingredients
    if util.contains_research_ingredient(tech.name, "chemical-science-pack")
        and not util.contains_research_ingredient(tech.name, "ff-transport-science-pack") then
      table.insert(ingredients, { "ff-transport-science-pack", 1 })
    else
      -- Add to all techs descending from key techs
      if (util.is_descendant_of(tech.name, "water_transport")
          or util.is_descendant_of(tech.name, "fluid-handling")
          or util.is_descendant_of(tech.name, "automobilism")
          or util.is_descendant_of(tech.name, "ff-transport-science-pack"))
          and util.contains_research_ingredient(tech.name, "logistic-science-pack")
          and not util.contains_research_ingredient(tech.name, "ff-transport-science-pack") then
        table.insert(ingredients, { "ff-transport-science-pack", 1 })
      end
    end
  end
end

if data.raw.technology["ff-interstellar-communication"] then
  for name, tech in pairs(data.raw.technology) do
    if name ~= "ff-interstellar-communication" and tech.prerequisites then
      for i, prereq in pairs(tech.prerequisites) do
        if prereq == "space-science-pack" then
          tech.prerequisites[i] = "ff-interstellar-communication"
        end
      end
    end
  end
end

-- Compatibility
require "__FreightForwarding__.compatibility.beautiful-bridge-railway.data-final-fixes"
require "__FreightForwarding__.compatibility.krastorio2.data-final-fixes"
require "__FreightForwarding__.compatibility.transport-drones.data-final-fixes"
