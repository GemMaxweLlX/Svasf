-- Dredger planner (prototypes/dredger-planner.lua). For every seamount / vent selected: skip it if its chunk is not
-- charted by the player's force, if a dredger or a planned one is already close (platforms would overlap) or if the
-- platform doesn't fit; otherwise place a ghost of the dredging platform. Normal selection plans the first dredger,
-- alt-selection the best one whose recipe the force has.

local TOOL = "ff-dredger-planner"
local TIERS = {"ff-dredging-platform", "ff-dredging-platform-mk2", "ff-dredging-platform-mk3"}
local SPACING = {["ff-dredging-platform"] = 18, ["ff-dredging-platform-mk2"] = 24, ["ff-dredging-platform-mk3"] = 30}
local DREDGERS = {"ff-dredger", "ff-dredger-mk2", "ff-dredger-mk3"}

local function best_tier(force)
  local best = TIERS[1]
  for _, name in pairs(TIERS) do
    if prototypes.entity[name] and force.recipes[name] and force.recipes[name].enabled then best = name end
  end
  return best
end

local function existing(names)
  local list = {}
  for _, name in pairs(names) do if prototypes.entity[name] then list[#list + 1] = name end end
  return list
end

local function plan(player, surface, resources, placer, ignore_chart)
  local force = player.force
  local spacing = SPACING[placer] or 18
  local placed, uncharted, blocked = 0, 0, 0
  local dredgers = existing(DREDGERS)
  local placers = existing(TIERS)
  for _, resource in pairs(resources) do
    if resource.valid then
      local position = resource.position
      local chunk = {x = math.floor(position.x / 32), y = math.floor(position.y / 32)}
      if not ignore_chart and not force.is_chunk_charted(surface, chunk) then
        uncharted = uncharted + 1
      else
        local near = surface.count_entities_filtered{name = dredgers, position = position, radius = spacing, limit = 1}
                   + surface.count_entities_filtered{ghost_name = placers, position = position, radius = spacing, limit = 1}
        if near > 0 or not surface.can_place_entity{name = placer, position = position, force = force,
                                                     build_check_type = defines.build_check_type.manual_ghost} then
          blocked = blocked + 1
        else
          local ghost = surface.create_entity{name = "entity-ghost", inner_name = placer, position = position,
                                              force = force, player = player.object_name == "LuaPlayer" and player or nil}
          if ghost then placed = placed + 1 else blocked = blocked + 1 end
        end
      end
    end
  end
  player.print({"ff-planner.result", placed, {"entity-name." .. placer}, blocked, uncharted})
  return placed, blocked, uncharted
end

local function on_selected(event, alt)
  if event.item ~= TOOL then return end
  local player = game.get_player(event.player_index)
  local placer = alt and best_tier(player.force) or TIERS[1]
  plan(player, event.surface, event.entities, placer)
end

---@type ScriptLib
local DredgerPlanner = {}

DredgerPlanner.events = {
  [defines.events.on_player_selected_area] = function(event) on_selected(event, false) end,
  [defines.events.on_player_alt_selected_area] = function(event) on_selected(event, true) end,
}

DredgerPlanner.add_remote_interface = function()
  remote.add_interface("ff-dredger-planner", {
    -- for tests: plan with a force instead of a player (prints to the force)
    plan = function(force_name, surface, area, placer, ignore_chart)
      local force = game.forces[force_name]
      local resources = surface.find_entities_filtered{area = area, name = existing{"ff-seamount", "ff-cobalt-vent", "ff-scrap-seamount"}}
      local fake = {force = force, print = function(message) force.print(message) end}
      local ok, placed, blocked, uncharted = pcall(plan, fake, surface, resources, placer or TIERS[1], ignore_chart)
      if not ok then return placed end
      return placed, blocked, uncharted
    end,
  })
end

return DredgerPlanner
