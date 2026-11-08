-- FF + Space Age exclusive: delivery permits (prototypes/delivery-permits.lua). Every 10 seconds:
--   * a permit whose prerequisites are researched gets a research post: a random place on land near the explored area
--     of its planet (once the planet has a surface), with a map tag and a chat message
--   * when the post holds the required containers, they are used up and the permit is granted; the post goes away
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

local function remove_post(record)
  if record.tag and record.tag.valid then record.tag.destroy() end
  if record.post and record.post.valid then record.post.destroy() end
  record.post, record.tag = nil, nil
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
        if not tech or tech.researched then
          if record.post then remove_post(record) end
        elseif record.post and record.post.valid then
          local inventory = record.post.get_inventory(defines.inventory.chest)
          if inventory.get_item_count(permit.item) >= permit.count then
            inventory.remove{name = permit.item, count = permit.count}
            local spill = inventory.get_contents()
            local surface, position = record.post.surface, record.post.position
            remove_post(record)
            for _, stack in pairs(spill) do  -- whatever else was put in is left on the ground
              surface.spill_item_stack{position = position, stack = {name = stack.name, count = stack.count, quality = stack.quality}}
            end
            tech.researched = true
            force.print({"ff-permit.granted", {"technology-name." .. permit.tech}, permit.count, permit.item})
          end
        elseif ready(force, permit) then
          local planet = game.planets[permit.planet]
          local surface = planet and planet.surface
          if surface then
            local position = find_spot(force, surface, permit)
            if position then
              local post = surface.create_entity{name = POST, position = position, force = force}
              if post then
                post.destructible = false
                record.post = post
                record.tag = force.add_chart_tag(surface, {position = position, icon = {type = "item", name = permit.item},
                                                           text = "× " .. permit.count})  -- tags take plain text
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
}

DeliveryPermits.events = {
  [defines.events.on_research_finished] = function(event)
    -- a permit can't be researched in labs; if it is finished another way (cheats, editor), drop its post
    local name = event.research.name
    if name:sub(1, 10) == "ff-permit-" then
      local record = state(event.research.force)[name]
      if record then remove_post(record) end
    end
  end,
}

DeliveryPermits.add_remote_interface = function()
  remote.add_interface("ff-delivery-permits", {
    update = update,
    post = function(force_index, permit)
      local record = state(game.forces[force_index or 1])[permit]
      return record and record.post
    end,
  })
end

return DeliveryPermits
