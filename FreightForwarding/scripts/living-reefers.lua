-- Living reefers (Space Age, runtime setting ff-living-reefers, off by default). Reefers carried in trains and ships
-- keep their contents alive: each filled reefer uses 1 feed every 10 minutes, taken from the same cargo hold:
-- bioflux (keeps for hours, the practical choice) or nutrients (spoil within minutes outside a reefer). Without nutrients it still slows spoilage, but only 2 times instead of 5 (it ages 2.5 times
-- faster than a fed reefer). Reefers in chests and warehouses are not affected.

local CHECK = 600                    -- ticks
local NUTRIENT_TICKS = 10 * 60 * 60  -- one nutrients per reefer per 10 minutes
local FED, HUNGRY = 5, 2             -- spoil slowdown of a fed and a hungry reefer
local FOODS = {"bioflux", "nutrients"}

local function is_reefer(stack)
  if not (stack.valid_for_read and stack.name:sub(1, 10) == "ff-reefer-") then return false end
  local ticks = stack.prototype.get_spoil_ticks(stack.quality)
  return ticks ~= nil and ticks > 0
end

local function update()
  local setting = settings.global["ff-living-reefers"]
  if not (setting and setting.value) then return end
  storage.ff_reefer_hunger = storage.ff_reefer_hunger or {}
  local hunger = storage.ff_reefer_hunger
  for _, train in pairs(game.train_manager.get_trains{}) do
    for _, wagon in pairs(train.cargo_wagons) do
      local inventory = wagon.get_inventory(defines.inventory.cargo_wagon)
      if inventory and not inventory.is_empty() then
        local reefers = {}
        for i = 1, #inventory do
          local stack = inventory[i]
          if is_reefer(stack) then reefers[#reefers + 1] = stack end
        end
        if #reefers > 0 then
          local need = (hunger[wagon.unit_number] or 0) + #reefers * CHECK / NUTRIENT_TICKS
          local whole = math.floor(need)
          local fed = true
          local available = 0
          for _, food in pairs(FOODS) do
            if prototypes.item[food] then available = available + inventory.get_item_count(food) end
          end
          if whole > 0 then
            local removed = 0
            for _, food in pairs(FOODS) do
              if removed < whole and prototypes.item[food] then
                removed = removed + inventory.remove{name = food, count = whole - removed}
              end
            end
            fed = removed >= whole
            need = fed and (need - removed) or 0
          elseif available == 0 then
            fed = false
          end
          hunger[wagon.unit_number] = need
          if not fed then
            -- age the contents faster: a hungry reefer spoils FED/HUNGRY times as fast as a fed one
            local extra = FED / HUNGRY - 1
            for _, stack in pairs(reefers) do
              local total = stack.prototype.get_spoil_ticks(stack.quality)
              if total and total > 0 then
                stack.spoil_percent = math.min(1, stack.spoil_percent + extra * CHECK / total)
              end
            end
          end
        end
      end
    end
  end
end

---@type ScriptLib
local LivingReefers = {}

LivingReefers.on_nth_tick = {
  [CHECK] = update,
}

LivingReefers.add_remote_interface = function()
  remote.add_interface("ff-living-reefers", {update = update})
end

return LivingReefers
