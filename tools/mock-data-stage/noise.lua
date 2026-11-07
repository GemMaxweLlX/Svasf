-- Parser + evaluator for Factorio 2.x noise expression strings (subset used by FF).
local M = {}

local function tokenize(s)
  local toks, i = {}, 1
  while i <= #s do
    local c = s:sub(i, i)
    if c:match("%s") then i = i + 1
    elseif s:sub(i):match("^%d") or (c == "." and s:sub(i+1,i+1):match("%d")) then
      local num = s:match("^%d*%.?%d*[eE][%+%-]?%d+", i) or s:match("^%d*%.?%d*", i)
      toks[#toks+1] = {t="num", v=tonumber(num)}; i = i + #num
    elseif c:match("[%a_]") then
      local id = s:match("^[%a_][%w_]*", i); toks[#toks+1] = {t="id", v=id}; i = i + #id
    elseif c == "'" or c == '"' then
      local j = s:find(c, i+1, true); assert(j, "unterminated string")
      toks[#toks+1] = {t="str", v=s:sub(i+1, j-1)}; i = j + 1
    else
      local two = s:sub(i, i+1)
      if two == "<=" or two == ">=" or two == "==" or two == "~=" or two == "!=" then
        toks[#toks+1] = {t="op", v=two}; i = i + 2
      elseif ("+-*/^%<>(){},="):find(c, 1, true) then
        toks[#toks+1] = {t="op", v=c}; i = i + 1
      else error("bad char '" .. c .. "' in: " .. s) end
    end
  end
  toks[#toks+1] = {t="eof"}
  return toks
end

local prec = { ["<"]=1, ["<="]=1, [">"]=1, [">="]=1, ["=="]=1, ["!="]=1, ["~="]=1, ["+"]=2, ["-"]=2, ["*"]=3, ["/"]=3, ["%"]=3, ["^"]=5 }

function M.parse(s)
  local toks, pos = tokenize(s), 1
  local function peek() return toks[pos] end
  local function nxt() pos = pos + 1; return toks[pos-1] end
  local function expect(v) local t = nxt(); if t.v ~= v then error("expected '" .. v .. "' got '" .. tostring(t.v) .. "' in: " .. s) end end
  local expr
  local function primary()
    local t = nxt()
    if t.t == "num" then return {k="num", v=t.v} end
    if t.t == "str" then return {k="str", v=t.v} end
    if t.v == "(" then local e = expr(0); expect(")"); return e end
    if t.v == "-" then return {k="neg", a=expr(4)} end
    if t.t == "id" then
      local p = peek()
      if p.v == "(" then
        nxt(); local args = {}
        if peek().v ~= ")" then
          repeat args[#args+1] = expr(0) until not (peek().v == "," and nxt())
        end
        expect(")")
        return {k="call", f=t.v, args=args}
      elseif p.v == "{" then
        nxt(); local named = {}
        if peek().v ~= "}" then
          repeat
            local key = nxt(); assert(key.t == "id", "named arg expected in " .. s)
            expect("="); named[key.v] = expr(0)
          until not (peek().v == "," and nxt())
        end
        expect("}")
        return {k="ncall", f=t.v, named=named}
      end
      return {k="var", v=t.v}
    end
    error("unexpected token " .. tostring(t.v) .. " in: " .. s)
  end
  function expr(minp)
    local lhs = primary()
    while true do
      local t = peek()
      local p = t.t == "op" and prec[t.v]
      if not p or p < minp then break end
      nxt()
      local rhs = expr(t.v == "^" and p or p + 1)
      lhs = {k="bin", op=t.v, a=lhs, b=rhs}
    end
    return lhs
  end
  local e = expr(0)
  if peek().t ~= "eof" then error("trailing tokens in: " .. s) end
  return e
end

M.named_signatures = {
  basis_noise = {x=1,y=1,seed0=1,seed1=1,input_scale=1,output_scale=1},
  quick_multioctave_noise = {x=1,y=1,seed0=1,seed1=1,input_scale=1,output_scale=1,octaves=1,octave_output_scale_multiplier=1,octave_input_scale_multiplier=1},
  spot_noise = {x=1,y=1,seed0=1,seed1=1,region_size=1,candidate_spot_count=1,suggested_minimum_candidate_point_spacing=1,skip_span=1,skip_offset=1,density_expression=1,spot_quantity_expression=1,hard_region_target_quantity=1,spot_radius_expression=1,spot_favorability_expression=1,basement_value=1,maximum_spot_basement_radius=1},
  random_penalty = {x=1,y=1,seed=1,source=1,amplitude=1},
  distance_from_nearest_point = {x=1,y=1,points=1,maximum_distance=1},
}
M.positional = { clamp=3, min=2, max=2, ["if"]=3, log2=1, var=1, abs=1 }
M.builtin_vars = { x=1, y=1, distance=1, map_seed=1, elevation=1, starting_lake_positions=1, starting_area_radius=1, pi=1, inf=1 }

-- Static check: returns list of problems
function M.check(ast, scope, problems, where)
  local function walk(n)
    if n.k == "var" then
      if not scope.vars[n.v] then problems[#problems+1] = where .. ": unknown variable " .. n.v end
    elseif n.k == "bin" then walk(n.a); walk(n.b)
    elseif n.k == "neg" then walk(n.a)
    elseif n.k == "call" then
      if n.f == "var" then
        local name = n.args[1] and n.args[1].v
        if not (name and (name:match("^control:[%w%-_]+:[%a]+$") or scope.vars[name])) then problems[#problems+1] = where .. ": bad var() " .. tostring(name) end
      elseif M.positional[n.f] then
        if #n.args ~= M.positional[n.f] then problems[#problems+1] = where .. ": " .. n.f .. " expects " .. M.positional[n.f] .. " args, got " .. #n.args end
        for _, a in pairs(n.args) do walk(a) end
      elseif scope.funcs[n.f] then
        if #n.args ~= #scope.funcs[n.f] then problems[#problems+1] = where .. ": " .. n.f .. " arity" end
        for _, a in pairs(n.args) do walk(a) end
      else problems[#problems+1] = where .. ": unknown function " .. n.f end
    elseif n.k == "ncall" then
      local sig = M.named_signatures[n.f]
      if not sig then problems[#problems+1] = where .. ": unknown named function " .. n.f
      else for k, a in pairs(n.named) do
        if not sig[k] then problems[#problems+1] = where .. ": " .. n.f .. " unknown arg " .. k end
        walk(a)
      end end
    end
  end
  walk(ast)
end

return M
