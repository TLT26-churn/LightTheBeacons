local _,B=...
local U,C,P,R=B.UI,B.Client,B.Protocol,B.Routing
local W=U.Widgets
local text,texture,fill,button,tip=W.text,W.texture,W.fill,W.button,W.tip
local media="Interface\\AddOns\\LightTheBeacons\\Media\\"
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
    local cooldown=math.max(0,(B.db.lastSent or 0)+P.cooldown-C.Now())
    f.icon:SetDesaturated(not own);f.icon:SetAlpha(own and 1 or .60)
    f.label:SetText(own and "Lit" or cooldown>0 and (cooldown.."s") or "Light")
    tip(f,own and "Your beacon is lit" or "Light the Beacons",
        (own and ("Expires in "..R.Time(own.expires-C.Now())..".\nLeft-click: extinguish your beacon.") or
        "Left-click: light a beacon now, without a message.").."\nRight-click: open the full card.\nShift-drag: move this button.")
end
local function checkbox(parent,label,description,y,fn)
    local c=CreateFrame("CheckButton",nil,parent);c:SetPoint("TOPLEFT",16,-y);c:SetSize(24,24)
    c:SetNormalTexture(media.."UI-CheckBox-Up.tga");c:SetCheckedTexture(media.."UI-CheckBox-Check.tga")
    text(parent,47,y+3,335,22,12,gold):SetText(label)
    text(parent,47,y+27,335,47,11,pale):SetText(description)
    c:SetScript("OnClick",function(self) fn(self:GetChecked() and true or false);U.Refresh() end)
    return c
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
    U.floatingCheck=checkbox(controls,"Show movable beacon button",
        "On by default. Click to light or extinguish. Shift-drag to move it; right-click opens the full card.",292,function(value) B.db.floatingButton=value end)
    U.resetFloating=button(controls,"Reset button position",16,380,184,function() B.db.buttonPosition=nil;U.RestoreFloating() end)
    button(controls,"Open world map",210,380,174,function()
        if OpenWorldMap then C.Call(OpenWorldMap,947)
        elseif WorldMapFrame then WorldMapFrame:Show();C.Call(WorldMapFrame.SetMapID,WorldMapFrame,947) end
    end)
    U.locationStatus=text(controls,16,423,368,38,11,pale)
    U.locationCount=text(controls,16,470,368,17,11,muted)
    local filters=CreateFrame("Frame",nil,U.frame);U.filtersPanel=filters;filters:SetAllPoints();filters:Hide()
    text(filters,16,60,368,26,17,gold):SetText("Player filters")
    text(filters,16,96,368,45,12,pale):SetText("Silence: no horn or popup. Hide: also removes their beacons. Location visibility is a separate choice.")
    text(filters,16,148,368,16,11,gold):SetText("FULL CHARACTER NAME  (including surname)")
    local field=CreateFrame("Frame",nil,filters,"BackdropTemplate");field:SetPoint("TOPLEFT",16,-171);field:SetSize(244,28)
    field:SetBackdrop({bgFile=media.."UI-DialogBox-Background.tga",edgeFile=media.."UI-DialogBox-Border.tga",edgeSize=8,insets={left=3,right=3,top=3,bottom=3}})
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
    U.filterEmpty=text(filters,24,284,352,50,12,muted,"CENTER");U.filterEmpty:SetText("No player filters.\nAdd a character's full name above.")
    text(filters,16,462,368,34,11,muted):SetText("Scroll for more players. Changes apply only to this character and are never sent to the guild.")
    filters:SetScript("OnHide",function() edit:ClearFocus() end)
    U.filterRows={}
end
local function filterRow(index)
    local row=CreateFrame("Frame",nil,U.filterChild);row:SetPoint("TOPLEFT",0,-((index-1)*64));row:SetSize(368,64)
    fill(row,0,60,368,1,.35,.43,.56,.35)
    row.name=text(row,0,3,292,20,12,gold);row.name:SetWordWrap(false)
    row:EnableMouse(true)
    row.remove=button(row,"Remove",300,0,68,function() B.RemovePlayerFilter(row.key) end)
    row.mode=button(row,"Beacons: Normal",0,27,180,function()
        local f=B.Filter(row.key);if f then B.SetPlayerFilter(f.name,nextMode[f.beacons],f.hideLocation) end
    end)
    row.location=CreateFrame("CheckButton",nil,row);row.location:SetPoint("TOPLEFT",192,-30);row.location:SetSize(22,22)
    row.location:SetNormalTexture(media.."UI-CheckBox-Up.tga");row.location:SetCheckedTexture(media.."UI-CheckBox-Check.tga")
    text(row,219,35,145,18,11,pale):SetText("Hide location")
    row.location:SetScript("OnClick",function(self) local f=B.Filter(row.key);if f then B.SetPlayerFilter(f.name,f.beacons,self:GetChecked()) end end)
    return row
end
function U.RefreshControls()
    if not U.controlsPanel then return end
    U.controlsPanel:SetShown(U.options and U.settingsPage=="controls")
    U.filtersPanel:SetShown(U.options and U.settingsPage=="filters")
    U.sharing:SetChecked(B.db.shareLocation);U.showLocations:SetChecked(B.db.showLocations);U.floatingCheck:SetChecked(B.db.floatingButton)
    U.resetFloating:SetEnabled(B.db.floatingButton)
    U.locationStatus:SetText((not IsInGuild or not IsInGuild()) and "Join a guild to share locations." or B.locationStatus or
        (B.db.shareLocation and "Location sharing is on; waiting for a readable map position." or "Location sharing is off."))
    U.locationCount:SetText(#B.Locations().." visible guild locations - stale markers expire after 45 sec")
    local list={};for key,f in pairs(B.db.playerFilters) do list[#list+1]={key=key,f=f} end
    table.sort(list,function(a,b) return a.f.name<b.f.name end)
    for i=1,math.max(#list,#U.filterRows) do
        local row=U.filterRows[i] or filterRow(i);U.filterRows[i]=row;local entry=list[i];row:SetShown(entry~=nil)
        if entry then row.key=entry.key;row.name:SetText(entry.f.name);row.mode.label:SetText("Beacons: "..modes[entry.f.beacons]);row.location:SetChecked(entry.f.hideLocation);tip(row,entry.f.name,"Beacons: "..modes[entry.f.beacons]..". Location: "..(entry.f.hideLocation and "hidden" or "shown")..".") end
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
        if hooksecurefunc and WorldMapFrame.SetMapID then C.Call(hooksecurefunc,WorldMapFrame,"SetMapID",function() U.MapPins() end) end
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
                    local icon=texture(pin,"AllianceCrest",0,0,20,24);icon:SetTexCoord(.175,.825,.09,.91)
                    pin:RegisterForClicks("LeftButtonUp","RightButtonUp")
                    pin:SetScript("OnClick",function(self,mouse)
                        local pos=self.location;if not pos or pos.expires<=C.Now() then return end
                        if mouse=="RightButton" then U.OpenSettingsPage("filters");U.filterName:SetText(pos.name);U.filterName:SetFocus()
                        else C.OpenMap(pos) end
                    end)
                    pin:SetScript("OnEnter",function(self)
                        local pos=self.location;if not GameTooltip or not pos then return end
                        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(pos.name,1,.82,.43)
                        GameTooltip:AddLine(C.Zone(pos.map).." - "..math.floor(pos.px*100+.5)..", "..math.floor(pos.py*100+.5),.86,.9,.97)
                        GameTooltip:AddLine("Updated "..math.max(0,C.Now()-pos.sent).." seconds ago.",.7,.75,.83)
                        GameTooltip:AddLine("Left-click: map waypoint. Right-click: player filters.",1,1,1,true);GameTooltip:Show()
                    end)
                    pin:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
                end
                pin:SetParent(canvas);pin:SetFrameLevel(canvas:GetFrameLevel()+14)
                pin.location=p;pin:ClearAllPoints();pin:SetPoint("CENTER",canvas,"TOPLEFT",x*canvas:GetWidth(),-y*canvas:GetHeight());pin:Show()
            end
        end
    end
    for i=index+1,#U.locationPins do U.locationPins[i]:Hide();U.locationPins[i].location=nil end
end
