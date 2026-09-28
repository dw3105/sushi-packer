-- S0 v9 probe P1 (SP-10: NOT in index; temporary entry, report via error()). Run per MODSET.
-- Dumps belt-family prototypes + unlock techs so N.EXTRA rows use real names, never guesses.
describe("probe v9 modset", function()
  it("dump belts splitters techs", function()
    local unlock = {}  -- recipe -> techs
    for tname, t in pairs(prototypes.technology) do
      for _, eff in ipairs(t.effects or {}) do
        if eff.type == "unlock-recipe" then
          unlock[eff.recipe] = unlock[eff.recipe] or {}
          table.insert(unlock[eff.recipe], tname)
        end
      end
    end
    local function techinfo(tn)
      local t = prototypes.technology[tn]
      if not t then return tn .. "(missing)" end
      local packs = {}
      for _, u in ipairs(t.research_unit_ingredients or {}) do packs[#packs + 1] = u.name end
      return string.format("%s[unit=%s count=%s hidden=%s packs=%s prereq=%s]", tn,
        tostring(t.research_unit_count_formula == nil and t.research_unit_count or t.research_unit_count_formula),
        tostring(t.research_unit_count), tostring(t.hidden), table.concat(packs, ","),
        table.concat((function() local p = {} for k in pairs(t.prerequisites or {}) do p[#p + 1] = k end table.sort(p) return p end)(), ","))
    end
    local lines = { "active mods: " .. (function() local m = {} for k, v in pairs(script.active_mods) do m[#m + 1] = k .. "@" .. v end table.sort(m) return table.concat(m, " ") end)() }
    for _, ty in ipairs({ "transport-belt", "underground-belt", "splitter" }) do
      local names = {}
      for n in pairs(prototypes.get_entity_filtered({ { filter = "type", type = ty } })) do names[#names + 1] = n end
      table.sort(names)
      for _, n in ipairs(names) do
        local e = prototypes.entity[n]
        local item = e.items_to_place_this and e.items_to_place_this[1]
        local itemname = item and (item.name or item) or "-"
        local techs = {}
        for _, tn in ipairs(unlock[itemname] or unlock[n] or {}) do techs[#techs + 1] = techinfo(tn) end
        table.sort(techs)
        local r = prototypes.recipe[itemname] or prototypes.recipe[n]
        local ing = {}
        if r then for _, i in ipairs(r.ingredients) do ing[#ing + 1] = i.name .. "x" .. i.amount end end
        lines[#lines + 1] = string.format("%s %s speed=%.6f items_s=%.2f hidden=%s next=%s item=%s recipe=%s{%s} tech=%s",
          ty, n, e.belt_speed, e.belt_speed * 480, tostring(e.hidden), e.next_upgrade and e.next_upgrade.name or "-",
          itemname, r and r.name or "-", table.concat(ing, ","), table.concat(techs, " | "))
      end
    end
    for n, s in pairs(settings.startup) do
      if n:find("belt") or n:find("hyper") then lines[#lines + 1] = "setting " .. n .. "=" .. tostring(s.value) end
    end
    local sp = {}
    for n in pairs(prototypes.item) do if n:find("sushi%-packer") then sp[#sp + 1] = n end end
    table.sort(sp)
    lines[#lines + 1] = "sushi items: " .. table.concat(sp, " ")
    log("P1DUMP\n" .. table.concat(lines, "\n"))
    error("P1DUMP lines=" .. #lines .. " (full dump in factorio-current.log)")
  end)
end)
