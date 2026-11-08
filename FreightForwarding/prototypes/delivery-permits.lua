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

local DISCOVERY = {
  vulcanus = "planet-discovery-vulcanus", fulgora = "planet-discovery-fulgora",
  gleba = "planet-discovery-gleba", aquilo = "planet-discovery-aquilo",
}

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
                               planet = permit.planet, min = permit.min, max = permit.max}
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
end
