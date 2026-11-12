local addon, B = ...
_G.LightTheBeacons=B
local C,P,R=B.Client,B.Protocol,B.Routing
B.version="1.6.3-test.3"
BINDING_HEADER_LIGHT_THE_BEACONS="Light the Beacons"
BINDING_NAME_LTB_TOGGLE="Open Light the Beacons"
BINDING_NAME_LTB_LIGHT="Light my beacon"
function B.Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffc55cLight the Beacons:|r "..message) end
end
function B.Sound(test,answer)
    if not test and (not B.db.sound or B.db.muteBeacons or not C.BeaconsAllowed()) then return end
    local key=answer and "lastAnswerSound" or "lastHorn"
    local cooldown=answer and 5 or B.db.hornCooldown or 30
    if not test and B[key] and GetTime()-B[key]<cooldown then return end
    local success,handle,method=C.PlayAlertSound(answer and 569543 or 566064,answer and 8173 or 10843)
    B.lastSoundResult=success and ("Playback accepted (native "..method..").") or "The game did not start the sound."
    if success then
        B[key]=GetTime()
        B.soundHandles=B.soundHandles or {}
        for old,expires in pairs(B.soundHandles) do if expires<=GetTime() then B.soundHandles[old]=nil end end
        if P.Number(handle,0,2147483647) then B.soundHandles[handle]=GetTime()+60 end
    elseif test or not B.lastSoundError or GetTime()-B.lastSoundError>60 then
        B.lastSoundError=GetTime();B.Print("The game did not start the sound. /ltb sound shows your audio settings.")
    end
    if test then B.Print(B.lastSoundResult.." "..C.AudioSettings()) end
    return success
end
function B.List()
    local list={}
    for _,beacon in pairs(B.session and B.session.beacons or {}) do if B.BeaconMode(beacon.owner)~="hidden" then list[#list+1]=beacon end end
    table.sort(list,function(a,b) if a.sent==b.sent then return a.name<b.name end;return a.sent>b.sent end)
    return list
end
function B.Selected()
    if B.preview then return B.preview end
    return B.selected and B.session and B.BeaconMode(B.selected)~="hidden" and B.session.beacons[B.selected] or nil
end
function B.TravelSpeed()
    return B.db and B.db.travelMode=="foot" and 7 or B.ridingPace or 7
end
function B.UpdateTravelPace()
    local old=B.TravelSpeed()
    B.ridingPace,B.ridingKnown=C.TrainedTravelPace()
    return old~=B.TravelSpeed()
end
function B.TravelLabel()
    if B.db.travelMode=="foot" then return "On foot (override)" end
    if not B.ridingKnown then return "Auto: On foot (unverified)" end
    return "Auto: "..(B.ridingPace==14 and "100% mount" or B.ridingPace==11.2 and "60% mount" or "On foot")
end
function B.ToggleTravelMode()
    B.db.travelMode=B.db.travelMode=="foot" and "auto" or "foot"
    if B.preview then B.Preview() else B.Replan();if B.navigating then B.SetNextWaypoint() end end
    B.UI.Refresh()
end
function B.Destination(b)
    if not b then return end
    local p=b.point or C.World(b.map,b.px,b.py)
    if p then p.n=b.name.."'s beacon" end
    return p
end
function B.Select(b)
    if not b then return end
    B.preview=nil;B.selected=b.owner;B.navigating=false;B.routeIndex=1
    B.Replan();B.UI.Refresh()
end
function B.Replan()
    B.UpdateTravelPace()
    if B.preview then B.route=B.preview.route;return end
    if UnitOnTaxi and UnitOnTaxi("player") then
        B.route={steps={},unavailable=true,pendingFlight=true,reason="Your route will update when you land."}
        B.waitingLanding=true;return
    end
    B.waitingLanding=nil
    local beacon=B.Selected();local group=beacon and B.GroupFor(beacon.owner)
    local start=C.Position();local goal=B.Destination(group and group.leader or beacon)
    B.route=nil
    if start and goal then B.route=R.Plan(start,goal,B.db.known,C.Faction(),B.TravelSpeed(),nil,B.db.times) end
    B.routeIndex=1;B.transportReady=nil
end
function B.Receive(msg,sender,channel)
    if not B.session then return end
    local event,b,sound=P.Receive(B.session,msg,sender,channel,B.members,C.Now())
    if event=="query" then
        B.BroadcastLocation()
        if B.own and B.own.expires>C.Now() and (not B.lastReply or GetTime()-B.lastReply>10) then
            B.lastReply=GetTime()
            local message=P.EncodeMessage(B.own);if message then C.Send(message) end
            C.Send(P.Encode(B.own))
        end
    elseif event=="beacon" then
        if b.owner==B.me then B.own=b;B.db.active=b end
        if not B.Selected() and B.BeaconMode(b.owner)~="hidden" then B.selected=b.owner;B.Replan() end
        local group=B.GroupFor(b.owner)
        local joined=group and #group.callers>1
        if sound and not joined and B.BeaconMode(b.owner)=="normal" and C.BeaconsAllowed() then
            B.Sound();if b.owner~=B.me then B.UI.Alert(b) end
        end
        B.UI.RefreshAlertGroup()
        B.UI.Refresh()
    elseif event=="location" then
        B.UI.MapPins()
    elseif event=="message" then
        B.UI.RefreshAlertGroup();B.UI.Refresh()
    elseif event=="cancel" then
        if B.selected==b.owner then B.selected=nil;B.navigating=false;B.route=nil end
        B.UI.RefreshAlertGroup()
        if B.UI.answerBanner and B.UI.answerBanner.beacon==b then B.UI.answerBanner:Hide() end
        B.UI.Refresh()
    elseif event=="response" then
        if b.owner==B.me then
            local count=0;for _ in pairs(b.responders) do count=count+1 end
            local first=B.db.answeredBeaconID~=b.id
            B.db.answeredBeaconID=b.id
            if first then B.Sound(false,true) end
            B.UI.Answered(sender,count,first,b)
        end
        B.UI.Refresh()
    end
end
function B.RequestLight(reason)
    if B.db then B.UI.Compose(reason) end
end
function B.SaveTemplate(slot,message)
    if not B.db or not P.Number(slot,1,3) or slot%1~=0 then return false end
    local clean=P.Message(message)
    B.db.messages[slot]=clean~="" and clean or nil
    return true
end
function B.Light(reason,message)
    if not B.db then return end
    if not C.BeaconsAllowed() then B.Print("Beacons are disabled here. Dungeon/raid use can be enabled in Beacon settings; battlegrounds and arenas stay disabled.");return false end
    if not B.me then B.Print("Your character is still loading.");return false end
    local now=C.Now()
    if B.db.lastSent and now-B.db.lastSent<P.cooldown then
        B.Print("Your horn is resting. Try again in "..math.max(1,P.cooldown-(now-B.db.lastSent)).." seconds.");return false
    end
    local dead=(UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) or false
    local pos=dead and C.Corpse() or C.Position()
    if not pos then B.Print(dead and "Your corpse location is unavailable. Try again after returning to your body." or "Your location is unavailable here.");return false end
    B.sequence=(B.sequence or 0)+1
    local b={id=now.."."..B.nonce.."."..B.sequence,sent=now,expires=now+P.ttl,
        map=pos.map,px=pos.px,py=pos.py,reason=reason or (dead and "fallen" or "aid")}
    b.message=P.Message(message)
    if b.message=="" then b.message=nil end
    local note=P.EncodeMessage(b)
    -- Send the optional note first so the receiving toast can include it.
    if note then
        local ok,why=C.Send(note)
        if not ok then B.Print(why);return false end
    end
    local packet=P.Encode(b)
    local ok,why=C.Send(packet)
    if not ok then B.Print(why);return false end
    B.preview=nil;B.db.lastSent=now
    B.members[B.me]=true
    if note then B.Receive(note,B.name,"GUILD") end
    B.Receive(packet,B.name,"GUILD")
    B.selected=B.me;B.navigating=false;B.Replan()
    if B.UI.composer and B.UI.composer:IsShown() then B.UI.options=false;B.UI.settingsPage=nil;B.UI.frame:Show() end
    B.UI.Refresh()
    B.DeathUI.BeaconSent()
    if B.UI.composer then B.UI.composer:Hide() end
    return true
end
function B.Extinguish()
    if not B.own or B.own.expires<=C.Now() then return end
    local ok,why=C.Send("1|C|"..B.own.id)
    if not ok then B.Print(why);return end
    B.Receive("1|C|"..B.own.id,B.name,"GUILD")
    B.own=nil;B.db.active=nil;B.UI.confirmedClearUntil=GetTime()+6;B.UI.Refresh()
end
function B.Answer()
    local b=B.Selected()
    if not b then return end
    if B.preview then B.Print("This is a local preview. No call has been sent.");return end
    if not C.BeaconsAllowed() then B.Print("Beacons are disabled in this instance.");return end
    local group=B.GroupFor(b.owner)
    if b.owner==B.me or group and group.owners[B.me] then
        B.navigating=false;B.UI.Tick()
        B.Print("This is your beacon. Your guildmates can answer the call.");return
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        B.Print("Return to life before following a rescue route. You can still view the beacon on your map.");return
    end
    if B.QueueGroupAnswers(group or {callers={b}})==false then return end
    B.Replan();B.navigating=true;B.routeIndex=1
    B.SetNextWaypoint();B.UI.Refresh()
end
function B.NextTarget()
    local step=B.route and B.route.steps and B.route.steps[B.routeIndex or 1]
    if not step then return end
    local pos=C.Position()
    if step.kind=="flight" and not (UnitOnTaxi and UnitOnTaxi("player")) then return step.from,step end
    if step.kind=="boat" or step.kind=="zeppelin" then
        if R.Distance(pos,step.from)<=100 then B.transportReady=B.routeIndex end
        if B.transportReady~=B.routeIndex and pos and pos.c==step.from.c then return step.from,step end
    end
    return step.to,step
end
function B.SetNextWaypoint()
    local p=B.NextTarget();if p then C.Waypoint(p) end
end
function B.TickRoute()
    if not C.BeaconsAllowed() then B.navigating=false;return end
    if B.waitingLanding and not (UnitOnTaxi and UnitOnTaxi("player")) then
        B.Replan();if B.navigating then B.SetNextWaypoint() end
    end
    if not B.navigating or not B.route or B.route.unavailable then return end
    local step=B.route.steps[B.routeIndex or 1]
    if not step then return end
    if UnitOnTaxi and UnitOnTaxi("player") then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    local distance=R.Distance(C.Position(),step.to)
    if distance<(step.kind=="ground" and 65 or 140) then
        B.routeIndex=B.routeIndex+1;B.SetNextWaypoint();B.UI.Refresh()
    end
end
function B.Death(restored)
    if B.deathActive or not C.IsOutdoor() then return end
    C.BeginDeathEvidence()
    B.deathActive=true;B.DeathUI.Reset();B.DeathUI.active=true;B.DeathUI.where=B.Grudges.Place()
    B.deathPoint=C.Position() or B.lastLivingPoint
    B.Grudges.OnDeath()
    B.deathSerial=(B.deathSerial or 0)+1;local serial=B.deathSerial
    local function decide()
        local dead=C.Call(UnitIsDeadOrGhost,"player")
        if serial~=B.deathSerial or not C.IsOutdoor() or not P.Plain(dead) or dead~=true then return end
        if B.DeathUI.dismissed then return end
        local confirmed=C.ConfirmedDeath();B.lastDeathConfirmed=confirmed;B.DeathUI.confirmed=confirmed
        if not C.DeathHasPvP(confirmed) then return end
        if B.db.auto and not restored and confirmed and not B.deathBeaconSent and not B.own and not B.DeathUI.suspended then
            if B.Light("pvp") then B.deathBeaconSent=true;return end
        end
        if B.db.prompt and IsInGuild and IsInGuild() then B.UI.PromptDeath(confirmed) end
    end
    B.deathBeaconSent=nil
    if C_Timer then
        C_Timer.After(.6,decide);C_Timer.After(1.8,decide);C_Timer.After(3.2,decide);C_Timer.After(5.5,decide)
    else decide() end
end
function B.Preview()
    B.UI.options=false;B.UI.settingsPage=nil
    B.UpdateTravelPace()
    local data=B.TravelData
    local start={c=0,x=-8900,y=600,n="Your position"}
    local goal={c=0,x=-9510,y=-2640,n="Aldric's beacon"}
    B.preview={name="Aldric",owner="preview",id="preview",sent=C.Now()-12,expires=C.Now()+288,
        map=1433,px=.34,py=.52,reason="pvp",point=goal,responders={other="Elowen"},message="Horde at the crossroads. Rally to me!"}
    B.preview.route=R.Plan(start,goal,{[2]=true,[4]=true,[5]=true,[12]=true},"A",B.TravelSpeed(),data)
    B.route=B.preview.route;B.routeIndex=1;B.navigating=false
    B.UI.frame:Show();B.UI.Alert(B.preview,true);B.UI.Refresh()
end
function B.RestoreOwn()
    if B.own or not B.me or not B.guild or B.guild=="" or B.db.guild~=B.guild then return end
    local active=B.db.active
    -- Do not retain an expired or invalid incident, note, or responder list
    -- across logins. A valid unexpired beacon is restored below.
    B.db.active=nil
    if type(active)=="table" and P.Text(active.id,40) and P.Number(active.sent,C.Now()-P.ttl,C.Now())
        and P.Number(active.map,1,100000) and P.Number(active.px,0,1) and P.Number(active.py,0,1)
        and (active.reason=="aid" or active.reason=="pvp" or active.reason=="fallen") then
        local parsed=P.Parse(P.Encode(active),C.Now())
        if parsed and B.me then
            parsed.owner=B.me;parsed.name=B.name;parsed.responders={};B.own=parsed
            local message=P.Message(active.message);if message~="" then parsed.message=message end
            if type(active.responders)=="table" then for key,name in pairs(active.responders) do
                if P.Identity(name)==key and key~=B.me and B.members[key] then parsed.responders[key]=name end
            end end
            if next(parsed.responders) then B.db.answeredBeaconID=parsed.id end
            B.db.active=parsed
            B.session.beacons[B.me]=parsed;B.session.heard[B.me..":"..parsed.id]=C.Now()
        end
    end
end
function B.GuildChanged()
    B.me,B.name=C.Me()
    local inGuild=IsInGuild and IsInGuild()
    local guild
    if inGuild then guild=(C_Club and C.Call(C_Club.GetGuildClubId)) or C.Call(GetGuildInfo,"player") else guild="" end
    if not P.Plain(guild) then guild=nil end
    if (not guild or guild=="") and IsInGuild and IsInGuild() then B.guildPending=true;B.members=C.Members();return end
    B.guildPending=false
    guild=tostring(guild or "")
    if B.guild and B.guild~=guild then
        B.lastLocationAttempt=nil;B.locationShared=false;B.locationStatus=nil
        B.session=P.NewSession();B.selected=nil;B.navigating=false;B.own=nil;B.db.active=nil;B.route=nil
        B.displayGroup=nil;B.answerQueue=nil;B.UI.pendingAlert=nil;B.UI.alertGroup=nil;B.UI.alertBeacon=nil
        if B.UI.banner then B.UI.banner:Hide() end
        if B.UI.answerBanner then B.UI.answerBanner:Hide() end
    end
    B.guild=guild;B.members=C.Members()
    if B.db.guild~=guild then B.db.active=nil;B.db.guild=guild end
    B.RestoreOwn()
    B.Grudges.GuildChanged()
end
function B.Initialize()
    if B.db then return end
    LightTheBeaconsDB=type(LightTheBeaconsDB)=="table" and LightTheBeaconsDB or {}
    B.db=LightTheBeaconsDB
    local savedMessages=type(B.db.messages)=="table" and B.db.messages or {}
    B.db.messages={}
    for slot=1,3 do B.SaveTemplate(slot,savedMessages[slot]) end
    for _,key in ipairs({"known","times","nodes","links"}) do if type(B.db[key])~="table" then B.db[key]={} end end
    if B.db.flightDiscoveryVersion~=2 then
        -- Versions 1.0.0/1.0.1 trusted Forever's unreliable world-map discovery
        -- flags and map-relative coordinates. Retain options, calls and timings.
        B.db.known={};B.db.nodes={};B.db.flightMasterScanned=nil
        B.db.flightDiscoveryVersion=2
    end
    for id,n in pairs(B.db.nodes) do
        if P.Number(id,1,100000) and type(n)=="table" and P.Text(n.n) and P.Number(n.c,0,100000)
            and P.Number(n.x,-100000,100000) and P.Number(n.y,-100000,100000) and (n.f=="A" or n.f=="H" or n.f=="AH") then
            B.TravelData.nodes[id]=n
        end
    end
    for from,row in pairs(B.db.links) do
        if B.TravelData.nodes[from] and type(row)=="table" then for to,seconds in pairs(row) do
            if B.TravelData.nodes[to] and P.Number(seconds,1,3600) then
                B.TravelData.flights[from]=B.TravelData.flights[from] or {};B.TravelData.flights[from][to]=seconds
            end
        end end
    end
    for key,value in pairs({sound=true,auto=false,prompt=true,pace=7}) do
        if type(B.db[key])~=type(value) then B.db[key]=value end
    end
    if B.db.pace~=7 and B.db.pace~=11.2 and B.db.pace~=14 then B.db.pace=7 end
    -- Existing manual speed is retained in saves, but automatic training
    -- detection is the default from 1.0.3 onward.
    if B.db.travelMode~="foot" then B.db.travelMode="auto" end
    B.UpdateTravelPace()
    if not P.Number(B.db.lastSent,0,C.Now()) then B.db.lastSent=nil end
    B.session=P.NewSession();B.nonce=math.random(100000,999999)
    C.CaptureLivingRecap()
    B.me,B.name=C.Me();B.GuildChanged();B.InitializeSocial();B.Grudges.Initialize()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C.Call(C_ChatInfo.RegisterAddonMessagePrefix,P.prefix)
        C.Call(C_ChatInfo.RegisterAddonMessagePrefix,B.Grudges.prefix)
    end
    B.UI.Create()
    C.RefreshFlights()
    if hooksecurefunc and TakeTaxiNode then hooksecurefunc("TakeTaxiNode",C.TaxiTaken) end
    if C_Timer then
        C_Timer.After(.3,function()
            -- Reloading while dead may recover the review UI, never an auto-call
            -- based on the recap that was already present at login.
            local dead=C.Call(UnitIsDeadOrGhost,"player")
            if P.Plain(dead) and dead==true then B.Death(true) end
        end)
        C_Timer.After(4,function() B.members=C.Members();if IsInGuild and IsInGuild() then C.Send("1|Q");B.BroadcastLocation() end end)
    end
    B.UI.Refresh()
end
local frame=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED","CHAT_MSG_ADDON","GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE",
    "CLUB_MEMBER_UPDATED","CLUB_MEMBER_ADDED","CLUB_MEMBER_REMOVED","PLAYER_ENTERING_WORLD","TAXIMAP_OPENED","TAXIMAP_CLOSED",
    "TAXI_NODE_STATUS_CHANGED","PLAYER_DEAD","PLAYER_UNGHOST","PLAYER_ALIVE","PLAYER_REGEN_ENABLED","ZONE_CHANGED_NEW_AREA"}) do frame:RegisterEvent(event) end
-- Restricted combat-log registration is optional; failure never blocks loading.
if type(CombatLogGetCurrentEventInfo)=="function" or (C_CombatLog and type(C_CombatLog.GetCurrentEventInfo)=="function") then
    pcall(frame.RegisterEvent,frame,"COMBAT_LOG_EVENT_UNFILTERED")
end
-- Optional registrations cannot prevent the slash command from loading on a
-- client build that renames a skill/spell event.
for _,event in ipairs({"SKILL_LINES_CHANGED","SPELLS_CHANGED","PLAYER_TARGET_CHANGED","UPDATE_MOUSEOVER_UNIT"}) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then if ...==addon and IsLoggedIn and IsLoggedIn() then B.Initialize() end;return end
    if event=="PLAYER_LOGIN" then B.Initialize();return end
    if not B.db then return end
    if event=="CHAT_MSG_ADDON" then
        local prefix,msg,channel,sender=...
        if P.Plain(prefix) and prefix==P.prefix and P.Plain(channel) and channel=="GUILD" then B.Receive(msg,sender,channel) end
        if P.Plain(prefix) and prefix==B.Grudges.prefix and P.Plain(channel) and channel=="GUILD" then B.Grudges.Receive(msg,sender,channel) end
    elseif event=="COMBAT_LOG_EVENT_UNFILTERED" then C.ReadCombatEvent()
    elseif event=="PLAYER_DEAD" then B.Death()
    elseif event=="PLAYER_TARGET_CHANGED" then B.Grudges.ObserveUnit("target")
    elseif event=="UPDATE_MOUSEOVER_UNIT" then B.Grudges.ObserveUnit("mouseover")
    elseif event=="TAXIMAP_OPENED" then C.TaxiOpened()
    elseif event=="TAXIMAP_CLOSED" then C.TaxiClosed()
    elseif event=="TAXI_NODE_STATUS_CHANGED" then C.RefreshFlights()
    elseif event=="SKILL_LINES_CHANGED" or event=="SPELLS_CHANGED" then
        if B.UpdateTravelPace() then
            if B.preview then B.Preview() else B.Replan();if B.navigating then B.SetNextWaypoint() end end
        end
        B.UI.Refresh()
    elseif event=="PLAYER_ENTERING_WORLD" then
        C.RefreshFlights();B.GuildChanged()
        B.UI.EnforceBeaconContext()
        if not C.IsOutdoor() then C.ClearAttackers();B.DeathUI.Dismiss() end
        if B.UpdateTravelPace() then B.Replan();if B.navigating then B.SetNextWaypoint() end end
        B.UI.Refresh()
    elseif event=="PLAYER_UNGHOST" or event=="PLAYER_ALIVE" then
        if not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
            B.deathPoint=nil;B.killingBlow=nil;B.nonPlayerDeath=nil;B.deathActive=nil;B.deathEvidence=nil;B.deathSerial=(B.deathSerial or 0)+1
            C.CaptureLivingRecap()
            C.ClearAttackers();B.DeathUI.Reset()
            B.Grudges.deathSerial=(B.Grudges.deathSerial or 0)+1
            B.Grudges.deathActive=nil
            B.Grudges.CancelDeathPrompt()
            if B.UI.deathPrompt then B.UI.deathPrompt:Hide() end
        end
    elseif event=="ZONE_CHANGED_NEW_AREA" then
        B.UI.EnforceBeaconContext()
        if not C.IsOutdoor() then C.ClearAttackers();B.DeathUI.Dismiss() end
        if not B.navigating then B.Replan() end
    elseif event~="PLAYER_REGEN_ENABLED" then B.GuildChanged() end
end)
local elapsed=0
frame:SetScript("OnUpdate",function(_,delta)
    if not B.db then return end
    B.DeathUI.Tick(delta)
    B.Grudges.Tick()
    elapsed=elapsed+delta;if elapsed<1 then return end;elapsed=0
    local now=C.Now();P.Prune(B.session,now)
    if B.own and B.own.expires<=now then B.own=nil;B.db.active=nil end
    if B.selected and not B.Selected() then B.selected=nil;B.route=nil;B.navigating=false end
    if not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
        B.lastLivingPoint=C.Position()
        C.CaptureLivingRecap()
    end
    C.ObserveFlight();B.TickAnswers();B.TickRoute();B.BroadcastLocation();B.UI.Tick();B.GrudgeUI.Tick()
end)
SLASH_LIGHTTHEBEACONS1="/ltb";SLASH_LIGHTTHEBEACONS2="/beacons"
SlashCmdList.LIGHTTHEBEACONS=function(input)
    local command=(input or ""):lower():match("^%s*(%S*)")
    if command=="light" then B.RequestLight()
    elseif command=="clear" then B.Extinguish()
    elseif command=="sound" then B.Print((B.lastSoundResult or "No alert played this session.").." "..C.AudioSettings())
    elseif command=="settings" then B.UI.OpenSettingsPage("beacons")
    elseif command=="scan" then C.RefreshFlights(true)
    elseif command=="options" then B.UI.Toggle(true)
    elseif command=="locations" then B.UI.OpenSettingsPage("controls")
    elseif command=="filters" then B.UI.OpenSettingsPage("filters")
    elseif command=="button" then B.db.floatingButton=not B.db.floatingButton;B.UI.Refresh()
    elseif command=="grudges" or command=="book" then B.GrudgeUI.Toggle()
    elseif command=="deathdock" then
        B.db.deathDock=B.db.deathDock==false;B.DeathUI.Refresh()
        B.Print("Dock guild actions below the death window: "..(B.db.deathDock and "on" or "off")..". Blizzard's controls are unchanged.")
    elseif command=="deathstatus" then
        B.Print("LTB "..B.version.."; death panel: "..(B.DeathUI.dockStatus or "inactive")..".")
        B.Print("This death has hostile-player evidence: "..(B.deathEvidence and B.deathEvidence.pvp and "yes" or "no")..".")
        B.Print("Recap: "..(B.recapReadStatus or "not read this session").."; "..
            #(B.Grudges.pendingDeath and B.Grudges.pendingDeath.attackers or {}).." detected attackers. No names in this diagnostic.")
        local restricted=C_CombatLog and C.Call(C_CombatLog.IsCombatLogRestricted)
        B.Print("Combat log restricted: "..(P.Plain(restricted) and type(restricted)=="boolean" and tostring(restricted) or "unknown")..
            "; outdoor death actions: "..(C.IsOutdoor() and "available" or "disabled")..".")
    elseif command=="status" then
        B.UpdateTravelPace();B.Print("Travel pace: "..B.TravelLabel()..".")
        B.Print(C.KnownCount().." confirmed flight points. Automatic PvP: "..(B.db.auto and "on, confirmed kills only" or "off")..".")
        if not B.db.flightMasterScanned then B.Print("Open a flight master's map to confirm your discovered flight points.") end
        B.Print("Public combat reader: "..((CombatLogGetCurrentEventInfo or (C_CombatLog and C_CombatLog.GetCurrentEventInfo)) and "available" or "unavailable; using readable death recaps when supplied")..".")
    else B.UI.Toggle() end
end
B.eventFrame=frame
