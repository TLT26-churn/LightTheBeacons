local _, B = ...
local C, P = {}, B.Protocol; B.Client=C
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d=pcall(fn,...);if ok then return a,b,c,d end
end
C.Call=call
function C.Now() return GetServerTime and GetServerTime() or time() end
function C.Me()
    local name,surname=call(UnitNameUnmodified or UnitName,"player")
    if not P.Text(name) then return end
    if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
        if P.Text(surname) then
            local sep=Constants and Constants.CharacterNameSeparatorConsts and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
            local tail=sep..surname
            if name:sub(-#tail)~=tail then name=name..tail end
        end
    elseif UnitFullName then
        local first,realm=call(UnitFullName,"player")
        if P.Text(first) then name=first end
        if P.Text(realm) then name=name.."-"..realm end
    end
    return P.Identity(name),name
end
function C.Faction()
    local value=call(UnitFactionGroup,"player")
    return P.Plain(value) and value=="Horde" and "H" or "A"
end
function C.Members()
    if not IsInGuild or not IsInGuild() then return {} end
    local members={};local me=C.Me();if me then members[me]=true end
    local function add(name) local k=P.Identity(name);if k then members[k]=true end end
    local club=C_Club and call(C_Club.GetGuildClubId)
    if club and C_Club.GetClubMembers and C_Club.GetMemberInfo then
        local ids=call(C_Club.GetClubMembers,club)
        if type(ids)=="table" then for _,id in ipairs(ids) do
            local m=call(C_Club.GetMemberInfo,club,id)
            if type(m)=="table" then add(m.name) end
        end end
    end
    local n=call(GetNumGuildMembers)
    if P.Number(n,0,10000) then for i=1,n do add(call(GetGuildRosterInfo,i)) end end
    return members
end
function C.Send(msg)
    if not IsInGuild or not IsInGuild() then return false,"Join a guild to light a beacon." end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return false,"Addon messages are unavailable." end
    if C_ChatInfo.InChatMessagingLockdown and call(C_ChatInfo.InChatMessagingLockdown)==true then
        return false,"The game is restricting addon messages. Try again when combat ends."
    end
    local ok,result=pcall(C_ChatInfo.SendAddonMessage,P.prefix,msg,"GUILD")
    local success=ok and P.Plain(result) and (result==true or result==0 or
        (Enum and Enum.SendAddonMessageResult and result==Enum.SendAddonMessageResult.Success))
    if not success then return false,"The game did not accept the beacon message. Please try again." end
    return true
end
function C.World(map,x,y)
    if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return end
    if not P.Number(map,1,100000) or not P.Number(x,0,1) or not P.Number(y,0,1) then return end
    local continent,vec=call(C_Map.GetWorldPosFromMapPos,map,CreateVector2D(x,y))
    if not P.Number(continent,0,100000) or not vec or not P.Plain(vec) then return end
    if not P.Number(vec.x,-100000,100000) or not P.Number(vec.y,-100000,100000) then return end
    return {c=continent,x=vec.x,y=vec.y,map=map,px=x,py=y}
end
function C.MapPoint(p,override)
    if not p then return end
    if p.map and not override then return p.map,p.px,p.py end
    if not C_Map or not C_Map.GetMapPosFromWorldPos or not CreateVector2D then return end
    local map,vec=call(C_Map.GetMapPosFromWorldPos,p.c,CreateVector2D(p.x,p.y),override)
    if not P.Number(map,1,100000) or not vec or not P.Plain(vec) then return end
    if not P.Number(vec.x,0,1) or not P.Number(vec.y,0,1) then return end
    return map,vec.x,vec.y
end
function C.Position()
    local map=C_Map and call(C_Map.GetBestMapForUnit,"player")
    if not P.Number(map,1,100000) then return end
    local vec=call(C_Map.GetPlayerMapPosition,map,"player")
    if not vec or not P.Plain(vec) then return end
    return C.World(map,vec.x,vec.y)
end
function C.Zone(map)
    local info=C_Map and call(C_Map.GetMapInfo,map)
    return type(info)=="table" and P.Text(info.name) and info.name or "Unknown location"
end
function C.IsOutdoor()
    local inInstance,kind=call(IsInInstance)
    return P.Plain(inInstance) and inInstance==false and P.Plain(kind) and kind~="pvp" and kind~="arena"
end
function C.Corpse()
    -- Retain the incident position when the player releases at a graveyard.
    if B.deathPoint then return B.deathPoint end
    local map=C_Map and call(C_Map.GetBestMapForUnit,"player")
    local vec=map and C_DeathInfo and call(C_DeathInfo.GetCorpseMapPosition,map)
    if vec and P.Plain(vec) then return C.World(map,vec.x,vec.y) end
end
function C.KnownCount()
    local n=0;for _,v in pairs(B.db.known) do if v==true then n=n+1 end end;return n
end
local function remember(map,node,taxi)
    if not node or not P.Plain(node) or not P.Number(node.nodeID,1,100000) then return end
    local id=node.nodeID
    if taxi then
        local states=Enum and Enum.FlightPathState
        if states and P.Plain(node.state) and (node.state==states.Current or node.state==states.Reachable) then
            B.db.known[id]=true
        end
    else
        if not P.Plain(node.isUndiscovered) then return end
        if node.isUndiscovered==false then B.db.known[id]=true
        elseif node.isUndiscovered==true then B.db.known[id]=false end
    end
    local n=B.TravelData.nodes[id]
    if not n and not taxi and node.position and P.Plain(node.position) then
        local p=C.World(map,node.position.x,node.position.y)
        local f=node.faction
        local factions=Enum and Enum.FlightPathFaction
        if p and factions and P.Plain(f) and (f==factions.Alliance or f==factions.Horde or f==factions.Neutral) and P.Text(node.name) then
            n={n=node.name,c=p.c,x=p.x,y=p.y,f=f==factions.Alliance and "A" or f==factions.Horde and "H" or "AH"}
            B.TravelData.nodes[id]=n;B.db.nodes[id]=n
        end
    end
    if n and P.Text(node.name) then n.n=node.name end
end
function C.ScanMap(map)
    if not C_TaxiMap then return end
    local nodes=call(C_TaxiMap.GetTaxiNodesForMap,map)
    if type(nodes)=="table" and P.Plain(nodes) then
        for _,node in ipairs(nodes) do remember(map,node,false) end
    end
end
function C.RefreshFlights()
    if not B.db or C.scanning or not C_Map then return end
    local queue,seen={},{}
    local function add(id) if P.Number(id,1,100000) and not seen[id] and #queue<300 then seen[id]=true;queue[#queue+1]=id end end
    add(1414);add(1415);add(947)
    local map=call(C_Map.GetBestMapForUnit,"player")
    for _=1,12 do
        if not map or seen[map] then break end
        add(map);local info=call(C_Map.GetMapInfo,map);map=info and info.parentMapID
    end
    for i=1,#queue do
        local children=call(C_Map.GetMapChildrenInfo,queue[i],nil,true)
        if type(children)=="table" then for _,info in ipairs(children) do add(info.mapID) end end
    end
    C.scanning=true;local i=1
    local function batch()
        for _=1,8 do if not queue[i] then break end;C.ScanMap(queue[i]);i=i+1 end
        if queue[i] and C_Timer then C_Timer.After(.05,batch)
        else C.scanning=false;if B.UI then B.UI.Refresh() end end
    end
    batch()
end
function C.TaxiOpened()
    local map=call(GetTaxiMapID)
    if not map or not C_TaxiMap then return end
    local nodes=call(C_TaxiMap.GetAllTaxiNodes,map)
    if type(nodes)~="table" then return end
    C.taxiSlots={};C.taxiCurrent=nil
    local states=Enum and Enum.FlightPathState
    for _,n in ipairs(nodes) do
        remember(map,n,true)
        if P.Number(n.slotIndex,1,10000) then C.taxiSlots[n.slotIndex]=n.nodeID end
        if states and P.Plain(n.state) and n.state==states.Current then C.taxiCurrent=n.nodeID end
    end
    -- Record actual directed connections exposed by this flight master. This
    -- extends the seed graph when Forever adds new flight points.
    if GetNumRoutes and TaxiGetNodeSlot then
        for slot in pairs(C.taxiSlots) do
            local count=call(GetNumRoutes,slot)
            if P.Number(count,1,100) then for hop=1,count do
                local from=C.taxiSlots[call(TaxiGetNodeSlot,slot,hop,true)]
                local to=C.taxiSlots[call(TaxiGetNodeSlot,slot,hop,false)]
                local a,b=B.TravelData.nodes[from],B.TravelData.nodes[to]
                if a and b and from~=to then
                    B.db.links[from]=B.db.links[from] or {}
                    local seconds=B.TravelData.flights[from] and B.TravelData.flights[from][to]
                        or B.Routing.Distance(a,b)*1.35/32
                    if P.Number(seconds,1,3600) then
                        B.db.links[from][to]=seconds
                        B.TravelData.flights[from]=B.TravelData.flights[from] or {}
                        B.TravelData.flights[from][to]=seconds
                    end
                end
            end end
        end
    end
    C.ScanMap(map)
    if B.UI then B.UI.Refresh() end
end
function C.TaxiTaken(slot)
    local from,to=C.taxiCurrent,C.taxiSlots and C.taxiSlots[slot]
    if from and to then C.flight={from=from,to=to,started=GetTime(),seen=false} end
end
function C.ObserveFlight()
    if not C.flight then return end
    local f=C.flight
    if UnitOnTaxi and UnitOnTaxi("player") then f.seen=true
    elseif f.seen then
        -- Only learn a single direct leg and verify arrival. Multi-hop rides
        -- and early landings must not overwrite the direct-flight estimates.
        local pos=C.Position();local dest=B.TravelData.nodes[f.to]
        local seconds=GetTime()-f.started
        if B.TravelData.flights[f.from] and B.TravelData.flights[f.from][f.to]
            and B.Routing.Distance(pos,dest)<100 and seconds>5 and seconds<3600 then
            B.db.times[f.from..":"..f.to]=seconds
        end
        C.flight=nil
    elseif GetTime()-f.started>20 then C.flight=nil end
end
function C.Waypoint(p)
    local map,x,y=C.MapPoint(p)
    if not map then return false end
    if C_Map.CanSetUserWaypointOnMap and call(C_Map.CanSetUserWaypointOnMap,map)==false then return false end
    if C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local ok=pcall(C_Map.SetUserWaypoint,UiMapPoint.CreateFromCoordinates(map,x,y))
        if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then call(C_SuperTrack.SetSuperTrackedUserWaypoint,true) end
    end
    return true
end
function C.OpenMap(p)
    local map,x,y=C.MapPoint(p)
    if not map then return end
    if OpenWorldMap then call(OpenWorldMap,map)
    elseif WorldMapFrame then WorldMapFrame:Show();call(WorldMapFrame.SetMapID,WorldMapFrame,map) end
    C.Waypoint(p)
end

-- Death detection uses public readable evidence only. No secure/internal APIs,
-- restricted-value transformations, opponent targeting, or name heuristics.
function C.HostilePlayer(guid,flags)
    if not P.Text(guid) or not guid:match("^Player%-") or not P.Number(flags,0,2147483647) then return false end
    local band=bit and bit.band or bit32 and bit32.band
    return band and band(flags,0x40)~=0 and band(flags,0x400)~=0 or false
end
function C.CombatEvent(...)
    local e={...}
    if not P.Text(e[2]) or not P.Plain(e[8]) then B.killingBlow=nil;return end
    local mine=call(UnitGUID,"player")
    if not P.Text(mine) or e[8]~=mine then return end
    local event=e[2]
    local overkill
    if event=="SWING_DAMAGE" then overkill=e[13]
    elseif event=="SPELL_DAMAGE" or event=="SPELL_PERIODIC_DAMAGE" or event=="RANGE_DAMAGE" or event=="DAMAGE_SHIELD" then overkill=e[16] end
    if not P.Plain(overkill) then B.killingBlow=nil;return end
    if overkill~=nil then
        -- Any later non-player damage invalidates a previous candidate.
        B.killingBlow=nil
        if P.Number(overkill,0,1e12) and C.HostilePlayer(e[4],e[6]) then
            B.killingBlow={at=GetTime(),source=e[4]}
        end
    elseif event=="ENVIRONMENTAL_DAMAGE" then B.killingBlow=nil end
end
function C.ReadCombatEvent()
    if C_CombatLog and call(C_CombatLog.IsCombatLogRestricted)==true then return end
    local fn=C_CombatLog and C_CombatLog.GetCurrentEventInfo or CombatLogGetCurrentEventInfo
    if type(fn)~="function" then return end
    local ok=pcall(function() C.CombatEvent(fn()) end)
    if not ok then B.killingBlow=nil end
end
function C.ConfirmedDeath()
    if B.killingBlow and GetTime()-B.killingBlow.at<=4 then return true end
    -- Some builds return GUID/flags in recaps, others only a caster name.
    -- A name alone cannot distinguish an NPC from a player and is ignored.
    local link=C.RecapKey()
    if not link or link==B.lastLivingRecap then return false end
    local recap=C_DeathRecap and call(C_DeathRecap.GetRecapEvents)
    if type(recap)~="table" or not P.Plain(recap) then return false end
    for _,e in ipairs(recap) do
        if type(e)=="table" and P.Plain(e) and C.HostilePlayer(e.sourceGUID,e.sourceFlags)
            and P.Number(e.overkill,0,1e12) and P.Number(e.timeBeforeDeath,0,.25) then return true end
    end
    return false
end
function C.RecapKey()
    local key=C_DeathRecap and call(C_DeathRecap.GetRecapLink)
    return P.Plain(key) and type(key)=="string" and key~="" and key or nil
end
