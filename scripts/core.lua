local N = require("scripts.names")
local M = {}

local function keyeq(x, name, quality) return x.name == name and x.quality == quality end
local function partial_key(name, quality, lane)
  return name .. "\0" .. quality .. "\0" .. lane
end
local function ensure_partial_index(box)
  if box.partial_by_key then return end
  local index = {}
  for i = 1, #box.partials do
    local p = box.partials[i]
    index[partial_key(p.name, p.quality, p.lane)] = p
  end
  box.partial_by_key = index
end
local function ready_add(box, p)
  box.sequence = box.sequence + 1
  p.started = false
  p.ready_sequence = box.sequence
  local q = box.ready[p.lane]
  q[#q + 1] = p
end
local function remove_partial(box, i)
  ensure_partial_index(box)
  local p = table.remove(box.partials, i)
  local key = partial_key(p.name, p.quality, p.lane)
  if box.partial_by_key[key] == p then box.partial_by_key[key] = nil end
  return p
end
local function oldest_partial(box, lane)
  local best
  for i = 1, #box.partials do
    local p = box.partials[i]
    if p.lane == lane and (best == nil or p.first_tick < box.partials[best].first_tick or
      (p.first_tick == box.partials[best].first_tick and p.sequence < box.partials[best].sequence)) then best = i end
  end
  return best
end
local function find_partial(box, name, quality, lane)
  ensure_partial_index(box)
  return box.partial_by_key[partial_key(name, quality, lane)]
end
-- D-5 (v8): per-lane slot count and per-(name, quality, lane) item count, partials + ready. Built lazily so
-- v1.7 saves migrate on first touch.
local function ensure_counters(box)
  if box.lane_used and box.held then return end
  local used, held = { 0, 0 }, {}
  local function count(p)
    used[p.lane] = used[p.lane] + 1
    local key = partial_key(p.name, p.quality, p.lane)
    held[key] = (held[key] or 0) + p.count
  end
  for i = 1, #box.partials do count(box.partials[i]) end
  for l = 1, 2 do for i = 1, #box.ready[l] do count(box.ready[l][i]) end end
  box.lane_used, box.held = used, held
end
local function held_add(box, p, n)
  local key = partial_key(p.name, p.quality, p.lane)
  local v = (box.held[key] or 0) + n
  if v <= 0 then v = nil end
  box.held[key] = v
end
local function add(box, name, quality, lane, count, stack_size, tick, limited, item_stack)
  ensure_counters(box)
  if limited then
    local room = M.item_room(box, name, quality, lane, item_stack)
    if room < count then count = room end
    if count <= 0 then return 0 end
  end
  local accepted = 0
  while count > 0 do
    local p = find_partial(box, name, quality, lane)
    if p then
      local n = math.min(count, p.stack_size - p.count)
      p.count = p.count + n; box.stored_count = box.stored_count + n; held_add(box, p, n)
      count = count - n; accepted = accepted + n
      if p.count == p.stack_size then
        local idx
        for i = 1, #box.partials do if box.partials[i] == p then idx = i; break end end
        remove_partial(box, idx); ready_add(box, p)
      end
    else
      if limited and not M.lane_room(box, lane) then
        local oldest = oldest_partial(box, lane)
        if oldest then
          local p = remove_partial(box, oldest); ready_add(box, p)
          box.used_slots = box.used_slots -- partial slot becomes ready slot
        end
        return accepted
      end
      box.sequence = box.sequence + 1
      local n = math.min(count, stack_size)
      local p = {name=name, quality=quality, lane=lane, count=n, stack_size=stack_size,
        first_tick=tick, sequence=box.sequence}
      if n == stack_size then ready_add(box, p) else
        local insert = #box.partials + 1
        for i=1,#box.partials do
          local old=box.partials[i]
          if tick < old.first_tick or (tick == old.first_tick and p.sequence < old.sequence) then insert=i; break end
        end
        table.insert(box.partials, insert, p)
        box.partial_by_key[partial_key(name, quality, lane)] = p
      end
      box.used_slots = box.used_slots + 1
      box.lane_used[lane] = box.lane_used[lane] + 1; held_add(box, p, n)
      box.stored_count = box.stored_count + n
      count = count - n; accepted = accepted + n
    end
  end
  return accepted
end

function M.new_box()
  return {partials={}, partial_by_key={}, ready={{},{}}, hold={nil,nil}, used_slots=0, stored_count=0, sequence=0,
    lane_used={0,0}, held={}}
end
-- L-2 v8 (lane A): may `lane` take one more slot? false -> flush/refuse like full box.
function M.lane_room(box, lane)
  ensure_counters(box)
  return box.lane_used[lane] < N.SLOTS / 2
end
-- C-6 v8 (lane B): how many more of (name, quality) `lane` may hold. item_stack nil = no cap.
function M.item_room(box, name, quality, lane, item_stack) return math.huge end
function M.accept(box, name, quality, lane, count, stack_size, tick, passthrough, item_stack)
  if passthrough then
    if box.hold[lane] ~= nil then return 0 end
    box.hold[lane]={name=name,quality=quality,count=count}; return count
  end
  return add(box,name,quality,lane,count,stack_size,tick,true,item_stack)
end
function M.adopt_external(box, name, quality, n, stack_size, tick)
  add(box,name,quality,1,n,stack_size,tick,false); return n
end
function M.used_slots(box) return box.used_slots end
function M.free_slots(box) return N.SLOTS-box.used_slots end
function M.on_tick(box, tick, timeout_ticks)
  if timeout_ticks == 0 then return end
  local i=1
  while i <= #box.partials do
    local p=box.partials[i]
    if p.first_tick + timeout_ticks <= tick then
      remove_partial(box,i); ready_add(box,p)
    else i=i+1 end
  end
end
function M.flush_partials(box, tick)
  while #box.partials > 0 do local p=remove_partial(box,1); ready_add(box,p) end
end
function M.peek_out(box, lane)
  local head=box.ready[lane][1]
  if head and head.started then return {name=head.name,quality=head.quality,count=head.count,passthrough=false} end
  local h=box.hold[lane]
  if h then return {name=h.name,quality=h.quality,count=h.count,passthrough=true} end
  if head then return {name=head.name,quality=head.quality,count=head.count,passthrough=false} end
  return nil
end
function M.take_out(box, lane, n)
  local item=M.peek_out(box,lane)
  if not item or n > item.count then error("take_out exceeds available item") end
  if item.passthrough then
    local h=box.hold[lane]; h.count=h.count-n
    if h.count==0 then box.hold[lane]=nil end
  else
    ensure_counters(box)
    local head=box.ready[lane][1]; head.started=true; head.count=head.count-n; box.stored_count=box.stored_count-n
    held_add(box,head,-n)
    if head.count==0 then table.remove(box.ready[lane],1); box.used_slots=box.used_slots-1; box.lane_used[lane]=box.lane_used[lane]-1 end
  end
end
function M.remove_external(box, name, quality, n)
  ensure_counters(box)
  local removed=0
  while removed<n do
    local best
    for i=1,#box.partials do local p=box.partials[i]
      if keyeq(p,name,quality) and (not best or p.first_tick>box.partials[best].first_tick or
        (p.first_tick==box.partials[best].first_tick and p.sequence>box.partials[best].sequence)) then best=i end
    end
    if not best then break end
    local p=box.partials[best]; local take=math.min(n-removed,p.count)
    p.count=p.count-take; box.stored_count=box.stored_count-take; removed=removed+take; held_add(box,p,-take)
    if p.count==0 then remove_partial(box,best); box.used_slots=box.used_slots-1; box.lane_used[p.lane]=box.lane_used[p.lane]-1 end
  end
  while removed<n do
    local lane,idx,seq
    for l=1,2 do for i=1,#box.ready[l] do local p=box.ready[l][i]
      if keyeq(p,name,quality) and (not seq or p.ready_sequence>seq) then lane,idx,seq=l,i,p.ready_sequence end
    end end
    if not lane then break end
    local q=box.ready[lane]; local p=q[idx]; local take=math.min(n-removed,p.count)
    p.count=p.count-take; box.stored_count=box.stored_count-take; removed=removed+take; held_add(box,p,-take)
    if p.count==0 then table.remove(q,idx); box.used_slots=box.used_slots-1; box.lane_used[lane]=box.lane_used[lane]-1 end
  end
  return removed
end
function M.hold_items(box)
  local out={}; for lane=1,2 do local h=box.hold[lane]; if h then out[#out+1]={name=h.name,quality=h.quality,count=h.count} end end; return out
end
function M.clear_hold(box) box.hold[1]=nil; box.hold[2]=nil end
function M.totals(box)
  local map={}
  local function add_total(p)
    local k=p.name.."\0"..tostring(p.quality); local t=map[k]
    if not t then t={name=p.name,quality=p.quality,count=0}; map[k]=t end
    t.count=t.count+p.count
  end
  for i=1,#box.partials do add_total(box.partials[i]) end
  for l=1,2 do for i=1,#box.ready[l] do add_total(box.ready[l][i]) end end
  local out={}; for _,v in pairs(map) do out[#out+1]=v end
  table.sort(out,function(a,b) if a.name~=b.name then return a.name<b.name end return a.quality<b.quality end)
  return out
end
function M.led_state(box)
  ensure_counters(box)
  if box.lane_used[1] >= N.SLOTS / 2 or box.lane_used[2] >= N.SLOTS / 2 then return "red" end
  if M.is_idle(box) then return "green" end
  return "yellow"
end
function M.is_idle(box)
  return box.stored_count==0 and #box.partials==0 and #box.ready[1]==0 and #box.ready[2]==0 and box.hold[1]==nil and box.hold[2]==nil
end
return M
