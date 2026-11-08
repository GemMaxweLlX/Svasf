local presets = require "presets"

---@return table<string, function>
local function remote_interface_fragment()
  if not script.active_mods["Milestones"] then return {} end

  return {
    milestones_presets = function()
      return presets
    end,
    -- Space Age (extended mode): milestones for the new mechanics, added after the detected preset
    milestones_preset_addons = function()
      if not script.active_mods["space-age"] or settings.startup["ff-classic-mode"].value then return {} end
      return {
        ["Freight Forwarding: Space Age"] = {
          required_mods = {"FreightForwarding", "space-age"},
          milestones = {
            {type = "group", name = "Freight"},
            {type = "item", name = "ff-light-rocket-silo", quantity = 1},
            {type = "item", name = "ff-reefer-container", quantity = 1},
            {type = "item", name = "ff-light-container", quantity = 1},
            {type = "item", name = "ff-cryo-container", quantity = 1},
            {type = "item", name = "ff-dredging-platform-mk3", quantity = 1},
            {type = "item", name = "ff-icebreaker", quantity = 1},
            {type = "item", name = "ff-freight-science-pack", quantity = 1},
            {type = "item", name = "ff-freight-consignment", quantity = 1},
            {type = "technology", name = "ff-interstellar-freight-contract", quantity = 1},
          },
        },
      }
    end
  }
end

return
{
  remote_interface_fragment = remote_interface_fragment,
}
