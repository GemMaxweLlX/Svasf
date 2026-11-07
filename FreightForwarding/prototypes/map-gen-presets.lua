-- Map gen preset "Freight Forwarding" and Nauvis defaults.
-- 2.x: `terrain_segmentation` and `water` were replaced by the "water" autoplace control
-- (frequency = scale, size = coverage); `research_queue_setting` no longer exists.

local presets = data.raw["map-gen-presets"]["default"]

local ff_default = { frequency = 0.5, size = 1.0, richness = 1 }

local ff_property_expression_names = {
  elevation = "x-continents",
  cliff_elevation = "ff_cliff_elevation",
}

presets["x-default"] = {
  order = ".1",
  basic_settings = {
    autoplace_controls = {
      water = { frequency = 1, size = 1 },
    },
    property_expression_names = table.deepcopy(ff_property_expression_names),
  },
  advanced_settings = {
    enemy_evolution = {
      time_factor = 0.000002,  -- Default is 0.000004
    },
    enemy_expansion = {
      enabled = false,
    },
  },
}

-- Halve frequency of all resources (patches are spread out between islands instead)
local excluded_controls = {
  ["ff-seamount"] = true,
  ["ff-rocket-silo-hole"] = true,
}

local nauvis = data.raw.planet and data.raw.planet["nauvis"]
local nauvis_controls = nauvis and nauvis.map_gen_settings and nauvis.map_gen_settings.autoplace_controls

for name, control in pairs(data.raw["autoplace-control"]) do
  if control.category == "resource" and not excluded_controls[name] then
    -- With Space Age only touch controls that are actually used on Nauvis
    if not nauvis_controls or nauvis_controls[name] or name:sub(1, 3) == "ff-" then
      presets["x-default"].basic_settings.autoplace_controls[name] = ff_default
    end
  end
end

-- Make FF terrain the Nauvis default, so "Default" preset (and Space Age's Nauvis) also gets islands.
if settings.startup["ff-island-terrain-by-default"].value and nauvis and nauvis.map_gen_settings then
  local mgs = nauvis.map_gen_settings
  mgs.property_expression_names = mgs.property_expression_names or {}
  for property, expression in pairs(ff_property_expression_names) do
    mgs.property_expression_names[property] = expression
  end
end
