-- 2.x: what a surface generates is defined by the planet's map_gen_settings. When the planet lists
-- its autoplace controls / entities / tiles explicitly, anything not listed is never placed,
-- so FF's resources and shallow water have to be registered on Nauvis.

local nauvis = data.raw.planet and data.raw.planet["nauvis"]
if not (nauvis and nauvis.map_gen_settings) then return end

local mgs = nauvis.map_gen_settings

local ff_controls = { "ff-seamount", "ff-lava-pool", "ff-rocket-silo-hole" }
local ff_entities = { "ff-seamount", "ff-lava-pool-resource", "ff-rocket-silo-hole" }
local ff_tiles = { "water-shallow", "water", "deepwater" }

if mgs.autoplace_controls then
  for _, name in pairs(ff_controls) do
    if data.raw["autoplace-control"][name] then
      mgs.autoplace_controls[name] = mgs.autoplace_controls[name] or {}
    end
  end
end

local settings = mgs.autoplace_settings
-- Only add to lists that already exist: a missing list means "everything" and must stay missing.
if settings and settings.entity and settings.entity.settings then
  for _, name in pairs(ff_entities) do
    if data.raw.resource[name] then
      settings.entity.settings[name] = settings.entity.settings[name] or {}
    end
  end
end
if settings and settings.tile and settings.tile.settings then
  for _, name in pairs(ff_tiles) do
    if data.raw.tile[name] then
      settings.tile.settings[name] = settings.tile.settings[name] or {}
    end
  end
end
