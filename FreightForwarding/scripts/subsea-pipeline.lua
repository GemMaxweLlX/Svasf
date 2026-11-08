-- Subsea pipeline (prototypes/subsea-pipeline.lua). Two pipeline landings face each other on one line across the
-- water. Open one: the window shows the landing opposite, the distance, the pipeline segments needed (taken from the
-- player's inventory) and the laying time. While the pipeline is laid a line grows across the water; when it is
-- done both landings are swapped to their "laid" twins, whose underground connection joins them.
-- Removing a laid landing breaks the pipeline: the other end goes back to an unlaid landing, the seabed pipe is lost.

local KINDS = {
  ["ff-pipeline-landing"] = {laid = "ff-pipeline-landing-laid", per_tile = 1},
  ["ff-duct-landing"] = {laid = "ff-duct-landing-laid", per_tile = 4},
}
local UNLAID = {}
for name, kind in pairs(KINDS) do UNLAID[kind.laid] = name end
local SEGMENT = "ff-pipeline-segment"
local MAX_DISTANCE = 255
local TICKS_PER_TILE = 30  -- 2 tiles per second

local function data()
  storage.ff_pipelines = storage.ff_pipelines or {jobs = {}, links = {}}
  return storage.ff_pipelines
end

local function kind_of(entity)
  local name = UNLAID[entity.name] or entity.name
  return KINDS[name] and name
end

local function is_landing(entity) return entity and entity.valid and kind_of(entity) ~= nil end

local VECTORS = {
  [defines.direction.north] = {0, -1}, [defines.direction.east] = {1, 0},
  [defines.direction.south] = {0, 1}, [defines.direction.west] = {-1, 0},
}
local OPPOSITE = {
  [defines.direction.north] = defines.direction.south, [defines.direction.south] = defines.direction.north,
  [defines.direction.east] = defines.direction.west, [defines.direction.west] = defines.direction.east,
}

local function distance(a, b)
  local dx, dy = a.position.x - b.position.x, a.position.y - b.position.y
  return math.sqrt(dx * dx + dy * dy)
end

local function segments(a, b) return math.ceil(distance(a, b)) * KINDS[kind_of(a)].per_tile end
local function laying_ticks(a, b) return math.ceil(distance(a, b)) * TICKS_PER_TILE end

local function format_time(ticks)
  local seconds = math.ceil(ticks / 60)
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function gps(entity)
  return string.format("[gps=%d,%d,%s]", math.floor(entity.position.x), math.floor(entity.position.y), entity.surface.name)
end

-- The landing of the same kind facing this one on its underground side (the side opposite to the pipe connection)
local function partner(landing)
  local v = VECTORS[landing.direction]
  if not v then return nil end
  local u = {-v[1], -v[2]}
  local kind = kind_of(landing)
  local p = landing.position
  local far = {p.x + u[1] * (MAX_DISTANCE + 1), p.y + u[2] * (MAX_DISTANCE + 1)}
  local area = {{math.min(p.x, far[1]) - 0.5, math.min(p.y, far[2]) - 0.5},
                {math.max(p.x, far[1]) + 0.5, math.max(p.y, far[2]) + 0.5}}
  local best, best_distance
  for _, other in pairs(landing.surface.find_entities_filtered{name = {kind, KINDS[kind].laid}, area = area,
                                                                 force = landing.force}) do
    if other ~= landing and other.direction == OPPOSITE[landing.direction] then
      local dx, dy = other.position.x - p.x, other.position.y - p.y
      local along = dx * u[1] + dy * u[2]
      local across = math.abs(dx * u[2] - dy * u[1])
      if along > 0 and across < 0.1 and (not best_distance or along < best_distance) then
        best, best_distance = other, along
      end
    end
  end
  return best
end

local function busy(entity)
  for _, job in pairs(data().jobs) do
    if job.a == entity or job.b == entity then return job end
  end
end

-- Swap a landing for another prototype in place, keeping fluid, health and quality
local function swap(entity, name)
  local surface, position, direction, force = entity.surface, entity.position, entity.direction, entity.force
  local quality, health = entity.quality, entity.health / entity.max_health
  local fluids = entity.get_fluid_contents()
  local old_unit = entity.unit_number
  entity.destroy()
  local new = surface.create_entity{name = name, position = position, direction = direction, force = force,
                                    quality = quality, raise_built = false, create_build_effect_smoke = false}
  if not new then return nil end
  new.health = new.max_health * health
  for fluid, amount in pairs(fluids) do new.insert_fluid{name = fluid, amount = amount} end
  data().links[old_unit] = nil
  return new
end

local function link(a, b)
  local laid_a = swap(a, KINDS[kind_of(a)].laid)
  local laid_b = swap(b, KINDS[kind_of(b)].laid)
  if laid_a and laid_b then
    data().links[laid_a.unit_number] = laid_b
    data().links[laid_b.unit_number] = laid_a
  end
  return laid_a, laid_b
end

---------------------------------------------------------------------------------------------------
-- Window

local function close_window(player)
  if player.gui.screen.ff_pipeline_window then player.gui.screen.ff_pipeline_window.destroy() end
end

local function open_window(player, landing)
  close_window(player)
  local frame = player.gui.screen.add{type = "frame", name = "ff_pipeline_window", direction = "vertical",
                                      caption = {"ff-pipeline.title"}}
  frame.location = {x = 40, y = 120}
  local inner = frame.add{type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical"}
  storage.ff_pipeline_windows = storage.ff_pipeline_windows or {}
  storage.ff_pipeline_windows[player.index] = landing
  local have = player.get_item_count(SEGMENT)
  inner.add{type = "label", caption = {"ff-pipeline.have", have}}
  local linked = data().links[landing.unit_number]
  if linked and linked.valid then
    inner.add{type = "label", caption = {"ff-pipeline.connected", gps(linked), math.floor(distance(landing, linked))}}
    return
  end
  local job = busy(landing)
  if job then
    local other = job.a == landing and job.b or job.a
    inner.add{type = "label", caption = {"ff-pipeline.laying", math.floor(distance(landing, other)),
                                          format_time(job.finish - game.tick)}}
    return
  end
  local other = partner(landing)
  if not other then
    inner.add{type = "label", caption = {"ff-pipeline.none", MAX_DISTANCE}}
    return
  end
  local need = segments(landing, other)
  inner.add{type = "label", caption = {"ff-pipeline.target", gps(other), math.floor(distance(landing, other))}}
  local cost = inner.add{type = "label", caption = {"ff-pipeline.cost", need, format_time(laying_ticks(landing, other))}}
  if need > have then cost.style.font_color = {1, 0.35, 0.3} end
  if busy(other) then
    inner.add{type = "label", caption = {"ff-pipeline.busy"}}
  else
    inner.add{type = "button", name = "ff_pipeline_lay", caption = {"ff-pipeline.lay"}}
  end
end

---------------------------------------------------------------------------------------------------
-- Laying

local function start(a, b)
  local line = rendering.draw_line{color = {0.35, 0.75, 1, 0.8}, width = 4, from = a, to = a, surface = a.surface,
                                   dash_length = 1, gap_length = 0.4}
  data().jobs[#data().jobs + 1] = {a = a, b = b, start = game.tick, finish = game.tick + laying_ticks(a, b), line = line}
end

local function try_start(player, landing)
  local other = partner(landing)
  if not other or busy(landing) or busy(other) or data().links[landing.unit_number] then return end
  local need = segments(landing, other)
  local have = player.get_item_count(SEGMENT)
  if have < need then
    player.print({"ff-pipeline.not-enough", need, have})
    return
  end
  player.remove_item{name = SEGMENT, count = need}
  start(landing, other)
  player.print({"ff-pipeline.started", math.floor(distance(landing, other)), need, format_time(laying_ticks(landing, other))})
end

local function update()
  local jobs = data().jobs
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if not (job.a.valid and job.b.valid) then
      if job.line and job.line.valid then job.line.destroy() end
      table.remove(jobs, i)
    elseif game.tick >= job.finish then
      if job.line and job.line.valid then job.line.destroy() end
      table.remove(jobs, i)
      local force = job.a.force
      local a, b = link(job.a, job.b)
      if a and b then force.print({"ff-pipeline.done", gps(b)}) end
    elseif job.line and job.line.valid then
      local f = (game.tick - job.start) / (job.finish - job.start)
      local from, to = job.a.position, job.b.position
      job.line.to = {from.x + (to.x - from.x) * f, from.y + (to.y - from.y) * f}
    end
  end
end

---------------------------------------------------------------------------------------------------

local function on_removed(event)
  local entity = event.entity
  if not (entity and entity.valid and UNLAID[entity.name]) then return end
  local links = data().links
  local other = links[entity.unit_number]
  links[entity.unit_number] = nil
  if other and other.valid and UNLAID[other.name] then
    links[other.unit_number] = nil
    local force = other.force
    local unlaid = swap(other, UNLAID[other.name])
    if unlaid then force.print({"ff-pipeline.broken", gps(unlaid)}) end
  end
end

local function on_gui_opened(event)
  if is_landing(event.entity) then open_window(game.get_player(event.player_index), event.entity) end
end

local function on_gui_closed(event)
  if is_landing(event.entity) then close_window(game.get_player(event.player_index)) end
end

local function on_gui_click(event)
  local element = event.element
  if not (element and element.valid and element.name == "ff_pipeline_lay") then return end
  local player = game.get_player(event.player_index)
  local landing = storage.ff_pipeline_windows and storage.ff_pipeline_windows[player.index]
  if not (landing and landing.valid) then return close_window(player) end
  try_start(player, landing)
  open_window(player, landing)
end

---@type ScriptLib
local SubseaPipeline = {}

SubseaPipeline.events = {
  [defines.events.on_gui_opened] = on_gui_opened,
  [defines.events.on_gui_closed] = on_gui_closed,
  [defines.events.on_gui_click] = on_gui_click,
  [defines.events.on_player_mined_entity] = on_removed,
  [defines.events.on_robot_mined_entity] = on_removed,
  [defines.events.on_entity_died] = on_removed,
  [defines.events.script_raised_destroy] = on_removed,
}

SubseaPipeline.on_nth_tick = {
  [60] = update,
}

SubseaPipeline.add_remote_interface = function()
  remote.add_interface("ff-subsea-pipeline", {
    -- for tests and scenarios: lay a pipeline without a player; returns segments, ticks or nil if no partner
    lay = function(landing)
      local other = partner(landing)
      if not other then return nil end
      start(landing, other)
      return segments(landing, other), laying_ticks(landing, other)
    end,
    partner = partner,
    jobs = function() return #data().jobs end,
  })
end

return SubseaPipeline
