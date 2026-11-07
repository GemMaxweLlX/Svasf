local function interfering_mods()
  -- Space Age has its own victory condition (reaching the solar system edge)
  return script.active_mods["Krastorio2"] or script.active_mods["SpaceMod"] or script.active_mods["space-age"]
end

local function rocket_has_communicator(silo)
  if not (silo and silo.valid) then return false end
  local inventory = silo.get_inventory(defines.inventory.rocket_silo_rocket)
  return inventory and inventory.get_item_count("ff-interstellar-communicator") > 0
end

-- 2.x: the rocket's contents are moved to a cargo pod at launch, so check the silo when the
-- launch is ordered and remember it until the rocket is launched.
local function on_rocket_launch_ordered(event)
  if interfering_mods() then return end
  if rocket_has_communicator(event.rocket_silo) then
    storage.communicator_launches = storage.communicator_launches or {}
    storage.communicator_launches[event.rocket_silo.unit_number] = true
  end
end

local function on_rocket_launched(event)
  if interfering_mods() then return end

  local silo = event.rocket_silo
  if not (silo and silo.valid) then return end
  local launches = storage.communicator_launches or {}
  local had_communicator = launches[silo.unit_number]
  launches[silo.unit_number] = nil

  if game.finished or game.finished_but_continuing or storage.finished then return end

  if had_communicator then
    storage.finished = true
    local force = silo.force

    if remote.interfaces["better-victory-screen"] and remote.interfaces["better-victory-screen"]["trigger_victory"] then
      remote.call("better-victory-screen", "trigger_victory", force)
    else
      game.set_game_state{
        game_finished = true,
        player_won = true,
        can_continue = true,
        victorious_force = force
      }
    end

  end
end

local function disable_rocket_victory()
  if interfering_mods() then return end

  for interface, functions in pairs(remote.interfaces) do
    if (functions["set_no_victory"] ~= nil) then
      remote.call(interface, "set_no_victory", true)
    end
  end

  if remote.interfaces["freeplay"] and remote.interfaces["freeplay"]["set_custom_intro_message"] then
    remote.call("freeplay", "set_custom_intro_message", {"freight-forwarding.msg-intro"})
  end
end

---@type ScriptLib
local Endgame = {}

Endgame.events = {
  [defines.events.on_rocket_launch_ordered] = on_rocket_launch_ordered,
  [defines.events.on_rocket_launched] = on_rocket_launched,
}

Endgame.on_init = disable_rocket_victory
Endgame.on_configuration_changed = disable_rocket_victory

return Endgame
