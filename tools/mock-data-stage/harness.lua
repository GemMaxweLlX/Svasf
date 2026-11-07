-- Minimal Factorio data-stage mock to execute FreightForwarding's settings/data stages.
local MOD = arg[1]
local SPACE_AGE = arg[2] == "sa"

package.path = "?.lua;" .. package.path

function log(s) io.stderr:write("[log] " .. tostring(s) .. "\n") end
serpent = { block = function(t) return tostring(t) end, line = function(t) return tostring(t) end }

function table.deepcopy(o, seen)
  if type(o) ~= "table" then return o end
  seen = seen or {}
  if seen[o] then return seen[o] end
  local c = {}
  seen[o] = c
  for k, v in pairs(o) do c[table.deepcopy(k, seen)] = table.deepcopy(v, seen) end
  return setmetatable(c, getmetatable(o))
end
function table_size(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

util = {
  by_pixel = function(x, y) return {x / 32, y / 32} end,
  empty_sprite = function() return {filename = "__core__/graphics/empty.png", width = 1, height = 1, frame_count = 1} end,
  table = { deepcopy = table.deepcopy },
  merge = function(ts) local r = {} for _, t in pairs(ts) do for k, v in pairs(t) do r[k] = v end end return r end,
  split = function(s, sep) local r = {} for p in s:gmatch("[^" .. sep .. "]+") do r[#r + 1] = p end return r end,
}
defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
circuit_connector_definitions = setmetatable({}, {__index = function() return {{}, {}, {}, {}} end})
function pipecoverspictures() return {} end
function accumulator_reflection() return {} end

-- Strict-ish data.raw: unknown prototypes are created on access with sensible defaults
local defaults = {
  technology = function(n) return {type = "technology", name = n, prerequisites = {}, effects = {}, unit = {count = 1, time = 1, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}}}} end,
  recipe = function(n) return {type = "recipe", name = n, ingredients = {{type = "item", name = "iron-plate", amount = 1}}, results = {{type = "item", name = n, amount = 1}}} end,
  tile = function(n) return {type = "tile", name = n, collision_mask = {layers = {ground_tile = true}}, variants = {}, build_sound = {small = {filename = "x.ogg"}}} end,
  item = function(n) return {type = "item", name = n, stack_size = 50, place_as_tile = (n == "landfill") and {result = "landfill", condition = {layers = {water_tile = true}}, condition_size = 1} or nil} end,
  ["noise-expression"] = function(n) return nil end,
  ["noise-function"] = function(n) return nil end,
  ["collision-layer"] = function(n) return nil end,
  ["autoplace-control"] = function(n) return nil end,
}
local accessed_missing = {}
local raw = {}
data = { raw = setmetatable(raw, {__index = function(t, type)
  local by_name = setmetatable({}, {__index = function(t2, name)
    local f = defaults[type]
    local proto
    if f then proto = f(name) else proto = {type = type, name = name, flags = {}, inventory_size = 40, friction = 0.01, energy_source = {type = "electric"}} end
    if proto == nil then return nil end
    accessed_missing[type .. "/" .. name] = true
    rawset(t2, name, proto)
    return proto
  end})
  rawset(t, type, by_name)
  return by_name
end}) }
function data:extend(list)
  for _, p in pairs(list) do
    assert(p.type and p.name, "prototype without type/name")
    data.raw[p.type][p.name] = p
  end
end

-- Pre-populate prototypes whose absence would change behaviour
data.raw["map-gen-presets"]["default"] = {type = "map-gen-presets", name = "default"}
data.raw["utility-constants"]["default"] = {type = "utility-constants", name = "default", main_menu_simulations = {}}
data.raw.lab.lab = {type = "lab", name = "lab", inputs = {"automation-science-pack", "logistic-science-pack", "chemical-science-pack"}}
data.raw.locomotive.locomotive = {type = "locomotive", name = "locomotive", energy_source = {type = "burner", fuel_categories = {"chemical"}, fuel_inventory_size = 1}}
data.raw["cargo-wagon"]["cargo-wagon"] = {type = "cargo-wagon", name = "cargo-wagon", inventory_size = 40}
data.raw.character.character = {type = "character", name = "character", inventory_size = 80}
data.raw.pump.pump = {type = "pump", name = "pump"}
data.raw["mining-drill"].pumpjack = {type = "mining-drill", name = "pumpjack", graphics_set = {animation = {north = {layers = {{filename = "p.png", width = 206, height = 172, scale = 0.5, shift = {0, 0}}}}}}, radius_visualisation_picture = {filename = "r.png", width = 12, height = 12}}
data.raw.pipe.pipe = {type = "pipe", name = "pipe", icon = "__base__/graphics/icons/pipe.png", pictures = {straight_vertical = {filename = "a.png", width = 64, height = 64}, fluid_background = {filename = "b.png"}}}
data.raw.radar.radar = {type = "radar", name = "radar", pictures = {layers = {{filename = "r.png"}, {filename = "s.png", draw_as_shadow = true}}}}
data.raw["rocket-silo"]["rocket-silo"] = {type = "rocket-silo", name = "rocket-silo", collision_box = {{-4.4, -4.4}, {4.4, 4.4}}, selection_box = {{-4.5, -4.5}, {4.5, 4.5}}, base_day_sprite = {}, circuit_connector = {}}
data.raw["offshore-pump"]["offshore-pump"] = {type = "offshore-pump", name = "offshore-pump"}
for _, n in pairs{"iron-ore", "copper-ore", "coal", "stone", "uranium-ore", "crude-oil", "lead-ore", "titanium-ore"} do
  data.raw.resource[n] = {type = "resource", name = n}
  data.raw["autoplace-control"][n] = {type = "autoplace-control", name = n, category = "resource"}
end
data.raw["autoplace-control"]["water"] = {type = "autoplace-control", name = "water", category = "terrain"}
data.raw["autoplace-control"]["enemy-base"] = {type = "autoplace-control", name = "enemy-base", category = "enemy"}
data.raw.fluid["crude-oil"] = {type = "fluid", name = "crude-oil"}
data.raw.fluid["water"] = {type = "fluid", name = "water"}
data.raw["unit-spawner"]["biter-spawner"] = {type = "unit-spawner", name = "biter-spawner", autoplace = {probability_expression = "enemy_autoplace_base(0, 6)"}}
data.raw["noise-function"]["enemy_autoplace_base"] = {type = "noise-function", name = "enemy_autoplace_base", parameters = {"distance_factor", "seed"},
  expression = "spot_noise{x = x, y = y, density_expression = max(0, distance - starting_area_radius) / 100, maximum_spot_basement_radius = 3, seed1 = seed}",
  local_expressions = {d = "distance * distance_factor"}}
for _, n in pairs{"water", "deepwater", "water-shallow", "water-mud", "water-green", "deepwater-green"} do
  data.raw.tile[n] = {type = "tile", name = n, collision_mask = {layers = {water_tile = true, player = true, resource = true, item = true, doodad = true}}}
end
data.raw.tile["grass-1"] = {type = "tile", name = "grass-1", collision_mask = {layers = {ground_tile = true}}}
data.raw.tile["concrete"] = {type = "tile", name = "concrete", collision_mask = {layers = {ground_tile = true}}, variants = {material_background = {picture = "x", count = 8}}, minable = {}}
if SPACE_AGE then
  data.raw.planet.nauvis = {type = "planet", name = "nauvis", map_gen_settings = {
    property_expression_names = {elevation = "elevation_nauvis"},
    autoplace_controls = {["iron-ore"] = {}, water = {}},
    autoplace_settings = {entity = {settings = {["iron-ore"] = {}}}, tile = {settings = {water = {}, deepwater = {}}}},
  }}
  data.raw["autoplace-control"]["tungsten-ore"] = {type = "autoplace-control", name = "tungsten-ore", category = "resource"}
  data.raw.lab.biolab = {type = "lab", name = "biolab", inputs = {"automation-science-pack", "logistic-science-pack"}}
end

-- Base vanilla patch metasets like 2.x core resource-autoplace
data.raw["noise-expression"]["regular_resource_patch_set_count"] = {type = "noise-expression", name = "regular_resource_patch_set_count", expression = "7"}
data.raw["noise-expression"]["starting_resource_patch_set_count"] = {type = "noise-expression", name = "starting_resource_patch_set_count", expression = "4"}
resource_autoplace__patch_metasets = {
  regular = {count_expression_name = "regular_resource_patch_set_count", next_patch_set_index = 7, patch_set_indexes = {}},
  starting = {count_expression_name = "starting_resource_patch_set_count", next_patch_set_index = 4, patch_set_indexes = {}},
}

mods = {base = "2.1.0", IntermodalContainers = "1", ["cargo-ships"] = "1", bzlead = "1", bztitanium = "1"}
if SPACE_AGE then mods["space-age"] = "2.1.0" end

-- require mapping
local loaded = {}
local function resolve(name)
  name = name:gsub("%.lua$", "")
  local mod, rest = name:match("^__([%w%-_]+)__[%./](.*)$")
  if mod == "FreightForwarding" then
    return MOD .. "/" .. rest:gsub("%.", "/") .. ".lua"
  elseif mod then
    return nil, mod .. "/" .. rest
  end
  return MOD .. "/" .. name:gsub("%.", "/") .. ".lua"
end
local stubs = {
  ["core/lualib/collision-mask-util"] = { get_default_mask = function(t) return {layers = {object = true, item = true, player = true, water_tile = true}} end },
  ["core.lualib.collision-mask-util"] = true,
  ["base/prototypes/entity/sounds"] = setmetatable({}, {__index = function() return {} end}),
  ["base.prototypes.entity.sounds"] = true,
  ["base/prototypes/entity/hit-effects"] = { entity = function() return {} end },
  ["base.prototypes.entity.hit-effects"] = true,
}
function require(name)
  if loaded[name] ~= nil then return loaded[name] end
  local path, stubname = resolve(name)
  if stubname then
    local key = stubname:gsub("%.", "/")
    local stub = stubs[key]
    if stub == nil then error("no stub for " .. name) end
    loaded[name] = stub
    return stub
  end
  local f = assert(loadfile(path))
  local r = f()
  if r == nil then r = true end
  loaded[name] = r
  return r
end

-- settings stage
settings = {startup = {}}
data.raw["string-setting"]["ic-machine-size"] = {type = "string-setting", name = "ic-machine-size"}
require("settings")
for _, t in pairs{"bool-setting", "int-setting", "double-setting", "string-setting"} do
  for name, s in pairs(rawget(data.raw, t) or {}) do
    local v = s.forced_value
    if v == nil then v = s.default_value end
    settings.startup[name] = {value = v}
  end
end

require("data")
require("data-updates")
require("data-final-fixes")

-- Dump noise expressions for the checker
local out = assert(io.open(arg[3] or "noise-dump.lua", "w"))
out:write("return {\n")
local function q(s) return string.format("%q", s) end
for _, t in pairs{"noise-expression", "noise-function"} do
  for name, p in pairs(rawget(data.raw, t) or {}) do
    out:write("{kind=" .. q(t) .. ", name=" .. q(name) .. ", expression=" .. q(tostring(p.expression)) .. ", params={")
    for _, prm in pairs(p.parameters or {}) do out:write(q(prm) .. ",") end
    out:write("}, locals={")
    for k, v in pairs(p.local_expressions or {}) do out:write("[" .. q(k) .. "]=" .. q(v) .. ",") end
    out:write("}},\n")
  end
end
for _, t in pairs{"resource", "tile", "unit-spawner"} do
  for name, p in pairs(rawget(data.raw, t) or {}) do
    if p.autoplace then
      for _, key in pairs{"probability_expression", "richness_expression"} do
        if p.autoplace[key] then
          out:write("{kind=" .. q(t .. "." .. key) .. ", name=" .. q(name) .. ", expression=" .. q(p.autoplace[key]) .. ", params={}, locals={}},\n")
        end
      end
    end
  end
end
out:write("}\n")
out:close()

-- Report checks
local problems = 0
local function check(cond, msg) if not cond then problems = problems + 1 print("PROBLEM: " .. msg) end end
for ptype, list in pairs(raw) do
  for name, p in pairs(list) do
    if ptype == "recipe" then
      for _, i in pairs(p.ingredients or {}) do check(i.type and i.name and i.amount, "recipe " .. name .. " ingredient not 2.x: " .. tostring(i[1] or i.name)) end
      for _, r in pairs(p.results or {}) do check(r.type and r.name, "recipe " .. name .. " result not 2.x") end
      check(p.result == nil and p.normal == nil, "recipe " .. name .. " has legacy result/normal")
    end
    if p.flags then for _, f in pairs(p.flags) do check(f ~= "hidden", ptype .. "/" .. name .. " has hidden flag") end end
    if p.collision_mask then check(p.collision_mask.layers ~= nil, ptype .. "/" .. name .. " collision mask not 2.x") end
    if p.hr_version then check(false, ptype .. "/" .. name .. " has hr_version") end
    if p.energy_source and ptype ~= "locomotive" then check(type(p.energy_source.emissions_per_minute) ~= "number", name .. " numeric emissions") end
  end
end
local function walk(t, path, seen)
  seen = seen or {}
  if seen[t] then return end
  seen[t] = true
  for k, v in pairs(t) do
    if k == "hr_version" then check(false, "hr_version at " .. path) end
    if type(v) == "table" then walk(v, path .. "." .. tostring(k), seen) end
  end
end
for ptype, list in pairs(raw) do for name, p in pairs(list) do if name:sub(1, 3) == "ff-" then walk(p, ptype .. "/" .. name) end end end
print("collision layers: " .. table.concat((function() local r = {} for n in pairs(rawget(raw, "collision-layer") or {}) do r[#r+1] = n end table.sort(r) return r end)(), ", "))
if SPACE_AGE then
  local mgs = raw.planet.nauvis.map_gen_settings
  print("nauvis elevation: " .. tostring(mgs.property_expression_names.elevation))
  local r = {} for n in pairs(mgs.autoplace_controls) do r[#r+1] = n end table.sort(r)
  print("nauvis controls: " .. table.concat(r, ", "))
  r = {} for n in pairs(mgs.autoplace_settings.entity.settings) do r[#r+1] = n end table.sort(r)
  print("nauvis entities: " .. table.concat(r, ", "))
  r = {} for n in pairs(mgs.autoplace_settings.tile.settings) do r[#r+1] = n end table.sort(r)
  print("nauvis tiles: " .. table.concat(r, ", "))
  print("silo item place_result: " .. tostring(raw.item["rocket-silo"].place_result))
end
print("done, problems: " .. problems)
