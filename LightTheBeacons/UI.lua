local _,B=...
local U,C,R,P={},B.Client,B.Routing,B.Protocol;B.UI=U
local media="Interface\\AddOns\\LightTheBeacons\\Media\\"
local gold={1,.82,.43};local pale={.86,.90,.97};local ink={.24,.15,.08}
local brass={.80,.65,.38};local muted={.60,.66,.76}
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
local function fill(parent,x,y,w,h,r,g,b,a,layer)
    local t=parent:CreateTexture(nil,layer or "BACKGROUND")
    t:SetColorTexture(r,g,b,a or 1);t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);return t
end
local function panel(parent,name,w,h)
    local f=CreateFrame("Frame",name,parent,"BackdropTemplate")
    f:SetSize(w,h)
    f:SetBackdrop({bgFile=media.."UI-DialogBox-Background.tga",edgeFile=media.."UI-DialogBox-Border.tga",
        tile=true,tileSize=32,edgeSize=30,insets={left=8,right=8,top=8,bottom=8}})
    f:SetBackdropColor(.12,.24,.50,.99);f:SetBackdropBorderColor(.92,.76,.41,1)
    fill(f,10,10,w-20,h-20,.025,.065,.145,.97)
    return f
end
local function button(parent,label,x,y,w,fn)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,28)
    b:SetBackdrop({bgFile=media.."UI-DialogBox-Background.tga",edgeFile=media.."UI-DialogBox-Border.tga",
        tile=true,tileSize=32,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}})
    b:SetBackdropColor(.12,.31,.72,1);b:SetBackdropBorderColor(.94,.76,.40,1)
    fill(b,5,5,w-10,18,.07,.20,.47,.92)
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
    if step.kind=="flight" then return "Fly to "..(step.to.n:match("^[^,]+") or step.to.n) end
    if step.kind=="boat" then return "Boat to "..step.to.n end
    if step.kind=="zeppelin" then return "Zeppelin to "..step.to.n end
    if step.toID=="goal" then return (B.route and B.route.speed or B.TravelSpeed())>7 and "Ride to the beacon" or "Continue on foot to the beacon" end
    return ((B.route and B.route.speed or B.TravelSpeed())>7 and "Ride to " or "Travel to ")..(step.to.n:match("^[^,]+") or step.to.n)
end
function U.Cycle(delta)
    if B.preview then return end
    local list=B.List();if #list<2 then return end
    local index=1;for i,b in ipairs(list) do if b.owner==B.selected then index=i end end
    B.Select(list[(index-1+delta)%#list+1])
end
local rowPitch,rowWidth,routeHeight=44,555,128
local paces={[7]="ON FOOT",[11.2]="60% MOUNT",[14]="100% MOUNT"}
local function place(p) return p and p.n and (p.n:match("^[^,]+") or p.n) end
local function stepDetail(step)
    local parts={step.kind=="flight" and "FLIGHT" or step.kind=="boat" and "BOAT" or step.kind=="zeppelin" and "ZEPPELIN" or "GROUND"}
    local from=step.fromID=="start" and "your position" or place(step.from)
    if from then parts[#parts+1]="from "..from end
    if step.via then
        local via={};for i,n in ipairs(step.via) do via[i]=n:match("^[^,]+") or n end
        parts[#parts+1]="via "..table.concat(via,", ")
    end
    if step.extra and step.extra.wait then parts[#parts+1]="includes waiting time" end
    return table.concat(parts,"  -  ")
end
-- One itinerary line: numbered marker on a connecting rail, action, leg time, then a short detail.
local function stepRow(i)
    local row=CreateFrame("Frame",nil,U.routeChild);row:SetPoint("TOPLEFT",0,-((i-1)*rowPitch));row:SetSize(rowWidth,rowPitch-2)
    row.band=fill(row,5,-2,rowWidth-10,rowPitch,.85,.66,.29,.07)
    row.rail=fill(row,16,27,2,rowPitch-24,.85,.66,.29,.35)
    row.edge=fill(row,5,3,24,24,.85,.66,.29,.85,"BORDER")
    row.face=fill(row,6,4,22,22,.035,.09,.21,1,"ARTWORK")
    row.number=text(row,5,8,24,16,12,gold,"CENTER")
    row.check=texture(row,"UI-CheckBox-Check",6,3,22,22,"OVERLAY");row.check:SetVertexColor(unpack(brass))
    row.title=text(row,42,4,354,18,13,pale);row.title:SetWordWrap(false)
    row.time=text(row,400,5,150,16,12,gold,"RIGHT");row.time:SetWordWrap(false)
    row.detail=text(row,42,24,508,14,10,brass);row.detail:SetWordWrap(false)
    return row
end
function U.Create()
    if U.frame then return end
    local f=panel(UIParent,"LightTheBeaconsWindow",620,572);U.frame=f
    f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");draggable(f)
    UISpecialFrames[#UISpecialFrames+1]="LightTheBeaconsWindow"
    fill(f,19,18,582,83,.035,.11,.28,.98)
    fill(f,24,19,572,1,.85,.66,.29,.62)
    texture(f,"AllianceCloth",29,13,83,91,"BACKGROUND"):SetTexCoord(0,.425,0,.51)
    texture(f,"AllianceCrest",31,12,78,91):SetTexCoord(.175,.825,.09,.91)
    fill(f,128,99,445,1,.80,.62,.29,.65)
    text(f,125,34,421,30,24,gold):SetText("Light the Beacons")
    U.subtitle=text(f,127,69,410,16,11,gold)
    closeButton(f,565,24,function() f:Hide() end)
    local function tab(label,x,fn)
        local t=CreateFrame("Button",nil,f);t:SetPoint("TOPLEFT",x,-108);t:SetSize(106,27)
        t.label=text(t,2,4,102,18,13,gold,"CENTER");t.label:SetText(label)
        t.line=fill(t,6,25,94,1,.85,.64,.28,.85)
        t:SetScript("OnClick",fn);return t
    end
    U.callsTab=tab("Beacons",26,function() U.options=false;U.Refresh() end)
    U.optionsTab=tab("Options",138,function() U.options=true;U.Refresh() end)
    U.previewTab=tab("Preview",250,function()
        if B.preview then B.preview=nil;B.Replan();U.banner:Hide();U.Refresh() else U.options=false;B.Preview() end
    end)
    U.count=text(f,368,115,228,17,11,pale,"RIGHT")
    U.main=CreateFrame("Frame",nil,f);U.main:SetAllPoints()
    -- Dispatch card: why, who, then the four facts a responder needs at a glance.
    fill(U.main,25,148,570,52,.045,.125,.30,.97)
    fill(U.main,25,200,570,44,.03,.085,.205,.97)
    fill(U.main,25,148,570,1,.85,.66,.29,.55,"BORDER")
    fill(U.main,40,200,545,1,.68,.48,.22,.35,"BORDER")
    fill(U.main,25,243,570,1,.85,.66,.29,.55,"BORDER")
    fill(U.main,25,148,3,96,.98,.77,.36,1,"BORDER")
    U.reason=text(U.main,42,157,330,13,10,gold);U.reason:SetWordWrap(false)
    U.destination=text(U.main,41,170,545,26,20,gold);U.destination:SetWordWrap(false)
    U.position=text(U.main,440,176,74,14,10,muted,"RIGHT")
    U.prev=button(U.main,"<",521,166,31,function() U.Cycle(-1) end)
    U.nextCall=button(U.main,">",557,166,31,function() U.Cycle(1) end)
    U.facts=CreateFrame("Frame",nil,U.main);U.facts:SetAllPoints()
    local function fact(label,x,w,align)
        if x>42 then fill(U.facts,x-10,207,1,30,.68,.48,.22,.3,"BORDER") end
        text(U.facts,x,208,w,11,9,brass,align):SetText(label)
        local value=text(U.facts,x,220,w,18,13,pale,align);value:SetWordWrap(false);return value
    end
    U.zone=fact("ZONE",42,160);U.coords=fact("COORDINATES",222,86);U.age=fact("CALLED",328,92)
    U.eta=fact("EST. TRAVEL",440,146,"RIGHT")
    U.idle=text(U.main,42,217,540,18,12,pale);U.idle:SetText("Light a beacon when you need allies at your side.")
    -- Itinerary: numbered legs with their times in one right-hand column.
    text(U.main,40,254,200,14,11,gold):SetText("YOUR ROUTE")
    U.routeMeta=text(U.main,250,255,335,14,10,muted,"RIGHT");U.routeMeta:SetWordWrap(false)
    fill(U.main,40,271,545,1,.68,.48,.22,.45)
    U.routeScroll=CreateFrame("ScrollFrame",nil,U.main)
    U.routeScroll:SetPoint("TOPLEFT",35,-277);U.routeScroll:SetSize(rowWidth,routeHeight);U.routeScroll:EnableMouseWheel(true)
    U.routeChild=CreateFrame("Frame",nil,U.routeScroll);U.routeChild:SetSize(rowWidth,routeHeight);U.routeScroll:SetScrollChild(U.routeChild)
    U.routeScroll:SetScript("OnMouseWheel",function(self,delta)
        local max=math.max(0,U.routeChild:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(max,(self:GetVerticalScroll() or 0)-delta*rowPitch)))
    end)
    U.stepRows={}
    texture(U.main,"AllianceCrest",410,279,158,196):SetAlpha(.065)
    U.empty=text(U.main,70,304,480,76,13,pale,"CENTER")
    U.routeNote=text(U.main,40,413,545,14,10,muted);U.routeNote:SetWordWrap(false)
    fill(U.main,35,435,550,1,.68,.48,.22,.35)
    U.responders=text(U.main,35,443,550,20,11,pale)
    U.answer=button(U.main,"Answer the Call",26,478,181,function() B.Answer() end)
    U.map=button(U.main,"Show Map",215,478,117,function()
        local p=B.Destination(B.Selected());if p and not B.preview then C.OpenMap(p) end
    end)
    U.light=button(f,"Light My Beacon",416,478,179,function()
        if B.own and B.own.expires>C.Now() then B.Extinguish() else B.Light() end
    end)
    U.status=text(f,30,517,560,17,10,pale,"CENTER")
    fill(f,33,541,554,1,.57,.45,.24,.25)
    text(f,32,548,556,13,9,{.56,.63,.73},"CENTER"):SetText("Made by Whitebeard Tinkerton - US PVP")
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
    U.sound=check("Sound the war horn", "A deep WoW horn for calls; an Alliance fanfare for your first responder.",148,"sound")
    U.auto=check("Call automatically after a confirmed PvP death", "Requires a readable hostile-player killing blow. Otherwise, use the call-for-aid prompt.",216,"auto")
    U.prompt=check("Offer a call for aid when I fall", "A private prompt after an outdoor death. Nothing is sent until you accept.",284,"prompt")
    U.pace=button(op,"Auto: On foot",34,354,207,function() B.ToggleTravelMode() end)
    tip(U.pace,"Travel pace","Auto uses your trained riding tier: on foot, 60%, or 100%. Click to switch between Auto and an on-foot override.")
    button(op,"Test horn",251,354,125,function() B.Sound(true) end)
    button(op,"Refresh flights",386,354,193,function() C.RefreshFlights(true) end)
    button(op,"Preview the rally",34,391,207,function() U.Answered("Elowen Dawnwatch",1,true,nil,true);B.Sound(true,true) end)
    text(op,36,432,546,34,11,pale):SetText("Only guildmates with the addon receive your call. Beacons last 5 minutes; calls have a 60-second cooldown.")
    -- A compact click-to-answer toast, with no oversized action-button row.
    local a=CreateFrame("Button","LightTheBeaconsAlert",UIParent,"BackdropTemplate");U.banner=a
    a:SetSize(520,118)
    a:SetBackdrop({bgFile=media.."UI-DialogBox-Background.tga",edgeFile=media.."UI-DialogBox-Border.tga",
        tile=true,tileSize=32,edgeSize=24,insets={left=10,right=10,top=10,bottom=10}})
    a:SetBackdropColor(.12,.25,.55,1);a:SetBackdropBorderColor(.95,.78,.43,1)
    fill(a,11,11,498,96,.035,.11,.27,.97)
    a:SetPoint("TOP",UIParent,"TOP",0,-125);a:SetFrameStrata("DIALOG")
    U.flame=texture(a,"AllianceCrest",20,24,53,66);U.flame:SetTexCoord(.175,.825,.09,.91)
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
    -- First responder earns the full rally; later allies update a shorter pulse.
    local answer=panel(UIParent,"LightTheBeaconsAnswer",560,148);U.answerBanner=answer
    answer:SetPoint("TOP",UIParent,"TOP",0,-120);answer:SetFrameStrata("DIALOG")
    answer:SetBackdropBorderColor(1,.84,.45,1)
    fill(answer,23,17,514,1,.95,.74,.31,.65)
    U.answerGlow=texture(answer,"AllianceGlow",17,17,98,114);U.answerGlow:SetAlpha(.55);U.answerGlow:SetVertexColor(1,.70,.22)
    U.answerGlow:SetTexCoord(.175,.825,.09,.91)
    texture(answer,"AllianceCrest",24,24,84,98):SetTexCoord(.175,.825,.09,.91)
    U.answerTitle=text(answer,121,24,415,28,21,gold)
    U.answerName=text(answer,123,60,410,23,16,pale);U.answerName:SetWordWrap(false)
    text(answer,123,86,410,20,13,pale):SetText("is coming to your aid.")
    U.answerCount=text(answer,123,116,410,17,11,gold)
    answer:SetScript("OnUpdate",function(self,delta)
        self.elapsed=(self.elapsed or 0)+delta
        local t=self.elapsed;local duration=self.duration or 7
        self:SetAlpha(math.min(1,t/.18,math.max(0,(duration-t)/.8)))
        U.answerGlow:SetAlpha(.30+.40*math.exp(-t/2)*(.5+.5*math.cos(t*7)))
        if t>=duration or (self.beacon and (self.beacon.expires<=C.Now() or B.own~=self.beacon)) then self:Hide() end
    end)
    answer:Hide()
    f:Hide()
end
function U.Answered(name,count,first,beacon,preview)
    if not U.answerBanner then return end
    local a=U.answerBanner
    U.answerTitle:SetText(preview and "RALLY PREVIEW" or first and "THE ALLIANCE ANSWERS!" or "REINFORCEMENTS INBOUND")
    U.answerTitle:SetFont("Fonts\\FRIZQT__.TTF",first and 21 or 18,"")
    U.answerName:SetText(name)
    U.answerCount:SetText(count..(count==1 and " ALLY ON THE WAY" or " ALLIES ON THE WAY"))
    a.beacon=beacon;a.elapsed=.18;a.duration=first and 7 or 4
    a:SetAlpha(1);U.answerGlow:SetAlpha(first and .7 or .4);a:Show()
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
    U.subtitle:SetText(B.preview and "LOCAL PREVIEW  -  No guild messages sent" or "FOR THE ALLIANCE")
    local list=B.preview and {B.preview} or B.List()
    local selected=B.Selected()
    if not selected and #list>0 then B.selected=list[1].owner;B.Replan();selected=B.Selected() end
    U.count:SetText(#list==0 and "No active calls" or #list==1 and "1 active call" or #list.." active calls")
    U.prev:SetShown(#list>1 and not B.preview);U.nextCall:SetShown(#list>1 and not B.preview)
    U.pace.label:SetText(B.TravelLabel())
    U.sound:SetChecked(B.db.sound);U.auto:SetChecked(B.db.auto);U.prompt:SetChecked(B.db.prompt)
    U.light.label:SetText(B.own and B.own.expires>C.Now() and "Extinguish My Beacon" or "Light My Beacon")
    U.light:SetEnabled(IsInGuild and IsInGuild() and true or false)
    U.status:SetText((IsInGuild and IsInGuild()) and (B.db.flightMasterScanned and
        (C.KnownCount().." confirmed flight points  -  Alerts stay within your guild's addon users") or
        "Open a flight master's map to confirm your discovered flight points") or "Join a guild to call for aid")
    local multi=#list>1 and not B.preview
    local index=1;for i,b in ipairs(list) do if selected and b.owner==selected.owner then index=i end end
    U.position:SetText(multi and (index.." of "..#list) or "")
    U.reason:SetText(selected and (reasons[selected.reason] or "Calls for aid"):upper() or "STANDING BY")
    U.destination:SetText(selected and selected.name or "Your guild's watch")
    U.destination:SetWidth(multi and 395 or 545)
    U.facts:SetShown(selected~=nil);U.idle:SetShown(selected==nil)
    if selected then
        U.zone:SetText(C.Zone(selected.map))
        U.coords:SetText(math.floor(selected.px*100+.5)..", "..math.floor(selected.py*100+.5))
        U.age:SetText(math.max(0,C.Now()-selected.sent).." sec ago")
    end
    U.answer:SetEnabled(selected~=nil and not B.preview and selected.owner~=B.me)
    U.map:SetEnabled(selected~=nil and not B.preview)
    local plan=selected and B.route
    local routed=plan and not plan.unavailable
    U.eta:SetText(plan and plan.pendingFlight and "Routing after landing" or routed and R.Time(plan.seconds) or "Route unavailable")
    U.eta:SetTextColor(unpack(routed and gold or pale));U.eta:SetFont("Fonts\\FRIZQT__.TTF",routed and 14 or 12,"")
    local steps=plan and plan.steps or {}
    local meta={}
    if routed and paces[plan.speed] then meta[#meta+1]=paces[plan.speed] end
    if #steps>0 then meta[#meta+1]=#steps..(#steps==1 and " STEP" or " STEPS") end
    local listHeight=math.max(routeHeight,#steps*rowPitch-4)
    if listHeight>routeHeight then meta[#meta+1]="SCROLL FOR MORE" end
    U.routeMeta:SetText(table.concat(meta,"  -  "))
    U.routeChild:SetHeight(listHeight)
    local at=B.navigating and (B.routeIndex or 1) or 0
    for i=1,math.max(#steps,#U.stepRows) do
        local row=U.stepRows[i] or stepRow(i);U.stepRows[i]=row
        local step=steps[i];row:SetShown(step~=nil)
        if step then
            local done,current=i<at,i==at
            row.band:SetShown(current);row.rail:SetShown(i<#steps)
            row.edge:SetAlpha(done and .45 or 1)
            row.face:SetColorTexture(unpack(current and {.98,.77,.36,1} or {.035,.09,.21,1}))
            row.number:SetText(tostring(i));row.number:SetShown(not done);row.check:SetShown(done)
            row.number:SetTextColor(unpack(current and ink or gold));row.number:SetShadowColor(0,0,0,current and 0 or .9)
            row.title:SetText(U.StepTitle(step));row.title:SetTextColor(unpack(done and muted or pale))
            row.time:SetText(R.Time(step.seconds));row.time:SetTextColor(unpack(done and muted or gold))
            row.detail:SetText(done and "COMPLETED" or stepDetail(step));row.detail:SetTextColor(unpack(done and muted or brass))
        end
    end
    U.routeScroll:SetVerticalScroll(math.min(U.routeScroll:GetVerticalScroll() or 0,math.max(0,U.routeChild:GetHeight()-routeHeight)))
    local message=not selected and "The watch is quiet.\n\nWhen the horn sounds, your guild's call will appear here." or
        not plan and "Route unavailable.\n\nOpen the beacon on your map." or #steps==0 and (plan.reason or "Route unavailable.") or nil
    U.empty:SetText(message or "");U.empty:SetShown(message~=nil)
    U.routeNote:SetText(not selected and "Preview a call to see the route display and alert." or
        #steps>0 and "Estimated travel. Follow roads around obstacles." or "")
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
