-- Space Age: the interstellar freight contract. Every 10 seconds, freight consignments in the hub of a space platform
-- at the shattered planet are taken in. When the contract is fulfilled, the force wins (and can keep playing).

local ITEM = "ff-freight-consignment"
local LOCATIONS = {["shattered-planet"] = true}

local function contract_size()
  return settings.startup["ff-freight-contract-size"].value
end

local function check()
  if not prototypes.item[ITEM] then return end
  storage.ff_contract = storage.ff_contract or {}
  local goal = contract_size()
  for _, force in pairs(game.forces) do
    local delivered = storage.ff_contract[force.index] or 0
    if delivered < goal then
      for _, platform in pairs(force.platforms) do
        local location = platform.valid and platform.space_location
        local hub = platform.valid and platform.hub
        if location and LOCATIONS[location.name] and hub and hub.valid then
          local inventory = hub.get_inventory(defines.inventory.hub_main)
          local taken = inventory and inventory.remove{name = ITEM, count = goal - delivered} or 0
          if taken > 0 then
            delivered = delivered + taken
            storage.ff_contract[force.index] = delivered
            force.print({"ff-contract.progress", delivered, goal})
          end
        end
      end
      if delivered >= goal then
        force.print({"ff-contract.fulfilled"})
        game.set_win_ending_info{title = {"ff-contract.victory-title"}, message = {"ff-contract.victory-message"}}
        game.set_game_state{game_finished = true, player_won = true, can_continue = true, victorious_force = force}
      end
    end
  end
end

---@type ScriptLib
local FreightContract = {}

FreightContract.on_nth_tick = {
  [600] = function()
    if script.active_mods["space-age"] then check() end
  end,
}

FreightContract.add_remote_interface = function()
  remote.add_interface("ff-freight-contract", {
    progress = function(force_index) return (storage.ff_contract or {})[force_index or 1] or 0, contract_size() end,
  })
end

return FreightContract
