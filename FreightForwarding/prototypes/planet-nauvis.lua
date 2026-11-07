-- 2.x: what a surface generates is defined by the planet's map_gen_settings. When the planet lists
-- its autoplace controls / entities / tiles explicitly, anything not listed is never placed,
-- so FF's resources and shallow water have to be registered on Nauvis.

local nauvis = data.raw.planet and data.raw.planet["nauvis"]
if not (nauvis and nauvis.map_gen_settings) then return end

local mgs = nauvis.map_gen_settings

local ff_controls = { "ff-seamount", "ff-rocket-silo-hole" }
local ff_entities = { "ff-seamount", "ff-rocket-silo-hole" }
-- With Space Age lava pools are on Vulcanus (prototypes/planet-vulcanus.lua)
if not mods["space-age"] then
  table.insert(ff_controls, "ff-lava-pool")
  table.insert(ff_entities, "ff-lava-pool-resource")
end
local ff_tiles = { "water-shallow", "water", "deepwater" }

if mgs.autoplace_controls then
  for _, name in pairs(ff_controls) do
    if data.raw["autoplace-control"][name] then
      mgs.autoplace_controls[name] = mgs.autoplace_controls[name] or {}
    end
  end
end

local autoplace_settings = mgs.autoplace_settings
-- Only add to lists that already exist: a missing list means "everything" and must stay missing.
if autoplace_settings and autoplace_settings.entity and autoplace_settings.entity.settings then
  for _, name in pairs(ff_entities) do
    if data.raw.resource[name] then
      autoplace_settings.entity.settings[name] = autoplace_settings.entity.settings[name] or {}
    end
  end
end
if autoplace_settings and autoplace_settings.tile and autoplace_settings.tile.settings then
  for _, name in pairs(ff_tiles) do
    if data.raw.tile[name] then
      autoplace_settings.tile.settings[name] = autoplace_settings.tile.settings[name] or {}
    end
  end
end

-- No inland oil on Nauvis: oil comes from offshore oil (Cargo Ships Oil Rig) only.
-- (1.x did this through Cargo Ships' "no_oil_on_land" setting, which no longer exists.)
if mgs.autoplace_controls then
  mgs.autoplace_controls["crude-oil"] = nil
end
if autoplace_settings and autoplace_settings.entity and autoplace_settings.entity.settings then
  autoplace_settings.entity.settings["crude-oil"] = nil
end
