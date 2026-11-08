-- Subsea cable. A cable landing is both ends at once: build one on each shore, open one of them and choose where the
-- cable goes. The window shows, for every other landing on the surface, the distance, the subsea cable needed (one per
-- tile, taken from the player's inventory) and the laying time. While it is being laid a line grows towards the other
-- landing; when done, the landings are joined by a normal copper wire, which carries power both ways.
-- Removing a landing cuts the cable (the cable on the seabed is lost).

local LANDING = "ff-cable-landing"
local CABLE = "ff-subsea-cable"
local MAX_DISTANCE = 1000      -- tiles
local TICKS_PER_TILE = 30      -- laying speed: 2 tiles per second

local function data()
  storage.ff_cables = storage.ff_cables or {jobs = {}}
  return storage.ff_cables
end

local function distance(a, b)
  local dx, dy = a.position.x - b.position.x, a.position.y - b.position.y
  return math.sqrt(dx * dx + dy * dy)
end

local function cable_needed(a, b) return math.ceil(distance(a, b)) end
local function laying_ticks(a, b) return math.ceil(distance(a, b)) * TICKS_PER_TILE end

local function format_time(ticks)
  local seconds = math.ceil(ticks / 60)
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function copper(entity) return entity.get_wire_connector(defines.wire_connector_id.pole_copper, true) end

local function linked(a, b)
  for _, connection in pairs(copper(a).connections) do
    if connection.target.owner == b then return true end
  end
  return false
end

local function busy(entity)
  for _, job in pairs(data().jobs) do
    if job.a == entity or job.b == entity then return job end
  end
end

---------------------------------------------------------------------------------------------------
-- Window

local function close_window(player)
  if player.gui.screen.ff_cable_window then player.gui.screen.ff_cable_window.destroy() end
end

local function open_window(player, landing)
  close_window(player)
  local frame = player.gui.screen.add{type = "frame", name = "ff_cable_window", direction = "vertical",
                                      caption = {"ff-cable.title"}}
  frame.location = {x = 40, y = 120}
  local inner = frame.add{type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical"}
  local have = player.get_item_count(CABLE)
  inner.add{type = "label", caption = {"ff-cable.have", have}}
  local job = busy(landing)
  if job then
    local other = job.a == landing and job.b or job.a
    inner.add{type = "label", caption = {"ff-cable.laying", math.floor(distance(landing, other)),
                                          format_time(job.finish - game.tick)}}
    return
  end
  local candidates = landing.surface.find_entities_filtered{name = LANDING, force = landing.force,
                                                            position = landing.position, radius = MAX_DISTANCE}
  table.sort(candidates, function(x, y) return distance(landing, x) < distance(landing, y) end)
  local grid = inner.add{type = "table", column_count = 5, draw_horizontal_line_after_headers = true}
  for _, header in pairs{"to", "distance", "cable", "time", ""} do
    grid.add{type = "label", caption = header ~= "" and {"ff-cable.col-" .. header} or "", style = "bold_label"}
  end
  local rows = 0
  for _, other in pairs(candidates) do
    if other ~= landing then
      rows = rows + 1
      local need = cable_needed(landing, other)
      grid.add{type = "label", caption = string.format("[gps=%d,%d,%s]", math.floor(other.position.x),
                                                       math.floor(other.position.y), other.surface.name)}
      grid.add{type = "label", caption = tostring(math.floor(distance(landing, other)))}
      local cable = grid.add{type = "label", caption = tostring(need)}
      if need > have then cable.style.font_color = {1, 0.35, 0.3} end
      grid.add{type = "label", caption = format_time(laying_ticks(landing, other))}
      if linked(landing, other) then
        grid.add{type = "label", caption = {"ff-cable.connected"}}
      elseif busy(other) then
        grid.add{type = "label", caption = {"ff-cable.busy"}}
      else
        grid.add{type = "button", name = "ff_cable_lay_" .. other.unit_number, caption = {"ff-cable.lay"},
                 tags = {from = landing.unit_number}}
      end
    end
  end
  if rows == 0 then inner.add{type = "label", caption = {"ff-cable.none", MAX_DISTANCE}} end
  storage.ff_cable_windows = storage.ff_cable_windows or {}
  storage.ff_cable_windows[player.index] = landing
end

---------------------------------------------------------------------------------------------------
-- Laying

local function start(player, landing, other)
  if not (landing.valid and other.valid) or busy(landing) or busy(other) or linked(landing, other) then return end
  local need = cable_needed(landing, other)
  if player.get_item_count(CABLE) < need then
    player.print({"ff-cable.not-enough", need, player.get_item_count(CABLE)})
    return
  end
  player.remove_item{name = CABLE, count = need}
  local line = rendering.draw_line{color = {0.3, 0.9, 0.8, 0.8}, width = 3, from = landing, to = landing,
                                   surface = landing.surface, dash_length = 1, gap_length = 0.5}
  data().jobs[#data().jobs + 1] = {a = landing, b = other, start = game.tick,
                                   finish = game.tick + laying_ticks(landing, other), line = line}
  player.print({"ff-cable.started", math.floor(distance(landing, other)), need, format_time(laying_ticks(landing, other))})
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
      copper(job.a).connect_to(copper(job.b), false, defines.wire_origin.player)
      job.a.force.print({"ff-cable.done", string.format("[gps=%d,%d,%s]", math.floor(job.b.position.x),
                                                         math.floor(job.b.position.y), job.b.surface.name)})
      table.remove(jobs, i)
    elseif job.line and job.line.valid then
      local f = (game.tick - job.start) / (job.finish - job.start)
      local from, to = job.a.position, job.b.position
      job.line.to = {from.x + (to.x - from.x) * f, from.y + (to.y - from.y) * f}
    end
  end
end

---------------------------------------------------------------------------------------------------

local function on_gui_opened(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == LANDING then
    open_window(game.get_player(event.player_index), entity)
  end
end

local function on_gui_closed(event)
  if event.entity and event.entity.valid and event.entity.name == LANDING then
    close_window(game.get_player(event.player_index))
  end
end

local function on_gui_click(event)
  local element = event.element
  if not (element and element.valid and element.name:sub(1, 13) == "ff_cable_lay_") then return end
  local player = game.get_player(event.player_index)
  local landing = storage.ff_cable_windows and storage.ff_cable_windows[player.index]
  local other_unit = tonumber(element.name:sub(14))
  if not (landing and landing.valid) then return end
  for _, other in pairs(landing.surface.find_entities_filtered{name = LANDING, position = landing.position, radius = MAX_DISTANCE}) do
    if other.unit_number == other_unit then
      start(player, landing, other)
      break
    end
  end
  open_window(player, landing)
end

---@type ScriptLib
local SubseaCable = {}

SubseaCable.events = {
  [defines.events.on_gui_opened] = on_gui_opened,
  [defines.events.on_gui_closed] = on_gui_closed,
  [defines.events.on_gui_click] = on_gui_click,
}

SubseaCable.on_nth_tick = {
  [60] = update,
}

SubseaCable.add_remote_interface = function()
  remote.add_interface("ff-subsea-cable", {
    -- for tests and scenarios: lay a cable without a player
    lay = function(a, b)
      local line = rendering.draw_line{color = {0.3, 0.9, 0.8, 0.8}, width = 3, from = a, to = a, surface = a.surface}
      data().jobs[#data().jobs + 1] = {a = a, b = b, start = game.tick, finish = game.tick + laying_ticks(a, b), line = line}
      return cable_needed(a, b), laying_ticks(a, b)
    end,
    jobs = function() return #data().jobs end,
  })
end

return SubseaCable
