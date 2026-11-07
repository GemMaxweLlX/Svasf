-- Small helpers for building Factorio 2.x noise expression strings.
-- In 1.1 noise expressions were Lua trees built with `require "noise"`; since 2.0 they are plain strings
-- compiled by the engine, so everything here just concatenates text.

local N = {}

--- Formats a Lua number as a noise literal.
---@param v number|string
---@return string
function N.num(v)
  if type(v) == "string" then return v end
  if v ~= v then error("NaN passed to noise expression builder") end
  if v == math.huge then return "inf" end
  if v == -math.huge then return "-inf" end
  if v == math.floor(v) and math.abs(v) < 1e15 then
    return string.format("%d", v)
  end
  return string.format("%.17g", v)
end

--- Wraps an expression in parentheses.
function N.p(expr)
  return "(" .. N.num(expr) .. ")"
end

--- Builds a call with named arguments: `name{a = 1, b = 2}`. Keys are sorted so output is deterministic.
---@param name string
---@param args table<string, number|string>
function N.call(name, args)
  local keys = {}
  for k in pairs(args) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = k .. " = " .. N.num(args[k])
  end
  return name .. "{" .. table.concat(parts, ", ") .. "}"
end

--- Builds a call with positional arguments: `name(a, b, c)`.
function N.fn(name, ...)
  local parts = {}
  for i, v in ipairs({...}) do parts[i] = N.num(v) end
  return name .. "(" .. table.concat(parts, ", ") .. ")"
end

function N.min(a, b) return N.fn("min", a, b) end
function N.max(a, b) return N.fn("max", a, b) end
function N.clamp(v, lo, hi) return N.fn("clamp", v, lo, hi) end

--- `if(cond, a, b)`
function N.if_else(cond, a, b) return N.fn("if", cond, a, b) end

--- Equivalent of 1.1 `noise.if_else_chain(c1, v1, c2, v2, ..., else)`.
function N.if_else_chain(...)
  local args = {...}
  local n = #args
  local result = N.num(args[n])
  for i = n - 2, 1, -2 do
    result = N.if_else(args[i], args[i + 1], result)
  end
  return result
end

--- Reference to a variable whose name is not a plain identifier, e.g. `var('control:iron-ore:size')`.
function N.var(name)
  if name:match("^[%a_][%w_]*$") then return name end
  return "var('" .. name .. "')"
end

--- Autoplace control multipliers (1.1: `control-setting:<name>:<setting>:multiplier`).
function N.control(control_name, setting)
  return N.var("control:" .. control_name .. ":" .. setting)
end

--- Uniform-ish random value in [0, amplitude], equivalent of 1.1 `noise.random(amplitude)`.
function N.random(amplitude, seed)
  return N.call("random_penalty", {
    x = "x",
    y = "y",
    seed = seed or 1,
    source = amplitude,
    amplitude = amplitude,
  })
end

--- Equivalent of 1.1 `noise.random_between(lower, upper)`.
function N.random_between(lower, upper, seed)
  return N.p(N.num(lower) .. " + " .. N.random(N.num(upper) .. " - " .. N.num(lower), seed))
end

--- Converts a prototype name to something usable as a noise identifier.
function N.ident(name)
  return (name:gsub("[^%w_]", "_"))
end

return N
