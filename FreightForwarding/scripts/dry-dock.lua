-- Dry dock (prototypes/dry-dock.lua). Every 2 seconds each dock looks at the ships standing still within RADIUS:
--   * repair: damaged hulls and engines are repaired with repair packs from the dock (REPAIR_PER_PACK hp each);
--   * swap: if a ship type is chosen in the dock's panel and the dock holds that ship, a ship of another type (same
--     kind: cargo or tanker) is replaced in place by it. Cargo, fuel, schedule, health and quality move over; the old
--     ship goes into the dock. Cargo that doesn't fit the new hold stays in the dock.
-- Only single ships (body + engine) are swapped, never a ship coupled with others.

local DOCK = "ff-dry-dock"
local RADIUS = 16
local REPAIR_PER_PACK = 300

local function data()
  storage.ff_docks = storage.ff_docks or {}
  return storage.ff_docks
end

-- Ship bodies and engines from Cargo Ships' ship definitions
local ships
local function ship_defs()
  if ships then return ships end
  ships = {bodies = {}, engines = {}}
  for _, entry in pairs(prototypes.mod_data) do
    if entry.data_type == "cargo-ships.ship-definition" and entry.data.name and prototypes.entity[entry.data.name] then
      ships.bodies[entry.data.name] = {engine = entry.data.engine, type = prototypes.entity[entry.data.name].type}
      if entry.data.engine then ships.engines[entry.data.engine] = true end
    end
  end
  return ships
end

local function body_of(train)
  for _, carriage in pairs(train.carriages) do
    if ship_defs().bodies[carriage.name] then return carriage end
  end
end

---------------------------------------------------------------------------------------------------
-- Repair

local function repair(dock, entity)
  if not (entity.valid and entity.health and entity.health < entity.max_health) then return end
  local inventory = dock.get_inventory(defines.inventory.chest)
  while entity.health < entity.max_health do
    local stack = inventory.find_item_stack("repair-pack")
    if not stack then return end
    entity.health = math.min(entity.max_health, entity.health + REPAIR_PER_PACK)
    stack.drain_durability(stack.prototype.get_durability(stack.quality))
  end
end

---------------------------------------------------------------------------------------------------
-- Swap

local function orientation_to_direction(orientation)
  return math.floor(orientation * 16 + 0.5) % 16
end

local function swap(dock, train, target)
  if #train.carriages > 2 then return false end
  local body = body_of(train)
  if not body or body.name == target then return false end
  local defs = ship_defs()
  if defs.bodies[body.name].type ~= defs.bodies[target].type then return false end
  local inventory = dock.get_inventory(defines.inventory.chest)
  if inventory.get_item_count(target) < 1 then return false end

  -- save
  local surface, force, quality = body.surface, body.force, body.quality
  local position, direction = body.position, orientation_to_direction(body.orientation)
  local health = body.health / body.max_health
  local cargo = {}
  local hold = body.get_inventory(defines.inventory.cargo_wagon)
  if hold then for _, stack in pairs(hold.get_contents()) do cargo[#cargo + 1] = stack end end
  local fluids = body.type == "fluid-wagon" and body.get_fluid_contents() or {}
  local fuel = {}
  local schedule, manual = nil, train.manual_mode
  pcall(function() schedule = train.schedule end)
  for _, carriage in pairs(train.carriages) do
    if carriage ~= body and carriage.burner then
      local fuel_inventory = carriage.get_fuel_inventory()
      if fuel_inventory then for _, stack in pairs(fuel_inventory.get_contents()) do fuel[#fuel + 1] = stack end end
    end
  end

  -- take the new ship, remove the old one (engine first)
  inventory.remove{name = target, count = 1}
  local old_name = body.name
  for _, carriage in pairs(train.carriages) do
    if carriage ~= body then carriage.destroy{raise_destroy = false} end
  end
  body.destroy{raise_destroy = false}

  -- build the new one; Cargo Ships adds its engine on script_raised_built
  local new = surface.create_entity{name = target, position = position, direction = direction, force = force,
                                    quality = quality, raise_built = true, create_build_effect_smoke = false}
  if not new then
    -- could not place it: put the old ship back as an item, keep the new one and the cargo in the dock
    inventory.insert{name = target, count = 1}
    inventory.insert{name = old_name, count = 1, quality = quality}
    for _, stack in pairs(cargo) do inventory.insert(stack) end
    for _, stack in pairs(fuel) do inventory.insert(stack) end
    return false
  end
  new.health = new.max_health * health
  local new_hold = new.get_inventory(defines.inventory.cargo_wagon)
  for _, stack in pairs(cargo) do
    local inserted = new_hold and new_hold.insert(stack) or 0
    if inserted < stack.count then
      inventory.insert{name = stack.name, count = stack.count - inserted, quality = stack.quality}
    end
  end
  for fluid, amount in pairs(fluids) do new.insert_fluid{name = fluid, amount = amount} end
  local new_train = new.train
  for _, carriage in pairs(new_train.carriages) do
    if carriage ~= new and carriage.burner then
      local fuel_inventory = carriage.get_fuel_inventory()
      for _, stack in pairs(fuel) do
        local inserted = fuel_inventory and fuel_inventory.insert(stack) or 0
        if inserted < stack.count then inventory.insert{name = stack.name, count = stack.count - inserted, quality = stack.quality} end
      end
      fuel = {}
    end
  end
  for _, stack in pairs(fuel) do inventory.insert(stack) end
  if schedule then pcall(function() new_train.schedule = schedule end) end
  new_train.manual_mode = manual
  inventory.insert{name = old_name, count = 1, quality = quality}
  force.print({"ff-dock.swapped", {"entity-name." .. old_name}, {"entity-name." .. target},
               string.format("[gps=%d,%d,%s]", math.floor(position.x), math.floor(position.y), surface.name)})
  return true
end

---------------------------------------------------------------------------------------------------

local function update()
  for unit, record in pairs(data()) do
    local dock = record.entity
    if not dock.valid then
      data()[unit] = nil
    else
      local seen = {}
      for _, carriage in pairs(dock.surface.find_entities_filtered{type = {"cargo-wagon", "fluid-wagon", "locomotive"},
                                                                    position = dock.position, radius = RADIUS, force = dock.force}) do
        local train = carriage.valid and carriage.train
        if train and not seen[train.id] and body_of(train) and train.speed == 0 then
          seen[train.id] = true
          for _, part in pairs(train.carriages) do repair(dock, part) end
          if record.target and ship_defs().bodies[record.target] then swap(dock, train, record.target) end
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Panel next to the dock's window: which ship type to swap to

local PANEL = "ff_dock_panel"

local function open_panel(player, dock)
  if player.gui.relative[PANEL] then player.gui.relative[PANEL].destroy() end
  local record = data()[dock.unit_number]
  if not record then return end
  local frame = player.gui.relative.add{type = "frame", name = PANEL, direction = "vertical", caption = {"ff-dock.title"},
    anchor = {gui = defines.relative_gui_type.container_gui, position = defines.relative_gui_position.right, name = DOCK}}
  local inner = frame.add{type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical"}
  local names = {}
  for name in pairs(ship_defs().bodies) do if prototypes.item[name] then names[#names + 1] = name end end
  local row = inner.add{type = "flow", direction = "horizontal"}
  row.style.vertical_align = "center"
  row.add{type = "label", caption = {"ff-dock.swap-to"}}
  row.add{type = "choose-elem-button", name = "ff_dock_target", elem_type = "item", item = record.target,
          elem_filters = {{filter = "name", name = names}}, tags = {unit = dock.unit_number}}
  local hint = inner.add{type = "label", caption = {"ff-dock.hint", RADIUS, REPAIR_PER_PACK}}
  hint.style.single_line = false
  hint.style.maximal_width = 260
end

local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == DOCK) then return end
  data()[entity.unit_number] = {entity = entity}
end

local function on_gui_opened(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == DOCK then open_panel(game.get_player(event.player_index), entity) end
end

local function on_gui_elem_changed(event)
  local element = event.element
  if not (element and element.valid and element.name == "ff_dock_target") then return end
  local record = data()[element.tags.unit]
  if record then record.target = element.elem_value end
end

local function on_entity_settings_pasted(event)
  local from, to = event.source, event.destination
  if from.name == DOCK and to.name == DOCK and data()[from.unit_number] and data()[to.unit_number] then
    data()[to.unit_number].target = data()[from.unit_number].target
  end
end

---@type ScriptLib
local DryDock = {}

DryDock.events = {
  [defines.events.on_built_entity] = on_built,
  [defines.events.on_robot_built_entity] = on_built,
  [defines.events.script_raised_built] = on_built,
  [defines.events.script_raised_revive] = on_built,
  [defines.events.on_gui_opened] = on_gui_opened,
  [defines.events.on_gui_elem_changed] = on_gui_elem_changed,
  [defines.events.on_entity_settings_pasted] = on_entity_settings_pasted,
}

DryDock.on_nth_tick = {
  [120] = update,
}

DryDock.add_remote_interface = function()
  remote.add_interface("ff-dry-dock", {
    set_target = function(dock, name) local r = data()[dock.unit_number] if r then r.target = name end end,
    update = update,
  })
end

return DryDock
