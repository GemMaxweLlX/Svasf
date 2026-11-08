local function blacklist_entities()
  if not script.active_mods["PickerDollies"] then return end
  if not remote.interfaces["PickerDollies"] then return end
  if not remote.interfaces["PickerDollies"]["add_blacklist_name"] then return end
  -- Blacklist FF entities
  remote.call("PickerDollies", "add_blacklist_name", "ff-lava-pool")
  remote.call("PickerDollies", "add_blacklist_name", "ff-lava-pool-small")
  remote.call("PickerDollies", "add_blacklist_name", "ff-dredger")
  for _, name in pairs{"ff-dredger-mk2", "ff-dredger-mk3"} do
    if prototypes.entity[name] then remote.call("PickerDollies", "add_blacklist_name", name) end
  end
  remote.call("PickerDollies", "add_blacklist_name", "rocket-silo")
  remote.call("PickerDollies", "add_blacklist_name", "oil-rig")
end

return
{
  load = blacklist_entities
}