-- Space Age: tips & tricks for Freight Forwarding's Space Age features. Runs in data-updates.

if not mods["space-age"] or settings.startup["ff-classic-mode"].value then return end

local TIPS = {
  {"ff-sa-rocket-tiers", "[item=ff-light-rocket-silo]", "ff-light-rocket-silo"},
  {"ff-sa-planet-chains", "[planet=vulcanus]", nil},
  {"ff-sa-container-tiers", "[item=ff-cryo-container]", "ic-container"},
  {"ff-sa-damaged-containers", "[item=ff-damaged-ic-container]", "ic-container"},
  {"ff-sa-dredgers", "[item=ff-dredging-platform-mk2]", "ff-dredging-platform"},
  {"ff-sa-bridges", "[entity=rail-support]", "rail-support"},
  {"ff-sa-lava-barges", "[item=ff-lava-barge]", "ff-lava-barge"},
  {"ff-sa-swamp-barges", "[item=ff-swamp-barge]", "ff-swamp-barge"},
  {"ff-sa-icebreaker", "[item=ff-icebreaker]", "ff-icebreaker"},
  {"ff-sa-fluorine-seeps", "[entity=ff-fluorine-seep]", nil},
  {"ff-sa-spoilage-sensor", "[item=ff-spoilage-sensor]", "ff-spoilage-sensor"},
  {"ff-sa-hot-titansteel", "[item=ff-hot-titansteel-plate]", "ff-hot-titansteel-plate"},
  {"ff-sa-freight-contract", "[item=ff-freight-consignment]", "ff-freight-consignment"},
}

local tips = {}
for i, tip in pairs(TIPS) do
  local required = tip[3]
  if not required or data.raw.item[required] or data.raw["item-with-entity-data"][required]
      or data.raw["rail-support"] and data.raw["rail-support"][required] then
    tips[#tips + 1] = {
      type = "tips-and-tricks-item",
      name = tip[1],
      tag = tip[2],
      category = "freight-forwarding",
      indent = 1,
      order = "s-" .. string.format("%02d", i),
      starting_status = "unlocked",
    }
  end
end
data:extend(tips)
