-- Space Age: more freight from the seas of other planets. Runs in data-updates, after planet-chains.lua.
--   * Fulgora: scrap seamounts on the floor of the deep oil ocean, dredged for scrap
--   * Aquilo: fluorine seeps on the floor of the ammoniacal ocean, pumped by the oil rig (Cargo Ships Oil Rig)
--   * hot titansteel cools down: if it is not cooled in time it spoils into a deformed plate, which the foundry
--     only melts back into steel and titanium (the cobalt is lost)

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end

local util = require("__FreightForwarding__.prototypes.data-util")
local N = require("__FreightForwarding__.resource-autoplace.noise-util")

local FULGORA = {{property = "magnetic-field", min = 99, max = 99}}

local function add_to_planet(planet, resource, control, expression_name)
  local mgs = planet.map_gen_settings
  mgs.property_expression_names = mgs.property_expression_names or {}
  mgs.property_expression_names["entity:" .. resource .. ":probability"] = expression_name
  mgs.autoplace_controls = mgs.autoplace_controls or {}
  mgs.autoplace_controls[control] = {}
  if mgs.autoplace_settings and mgs.autoplace_settings.entity and mgs.autoplace_settings.entity.settings then
    mgs.autoplace_settings.entity.settings[resource] = {}
  end
end

---------------------------------------------------------------------------------------------------
-- Fulgora: scrap seamounts

local seamount = data.raw.resource["ff-seamount"]
local fulgora = data.raw.planet["fulgora"]
if seamount and fulgora and fulgora.map_gen_settings and data.raw.item["scrap"] then
  local scrap_mount = table.deepcopy(seamount)
  scrap_mount.name = "ff-scrap-seamount"
  scrap_mount.localised_name = {"entity-name.ff-scrap-seamount"}
  scrap_mount.localised_description = {"entity-description.ff-scrap-seamount"}
  scrap_mount.map_color = {0.75, 0.6, 0.85}
  local sheet = scrap_mount.stages and scrap_mount.stages.sheet
  if sheet then sheet.tint = {a = 0.5, r = 0.45, g = 0.35, b = 0.5} end
  scrap_mount.autoplace = {control = "ff-scrap-seamount", order = "c", probability_expression = "0", richness_expression = "10"}
  -- collision mask is set in data-final-fixes: only on the deep oil ocean

  data:extend{
    scrap_mount,
    {
      type = "autoplace-control",
      name = "ff-scrap-seamount",
      localised_name = {"", "[entity=ff-scrap-seamount] ", {"entity-name.ff-scrap-seamount"}},
      richness = false,
      order = "z-e",
      category = "resource",
    },
    {
      type = "noise-expression",
      name = "ff_fulgora_scrap_seamount_probability",
      expression = N.num(6 / (64 * 64 ^ 2)) .. " * " .. N.control("ff-scrap-seamount", "frequency") .. " * (distance > 150)",
    },
    {
      type = "recipe",
      name = "ff-scrap-dredging",
      localised_name = {"recipe-name.ff-scrap-dredging"},
      icons = {{icon = data.raw.item["scrap"].icon, icon_size = data.raw.item["scrap"].icon_size or 64}},
      categories = {"ff-dredging"},
      enabled = false,
      energy_required = 50,
      ingredients = {},
      results = {{type = "item", name = "scrap", amount_min = 100, amount_max = 250}},
      main_product = "scrap",
      always_show_products = true,
      show_amount_in_title = false,
      surface_conditions = FULGORA,
      subgroup = data.raw.item["scrap"].subgroup,
      order = "z[ff-scrap-dredging]",
    },
  }
  add_to_planet(fulgora, "ff-scrap-seamount", "ff-scrap-seamount", "ff_fulgora_scrap_seamount_probability")
  util.add_unlock("ff-dredging", "ff-scrap-dredging")

  -- Shallow oil ocean gets its own layer, so the seamounts stay on the deep ocean
  data:extend{{type = "collision-layer", name = "ff_shallow_oil"}}
  for _, name in pairs{"oil-ocean-shallow", "oil-ocean-shallow-2"} do
    local tile = data.raw.tile[name]
    if tile and tile.collision_mask then
      tile.collision_mask.layers = tile.collision_mask.layers or {}
      tile.collision_mask.layers["ff_shallow_oil"] = true
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Aquilo: fluorine seeps

local offshore_oil = data.raw.resource["offshore-oil"]
local aquilo = data.raw.planet["aquilo"]
if offshore_oil and aquilo and aquilo.map_gen_settings and data.raw.fluid["fluorine"] then
  local seep = table.deepcopy(offshore_oil)
  seep.name = "ff-fluorine-seep"
  seep.localised_name = {"entity-name.ff-fluorine-seep"}
  seep.localised_description = {"entity-description.ff-fluorine-seep"}
  seep.map_color = {0.75, 1, 0.45}
  seep.icons = {{icon = data.raw.fluid["fluorine"].icon, icon_size = data.raw.fluid["fluorine"].icon_size or 64}}
  seep.icon = nil
  seep.minable = table.deepcopy(seep.minable)
  seep.minable.results = {{type = "fluid", name = "fluorine", amount_min = 10, amount_max = 10, independent_probability = 1}}
  seep.autoplace = {control = "ff-fluorine-seep", order = "c", probability_expression = "0",
                    richness_expression = "400000 + 200 * distance"}
  data:extend{
    seep,
    {
      type = "autoplace-control",
      name = "ff-fluorine-seep",
      localised_name = {"", "[entity=ff-fluorine-seep] ", {"entity-name.ff-fluorine-seep"}},
      richness = true,
      order = "z-f",
      category = "resource",
    },
    {
      type = "noise-expression",
      name = "ff_aquilo_fluorine_seep_probability",
      -- Collision (water_resource layer) keeps them on the ocean
      expression = N.num(10 / (64 * 64 ^ 2)) .. " * " .. N.control("ff-fluorine-seep", "frequency") .. " * (distance > 100)",
    },
  }
  add_to_planet(aquilo, "ff-fluorine-seep", "ff-fluorine-seep", "ff_aquilo_fluorine_seep_probability")
end

---------------------------------------------------------------------------------------------------
-- Hot titansteel cools down

local hot = data.raw.item["ff-hot-titansteel-plate"]
local plate = data.raw.item["ff-titansteel-plate"]
if hot and plate and data.raw["recipe-category"]["metallurgy"] then
  local icons = table.deepcopy(plate.icons or {{icon = plate.icon, icon_size = plate.icon_size}})
  for _, icon in pairs(icons) do icon.tint = {r = 0.45, g = 0.3, b = 0.25, a = 1} end
  data:extend{
    {
      type = "item",
      name = "ff-deformed-titansteel-plate",
      icons = icons,
      subgroup = plate.subgroup,
      order = (plate.order or "") .. "-z",
      stack_size = 20,
      weight = plate.weight,
    },
    {
      type = "recipe",
      name = "ff-deformed-titansteel-remelting",
      categories = {"metallurgy"},
      icons = icons,
      subgroup = plate.subgroup,
      order = (plate.order or "") .. "-z",
      enabled = false,
      energy_required = 4,
      ingredients = {{type = "item", name = "ff-deformed-titansteel-plate", amount = 1}},
      results = {
        {type = "item", name = "steel-plate", amount = 1},
        {type = "item", name = "titanium-plate", amount = 1},
      },
      allow_decomposition = false,
    },
  }
  hot.spoil_ticks = 2 * 60 * 60  -- 2 minutes to get it into a chemical plant
  hot.spoil_result = "ff-deformed-titansteel-plate"
  util.add_unlock("ff-titansteel-processing", "ff-deformed-titansteel-remelting")
end
