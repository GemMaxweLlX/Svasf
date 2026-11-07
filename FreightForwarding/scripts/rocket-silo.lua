-- Rocket silos on Nauvis can only be built in naturally occurring rocket silo holes.
--
-- The silo item places a dummy mining drill which can only be placed on a hole resource; the dummy is
-- replaced by the real silo here. With Space Age this applies to the light (tier 1) rocket silo; the
-- normal silo can be built anywhere (see prototypes/rocket-tiers.lua).

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

---@type ScriptLib
local RocketSilo = {}

RocketSilo.events = {
  [defines.events.on_script_trigger_effect] = on_script_trigger_effect,
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
