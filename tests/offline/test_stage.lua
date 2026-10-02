local function read(path)
  local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s
end

describe("stage", function()
  it("release info has no test dependency", function()
    local stage = read("tools/stage.sh")
    assert(stage:find("factorio%-test") and stage:find("release"), "stage script must filter test dependency for release")
    assert(stage:find("dependencies", 1, true), "stage must update dependency list")
  end)
  it("versions are 0.1.21 and 0.2.21", function()
    assert(read("info.json"):find('"version": "0.1.21"', 1, true))
    assert(read("tools/stage.sh"):find('0.1.21', 1, true) and read("tools/stage.sh"):find('0.2.21', 1, true))
    assert(read("tools/load_check.sh"):find('0.1.21', 1, true) and read("tools/load_check.sh"):find('0.2.21', 1, true))
    -- v1.9 (author): README + portal page named 0.1.8 / 0.2.8 after bump; docs must name current versions
    for _, f in ipairs({ "README.md", "portal/description.md" }) do
      assert(read(f):find('0.1.21', 1, true) and read(f):find('0.2.21', 1, true), f .. " names current versions")
    end
  end)
  it("release ships thumbnail and changelog", function()
    local stage = read("tools/stage.sh")
    assert(stage:find("thumbnail.png", 1, true) and stage:find("changelog.txt", 1, true))
    assert(read("thumbnail.png") and read("changelog.txt"))
  end)
  it("thumbnail is 144 by 144 png", function()
    local f = assert(io.open("thumbnail.png", "rb")); local b = f:read("*a"); f:close()
    assert(b:sub(1, 8) == "\137PNG\r\n\026\n")
    local function u32(i) local a,c,d,e=b:byte(i,i+3); return ((a*256+c)*256+d)*256+e end
    assert(u32(17) == 144 and u32(21) == 144)
  end)
  it("release stage needs no Factorio", function()
    -- GitHub Actions builds release zips on a runner with no Factorio install.
    local dir = os.tmpname(); os.remove(dir)
    local ok = os.execute("FACTORIO_ROOT=/nonexistent STAGE_DIR=" .. dir .. " tools/stage.sh 2.0 release >/dev/null 2>&1")
    local info = io.open(dir .. "/mods/sushi-packer_0.1.21/info.json")
    os.execute("rm -rf " .. dir)
    assert(ok == true or ok == 0, "stage release failed without Factorio")
    assert(info, "release staged mod missing"); info:close()
  end)
  it("portal logo and description in repo", function()
    local function size(path)
      local f = assert(io.open(path, "rb"), path .. " missing"); local b = f:read("*a"); f:close()
      assert(b:sub(1, 8) == "\137PNG\r\n\026\n", path .. " not png")
      local function u32(i) local a,c,d,e=b:byte(i,i+3); return ((a*256+c)*256+d)*256+e end
      return u32(17), u32(21)
    end
    local w, h = size("portal/logo-512.png"); assert(w == 512 and h == 512, "logo 512")
    local d = read("portal/description.md")
    for _, needle in ipairs({"# Sushi Packer", "0.1.21", "0.2.21", "Space Age", "belt stack"}) do
      assert(d:find(needle, 1, true), "description lacks " .. needle)
    end
    assert(not d:find("logo-512.png", 1, true), "description repeats portal thumbnail (author 2026-09-28)")
    assert(not d:find("all 48 slots", 1, true), "description still says shared all 48 slots (v8: 24 per lane)")
    assert(read("README.md"):find("portal/logo-512.png", 1, true), "README shows logo")
    assert(read("tools/thumb_from_shot.py"):find("thumbnail.png", 1, true), "thumb_from_shot.py writes thumbnail")
    assert(read("portal/thumb-shot.png"), "in-game source shot in repo (author 2026-09-28)")
  end)
  it("release ships MIT license", function()
    assert(read("LICENSE"):find("MIT License", 1, true), "LICENSE is MIT (author 2026-09-27)")
    assert(read("tools/stage.sh"):find("LICENSE", 1, true), "stage ships LICENSE")
  end)
  it("changelog format valid", function()
    local s = read("changelog.txt")
    local sep = string.rep("-", 99)
    for _, v in ipairs({"0.2.21", "0.2.20", "0.2.19", "0.2.18", "0.2.17", "0.2.16", "0.2.15", "0.2.14", "0.2.13", "0.2.12", "0.2.11", "0.2.10", "0.2.9", "0.2.8", "0.2.7", "0.2.6", "0.2.5", "0.2.4", "0.2.3", "0.2.2", "0.2.1", "0.2.0", "0.1.20", "0.1.19", "0.1.18", "0.1.17", "0.1.16", "0.1.15", "0.1.14", "0.1.13", "0.1.12", "0.1.11", "0.1.10", "0.1.9", "0.1.8", "0.1.7", "0.1.6", "0.1.5", "0.1.4", "0.1.3", "0.1.2", "0.1.1", "0.1.0"}) do
      assert(s:find(sep .. "\nVersion: " .. v .. "\nDate: 2026-", 1, true), "missing changelog block " .. v)  -- v1.15: October
    end
  end)
end)
