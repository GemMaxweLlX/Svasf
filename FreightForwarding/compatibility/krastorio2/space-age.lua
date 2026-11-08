-- Krastorio 2 Spaced Out + Space Age + FF in extended mode (not classic): a compromise between the two overhauls.
-- Runs at the end of data-final-fixes.
--   * batteries: FF's lithium battery pack (tier 3, Aquilo) is built from K2's lithium-sulfur batteries, whose lithium
--     also comes from Aquilo, so K2's battery is a step of FF's battery ladder instead of a duplicate
--   * matter: no cobalt ingots from matter (cobalt is Vulcanus' part of the interplanetary chain); cobalt -> matter stays
--   * science: transport science is left out of technologies that need K2's late tech cards (see data-final-fixes)
--   * victory: K2's intergalactic transceiver is the goal; fulfilling the first freight contract grants "Alliance with
--     the Long Caravan", which the transceiver needs (scripts/freight-contract.lua)

if not (mods["Krastorio2-spaced-out"] and mods["space-age"]) or settings.startup["ff-classic-mode"].value then return end

local util = require "__FreightForwarding__.prototypes.data-util"

-- Batteries
if data.raw.recipe["ff-lithium-battery-pack"] and data.raw.item["kr-lithium-sulfur-battery"] then
  util.remove_ingredient("ff-lithium-battery-pack", "lithium-plate")
  util.add_ingredient("ff-lithium-battery-pack", "kr-lithium-sulfur-battery", 4)
  if data.raw.technology["kr-lithium-sulfur-battery"] then
    util.add_prerequisite("ff-lithium-battery-pack", "kr-lithium-sulfur-battery")
  end
end

-- Matter
local deconversion = data.raw.recipe["kr-matter-to-ff-cobalt-ingot"]
if deconversion then
  deconversion.hidden = true
  util.remove_recipe_effect("kr-matter-cobalt-processing", "kr-matter-to-ff-cobalt-ingot")
end

-- Victory: the first contract makes the caravan relay the transceiver's signal
local contract = data.raw.technology["ff-interstellar-freight-contract"]
local transceiver = data.raw.technology["kr-intergalactic-transceiver"]
if contract and transceiver then
  local consignment = data.raw.item["ff-freight-consignment"]
  local icons = table.deepcopy(contract.icons or {{icon = contract.icon, icon_size = contract.icon_size or 256}})
  data:extend{{
    type = "technology",
    name = "ff-caravan-alliance",
    localised_name = {"technology-name.ff-caravan-alliance"},
    localised_description = {"technology-description.ff-caravan-alliance"},
    icons = icons,
    prerequisites = {"ff-interstellar-freight-contract"},
    research_trigger = {type = "scripted", trigger_description = {"technology-description.ff-caravan-alliance-trigger"}},
    effects = {},
    order = (contract.order or "") .. "-alliance",
  }}
  util.add_prerequisite("kr-intergalactic-transceiver", "ff-caravan-alliance")
end
