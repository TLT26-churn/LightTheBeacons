local _,B=...
local U,C,P,R=B.UI,B.Client,B.Protocol,B.Routing
local W=U.Widgets
local text,texture,fill,button,tip=W.text,W.texture,W.fill,W.button,W.tip
local function asset(name) return assert(B.MediaPaths[name], "Unknown media: "..tostring(name)) end
local gold,pale,muted={1,.82,.43},{.86,.90,.97},{.60,.66,.76}
local modes={normal="Normal",silent="Silence",hidden="Hide"}
local nextMode={normal="silent",silent="hidden",hidden="normal"}

function U.OpenSettingsPage(page)
    if not U.frame then return end
    U.settingsPage=page;U.options=true;U.frame:Show();U.Refresh()
end
function U.RestoreFloating()
    local f=U.floating;f:ClearAllPoints()
    local pos=B.db.buttonPosition
    if pos then f:SetPoint("CENTER",UIParent,"BOTTOMLEFT",pos.x*UIParent:GetWidth(),pos.y*UIParent:GetHeight())
    else f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-80,-220) end
end
function U.RefreshFloating()
    local f=U.floating;if not f or not B.db then return end
    f:SetShown(B.db.floatingButton)
    local own=B.own and B.own.expires>C.Now() and B.own
    f:SetEnabled(own~=nil or C.BeaconsAllowed())
    local cooldown=math.max(0,(B.db.lastSent or 0)+P.cooldown-C.Now())
    f.icon:SetDesaturated(not own);f.icon:SetAlpha(own and 1 or .60)
    f.label:SetText(own and "Lit" or cooldown>0 and (cooldown.."s") or "Light")
    tip(f,own and "Your beacon is lit" or "Light the Beacons",
        (own and ("Expires in "..R.Time(own.expires-C.Now())..".\nLeft-click: extinguish your beacon.") or
        "Left-click: light a beacon now, without a message.").."\nRight-click: open the full card.\nShift-drag: move this button.")
end
function U.EnforceBeaconContext()
    if C.BeaconsAllowed() then return end
    B.navigating=false;B.answerQueue=nil;U.pendingAlert=nil
    if U.banner then U.banner:Hide() end
    if U.answerBanner then U.answerBanner:Hide() end
    if U.hud then U.hud:Hide() end
end
function U.MapIconFactor(canvas)
    local base=C.Call(UIParent.GetEffectiveScale,UIParent)
    local scale=C.Call(canvas.GetEffectiveScale,canvas)
    local ratio=P.Number(base,.01,100) and P.Number(scale,.01,100) and base/scale or 1
    return (B.db.mapIconScale or 75)/100*ratio
end
local function checkbox(parent,label,description,y,fn)
    local c=CreateFrame("CheckButton",nil,parent);c:SetPoint("TOPLEFT",16,-y);c:SetSize(24,24)
    c:SetNormalTexture(asset("UI-CheckBox-Up"));c:SetCheckedTexture(asset("UI-CheckBox-Check"))
    text(parent,47,y+3,335,22,12,gold):SetText(label)
    text(parent,47,y+27,335,47,11,pale):SetText(description)
    c:SetScript("OnClick",function(self) fn(self:GetChecked() and true or false);U.Refresh() end)
    return c
end
local function slider(parent,label,y,key,minimum,maximum,step,suffix,description)
    local value=text(parent,16,y,368,20,12,gold)
    local s=CreateFrame("Slider",nil,parent);s:SetPoint("TOPLEFT",24,-(y+25));s:SetSize(352,22)
    s:EnableMouse(true);s:SetOrientation("HORIZONTAL");s:SetMinMaxValues(minimum,maximum);s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    fill(s,0,9,352,4,.52,.42,.25,1)
    local thumb=s:CreateTexture(nil,"OVERLAY");thumb:SetSize(12,22);thumb:SetColorTexture(1,.82,.43,1);s:SetThumbTexture(thumb)
    text(parent,16,y+51,368,30,11,muted):SetText(description)
    s:SetScript("OnValueChanged",function(self,v)
        if self.refreshing then return end
        v=math.max(minimum,math.min(maximum,math.floor(v/step+.5)*step))
        B.db[key]=v
        if key=="mergeDistance" then B.Replan();U.RefreshAlertGroup();if B.navigating then B.SetNextWaypoint() end end
        U.Refresh();U.MapPins()
    end)
    s.Refresh=function(self)
        self.refreshing=true;self:SetValue(B.db[key]);self.refreshing=nil
        value:SetText(label..": "..B.db[key]..suffix)
    end
    return s
end
function U.CreateControls()
    local f=CreateFrame("Button","LightTheBeaconsFloating",UIParent);U.floating=f
    f:SetSize(44,60);f:SetFrameStrata("MEDIUM");f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true)
    f:RegisterForClicks("LeftButtonUp","RightButtonUp");f:RegisterForDrag("LeftButton")
    f.icon=texture(f,"RoyalBrazier",2,2,40,40)
    f.label=text(f,0,45,44,15,11,gold,"CENTER")
    f:SetScript("OnDragStart",function(self)
        if IsShiftKeyDown and IsShiftKeyDown() then self.dragging=true;self:StartMoving() end
    end)
    f:SetScript("OnDragStop",function(self)
        if not self.dragging then return end
        self:StopMovingOrSizing();self.dragging=false;self.ignoreClickUntil=GetTime()+.3
        local x,y=self:GetCenter();local w,h=UIParent:GetWidth(),UIParent:GetHeight()
        if P.Number(x,0,w) and P.Number(y,0,h) and w>0 and h>0 then B.db.buttonPosition={x=x/w,y=y/h} end
        U.RestoreFloating()
    end)
    f:SetScript("OnClick",function(self,mouse)
        if self.dragging or (self.ignoreClickUntil and GetTime()<self.ignoreClickUntil) or (IsShiftKeyDown and IsShiftKeyDown()) then return end
        if mouse=="RightButton" then
            B.preview=nil;U.options=false;U.settingsPage=nil
            if B.own and B.own.expires>C.Now() then B.Select(B.own) end
            U.frame:Show();U.Refresh()
        elseif B.own and B.own.expires>C.Now() then B.Extinguish()
        else B.Light() end
    end)
    U.RestoreFloating()
    local controls=CreateFrame("Frame",nil,U.frame);U.controlsPanel=controls;controls:SetAllPoints();controls:Hide()
    text(controls,16,60,368,26,17,gold):SetText("Map & beacon controls")
    U.sharing=checkbox(controls,"Share my location with guildmates",
        "On by default. Sends your position about every 10 seconds. Off stops background sharing; a lit beacon still shares its incident location.",100,function(value) B.ShareLocation(value) end)
    U.showLocations=checkbox(controls,"Show guildmates on my map",
        "Shows addon users on zone, continent and world maps. Hiding their markers does not change your own sharing.",202,function(value) B.db.showLocations=value;U.MapPins() end)
    U.friendsOnly=checkbox(controls,"Show only Friends on the map",
        "Filters guild location and beacon markers. Your beacon stays visible; calls and alerts are unchanged.",282,function(value) B.db.friendsOnly=value;U.MapPins() end)
    U.floatingCheck=checkbox(controls,"Show movable beacon button",
        "On by default. Click to light or extinguish. Shift-drag to move it; right-click opens the full card.",372,function(value) B.db.floatingButton=value end)
    U.resetFloating=button(controls,"Reset button position",16,460,184,function() B.db.buttonPosition=nil;U.RestoreFloating() end)
    button(controls,"Open world map",210,460,174,function()
        if OpenWorldMap then C.Call(OpenWorldMap,947)
        elseif WorldMapFrame then WorldMapFrame:Show();C.Call(WorldMapFrame.SetMapID,WorldMapFrame,947) end
    end)
    U.locationStatus=text(controls,16,499,368,38,11,pale)
    U.locationCount=text(controls,16,548,368,17,11,muted)
    local settings=CreateFrame("Frame",nil,U.frame);U.beaconSettings=settings;settings:SetAllPoints();settings:Hide()
    text(settings,16,60,368,26,17,gold):SetText("Beacon settings")
    U.combine=checkbox(settings,"Combine nearby beacons",
        "One card and marker for a nearby group. Joining updates names quietly; each caller keeps their own beacon.",96,function(v) B.db.combineBeacons=v;B.Replan();U.RefreshAlertGroup();U.MapPins() end)
    U.mergeRange=slider(settings,"Combine within",184,"mergeDistance",25,250,25," yards",
        "Default: 100 yards. Every caller must be within this range of every other caller.")
    U.instances=checkbox(settings,"Disable beacons in dungeons and raids",
        "On by default. Blocks calls, horns, popups and route guidance here. Battlegrounds and arenas always stay disabled.",272,function(v) B.db.disableInInstances=v;U.EnforceBeaconContext();U.MapPins() end)
    U.popups=checkbox(settings,"Show beacon and response popups",
        "Calls always remain in the card. Turn this off for fewer interruptions; sound has its own switch.",360,function(v)
            B.db.beaconPopups=v
            if not v then U.pendingAlert=nil;U.banner:Hide();U.answerBanner:Hide() end
        end)
    U.hornCooldown=slider(settings,"Shared horn cooldown",448,"hornCooldown",0,120,5," sec",
        "Default: 30 sec. New calls still appear. 0 allows every separate call to sound.")
    U.markerSize=slider(settings,"Map marker size",536,"mapIconScale",50,150,5,"%",
        "Default: 75% of the old size. Applies to guildmates, Friends and beacons.")
    local chat=CreateFrame("Frame",nil,U.frame);U.chatPanel=chat;chat:SetAllPoints();chat:Hide()
    text(chat,16,60,368,26,17,gold):SetText("Chat notices")
    U.chatBeacons=checkbox(chat,"Beacon activity",
        "Who lights or extinguishes a beacon, who answers yours, and confirmation when you answer a call.",100,function(v) B.db.chatBeacons=v end)
    U.chatJoins=checkbox(chat,"Nearby beacon joins",
        "Off by default. Adds a chat line when someone joins a shared beacon. Joins still have no new horn or popup.",194,function(v) B.db.chatJoins=v end)
    U.chatGrudges=checkbox(chat,"Grudge activity",
        "Who records, avenges or withdraws a grudge. Syncing older guild history stays quiet.",288,function(v) B.db.chatGrudges=v end)
    U.chatSightings=checkbox(chat,"Enemy sightings",
        "Off by default. Adds target and mouseover warnings to chat. Requires sighting warnings in Grudges settings.",382,function(v) B.db.chatSightings=v end)
    text(chat,16,474,368,28,11,muted):SetText("Only in your chat window. Global mute and player filters apply. Nothing is posted to guild chat.")
    local filters=CreateFrame("Frame",nil,U.frame);U.filtersPanel=filters;filters:SetAllPoints();filters:Hide()
    text(filters,16,60,368,26,17,gold):SetText("Friends & filters")
    text(filters,16,96,368,45,12,pale):SetText("Mark Friends for the map filter. Silence keeps calls quiet; Hide removes their beacons. Location hiding is separate.")
    text(filters,16,148,368,16,11,gold):SetText("FULL CHARACTER NAME  (including surname)")
    local field=CreateFrame("Frame",nil,filters,"BackdropTemplate");field:SetPoint("TOPLEFT",16,-171);field:SetSize(244,28)
    field:SetBackdrop({bgFile=asset("UI-DialogBox-Background"),edgeFile=asset("UI-DialogBox-Border"),edgeSize=8,insets={left=3,right=3,top=3,bottom=3}})
    field:SetBackdropColor(.035,.09,.21,1);field:SetBackdropBorderColor(.80,.65,.38,1)
    local edit=CreateFrame("EditBox",nil,field);U.filterName=edit;edit:SetPoint("TOPLEFT",7,-5);edit:SetSize(230,20)
    edit:SetFont("Fonts\\FRIZQT__.TTF",12,"");edit:SetTextColor(unpack(pale));edit:SetAutoFocus(false);edit:SetMaxBytes(150)
    edit:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    U.addFilter=button(filters,"Add player",270,171,114,function()
        local raw=edit:GetText() or "";local key=P.Identity(raw:gsub("%s+"," "):match("^%s*(.-)%s*$"))
        if key and B.Filter(key) then U.filterStatus:SetText("Already in the list. Edit the existing filter below.");return end
        local ok,why=B.SetPlayerFilter(edit:GetText(),"normal",false)
        if ok then edit:SetText("");edit:ClearFocus();U.filterStatus:SetText("Choose beacon and location visibility below.")
        else U.filterStatus:SetText(why) end
    end)
    U.filterStatus=text(filters,16,212,368,32,11,muted)
    local scroll=CreateFrame("ScrollFrame",nil,filters);U.filterScroll=scroll;scroll:SetPoint("TOPLEFT",16,-254);scroll:SetSize(368,192);scroll:EnableMouseWheel(true)
    U.filterChild=CreateFrame("Frame",nil,scroll);U.filterChild:SetSize(368,192);scroll:SetScrollChild(U.filterChild)
    scroll:SetScript("OnMouseWheel",function(self,delta) self:SetVerticalScroll(math.max(0,math.min(U.filterChild:GetHeight()-192,(self:GetVerticalScroll() or 0)-delta*64))) end)
    U.filterEmpty=text(filters,24,284,352,50,12,muted,"CENTER");U.filterEmpty:SetText("No Friends or player filters.\nAdd a character's full name above.")
    text(filters,16,462,368,34,11,muted):SetText("Scroll for more players. Changes apply only to this character and are never sent to the guild.")
    filters:SetScript("OnHide",function() edit:ClearFocus() end)
    U.filterRows={}
end
local function filterRow(index)
    local row=CreateFrame("Frame",nil,U.filterChild);row:SetPoint("TOPLEFT",0,-((index-1)*64));row:SetSize(368,64)
    fill(row,0,60,368,1,.35,.43,.56,.35)
    row.name=text(row,0,3,198,20,12,gold);row.name:SetWordWrap(false)
    row:EnableMouse(true)
    row.friend=CreateFrame("CheckButton",nil,row);row.friend:SetPoint("TOPLEFT",204,0);row.friend:SetSize(22,22)
    row.friend:SetNormalTexture(asset("UI-CheckBox-Up"));row.friend:SetCheckedTexture(asset("UI-CheckBox-Check"))
    text(row,231,5,63,18,11,pale):SetText("Friend")
    row.friend:SetScript("OnClick",function(self) local f=B.Filter(row.key);if f then B.SetFriend(f.name,self:GetChecked()) end end)
    row.remove=button(row,"Remove",300,0,68,function() B.RemovePlayerFilter(row.key) end)
    tip(row.remove,"Remove player","Removes their Friend mark and all local filters.")
    row.mode=button(row,"Beacons: Normal",0,27,180,function()
        local f=B.Filter(row.key);if f then B.SetPlayerFilter(f.name,nextMode[f.beacons],f.hideLocation) end
    end)
    row.location=CreateFrame("CheckButton",nil,row);row.location:SetPoint("TOPLEFT",192,-30);row.location:SetSize(22,22)
    row.location:SetNormalTexture(asset("UI-CheckBox-Up"));row.location:SetCheckedTexture(asset("UI-CheckBox-Check"))
    text(row,219,35,145,18,11,pale):SetText("Hide location")
    row.location:SetScript("OnClick",function(self) local f=B.Filter(row.key);if f then B.SetPlayerFilter(f.name,f.beacons,self:GetChecked()) end end)
    return row
end
function U.RefreshControls()
    if not U.controlsPanel then return end
    U.controlsPanel:SetShown(U.options and U.settingsPage=="controls")
    U.filtersPanel:SetShown(U.options and U.settingsPage=="filters")
    U.beaconSettings:SetShown(U.options and U.settingsPage=="beacons")
    U.chatPanel:SetShown(U.options and U.settingsPage=="chat")
    U.chatBeacons:SetChecked(B.db.chatBeacons);U.chatJoins:SetChecked(B.db.chatJoins)
    U.chatGrudges:SetChecked(B.db.chatGrudges);U.chatSightings:SetChecked(B.db.chatSightings)
    U.chatJoins:SetEnabled(B.db.chatBeacons)
    U.combine:SetChecked(B.db.combineBeacons);U.instances:SetChecked(B.db.disableInInstances);U.popups:SetChecked(B.db.beaconPopups)
    U.mergeRange:Refresh();U.hornCooldown:Refresh();U.markerSize:Refresh()
    U.mergeRange:EnableMouse(B.db.combineBeacons);U.mergeRange:SetAlpha(B.db.combineBeacons and 1 or .4)
    U.sharing:SetChecked(B.db.shareLocation);U.showLocations:SetChecked(B.db.showLocations);U.floatingCheck:SetChecked(B.db.floatingButton);U.friendsOnly:SetChecked(B.db.friendsOnly)
    U.resetFloating:SetEnabled(B.db.floatingButton)
    U.locationStatus:SetText((not IsInGuild or not IsInGuild()) and "Join a guild to share locations." or B.locationStatus or
        (B.db.shareLocation and "Location sharing is on; waiting for a readable map position." or "Location sharing is off."))
    U.locationCount:SetText(#B.Locations()..(B.db.friendsOnly and " visible Friends - " or " visible guild locations - ").."stale markers expire after 45 sec")
    local list={};for key,f in pairs(B.db.playerFilters) do list[#list+1]={key=key,f=f} end
    table.sort(list,function(a,b) return a.f.name<b.f.name end)
    for i=1,math.max(#list,#U.filterRows) do
        local row=U.filterRows[i] or filterRow(i);U.filterRows[i]=row;local entry=list[i];row:SetShown(entry~=nil)
        if entry then row.key=entry.key;row.name:SetText(entry.f.name);row.friend:SetChecked(entry.f.friend);row.mode.label:SetText("Beacons: "..modes[entry.f.beacons]);row.location:SetChecked(entry.f.hideLocation);tip(row,entry.f.name,(entry.f.friend and "Friend. " or "").."Beacons: "..modes[entry.f.beacons]..". Location: "..(entry.f.hideLocation and "hidden" or "shown")..".") end
    end
    U.filterEmpty:SetShown(#list==0);U.filterChild:SetHeight(math.max(192,#list*64))
    U.filterScroll:SetVerticalScroll(math.min(U.filterScroll:GetVerticalScroll() or 0,U.filterChild:GetHeight()-192))
    U.RefreshFloating()
end
function U.LocationPins()
    U.locationPins=U.locationPins or {}
    if WorldMapFrame and U.mapHooked~=WorldMapFrame then
        U.mapHooked=WorldMapFrame
        WorldMapFrame:HookScript("OnShow",function() U.MapPins() end)
        WorldMapFrame:HookScript("OnHide",function() U.MapPins() end)
        if hooksecurefunc and WorldMapFrame.SetMapID then C.Call(hooksecurefunc,WorldMapFrame,"SetMapID",function()
            U.MapPins()
            -- Some map skins replace/resize the canvas after SetMapID returns.
            if C_Timer and not U.mapRefreshPending then
                U.mapRefreshPending=true;C_Timer.After(0,function() U.mapRefreshPending=nil;U.MapPins() end)
            end
        end) end
    end
    local map=WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local canvas=map and ((WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()) or WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
    local index=0
    if canvas and B.db then
        for _,p in ipairs(B.Locations()) do
            local id,x,y=C.MapPoint(p,map)
            if id==map and x and y then
                index=index+1;local pin=U.locationPins[index]
                if not pin then
                    pin=CreateFrame("Button",nil,canvas);U.locationPins[index]=pin;pin:SetSize(20,24)
                    pin.icon=texture(pin,"AllianceCrest",0,0,20,24)
                    pin:RegisterForClicks("LeftButtonUp","RightButtonUp")
                    pin:SetScript("OnClick",function(self,mouse)
                        local pos=self.location;if not pos or pos.expires<=C.Now() then return end
                        if mouse=="RightButton" then U.OpenSettingsPage("filters");U.filterName:SetText(pos.name);U.filterName:SetFocus()
                        else C.OpenMap(pos) end
                    end)
                    pin:SetScript("OnEnter",function(self)
                        local pos=self.location;if not GameTooltip or not pos then return end
                        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(pos.name,1,.82,.43)
                        if B.IsFriend(pos.owner) then GameTooltip:AddLine("Friend",1,.82,.43) end
                        GameTooltip:AddLine(C.Zone(pos.map).." - "..math.floor(pos.px*100+.5)..", "..math.floor(pos.py*100+.5),.86,.9,.97)
                        GameTooltip:AddLine("Updated "..math.max(0,C.Now()-pos.sent).." seconds ago.",.7,.75,.83)
                        GameTooltip:AddLine("Left-click: map waypoint. Right-click: player filters.",1,1,1,true);GameTooltip:Show()
                    end)
                    pin:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
                end
                -- Pins are reused as the roster/filter order changes. Reset both
                -- texture and geometry so a former Friend's shield never leaks
                -- onto a regular guildmate's marker.
                pin.icon:ClearAllPoints()
                local factor=U.MapIconFactor(canvas)
                pin:SetSize(20*factor,24*factor)
                if B.IsFriend(p.owner) then
                    pin.icon:SetTexture(asset("AllianceShield"));pin.icon:SetTexCoord(.125,.875,0,1)
                    pin.icon:SetSize(18*factor,24*factor);pin.icon:SetPoint("TOPLEFT",factor,0)
                else
                    pin.icon:SetTexture(asset("AllianceCrest"));pin.icon:SetTexCoord(.175,.825,.09,.91)
                    pin.icon:SetSize(20*factor,24*factor);pin.icon:SetPoint("TOPLEFT",0,0)
                end
                pin:SetParent(canvas);pin:SetFrameLevel(canvas:GetFrameLevel()+14)
                pin.location=p;pin:ClearAllPoints();pin:SetPoint("CENTER",canvas,"TOPLEFT",x*canvas:GetWidth(),-y*canvas:GetHeight());pin:Show()
            end
        end
    end
    for i=index+1,#U.locationPins do U.locationPins[i]:Hide();U.locationPins[i].location=nil end
end
