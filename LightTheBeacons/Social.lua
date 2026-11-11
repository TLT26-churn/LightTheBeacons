local _,B=...
local P,C=B.Protocol,B.Client

local function playerName(name)
    if not P.Text(name,150) then return end
    name=name:gsub("%s+"," "):match("^%s*(.-)%s*$")
    if not P.Text(name,150) then return end
    return name,P.Identity(name)
end
function B.Filter(owner) return B.db and B.db.playerFilters and B.db.playerFilters[owner] end
function B.IsFriend(owner) local f=B.Filter(owner);return f and f.friend==true or false end
function B.MapVisible(owner) return owner==B.me or not B.db.friendsOnly or B.IsFriend(owner) end
function B.MuteBeacons(enabled)
    B.db.muteBeacons=enabled==true
    if B.db.muteBeacons then
        B.UI.pendingAlert=nil
        if B.UI.banner then B.UI.banner:Hide() end
        if B.UI.answerBanner then B.UI.answerBanner:Hide() end
        if B.UI.deathPrompt then B.UI.deathPrompt:Hide() end
        if B.GrudgeUI and B.GrudgeUI.toast then B.GrudgeUI.toast:Hide() end
        if B.Grudges then B.Grudges.CancelDeathPrompt() end
        if B.DeathUI then B.DeathUI.Dismiss() end
        for handle,expires in pairs(B.soundHandles or {}) do if expires>GetTime() then C.Call(StopSound,handle) end end
        B.soundHandles={}
    end
    B.UI.Refresh()
end
function B.BeaconMode(owner)
    if owner==B.me then return "normal" end
    local f=B.Filter(owner);return f and f.beacons or "normal"
end
function B.SetPlayerFilter(name,mode,hideLocation,friend)
    local clean,key=playerName(name)
    if not key or key==B.me then return false,"Enter another player's full character name." end
    if mode~="normal" and mode~="silent" and mode~="hidden" then return false,"Choose Normal, Silence or Hide." end
    local count=0;for _ in pairs(B.db.playerFilters) do count=count+1 end
    if not B.db.playerFilters[key] and count>=200 then return false,"Remove a filter before adding another (200 maximum)." end
    local old=B.Filter(key)
    if friend==nil then friend=old and old.friend end
    B.db.playerFilters[key]={name=clean,beacons=mode,hideLocation=hideLocation==true,friend=friend==true}
    if mode~="normal" and B.UI.alertBeacon and B.UI.alertBeacon.owner==key then B.UI.banner:Hide() end
    if mode=="hidden" and B.selected==key then B.selected=nil;B.route=nil;B.navigating=false;B.UI.hud:Hide() end
    B.UI.Refresh();B.UI.MapPins()
    return true
end
function B.SetFriend(name,enabled)
    local _,key=playerName(name);local old=key and B.Filter(key)
    return B.SetPlayerFilter(name,old and old.beacons or "normal",old and old.hideLocation or false,enabled==true)
end
function B.RemovePlayerFilter(key)
    B.db.playerFilters[key]=nil;B.UI.Refresh();B.UI.MapPins()
end
function B.InitializeSocial()
    for key,value in pairs({shareLocation=true,showLocations=true,floatingButton=true,muteBeacons=false,friendsOnly=false}) do
        if type(B.db[key])~="boolean" then B.db[key]=value end
    end
    local old=type(B.db.playerFilters)=="table" and B.db.playerFilters or {}
    B.db.playerFilters={};local count=0
    for _,f in pairs(old) do
        if type(f)=="table" and P.Plain(f) then
            local name,key=playerName(f.name)
            if key and key~=B.me and (f.beacons=="normal" or f.beacons=="silent" or f.beacons=="hidden") and count<200 then
                B.db.playerFilters[key]={name=name,beacons=f.beacons,hideLocation=f.hideLocation==true,friend=f.friend==true};count=count+1
            end
        end
    end
    local pos=B.db.buttonPosition
    if type(pos)~="table" or not P.Number(pos.x,0,1) or not P.Number(pos.y,0,1) then B.db.buttonPosition=nil end
    B.locationWithdrawPending=not B.db.shareLocation
end
function B.Locations()
    local list={}
    if not B.db or not B.db.showLocations then return list end
    for key,p in pairs(B.session.locations) do
        local f=B.Filter(key)
        if key~=B.me and B.members[key] and B.MapVisible(key) and not p.hidden and p.expires>C.Now() and not (f and f.hideLocation) then list[#list+1]=p end
    end
    table.sort(list,function(a,b) return a.name<b.name end)
    return list
end
function B.ShareLocation(enabled)
    B.db.shareLocation=enabled==true
    B.locationWithdrawPending=not B.db.shareLocation
    B.lastLocationAttempt=nil
    B.BroadcastLocation()
    B.UI.Refresh()
end
function B.BroadcastLocation()
    if not B.db or not B.session or not IsInGuild or not IsInGuild() then return end
    local now=GetTime();local interval=B.locationWithdrawPending and 2 or 10
    if B.lastLocationAttempt and now-B.lastLocationAttempt<interval then return end
    if not B.db.shareLocation and not B.locationWithdrawPending then return end
    B.lastLocationAttempt=now
    local pos=B.db.shareLocation and C.Location()
    local packet=pos and string.format("1|L|%d|%d|%.5f|%.5f",C.Now(),pos.map,pos.px,pos.py) or "1|H|"..C.Now()
    local ok=C.Send(packet)
    if ok then
        B.locationWithdrawPending=false;B.locationShared=pos and true or false
        B.locationStatus=pos and "Sharing with guild addon users." or B.db.shareLocation and "No readable map position here; location withdrawn." or "Location sharing is off."
    else
        B.locationStatus=B.db.shareLocation and "Waiting for the game to allow location updates." or "Sharing is off. Retrying the withdrawal; old markers expire within 45 seconds."
    end
end
