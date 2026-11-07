local N = require("noise")
local dump = dofile(arg[1])
local vars, funcs = {}, {}
for k in pairs(N.builtin_vars) do vars[k] = true end
for _, e in pairs(dump) do
  if e.kind == "noise-expression" then vars[e.name] = true end
  if e.kind == "noise-function" then funcs[e.name] = e.params end
end
local problems, count = {}, 0
for _, e in pairs(dump) do
  local scope = {vars = setmetatable({}, {__index = vars}), funcs = funcs}
  for _, p in pairs(e.params) do scope.vars[p] = true end
  for k in pairs(e.locals) do scope.vars[k] = true end
  local items = {{"expression", e.expression}}
  for k, v in pairs(e.locals) do items[#items+1] = {"local " .. k, v} end
  for _, it in pairs(items) do
    count = count + 1
    local ok, ast = pcall(N.parse, it[2])
    if not ok then problems[#problems+1] = e.kind .. " " .. e.name .. " " .. it[1] .. ": PARSE " .. ast
    else N.check(ast, scope, problems, e.kind .. " " .. e.name .. " " .. it[1]) end
  end
end
for _, p in pairs(problems) do print(p) end
print(("checked %d expressions, %d problems"):format(count, #problems))
