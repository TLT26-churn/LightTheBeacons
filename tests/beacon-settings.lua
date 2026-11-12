local client,check=...
local function fresh(saved) return client("Elowen","Dawnwatch",saved) end
local sequence=0
local function add(c,name,x,age,map)
    sequence=sequence+1
    local p=c.B.Protocol;local key=p.Identity(name);c.B.members[key]=true
    local b={id="sample."..sequence,sent=c.s.time-(age or 0),map=map or 1429,px=x,py=.45,reason="aid"}
    c.B.Receive(p.Encode(b),name,"GUILD")
    return c.B.session.beacons[key],p.Encode(b)
end
local function cancel(c,b) c.B.Receive("1|C|"..b.id,b.name,"GUILD") end
local function mapFrame(c,id)
    local e=c.env;local map=e.CreateFrame("Frame","WorldMapFrame",e.UIParent);e.WorldMapFrame=map
    map.current=id;map.canvas=e.CreateFrame("Frame",nil,map);map.canvas:SetSize(900,600)
    map.GetCanvas=function(self) return self.canvas end
    map.GetMapID=function(self) return self.current end
    map.SetMapID=function(self,id) self.current=id end
    return map
end
local function visible(pins)
    local count=0;for _,pin in ipairs(pins or {}) do if pin:IsShown() then count=count+1 end end;return count
end

do
    local c=fresh();local b,u=c.B,c.B.UI
    check(b.db.combineBeacons and b.db.mergeDistance==100 and b.db.hornCooldown==30 and b.db.mapIconScale==75,
        "New defaults combine within 100 yards, wait 30 sec between horns and shrink map icons to 75%")
    check(b.db.disableInInstances and b.db.beaconPopups,"Instance suppression and normal popups default on")
    u.OpenSettingsPage("beacons")
    check(u.beaconSettings:IsShown() and u.frame:GetHeight()==638,"Beacon settings fit the options window")
    u.mergeRange:SetValue(150);u.hornCooldown:SetValue(45);u.markerSize:SetValue(110)
    u.combine:SetChecked(false);u.combine.scripts.OnClick(u.combine)
    u.instances:SetChecked(false);u.instances.scripts.OnClick(u.instances)
    u.popups:SetChecked(false);u.popups.scripts.OnClick(u.popups)
    local reloaded=fresh(b.db).B.db
    check(not reloaded.combineBeacons and reloaded.mergeDistance==150 and reloaded.hornCooldown==45 and reloaded.mapIconScale==110
        and not reloaded.disableInInstances and not reloaded.beaconPopups,"Every new player preference survives reload")
    local bad=fresh({mergeDistance=0/0,hornCooldown=-1,mapIconScale=999,combineBeacons="yes",disableInInstances=3})
    check(bad.B.db.mergeDistance==100 and bad.B.db.hornCooldown==30 and bad.B.db.mapIconScale==75
        and bad.B.db.combineBeacons and bad.B.db.disableInInstances,"Invalid saved preferences restore safe defaults")
    for _,cmd in ipairs({"horn","rally","preview"}) do c.env.SlashCmdList.LIGHTTHEBEACONS(cmd) end
    check(#c.s.sounds==0 and not b.preview and not u.answerBanner:IsShown(),"Removed test commands cannot trigger audio or previews")
    local clean=true
    for _,o in ipairs(c.objects) do if o.text=="Test horn" or o.text=="Preview the rally" or o.text=="Preview a call" then clean=false end end
    check(clean,"No test feature remains in player-facing options")
end

-- Distinct incidents share a sound cooldown, never a visibility cooldown.
do
    local c=fresh();local u=c.B.UI
    add(c,"Scout First",.1);check(#c.s.sounds==1 and u.banner:IsShown(),"First call sounds and appears immediately")
    c.advance(10);local second=add(c,"Scout Second",.4)
    check(#c.s.sounds==1 and u.alertBeacon==second and #c.B.Groups()==2,"A separate call inside 30 sec still appears, silently")
    c.advance(19);add(c,"Scout Third",.7);check(#c.s.sounds==1,"Suppressed horns do not reset or bypass the cooldown")
    c.advance(1);add(c,"Scout Fourth",.9);check(#c.s.sounds==2,"Horn becomes available exactly 30 sec after the last played horn")
    c.B.db.hornCooldown=0;add(c,"Scout Fifth",.2);check(#c.s.sounds==3,"Zero horn cooldown allows each separate incident")
    c.B.db.sound=false;add(c,"Scout Sixth",.3);check(#c.s.sounds==3 and u.banner:IsShown(),"Sound off still permits visible calls")
    c.B.db.sound=true;c.B.db.beaconPopups=false;u.banner:Hide();add(c,"Scout Seventh",.5)
    check(#c.s.sounds==4 and not u.banner:IsShown() and #c.B.List()==7,"Popup preference is independent of sound and call visibility")
end

-- Joins remain quiet even after the horn cooldown and after popup dismissal.
local preview=fresh()
do
    local c=preview;local b,u=c.B,c.B.UI
    local first=add(c,"Scout Ironward",.1);u.banner.elapsed=4
    c.advance(31);local second=add(c,"Scout Dawnwatch",.11)
    check(#b.List()==2 and #b.Groups()==1 and #b.Groups()[1].callers==2,"Nearby calls share one display group while retaining individual protocol records")
    check(#c.s.sounds==1 and u.banner.elapsed==4 and u.alertName:GetText():find("2 guildmates"),"Joining updates a live popup without a new horn or animation")
    check(u.destination:GetText()=="2 allies need aid" and not u.pager:IsShown(),"Combined calls use one compact card")
    second.message="Enemies at the bridge. Bring a healer."
    u.expanded=true;u.frame:Show();u.Refresh()
    check(u.callerScroll:IsShown() and u.callerRows[2]:GetText():find("Bring a healer"),"Expanded group details retain individual messages")
    u.banner:Hide();c.advance(31);local third=add(c,"Scout Stormwatch",.12)
    check(#c.s.sounds==1 and not u.banner:IsShown(),"A later join cannot reopen a dismissed popup or play a horn")
    local world=mapFrame(c,1429);u.MapPins()
    check(visible(u.pins)==1 and u.pins[1].count:GetText()=="3","One shared brazier displays the caller count")
    local originalGoal=b.Destination(b.Groups()[1].leader)
    check(b.Groups()[1].leader==first and originalGoal.px==.1,"New joins do not move the group's oldest destination")
    cancel(c,first)
    check(#b.Groups()==1 and #b.Groups()[1].callers==2 and b.Selected() and b.Selected().owner==second.owner,
        "Leader cancellation retains the other callers and selection")
    check(#c.s.sounds==1 and not u.banner:IsShown(),"Leader cancellation cannot replay an alert")
    b.SetPlayerFilter(third.name,"hidden",false);u.MapPins()
    check(#b.Groups()[1].callers==1 and u.pins[1].count:GetText()=="","Hidden callers disappear from group counts and pins")
    b.RemovePlayerFilter(third.owner);b.SetFriend(third.name,true);b.db.friendsOnly=true;u.MapPins()
    check(#u.pins[1].group.callers==1 and u.pins[1].beacon==third,"Friends-only markers never disclose a filtered group member")
    b.db.friendsOnly=false;second.expires=c.s.time; b.Protocol.Prune(b.session,c.s.time);u.Refresh();u.MapPins()
    check(#b.Groups()==1 and b.Groups()[1].leader==third,"Individual expiry preserves the remaining beacon")
    b.db.combineBeacons=false;add(c,"Scout Farwatch",.115)
    check(#b.Groups()==2,"Disabling combining keeps nearby calls separate")
end

do
    local c=fresh();local a=add(c,"Scout A",.1);add(c,"Scout B",.12);add(c,"Scout C",.14)
    check(#c.B.Groups()==2,"A chain of nearby callers cannot merge fights more than the range apart")
    local edge=fresh();add(edge,"Scout A",.1);add(edge,"Scout B",.125)
    check(#edge.B.Groups()==1,"Exactly 100 yards is inside the default merge range")
    edge.B.UI.mergeRange:SetValue(75);check(#edge.B.Groups()==2,"Changing range immediately separates a group beyond the new limit")
    local reverse=fresh();add(reverse,"Scout B",.12,0);local old=add(reverse,"Scout A",.1,10)
    check(reverse.B.Groups()[1].leader==old and #reverse.s.sounds==1,"Out-of-order older calls join quietly with a deterministic representative")
    local steps=reverse.B.route.steps
    check(steps[#steps].to.px==old.px,"The route updates to the same group destination as the map marker")
    local missing=fresh();missing.env.C_Map.GetWorldPosFromMapPos=nil;add(missing,"Scout A",.1);add(missing,"Scout B",.1)
    check(#missing.B.Groups()==2,"Unavailable world distances cannot merge guessed locations")
    local continents=fresh();add(continents,"Scout A",.1);add(continents,"Scout B",.1,0,1446)
    check(#continents.B.Groups()==2,"Calls on different continents stay separate")
    local floor=fresh();floor.env.Enum.UIMapType={Dungeon=4,Micro=5}
    local info=floor.env.C_Map.GetMapInfo
    floor.env.C_Map.GetMapInfo=function(id) local m=info(id);if m then m.mapType=4 end;return m end
    add(floor,"Scout A",.1);add(floor,"Scout B",.1)
    check(#floor.B.Groups()==2,"Dungeon maps cannot merge calls from potentially different instance copies")
    local expired=fresh();local gone=add(expired,"Scout A",.1);gone.expires=expired.s.time
    add(expired,"Scout B",.11)
    check(#expired.B.Groups()==1 and #expired.B.Groups()[1].callers==1 and expired.B.UI.banner:IsShown(),"Expired callers cannot swallow a new incident as a quiet join")
    local duplicate=fresh();local _,packet=add(duplicate,"Scout A",.1);duplicate.B.UI.banner:Hide();duplicate.advance(31)
    duplicate.B.Receive(packet,"Scout A","GUILD")
    check(#duplicate.s.sounds==1 and not duplicate.B.UI.banner:IsShown(),"Duplicate packets cannot bypass the horn cooldown or reopen notifications")
end

do
    local c=fresh();local first=add(c,"Scout Ironward",.1);local sounds=#c.s.sounds
    c.B.Light()
    check(#c.s.sounds==sounds and #c.B.Groups()==1 and not c.B.UI.banner:IsShown(),"Lighting your own nearby beacon joins silently and dismisses the incoming toast")
    check(c.B.Selected()==c.B.own and c.B.UI.answer.label:GetText()=="Extinguish My Beacon","A group containing you always exposes your own extinguish action")
    local sent=#c.s.sent;c.B.Answer()
    check(#c.s.sent==sent and not c.B.navigating,"Group membership cannot bypass the self-answer guard")
    c.B.Extinguish()
    check(not c.B.own and c.B.session.beacons[first.owner]==first and #c.B.Groups()==1,"Extinguishing only removes your own contribution")
    local failed=fresh();add(failed,"Scout Ironward",.1);failed.s.sendResult=5;failed.B.Answer()
    check(not failed.B.navigating and not failed.B.answerQueue,"Failed acknowledgement does not start guidance or claim success")
    local queued=fresh();queued.B.UI.Answered("Example Ally",1,true,nil)
    add(queued,"Scout Ironward",.1);queued.B.Light();queued.B.UI.answerBanner:Hide()
    check(not queued.B.UI.banner:IsShown() and not queued.B.UI.pendingAlert,"Joining your own queued group cannot reopen an own-call popup after a celebration")
end

-- Each caller receives a backwards-compatible response, paced for old clients.
do
    local c=fresh();for i=1,20 do add(c,"Scout "..string.format("%02d",i),.1+i*.0001) end
    c.B.Answer();local count=0
    for _=1,20 do c.advance(2);c.B.TickAnswers() end
    for _,b in pairs(c.B.session.beacons) do if b.responders[c.B.me] then count=count+1 end end
    check(count==20 and #c.B.answerQueue==0,"Answering a combined call acknowledges every active caller without exceeding the receive budget")
    local before=#c.s.sent;c.B.Answer();check(#c.s.sent==before,"Resuming a combined route never duplicates acknowledgements")
    check(c.B.UI.summary:GetText():find("1 ally"),"The same responder is counted once across the group")
    local cancelQueue=fresh();add(cancelQueue,"Scout A",.1);local other=add(cancelQueue,"Scout B",.11)
    cancelQueue.B.Answer();cancel(cancelQueue,other);cancelQueue.advance(2);local n=#cancelQueue.s.sent;cancelQueue.B.TickAnswers()
    check(#cancelQueue.s.sent==n,"Cancelled calls are discarded before queued acknowledgements are sent")
end

for _,kind in ipairs({"party","raid","pvp","arena","scenario"}) do
    local c=fresh();c.env.IsInInstance=function() return true,kind end
    local b=add(c,"Scout Ironward",.1)
    check(b and #c.s.sounds==0 and not c.B.UI.banner:IsShown() and not c.B.Light(),"Instance default stores quiet calls but blocks lighting in "..kind)
    c.B.Select(b);c.B.Answer();check(not c.B.navigating,"Default instance setting blocks route guidance in "..kind)
    c.B.db.disableInInstances=false
    local allowed=kind=="party" or kind=="raid"
    check(c.B.Client.BeaconsAllowed()==allowed,"Only party/raid beacons may be enabled explicitly: "..kind)
    add(c,"Scout Farwatch",.5)
    check((#c.s.sounds==1)==allowed and c.B.UI.banner:IsShown()==allowed,"Incoming sound/popup follows instance preference in "..kind)
end
do
    local c=fresh();add(c,"Scout Ironward",.1);c.B.Answer();c.B.UI.Answered("Example Ally",1,true,nil)
    c.env.IsInInstance=function() return true,"party" end
    c.B.eventFrame.scripts.OnEvent(c.B.eventFrame,"ZONE_CHANGED_NEW_AREA")
    check(not c.B.UI.banner:IsShown() and not c.B.UI.answerBanner:IsShown() and not c.B.UI.pendingAlert and not c.B.navigating,
        "Entering an excluded instance clears popups, queued popups and guidance")
    c.env.IsInInstance=function() return false,"none" end;c.B.UI.Tick()
    check(not c.B.UI.banner:IsShown() and not c.B.UI.answerBanner:IsShown(),"Leaving an instance does not replay suppressed notifications")
end

-- Exercise both directions of the atlas fallback with world APIs unavailable.
do
    local c=fresh();local C,e=c.B.Client,c.env
    local id,x,y=C.MapPoint({map=1429,px=.1,py=.45},947)
    local wide={map=id,px=x,py=y}
    e.C_Map.GetWorldPosFromMapPos=nil;e.C_Map.GetMapPosFromWorldPos=nil
    local zone,zx,zy=C.MapPoint(wide,1429)
    check(zone==1429 and math.abs(zx-.1)<1e-8 and math.abs(zy-.45)<1e-8,"World-atlas location transforms back down into the zone without world APIs")
    local continent,cx,cy=C.MapPoint(wide,1415)
    local z,xx,yy=C.MapPoint({map=continent,px=cx,py=cy},1429)
    check(z==1429 and math.abs(xx-.1)<1e-8 and math.abs(yy-.45)<1e-8,"Continent positions remain visible after zooming into their zone")
    check(C.MapPoint(wide,1446)==nil and C.MapPoint(wide,1433)==nil,"Out-of-zone and cross-continent points are never clamped into unrelated maps")
    local map=mapFrame(c,947);local key=c.B.Protocol.Identity("Scout Ironward");c.B.members[key]=true
    c.B.Receive(string.format("1|L|%d|947|%.5f|%.5f",c.s.time,x,y),"Scout Ironward","GUILD");c.B.UI.MapPins()
    local pin=c.B.UI.locationPins[1];check(pin:IsShown(),"World-level location has a visible world pin")
    map:SetMapID(1429);check(pin:IsShown() and pin.location.map==947,"The same broad-map location remains visible on the zone map")
    map:SetMapID(1446);check(not pin:IsShown(),"Zone transition removes a marker that is outside the destination map")
    map:SetMapID(1429);check(pin:IsShown(),"Returning to the matching zone restores its marker")
    e.C_Map.GetMapRectOnMap=function() return 0,0,0,1 end
    check(C.MapPoint(wide,1429)==nil,"Degenerate map rectangles fail safely")
end
do
    local c=fresh();local world=mapFrame(c,1429);local b=add(c,"Scout Ironward",.1)
    c.B.Receive(string.format("1|L|%d|1429|.1|.45",c.s.time),b.name,"GUILD");c.B.UI.MapPins()
    local u=c.B.UI;local p,l=u.pins[1],u.locationPins[1]
    check(p:GetWidth()==18 and l.icon:GetHeight()==18,"Default beacon and guildmate markers are smaller")
    world.canvas:SetScale(2);u.MapPins()
    check(p:GetWidth()*world.canvas:GetEffectiveScale()==18 and l.icon:GetHeight()*world.canvas:GetEffectiveScale()==18,
        "Map zoom does not inflate either marker type")
    local new=c.env.CreateFrame("Frame",nil,world);new:SetSize(500,400);world.canvas=new;world:SetMapID(1429)
    check(p.parent==new and l.parent==new and p.anchor[4]==50 and l.anchor[4]==50,"Both pin types reparent and reposition when a skin replaces the map canvas")
    u.markerSize:SetValue(150)
    check(p:GetWidth()==36 and l.icon:GetHeight()==36,"Marker size control immediately scales both marker types")
    c.B.SetFriend(b.name,true);check(l.icon:GetWidth()==27 and l.icon:GetHeight()==36,"Resized Friend shields preserve their original proportions")
    c.B.db.showLocations=false;u.MapPins();check(not l:IsShown() and p:IsShown(),"Location visibility preference still leaves beacon markers independent")
end
return preview
