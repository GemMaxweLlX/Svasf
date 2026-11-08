-- Interstellar freight contracts (Space Age) and the freight panel (all games with Intermodal Containers).
--
-- Lore: the Long Caravan, interstellar haulers on a route centuries long, can't afford to brake; at the solar system
-- edge they take cargo on the fly. Consignments (and their light containers) leave with it for good. The caravan pays
-- with navigation data, hence the logistics bonus.
--
-- Contracts: every 10 seconds, freight consignments in the hub of a space platform at the solar system edge (or the
-- shattered planet beyond it) are taken in. The first fulfilled contract wins the game (Space Age's own victory for
-- just reaching the edge is turned off). After that, contracts go on: each one is bigger than the last and every
-- fulfilled contract gives a logistics bonus (robot speed, train and ship braking force).
--
-- Freight panel (top left): progress of the current contract, and a button for freight statistics per planet
-- (containers packed, unpacked and damaged), read from the force's production statistics.

local ITEM = "ff-freight-consignment"
local LOCATIONS = {["solar-system-edge"] = true, ["shattered-planet"] = true}
local BONUS_ROBOT_SPEED = 0.1
local BONUS_BRAKING = 0.1

---------------------------------------------------------------------------------------------------
-- Contract state

local function base_size()
  return settings.startup["ff-freight-contract-size"].value
end

--- Size of contract number n (1, 2, 3...): the base size, then +50% of it for every contract after the first
local function contract_size(n)
  return math.floor(base_size() * (1 + 0.5 * (n - 1)))
end

local function get_state(force)
  storage.ff_contract = storage.ff_contract or {}
  local state = storage.ff_contract[force.index]
  if type(state) ~= "table" then  -- older saves stored only the delivered count
    state = {number = 1, delivered = state or 0}
    storage.ff_contract[force.index] = state
  end
  return state
end

local function contract_available(force)
  local tech = force.technologies["ff-interstellar-freight-contract"]
  return tech and tech.researched
end

---------------------------------------------------------------------------------------------------
-- Freight statistics

local container_names
local function get_container_names()
  if container_names then return container_names end
  container_names = {filled = {}, damaged = {}}
  for name, item in pairs(prototypes.item) do
    if name:sub(1, 11) == "ff-damaged-" then
      container_names.damaged[#container_names.damaged + 1] = name
    elseif name:sub(1, 13) == "ic-container-" and prototypes.recipe["ic-load-" .. name:sub(14)] then
      container_names.filled[#container_names.filled + 1] = name
    else
      for _, prefix in pairs{"ff-reefer-", "ff-light-", "ff-cryo-"} do
        if name:sub(1, #prefix) == prefix and prototypes.recipe[prefix .. "load-" .. name:sub(#prefix + 1)] then
          container_names.filled[#container_names.filled + 1] = name
        end
      end
    end
  end
  return container_names
end

local function freight_statistics(force)
  local names = get_container_names()
  local rows = {}
  for _, surface in pairs(game.surfaces) do
    if not surface.platform then
      local stats = force.get_item_production_statistics(surface)
      local packed, unpacked, damaged = 0, 0, 0
      for _, name in pairs(names.filled) do
        packed = packed + stats.get_input_count(name)
        unpacked = unpacked + stats.get_output_count(name)
      end
      for _, name in pairs(names.damaged) do
        damaged = damaged + stats.get_input_count(name)
      end
      if packed + unpacked + damaged > 0 or surface.name == "nauvis" then
        rows[#rows + 1] = {
          name = surface.planet and surface.planet.prototype.localised_name or surface.name,
          packed = packed, unpacked = unpacked, damaged = damaged,
        }
      end
    end
  end
  return rows
end

---------------------------------------------------------------------------------------------------
-- GUI

local function show_panel(player)
  local setting = player.mod_settings["ff-show-freight-panel"]
  return (setting == nil or setting.value) and prototypes.item["ic-container"] ~= nil
end

local function update_panel(player)
  local top = player.gui.top
  if top.ff_freight_panel then top.ff_freight_panel.destroy() end
  if not show_panel(player) then return end
  local frame = top.add{type = "frame", name = "ff_freight_panel", direction = "vertical", caption = {"ff-gui.panel-title"}}
  local force = player.force
  if prototypes.item[ITEM] and contract_available(force) then
    local state = get_state(force)
    local goal = contract_size(state.number)
    frame.add{type = "label", caption = {"ff-gui.contract", state.number, state.delivered, goal}}
    local bar = frame.add{type = "progressbar", value = math.min(1, state.delivered / goal)}
    bar.style.horizontally_stretchable = true
    if (state.completed or 0) > 0 then
      frame.add{type = "label", caption = {"ff-gui.bonus", state.completed,
        math.floor(state.completed * BONUS_ROBOT_SPEED * 100 + 0.5), math.floor(state.completed * BONUS_BRAKING * 100 + 0.5)}}
    end
  end
  frame.add{type = "button", name = "ff_freight_stats_button", caption = {"ff-gui.stats-button"}}
end

local function update_all_panels(force)
  for _, player in pairs((force and force.players) or game.players) do update_panel(player) end
end

local function toggle_stats(player)
  local screen = player.gui.screen
  if screen.ff_freight_stats then
    screen.ff_freight_stats.destroy()
    return
  end
  local frame = screen.add{type = "frame", name = "ff_freight_stats", direction = "vertical"}
  local titlebar = frame.add{type = "flow", direction = "horizontal"}
  titlebar.drag_target = frame
  titlebar.add{type = "label", caption = {"ff-gui.stats-title"}, style = "frame_title", ignored_by_interaction = true}
  local filler = titlebar.add{type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true}
  filler.style.horizontally_stretchable = true
  filler.style.height = 24
  titlebar.add{type = "sprite-button", name = "ff_freight_stats_close", sprite = "utility/close", style = "frame_action_button"}

  local inner = frame.add{type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical"}
  local table = inner.add{type = "table", column_count = 4, draw_horizontal_line_after_headers = true}
  for _, header in pairs{"planet", "packed", "unpacked", "damaged"} do
    table.add{type = "label", caption = {"ff-gui.stats-" .. header}, style = "bold_label"}
  end
  for _, row in pairs(freight_statistics(player.force)) do
    table.add{type = "label", caption = row.name}
    table.add{type = "label", caption = tostring(math.floor(row.packed))}
    table.add{type = "label", caption = tostring(math.floor(row.unpacked))}
    table.add{type = "label", caption = tostring(math.floor(row.damaged))}
  end
  local state = prototypes.item[ITEM] and get_state(player.force)
  if state and state.total then
    inner.add{type = "label", caption = {"ff-gui.stats-consignments", state.total}}
  end
  frame.force_auto_center()
  player.opened = frame
end

---------------------------------------------------------------------------------------------------
-- Delivery

local function apply_bonus(force)
  force.worker_robots_speed_modifier = force.worker_robots_speed_modifier + BONUS_ROBOT_SPEED
  force.train_braking_force_bonus = force.train_braking_force_bonus + BONUS_BRAKING
end

local function victory(force)
  if remote.interfaces["better-victory-screen"] and remote.interfaces["better-victory-screen"]["trigger_victory"] then
    remote.call("better-victory-screen", "trigger_victory", force)
  else
    game.reset_game_state()
    game.enable_galaxy_of_fame_button = true
    game.set_win_ending_info{title = {"ff-contract.victory-title"}, message = {"ff-contract.victory-message"}}
    game.set_game_state{game_finished = true, player_won = true, can_continue = true, victorious_force = force}
  end
end

local function check()
  if not prototypes.item[ITEM] then return end
  for _, force in pairs(game.forces) do
    local state = get_state(force)
    local changed = false
    for _, platform in pairs(force.platforms) do
      local location = platform.valid and platform.space_location
      local hub = platform.valid and platform.hub
      if location and LOCATIONS[location.name] and hub and hub.valid then
        local inventory = hub.get_inventory(defines.inventory.hub_main)
        local available = inventory and inventory.get_item_count(ITEM) or 0
        local picked_up = 0
        while available > 0 do
          local goal = contract_size(state.number)
          local taken = inventory.remove{name = ITEM, count = math.min(available, goal - state.delivered)}
          if taken == 0 then break end
          available = available - taken
          picked_up = picked_up + taken
          if state.delivered + taken < goal then
            force.print({"ff-contract.pickup", picked_up, state.delivered + taken, goal})
          end
          state.delivered = state.delivered + taken
          state.total = (state.total or 0) + taken
          changed = true
          if state.delivered >= goal then
            state.completed = (state.completed or 0) + 1
            force.print({"ff-contract.fulfilled-n", state.number, BONUS_ROBOT_SPEED * 100, BONUS_BRAKING * 100})
            apply_bonus(force)
            if state.number == 1 then victory(force) end
            state.number = state.number + 1
            state.delivered = 0
            force.print({"ff-contract.next", state.number, contract_size(state.number)})
          end
        end
      end
    end
    if changed then update_all_panels(force) end
  end
end

---------------------------------------------------------------------------------------------------

-- Space Age wins as soon as a platform reaches the solar system edge; with the contract, reaching it is not enough
local function take_over_victory()
  if not (script.active_mods["space-age"] and prototypes.item[ITEM]) then return end
  local iface = remote.interfaces["space_finish_script"]
  if iface and iface["set_no_victory"] then remote.call("space_finish_script", "set_no_victory", true) end
end

local function on_gui_click(event)
  local element = event.element
  if not (element and element.valid) then return end
  local player = game.get_player(event.player_index)
  if element.name == "ff_freight_stats_button" or element.name == "ff_freight_stats_close" then
    toggle_stats(player)
  end
end

local function on_gui_closed(event)
  if event.element and event.element.valid and event.element.name == "ff_freight_stats" then
    event.element.destroy()
  end
end

---@type ScriptLib
local FreightContract = {}

FreightContract.on_init = function()
  take_over_victory()
  update_all_panels()
end
FreightContract.on_configuration_changed = function()
  container_names = nil
  take_over_victory()
  update_all_panels()
end

FreightContract.events = {
  [defines.events.on_gui_click] = on_gui_click,
  [defines.events.on_gui_closed] = on_gui_closed,
  [defines.events.on_player_created] = function(event) update_panel(game.get_player(event.player_index)) end,
  [defines.events.on_player_changed_force] = function(event) update_panel(game.get_player(event.player_index)) end,
  [defines.events.on_runtime_mod_setting_changed] = function(event)
    if event.setting == "ff-show-freight-panel" and event.player_index then update_panel(game.get_player(event.player_index)) end
  end,
  [defines.events.on_research_finished] = function(event)
    if event.research.name == "ff-interstellar-freight-contract" then
      event.research.force.print({"ff-contract.signal"})
      update_all_panels(event.research.force)
    end
  end,
}

FreightContract.on_nth_tick = {
  [600] = function()
    if script.active_mods["space-age"] then check() end
  end,
}

FreightContract.add_remote_interface = function()
  remote.add_interface("ff-freight-contract", {
    progress = function(force_index)
      local force = game.forces[force_index or 1]
      local state = get_state(force)
      return state.delivered, contract_size(state.number), state.number, state.completed or 0
    end,
    statistics = function(force_index) return freight_statistics(game.forces[force_index or 1]) end,
  })
end

return FreightContract
