-- Freight Forwarding self-test. Enable only on a throwaway map: it rewrites the area around spawn.
-- Every check writes "FFSELFTEST PASS <name>" or "FFSELFTEST FAIL <name> <details>" to the log; at the end a summary.

local results = {pass = 0, fail = 0}
local function report(ok, name, details)
  if ok then results.pass = results.pass + 1 else results.fail = results.fail + 1 end
  log("FFSELFTEST " .. (ok and "PASS " or "FAIL ") .. name .. (details and (" " .. tostring(details)) or ""))
end
local function fl(e) return e and e.valid and e.get_fluid_contents() or {} end
local function total(t) local n = 0 for _, v in pairs(t) do n = n + v end return n end

local function clear(s, area, water_x)
  local tiles = {}
  for x = area[1][1], area[2][1] do for y = area[1][2], area[2][2] do
    local water = water_x and x > water_x[1] and x < water_x[2]
    tiles[#tiles + 1] = {name = water and "deepwater" or "grass-1", position = {x, y}}
  end end
  s.set_tiles(tiles)
  for _, e in pairs(s.find_entities_filtered{area = area}) do if e.type ~= "character" then e.destroy() end end
end

local function setup()
  local s = game.surfaces.nauvis
  local force = game.forces.player
  -- 1. Tank containers (extended mode only)
  if prototypes.item["ff-tank-container"] then
    force.technologies["ff-tank-containers"].researched = true
    clear(s, {{-30, 40}, {-10, 60}})
    s.create_entity{name = "electric-energy-interface", position = {-20, 55}, force = force}
    s.create_entity{name = "substation", position = {-20, 50}, force = force}
    local load = s.create_entity{name = "chemical-plant", position = {-23.5, 47.5}, force = force}
    load.set_recipe("ff-tank-load-petroleum-gas")
    load.insert{name = "ff-tank-container", count = 1}
    load.insert_fluid{name = "petroleum-gas", amount = 2000}
    local unload = s.create_entity{name = "chemical-plant", position = {-16.5, 47.5}, force = force}
    unload.set_recipe("ff-tank-unload-petroleum-gas")
    unload.insert{name = "ff-tank-petroleum-gas", count = 1}
    storage.tank_load, storage.tank_unload = load, unload
  else
    log("FFSELFTEST SKIP tank containers (classic mode or no Intermodal Containers)")
  end
  -- 2. Subsea pipeline: pipe and duct landings across 50 tiles of water
  if prototypes.entity["ff-pipeline-landing"] then
    clear(s, {{-10, -30}, {80, -5}}, {4, 56})
    local a = s.create_entity{name = "ff-pipeline-landing", position = {0.5, -20.5}, direction = defines.direction.west, force = force}
    local b = s.create_entity{name = "ff-pipeline-landing", position = {60.5, -20.5}, direction = defines.direction.east, force = force}
    report(remote.call("ff-subsea-pipeline", "partner", a) == b, "pipeline: landing finds the one opposite")
    report(remote.call("ff-subsea-pipeline", "lay", a) == 60, "pipeline: 60 segments for 60 tiles")
    storage.pipe = {a = {0.5, -20.5}, b = {60.5, -20.5}}
    if prototypes.entity["ff-duct-landing"] then
      local da = s.create_entity{name = "ff-duct-landing", position = {0, -10}, direction = defines.direction.west, force = force}
      s.create_entity{name = "ff-duct-landing", position = {60, -10}, direction = defines.direction.east, force = force}
      report(remote.call("ff-subsea-pipeline", "lay", da) == 240, "pipeline: duct landing needs 4 segments per tile")
      storage.duct = {a = {0, -10}, b = {60, -10}}
    else
      report(false, "pipeline: duct landing exists (Fluid Must Flow)")
    end
  end
  -- 3. Cargo insurance
  if prototypes.entity["ff-insurance-office"] then
    clear(s, {{20, 20}, {50, 50}})
    local office = s.create_entity{name = "ff-insurance-office", position = {40.5, 40.5}, force = force}
    for y = 24, 44, 2 do s.create_entity{name = "straight-rail", position = {25, y}, force = force} end
    local wagon = s.create_entity{name = "cargo-wagon", position = {25, 34}, force = force}
    if wagon then
      wagon.insert{name = "iron-plate", count = 100}
      wagon.die()
      local got = office.get_inventory(defines.inventory.chest).get_item_count("iron-plate")
      local rate = settings.global["ff-insurance-payout"].value
      report(got == math.floor(100 * rate / 100), "insurance: destroyed wagon pays out " .. rate .. "%", "got " .. got)
    else
      report(false, "insurance: could not build a cargo wagon")
    end
  end
  -- 4. Archipelago map preset and noise expression
  report(prototypes.named_noise_expression["ff-archipelago"] ~= nil, "archipelago: noise expression exists")
  report(prototypes.named_noise_expression["x-continents"] ~= nil, "islands: x-continents exists")
end

local function check()
  local s = game.surfaces.nauvis
  local function at(p) return s.find_entities_filtered{position = p, radius = 0.6, type = "pipe-to-ground"}[1] end
  if storage.pipe then
    local a, b = at(storage.pipe.a), at(storage.pipe.b)
    report(a and a.name == "ff-pipeline-landing-laid" and b and b.name == "ff-pipeline-landing-laid", "pipeline: landings swapped to laid")
    if a then a.insert_fluid{name = "water", amount = 100} end
  end
  if storage.duct then
    local a, b = at(storage.duct.a), at(storage.duct.b)
    report(a and a.name == "ff-duct-landing-laid" and b and b.name == "ff-duct-landing-laid", "pipeline: duct landings swapped to laid")
  end
  if storage.tank_load then
    local out = storage.tank_load.get_output_inventory()
    report(out.get_item_count("ff-tank-petroleum-gas") == 1, "tank containers: chemical plant fills a tank")
    report(total(fl(storage.tank_unload)) >= 2000 or storage.tank_unload.get_output_inventory().get_item_count("ff-tank-container") >= 1,
           "tank containers: chemical plant empties a tank", serpent.line(fl(storage.tank_unload)))
  end
end

local function check_flow()
  local s = game.surfaces.nauvis
  if storage.pipe then
    local b = s.find_entities_filtered{position = storage.pipe.b, radius = 0.6, type = "pipe-to-ground"}[1]
    report(b and total(fl(b)) > 0, "pipeline: water reaches the far landing", b and serpent.line(fl(b)))
    local a = s.find_entities_filtered{position = storage.pipe.a, radius = 0.6, type = "pipe-to-ground"}[1]
    if a then a.die() end
  end
end

local function check_broken()
  local s = game.surfaces.nauvis
  if storage.pipe then
    local b = s.find_entities_filtered{position = storage.pipe.b, radius = 0.6, type = "pipe-to-ground"}[1]
    report(b and b.name == "ff-pipeline-landing", "pipeline: removing one landing breaks the pipeline")
  end
  log(string.format("FFSELFTEST SUMMARY %d passed, %d failed", results.pass, results.fail))
end

script.on_init(function() storage.start = game.tick end)
script.on_nth_tick(60, function(e)
  local t = e.tick - (storage.start or 0)
  if t == 60 then setup()
  elseif t == 2100 then check()
  elseif t == 2400 then check_flow()
  elseif t == 2700 then check_broken() end
end)
