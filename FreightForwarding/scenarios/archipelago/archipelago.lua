-- Archipelago goals. The map: many small islands (the water control turned up), so ships are needed early.
-- Goals are checked every 2 seconds; each one done gives a reward to every connected player (or into the spawn
-- area if their inventory is full) and shows the next goal.

local CHECK_TICKS = 120

local function produced(force, item)
  local total = 0
  for _, surface in pairs(game.surfaces) do
    total = total + force.get_item_production_statistics(surface).get_input_count(item)
  end
  return total
end

local function count_built(force, names)
  if type(names) == "string" then names = {names} end
  local existing = {}
  for _, name in pairs(names) do if prototypes.entity[name] then existing[#existing + 1] = name end end
  if #existing == 0 then return 0 end
  local total = 0
  for _, surface in pairs(game.surfaces) do
    total = total + surface.count_entities_filtered{name = existing, force = force}
  end
  return total
end

local function researched(force, tech)
  local t = force.technologies[tech]
  return t and t.researched
end

-- Every goal: key (locale ff-archipelago.goal-<key>), done(force) -> bool, progress(force) -> string, reward items.
-- Goals whose prototypes are missing (other mods turned off) are skipped.
local GOALS = {
  {key = "ships", needs = {technology = "cargo_ships"},
   done = function(f) return researched(f, "cargo_ships") end,
   reward = {{name = "port", count = 2}, {name = "buoy", count = 10}}},
  {key = "port", needs = {entity = "port"},
   done = function(f) return count_built(f, "port") >= 2 end,
   progress = function(f) return count_built(f, "port") .. "/2" end,
   reward = {{name = "cargo_ship", count = 1}}},
  {key = "containers", needs = {item = "ic-container"},
   done = function(f) return produced(f, "ic-container") >= 100 end,
   progress = function(f) return math.min(100, produced(f, "ic-container")) .. "/100" end,
   reward = {{name = "steel-plate", count = 200}}},
  {key = "dredger", needs = {entity = "ff-dredger"},
   done = function(f) return count_built(f, {"ff-dredger", "ff-dredger-mk2", "ff-dredger-mk3"}) >= 1 end,
   reward = {{name = "landfill", count = 200}}},
  {key = "sea-infrastructure", needs = {technology = "ff-sea-infrastructure"},
   done = function(f) return researched(f, "ff-sea-infrastructure") end,
   reward = {{name = "ff-port-crane", count = 4}}},
  {key = "transport-science", needs = {item = "ff-transport-science-pack"},
   done = function(f) return produced(f, "ff-transport-science-pack") >= 1000 end,
   progress = function(f) return math.min(1000, produced(f, "ff-transport-science-pack")) .. "/1000" end,
   reward = {{name = "speed-module", count = 10}}},
  {key = "rocket", needs = {item = "rocket-silo"},
   done = function(f) return researched(f, "rocket-silo") end,
   reward = {{name = "solar-panel", count = 50}}},
}

local function available(goal)
  local needs = goal.needs or {}
  if needs.technology and not prototypes.technology[needs.technology] then return false end
  if needs.entity and not prototypes.entity[needs.entity] then return false end
  if needs.item and not prototypes.item[needs.item] then return false end
  return true
end

local function current()
  local index = storage.archipelago.goal
  while GOALS[index] and not available(GOALS[index]) do index = index + 1 end
  storage.archipelago.goal = index
  return GOALS[index], index
end

local function goal_text(force)
  local goal = current()
  if not goal then return {"ff-archipelago.all-done"} end
  local progress = goal.progress and goal.progress(force) or ""
  return {"", {"ff-archipelago.header"}, "\n", {"ff-archipelago.goal-" .. goal.key}, progress ~= "" and ("\n" .. progress) or ""}
end

local function show(player) player.set_goal_description(goal_text(player.force)) end

local function give(player, items)
  for _, item in pairs(items) do
    if prototypes.item[item.name] then
      local inserted = player.insert(item)
      if inserted < item.count and player.character then
        player.surface.spill_item_stack{position = player.position, stack = {name = item.name, count = item.count - inserted}}
      end
    end
  end
end

local function check()
  local force = game.forces.player
  local goal = current()
  while goal and goal.done(force) do
    for _, player in pairs(force.connected_players) do give(player, goal.reward or {}) end
    force.print({"ff-archipelago.done", {"ff-archipelago.goal-" .. goal.key}})
    storage.archipelago.goal = storage.archipelago.goal + 1
    goal = current()
  end
  for _, player in pairs(force.connected_players) do show(player) end
end

local function make_islands()
  local surface = game.surfaces.nauvis
  local mgs = surface.map_gen_settings
  -- Archipelago island terrain (prototypes/map-gen.lua), whatever the map preset was
  mgs.property_expression_names = mgs.property_expression_names or {}
  mgs.property_expression_names.elevation = "ff-archipelago"
  mgs.property_expression_names.cliff_elevation = "ff_cliff_elevation"
  surface.map_gen_settings = mgs
  surface.clear(true)
end

local lib = {}

lib.on_init = function()
  storage.archipelago = {goal = 1}
  make_islands()
  if remote.interfaces.freeplay then
    remote.call("freeplay", "set_custom_intro_message", {"ff-archipelago.intro"})
  end
end

lib.events = {
  [defines.events.on_player_created] = function(event) show(game.get_player(event.player_index)) end,
  [defines.events.on_player_joined_game] = function(event) show(game.get_player(event.player_index)) end,
}

lib.on_nth_tick = {[CHECK_TICKS] = check}

lib.add_remote_interface = function()
  remote.add_interface("ff-archipelago", {
    goal = function() local goal, index = current() return goal and goal.key, index end,
    check = check,
  })
end

return lib
