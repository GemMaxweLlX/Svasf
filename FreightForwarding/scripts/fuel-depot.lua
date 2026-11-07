-- Fuel depot: a chest next to a train stop or port. When a train or ship stops at the station, its locomotives /
-- ship engines drop their burnt fuel (e.g. empty batteries) into the depot and are refuelled from it.

local DEPOT = "ff-fuel-depot"
local DEPOT_RADIUS = 10

local function service_locomotive(locomotive, depots)
  local burnt = locomotive.get_burnt_result_inventory()
  if burnt and not burnt.is_empty() then
    for i = 1, #burnt do
      local stack = burnt[i]
      if stack.valid_for_read then
        for _, depot in pairs(depots) do
          local inserted = depot.insert(stack)
          if inserted > 0 then stack.count = stack.count - inserted end
          if not stack.valid_for_read then break end
        end
      end
    end
  end

  local fuel = locomotive.get_fuel_inventory()
  if not fuel then return end
  for _, depot in pairs(depots) do
    local inventory = depot.get_inventory(defines.inventory.chest)
    for i = 1, #inventory do
      local stack = inventory[i]
      if stack.valid_for_read and fuel.can_insert(stack) then
        local inserted = fuel.insert(stack)
        if inserted > 0 then stack.count = stack.count - inserted end
      end
    end
  end
end

local function on_train_changed_state(event)
  local train = event.train
  if not (train and train.valid and train.state == defines.train_state.wait_station) then return end
  local station = train.station
  if not (station and station.valid) then return end
  local depots = station.surface.find_entities_filtered{
    name = DEPOT, position = station.position, radius = DEPOT_RADIUS, force = station.force,
  }
  if #depots == 0 then return end
  for _, movers in pairs{train.locomotives.front_movers, train.locomotives.back_movers} do
    for _, locomotive in pairs(movers) do
      service_locomotive(locomotive, depots)
    end
  end
end

---@type ScriptLib
local FuelDepot = {}

FuelDepot.events = {
  [defines.events.on_train_changed_state] = on_train_changed_state,
}

return FuelDepot
