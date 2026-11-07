-- Rocket silos can only be built in naturally occurring rocket silo holes.
--
-- Without Space Age the rocket silo item places a dummy mining drill which can only be placed on a
-- hole resource; the dummy is replaced by a real silo here.
-- With Space Age the item places a real silo (silos are needed on every planet), and on Nauvis a silo
-- built outside a hole is removed and refunded.

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
  surface.create_entity{
    name = script.active_mods["Rocket-Silo-Construction"] and "rsc-silo-stage1" or "rocket-silo",
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
-- Space Age: enforce holes on Nauvis by script

local function is_restricted_surface(surface)
  return surface.name == "nauvis"
end

local function is_on_hole(entity)
  local holes = entity.surface.find_entities_filtered{
    name = "ff-rocket-silo-hole",
    position = entity.position,
    radius = 1,
  }
  return #holes > 0
end

local function on_built_entity(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end
  if entity.name ~= "rocket-silo" and entity.name ~= "rsc-silo-stage1" then return end
  if not prototypes.entity["ff-rocket-silo-hole"] then return end
  if not is_restricted_surface(entity.surface) or is_on_hole(entity) then return end

  local player = event.player_index and game.get_player(event.player_index)
  local item = { name = "rocket-silo", count = 1, quality = entity.quality and entity.quality.name or nil }
  local surface, position, force = entity.surface, entity.position, entity.force
  entity.destroy()

  local refunded = false
  if player and player.can_insert(item) then
    refunded = player.insert(item) > 0
  end
  if not refunded then
    surface.spill_item_stack{ position = position, stack = item, enable_looted = true, force = force, allow_belts = false }
  end

  local message = {"freight-forwarding.rocket-silo-needs-hole"}
  if player then
    player.create_local_flying_text{ text = message, create_at_cursor = true }
  else
    force.print(message)
  end
end

---@type ScriptLib
local RocketSilo = {}

RocketSilo.events = {
  [defines.events.on_script_trigger_effect] = on_script_trigger_effect,
}

if script.active_mods["space-age"] then
  RocketSilo.events[defines.events.on_built_entity] = on_built_entity
  RocketSilo.events[defines.events.on_robot_built_entity] = on_built_entity
end

RocketSilo.on_init = function()
  if not prototypes.entity["ff-rocket-silo-hole"] then return end
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type = "resource", name = "ff-rocket-silo-hole"}) do
      on_rocket_silo_hole_created({ target_entity = entity })
    end
  end
end

return RocketSilo
