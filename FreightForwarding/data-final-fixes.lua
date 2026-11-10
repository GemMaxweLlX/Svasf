local C = require "__FreightForwarding__.prototypes.collision-util"
local util = require "__FreightForwarding__.prototypes.data-util"

-- Collision layers (2.x: named collision-layer prototypes instead of numbered "layer-N")
local non_deep_water_layer = C.layer("ff_non_deep_water")      -- prototypes/landfill.lua
local platform_layer = C.layer("ff_platform")
local water_object_layer = C.layer("ff_water_object")
local substitute_player_layer = C.layer("ff_substitute_player")
local underwater_pipe_layer = C.layer("ff_underwater_pipe")

-- Seamounts: only on deep water.
-- Water tiles have the "resource" layer in 2.x; Cargo Ships Oil Rig instead puts its offshore oil on a
-- "water_resource" layer (present on land and non-deep water). Use it too, so seamounts and offshore oil
-- don't overlap. Without that mod, a separate layer is used and seamounts only avoid land and shallow water.
local seamount_resource_layer = data.raw["collision-layer"]["water_resource"] and "water_resource" or "ff_seamount"
C.layer(seamount_resource_layer)
data.raw["resource"]["ff-seamount"].collision_mask = C.mask{ seamount_resource_layer, non_deep_water_layer, "ground_tile" }
-- Cobalt vents (Space Age, Vulcanus): same rule, which leaves only lava (and deep water) for them
if data.raw["resource"]["ff-cobalt-vent"] then
  data.raw["resource"]["ff-cobalt-vent"].collision_mask = C.mask{ seamount_resource_layer, non_deep_water_layer, "ground_tile" }
end

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

-- Ensure collisions between pumps on water, underwater pipe, oil rig, offshore storage tank, sonar buoy.
-- 2.1: Cargo Ships has separate ship (un)loading pumps for water; the normal pump stays on land.
local pump = data.raw["pump"]["pump"]
local water_pumps = {}
for _, name in pairs{"ship-loading-pump", "ship-unloading-pump"} do
  if data.raw["pump"][name] then table.insert(water_pumps, data.raw["pump"][name]) end
end
if #water_pumps == 0 then water_pumps = {pump} end  -- older Cargo Ships: the normal pump goes on water

for _, water_pump in pairs(water_pumps) do
  C.add_layer(water_pump, water_object_layer)
end
C.add_layer(data.raw.pipe["ff-underwater-pipe"], water_object_layer)
C.add_layer(data.raw["radar"]["ff-sonar-buoy"], water_object_layer)
if data.raw["radar"]["ff-sonar-buoy-2"] then
  data.raw["radar"]["ff-sonar-buoy-2"].collision_mask = table.deepcopy(data.raw["radar"]["ff-sonar-buoy"].collision_mask)
end
if data.raw["mining-drill"]["oil_rig"] then
  C.add_layer(data.raw["mining-drill"]["oil_rig"], water_object_layer)
end

-- Compatibility for pump upgrade mods
local next_pump = pump.next_upgrade
while next_pump and data.raw.pump[next_pump] do
  data.raw.pump[next_pump].collision_mask = table.deepcopy(pump.collision_mask)
  next_pump = data.raw.pump[next_pump].next_upgrade
end

-- Offshore storage tank: like a pump on water, but never on land
local offshore_tank_collision = C.get_mask(water_pumps[1])
offshore_tank_collision.layers["ground_tile"] = true
offshore_tank_collision.layers["object"] = true
data.raw["storage-tank"]["ff-offshore-storage-tank"].collision_mask = offshore_tank_collision
-- Offshore wind turbine: like the offshore tank (only on water); tidal generator: also not on deep water
if data.raw["electric-energy-interface"]["ff-offshore-wind-turbine"] then
  data.raw["electric-energy-interface"]["ff-offshore-wind-turbine"].collision_mask = table.deepcopy(offshore_tank_collision)
end
if data.raw["electric-energy-interface"]["ff-tidal-generator"] then
  local tidal_collision = table.deepcopy(offshore_tank_collision)
  tidal_collision.layers["ff_deep_water"] = true
  data.raw["electric-energy-interface"]["ff-tidal-generator"].collision_mask = tidal_collision
end

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
-- Space Age: technologies that need another planet's science don't need transport science (the interplanetary
-- freight science covers the late ones), unless the setting asks for it
-- Any science that isn't Nauvis' counts as another planet's: Space Age planets, planets from other mods (Cerys,
-- Muluna, Maraxsis...) and K2's late tech cards
local NAUVIS_SCIENCE = {
  ["automation-science-pack"] = true, ["logistic-science-pack"] = true, ["military-science-pack"] = true,
  ["chemical-science-pack"] = true, ["production-science-pack"] = true, ["utility-science-pack"] = true,
  ["space-science-pack"] = true, ["ff-transport-science-pack"] = true, ["kr-basic-tech-card"] = true,
}
local skip_planet_techs = mods["space-age"] and not settings.startup["ff-classic-mode"].value
                          and not settings.startup["ff-transport-science-planet-techs"].value
local function needs_planet_science(tech_name)
  for _, pack in pairs(util.research_packs(tech_name)) do
    if not NAUVIS_SCIENCE[pack] then return true end
  end
  return false
end
for _, tech in pairs(data.raw.technology) do
  if tech.unit and tech.unit.ingredients and not (skip_planet_techs and needs_planet_science(tech.name))
      -- never make a technology impossible: some lab has to accept transport science with its other packs
      and util.lab_accepts(util.research_packs(tech.name, "ff-transport-science-pack")) then
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

-- Elevated rails: like on Fulgora's deep oil ocean, rail supports can't stand in deep water, so bridges only
-- cross shallow straits and the open ocean still needs ships
if data.raw["collision-layer"]["rail_support"] then
  for _, name in pairs{"deepwater", "deepwater-green"} do
    if data.raw.tile[name] then C.add_layer(data.raw.tile[name], "rail_support") end
  end
end

-- Fulgora scrap seamounts: like seamounts, plus not on the shallow oil ocean
if data.raw["resource"]["ff-scrap-seamount"] then
  data.raw["resource"]["ff-scrap-seamount"].collision_mask = C.mask{ seamount_resource_layer, non_deep_water_layer, "ground_tile", "ff_shallow_oil" }
end

-- Space Age container tiers (needs the containers generated by Intermodal Containers in its data-final-fixes)
require "__FreightForwarding__.prototypes.container-tiers"
require "__FreightForwarding__.prototypes.freight-science-final"
require "__FreightForwarding__.prototypes.lava-waterways"
require "__FreightForwarding__.prototypes.container-damage"
require "__FreightForwarding__.prototypes.container-groups"
require "__FreightForwarding__.prototypes.delivery-permits"
require "__FreightForwarding__.prototypes.tier-badges"
require "__FreightForwarding__.compatibility.krastorio2.space-age"
require "__FreightForwarding__.compatibility.mining-space-industries.data-final-fixes"
