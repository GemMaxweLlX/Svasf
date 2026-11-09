-- Tips & tricks for the extended mode features (with or without Space Age). Runs at the end of data-updates.

if settings.startup["ff-classic-mode"].value then return end

local function exists(name)
  for _, type in pairs{"item", "item-with-entity-data", "tool"} do
    if data.raw[type] and data.raw[type][name] then return true end
  end
  return false
end

-- name, tag, required item (tip skipped without it)
local TIPS = {
  {"ff-ext-cargo-sensor", "[item=ff-cargo-sensor]", "ff-cargo-sensor"},
  {"ff-ext-routes-panel", "[item=locomotive]", nil},
  {"ff-ext-tank-containers", "[item=ff-tank-container]", "ff-tank-container"},
  {"ff-ext-subsea-pipeline", "[item=ff-pipeline-landing]", "ff-pipeline-landing"},
  {"ff-ext-subsea-cable", "[item=ff-cable-landing]", "ff-cable-landing"},
  {"ff-ext-sea-power", "[item=ff-port-crane]", "ff-port-crane"},
  {"ff-ext-insurance", "[item=ff-insurance-office]", "ff-insurance-office"},
  {"ff-ext-exchange", "[item=ff-caravan-exchange]", "ff-caravan-exchange"},
  {"ff-ext-great-caravan", "[item=ff-freight-consignment]", "ff-freight-consignment"},
}

local tips = {}
for i, tip in pairs(TIPS) do
  if not tip[3] or exists(tip[3]) then
    tips[#tips + 1] = {
      type = "tips-and-tricks-item",
      name = tip[1],
      tag = tip[2],
      category = "freight-forwarding",
      indent = 1,
      order = "t-" .. string.format("%02d", i),
      starting_status = "unlocked",
    }
  end
end
data:extend(tips)
