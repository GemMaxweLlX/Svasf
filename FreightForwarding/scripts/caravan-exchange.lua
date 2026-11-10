-- Caravan exchange (prototypes/caravan-exchange.lua). Put containers of basic goods into the exchange and choose what
-- to receive in the panel next to its window. Every 10 seconds the offered containers are sold at the current price
-- (minus the caravan's fee) and containers of the chosen good are bought with the credit, as many as fit; the rest of
-- the credit stays on the exchange. Prices drift every PRICE_PERIOD; the panel shows them with the trend.

local EXCHANGE = "ff-caravan-exchange"
local FEE = 0.1
local PRICE_PERIOD = 10 * 60 * 60  -- 10 minutes
local MIN_FACTOR, MAX_FACTOR = 0.6, 1.6

-- Basic goods and their base value per item (ore = 1). Only those with a container are traded.
local GOODS = {
  {"iron-ore", 1}, {"copper-ore", 1}, {"stone", 1}, {"coal", 1}, {"wood", 1}, {"uranium-ore", 3},
  {"lead-ore", 1.2}, {"titanium-ore", 1.5}, {"calcite", 1.5}, {"tungsten-ore", 3}, {"holmium-ore", 4},
  {"iron-plate", 1.2}, {"copper-plate", 1.2}, {"stone-brick", 2.4}, {"steel-plate", 6}, {"lead-plate", 1.5},
  {"titanium-plate", 3}, {"plastic-bar", 3}, {"sulfur", 2}, {"solid-fuel", 3}, {"ff-cobalt-ingot", 6},
}

local function containers()
  local list = {}
  for _, entry in pairs(GOODS) do
    local item = "ic-container-" .. entry[1]
    local unload = prototypes.recipe["ic-unload-" .. entry[1]]
    if prototypes.item[item] and unload then
      local per = 0
      for _, product in pairs(unload.products) do
        if product.name == entry[1] then per = product.amount or product.amount_max or 0 end
      end
      if per > 0 then list[item] = {good = entry[1], value = entry[2] * per} end
    end
  end
  return list
end

local market_cache
local function market()
  market_cache = market_cache or containers()
  return market_cache
end

local function state()
  storage.ff_exchange = storage.ff_exchange or {exchanges = {}, factors = {}, previous = {}, next_prices = 0}
  return storage.ff_exchange
end

-- Caravan blueprint "trade agreement" (reputation 6, scripts/freight-contract.lua) halves the fee
local function fee_for(force)
  local perks = storage.ff_caravan_perks and storage.ff_caravan_perks[force.index]
  return perks and perks["exchange-fee"] and FEE / 2 or FEE
end

local function factor(item) return state().factors[item] or 1 end
local function price(item) return market()[item].value * factor(item) end

local function update_prices()
  local s = state()
  s.rng = s.rng or game.create_random_generator(4242)
  for item in pairs(market()) do
    local old = s.factors[item] or 1
    s.previous[item] = old
    local new = old * (0.85 + 0.3 * s.rng())
    s.factors[item] = math.min(MAX_FACTOR, math.max(MIN_FACTOR, new + (1 - new) * 0.1))  -- drifts back towards 1
  end
  s.next_prices = game.tick + PRICE_PERIOD
end

---------------------------------------------------------------------------------------------------
-- Trading

local function trade(record)
  local entity = record.entity
  local target = record.target
  if not (target and market()[target]) then return end
  local inventory = entity.get_inventory(defines.inventory.chest)
  for _, stack in pairs(inventory.get_contents()) do
    if stack.name ~= target and market()[stack.name] then
      local removed = inventory.remove{name = stack.name, count = stack.count, quality = stack.quality}
      record.credit = (record.credit or 0) + removed * price(stack.name) * (1 - fee_for(entity.force))
      record.sold = (record.sold or 0) + removed
    end
  end
  local cost = price(target)
  local can_buy = math.floor((record.credit or 0) / cost)
  if can_buy > 0 then
    local inserted = inventory.insert{name = target, count = can_buy}
    record.credit = record.credit - inserted * cost
    record.bought = (record.bought or 0) + inserted
  end
end

local function update()
  local s = state()
  if game.tick >= (s.next_prices or 0) then update_prices() end
  for unit, record in pairs(s.exchanges) do
    if record.entity.valid then trade(record) else s.exchanges[unit] = nil end
  end
end

---------------------------------------------------------------------------------------------------
-- Panel (next to the exchange's chest window)

local PANEL = "ff_exchange_panel"

local function close_panel(player)
  if player.gui.relative[PANEL] then player.gui.relative[PANEL].destroy() end
end

local function open_panel(player, entity)
  close_panel(player)
  local s = state()
  local record = s.exchanges[entity.unit_number]
  if not record then return end
  local frame = player.gui.relative.add{type = "frame", name = PANEL, direction = "vertical", caption = {"ff-exchange.title"},
    anchor = {gui = defines.relative_gui_type.container_gui, position = defines.relative_gui_position.right, name = EXCHANGE}}
  frame.tags = {unit = entity.unit_number}
  local inner = frame.add{type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical"}
  local names = {}
  for item in pairs(market()) do names[#names + 1] = item end
  table.sort(names)
  local row = inner.add{type = "flow", direction = "horizontal"}
  row.style.vertical_align = "center"
  row.add{type = "label", caption = {"ff-exchange.receive"}}
  row.add{type = "choose-elem-button", name = "ff_exchange_target", elem_type = "item", item = record.target,
          elem_filters = {{filter = "name", name = names}}, tags = {unit = entity.unit_number}}
  inner.add{type = "label", caption = {"ff-exchange.credit", string.format("%.1f", record.credit or 0)}}
  inner.add{type = "label", caption = {"ff-exchange.fee", string.format("%g", fee_for(entity.force) * 100)}}
  inner.add{type = "label", caption = {"ff-exchange.next", math.ceil(math.max(0, (s.next_prices or 0) - game.tick) / 3600)}}
  local pane = inner.add{type = "scroll-pane"}
  pane.style.maximal_height = 400
  local grid = pane.add{type = "table", column_count = 3, draw_horizontal_line_after_headers = true}
  grid.add{type = "label", caption = {"ff-exchange.col-container"}, style = "bold_label"}
  grid.add{type = "label", caption = {"ff-exchange.col-price"}, style = "bold_label"}
  grid.add{type = "label", caption = {"ff-exchange.col-trend"}, style = "bold_label"}
  for _, item in pairs(names) do
    grid.add{type = "label", caption = "[item=" .. item .. "]"}
    grid.add{type = "label", caption = string.format("%.0f", price(item))}
    local old = s.previous[item] or 1
    local now = factor(item)
    local trend = grid.add{type = "label", caption = now > old * 1.005 and "▲" or (now < old * 0.995 and "▼" or "•")}
    if now > old * 1.005 then trend.style.font_color = {0.4, 1, 0.4}
    elseif now < old * 0.995 then trend.style.font_color = {1, 0.4, 0.4} end
  end
end

local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == EXCHANGE) then return end
  local s = state()
  s.exchanges[entity.unit_number] = {entity = entity, credit = 0}
  if (s.next_prices or 0) == 0 then update_prices() end
  local tags = event.tags
  if tags and tags.ff_exchange_target then s.exchanges[entity.unit_number].target = tags.ff_exchange_target end
end

local function on_gui_opened(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == EXCHANGE then
    open_panel(game.get_player(event.player_index), entity)
  end
end

local function on_gui_elem_changed(event)
  local element = event.element
  if not (element and element.valid and element.name == "ff_exchange_target") then return end
  local record = state().exchanges[element.tags.unit]
  if not record then return end
  record.target = element.elem_value
  if record.entity.valid then open_panel(game.get_player(event.player_index), record.entity) end
end

-- Copy-paste the chosen good between exchanges
local function on_entity_settings_pasted(event)
  local s = state()
  local from, to = event.source, event.destination
  if from.name == EXCHANGE and to.name == EXCHANGE and s.exchanges[from.unit_number] and s.exchanges[to.unit_number] then
    s.exchanges[to.unit_number].target = s.exchanges[from.unit_number].target
  end
end

---@type ScriptLib
local CaravanExchange = {}

CaravanExchange.events = {
  [defines.events.on_built_entity] = on_built,
  [defines.events.on_robot_built_entity] = on_built,
  [defines.events.script_raised_built] = on_built,
  [defines.events.script_raised_revive] = on_built,
  [defines.events.on_gui_opened] = on_gui_opened,
  [defines.events.on_gui_elem_changed] = on_gui_elem_changed,
  [defines.events.on_entity_settings_pasted] = on_entity_settings_pasted,
}

CaravanExchange.on_nth_tick = {
  [600] = update,
}

CaravanExchange.add_remote_interface = function()
  remote.add_interface("ff-caravan-exchange", {
    -- for tests and scenarios
    set_target = function(entity, item) local r = state().exchanges[entity.unit_number] if r then r.target = item end end,
    price = function(item) return market()[item] and price(item) end,
    record = function(entity) local r = state().exchanges[entity.unit_number] return r and r.credit, r and r.sold, r and r.bought end,
    update = update,
  })
end

return CaravanExchange
