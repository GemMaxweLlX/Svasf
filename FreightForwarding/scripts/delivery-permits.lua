-- FF + Space Age exclusive: delivery permits (prototypes/delivery-permits.lua). Every 10 seconds:
--   * a permit whose prerequisites are researched gets a research post: a random place on land near the explored area
--     of its planet (once the planet has a surface), with a map tag and a chat message
--   * the post is found damaged: repair materials (per planet) have to be delivered into it first; then it is restored
--     and takes the delivery
--   * when the repaired post holds the required containers, they are used up, a cargo pod takes off from the post
--     and the permit is granted; 5 minutes later the post blows itself up
-- Saves where a key technology is already researched get its permit right away.

local POST = "ff-research-post"

local function permits()
  local entry = prototypes.mod_data["ff-delivery-permits"]
  return entry and entry.data.permits or {}
end

local function state(force)
  storage.ff_permits = storage.ff_permits or {}
  storage.ff_permits[force.index] = storage.ff_permits[force.index] or {}
  return storage.ff_permits[force.index]
end

local function rng()
  storage.ff_permit_rng = storage.ff_permit_rng or game.create_random_generator(4711)
  return storage.ff_permit_rng
end

local function ready(force, permit)
  local tech = force.technologies[permit.permit]
  if not tech or tech.researched then return false end
  for _, prerequisite in pairs(tech.prerequisites) do
    if not prerequisite.researched then return false end
  end
  return true
end

--- Random land position near the explored area: a charted chunk at the permit's distance from the spawn point.
--- Falls back to generated chunks, then to the nearest suitable spot.
local function find_spot(force, surface, permit)
  local origin = force.get_spawn_position(surface)
  local function in_range(chunk, min, max)
    local x, y = chunk.x * 32 + 16 - origin.x, chunk.y * 32 + 16 - origin.y
    local d = math.sqrt(x * x + y * y)
    return d >= min and d <= max
  end
  local charted, generated = {}, {}
  for chunk in surface.get_chunks() do
    if surface.is_chunk_generated(chunk) and in_range(chunk, permit.min, permit.max) then
      if force.is_chunk_charted(surface, chunk) then charted[#charted + 1] = chunk else generated[#generated + 1] = chunk end
    end
  end
  for _, pool in pairs{charted, generated} do
    for _ = 1, math.min(#pool, 40) do
      local chunk = pool[rng()(1, #pool)]
      local center = {chunk.x * 32 + 16, chunk.y * 32 + 16}
      local position = surface.find_non_colliding_position(POST, center, 16, 1, true)
      if position then return position end
    end
  end
  -- nothing generated that far yet: generate some chunks in range around a random direction and try again later
  local angle = rng()() * 2 * math.pi
  local d = (permit.min + permit.max) / 2
  surface.request_to_generate_chunks({origin.x + math.cos(angle) * d, origin.y + math.sin(angle) * d}, 1)
end

local function gps(entity)
  return string.format("[gps=%d,%d,%s]", math.floor(entity.position.x), math.floor(entity.position.y), entity.surface.name)
end

local SPAWN_HEALTH = 0.15                -- a post is found damaged; repair materials restore it
local SELF_DESTRUCT = 5 * 60 * 60       -- 5 minutes after the delivery the post blows itself up
local ROCKET_TICKS = 150

local function remove_post(record)
  if record.tag and record.tag.valid then record.tag.destroy() end
  if record.label and record.label.valid then record.label.destroy() end
  if record.post and record.post.valid then record.post.destroy() end
  record.post, record.tag, record.label, record.stage, record.explode_at = nil, nil, nil, nil, nil
end

local function set_label(record, text, color)
  if not (record.post and record.post.valid) then return end
  if record.label and record.label.valid then
    record.label.text = text
    record.label.color = color
  else
    record.label = rendering.draw_text{text = text, surface = record.post.surface, target = {entity = record.post, offset = {0, -2.2}},
                                       color = color, scale = 1.4, alignment = "center", use_rich_text = true}
  end
end

local function spill_contents(post)
  local inventory = post.get_inventory(defines.inventory.chest)
  for _, stack in pairs(inventory.get_contents()) do
    post.surface.spill_item_stack{position = post.position, stack = {name = stack.name, count = stack.count, quality = stack.quality}}
  end
  inventory.clear()
end

--- The records leave in a cargo pod (the one space platform hubs send down), rising from the post with its
--- thrusters burning, its shadow sliding away on the ground
local function launch_rocket(post)
  local surface, x, y = post.surface, post.position.x, post.position.y
  local pod = rendering.draw_sprite{sprite = "ff-cargo-pod", surface = surface, target = {x, y - 1}, render_layer = "air-object"}
  local flame = rendering.draw_animation{animation = "ff-cargo-pod-thruster", surface = surface, target = {x, y - 1},
                                         render_layer = "air-object", animation_speed = 1}
  local shadow = rendering.draw_sprite{sprite = "ff-cargo-pod-shadow", surface = surface, target = {x, y}}
  storage.ff_permit_rockets = storage.ff_permit_rockets or {}
  table.insert(storage.ff_permit_rockets, {pod = pod, flame = flame, shadow = shadow, surface = surface, x = x, y = y, t = 0})
  surface.create_entity{name = "explosion", position = post.position}
  surface.play_sound{path = "ff-cargo-pod-launch", position = post.position}
end

local function animate_rockets()
  local rockets = storage.ff_permit_rockets
  if not rockets or #rockets == 0 then return end
  for i = #rockets, 1, -1 do
    local rocket = rockets[i]
    rocket.t = rocket.t + 1
    local rise = 0.002 * rocket.t * rocket.t  -- accelerating upwards
    local position = {rocket.x, rocket.y - 1 - rise}
    for _, object in pairs{rocket.pod, rocket.flame} do
      if object and object.valid then object.target = position end
    end
    if rocket.shadow and rocket.shadow.valid then  -- the shadow slides away and fades as the pod climbs
      rocket.shadow.target = {rocket.x + rise * 0.6, rocket.y + rise * 0.3}
      rocket.shadow.color = {1, 1, 1, math.max(0, 1 - rocket.t / ROCKET_TICKS)}
    end
    if rocket.surface.valid and rocket.t % 3 == 0 and rocket.t < ROCKET_TICKS * 0.6 then
      rocket.surface.create_trivial_smoke{name = "smoke-fast", position = {rocket.x, rocket.y - rise}}
    end
    if rocket.t >= ROCKET_TICKS or not rocket.surface.valid then
      for _, object in pairs{rocket.pod, rocket.flame, rocket.shadow, rocket.sprite} do
        if object and object.valid then object.destroy() end
      end
      table.remove(rockets, i)
    end
  end
end

local function format_time(ticks)
  local seconds = math.max(0, math.ceil(ticks / 60))
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

--- Every second: repair state, delivery, rocket and self-destruct countdown of the posts
local function tick_posts()
  local list = permits()
  if #list == 0 or not storage.ff_permits then return end
  for force_index, records in pairs(storage.ff_permits) do
    local force = game.forces[force_index]
    for _, permit in pairs(list) do
      local record = records[permit.permit]
      local post = record and record.post
      if post and post.valid then
        if record.stage == "damaged" then
          -- repair: the materials have to be delivered into the post, then it is restored
          local inventory = post.get_inventory(defines.inventory.chest)
          local progress, complete = {""}, true
          for _, need in pairs(permit.repair or {}) do
            local have = math.min(inventory.get_item_count(need.item), need.count)
            if have < need.count then complete = false end
            progress[#progress + 1] = string.format("[item=%s] %d/%d  ", need.item, have, need.count)
          end
          if complete then
            for _, need in pairs(permit.repair or {}) do inventory.remove{name = need.item, count = need.count} end
            post.health = post.max_health
            record.stage = "ready"
            force.print({"ff-permit.repaired", {"technology-name." .. permit.tech}, permit.count, permit.item, gps(post)})
          else
            set_label(record, {"ff-permit.needs-repair", progress}, {1, 0.45, 0.3})
          end
        end
        if record.stage == "ready" then
          set_label(record, {"ff-permit.ready", permit.count, permit.item}, {0.4, 1, 0.6})
          local inventory = post.get_inventory(defines.inventory.chest)
          if inventory.get_item_count(permit.item) >= permit.count then
            inventory.remove{name = permit.item, count = permit.count}
            spill_contents(post)  -- whatever else was put in is left on the ground
            launch_rocket(post)
            record.stage = "launched"  -- before granting: on_research_finished must not remove this post
            record.explode_at = game.tick + SELF_DESTRUCT
            force.technologies[permit.permit].researched = true
            force.print({"ff-permit.granted", {"technology-name." .. permit.tech}, permit.count, permit.item})
            post.operable = false
            if record.tag and record.tag.valid then record.tag.destroy() end
          end
        elseif record.stage == "launched" then
          local left = record.explode_at - game.tick
          if left <= 0 then
            spill_contents(post)
            if record.label and record.label.valid then record.label.destroy() end
            post.destructible = true
            post.die()
            record.post, record.label, record.stage, record.explode_at = nil, nil, nil, nil
          else
            set_label(record, {"ff-permit.countdown", format_time(left)}, {1, 0.8, 0.2})
          end
        end
      end
    end
  end
end

local function update()
  local list = permits()
  if #list == 0 then return end
  for _, force in pairs(game.forces) do
    if #force.players > 0 or force.name == "player" then
      local records = state(force)
      for _, permit in pairs(list) do
        local record = records[permit.permit] or {}
        records[permit.permit] = record
        local tech = force.technologies[permit.permit]
        local key_tech = force.technologies[permit.tech]
        if tech and not tech.researched and key_tech and key_tech.researched then
          tech.researched = true  -- older save: the key technology was researched before permits existed
        end
        if record.stage == "launched" then
          -- counting down to self-destruction (tick_posts)
        elseif not tech or tech.researched then
          if record.post then remove_post(record) end
        elseif record.post and record.post.valid then
          -- waiting for repair / delivery (tick_posts)
        elseif ready(force, permit) then
          local planet = game.planets[permit.planet]
          local surface = planet and planet.surface
          if surface then
            if record.post or record.tag then remove_post(record) end  -- the old post was destroyed: a new one
            local position = find_spot(force, surface, permit)
            if position then
              local post = surface.create_entity{name = POST, position = position, force = force}
              if post then
                post.health = post.max_health * SPAWN_HEALTH
                record.post = post
                record.stage = "damaged"
                record.tag = force.add_chart_tag(surface, {position = position, icon = {type = "item", name = permit.item},
                                                           text = "× " .. permit.count})  -- tags take plain text
                local progress = {""}
                for _, need in pairs(permit.repair or {}) do
                  progress[#progress + 1] = string.format("[item=%s] 0/%d  ", need.item, need.count)
                end
                set_label(record, {"ff-permit.needs-repair", progress}, {1, 0.45, 0.3})
                force.print({"ff-permit.post", {"technology-name." .. permit.tech}, permit.count, permit.item, gps(post)})
              end
            end
          end
        end
      end
    end
  end
end

---@type ScriptLib
local DeliveryPermits = {}

DeliveryPermits.on_nth_tick = {
  [600] = function()
    if script.active_mods["space-age"] then update() end
  end,
  [60] = function()
    if script.active_mods["space-age"] then tick_posts() end
  end,
}

DeliveryPermits.events = {
  [defines.events.on_tick] = animate_rockets,
  [defines.events.on_research_finished] = function(event)
    -- a permit can't be researched in labs; if it is finished another way (cheats, editor), drop its post
    local name = event.research.name
    if name:sub(1, 10) == "ff-permit-" then
      local record = state(event.research.force)[name]
      if record and record.stage ~= "launched" then remove_post(record) end
    end
  end,
}

DeliveryPermits.add_remote_interface = function()
  remote.add_interface("ff-delivery-permits", {
    update = update,
    tick_posts = tick_posts,
    post = function(force_index, permit)
      local record = state(game.forces[force_index or 1])[permit]
      return record and record.post
    end,
  })
end

return DeliveryPermits
