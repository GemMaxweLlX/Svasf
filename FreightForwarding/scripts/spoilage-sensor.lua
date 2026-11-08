-- Space Age: spoilage sensor. Twice a second each sensor looks for a train stop within a few tiles and outputs
-- the spoilage of the stopped train's cargo, in percent: the most spoiled stack (ff-spoilage-max) and the average
-- weighted by item count (ff-spoilage-average). Use them in a "circuit condition" wait condition.

local SENSOR = "ff-spoilage-sensor"
local RADIUS = 4

local function cargo_spoilage(train)
  local max, total, weighted = 0, 0, 0
  for _, wagon in pairs(train.cargo_wagons) do
    local inventory = wagon.get_inventory(defines.inventory.cargo_wagon)
    if inventory then
      for i = 1, #inventory do
        local stack = inventory[i]
        if stack.valid_for_read and stack.prototype.get_spoil_ticks(stack.quality) > 0 then
          local spoil = stack.spoil_percent
          if spoil > max then max = spoil end
          total = total + stack.count
          weighted = weighted + spoil * stack.count
        end
      end
    end
  end
  if total == 0 then return nil end
  return max, weighted / total
end

local function set_signals(sensor, max, average)
  local behavior = sensor.get_or_create_control_behavior()
  local section = behavior.get_section(1) or behavior.add_section()
  if not section then return end
  if max then
    section.set_slot(1, {value = {type = "virtual", name = "ff-spoilage-max", quality = "normal"}, min = math.floor(max * 100 + 0.5)})
    section.set_slot(2, {value = {type = "virtual", name = "ff-spoilage-average", quality = "normal"}, min = math.floor(average * 100 + 0.5)})
  else
    section.clear_slot(1)
    section.clear_slot(2)
  end
end

local function update()
  local sensors = storage.ff_spoilage_sensors
  if not sensors then return end
  for unit_number, sensor in pairs(sensors) do
    if not sensor.valid then
      sensors[unit_number] = nil
    else
      local max, average
      for _, stop in pairs(sensor.surface.find_entities_filtered{type = "train-stop", position = sensor.position, radius = RADIUS}) do
        local train = stop.get_stopped_train()
        if train then
          max, average = cargo_spoilage(train)
          break
        end
      end
      set_signals(sensor, max, average)
    end
  end
end

local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == SENSOR) then return end
  entity.operable = false
  storage.ff_spoilage_sensors = storage.ff_spoilage_sensors or {}
  storage.ff_spoilage_sensors[entity.unit_number] = entity
end

---@type ScriptLib
local SpoilageSensor = {}

SpoilageSensor.events = {
  [defines.events.on_built_entity] = on_built,
  [defines.events.on_robot_built_entity] = on_built,
  [defines.events.script_raised_built] = on_built,
  [defines.events.script_raised_revive] = on_built,
}

SpoilageSensor.on_nth_tick = {
  [30] = update,
}

return SpoilageSensor
