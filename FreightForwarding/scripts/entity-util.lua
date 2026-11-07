-- Small wrappers around LuaEntity API that changed between Factorio 1.1 and 2.x.
local EntityUtil = {}

--- 1.1 `entity.active = x`; 2.x uses `entity.disabled_by_script = not x`.
---@param entity LuaEntity
---@param active boolean
function EntityUtil.set_active(entity, active)
  local ok = pcall(function() entity.disabled_by_script = not active end)
  if not ok then
    entity.active = active
  end
end

--- Clears the backer name if the entity type supports one.
---@param entity LuaEntity
function EntityUtil.clear_backer_name(entity)
  pcall(function() entity.backer_name = "" end)
end

return EntityUtil
