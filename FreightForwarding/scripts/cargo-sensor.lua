-- Cargo sensor (prototypes/logistics-qol.lua). Twice a second each sensor looks for a train stop or port within a few
-- tiles and, for the stopped train or ship, outputs what its containers hold, unpacked: e.g. 10 iron plate containers
-- give "iron plate = 10 x (plates per container)". Tank containers give fluid signals. Plus:
--   ff-cargo-containers  number of containers aboard
--   ff-cargo-fill        cargo slots in use, percent
--   ff-cargo-vehicles    1 while a train or ship is stopped
-- (Loose items are not included: the train stop itself can read the train's contents.)

local SENSOR = "ff-cargo-sensor"
local RADIUS = 4
local MAX_SLOTS = 900

-- Container item -> {type, name, amount} it unpacks to, from the unload recipes (IC "ic-unload-", FF tanks, reefers...)
local contents_cache
local function contents()
  if contents_cache then return contents_cache end
  contents_cache = {}
  for name, recipe in pairs(prototypes.recipe) do
    local unloaded = name:match("^ic%-unload%-(.+)$") or name:match("^ff%-tank%-unload%-(.+)$")
    if unloaded then
      local container = recipe.ingredients[1]
      for _, product in pairs(recipe.products) do
        if product.name == unloaded and container then
          contents_cache[container.name] = {type = product.type, name = product.name, amount = product.amount or product.amount_max or 1}
        end
      end
    end
  end
  return contents_cache
end

local function read_cargo(train)
  local held, containers, used, slots = {}, 0, 0, 0
  local map = contents()
  for _, wagon in pairs(train.cargo_wagons) do
    local inventory = wagon.get_inventory(defines.inventory.cargo_wagon)
    if inventory then
      slots = slots + #inventory
      used = used + #inventory - inventory.count_empty_stacks()
      for _, stack in pairs(inventory.get_contents()) do
        local inside = map[stack.name]
        if inside then
          containers = containers + stack.count
          local quality = inside.type == "fluid" and "normal" or (stack.quality or "normal")
          local key = inside.type .. "/" .. inside.name .. "/" .. quality
          held[key] = held[key] or {type = inside.type, name = inside.name, quality = quality, count = 0}
          held[key].count = held[key].count + stack.count * inside.amount
        end
      end
    end
  end
  return held, containers, slots > 0 and math.floor(used * 100 / slots + 0.5) or 0
end

local function virtual(name) return {type = "virtual", name = name, quality = "normal"} end

local function set_signals(sensor, held, containers, fill)
  local behavior = sensor.get_or_create_control_behavior()
  local section = behavior.get_section(1) or behavior.add_section()
  if not section then return end
  local filters = {}
  if held then
    filters[1] = {value = virtual("ff-cargo-containers"), min = containers}
    filters[2] = {value = virtual("ff-cargo-fill"), min = fill}
    filters[3] = {value = virtual("ff-cargo-vehicles"), min = 1}
    for _, entry in pairs(held) do
      if #filters >= MAX_SLOTS then break end
      local count = math.min(entry.count, 2147483647)
      filters[#filters + 1] = {value = {type = entry.type, name = entry.name, quality = entry.quality}, min = count}
    end
  end
  section.filters = filters
end

local function update()
  local sensors = storage.ff_cargo_sensors
  if not sensors then return end
  for unit_number, sensor in pairs(sensors) do
    if not sensor.valid then
      sensors[unit_number] = nil
    else
      local held, containers, fill
      for _, stop in pairs(sensor.surface.find_entities_filtered{type = "train-stop", position = sensor.position, radius = RADIUS}) do
        local train = stop.get_stopped_train()
        if train then
          held, containers, fill = read_cargo(train)
          break
        end
      end
      set_signals(sensor, held, containers, fill)
    end
  end
end

local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == SENSOR) then return end
  entity.operable = false
  storage.ff_cargo_sensors = storage.ff_cargo_sensors or {}
  storage.ff_cargo_sensors[entity.unit_number] = entity
end

---@type ScriptLib
local CargoSensor = {}

CargoSensor.events = {
  [defines.events.on_built_entity] = on_built,
  [defines.events.on_robot_built_entity] = on_built,
  [defines.events.script_raised_built] = on_built,
  [defines.events.script_raised_revive] = on_built,
}

CargoSensor.on_nth_tick = {
  [30] = update,
}

CargoSensor.add_remote_interface = function()
  remote.add_interface("ff-cargo-sensor", {
    -- for tests: what a train would show
    read = function(train) local held, containers, fill = read_cargo(train) return held, containers, fill end,
  })
end

return CargoSensor
