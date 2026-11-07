-- Evaluates FF's elevation expression on a grid and writes a PPM preview.
-- basis_noise is approximated with seeded 2D Perlin noise (not Factorio's exact noise).
local N = require("noise")
local dump = dofile(arg[1])
local out_path = arg[2] or "preview.ppm"
local half = tonumber(arg[3] or 4096)
local step = tonumber(arg[4] or 32)
local seed = tonumber(arg[5] or 12345)

local named = {}
for _, e in pairs(dump) do
  if e.kind == "noise-expression" or e.kind == "noise-function" then
    local locals = {}
    for k, v in pairs(e.locals) do locals[k] = N.parse(v) end
    named[e.name] = {ast = N.parse(e.expression), locals = locals, params = e.params}
  end
end

-- Perlin
local bxor, band = bit32.bxor, bit32.band
local function ihash(ix, iy, s0, s1)
  local h = bit32.band(ix * 374761393 + iy * 668265263 + s0 * 2246822519 + s1 * 3266489917, 0xFFFFFFFF)
  h = bit32.band(bxor(h, bit32.rshift(h, 13)) * 1274126177, 0xFFFFFFFF)
  h = bxor(h, bit32.rshift(h, 16))
  return h
end
local function grad(ix, iy, s0, s1, dx, dy)
  local a = (ihash(ix, iy, s0, s1) % 1024) / 1024 * 2 * math.pi
  return math.cos(a) * dx + math.sin(a) * dy
end
local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
local function perlin(x, y, s0, s1)
  local x0, y0 = math.floor(x), math.floor(y)
  local fx, fy = x - x0, y - y0
  local u, v = fade(fx), fade(fy)
  local n00 = grad(x0, y0, s0, s1, fx, fy)
  local n10 = grad(x0 + 1, y0, s0, s1, fx - 1, fy)
  local n01 = grad(x0, y0 + 1, s0, s1, fx, fy - 1)
  local n11 = grad(x0 + 1, y0 + 1, s0, s1, fx - 1, fy - 1)
  local nx0 = n00 + (n10 - n00) * u
  local nx1 = n01 + (n11 - n01) * u
  return (nx0 + (nx1 - nx0) * v) * 1.4  -- ~[-1, 1]
end

local env
local eval
local function call_named(f, n, scope)
  local a = {}
  for k, e in pairs(n.named) do a[k] = (k ~= "points") and eval(e, scope) or nil end
  if f == "basis_noise" then
    return perlin(a.x * a.input_scale, a.y * a.input_scale, math.floor(a.seed0) % 100000, math.floor(a.seed1)) * a.output_scale
  elseif f == "quick_multioctave_noise" then
    local sum, is, os = 0, a.input_scale, a.output_scale
    for o = 1, a.octaves do
      sum = sum + perlin(a.x * is, a.y * is, math.floor(a.seed0) % 100000, math.floor(a.seed1) + o * 7) * os
      is = is * a.octave_input_scale_multiplier
      os = os * a.octave_output_scale_multiplier
    end
    return sum
  elseif f == "distance_from_nearest_point" then
    local dx, dy = a.x - env.lake[1], a.y - env.lake[2]
    return math.min(math.sqrt(dx * dx + dy * dy), a.maximum_distance)
  elseif f == "random_penalty" then
    return a.source - (ihash(math.floor(a.x), math.floor(a.y), 1, math.floor(a.seed)) % 1000) / 1000 * a.amplitude
  end
  error("eval: unsupported " .. f)
end

function eval(n, scope)
  local k = n.k
  if k == "num" then return n.v
  elseif k == "var" then
    local v = scope.vals[n.v]
    if v ~= nil then return v end
    local lc = scope.locals[n.v]
    if lc then v = eval(lc, scope); scope.vals[n.v] = v; return v end
    v = env.vals[n.v]
    if v ~= nil then return v end
    local ne = named[n.v]
    if ne then
      local s = {vals = {}, locals = ne.locals}
      v = eval(ne.ast, s); env.vals[n.v] = v; return v
    end
    if n.v == "inf" then return math.huge end
    error("eval: unknown var " .. n.v)
  elseif k == "neg" then return -eval(n.a, scope)
  elseif k == "bin" then
    local a, b = eval(n.a, scope), eval(n.b, scope)
    local op = n.op
    if op == "+" then return a + b elseif op == "-" then return a - b elseif op == "*" then return a * b
    elseif op == "/" then return a / b elseif op == "^" then return a ^ b elseif op == "%" then return a % b
    elseif op == "<" then return a < b and 1 or 0 elseif op == ">" then return a > b and 1 or 0
    elseif op == "<=" then return a <= b and 1 or 0 elseif op == ">=" then return a >= b and 1 or 0 end
  elseif k == "call" then
    local f = n.f
    if f == "var" then
      local name = n.args[1].v
      if name:match("^control:") then return 1 end
      return eval({k = "var", v = name}, scope)
    end
    local a = {}
    for i, e in ipairs(n.args) do a[i] = eval(e, scope) end
    if f == "clamp" then return math.max(a[2], math.min(a[3], a[1]))
    elseif f == "min" then return math.min(a[1], a[2]) elseif f == "max" then return math.max(a[1], a[2])
    elseif f == "if" then return a[1] ~= 0 and a[2] or a[3]
    elseif f == "log2" then return math.log(a[1]) / math.log(2)
    elseif f == "abs" then return math.abs(a[1]) end
    local fn = named[f]
    if fn then
      local s = {vals = {}, locals = fn.locals}
      for i, p in ipairs(fn.params) do s.vals[p] = a[i] end
      return eval(fn.ast, s)
    end
    error("eval: unknown function " .. f)
  elseif k == "ncall" then return call_named(n.f, n, scope)
  end
end

local function at(x, y, name)
  env = {vals = {x = x, y = y, distance = math.sqrt(x * x + y * y), map_seed = seed}, lake = {40, -120}}
  local elevation = eval({k = "var", v = "x-continents"}, {vals = {}, locals = {}})
  env.vals.elevation = elevation
  return env
end

local size = math.floor(2 * half / step)
local f = assert(io.open(out_path, "wb"))
f:write(("P6\n%d %d\n255\n"):format(size, size))
local stats = {land = 0, shallow = 0, water = 0, deep = 0, silo = 0, lava_zone = 0, seamount_zone = 0}
local tile_fn = named["ff_water_autoplace"]
for j = 0, size - 1 do
  local row = {}
  for i = 0, size - 1 do
    local x, y = -half + i * step, -half + j * step
    local e = at(x, y)
    local elev = e.vals.elevation
    local spread = eval({k = "var", v = "ff_resource_spread"}, {vals = {}, locals = {}})
    local function wa(maxe, infl) return infl * math.min(maxe - elev, 1) end
    local best, kind = 1, "land"   -- land tiles ~ probability 1
    for _, t in pairs{{"shallow", 0, 25}, {"water", -2.5, 100}, {"deep", -8, 200}} do
      local p = wa(t[2], t[3]); if p > best then best, kind = p, t[1] end
    end
    stats[kind] = stats[kind] + 1
    local r, g, b
    if kind == "deep" then r, g, b = 20, 40, 90
    elseif kind == "water" then r, g, b = 40, 80, 150
    elseif kind == "shallow" then r, g, b = 90, 140, 170
    else
      local h = math.min(1, elev / 40)
      r, g, b = math.floor(70 + 90 * h), math.floor(110 + 60 * h), math.floor(50 + 40 * h)
    end
    local d = e.vals.distance
    if elev > 8 and d > 4000 and spread < 0.6 then stats.silo = stats.silo + 1; r, g, b = 230, 230, 230 end
    if kind ~= "deep" and kind ~= "water" and kind ~= "shallow" and math.abs(spread - 0.9) < 0.05 and d > 3000 then
      stats.lava_zone = stats.lava_zone + 1; r, g, b = 230, 90, 20 end
    if elev < -20 then stats.seamount_zone = stats.seamount_zone + 1 end
    if math.abs(x) < step and math.abs(y) < step then r, g, b = 255, 0, 0 end
    row[#row + 1] = string.char(r, g, b)
  end
  f:write(table.concat(row))
end
f:close()
local total = size * size
for k, v in pairs(stats) do print(("%-14s %6.2f%%"):format(k, 100 * v / total)) end
-- Radius of the starting island along +x
for r = 0, half, 16 do
  local e = at(r, 0)
  if e.vals.elevation < 0 then print("starting island edge (+x axis) ~", r) break end
end
