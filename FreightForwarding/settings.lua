data:extend{
  {
    type = "bool-setting",
    name = "ff-disable-default-sims",
    order = "a",
    setting_type = "startup",
    default_value = true
  },
  {
    type = "bool-setting",
    name = "ff-revert-locomotive-fuel-category",
    setting_type = "startup",
    default_value = false,
    order = "b",
  },
  {
    -- Classic mode: Freight Forwarding exactly as in 1.x on Nauvis, even with Space Age; other planets untouched
    type = "bool-setting",
    name = "ff-classic-mode",
    setting_type = "startup",
    default_value = false,
    order = "a-b",
  },
  -- Interstellar freight contracts (Space Age), in minutes
  {type = "int-setting", name = "ff-contract-offer-lifetime", setting_type = "runtime-global", default_value = 30, minimum_value = 1, maximum_value = 1440, order = "f-a"},
  {type = "int-setting", name = "ff-contract-refresh", setting_type = "runtime-global", default_value = 45, minimum_value = 1, maximum_value = 1440, order = "f-b"},
  {type = "int-setting", name = "ff-contract-deadline", setting_type = "runtime-global", default_value = 180, minimum_value = 5, maximum_value = 10000, order = "f-c"},
  {type = "int-setting", name = "ff-contract-penalty", setting_type = "runtime-global", default_value = 5, minimum_value = 0, maximum_value = 100, order = "f-d"},
  {
    type = "bool-setting",
    name = "ff-map-tags",
    setting_type = "runtime-global",
    default_value = true,
    order = "d",
  },
  {
    -- 2.x: also apply the FF island terrain to Nauvis' defaults, not only to the "Freight Forwarding" preset
    type = "bool-setting",
    name = "ff-island-terrain-by-default",
    setting_type = "startup",
    default_value = true,
    order = "c",
  },
  -- Space Age balance (not used in classic mode)
  {
    type = "int-setting",
    name = "ff-light-container-weight",
    setting_type = "startup",
    default_value = 400,
    minimum_value = 100,
    maximum_value = 1000,
    order = "e-a",
  },
  {
    type = "int-setting",
    name = "ff-fluorine-seep-yield",
    setting_type = "startup",
    default_value = 35,
    minimum_value = 5,
    maximum_value = 300,
    order = "e-b",
  },
  {
    type = "int-setting",
    name = "ff-scrap-dredging-amount",
    setting_type = "startup",
    default_value = 100,
    minimum_value = 10,
    maximum_value = 500,
    order = "e-c",
  },
  {
    type = "bool-setting",
    name = "ff-dredger-productivity-modules",
    setting_type = "startup",
    default_value = false,
    order = "e-d",
  },
  {
    type = "double-setting",
    name = "ff-swamp-ship-speed",
    setting_type = "startup",
    default_value = 0.4,
    minimum_value = 0.1,
    maximum_value = 1,
    order = "e-e",
  },
  {
    type = "double-setting",
    name = "ff-heavy-ship-speed",
    setting_type = "startup",
    default_value = 0.7,
    minimum_value = 0.3,
    maximum_value = 1.5,
    order = "e-f",
  },
  {
    type = "double-setting",
    name = "ff-wagon-mk2-capacity",
    setting_type = "startup",
    default_value = 1.5,
    minimum_value = 1,
    maximum_value = 3,
    order = "e-g",
  },
  {
    type = "bool-setting",
    name = "ff-transport-science-planet-techs",
    setting_type = "startup",
    default_value = false,
    order = "e-h",
  },
  {
    type = "int-setting",
    name = "ff-freight-contract-size",
    setting_type = "startup",
    default_value = 100,
    minimum_value = 1,
    maximum_value = 10000,
    order = "e-i",
  },
}

local function force_setting(setting_type, setting_name, value)
  local setting = (data.raw[setting_type .. "-setting"] or {})[setting_name]
  if setting then
    if setting_type == "bool" then
      setting.forced_value = value
    else
      setting.allowed_values = { value }
    end
    setting.default_value = value
    setting.hidden = true
  end
end

-- Intermodal Containers
force_setting("string", "ic-machine-size", "4×4")
force_setting("double", "ic-stack-size-multiplier", 0.5)
force_setting("double", "ic-stacks-per-container", 20)
force_setting("int", "ic-container-stack-size", 1)
force_setting("double", "ic-cargo-wagon-inventory-multiplier", 1)  -- Handled in our own inventory-sizes.lua
force_setting("double", "ic-belts-per-machine", 1)
force_setting("double", "ic-container-loss-chance", 0.01)

-- Force offshore oil, no inland oil
-- (2.1: oil rigs are in cargo-ships-oil-rig; deep_oil / no_oil_on_land / oil_richness no longer exist,
--  inland oil is removed from Nauvis in prototypes/planet-nauvis.lua)
force_setting("bool", "deep_oil", true)
force_setting("bool", "no_oil_on_land", true)
force_setting("bool", "no_shallow_oil", true)
force_setting("bool", "no_oil_for_oil_rig", true)
force_setting("string", "oil_richness", "good")
force_setting("string", "oil_rigs_require_external_power", "disabled")

-- Reduce tanker capacity from 250k to 200k
force_setting("int", "tanker_capacity", 200)
force_setting("double", "fuel_modifier", 2)

-- Increase oil rig storage to match oil tanker's
--force_setting("int", "oil_rig_capacity", 250)

-- Remove military science from spiderling and patrol technologies
force_setting("bool", "sp-remove-military-requirement", true)

-- Ensure missile hovercraft exists
force_setting("bool", "enable-mcraft", true)

-- Lex's Aircraft
-- Hide light gunship settings, ensure all ships support logistics requests
local function hide_setting(setting_type, setting_name)
  local setting = (data.raw[setting_type .. "-setting"] or {})[setting_name]
  if setting then setting.hidden = true end
end
hide_setting("double", "lex-flying-gunship-speed-settings")
hide_setting("int", "lex-gunship-inventory-size-settings")
force_setting("int", "lex-flying-cargo-trash-inventory-size-settings", 20)
force_setting("int", "lex-gunship-trash-inventory-size-settings", 10)
force_setting("int", "lex-flying-heavyship-trash-inventory-size-settings", 10)

-- BZ hide extra options
force_setting("bool", "bzlead-byproduct", true)
--force_setting("string", "bzlead-more-entities", "no")  -- default-enabled by bzvery
force_setting("string", "bzlead-more-ammo", "no")
force_setting("string", "bztitanium-mining-fluid", "lubricant")
force_setting("int", "bztitanium-mining-fluid-amount", 3)

require "__FreightForwarding__.compatibility.beautiful-bridge-railway.settings"
require "__FreightForwarding__.compatibility.krastorio2.settings"
