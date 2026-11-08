-- Krastorio 2 (2.1) and Krastorio 2 Spaced Out
if mods["Krastorio2"] then
  data:extend{
    {
      type = "bool-setting",
      name = "ff-k2-no-lead-ammo",
      order = "c",
      setting_type = "startup",
      default_value = true
    },
  }
end
