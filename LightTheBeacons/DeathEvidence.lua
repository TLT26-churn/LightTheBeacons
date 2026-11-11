local _,B=...
local C,P=B.Client,B.Protocol
local damage={SWING_DAMAGE=true,SPELL_DAMAGE=true,SPELL_PERIODIC_DAMAGE=true,RANGE_DAMAGE=true,
    DAMAGE_SHIELD=true,DAMAGE_SPLIT=true,ENVIRONMENTAL_DAMAGE=true}
-- Public recap formats differ between client builds. Keep the adapter bounded
-- and fail closed on restricted values; never infer an attacker from proximity.
local function rawRecap()
    local rows=C_DeathRecap and C.Call(C_DeathRecap.GetRecapEvents)
    if not P.Plain(rows) or type(rows)~="table" then return {},false end
    return rows,true
end
local function latestStamp(rows)
    local latest=0
    for i=1,256 do
        local e=rows[i];if P.Plain(e) and e==nil then break end
        if P.Plain(e) and type(e)=="table" and P.Number(e.timestamp,1,1e12) then latest=math.max(latest,e.timestamp) end
    end
    return latest
end
function C.CaptureLivingRecap()
    B.lastLivingRecap=C.RecapKey()
    -- A timestamp baseline is needed only on clients without recap links.
    if B.lastLivingRecap then B.lastLivingRecapStamp=0
    else B.lastLivingRecapStamp=C.Call(function()
        local rows,available=rawRecap();if available then return latestStamp(rows) end
    end) end
end
function C.BeginDeathEvidence()
    B.deathEvidence={at=GetTime(),server=C.Now()};B.recapReadStatus="waiting"
end
local function readRecap()
    local raw,available=rawRecap();if not available then return {},"recap unavailable" end
    local link=C.RecapKey();local incident=B.deathEvidence
    local newLink=link and link~=B.lastLivingRecap
    local latest=latestStamp(raw)
    local newStamp=not link and not B.lastLivingRecap and incident
        and P.Number(B.lastLivingRecapStamp,0,1e12) and latest>B.lastLivingRecapStamp
        and latest>=incident.server-2 and latest<=incident.server+2
    if not newLink and not newStamp then return {},"no fresh recap" end
    local rows={}
    for i=1,256 do
        local e=raw[i];if P.Plain(e) and e==nil then break end
        if P.Plain(e) and type(e)=="table" then
            local age,lethalWindow
            if P.Number(e.timeBeforeDeath,0,30) then
                age=e.timeBeforeDeath;lethalWindow=age<=.25
            elseif incident and P.Number(e.timestamp,incident.server-30,incident.server+2) then
                age=math.max(0,incident.server-e.timestamp);lethalWindow=age<=2
            end
            -- Explicit invalid/old timestamps cannot be rescued by another field.
            local stampOK=P.Plain(e.timestamp) and e.timestamp==nil or incident and P.Number(e.timestamp,incident.server-30,incident.server+2)
            local eventOK=P.Text(e.event,40) and damage[e.event]
            local lethal=P.Number(e.overkill,0,1e12) and lethalWindow
            -- Legacy recaps sometimes omit amount/event for the killing blow.
            local legacy=P.Plain(e.event) and e.event==nil and lethal
            if age and stampOK and (eventOK or legacy) and (P.Number(e.amount,1,1e12) or lethal and P.Plain(e.amount) and e.amount==nil) then
                rows[#rows+1]={guid=P.Text(e.sourceGUID,80) and e.sourceGUID or nil,
                    name=P.Text(e.sourceName,100) and e.sourceName or nil,
                    flags=P.Number(e.sourceFlags,0,2147483647) and e.sourceFlags or nil,
                    age=age,lethal=lethal and true or false,environmental=P.Text(e.event,40) and e.event=="ENVIRONMENTAL_DAMAGE"}
            end
        end
    end
    return rows,#rows>0 and "fresh readable recap" or "fresh recap; no readable damage"
end
function C.DeathRecap()
    local ok,rows,status=pcall(readRecap)
    B.recapReadStatus=ok and status or "recap unavailable"
    return ok and rows or {}
end
local function recapKiller()
    local winner,ambiguous
    for _,e in ipairs(C.DeathRecap()) do
        if e.lethal then
            if not winner or e.age<winner.age then winner=e;ambiguous=false
            elseif e.age==winner.age and e.guid~=winner.guid then ambiguous=true end
        end
    end
    return not ambiguous and winner or nil,ambiguous
end
local function verdict()
    local killer,ambiguous=recapKiller();local incident=B.deathEvidence
    if killer then
        local player=C.HostilePlayer(killer.guid,killer.flags) and {source=killer.guid,name=killer.name} or nil
        local npc=killer.environmental or C.NonPlayerSource(killer.guid,killer.flags)
        if incident then incident.killer=player;incident.nonPlayer=npc;incident.resolved=true end
        return player,npc
    end
    if ambiguous then
        if incident then incident.killer=nil;incident.nonPlayer=nil;incident.resolved=true end
        return nil,false
    end
    if B.nonPlayerDeath and GetTime()-B.nonPlayerDeath<=4 then
        if incident then incident.killer=nil;incident.nonPlayer=true;incident.resolved=true end
        return nil,true
    end
    if incident and incident.resolved then return incident.killer,incident.nonPlayer end
    if B.killingBlow and GetTime()-B.killingBlow.at<=4 then
        if incident then incident.killer=B.killingBlow;incident.nonPlayer=false;incident.resolved=true end
        return B.killingBlow,false
    end
end
function C.ConfirmedDeath()
    local killer=verdict()
    return killer~=nil,killer
end
function C.ConfirmedNonPlayerDeath()
    local _,npc=verdict();return npc and true or false
end
function C.DeathAttackers(at,killer)
    local byName,byGUID={},{}
    local mine=C.Call(UnitGUID,"player")
    local function add(guid,name)
        if not P.Text(name,100) or name~=B.Grudges.Clean(name,70,100)
            or not P.Text(guid,80) or not guid:match("^Player%-%x+%-%x+$") then return end
        local key=P.Identity(name)
        if not key or key==B.me or B.members[key] or P.Text(mine,80) and guid==mine then return end
        local lethal=killer and killer.source==guid or false
        if byGUID[guid] then if lethal then byGUID[guid].killingBlow=true end;return end
        if not byName[key] or lethal then
            local entry={key=key,guid=guid,name=name,killingBlow=lethal}
            byName[key]=entry;byGUID[guid]=entry
        end
    end
    for _,entry in pairs(B.recentAttackers or {}) do
        if entry.at>=at-30 and entry.at<=at+3.2 then add(entry.guid,entry.name) end
    end
    for _,entry in ipairs(C.DeathRecap()) do
        if C.HostilePlayer(entry.guid,entry.flags) then add(entry.guid,entry.name) end
    end
    if killer then add(killer.source,killer.name) end
    local list={};for _,entry in pairs(byName) do list[#list+1]=entry end
    table.sort(list,function(a,b) if a.killingBlow~=b.killingBlow then return a.killingBlow end;return a.key<b.key end)
    while #list>32 do table.remove(list) end
    return list
end
