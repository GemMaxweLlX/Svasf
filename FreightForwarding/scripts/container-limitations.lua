-- Filled containers are too heavy for logistic robots and spider vehicles.
-- 2.x: logistic requests live in LuaLogisticSections; inventories return arrays from get_contents().

local function is_container(name)
  return name == "ic-container" or name:sub(1, #"ic-container-") == "ic-container-"
end

local function is_filled_container(name)
  return name:sub(1, #"ic-container") == "ic-container-"
end

local function filter_name(filter)
  if not filter then return nil end
  local value = filter.value or filter
  if type(value) == "string" then return value end
  return value.name
end

local function flying_text(player, text)
  player.create_local_flying_text{
    text = text,
    create_at_cursor = true,
  }
end

--- Removes container requests from all logistic sections of an entity. Returns true if anything was cleared.
---@param entity LuaEntity
local function clear_container_requests(entity)
  local requester = entity.get_requester_point()
  if not (requester and requester.valid) then return false end
  local cleared = false
  for _, section in pairs(requester.sections) do
    if section.is_manual then
      for slot_index = 1, section.filters_count do
        local slot = section.get_slot(slot_index)
        local name = slot and filter_name(slot)
        if name and is_container(name) then
          section.clear_slot(slot_index)
          cleared = true
        end
      end
    end
  end
  return cleared
end

local function on_entity_logistic_slot_changed(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end
  local section = event.section
  local name
  if section and section.valid and section.is_manual then
    local slot = section.get_slot(event.slot_index)
    name = slot and filter_name(slot)
    if name and is_container(name) and (slot.max == nil or slot.max > 0) then
      section.clear_slot(event.slot_index)
    else
      name = nil
    end
  end
  if name then
    local player = event.player_index and game.get_player(event.player_index)
    if player then
      flying_text(player, {"freight-forwarding.containers-too-heavy"})
    else
      entity.force.print({"freight-forwarding.containers-too-heavy"})
    end
  end
end

-- Logistic chests: also covers storage chest filters
local function check_requester_slots(entity)
  local slots_cleared = clear_container_requests(entity)

  if entity.prototype.logistic_mode == "storage" then
    local name = filter_name(entity.storage_filter)
    if name and is_container(name) then
      entity.storage_filter = nil
      slots_cleared = true
    end
  end
  return slots_cleared
end

local function on_entity_settings_pasted(event)
  local entity = event.destination
  if entity.type == "logistic-container" then
    if check_requester_slots(entity) then
      local player = game.get_player(event.player_index)
      if player then flying_text(player, {"freight-forwarding.containers-too-heavy"}) end
    end
  end
end

local function check_spidertron_inventory(entity)
  local items_spilled = false
  for _, inventory_define in pairs({defines.inventory.spider_trunk, defines.inventory.spider_trash}) do
    local inventory = entity.get_inventory(inventory_define)
    if inventory then
      for _, item in pairs(inventory.get_contents()) do
        if is_filled_container(item.name) then
          local stack = {name = item.name, count = item.count, quality = item.quality}
          local removed = inventory.remove(stack)
          if removed > 0 then
            items_spilled = true
            stack.count = removed
            entity.surface.spill_item_stack{
              position = entity.position,
              stack = stack,
              enable_looted = true,
              allow_belts = false,
            }
          end
        end
      end
    end
  end
  return items_spilled
end

local function on_player_fast_transferred(event)
  local entity = event.entity
  if entity and entity.valid and entity.type == "spider-vehicle" then
    if check_spidertron_inventory(entity) then
      local player = game.get_player(event.player_index)
      flying_text(player, {"freight-forwarding.containers-in-spider-vehicles-by-player"})
    end
  end
end

-- If player presses Z over a spidertron
local function on_player_cursor_stack_changed(event)
  local player = game.get_player(event.player_index)
  local entity = player.selected
  if entity and entity.type == "spider-vehicle" then
    if check_spidertron_inventory(entity) then
      flying_text(player, {"freight-forwarding.containers-in-spider-vehicles-by-player"})
    end
  end
end

local function on_tick(event)
  if event.tick % 10 ~= 0 then return end  -- Only GUI-open entities are checked, a few times per second is plenty
  for _, player in pairs(game.connected_players) do
    local entity = player.opened
    if entity and entity.object_name == "LuaEntity" and entity.valid then
      if entity.type == "logistic-container" then
        if check_requester_slots(entity) then
          flying_text(player, {"freight-forwarding.containers-too-heavy"})
        end
      elseif entity.type == "spider-vehicle" then
        if check_spidertron_inventory(entity) then
          flying_text(player, {"freight-forwarding.containers-in-spider-vehicles-by-player"})
        end
      end
    end
  end
end

---@type ScriptLib
local ContainerLimitations = {}

ContainerLimitations.events = {
  [defines.events.on_entity_logistic_slot_changed] = on_entity_logistic_slot_changed,
  [defines.events.on_entity_settings_pasted]       = on_entity_settings_pasted,
  [defines.events.on_player_fast_transferred]      = on_player_fast_transferred,
  [defines.events.on_player_cursor_stack_changed]  = on_player_cursor_stack_changed,
  [defines.events.on_tick] = on_tick
}

return ContainerLimitations
