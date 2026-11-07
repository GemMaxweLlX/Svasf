---@param winning_force LuaForce the force that triggered the victory
---@param forces LuaForce[] list of forces victory screen will be shown to
---@return unknown
local function better_victory_screen_statistics(winning_force, forces)
  local statistics = { by_force = {} }
  for _, force in pairs(forces) do
    -- 2.x: production statistics are per surface
    local containers_created = 0
    for _, surface in pairs(game.surfaces) do
      containers_created = containers_created + force.get_item_production_statistics(surface).get_input_count("ic-container")
    end
    statistics.by_force[force.name] = {
      -- Add it to the existing production category
      ["production"] = { stats = {
        ["containers"] = { value = containers_created, order = "p" },
      } }
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
