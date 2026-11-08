-- Cargo insurance (prototypes/cargo-insurance.lua). When a cargo wagon, ship, boat or spidertron is destroyed, the
-- payout (setting ff-insurance-payout, percent of every stack, rounded down) goes into the nearest insurance office
-- of the same force on the same surface. What does not fit is lost. Mined vehicles are not destroyed: no payout.

local OFFICE = "ff-insurance-office"
local INVENTORIES = {
  ["cargo-wagon"] = defines.inventory.cargo_wagon,
  ["car"] = defines.inventory.car_trunk,
  ["spider-vehicle"] = defines.inventory.spider_trunk,
}

local function payout_rate()
  local setting = settings.global["ff-insurance-payout"]
  return (setting and setting.value or 50) / 100
end

local function stats()
  storage.ff_insurance = storage.ff_insurance or {claims = 0, items = 0}
  return storage.ff_insurance
end

local function on_entity_died(event)
  local vehicle = event.entity
  if not (vehicle and vehicle.valid) then return end
  local inventory_id = INVENTORIES[vehicle.type]
  if not inventory_id then return end
  local inventory = vehicle.get_inventory(inventory_id)
  if not inventory or inventory.is_empty() then return end
  local offices = vehicle.surface.find_entities_filtered{name = OFFICE, force = vehicle.force}
  if #offices == 0 then return end
  local office = vehicle.surface.get_closest(vehicle.position, offices)
  local rate = payout_rate()
  if rate <= 0 then return end
  local paid, lost = 0, 0
  local office_inventory = office.get_inventory(defines.inventory.chest)
  for _, stack in pairs(inventory.get_contents()) do
    local count = math.floor(stack.count * rate)
    if count > 0 then
      local inserted = office_inventory.insert{name = stack.name, count = count, quality = stack.quality}
      paid = paid + inserted
      lost = lost + count - inserted
    end
  end
  if paid == 0 and lost == 0 then return end
  local s = stats()
  s.claims = s.claims + 1
  s.items = s.items + paid
  local where = string.format("[gps=%d,%d,%s]", math.floor(office.position.x), math.floor(office.position.y), office.surface.name)
  vehicle.force.print({"ff-insurance.paid", vehicle.localised_name, paid, where, math.floor(rate * 100 + 0.5)})
  if lost > 0 then vehicle.force.print({"ff-insurance.full", lost}) end
end

---@type ScriptLib
local CargoInsurance = {}

CargoInsurance.events = {
  [defines.events.on_entity_died] = on_entity_died,
}

CargoInsurance.add_remote_interface = function()
  remote.add_interface("ff-cargo-insurance", {
    stats = function() return stats().claims, stats().items end,
  })
end

return CargoInsurance
