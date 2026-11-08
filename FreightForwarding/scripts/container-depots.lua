-- Intermodal Containers depots, worked every 2 seconds:
--   packing depot (storage chest): packs loose items into containers, using empty containers inside it
--   unpacking depot (passive provider): unpacks full containers into loose items and empty containers

local PACKING = "ff-packing-depot"
local UNPACKING = "ff-unpacking-depot"
local EMPTY = "ic-container"

local load_map, unload_map
local function maps()
  if load_map then return load_map, unload_map end
  load_map, unload_map = {}, {}
  for name, recipe in pairs(prototypes.recipe) do
    if name:sub(1, 8) == "ic-load-" then
      local base = name:sub(9)
      local filled
      for _, product in pairs(recipe.products) do filled = product.name end
      for _, ingredient in pairs(recipe.ingredients) do
        if ingredient.name == base and filled then
          load_map[base] = {filled = filled, amount = ingredient.amount}
          unload_map[filled] = {base = base, amount = ingredient.amount}
        end
      end
    end
  end
  return load_map, unload_map
end

local function pack(depot)
  local inventory = depot.get_inventory(defines.inventory.chest)
  local loads = maps()
  local empties = inventory.get_item_count(EMPTY)
  if empties == 0 then return end
  for _, content in pairs(inventory.get_contents()) do
    local entry = loads[content.name]
    if entry and (content.quality or "normal") == "normal" then
      local count = math.min(math.floor(content.count / entry.amount), empties)
      for _ = 1, count do
        if not inventory.can_insert{name = entry.filled, count = 1} then return end
        inventory.remove{name = content.name, count = entry.amount}
        inventory.remove{name = EMPTY, count = 1}
        inventory.insert{name = entry.filled, count = 1}
        empties = empties - 1
      end
      if empties == 0 then return end
    end
  end
end

local function unpack(depot)
  local inventory = depot.get_inventory(defines.inventory.chest)
  local _, unloads = maps()
  for _, content in pairs(inventory.get_contents()) do
    local entry = unloads[content.name]
    if entry then
      for _ = 1, content.count do
        inventory.remove{name = content.name, count = 1}
        local inserted = inventory.insert{name = entry.base, count = entry.amount}
        if inserted < entry.amount or not inventory.can_insert{name = EMPTY, count = 1} then
          -- Not enough room: put everything back as it was
          if inserted > 0 then inventory.remove{name = entry.base, count = inserted} end
          inventory.insert{name = content.name, count = 1}
          return
        end
        inventory.insert{name = EMPTY, count = 1}
      end
    end
  end
end

local function update()
  local depots = storage.ff_container_depots
  if not depots then return end
  for unit_number, depot in pairs(depots) do
    if not depot.valid then
      depots[unit_number] = nil
    elseif depot.name == PACKING then
      pack(depot)
    else
      unpack(depot)
    end
  end
end

local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid and (entity.name == PACKING or entity.name == UNPACKING)) then return end
  storage.ff_container_depots = storage.ff_container_depots or {}
  storage.ff_container_depots[entity.unit_number] = entity
end

---@type ScriptLib
local ContainerDepots = {}

ContainerDepots.events = {
  [defines.events.on_built_entity] = on_built,
  [defines.events.on_robot_built_entity] = on_built,
  [defines.events.script_raised_built] = on_built,
  [defines.events.script_raised_revive] = on_built,
}

ContainerDepots.on_nth_tick = {
  [120] = update,
}

return ContainerDepots
