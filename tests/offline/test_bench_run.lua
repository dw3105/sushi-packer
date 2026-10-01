local function read(path)
  local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s
end
local function sh(cmd)
  local f = assert(io.popen(cmd .. ' 2>&1; echo "EXIT=$?"', "r"))
  local out = f:read("*a"); f:close()
  local code = tonumber(out:match("EXIT=(%d+)%s*$"))
  return (out:gsub("EXIT=%d+%s*$", "")), code
end
local function contains(s, needle) return s:find(needle, 1, true) ~= nil end

describe("bench run", function()
  it("belt only row marked box no", function()
    local p = io.popen("tools/bench/run.sh 2.0 --tier red --flow stacks --belt-only --dry-run 2>&1")
    local out = p:read("*a"); p:close()
    ok(out:find("bench-dry FV=2.0 boxes=200 ticks=3600 tier=red modset=none flow=stacks seed=1 box=no", 1, true), out)
    p = io.popen("BENCH_LOAD1=1.50 python3 tools/bench/parse.py tests/offline/fixtures/bench/benchmark.log /nonexistent 2.0 200 5 red none stacks no 2>&1")
    out = p:read("*a"); p:close()
    ok(out:find("load1=1.50 box=no", 1, true), out)
  end)
  it("parser prints old fields then new", function()
    local out, code = sh("BENCH_LOAD1=1.50 python3 tools/bench/parse.py tests/offline/fixtures/bench/benchmark.log tests/offline/fixtures/bench/factorio-current.log 2.0 200 5 turbo ubsa stacks")
    eq(code, 0, out)
    eq(out:gsub("%s+$", ""), "bench FV=2.0 boxes=200 ticks=5 script_ms_avg=2.182 whole_ms_avg=3.534 tier=turbo modset=ubsa flow=stacks ms_per_box=0.01091 items_in=45000 us_per_item=58.19 load1=1.50 box=yes")
  end)
  it("parser without counter lines says na", function()
    local out, code = sh("python3 tools/bench/parse.py tests/offline/fixtures/bench/benchmark.log /no/such/bench-log 2.0 200 5 yellow none single")
    eq(code, 0, out); ok(contains(out, "items_in=0 us_per_item=na"), out)
  end)
  it("parser rejects wrong tick count", function()
    local out, code = sh("python3 tools/bench/parse.py tests/offline/fixtures/bench/benchmark.log /no/such/bench-log 2.0 200 6 yellow none single")
    ok(code ~= 0, out); ok(contains(out, "expected 6 ordered tick rows"), out)
  end)
  it("dry run prints resolved row", function()
    local out, code = sh("tools/bench/run.sh 2.0 --tier ub-ultimate --modset ubsa --flow stacks --boxes 5 --seed 3 --dry-run")
    eq(code, 0, out); ok(contains(out, "bench-dry FV=2.0 boxes=5 ticks=3600 tier=ub-ultimate modset=ubsa flow=stacks seed=3"), out)
  end)
  it("defaults", function()
    local out, code = sh("tools/bench/run.sh 2.0 --dry-run")
    eq(code, 0, out); ok(contains(out, "bench-dry FV=2.0 boxes=200 ticks=3600 tier=yellow modset=none flow=single seed=1"), out)
  end)
  it("bad args exit 2", function()
    local commands = {
      "tools/bench/run.sh 2.0 --flow dice --dry-run",
      "tools/bench/run.sh 2.0 --modset nope --dry-run",
      "tools/bench/run.sh 2.1 --modset ubsa --dry-run",
      "tools/bench/run.sh 2.0 --seed x --dry-run",
      "tools/bench/run.sh 2.0 --tier 'a b' --dry-run",
      "tools/bench/run.sh 2.0 --tier",
      "tools/bench/run.sh 2.0 --what --dry-run",
    }
    for _, cmd in ipairs(commands) do local out, code = sh(cmd); eq(code, 2, cmd .. "\n" .. out) end
  end)
  it("modlist keeps stage entries adds bench", function()
    local dir = os.tmpname(); os.remove(dir); os.execute("mkdir -p " .. dir)
    local f = assert(io.open(dir .. "/mod-list.json", "w"))
    f:write('{"mods":[{"name":"base","enabled":true},{"name":"space-age","enabled":false},{"name":"sushi-packer","enabled":true},{"name":"sushi-packer-test-env","enabled":true},{"name":"AdvancedBeltsUpdated","enabled":true}]}'); f:close()
    local out, code = sh("python3 tools/bench/modlist.py " .. dir)
    local json = read(dir .. "/mod-list.json"); os.execute("rm -rf " .. dir)
    eq(code, 0, out)
    for _, pair in ipairs({{'base',true},{'space-age',false},{'AdvancedBeltsUpdated',true},{'sushi-packer-test-env',false},{'sushi-packer-bench',true}}) do
      local at = json:find('"name": "' .. pair[1] .. '"', 1, true)
      local entry = at and json:sub(at, json:find("\n    },", at, true) or #json)
      ok(entry and entry:match('"enabled"%s*:%s*' .. tostring(pair[2])), "wrong/missing " .. pair[1] .. ": " .. json)
    end
  end)
  it("makefile has bench-all rows", function()
    local makefile = read("Makefile")
    for _, needle in ipairs({"bench-all:", "yellow", "red", "blue", "turbo", "ub-ultimate", "ubsa", "kr-superior", "k2so", "--flow stacks"}) do ok(contains(makefile, needle), "Makefile missing " .. needle) end
    local out20, c20 = sh("make -n bench-all FV=2.0"); local out21, c21 = sh("make -n bench-all FV=2.1")
    eq(c20, 0, out20); eq(c21, 0, out21)
    ok(contains(out20, "ub-ultimate") and not contains(out20, "kr-superior"), out20)
    ok(contains(out21, "kr-superior") and not contains(out21, "ub-ultimate"), out21)
  end)
  it("run.sh no longer overwrites mod list", function()
    local s = read("tools/bench/run.sh")
    ok(not contains(s, "'sushi-packer','sushi-packer-bench'"), "legacy mod-list overwrite remains")
    ok(contains(s, "tools/bench/modlist.py") and contains(s, "tools/bench/parse.py"), "run.sh must call helpers")
  end)
end)
