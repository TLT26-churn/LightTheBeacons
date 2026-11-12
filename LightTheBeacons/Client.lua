local _, B = ...
local C, P = {}, B.Protocol; B.Client=C
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d=pcall(fn,...);if ok then return a,b,c,d end
end
C.Call=call
-- Forever can return nothing for a sound kit even when its native file plays.
-- FileDataIDs address the client assets directly; no recording is bundled.
function C.PlayAlertSound(fileID,kitID)
    local success,handle=call(PlaySoundFile,fileID,"Master")
    if P.Plain(success) and success==true then return true,handle,"file" end
    local play=C_Sound and C_Sound.PlaySound or PlaySound
    success,handle=call(play,kitID)
    if P.Plain(success) and success==true then return true,handle,"kit" end
    return false,nil,"unavailable"
end
function C.AudioSettings()
    local get=C_CVar and C_CVar.GetCVar or GetCVar
    local function value(name)
        local v=call(get,name)
        return P.Plain(v) and (type(v)=="string" or type(v)=="number") and tostring(v) or "unknown"
    end
    return "Sound enabled: "..value("Sound_EnableAllSound").."; master volume: "..value("Sound_MasterVolume")..
        "; SFX enabled: "..value("Sound_EnableSFX").."."
end
-- Read this character's trained riding rank, never their level, temporary
-- movement speed, or the skill's maximum trainable rank. No UI expansion needed.
function C.TrainedTravelPace()
    local info=C_SkillInfo and call(C_SkillInfo.GetSkillLineInfoByID,762)
    if type(info)=="table" and P.Plain(info) and P.Number(info.skillID,762,762)
        and P.Number(info.rank,0,1000) then
        return info.rank>=150 and 14 or info.rank>=75 and 11.2 or 7,true
    end
    -- Some client builds expose training in the spellbook before skill data.
    local readable=false
    local function known(id)
        local value=C_SpellBook and call(C_SpellBook.IsSpellKnown,id)
        if P.Plain(value) and type(value)=="boolean" then readable=true;if value then return true end end
        value=call(IsPlayerSpell,id)
        if P.Plain(value) and type(value)=="boolean" then readable=true;if value then return true end end
        value=call(IsSpellKnown,id)
        if P.Plain(value) and type(value)=="boolean" then readable=true;return value end
        return false
    end
    if known(33391) then return 14,true end -- Journeyman Riding (150)
    if known(33388) then return 11.2,true end -- Apprentice Riding (75)
    return 7,readable
end
function C.Now() return GetServerTime and GetServerTime() or time() end
function C.UnitName(unit)
    local name,surname=call(UnitNameUnmodified or UnitName,unit)
    if not P.Text(name) then return end
    if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
        if P.Text(surname) then
            local sep=Constants and Constants.CharacterNameSeparatorConsts and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
            local tail=sep..surname
            if name:sub(-#tail)~=tail then name=name..tail end
        end
    elseif UnitFullName then
        local first,realm=call(UnitFullName,unit)
        if P.Text(first) then name=first end
        if P.Text(realm) then name=name.."-"..realm end
    end
    return name
end
function C.Me()
    local name=C.UnitName("player")
    return name and P.Identity(name),name
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
function C.Send(msg,prefix)
    if not IsInGuild or not IsInGuild() then return false,"Join a guild to light a beacon." end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return false,"Addon messages are unavailable." end
    if C_ChatInfo.InChatMessagingLockdown and call(C_ChatInfo.InChatMessagingLockdown)==true then
        return false,"The game is restricting addon messages. Try again when combat ends."
    end
    local ok,result=pcall(C_ChatInfo.SendAddonMessage,prefix or P.prefix,msg,"GUILD")
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
    if P.Number(p.map,1,100000) and P.Number(p.px,0,1) and P.Number(p.py,0,1) and (not override or p.map==override) then return p.map,p.px,p.py end
    if not C_Map then return end
    local world=p.c and p or C.World(p.map,p.px,p.py)
    if world and CreateVector2D then
        local map,vec=call(C_Map.GetMapPosFromWorldPos,world.c,CreateVector2D(world.x,world.y),override)
        if P.Number(map,1,100000) and (not override or map==override) and vec and P.Plain(vec)
            and P.Number(vec.x,0,1) and P.Number(vec.y,0,1) then return map,vec.x,vec.y end
    end
    -- Use a common ancestor in the map atlas. The old upward-only fallback
    -- lost continent/world positions when the viewer opened a zone map.
    if not P.Number(p.map,1,100000) or not P.Number(override,1,100000)
        or not P.Number(p.px,0,1) or not P.Number(p.py,0,1) then return end
    local function edge(map)
        local info=call(C_Map.GetMapInfo,map)
        if type(info)~="table" or not P.Plain(info) or not P.Number(info.parentMapID,1,100000) then return end
        -- Floors cannot be projected onto each other through a parent atlas.
        if Enum and Enum.UIMapType and (info.mapType==Enum.UIMapType.Dungeon or info.mapType==Enum.UIMapType.Micro) then return end
        local l,r,t,b=call(C_Map.GetMapRectOnMap,map,info.parentMapID)
        if not P.Number(l,-100,100) or not P.Number(r,-100,100) or not P.Number(t,-100,100)
            or not P.Number(b,-100,100) or l>=r or t>=b then return end
        return info.parentMapID,l,r,t,b
    end
    local source={};local map,x,y=p.map,p.px,p.py
    for _=1,12 do
        if source[map] or not P.Number(x,-100,100) or not P.Number(y,-100,100) then break end
        source[map]={x=x,y=y}
        local parent,l,r,t,b=edge(map);if not parent then break end
        map,x,y=parent,l+x*(r-l),t+y*(b-t)
    end
    local path,seen={},{};map=override
    for _=1,12 do
        if seen[map] then return end;seen[map]=true
        local point=source[map]
        if point then
            x,y=point.x,point.y
            for i=#path,1,-1 do local e=path[i];x,y=(x-e.l)/(e.r-e.l),(y-e.t)/(e.b-e.t) end
            if P.Number(x,0,1) and P.Number(y,0,1) then return override,x,y end
            return
        end
        local parent,l,r,t,b=edge(map);if not parent then return end
        path[#path+1]={l=l,r=r,t=t,b=b};map=parent
    end
end
function C.Location()
    local map=C_Map and call(C_Map.GetBestMapForUnit,"player")
    if not P.Number(map,1,100000) then return end
    local vec=call(C_Map.GetPlayerMapPosition,map,"player")
    if not vec or not P.Plain(vec) or not P.Number(vec.x,0,1) or not P.Number(vec.y,0,1) then return end
    return {map=map,px=vec.x,py=vec.y}
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
    return P.Plain(inInstance) and inInstance==false and P.Plain(kind) and kind=="none"
end
function C.BeaconsAllowed()
    if C.IsOutdoor() then return true end
    local inside,kind=call(IsInInstance)
    return P.Plain(inside) and inside==true and P.Plain(kind) and
        (kind=="party" or kind=="raid") and B.db and B.db.disableInInstances==false or false
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
-- World-map isUndiscovered flags are not reliable on Forever. Only an open
-- flight-master map can confirm that this character has a usable flight point.
local function taxiState(node,states)
    if type(node)~="table" or not P.Plain(node) or not P.Number(node.nodeID,1,100000)
        or not P.Number(node.slotIndex,1,10000) or not P.Plain(node.state)
        or not P.Plain(node.isMapLayerTransition) or node.isMapLayerTransition then return end
    local kind=node.state==states.Current and "CURRENT" or node.state==states.Reachable and "REACHABLE"
    if not kind then return end
    -- When the legacy slot API is present, an explicit disagreement is not
    -- evidence of discovery. Some Forever builds only expose the modern API.
    local slotKind=call(TaxiNodeGetType,node.slotIndex)
    if slotKind~=nil and (not P.Plain(slotKind) or slotKind~=kind) then return end
    return kind
end
local function rememberTaxi(map,node)
    local id=node.nodeID
    B.db.known[id]=true
    local n=B.TravelData.nodes[id]
    if not n and node.position and P.Plain(node.position) and P.Text(node.name) then
        local p=C.World(map,node.position.x,node.position.y)
        if p then
            -- Reachability at this character's flight master proves faction use.
            -- Use the actual taxi map for positions, never a queried zone map.
            n={n=node.name,c=p.c,x=p.x,y=p.y,f=C.Faction()}
            B.TravelData.nodes[id]=n;B.db.nodes[id]=n
        end
    end
    if n and P.Text(node.name) then n.n=node.name end
end
function C.RefreshFlights(feedback)
    local refreshed=C.taxiOpen and C.TaxiOpened() or false
    if feedback then
        B.Print(refreshed and "Confirmed your flight points from this flight master." or
            "Open a flight master's map to confirm your discovered flight points.")
    end
    if B.UI then B.UI.Refresh() end
    return refreshed
end
function C.TaxiClosed()
    C.taxiOpen=false
    -- TakeTaxiNode's post-hook may run after the synchronous close event.
    -- Keep its last slot snapshot for timing only; RefreshFlights is gated above.
end
function C.TaxiOpened()
    C.taxiOpen=true;C.taxiSlots={};C.taxiCurrent=nil
    local map=call(GetTaxiMapID)
    local states=Enum and Enum.FlightPathState
    if not P.Number(map,1,100000) or not C_TaxiMap or not states then return false end
    local nodes=call(C_TaxiMap.GetAllTaxiNodes,map)
    if type(nodes)~="table" or not P.Plain(nodes) then return false end
    local confirmed={}
    for _,node in ipairs(nodes) do
        local kind=taxiState(node,states)
        if kind then
            confirmed[#confirmed+1]=node
            if kind=="CURRENT" then C.taxiCurrent=node.nodeID end
        end
    end
    -- Empty, stale or partial lists with no current flight master prove nothing.
    if not C.taxiCurrent then return false end
    for _,node in ipairs(confirmed) do
        rememberTaxi(map,node);C.taxiSlots[node.slotIndex]=node.nodeID
    end
    B.db.flightMasterScanned=true
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
    if B.Selected() and not B.preview then
        B.Replan();if B.navigating then B.SetNextWaypoint() end
    end
    if B.UI then B.UI.Refresh() end
    return true
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
function C.NonPlayerSource(guid,flags)
    if not P.Text(guid) or not guid:match("^Creature%-") or not P.Number(flags,0,2147483647) then return false end
    local band=bit and bit.band or bit32 and bit32.band
    -- A player-controlled pet is not proof of a PvE death.
    return band and band(flags,0x800)~=0 and band(flags,0x100)==0 or false
end
-- A bounded, session-only list of players who actually damaged this character.
-- Never use nearby names, targets, pets without a readable owner, or restricted data.
function C.ClearAttackers() B.recentAttackers={} end
function C.RememberAttacker(guid,name,flags,amount)
    if not C.HostilePlayer(guid,flags) or not P.Text(name,100) or not P.Number(amount,1,1e12)
        or not B.Grudges.Active() or B.Grudges.options.deathMode=="off" or not C.IsOutdoor() then return end
    local now=GetTime();local recent=B.recentAttackers or {};B.recentAttackers=recent
    local count,oldest=0,nil
    for key,entry in pairs(recent) do
        if now-entry.at>30 then recent[key]=nil
        else count=count+1;if not oldest or entry.at<recent[oldest].at then oldest=key end end
    end
    if not recent[guid] and count>=32 then recent[oldest]=nil end
    recent[guid]={guid=guid,name=name,at=now}
end
function C.CombatEvent(...)
    local e={...}
    if B.Grudges then B.Grudges.Combat(e) end
    if not P.Text(e[2]) or not P.Plain(e[8]) then B.killingBlow=nil;B.nonPlayerDeath=nil;return end
    local mine=call(UnitGUID,"player")
    if not P.Text(mine) or e[8]~=mine then return end
    local event=e[2]
    local overkill
    if event=="SWING_DAMAGE" then overkill=e[13]
    elseif event=="SPELL_DAMAGE" or event=="SPELL_PERIODIC_DAMAGE" or event=="RANGE_DAMAGE" or event=="DAMAGE_SHIELD" then overkill=e[16] end
    if not P.Plain(overkill) then B.killingBlow=nil;B.nonPlayerDeath=nil;return end
    if overkill~=nil then
        if P.Number(overkill,-1,1e12) then C.RememberAttacker(e[4],e[5],e[6],event=="SWING_DAMAGE" and e[12] or e[15]) end
        -- Any later non-player damage invalidates a previous candidate.
        B.killingBlow=nil;B.nonPlayerDeath=nil
        if P.Number(overkill,0,1e12) and C.HostilePlayer(e[4],e[6]) then
            B.killingBlow={at=GetTime(),source=e[4],name=P.Text(e[5],100) and e[5] or nil}
        elseif P.Number(overkill,0,1e12) and C.NonPlayerSource(e[4],e[6]) then
            B.nonPlayerDeath=GetTime()
        end
    elseif event=="ENVIRONMENTAL_DAMAGE" then
        B.killingBlow=nil;B.nonPlayerDeath=P.Number(e[14],0,1e12) and GetTime() or nil
    end
end
function C.ReadCombatEvent()
    if C_CombatLog and call(C_CombatLog.IsCombatLogRestricted)==true then return end
    local fn=C_CombatLog and C_CombatLog.GetCurrentEventInfo or CombatLogGetCurrentEventInfo
    if type(fn)~="function" then return end
    local ok=pcall(function() C.CombatEvent(fn()) end)
    if not ok then B.killingBlow=nil;B.nonPlayerDeath=nil end
end
function C.RecapKey()
    local key=C_DeathRecap and call(C_DeathRecap.GetRecapLink)
    return P.Plain(key) and type(key)=="string" and key~="" and key or nil
end
