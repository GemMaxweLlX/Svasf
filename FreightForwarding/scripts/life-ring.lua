local x_scale = 0.4
local y_scale = 0.4
local scale = 0.4
--local offset = {x = 0, y = -0.5}
local splash_positions = {
  {0, 0.6},
  {0, -0.8},
  {-0.7, 0},
  {0.7, 0},
  {0.35, 0.55},
  {-0.35, 0.55},
  {0.55, 0.35},
  {-0.55, 0.35},
  {0.45, -0.65},
  {-0.45, -0.65},
  {0.65, -0.45},
  {-0.65, -0.45},
}

--local shadow_offset = {0.3, 0.3}
local shadow_offset = {0.2, 0.2}
local legs_offset = {0, 0.6}

local function add_offset(position, offset)
  return {x = position.x + (offset[1] or offset.x), y = position.y + (offset[2] or offset.y)}
end

local function get_offset(walking_state)
  local offset = {x = 0, y = 0}
  if walking_state.walking then
    if walking_state.direction == defines.direction.north then
      offset.x = -0.05
    elseif walking_state.direction == defines.direction.west then
      offset.x = -0.1
    elseif walking_state.direction == defines.direction.south or walking_state.direction == defines.direction.southeast or walking_state.direction == defines.direction.southwest then
      offset.y = 0.05
    end
  else
    if walking_state.direction == defines.direction.east or walking_state.direction == defines.direction.northeast then
      offset.x = -0.15
    elseif walking_state.direction == defines.direction.west or walking_state.direction == defines.direction.northwest then
      offset.x = 0.15
    elseif walking_state.direction == defines.direction.south then
      offset.y = -0.15
    end
  end
  return {x = offset.x, y = offset.y-0.7}
end

-- 2.x: rendering functions return LuaRenderObject instead of numeric ids.
-- Ids stored by 1.1 saves are converted on the fly.
local function get_object(object)
  if type(object) == "number" then
    return rendering.get_object_by_id(object)
  end
  return object
end

local function set_target(object, entity, offset)
  object = get_object(object)
  if object and object.valid then
    object.target = { entity = entity, offset = offset }
  end
end

local function destroy(object)
  object = get_object(object)
  if object and object.valid then
    object.destroy()
  end
end

local function on_tick()
  for _, player in pairs(game.players) do
    -- 2.x: player.position/surface follow remote view, so use the character
    local character = player.character
    local tile = character and character.surface.get_tile(character.position.x, character.position.y)
    if character and (not tile or not tile.valid) then goto continue end
    local tile_name = tile and tile.name
    if (tile_name == "water" or tile_name == "deepwater")
      and player.character and not player.vehicle
      and (not (remote.interfaces["jetpack"] and remote.interfaces["jetpack"].is_jetpacking) or not remote.call("jetpack", "is_jetpacking", {character=player.character}))
      then
      local offset = get_offset(player.walking_state)
      if not storage.liferings[player.index] and player.character then
        storage.liferings[player.index] = {
          front = rendering.draw_sprite{
            sprite = "ff-life-ring-front",
            target = {entity = player.character, offset = offset},
            surface = player.character.surface,
            x_scale = scale,
            y_scale = scale+0.1,
            render_layer = "higher-object-under",
          },
          back = rendering.draw_sprite{
            sprite = "ff-life-ring-back",
            target = {entity = player.character, offset = offset},
            surface = player.character.surface,
            x_scale = scale,
            y_scale = scale+0.1,
            render_layer = "lower-object-above-shadow",
          },
          shadow = rendering.draw_sprite{
            sprite = "ff-life-ring-front-shadow",
            target = {entity = player.character, offset = add_offset(offset, shadow_offset)},
            surface = player.character.surface,
            x_scale = scale*1.25,
            y_scale = scale+0.1,
            render_layer = "lower-object",
          },
          legs = rendering.draw_sprite{
            sprite = "ff-water-legs",  -- Partially covers up legs
            target = {entity = player.character, offset = add_offset(offset, legs_offset)},
            surface = player.character.surface,
            x_scale = 0.6,
            y_scale = 0.4,
            render_layer = "object",
          },

        }
      else
        local rings = storage.liferings[player.index]
        set_target(rings.front, player.character, offset)
        set_target(rings.back, player.character, offset)
        set_target(rings.shadow, player.character, add_offset(offset, shadow_offset))
        set_target(rings.legs, player.character, add_offset(offset, legs_offset))
      end
      for _, splash_position in pairs(splash_positions) do
        character.surface.create_entity{
          name = "ff-life-ring-splash",
          position = add_offset(add_offset(character.position, splash_position), offset),
        }
      end
    else
      if storage.liferings[player.index] then
        local rings = storage.liferings[player.index]
        destroy(rings.front)
        destroy(rings.back)
        destroy(rings.shadow)
        destroy(rings.legs)
        storage.liferings[player.index] = nil
      end
    end
    ::continue::
  end
end


---@type ScriptLib
local LifeRing = {}

LifeRing.events = {
  [defines.events.on_tick] = on_tick
}

LifeRing.on_init = function ()
  storage.liferings = {}
end

LifeRing.on_configuration_changed = function(changed_data)
  storage.liferings = storage.liferings or {}
end

return LifeRing

