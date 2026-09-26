-- Offline test runner, lua5.2 (SP-06). usage: lua5.2 tests/offline/run.lua <file.lua> [full test name]
-- Full test name = describe names + " " + it name, joined by single spaces.
-- With a name: runs only that test; exit 1 if it fails OR is not found (typo never passes).
-- Without a name: runs every test in the file (integrator full suite only, SP-02).
package.path = "./?.lua;" .. package.path
local file, want = arg[1], arg[2]
if not file then io.stderr:write("usage: lua5.2 tests/offline/run.lua <file.lua> [full test name]\n"); os.exit(2) end

local tests, stack = {}, {}
function describe(name, fn) stack[#stack + 1] = name; fn(); stack[#stack] = nil end
function it(name, fn)
  local parts = {}
  for i = 1, #stack do parts[i] = stack[i] end
  parts[#parts + 1] = name
  tests[#tests + 1] = { name = table.concat(parts, " "), fn = fn }
end
test = it

-- Assertions: plain functions, message says expected vs found.
local function show(v)
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. show(v[k]) end
  return "{" .. table.concat(out, ",") .. "}"
end
function eq(found, expected, msg)
  if show(found) ~= show(expected) then
    error((msg and msg .. ": " or "") .. "expected " .. show(expected) .. ", found " .. show(found), 2)
  end
end
function ok(cond, msg) if not cond then error(msg or "expected true", 2) end end

dofile(file)

local ran, failed = 0, 0
for _, t in ipairs(tests) do
  if want == nil or t.name == want then
    ran = ran + 1
    local good, err = pcall(t.fn)
    if good then print("PASS " .. t.name) else failed = failed + 1; print("FAIL " .. t.name .. "\n  " .. tostring(err)) end
  end
end
if want and ran == 0 then print("NOT FOUND: " .. want .. " in " .. file); os.exit(1) end
print(("offline %s: %d ran, %d failed"):format(file, ran, failed))
os.exit(failed == 0 and 0 or 1)
