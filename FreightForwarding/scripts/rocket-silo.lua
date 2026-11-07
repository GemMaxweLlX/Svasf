-- Rocket silos on Nauvis can only be built in naturally occurring rocket silo holes.
--
-- Without Space Age the silo item places a dummy mining drill which can only be placed on a hole resource;
-- the dummy is replaced by the real silo here.
-- With Space Age the rule applies to the light (tier 1) rocket silo on Nauvis only, enforced below when it is
-- built; on other planets it can be built anywhere, and the normal silo anywhere (prototypes/rocket-tiers.lua).

local function on_rocket_silo_hole_created(event)
  local hole = event.target_entity
  hole.amount = 1
  hole.destructible = false

  hole.surface.destroy_decoratives{
    area = hole.bounding_box,
  }
end

local function on_rocket_silo_created(event)
  local dummy = event.target_entity
  local force = dummy.force
  local surface = dummy.surface
  local position = dummy.position
  local quality = dummy.quality
  dummy.destroy()
  local silo_name = "rocket-silo"
  if prototypes.entity["ff-light-rocket-silo"] then
    silo_name = "ff-light-rocket-silo"
  elseif script.active_mods["Rocket-Silo-Construction"] then
    silo_name = "rsc-silo-stage1"
  end
  surface.create_entity{
    name = silo_name,
    position = position,
    force = force,
    quality = quality,
    create_build_effect_smoke = false,
    raise_built = true,
  }
end

local function on_script_trigger_effect(event)
  if event.effect_id == "ff-rocket-silo-hole-created" then on_rocket_silo_hole_created(event) end
  if event.effect_id == "ff-rocket-silo-created" then on_rocket_silo_created(event) end
end

---------------------------------------------------------------------------------------------------
-- Space Age: light rocket silo on Nauvis must be built exactly on a hole

local LIGHT_SILO = "ff-light-rocket-silo"

local function is_on_hole(surface, position)
  return #surface.find_entities_filtered{name = "ff-rocket-silo-hole", position = position, radius = 0.6} > 0
end

local function refuse(event, entity, message_key)
  local player = event.player_index and game.get_player(event.player_index)
  local message = {message_key}
  if player then
    player.create_local_flying_text{text = message, create_at_cursor = true}
  else
    entity.force.print(message)
  end
end

local function on_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end
  local is_ghost = entity.type == "entity-ghost"
  local name = is_ghost and entity.ghost_name or entity.name
  if name ~= LIGHT_SILO then return end
  if entity.surface.name ~= "nauvis" then return end
  if not prototypes.entity["ff-rocket-silo-hole"] then return end
  if is_on_hole(entity.surface, entity.position) then return end

  refuse(event, entity, "freight-forwarding.rocket-silo-needs-hole")
  if is_ghost then
    entity.destroy()
    return
  end
  -- Refund the silo
  local item = {name = LIGHT_SILO, count = 1, quality = entity.quality and entity.quality.name or nil}
  local surface, position, force = entity.surface, entity.position, entity.force
  local player = event.player_index and game.get_player(event.player_index)
  local buffer = event.robot and event.robot.get_inventory(defines.inventory.robot_cargo)
  entity.destroy()
  if player and player.can_insert(item) and player.insert(item) > 0 then return end
  if buffer and buffer.can_insert(item) and buffer.insert(item) > 0 then return end
  surface.spill_item_stack{position = position, stack = item, enable_looted = true, force = force, allow_belts = false}
end

-- Researching any of the three "Heavy-lift rockets" technologies completes the other two
local HEAVY_LIFT_PREFIX = "ff-heavy-lift-rockets-"
local function on_research_finished(event)
  local research = event.research
  if research.name:sub(1, #HEAVY_LIFT_PREFIX) ~= HEAVY_LIFT_PREFIX then return end
  for name, technology in pairs(research.force.technologies) do
    if name:sub(1, #HEAVY_LIFT_PREFIX) == HEAVY_LIFT_PREFIX and not technology.researched then
      technology.researched = true
    end
  end
end

---@type ScriptLib
local RocketSilo = {}

RocketSilo.events = {
  [defines.events.on_script_trigger_effect] = on_script_trigger_effect,
  [defines.events.on_built_entity] = on_built,
  [defines.events.on_robot_built_entity] = on_built,
  [defines.events.script_raised_built] = on_built,
  [defines.events.on_research_finished] = on_research_finished,
}

RocketSilo.on_init = function()
  if not prototypes.entity["ff-rocket-silo-hole"] then return end
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type = "resource", name = "ff-rocket-silo-hole"}) do
      on_rocket_silo_hole_created({ target_entity = entity })
    end
  end
end

return RocketSilo
