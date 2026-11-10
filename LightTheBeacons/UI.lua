local _,B=...
local U,C,R,P={},B.Client,B.Routing,B.Protocol;B.UI=U
local media="Interface\\AddOns\\LightTheBeacons\\Media\\"
local gold={1,.79,.37};local pale={.94,.87,.69};local ink={.24,.15,.08}
local function text(parent,x,y,w,h,size,color,align)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont("Fonts\\FRIZQT__.TTF",size or 13,"")
    f:SetPoint("TOPLEFT",x,-y);f:SetSize(w,h)
    f:SetJustifyH(align or "LEFT");f:SetJustifyV("TOP");f:SetWordWrap(true)
    f:SetTextColor(unpack(color or pale))
    if color~=ink then f:SetShadowColor(0,0,0,.9);f:SetShadowOffset(1,-1) end
    return f
end
local function texture(parent,name,x,y,w,h,layer)
    local t=parent:CreateTexture(nil,layer or "ARTWORK")
    t:SetTexture(media..name..".tga");t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);return t
end
local function fill(parent,x,y,w,h,r,g,b,a)
    local t=parent:CreateTexture(nil,"BACKGROUND")
    t:SetColorTexture(r,g,b,a or 1);t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);return t
end
local function panel(parent,name,w,h)
    local f=CreateFrame("Frame",name,parent,"BackdropTemplate")
    f:SetSize(w,h)
    f:SetBackdrop({bgFile=media.."UI-DialogBox-Background.tga",edgeFile=media.."UI-DialogBox-Border.tga",
        tile=true,tileSize=32,edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
    f:SetBackdropColor(.55,.48,.36,.98);f:SetBackdropBorderColor(.84,.70,.44,1)
    return f
end
local function button(parent,label,x,y,w,fn)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,28)
    for _,state in ipairs({"Normal","Pushed","Disabled","Highlight"}) do
        local names={Normal="Up",Pushed="Down",Disabled="Disabled",Highlight="Highlight"}
        b["Set"..state.."Texture"](b,media.."UI-Panel-Button-"..names[state]..".tga")
        local t=b["Get"..state.."Texture"](b);t:SetTexCoord(0,.625,0,.6875)
        if state=="Highlight" then t:SetBlendMode("ADD") end
    end
    b.label=text(b,5,6,w-10,18,12,gold,"CENTER");b.label:SetText(label)
    b:SetScript("OnClick",fn)
    b:SetScript("OnEnable",function() b.label:SetTextColor(unpack(gold)) end)
    b:SetScript("OnDisable",function() b.label:SetTextColor(.5,.48,.42) end)
    return b
end
local function tip(frame,title,body)
    frame:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(title,1,.82,.3)
        if body then GameTooltip:AddLine(body,.95,.9,.8,true) end;GameTooltip:Show()
    end)
    frame:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
end
local function draggable(f)
    f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
end
local function closeButton(parent,x,y,callback)
    local b=CreateFrame("Button",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(28,28)
    b:SetNormalTexture(media.."UI-Panel-MinimizeButton-Up.tga")
    b:SetPushedTexture(media.."UI-Panel-MinimizeButton-Down.tga")
    b:SetHighlightTexture(media.."UI-Panel-MinimizeButton-Highlight.tga","ADD")
    b:SetScript("OnClick",callback);return b
end
local reasons={aid="Calls for aid",pvp="Fallen in battle",fallen="Fallen ally"}
function U.StepTitle(step)
    if step.kind=="flight" then return "Fly to "..step.to.n end
    if step.kind=="boat" then return "Boat to "..step.to.n end
    if step.kind=="zeppelin" then return "Zeppelin to "..step.to.n end
    return (B.db.pace>7 and "Ride to " or "Travel to ")..step.to.n
end
function U.Cycle(delta)
    if B.preview then return end
    local list=B.List();if #list<2 then return end
    local index=1;for i,b in ipairs(list) do if b.owner==B.selected then index=i end end
    B.Select(list[(index-1+delta)%#list+1])
end
function U.Create()
    if U.frame then return end
    local f=panel(UIParent,"LightTheBeaconsWindow",620,526);U.frame=f
    f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");draggable(f)
    UISpecialFrames[#UISpecialFrames+1]="LightTheBeaconsWindow"
    fill(f,19,18,582,58,.16,.105,.045,.5)
    texture(f,"Torch",30,28,33,33):SetTexCoord(.08,.92,.08,.92)
    text(f,77,25,460,28,21,gold):SetText("Light the Beacons")
    U.subtitle=text(f,78,53,456,16,11,pale)
    closeButton(f,565,24,function() f:Hide() end)
    local function tab(label,x,fn)
        local t=CreateFrame("Button",nil,f);t:SetPoint("TOPLEFT",x,-84);t:SetSize(106,27)
        t.label=text(t,2,4,102,18,13,gold,"CENTER");t.label:SetText(label)
        t.line=fill(t,6,25,94,1,.85,.64,.28,.85)
        t:SetScript("OnClick",fn);return t
    end
    U.callsTab=tab("Beacons",26,function() U.options=false;U.Refresh() end)
    U.optionsTab=tab("Options",138,function() U.options=true;U.Refresh() end)
    U.previewTab=tab("Preview",250,function()
        if B.preview then B.preview=nil;B.Replan();U.banner:Hide();U.Refresh() else U.options=false;B.Preview() end
    end)
    U.count=text(f,368,91,228,17,11,pale,"RIGHT")
    U.main=CreateFrame("Frame",nil,f);U.main:SetAllPoints()
    -- One dispatch card and a full-width route: no empty sidebar or stretched paper.
    fill(U.main,25,124,570,77,.22,.15,.075,.65)
    fill(U.main,25,124,3,77,.92,.59,.19,.95)
    U.destination=text(U.main,42,137,450,25,19,gold)
    U.location=text(U.main,43,168,464,20,12,pale)
    U.prev=button(U.main,"<",515,136,31,function() U.Cycle(-1) end)
    U.nextCall=button(U.main,">",552,136,31,function() U.Cycle(1) end)
    U.age=text(U.main,495,173,87,16,10,pale,"RIGHT")
    text(U.main,35,217,205,20,11,gold):SetText("YOUR JOURNEY")
    U.eta=text(U.main,244,213,340,25,15,gold,"RIGHT")
    fill(U.main,35,238,550,1,.68,.48,.22,.45)
    U.routeScroll=CreateFrame("ScrollFrame",nil,U.main)
    U.routeScroll:SetPoint("TOPLEFT",35,-249);U.routeScroll:SetSize(550,132);U.routeScroll:EnableMouseWheel(true)
    U.routeChild=CreateFrame("Frame",nil,U.routeScroll);U.routeChild:SetSize(550,132);U.routeScroll:SetScrollChild(U.routeChild)
    U.routeScroll:SetScript("OnMouseWheel",function(self,delta)
        local max=math.max(0,U.routeChild:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(max,(self:GetVerticalScroll() or 0)-delta*44)))
    end)
    U.stepRows={}
    U.empty=text(U.main,70,272,480,76,14,pale,"CENTER")
    U.empty:SetText("The watch is quiet.\n\nWhen the horn sounds, your guild's call will appear here.")
    U.routeNote=text(U.main,35,387,550,18,10,pale)
    fill(U.main,35,411,550,1,.68,.48,.22,.35)
    U.responders=text(U.main,35,419,550,20,11,pale)
    U.answer=button(U.main,"Answer the Call",26,454,181,function() B.Answer() end)
    U.map=button(U.main,"Show Map",215,454,117,function()
        local p=B.Destination(B.Selected());if p and not B.preview then C.OpenMap(p) end
    end)
    U.light=button(f,"Light My Beacon",416,454,179,function()
        if B.own and B.own.expires>C.Now() then B.Extinguish() else B.Light() end
    end)
    U.status=text(f,30,493,560,17,10,pale,"CENTER")
    U.optionsPanel=CreateFrame("Frame",nil,f);U.optionsPanel:SetAllPoints();U.optionsPanel:Hide()
    local op=U.optionsPanel
    local function check(label,description,y,key)
        local c=CreateFrame("CheckButton",nil,op);c:SetPoint("TOPLEFT",31,-y);c:SetSize(26,26)
        c:SetNormalTexture(media.."UI-CheckBox-Up.tga");c:SetCheckedTexture(media.."UI-CheckBox-Check.tga")
        text(op,66,y+3,516,22,13,gold):SetText(label)
        text(op,66,y+29,510,34,11,pale):SetText(description)
        c:SetScript("OnClick",function(self) B.db[key]=self:GetChecked() and true or false;U.Refresh() end)
        return c
    end
    U.sound=check("Sound the war horn", "A short horn for new calls. Uses the game's Master volume.",131,"sound")
    U.auto=check("Call automatically after a confirmed PvP death", "Requires a readable hostile-player killing blow. Otherwise, use the call-for-aid prompt.",203,"auto")
    U.prompt=check("Offer a call for aid when I fall", "A private prompt after an outdoor death. Nothing is sent until you accept.",275,"prompt")
    U.pace=button(op,"Travel pace: On foot",34,354,207,function()
        B.db.pace=B.db.pace==7 and 11.2 or B.db.pace==11.2 and 14 or 7
        if not B.navigating then B.Replan() end;U.Refresh()
    end)
    button(op,"Test horn",251,354,125,function() B.Sound(true) end)
    button(op,"Refresh flights",386,354,193,function() C.RefreshFlights(true) end)
    text(op,36,399,546,39,11,pale):SetText("Only guildmates with the addon receive your call. Beacons burn for 5 minutes, with a 60-second cooldown between calls.")
    -- A compact click-to-answer toast, with no oversized action-button row.
    local a=CreateFrame("Button","LightTheBeaconsAlert",UIParent,"BackdropTemplate");U.banner=a
    a:SetSize(520,118)
    a:SetBackdrop({bgFile=media.."UI-DialogBox-Background.tga",edgeFile=media.."UI-DialogBox-Border.tga",
        tile=true,tileSize=32,edgeSize=24,insets={left=10,right=10,top=10,bottom=10}})
    a:SetBackdropColor(.6,.48,.29,.98);a:SetBackdropBorderColor(.9,.71,.4,1)
    a:SetPoint("TOP",UIParent,"TOP",0,-125);a:SetFrameStrata("DIALOG")
    U.flame=texture(a,"Torch",23,31,42,42);U.flame:SetTexCoord(.08,.92,.08,.92)
    U.alertTitle=text(a,81,20,401,26,20,gold);U.alertTitle:SetText("The beacons are lit!")
    U.alertName=text(a,82,49,408,20,14,pale)
    U.alertZone=text(a,82,73,408,16,11,gold)
    text(a,82,94,408,14,10,pale):SetText("Click to answer the call  -  Right-click to dismiss")
    a:RegisterForClicks("LeftButtonUp","RightButtonUp")
    a:SetScript("OnClick",function(_,mouse)
        if mouse=="RightButton" then a:Hide();return end
        local b=U.alertBeacon
        if b and b.owner~="preview" and B.session.beacons[b.owner] then
            B.Select(B.session.beacons[b.owner]);B.Answer();U.options=false;f:Show()
        elseif b and b.owner=="preview" then U.options=false;f:Show() end
        a:Hide()
    end)
    a:Hide();a.elapsed=0
    a:SetScript("OnUpdate",function(self,delta)
        self.elapsed=self.elapsed+delta;U.flame:SetAlpha(.88+.12*math.sin(self.elapsed*3))
        if self.elapsed>22 then self:Hide() end
    end)
    local d=panel(UIParent,"LightTheBeaconsDeathPrompt",410,128);U.deathPrompt=d
    d:SetPoint("CENTER",UIParent,"CENTER",0,-170);d:SetFrameStrata("DIALOG")
    texture(d,"Torch",23,23,34,34):SetTexCoord(.08,.92,.08,.92)
    text(d,77,21,310,25,18,gold):SetText("Call for aid?")
    U.deathText=text(d,77,49,310,32,12,pale)
    button(d,"Light the Beacons",74,87,183,function() B.Light(U.deathConfirmed and "pvp" or "fallen") end)
    button(d,"Dismiss",266,87,119,function() d:Hide() end);d:Hide()
    local h=panel(UIParent,"LightTheBeaconsGuide",350,94);U.hud=h
    h:SetPoint("TOP",UIParent,"TOP",0,-265);h:SetFrameStrata("MEDIUM");draggable(h)
    U.arrow=texture(h,"Arrow",20,30,36,36)
    U.next=text(h,69,19,245,33,13,gold)
    U.distance=text(h,69,58,245,20,11,pale)
    closeButton(h,315,10,function() B.navigating=false;h:Hide() end);h:Hide()
    if Minimap then
        local m=CreateFrame("Button","LightTheBeaconsMinimap",Minimap,"BackdropTemplate");U.minimap=m
        m:SetSize(30,30);m:SetPoint("TOPLEFT",Minimap,"TOPLEFT",0,0);m:SetFrameStrata("MEDIUM")
        m:SetNormalTexture(media.."Torch.tga");m:RegisterForClicks("LeftButtonUp","RightButtonUp")
        m:SetScript("OnClick",function(_,mouse) U.Toggle(mouse=="RightButton") end)
        tip(m,"Light the Beacons","Left-click: open beacons\nRight-click: options\n/ltb light: call for aid")
    end
    f:Hide()
end
function U.Toggle(options)
    if not U.frame then return end
    B.preview=nil
    if options then U.options=true;U.frame:Show()
    else U.frame:SetShown(not U.frame:IsShown()) end
    if U.frame:IsShown() and not B.navigating then B.Replan() end
    U.Refresh()
end
function U.Alert(b,preview)
    if not U.banner then return end
    U.alertBeacon=b
    U.alertName:SetText(b.name.." calls for aid!")
    U.alertZone:SetText((preview and "PREVIEW - " or "")..C.Zone(b.map).."  |  "..(reasons[b.reason] or "Calls for aid"))
    U.banner.elapsed=0;U.banner:Show()
end
function U.PromptDeath(confirmed)
    U.deathConfirmed=confirmed
    U.deathText:SetText(confirmed and "A hostile player struck you down." or "Rally your guildmates to your fallen body.")
    U.deathPrompt:Show()
end
function U.Refresh()
    if not U.frame or not B.db then return end
    U.main:SetShown(not U.options);U.optionsPanel:SetShown(U.options and true or false)
    U.callsTab.line:SetShown(not U.options and not B.preview)
    U.optionsTab.line:SetShown(U.options and true or false)
    U.previewTab.line:SetShown(B.preview~=nil and not U.options)
    U.subtitle:SetText(B.preview and "LOCAL PREVIEW  -  No guild messages sent" or "Stand together when the horn sounds.")
    local list=B.preview and {B.preview} or B.List()
    local selected=B.Selected()
    if not selected and #list>0 then B.selected=list[1].owner;B.Replan();selected=B.Selected() end
    U.count:SetText(#list==0 and "No active calls" or #list==1 and "1 active call" or #list.." active calls")
    U.prev:SetShown(#list>1 and not B.preview);U.nextCall:SetShown(#list>1 and not B.preview)
    U.empty:SetShown(selected==nil)
    local pace=B.db.pace==7 and "On foot" or B.db.pace==11.2 and "60% mount" or "100% mount"
    U.pace.label:SetText("Travel pace: "..pace)
    U.sound:SetChecked(B.db.sound);U.auto:SetChecked(B.db.auto);U.prompt:SetChecked(B.db.prompt)
    U.light.label:SetText(B.own and B.own.expires>C.Now() and "Extinguish My Beacon" or "Light My Beacon")
    U.light:SetEnabled(IsInGuild and IsInGuild() and true or false)
    U.status:SetText((IsInGuild and IsInGuild()) and (B.db.flightMasterScanned and
        (C.KnownCount().." confirmed flight points  -  Alerts stay within your guild's addon users") or
        "Open a flight master's map to confirm your discovered flight points") or "Join a guild to call for aid")
    U.destination:SetText(selected and selected.name or "Your guild's watch")
    U.location:SetText(selected and (C.Zone(selected.map).."  -  "..math.floor(selected.px*100+.5)..", "..math.floor(selected.py*100+.5).."  -  "..(reasons[selected.reason] or "Calls for aid")) or "Light a beacon when you need allies at your side.")
    U.age:SetText(selected and (math.max(0,C.Now()-selected.sent).." sec ago") or "")
    U.answer:SetEnabled(selected~=nil and not B.preview and selected.owner~=B.me)
    U.map:SetEnabled(selected~=nil and not B.preview)
    local plan=selected and B.route
    U.eta:SetText(not selected and "Standing by" or plan and plan.pendingFlight and "Routing after landing" or plan and not plan.unavailable and ("About "..R.Time(plan.seconds)) or "Route unavailable")
    local steps=plan and plan.steps or {}
    U.routeChild:SetHeight(math.max(132,#steps*44))
    for i=1,math.max(#steps,#U.stepRows) do
        local row=U.stepRows[i]
        if not row then
            row=CreateFrame("Frame",nil,U.routeChild);row:SetPoint("TOPLEFT",0,-((i-1)*44));row:SetSize(550,43)
            row.number=text(row,0,7,28,25,18,gold,"CENTER")
            row.title=text(row,43,3,502,20,13,pale);row.title:SetWordWrap(false)
            row.detail=text(row,43,25,502,14,10,gold);row.detail:SetWordWrap(false)
            U.stepRows[i]=row
        end
        local step=steps[i];row:SetShown(step~=nil)
        if step then
            row.number:SetText(tostring(i));row.title:SetText(U.StepTitle(step))
            local kind=step.kind=="flight" and "FLIGHT" or step.kind=="boat" and "BOAT" or step.kind=="zeppelin" and "ZEPPELIN" or "ON THE GROUND"
            local detail=kind.."  -  "..R.Time(step.seconds)
            if step.via then detail=detail.."  -  via "..table.concat(step.via,", ") end
            if step.extra and step.extra.wait then detail=detail.."  -  includes waiting time" end
            if B.navigating and i<(B.routeIndex or 1) then detail="COMPLETED" end
            row.detail:SetText(detail)
        end
    end
    U.routeScroll:SetVerticalScroll(math.min(U.routeScroll:GetVerticalScroll() or 0,math.max(0,U.routeChild:GetHeight()-132)))
    U.routeNote:SetText(not selected and "Preview a call to see the route display and alert." or plan and plan.unavailable and plan.reason or
        "Estimated travel. Follow roads around obstacles."..(#steps>3 and " Scroll for more steps." or ""))
    local names={};if selected then for _,name in pairs(selected.responders or {}) do names[#names+1]=name end end
    table.sort(names)
    U.responders:SetText(selected and (#names>0 and ("Answering: "..table.concat(names,", ")) or "Waiting for a guildmate to answer.") or "The horn reaches guildmates who have this addon.")
end
function U.MapPins()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        for _,pin in ipairs(U.pins or {}) do pin:Hide() end;return
    end
    local canvas=WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas() or WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
    local map=WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    if not canvas or not map then return end
    U.pins=U.pins or {};local i=0
    for _,b in ipairs(B.List()) do
        local p=B.Destination(b);local id,x,y=C.MapPoint(p,map)
        if id==map and x and y then
            i=i+1;local pin=U.pins[i]
            if not pin then
                pin=CreateFrame("Button",nil,canvas);pin:SetSize(24,24)
                pin:SetNormalTexture(media.."Torch.tga");pin:SetFrameLevel(canvas:GetFrameLevel()+15)
                pin:SetScript("OnClick",function(self) if self.beacon then B.Select(self.beacon);U.options=false;U.frame:Show() end end)
                pin:SetScript("OnEnter",function(self)
                    if not GameTooltip or not self.beacon then return end
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(self.beacon.name.." calls for aid!",1,.8,.3)
                    GameTooltip:AddLine("Click to view the route.",1,1,1);GameTooltip:Show()
                end)
                pin:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
                U.pins[i]=pin
            end
            pin.beacon=b;pin:ClearAllPoints();pin:SetPoint("CENTER",canvas,"TOPLEFT",x*canvas:GetWidth(),-y*canvas:GetHeight());pin:Show()
        end
    end
    for j=i+1,#U.pins do U.pins[j]:Hide() end
end
function U.Tick()
    if not U.frame then return end
    if U.frame:IsShown() then U.Refresh() end
    if U.alertBeacon and U.alertBeacon.expires<=C.Now() then U.banner:Hide() end
    U.hud:SetShown(B.navigating and B.Selected()~=nil and true or false)
    if U.hud:IsShown() then
        local p,step=B.NextTarget();local pos=C.Position()
        if not step then
            U.next:SetText(B.route and B.route.pendingFlight and "Finish your current flight" or B.route and B.route.unavailable and "Open the beacon on your map" or "You have reached the beacon area")
            U.distance:SetText("Stand with your guildmate.");U.arrow:Hide()
        else
            U.next:SetText(U.StepTitle(step))
            local distance=R.Distance(pos,p)
            U.distance:SetText(distance==math.huge and "Follow the transport to the other continent" or math.floor(distance+.5).." yards to the next waypoint")
            local facing=GetPlayerFacing and C.Call(GetPlayerFacing)
            if pos and p and pos.c==p.c and P.Number(facing,0,7) then
                local angle=math.atan2(p.y-pos.y,p.x-pos.x)-facing
                U.arrow:SetRotation(angle);U.arrow:Show()
            else U.arrow:Hide() end
        end
    end
    U.MapPins()
end
