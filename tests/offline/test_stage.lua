local function read(path)
  local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s
end

describe("stage", function()
  it("release info has no test dependency", function()
    local stage = read("tools/stage.sh")
    assert(stage:find("factorio%-test") and stage:find("release"), "stage script must filter test dependency for release")
    assert(stage:find("dependencies", 1, true), "stage must update dependency list")
  end)
  it("versions are 0.1.1 and 0.2.1", function()
    assert(read("info.json"):find('"version": "0.1.1"', 1, true))
    assert(read("tools/stage.sh"):find('0.1.1', 1, true) and read("tools/stage.sh"):find('0.2.1', 1, true))
    assert(read("tools/load_check.sh"):find('0.1.1', 1, true) and read("tools/load_check.sh"):find('0.2.1', 1, true))
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
  it("changelog format valid", function()
    local s = read("changelog.txt")
    local sep = string.rep("-", 99)
    for _, v in ipairs({"0.2.1", "0.2.0", "0.1.1", "0.1.0"}) do
      assert(s:find(sep .. "\nVersion: " .. v .. "\nDate: 2026%-09%-26"), "missing changelog block " .. v)
    end
  end)
end)
