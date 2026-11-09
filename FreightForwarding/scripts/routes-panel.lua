-- Routes panel (shortcut bar button "ff-routes-panel"): every train and ship of the force, with where it is, what it
-- is doing, how long it has been doing it, how full it is and its main cargo. Refreshed every 2 seconds while open.
-- Filter: all / ships / trains. Sorted by how long they have been in the same state (stuck vehicles first).

local SHORTCUT = "ff-routes-panel"
local FRAME = "ff_routes_panel"
local MAX_ROWS = 60

local ship_parts
local function is_ship(train)
  if not ship_parts then
    ship_parts = {}
    for _, entry in pairs(prototypes.mod_data) do
      if entry.data_type == "cargo-ships.ship-definition" then
        if entry.data.name then ship_parts[entry.data.name] = true end
        if entry.data.engine then ship_parts[entry.data.engine] = true end
      end
    end
  end
  return train.front_stock and ship_parts[train.front_stock.name] or false
end

-- train state name -> panel state (names, so states missing in this version of the game are skipped)
local STATE_NAMES = {
  on_the_path = "moving", path_lost = "no-path", no_schedule = "no-schedule", no_path = "no-path",
  arrive_signal = "moving", wait_signal = "signal", arrive_station = "moving", wait_station = "station",
  manual_control_stop = "manual", manual_control = "manual", destination_full = "full",
}
local STATE_KEYS = {}
for name, key in pairs(STATE_NAMES) do
  if defines.train_state[name] then STATE_KEYS[defines.train_state[name]] = key end
end
local BAD = {["no-path"] = true, ["no-schedule"] = true, full = true}

local function since()
  storage.ff_routes = storage.ff_routes or {}
  return storage.ff_routes
end

local function format_time(ticks)
  local seconds = math.floor(ticks / 60)
  local h, m, s = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

local function cargo(train)
  local items, used, slots = {}, 0, 0
  for _, wagon in pairs(train.cargo_wagons) do
    local inventory = wagon.get_inventory(defines.inventory.cargo_wagon)
    if inventory then
      slots = slots + #inventory
      used = used + #inventory - inventory.count_empty_stacks()
      for _, stack in pairs(inventory.get_contents()) do items[stack.name] = (items[stack.name] or 0) + stack.count end
    end
  end
  local fluids = train.get_fluid_contents()
  local list = {}
  for name, count in pairs(items) do list[#list + 1] = {"item", name, count} end
  for name, amount in pairs(fluids) do list[#list + 1] = {"fluid", name, math.floor(amount)} end
  table.sort(list, function(a, b) return a[3] > b[3] end)
  local text = ""
  for i = 1, math.min(3, #list) do text = text .. string.format("[%s=%s]%d ", list[i][1], list[i][2], list[i][3]) end
  local fill = slots > 0 and math.floor(used * 100 / slots + 0.5) or nil
  return text, fill
end

local function status(train)
  local key = STATE_KEYS[train.state] or "moving"
  local where = ""
  if key == "station" and train.station and train.station.valid then where = train.station.backer_name
  elseif key == "moving" and train.path_end_stop and train.path_end_stop.valid then where = train.path_end_stop.backer_name end
  return key, where
end

local function build(player)
  local frame = player.gui.left[FRAME]
  if not frame then return end
  local filter = frame.ff_routes_filter and frame.ff_routes_filter.selected_index or 1
  if frame.ff_routes_body then frame.ff_routes_body.destroy() end
  local body = frame.add{type = "scroll-pane", name = "ff_routes_body"}
  body.style.maximal_height = 500
  local grid = body.add{type = "table", column_count = 6, draw_horizontal_line_after_headers = true}
  for _, header in pairs{"vehicle", "state", "where", "time", "fill", "cargo"} do
    grid.add{type = "label", caption = {"ff-routes.col-" .. header}, style = "bold_label"}
  end
  local times = since()
  local rows = {}
  for _, train in pairs(game.train_manager.get_trains{force = player.force}) do
    local ship = is_ship(train)
    if filter == 1 or (filter == 2 and ship) or (filter == 3 and not ship) then
      local key, where = status(train)
      local record = times[train.id]
      rows[#rows + 1] = {train = train, ship = ship, key = key, where = where,
                         time = record and (game.tick - record.tick) or 0}
    end
  end
  table.sort(rows, function(a, b)
    if BAD[a.key] ~= BAD[b.key] then return BAD[a.key] == true end
    return a.time > b.time
  end)
  for i = 1, math.min(MAX_ROWS, #rows) do
    local row = rows[i]
    local train = row.train
    local front = train.front_stock
    local position = front and front.position or {x = 0, y = 0}
    local surface = front and front.surface.name or "nauvis"
    grid.add{type = "label", caption = string.format("[item=%s] #%d [gps=%d,%d,%s]", front and front.name or "locomotive",
                                                     train.id, math.floor(position.x), math.floor(position.y), surface),
             tooltip = row.ship and {"ff-routes.ship"} or {"ff-routes.train"}}
    local state = grid.add{type = "label", caption = {"ff-routes.state-" .. row.key}}
    if BAD[row.key] then state.style.font_color = {1, 0.4, 0.3} end
    grid.add{type = "label", caption = row.where}
    grid.add{type = "label", caption = format_time(row.time)}
    local text, fill = cargo(train)
    grid.add{type = "label", caption = fill and (fill .. "%") or "—"}
    grid.add{type = "label", caption = text}
  end
  if #rows == 0 then body.add{type = "label", caption = {"ff-routes.none"}} end
  if #rows > MAX_ROWS then body.add{type = "label", caption = {"ff-routes.more", #rows - MAX_ROWS}} end
end

local function toggle(player)
  local frame = player.gui.left[FRAME]
  if frame then
    frame.destroy()
    player.set_shortcut_toggled(SHORTCUT, false)
    return
  end
  frame = player.gui.left.add{type = "frame", name = FRAME, direction = "vertical", caption = {"ff-routes.title"}}
  frame.add{type = "drop-down", name = "ff_routes_filter", selected_index = 1,
            items = {{"ff-routes.filter-all"}, {"ff-routes.filter-ships"}, {"ff-routes.filter-trains"}}}
  player.set_shortcut_toggled(SHORTCUT, true)
  build(player)
end

-- Remember when each train entered its current state
local function on_train_changed_state(event)
  local train = event.train
  since()[train.id] = {tick = game.tick, state = train.state}
end

local function update()
  for _, player in pairs(game.connected_players) do
    if player.gui.left[FRAME] then build(player) end
  end
  -- forget trains that no longer exist (every refresh is cheap enough: ids only)
  local times = since()
  if game.tick % 18000 < 120 then
    local alive = {}
    for _, train in pairs(game.train_manager.get_trains{}) do alive[train.id] = true end
    for id in pairs(times) do if not alive[id] then times[id] = nil end end
  end
end

local function on_lua_shortcut(event)
  if event.prototype_name == SHORTCUT then toggle(game.get_player(event.player_index)) end
end

local function on_gui_selection_state_changed(event)
  if event.element.valid and event.element.name == "ff_routes_filter" then build(game.get_player(event.player_index)) end
end

---@type ScriptLib
local RoutesPanel = {}

RoutesPanel.events = {
  [defines.events.on_lua_shortcut] = on_lua_shortcut,
  [defines.events.on_train_changed_state] = on_train_changed_state,
  [defines.events.on_gui_selection_state_changed] = on_gui_selection_state_changed,
}

RoutesPanel.on_nth_tick = {
  [120] = update,
}

RoutesPanel.add_remote_interface = function()
  remote.add_interface("ff-routes-panel", {
    -- for tests: rows as the panel would show them for a force
    rows = function(force_name)
      local result = {}
      for _, train in pairs(game.train_manager.get_trains{force = force_name}) do
        local key, where = status(train)
        local text, fill = cargo(train)
        result[#result + 1] = {id = train.id, ship = is_ship(train), state = key, where = where, fill = fill, cargo = text}
      end
      return result
    end,
  })
end

return RoutesPanel
