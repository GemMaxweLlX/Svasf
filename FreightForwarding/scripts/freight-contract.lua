-- Interstellar freight contracts (Space Age) and the freight panel (all games with Intermodal Containers).
--
-- Lore: the Long Caravan, interstellar haulers on a route centuries long, can't afford to brake; at the solar system
-- edge they take cargo on the fly. Consignments (and their light containers) leave with it for good. Each caravan
-- ship pays with what it carries: navigation data, survey maps, research archives...
--
-- Contracts: every 10 seconds, freight consignments in the hub of a space platform at the solar system edge (or the
-- shattered planet beyond it) are taken in. The first fulfilled contract wins the game (Space Age's own victory for
-- just reaching the edge is turned off). The caravan offers 3 contracts to choose from (CONTRACT_TYPES); each has its
-- own size and reward. Nothing is taken until one is accepted, and it can be changed until the first delivery.
-- Contracts get bigger one after another.
--
-- Panels (left, toggled by shortcut bar buttons): containers (freight statistics per planet: packed, unpacked and
-- damaged, read from the force's production statistics) and contracts (offers, active contract, timers, rewards).

local ITEM = "ff-freight-consignment"
local LOCATIONS = {["solar-system-edge"] = true, ["shattered-planet"] = true}
local OFFER_COUNT = 3

-- Contract types: size factor and reward (applied to the force once per fulfilled contract)
local CONTRACT_TYPES = {
  navigation = {size = 1, values = {10, 10}, apply = function(force)
    force.worker_robots_speed_modifier = force.worker_robots_speed_modifier + 0.1
    force.train_braking_force_bonus = force.train_braking_force_bonus + 0.1
  end},
  survey = {size = 1.25, values = {5}, apply = function(force)
    force.mining_drill_productivity_bonus = force.mining_drill_productivity_bonus + 0.05
  end},
  archive = {size = 1, values = {10}, apply = function(force)
    force.laboratory_speed_modifier = force.laboratory_speed_modifier + 0.1
  end},
  cargo = {size = 1.5, values = {1, 1}, apply = function(force)
    force.bulk_inserter_capacity_bonus = force.bulk_inserter_capacity_bonus + 1
    force.inserter_stack_size_bonus = force.inserter_stack_size_bonus + 1
  end},
  drones = {size = 1.5, values = {1}, apply = function(force)
    force.worker_robots_storage_bonus = force.worker_robots_storage_bonus + 1
  end},
  workshop = {size = 0.75, values = {20}, apply = function(force)
    force.manual_crafting_speed_modifier = force.manual_crafting_speed_modifier + 0.2
  end},
}
local TYPE_ORDER = {"navigation", "survey", "archive", "cargo", "drones", "workshop"}

---------------------------------------------------------------------------------------------------
-- Contract state

local function base_size()
  return settings.startup["ff-freight-contract-size"].value
end

--- Size of contract number n (1, 2, 3...) of a type: the base size, +50% of it for every contract after the first,
--- times the type's factor
local function contract_size(n, type_name)
  local factor = CONTRACT_TYPES[type_name] and CONTRACT_TYPES[type_name].size or 1
  return math.max(1, math.floor(base_size() * (1 + 0.5 * (n - 1)) * factor))
end

local function reward_text(type_name)
  local t = CONTRACT_TYPES[type_name]
  return {"ff-contract-reward." .. type_name, table.unpack(t.values)}
end

local function total_text(type_name, count)
  local t = CONTRACT_TYPES[type_name]
  local values = {}
  for i, v in pairs(t.values) do values[i] = v * count end
  return {"ff-contract-reward." .. type_name, table.unpack(values)}
end

-- Timers (runtime map settings, in minutes)
local MINUTE = 60 * 60
local function setting_ticks(name) return settings.global[name].value * MINUTE end
local PENALTY_PERIOD = 10 * MINUTE

local function format_time(ticks)
  local seconds = math.max(0, math.floor(ticks / 60))
  local h, m, sec = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
  return string.format("%d:%02d", m, sec)
end

--- New offers: OFFER_COUNT different contract types, each with its own expiry (offer lifetime ±25%)
local function draw_offers(state)
  storage.ff_contract_rng = storage.ff_contract_rng or game.create_random_generator(12345)
  local rng = storage.ff_contract_rng
  local pool = {}
  for _, name in pairs(TYPE_ORDER) do pool[#pool + 1] = name end
  local offers = {}
  local lifetime = setting_ticks("ff-contract-offer-lifetime")
  for _ = 1, math.min(OFFER_COUNT, #pool) do
    local i = rng(1, #pool)
    offers[#offers + 1] = {type = table.remove(pool, i), expires = game.tick + math.floor(lifetime * (0.75 + 0.5 * rng()))}
  end
  state.offers = offers
  state.refresh_at = game.tick + setting_ticks("ff-contract-refresh")
end

--- Time to fulfil a contract: the deadline setting is for a contract of the base size, bigger ones get more time
local function deadline_for(number, type_name)
  return math.floor(setting_ticks("ff-contract-deadline") * contract_size(number, type_name) / base_size())
end

--- Consignments the active contract needs, penalty included
local function goal_of(state)
  return contract_size(state.number, state.active) + (state.penalty or 0)
end

local function get_state(force)
  storage.ff_contract = storage.ff_contract or {}
  local state = storage.ff_contract[force.index]
  if type(state) ~= "table" then  -- older saves stored only the delivered count
    state = {number = 1, delivered = state or 0}
    storage.ff_contract[force.index] = state
  end
  state.bonuses = state.bonuses or {}
  if state.delivered > 0 and not state.active then
    -- contracts from before the choice existed were navigation contracts
    state.active = "navigation"
    state.bonuses.navigation = state.bonuses.navigation or (state.completed or 0)
  end
  if state.offers then  -- offers from before the timers were plain type names
    for i, offer in pairs(state.offers) do
      if type(offer) == "string" then state.offers[i] = {type = offer, expires = game.tick + setting_ticks("ff-contract-offer-lifetime")} end
    end
  end
  if state.active and not state.deadline then state.deadline = game.tick + setting_ticks("ff-contract-deadline") end
  if not state.active and not state.offers then draw_offers(state) end
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
-- GUI: two panels on the left, each toggled by a shortcut bar button
--   containers panel: freight statistics per planet (refreshed every 10 s)
--   contracts panel:  offers / active contract with timers, rewards received

local CONTAINER_SHORTCUT = "ff-container-panel"
local CONTRACT_SHORTCUT = "ff-contract-panel"

local function panels_of(player)
  storage.ff_panels = storage.ff_panels or {}
  local panels = storage.ff_panels[player.index]
  if not panels then
    panels = {containers = false, contracts = false}
    storage.ff_panels[player.index] = panels
  end
  return panels
end

local function add_text(parent, caption, style)
  local label = parent.add{type = "label", caption = caption, style = style}
  label.style.single_line = false
  label.style.maximal_width = 320
  return label
end

local function build_containers(player)
  local frame = player.gui.left.add{type = "frame", name = "ff_container_panel", direction = "vertical",
                                    caption = {"ff-gui.stats-title"}}
  local inner = frame.add{type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical"}
  local grid = inner.add{type = "table", column_count = 4, draw_horizontal_line_after_headers = true}
  for _, header in pairs{"planet", "packed", "unpacked", "damaged"} do
    grid.add{type = "label", caption = {"ff-gui.stats-" .. header}, style = "bold_label"}
  end
  for _, row in pairs(freight_statistics(player.force)) do
    grid.add{type = "label", caption = row.name}
    grid.add{type = "label", caption = tostring(math.floor(row.packed))}
    grid.add{type = "label", caption = tostring(math.floor(row.unpacked))}
    grid.add{type = "label", caption = tostring(math.floor(row.damaged))}
  end
  local state = prototypes.item[ITEM] and get_state(player.force)
  if state and state.total then
    inner.add{type = "label", caption = {"ff-gui.stats-consignments", state.total}}
  end
end

local function build_contracts(player)
  local frame = player.gui.left.add{type = "frame", name = "ff_contract_panel", direction = "vertical",
                                    caption = {"ff-gui.contracts-title"}}
  local state = get_state(player.force)
  if state.active then
    local goal = goal_of(state)
    add_text(frame, {"ff-gui.contract-active", state.number, {"ff-contract-name." .. state.active}, state.delivered, goal})
    local overdue = game.tick > state.deadline
    local timer = add_text(frame, overdue and {"ff-gui.overdue", format_time(game.tick - state.deadline), state.penalty or 0}
                                          or {"ff-gui.deadline", format_time(state.deadline - game.tick)})
    timer.name = "ff_deadline_timer"
    if overdue then timer.style.font_color = {1, 0.3, 0.2} end
    local bar = frame.add{type = "progressbar", value = math.min(1, state.delivered / goal)}
    bar.style.horizontally_stretchable = true
    add_text(frame, {"ff-gui.reward", reward_text(state.active)})
    if state.delivered == 0 then
      frame.add{type = "button", name = "ff_contract_cancel", caption = {"ff-gui.change-contract"}}
    end
  else
    add_text(frame, {"ff-gui.choose-contract", state.number}, "bold_label")
    for i, offer in pairs(state.offers or {}) do
      local size = contract_size(state.number, offer.type)
      local button = frame.add{type = "button", name = "ff_contract_offer_" .. i,
        caption = {"ff-gui.offer", {"ff-contract-name." .. offer.type}, size},
        tooltip = {"", {"ff-contract-description." .. offer.type}, "\n", {"ff-gui.reward", reward_text(offer.type)},
                   "\n", {"ff-gui.offer-deadline", format_time(deadline_for(state.number, offer.type))}}}
      button.style.horizontally_stretchable = true
      add_text(frame, {"ff-gui.reward", reward_text(offer.type)})
      add_text(frame, {"ff-gui.offer-expires", format_time(offer.expires - game.tick)}).name = "ff_offer_timer_" .. i
    end
    if #(state.offers or {}) == 0 then add_text(frame, {"ff-gui.no-offers"}) end
    add_text(frame, {"ff-gui.refresh", format_time(state.refresh_at - game.tick)}).name = "ff_refresh_timer"
  end
  if (state.completed or 0) > 0 then
    add_text(frame, {"ff-gui.completed", state.completed}, "bold_label")
    for _, name in pairs(TYPE_ORDER) do
      if (state.bonuses[name] or 0) > 0 then add_text(frame, total_text(name, state.bonuses[name])) end
    end
  end
end

local function update_panel(player)
  if not (player and player.valid) then return end
  -- panels of older versions
  if player.gui.top.ff_freight_panel then player.gui.top.ff_freight_panel.destroy() end
  if player.gui.screen.ff_freight_stats then player.gui.screen.ff_freight_stats.destroy() end

  local left = player.gui.left
  for _, name in pairs{"ff_container_panel", "ff_contract_panel"} do
    if left[name] then left[name].destroy() end
  end
  local panels = panels_of(player)
  local can_contract = prototypes.item[ITEM] ~= nil and contract_available(player.force)
  if panels.containers and prototypes.item["ic-container"] then build_containers(player) end
  if panels.contracts and can_contract then build_contracts(player) end

  if prototypes.shortcut[CONTAINER_SHORTCUT] then
    player.set_shortcut_toggled(CONTAINER_SHORTCUT, panels.containers)
  end
  if prototypes.shortcut[CONTRACT_SHORTCUT] then
    player.set_shortcut_available(CONTRACT_SHORTCUT, can_contract)
    player.set_shortcut_toggled(CONTRACT_SHORTCUT, panels.contracts and can_contract)
  end
end

local function update_all_panels(force)
  for _, player in pairs((force and force.players) or game.players) do update_panel(player) end
end

local function refresh_container_panels()
  for _, player in pairs(game.connected_players) do
    if player.gui.left.ff_container_panel then update_panel(player) end
  end
end

local function on_lua_shortcut(event)
  local player = game.get_player(event.player_index)
  local panels = panels_of(player)
  if event.prototype_name == CONTAINER_SHORTCUT then
    panels.containers = not panels.containers
  elseif event.prototype_name == CONTRACT_SHORTCUT then
    panels.contracts = not panels.contracts
  else
    return
  end
  update_panel(player)
end

---------------------------------------------------------------------------------------------------
-- Delivery

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
      if not state.active then break end  -- no contract accepted: the caravan doesn't stop by
      local location = platform.valid and platform.space_location
      local hub = platform.valid and platform.hub
      if location and LOCATIONS[location.name] and hub and hub.valid then
        local inventory = hub.get_inventory(defines.inventory.hub_main)
        local available = inventory and inventory.get_item_count(ITEM) or 0
        if available > 0 then
          local goal = goal_of(state)
          local taken = inventory.remove{name = ITEM, count = math.min(available, goal - state.delivered)}
          if taken > 0 then
            state.delivered = state.delivered + taken
            state.total = (state.total or 0) + taken
            changed = true
            if state.delivered < goal then
              force.print({"ff-contract.pickup", taken, state.delivered, goal})
            else
              local type_name = state.active
              CONTRACT_TYPES[type_name].apply(force)
              state.bonuses[type_name] = (state.bonuses[type_name] or 0) + 1
              state.completed = (state.completed or 0) + 1
              force.print({"ff-contract.fulfilled-type", state.number, {"ff-contract-name." .. type_name}, reward_text(type_name)})
              if state.number == 1 then victory(force) end
              state.number = state.number + 1
              state.delivered = 0
              state.active = nil
              state.deadline = nil
              state.penalty = nil
              state.previous_offers = nil
              draw_offers(state)
              force.print({"ff-contract.new-offers", state.number})
            end
          end
        end
      end
    end
    if changed then update_all_panels(force) end
  end
end

local function accept(force, index)
  local state = get_state(force)
  if state.active or not (state.offers and state.offers[index]) then return false end
  state.active = state.offers[index].type
  state.previous_offers = state.offers
  state.offers = nil
  state.deadline = game.tick + deadline_for(state.number, state.active)
  state.penalty = nil
  force.print({"ff-contract.accepted", state.number, {"ff-contract-name." .. state.active}, contract_size(state.number, state.active)})
  update_all_panels(force)
  return true
end

local function cancel(force)
  local state = get_state(force)
  if not state.active or state.delivered > 0 then return false end
  state.active = nil
  state.deadline = nil
  state.penalty = nil
  -- back to the offers that were on the table (those not expired since)
  local offers = {}
  for _, offer in pairs(state.previous_offers or {}) do
    if offer.expires > game.tick then offers[#offers + 1] = offer end
  end
  state.offers = offers
  state.previous_offers = nil
  update_all_panels(force)
  return true
end

--- Once a second: offers expire, offers are refreshed, overdue contracts pile up penalties, timers on the panel
local function tick_timers()
  if not prototypes.item[ITEM] then return end
  for _, force in pairs(game.forces) do
    if contract_available(force) then
      local state = get_state(force)
      local rebuild = false
      if state.active then
        if game.tick > state.deadline then
          local periods = math.floor((game.tick - state.deadline) / PENALTY_PERIOD) + 1
          local penalty = math.ceil(contract_size(state.number, state.active) * settings.global["ff-contract-penalty"].value / 100 * periods)
          if penalty ~= (state.penalty or 0) then
            if not state.penalty then force.print({"ff-contract.overdue", state.number}) end
            state.penalty = penalty
            force.print({"ff-contract.penalty", penalty, goal_of(state)})
            rebuild = true
          end
        end
      else
        if game.tick >= (state.refresh_at or 0) then
          draw_offers(state)
          force.print({"ff-contract.refreshed"})
          rebuild = true
        else
          for i = #state.offers, 1, -1 do
            if state.offers[i].expires <= game.tick then
              table.remove(state.offers, i)
              rebuild = true
            end
          end
        end
      end
      if rebuild then
        update_all_panels(force)
      else
        for _, player in pairs(force.players) do
          local frame = player.gui.left.ff_contract_panel
          if frame then
            if frame.ff_refresh_timer then frame.ff_refresh_timer.caption = {"ff-gui.refresh", format_time(state.refresh_at - game.tick)} end
            for i, offer in pairs(state.offers or {}) do
              local label = frame["ff_offer_timer_" .. i]
              if label then label.caption = {"ff-gui.offer-expires", format_time(offer.expires - game.tick)} end
            end
            if frame.ff_deadline_timer and state.active then
              if game.tick > state.deadline then
                frame.ff_deadline_timer.caption = {"ff-gui.overdue", format_time(game.tick - state.deadline), state.penalty or 0}
              else
                frame.ff_deadline_timer.caption = {"ff-gui.deadline", format_time(state.deadline - game.tick)}
              end
            end
          end
        end
      end
    end
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
  if element.name == "ff_contract_cancel" then
    cancel(player.force)
  elseif element.name:sub(1, 18) == "ff_contract_offer_" then
    accept(player.force, tonumber(element.name:sub(19)))
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
  [defines.events.on_lua_shortcut] = on_lua_shortcut,
  [defines.events.on_player_created] = function(event) update_panel(game.get_player(event.player_index)) end,
  [defines.events.on_player_changed_force] = function(event) update_panel(game.get_player(event.player_index)) end,
  [defines.events.on_research_finished] = function(event)
    if event.research.name == "ff-interstellar-freight-contract" then
      local state = get_state(event.research.force)
      if not state.active then draw_offers(state) end  -- timers start now
      event.research.force.print({"ff-contract.signal"})
      for _, player in pairs(event.research.force.players) do panels_of(player).contracts = true end  -- open it once
      update_all_panels(event.research.force)
    end
  end,
}

FreightContract.on_nth_tick = {
  [600] = function()
    if script.active_mods["space-age"] then check() end
    refresh_container_panels()
  end,
  [60] = function()
    if script.active_mods["space-age"] then tick_timers() end
  end,
}

FreightContract.add_remote_interface = function()
  remote.add_interface("ff-freight-contract", {
    progress = function(force_index)
      local force = game.forces[force_index or 1]
      local state = get_state(force)
      local offers = {}
      for _, offer in pairs(state.offers or {}) do offers[#offers + 1] = offer.type end
      return state.delivered, state.active and goal_of(state) or 0, state.number,
             state.completed or 0, state.active, offers, state.deadline, state.penalty, state.refresh_at
    end,
    accept = function(force_index, index) return accept(game.forces[force_index or 1], index) end,
    cancel = function(force_index) return cancel(game.forces[force_index or 1]) end,
    statistics = function(force_index) return freight_statistics(game.forces[force_index or 1]) end,
  })
end

return FreightContract
