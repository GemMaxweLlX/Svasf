---@param winning_force LuaForce the force that triggered the victory
---@param forces LuaForce[] list of forces victory screen will be shown to
---@return unknown
local function better_victory_screen_statistics(winning_force, forces)
  local statistics = { by_force = {} }
  for _, force in pairs(forces) do
    -- 2.x: production statistics are per surface; containers of every kind (filled ones = packed)
    local containers_created, packed = 0, 0
    for _, surface in pairs(game.surfaces) do
      local stats = force.get_item_production_statistics(surface)
      for _, empty in pairs{"ic-container", "ff-reefer-container", "ff-light-container", "ff-cryo-container"} do
        if prototypes.item[empty] then containers_created = containers_created + stats.get_input_count(empty) end
      end
    end
    local freight = remote.interfaces["ff-freight-contract"] and remote.call("ff-freight-contract", "statistics", force.index) or {}
    for _, row in pairs(freight) do packed = packed + row.packed end
    local stats = {
      ["containers"] = { value = containers_created, order = "p" },
      ["ff-containers-packed"] = { value = packed, order = "q" },
    }
    local contract = storage.ff_contract and storage.ff_contract[force.index]
    if type(contract) == "table" then
      stats["ff-contracts"] = { value = contract.completed or 0, order = "r" }
      stats["ff-consignments"] = { value = contract.total or 0, order = "s" }
    end
    statistics.by_force[force.name] = {
      -- Add it to the existing production category
      ["production"] = { stats = stats },
    }
  end
  return statistics
end

---@return table<string, function>
local function remote_interface_fragment()
  if not script.active_mods["better-victory-screen"] then return {} end

  return {
    ["better-victory-screen-statistics"] = function(winning_force, forces)
      return better_victory_screen_statistics(winning_force, forces)
    end
  }
end

return
{
  remote_interface_fragment = remote_interface_fragment,
}
