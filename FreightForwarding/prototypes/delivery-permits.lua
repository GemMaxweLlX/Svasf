-- FF + Space Age exclusive: delivery permits. A key technology needs a permit first: a special technology that can't be
-- researched in labs. It is granted when a given container is delivered to a research post, which appears at a random
-- place on land near the explored area of the given planet (scripts/delivery-permits.lua). The container is used up.
-- After that the key technology is researched as usual. Runs in data-final-fixes (needs the generated containers).
-- Off in classic mode, or with the startup setting.

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end
if not settings.startup["ff-delivery-permits"].value then return end

-- tech = key technology, item = container to deliver, count, planet, min/max = distance from the planet's spawn
local PERMITS = {
  {tech = "ff-dredging",                   item = "ic-container-concrete",           count = 2, planet = "nauvis",   min = 200, max = 700},
  {tech = "ff-sea-infrastructure",         item = "ic-container-copper-cable",       count = 2, planet = "nauvis",   min = 300, max = 1000},
  {tech = "ff-titansteel-processing",      item = "ic-container-titanium-plate",     count = 2, planet = "vulcanus", min = 80,  max = 500},
  {tech = "ff-light-containers",           item = "ic-container-lead-plate",         count = 2, planet = "vulcanus", min = 80,  max = 500},
  {tech = "ff-battery-pack",               item = "ic-container-ff-cobalt-ingot",    count = 2, planet = "fulgora",  min = 80,  max = 500},
  {tech = "ff-refrigerated-containers",    item = "ic-container-plastic-bar",        count = 2, planet = "gleba",    min = 80,  max = 500},
  {tech = "ff-cryo-containers",            item = "ff-reefer-bioflux",               count = 1, planet = "aquilo",   min = 60,  max = 400},
  {tech = "ff-lithium-battery-pack",       item = "ff-reefer-ff-charged-battery-pack", count = 1, planet = "aquilo", min = 60,  max = 400},
  {tech = "ff-heavy-cargo-ship",           item = "ic-container-ff-titansteel-plate", count = 1, planet = "aquilo",  min = 60,  max = 400},
  {tech = "ff-icebreaker",                 item = "ic-container-tungsten-carbide",   count = 1, planet = "aquilo",   min = 60,  max = 400},
  {tech = "ff-interstellar-freight-contract", item = "ff-light-superconductor",      count = 2, planet = "aquilo",   min = 60,  max = 400},
}

-- What a damaged research post needs delivered before it is restored: common goods plus something local
local REPAIR = {
  nauvis   = {{"steel-plate", 40}, {"electronic-circuit", 20}, {"stone-brick", 50}},
  vulcanus = {{"steel-plate", 40}, {"electronic-circuit", 20}, {"calcite", 50}},
  fulgora  = {{"steel-plate", 40}, {"electronic-circuit", 20}, {"scrap", 50}},
  gleba    = {{"steel-plate", 40}, {"electronic-circuit", 20}, {"stone-brick", 50}},
  aquilo   = {{"steel-plate", 40}, {"electronic-circuit", 20}, {"ice", 50}},
  -- planets from other mods
  cerys    = {{"steel-plate", 40}, {"electronic-circuit", 20}, {"methane-ice", 50}},
  moshine  = {{"steel-plate", 40}, {"electronic-circuit", 20}, {"sand", 50}},
  maraxsis = {{"steel-plate", 40}, {"electronic-circuit", 20}, {"maraxsis-coral", 50}},
  muluna   = {{"steel-plate", 40}, {"electronic-circuit", 20}, {"anorthite-chunk", 50}},
}

local function repair_for(planet)
  local list = {}
  for _, entry in pairs(REPAIR[planet] or REPAIR.nauvis) do
    if data.raw.item[entry[1]] then list[#list + 1] = {item = entry[1], count = entry[2]} end
  end
  return list
end

local DISCOVERY = {
  vulcanus = "planet-discovery-vulcanus", fulgora = "planet-discovery-fulgora",
  gleba = "planet-discovery-gleba", aquilo = "planet-discovery-aquilo",
  cerys = "moon-discovery-cerys", moshine = "planet-discovery-moshine",
  maraxsis = "planet-discovery-maraxsis", muluna = "planet-discovery-muluna",
}

---------------------------------------------------------------------------------------------------
-- Planets from other mods: an expedition permit (the planet's discovery needs supplies delivered to a post on the
-- planet it is reached from) and a survey permit (the planet's first technology using its own science needs a
-- delivery to a post on the planet itself, repaired with its local material). Only planets whose discovery is
-- researched with science (not a trigger) get the expedition permit.

--- Number of technologies a technology depends on (all ancestors)
local depth_cache = {}
local function depth(name)
  if depth_cache[name] then return depth_cache[name] end
  depth_cache[name] = 0  -- guards against cycles
  local seen, stack, count = {}, {name}, 0
  while #stack > 0 do
    local current = table.remove(stack)
    local tech = data.raw.technology[current]
    for _, prerequisite in pairs(tech and tech.prerequisites or {}) do
      if not seen[prerequisite] then
        seen[prerequisite] = true
        count = count + 1
        stack[#stack + 1] = prerequisite
      end
    end
  end
  depth_cache[name] = count
  return count
end

--- Technologies on the way to the solar system edge: a survey permit must not block the endgame
local critical = {}
do
  local stack = {"stellar-discovery-solar-system-edge"}
  while #stack > 0 do
    local tech = data.raw.technology[table.remove(stack)]
    for _, prerequisite in pairs(tech and tech.prerequisites or {}) do
      if not critical[prerequisite] then
        critical[prerequisite] = true
        stack[#stack + 1] = prerequisite
      end
    end
  end
end

--- The earliest technology (fewest ancestors, then cheapest) needing this science pack that is researched with
--- science (not a trigger), is not an infinite one and is not on the way to the solar system edge
local function first_technology_with(pack)
  local best, best_key
  for name, tech in pairs(data.raw.technology) do
    if tech.unit and tech.unit.ingredients and not name:find("^ff%-") and not tech.unit.count_formula
        and not critical[name] then
      local uses = false
      for _, ingredient in pairs(tech.unit.ingredients) do
        if (ingredient.name or ingredient[1]) == pack then uses = true end
      end
      if uses then
        local key = {depth(name), (tech.unit.count or 0) * #tech.unit.ingredients, name}
        if not best_key or key[1] < best_key[1] or (key[1] == best_key[1] and (key[2] < best_key[2]
            or (key[2] == best_key[2] and key[3] < best_key[3]))) then
          best, best_key = name, key
        end
      end
    end
  end
  return best
end

local MOD_PLANETS = {
  {planet = "cerys", from = "fulgora",
   expedition = {item = "ic-container-lead-plate", count = 2},           -- shielding against the radiation
   pack = "cerysian-science-pack", survey = {item = "ic-container-holmium-plate", count = 1}},
  {planet = "moshine", from = "vulcanus",
   expedition = {item = "ic-container-ff-titansteel-plate", count = 1}}, -- a hull for 98 °C and acid rain
  {planet = "maraxsis", from = "gleba",
   expedition = {item = "ic-container-tungsten-carbide", count = 2},      -- pressure hulls for the deep
   pack = "hydraulic-science-pack", survey = {item = "ic-container-ff-titansteel-plate", count = 1}},
  {planet = "muluna", pack = "interstellar-science-pack",
   survey = {item = "ic-container-titanium-plate", count = 2}},         -- Nauvis titanium for the moon base
}
for _, entry in pairs(MOD_PLANETS) do
  if data.raw.planet[entry.planet] then
    local discovery = data.raw.technology[DISCOVERY[entry.planet]]
    if entry.expedition and discovery and discovery.unit and not discovery.research_trigger then
      PERMITS[#PERMITS + 1] = {tech = DISCOVERY[entry.planet], item = entry.expedition.item, count = entry.expedition.count,
                               planet = entry.from, min = 80, max = 500}
    end
    local survey_tech = entry.pack and data.raw.item[entry.pack] or entry.pack and data.raw.tool[entry.pack]
    survey_tech = survey_tech and first_technology_with(entry.pack)
    if survey_tech and entry.survey then
      PERMITS[#PERMITS + 1] = {tech = survey_tech, item = entry.survey.item, count = entry.survey.count,
                               planet = entry.planet, min = 60, max = 400}
    end
  end
end

--- Technology that unlocks the loading recipe of a filled container (so the permit comes after it)
local function loading_tech(item)
  local recipe
  for _, prefix in pairs{{"ic-container-", "ic-load-"}, {"ff-reefer-", "ff-reefer-load-"}, {"ff-light-", "ff-light-load-"},
                         {"ff-cryo-", "ff-cryo-load-"}} do
    if item:sub(1, #prefix[1]) == prefix[1] then
      recipe = prefix[2] .. item:sub(#prefix[1] + 1)
      break
    end
  end
  if not (recipe and data.raw.recipe[recipe]) then return nil end
  if data.raw.recipe[recipe].enabled ~= false then  -- IC loading recipes are enabled; containerization is the gate
    return data.raw.technology["ic-containerization-1"] and "ic-containerization-1" or nil
  end
  for name, tech in pairs(data.raw.technology) do
    for _, effect in pairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe then return name end
    end
  end
end

local function icons_of(prototype)
  return table.deepcopy(prototype.icons or {{icon = prototype.icon, icon_size = prototype.icon_size or 64}})
end

local registry = {}
for _, permit in pairs(PERMITS) do
  local main = data.raw.technology[permit.tech]
  local item = data.raw.item[permit.item]
  if main and item and data.raw.planet[permit.planet] then
    local name = "ff-permit-" .. permit.tech
    local prerequisites = table.deepcopy(main.prerequisites or {})
    local function add_prerequisite(tech)
      if not tech or tech == permit.tech or not data.raw.technology[tech] then return end
      for _, p in pairs(prerequisites) do if p == tech then return end end
      prerequisites[#prerequisites + 1] = tech
    end
    add_prerequisite(DISCOVERY[permit.planet])
    add_prerequisite(loading_tech(permit.item))

    -- tech icon: the container with the planet in the corner
    local icons = {}
    for _, icon in pairs(icons_of(item)) do
      icon.scale = (icon.scale or (64 / (icon.icon_size or 64)) * 0.5) * 4
      if icon.shift then icon.shift = {(icon.shift[1] or icon.shift.x) * 4, (icon.shift[2] or icon.shift.y) * 4} end
      icons[#icons + 1] = icon
    end
    local planet = data.raw.planet[permit.planet]
    if planet.icon then
      icons[#icons + 1] = {icon = planet.icon, icon_size = planet.icon_size or 64, scale = 0.75, shift = {-40, 40}}
    end

    data:extend{{
      type = "technology",
      name = name,
      localised_name = {"technology-name.ff-permit", main.localised_name or {"technology-name." .. permit.tech}},
      localised_description = {"technology-description.ff-permit", tostring(permit.count), permit.item, permit.planet,
                               main.localised_name or {"technology-name." .. permit.tech}},
      icons = icons,
      prerequisites = prerequisites,
      research_trigger = {
        type = "scripted",
        trigger_description = {"technology-description.ff-permit-trigger", tostring(permit.count), permit.item, permit.planet},
      },
      effects = {},
      order = (main.order or "") .. "-permit",
    }}
    -- the key technology now needs the permit
    main.prerequisites = main.prerequisites or {}
    table.insert(main.prerequisites, name)
    registry[#registry + 1] = {permit = name, tech = permit.tech, item = permit.item, count = permit.count,
                               planet = permit.planet, min = permit.min, max = permit.max,
                               repair = repair_for(permit.planet)}
  end
end

-- Research post: where the containers are delivered
local chest = data.raw.container["steel-chest"]
if #registry > 0 and chest then
  local post = table.deepcopy(chest)
  post.name = "ff-research-post"
  post.localised_name = {"entity-name.ff-research-post"}
  post.localised_description = {"entity-description.ff-research-post"}
  post.icons = icons_of(chest)
  for _, icon in pairs(post.icons) do icon.tint = {r = 0.55, g = 0.9, b = 1, a = 1} end
  post.icon = nil
  post.minable = nil
  post.inventory_size = 8
  post.max_health = 1000            -- found damaged, to be repaired with repair packs (scripts/delivery-permits.lua)
  post.dying_explosion = data.raw.explosion["big-explosion"] and "big-explosion" or post.dying_explosion
  post.corpse = data.raw.corpse["big-remnants"] and "big-remnants" or post.corpse
  post.flags = {"placeable-neutral", "not-blueprintable", "not-deconstructable", "not-upgradable", "not-flammable"}
  post.collision_box = {{-0.9, -0.9}, {0.9, 0.9}}
  post.selection_box = {{-1, -1}, {1, 1}}
  post.map_color = {0.3, 0.9, 1}
  post.next_upgrade = nil
  post.fast_replaceable_group = nil
  post.placeable_by = nil
  post.surface_conditions = nil
  local function scale(t)
    if type(t) ~= "table" then return end
    if t.filename or t.filenames then
      t.scale = (t.scale or 1) * 2
      if t.shift then t.shift = {(t.shift[1] or t.shift.x) * 2, (t.shift[2] or t.shift.y) * 2} end
      if not t.draw_as_shadow then t.tint = {r = 0.55, g = 0.9, b = 1, a = 1} end
    end
    for _, v in pairs(t) do scale(v) end
  end
  scale(post.picture)
  data:extend{post, {type = "mod-data", name = "ff-delivery-permits", data = {permits = registry}}}

  -- The records leave in a cargo pod, like the ones space platform hubs send down: the game's own pod graphics
  local util = require("util")
  local POD = "__base__/graphics/entity/cargo-pod/"
  local sounds = {}
  for i = 1, 5 do sounds[i] = {filename = "__base__/sound/procession/cargo-pod-thruster-burst-" .. i .. ".ogg", volume = 0.7} end
  data:extend{
    {
      type = "sprite",
      name = "ff-cargo-pod",
      layers = {
        util.sprite_load(POD .. "pod-static-detached", {priority = "medium", scale = 0.5}),
        util.sprite_load(POD .. "pod-static-emission", {priority = "medium", scale = 0.5, blend_mode = "additive", draw_as_glow = true}),
      },
    },
    {
      type = "sprite",
      name = "ff-cargo-pod-shadow",
      layers = {util.sprite_load(POD .. "pod-static-shadow", {priority = "medium", scale = 0.5, draw_as_shadow = true})},
    },
    {
      type = "animation",
      name = "ff-cargo-pod-thruster",
      layers = {util.sprite_load(POD .. "pod-thruster-loop", {
        animation_speed = 0.5, scale = 0.25, frame_count = 10, draw_as_glow = true, blend_mode = "additive",
        shift = util.by_pixel(0, 64), priority = "medium"})},
    },
    {
      type = "sound",
      name = "ff-cargo-pod-launch",
      category = "game-effect",
      variations = sounds,
      audible_distance_modifier = 2,
    },
  }
end
