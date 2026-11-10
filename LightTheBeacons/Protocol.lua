local _, B = ...
B.Protocol = {}
local P = B.Protocol
P.prefix, P.ttl, P.cooldown = "LTB1", 300, 60

function P.Plain(v)
    return not (issecretvalue and issecretvalue(v))
end
function P.Number(v, lo, hi)
    return P.Plain(v) and type(v) == "number" and v == v and v >= lo and v <= hi
end
function P.Text(v, max)
    return P.Plain(v) and type(v) == "string" and #v > 0 and #v <= (max or 150) and not v:find("[|%c]")
end
function P.Identity(name)
    if not P.Text(name) then return end
    if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
        return name:gsub("%-[^%-]+$", ""):lower()
    end
    local n, realm = name:match("^(.-)%-(.+)$")
    if not n then n, realm = name, (GetNormalizedRealmName and GetNormalizedRealmName() or "") end
    return (n .. "-" .. realm:gsub("%s", "")):lower()
end
local function idOK(id)
    return P.Text(id, 40) and id:match("^[%w%.%-]+$") ~= nil
end
function P.Encode(b)
    return string.format("1|B|%s|%d|%d|%.5f|%.5f|%s", b.id, b.sent, b.map, b.px, b.py, b.reason)
end
-- Never evaluate received Lua or accept a sender identity from a payload.
function P.Parse(msg, now)
    if not P.Plain(msg) or type(msg) ~= "string" or #msg > 250 or msg:find("%c") then return end
    local f = {}
    for part in (msg .. "|"):gmatch("(.-)|") do f[#f+1] = part end
    if f[1] ~= "1" then return end
    if f[2] == "Q" and #f == 2 then return {kind="Q"} end
    if not idOK(f[3]) then return end
    if f[2] == "C" and #f == 3 then return {kind="C", id=f[3]} end
    if f[2] == "R" and #f == 4 and P.Text(f[4]) then
        return {kind="R", id=f[3], owner=f[4]}
    end
    if f[2] ~= "B" or #f ~= 8 then return end
    local sent, map, x, y = tonumber(f[4]), tonumber(f[5]), tonumber(f[6]), tonumber(f[7])
    if not P.Number(sent, now-P.ttl, now+10) or sent%1 ~= 0 or sent<=now-P.ttl then return end
    if not P.Number(map, 1, 100000) or map%1 ~= 0 then return end
    if not P.Number(x, 0, 1) or not P.Number(y, 0, 1) then return end
    if f[8] ~= "aid" and f[8] ~= "pvp" and f[8] ~= "fallen" then return end
    return {kind="B", id=f[3], sent=sent, expires=math.min(sent+P.ttl, now+P.ttl),
        map=map, px=x, py=y, reason=f[8]}
end

function P.NewSession(now)
    return {beacons={}, dead={}, heard={}, lastNew={}, lastQuery={}, newest={}, budget={}, now=now or 0}
end
function P.Prune(s, now)
    for key,b in pairs(s.beacons) do if b.expires <= now then s.beacons[key] = nil end end
    for key,t in pairs(s.dead) do if t <= now then s.dead[key] = nil end end
    for key,t in pairs(s.heard) do if t+P.ttl*2 <= now then s.heard[key] = nil end end
    for key,t in pairs(s.lastNew) do if t+P.ttl*2 <= now then s.lastNew[key] = nil end end
    for key,t in pairs(s.lastQuery) do if t+P.ttl*2 <= now then s.lastQuery[key] = nil end end
    for key,t in pairs(s.newest) do if t+P.ttl*2 <= now then s.newest[key] = nil end end
    for key,v in pairs(s.budget) do if v.at+30 <= now then s.budget[key] = nil end end
end
function P.Receive(s, msg, sender, channel, members, now)
    if channel ~= "GUILD" then return end
    local key = P.Identity(sender)
    if not key or not members[key] then return end
    local b = P.Parse(msg, now)
    if not b then return end
    P.Prune(s, now)
    local budget=s.budget[key]
    if not budget or now-budget.at>=10 then budget={at=now,count=0};s.budget[key]=budget end
    budget.count=budget.count+1;if budget.count>12 then return end
    if b.kind == "Q" then
        if s.lastQuery[key] and now-s.lastQuery[key] < 30 then return end
        s.lastQuery[key] = now
        return "query", key
    end
    if b.kind == "R" then
        local active = s.beacons[b.owner]
        if active and active.id == b.id and key ~= b.owner then
            active.responders = active.responders or {}
            if active.responders[key] then return end
            active.responders[key] = sender
            return "response", active
        end
        return
    end
    local token = key .. ":" .. b.id
    if b.kind == "C" then
        -- A sender can only extinguish its own beacon, including reordered packets.
        local count=0;for _ in pairs(s.dead) do count=count+1 end
        if count<512 then s.dead[token] = now+P.ttl end
        if s.beacons[key] and s.beacons[key].id == b.id then
            local old = s.beacons[key]; s.beacons[key] = nil
            return "cancel", old
        end
        return
    end
    if s.dead[token] then return end
    local old = s.beacons[key]
    if old and (old.id == b.id or old.sent > b.sent) then return end
    if s.newest[key] and b.sent<=s.newest[key] then return end
    if s.lastNew[key] and now-s.lastNew[key] < P.cooldown then return end
    local count=0; for _ in pairs(s.beacons) do count=count+1 end
    if not old and count>=80 then return end
    s.lastNew[key] = now
    s.newest[key] = b.sent
    b.owner, b.name, b.responders = key, sender, {}
    local sound = not s.heard[token]
    s.heard[token] = now
    s.beacons[key] = b
    return "beacon", b, sound
end
