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
    f.surface=fill(f,10,10,w-20,h-20,.025,.065,.145,.97)
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
U.Widgets={text=text,texture=texture,fill=fill,panel=panel,button=button,tip=tip}
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
local rowPitch,rowWidth,routeHeight=48,368,144
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
    row.title=text(row,36,4,247,18,12,pale);row.title:SetWordWrap(false)
    row.time=text(row,285,5,78,16,11,gold,"RIGHT");row.time:SetWordWrap(false)
    row.detail=text(row,36,24,327,18,11,brass);row.detail:SetWordWrap(false)
    row:EnableMouse(true)
    return row
end
function U.Create()
    if U.frame then return end
    local f=panel(UIParent,"LightTheBeaconsWindow",400,180);U.frame=f
    f:SetBackdrop({bgFile=media.."UI-DialogBox-Background.tga",edgeFile=media.."UI-DialogBox-Border.tga",
        tile=true,tileSize=32,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}})
    f.surface:ClearAllPoints();f.surface:SetPoint("TOPLEFT",6,-6);f.surface:SetSize(388,168)
    f:SetPoint("TOP",UIParent,"CENTER",0,120);f:SetFrameStrata("DIALOG");draggable(f)
    UISpecialFrames[#UISpecialFrames+1]="LightTheBeaconsWindow"
    fill(f,6,6,388,38,.045,.12,.27,1)
    fill(f,6,44,388,1,.80,.65,.38,.7)
    texture(f,"AllianceCrest",16,12,22,27):SetTexCoord(.175,.825,.09,.91)
    text(f,44,15,187,22,16,gold):SetText("Light the Beacons")
    local function link(parent,label,x,y,w,fn)
        local b=CreateFrame("Button",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,28)
        b.label=text(b,0,7,w,18,11,gold,"CENTER");b.label:SetText(label)
        b:SetScript("OnClick",fn)
        b:SetScript("OnEnable",function() b.label:SetTextColor(unpack(gold)) end)
        b:SetScript("OnDisable",function() b.label:SetTextColor(unpack(muted)) end)
        return b
    end
    U.light=link(f,"Light mine",236,12,61,function()
        if B.own and B.own.expires>C.Now() then B.Select(B.own);U.options=false;U.Refresh()
        else B.RequestLight() end
    end)
    U.optionsButton=link(f,"Options",303,12,48,function()
        if U.settingsPage then U.settingsPage=nil;U.options=true else U.options=not U.options end
        U.Refresh()
    end)
    tip(U.optionsButton,"Options","Sound, automatic calls, travel pace, quick messages and credits.")
    closeButton(f,365,10,function() f:Hide() end)
    U.main=CreateFrame("Frame",nil,f);U.main:SetAllPoints()
    U.beacon=texture(U.main,"RoyalBrazier",16,55,32,36)
    U.destination=text(U.main,58,55,248,23,17,gold);U.destination:SetWordWrap(false)
    U.identity=CreateFrame("Frame",nil,U.main);U.identity:SetPoint("TOPLEFT",58,-52);U.identity:SetSize(248,26);U.identity:EnableMouse(true)
    U.eta=text(U.main,308,58,76,18,12,gold,"RIGHT");U.eta:SetWordWrap(false)
    U.summary=text(U.main,58,82,326,17,11,muted);U.summary:SetWordWrap(false)
    U.callMessage=text(U.main,16,106,368,31,12,pale);U.callMessage:SetNonSpaceWrap(true)
    U.answer=button(U.main,"Answer the Call",16,139,169,function()
        local b=B.Selected()
        if not b then B.RequestLight()
        elseif b.owner==B.me then B.Extinguish()
        else B.Answer() end
    end)
    U.expand=link(U.main,"Details +",310,139,74,function() U.expanded=not U.expanded;U.Refresh() end)
    U.brief=CreateFrame("Frame",nil,U.main);U.brief:SetSize(368,38)
    fill(U.brief,0,0,368,38,.045,.13,.29,1)
    fill(U.brief,0,0,2,38,.85,.66,.29,.9)
    U.briefText=text(U.brief,9,6,349,30,12,pale);U.briefText:SetNonSpaceWrap(true)
    -- Simultaneous calls use a quiet pager, present only when there is a choice.
    U.pager=CreateFrame("Frame",nil,U.main);U.pager:SetSize(368,28)
    U.prev=link(U.pager,"<",0,0,30,function() U.Cycle(-1) end)
    U.position=text(U.pager,38,7,292,16,11,muted,"CENTER")
    U.nextCall=link(U.pager,">",338,0,30,function() U.Cycle(1) end)
    U.details=CreateFrame("Frame",nil,U.main);U.details:SetSize(400,304)
    fill(U.details,16,0,368,1,.80,.65,.38,.45)
    U.reason=text(U.details,16,12,180,16,11,gold)
    U.routeMeta=text(U.details,190,12,194,16,11,muted,"RIGHT");U.routeMeta:SetWordWrap(false)
    U.routeScroll=CreateFrame("ScrollFrame",nil,U.details)
    U.routeScroll:SetPoint("TOPLEFT",16,-36);U.routeScroll:SetSize(rowWidth,routeHeight);U.routeScroll:EnableMouseWheel(true)
    U.routeChild=CreateFrame("Frame",nil,U.routeScroll);U.routeChild:SetSize(rowWidth,routeHeight);U.routeScroll:SetScrollChild(U.routeChild)
    U.routeScroll:SetScript("OnMouseWheel",function(self,delta)
        local max=math.max(0,U.routeChild:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(max,(self:GetVerticalScroll() or 0)-delta*rowPitch)))
    end)
    U.stepRows={}
    U.empty=text(U.details,20,44,360,76,12,pale)
    U.routeNote=text(U.details,16,190,368,30,11,muted)
    U.location=text(U.details,16,223,368,17,11,pale)
    U.age=text(U.details,16,244,368,17,11,muted)
    U.responderBox=CreateFrame("Frame",nil,U.details);U.responderBox:SetPoint("TOPLEFT",16,-267);U.responderBox:SetSize(368,44);U.responderBox:EnableMouse(true)
    U.responders=text(U.responderBox,0,0,368,44,11,pale);U.responders:SetNonSpaceWrap(true)
    U.map=button(U.details,"Show Map",16,318,116,function()
        local p=B.Destination(B.Selected());if p and not B.preview then C.OpenMap(p) end
    end)
    U.stop=button(U.details,"Stop guidance",204,318,180,function() B.navigating=false;U.Tick() end)
    U.details:SetHeight(358)
    U.optionsPanel=CreateFrame("Frame",nil,f);U.optionsPanel:SetAllPoints();U.optionsPanel:Hide()
    local op=U.optionsPanel
    local function check(label,description,y,key)
        local c=CreateFrame("CheckButton",nil,op);c:SetPoint("TOPLEFT",16,-y);c:SetSize(24,24)
        c:SetNormalTexture(media.."UI-CheckBox-Up.tga");c:SetCheckedTexture(media.."UI-CheckBox-Check.tga")
        text(op,47,y+3,335,22,12,gold):SetText(label)
        text(op,47,y+27,335,35,11,pale):SetText(description)
        c:SetScript("OnClick",function(self) B.db[key]=self:GetChecked() and true or false;U.Refresh() end)
        return c
    end
    U.sound=check("Sound the war horn","Deep WoW horn for calls; Alliance fanfare for your first responder.",56,"sound")
    U.auto=check("Automatic PvP death alerts","Needs a readable hostile-player killing blow. Use the death prompt when attribution is unavailable.",126,"auto")
    U.prompt=check("Offer a call for aid when I fall","Private prompt after an outdoor death. Nothing is sent until you accept.",204,"prompt")
    U.pace=button(op,"Auto: On foot",16,278,232,function() B.ToggleTravelMode() end)
    tip(U.pace,"Travel pace","Auto uses your trained riding tier: on foot, 60%, or 100%. Click to switch between Auto and an on-foot override.")
    button(op,"Test horn",258,278,126,function() B.Sound(true) end)
    button(op,"Refresh flights",16,316,175,function() C.RefreshFlights(true) end)
    button(op,"Preview the rally",201,316,183,function() U.Answered("Elowen Dawnwatch",1,true,nil,true);B.Sound(true,true) end)
    button(op,"Quick messages",16,354,175,function() U.Compose() end)
    U.previewButton=button(op,"Preview a call",201,354,183,function()
        U.options=false;U.expanded=false;B.Preview()
    end)
    button(op,"Map & beacon controls",16,392,232,function() U.OpenSettingsPage("controls") end)
    button(op,"Player filters",258,392,126,function() U.OpenSettingsPage("filters") end)
    U.status=text(op,16,435,368,34,11,pale)
    text(op,16,476,368,32,11,muted):SetText("Only guild addon users receive calls. Beacons last 5 minutes; calls have a 60-second cooldown.")
    fill(op,16,520,368,1,.57,.45,.24,.3)
    U.credit=text(op,16,530,368,16,11,muted);U.credit:SetText("Made by Whitebeard Tinkerton - US PVP")
    -- Compose locally; choosing or saving a template never broadcasts it.
    local composer=panel(UIParent,"LightTheBeaconsComposer",620,418);U.composer=composer
    composer:SetPoint("CENTER");composer:SetFrameStrata("FULLSCREEN_DIALOG");draggable(composer)
    UISpecialFrames[#UISpecialFrames+1]="LightTheBeaconsComposer"
    texture(composer,"AllianceCrest",25,17,58,70):SetTexCoord(.175,.825,.09,.91)
    text(composer,99,30,448,28,22,gold):SetText("Rally your allies")
    text(composer,101,63,450,16,11,pale):SetText("Give your guildmates a reason to ride.")
    closeButton(composer,565,23,function() composer:Hide() end)
    text(composer,30,101,400,16,12,gold):SetText("YOUR MESSAGE  (optional)")
    U.messageCount=text(composer,500,103,88,14,10,muted,"RIGHT")
    local field=CreateFrame("Frame",nil,composer,"BackdropTemplate")
    field:SetPoint("TOPLEFT",30,-123);field:SetSize(560,38)
    field:SetBackdrop({bgFile=media.."UI-DialogBox-Background.tga",edgeFile=media.."UI-DialogBox-Border.tga",tile=true,tileSize=32,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}})
    field:SetBackdropColor(.035,.09,.21,1);field:SetBackdropBorderColor(.80,.65,.38,1)
    local edit=CreateFrame("EditBox",nil,field);U.messageEdit=edit
    edit:SetPoint("TOPLEFT",10,-8);edit:SetSize(540,22);edit:SetFont("Fonts\\FRIZQT__.TTF",13,"")
    edit:SetTextColor(unpack(pale));edit:SetAutoFocus(false);edit:SetMultiLine(false)
    edit:SetMaxLetters(P.messageLimit);edit:SetMaxBytes(P.messageLimit*4)
    edit:SetScript("OnTextChanged",function(self)
        local clean,count=P.Message(self:GetText(),true)
        if clean~=self:GetText() then self:SetText(clean) end
        U.messageCount:SetText(count.." / "..P.messageLimit)
    end)
    edit:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    edit:SetScript("OnEscapePressed",function() composer:Hide() end)
    composer:SetScript("OnHide",function() edit:ClearFocus() end)
    text(composer,32,169,556,15,10,muted):SetText("Shown on your allies' alert and beacon card. Leave blank to just sound the horn.")
    text(composer,30,198,560,16,11,gold):SetText("QUICK MESSAGES  -  Saved for this character")
    U.templates={}
    for i=1,3 do
        local slot=i;local y=222+(i-1)*38
        text(composer,30,y+8,18,16,12,gold):SetText(tostring(slot))
        local use=button(composer,"Empty slot",52,y,344,function()
            edit:SetText(B.db.messages[slot] or "");edit:SetFocus();edit:SetCursorPosition(#edit:GetText())
        end)
        use.label:SetJustifyH("LEFT");use.label:SetWordWrap(false)
        local save=button(composer,"Save current",406,y,100,function()
            B.SaveTemplate(slot,edit:GetText());U.RefreshTemplates()
        end)
        tip(save,"Save quick message "..slot,"Save the text above into this slot. To change a message, select it, edit the text and save again.")
        local clear=button(composer,"Clear",516,y,72,function() B.SaveTemplate(slot,"");U.RefreshTemplates() end)
        U.templates[slot]={use=use,save=save,clear=clear}
    end
    text(composer,32,342,556,15,10,muted):SetText("Only guildmates using the addon receive your call.")
    U.composeCancel=button(composer,"Cancel",276,371,102,function() composer:Hide() end)
    U.composeSend=button(composer,"Light the Beacons",390,371,198,function() B.Light(U.composeReason,edit:GetText()) end)
    composer:Hide()
    -- A compact click-to-answer toast, with no oversized action-button row.
    local a=CreateFrame("Button","LightTheBeaconsAlert",UIParent,"BackdropTemplate");U.banner=a
    a:SetSize(520,118)
    a:SetBackdrop({bgFile=media.."UI-DialogBox-Background.tga",edgeFile=media.."UI-DialogBox-Border.tga",
        tile=true,tileSize=32,edgeSize=24,insets={left=10,right=10,top=10,bottom=10}})
    a:SetBackdropColor(.12,.25,.55,1);a:SetBackdropBorderColor(.95,.78,.43,1)
    U.alertBack=fill(a,11,11,498,96,.035,.11,.27,.97)
    a:SetPoint("TOP",UIParent,"TOP",0,-125);a:SetFrameStrata("DIALOG")
    U.flame=texture(a,"RoyalBrazier",20,29,53,53)
    U.alertTitle=text(a,81,20,401,26,20,gold);U.alertTitle:SetText("The beacons are lit!")
    U.alertName=text(a,82,49,408,20,14,pale)
    U.alertZone=text(a,82,73,408,16,11,gold)
    U.alertMessage=text(a,82,96,408,32,12,pale);U.alertMessage:SetNonSpaceWrap(true)
    U.alertHint=text(a,82,94,408,14,10,pale);U.alertHint:SetText("Click to answer the call  -  Right-click to dismiss")
    a:RegisterForClicks("LeftButtonUp","RightButtonUp")
    a:SetScript("OnClick",function(_,mouse)
        if mouse=="RightButton" then a:Hide();return end
        local b=U.alertBeacon
        if b and b.owner~="preview" and B.session.beacons[b.owner] then
            B.Select(B.session.beacons[b.owner])
            if b.owner~=B.me then B.Answer() end
            U.options=false;U.Refresh();f:Show()
        elseif b and b.owner=="preview" then U.options=false;U.Refresh();f:Show() end
        a:Hide()
    end)
    a:Hide();a.elapsed=0
    a:SetScript("OnUpdate",function(self,delta)
        self.elapsed=self.elapsed+delta;U.flame:SetAlpha(.88+.12*math.sin(self.elapsed*3))
        if self.elapsed>22 then self:Hide() end
    end)
    local d=panel(UIParent,"LightTheBeaconsDeathPrompt",410,128);U.deathPrompt=d
    d:SetPoint("CENTER",UIParent,"CENTER",0,-170);d:SetFrameStrata("DIALOG")
    texture(d,"RoyalBrazier",23,23,34,34)
    text(d,77,21,310,25,18,gold):SetText("Call for aid?")
    U.deathText=text(d,77,49,310,32,12,pale)
    U.deathCall=button(d,"Light the Beacons",74,87,183,function() B.RequestLight(U.deathConfirmed and "pvp" or "fallen");d:Hide() end)
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
        m:SetNormalTexture(media.."RoyalBrazier.tga");m:RegisterForClicks("LeftButtonUp","RightButtonUp")
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
    answer:SetScript("OnHide",function()
        local pending=U.pendingAlert;U.pendingAlert=nil
        if pending and (pending.preview or B.session.beacons[pending.beacon.owner]==pending.beacon) and pending.beacon.expires>C.Now() then
            U.Alert(pending.beacon,pending.preview)
        end
    end)
    answer:Hide()
    U.CreateControls()
    f:Hide()
end
function U.Answered(name,count,first,beacon,preview)
    if not U.answerBanner then return end
    local a=U.answerBanner
    if U.banner:IsShown() then
        if U.alertBeacon and U.alertBeacon.owner~=B.me then U.pendingAlert={beacon=U.alertBeacon,preview=U.alertPreview} end
        U.banner:Hide()
    end
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
    if options then U.options=true;U.settingsPage=nil;U.frame:Show()
    else U.frame:SetShown(not U.frame:IsShown()) end
    if U.frame:IsShown() and not B.navigating then B.Replan() end
    U.Refresh()
end
function U.RefreshTemplates()
    for slot,row in ipairs(U.templates) do
        local message=B.db.messages[slot]
        row.use.label:SetText(message or "Empty slot")
        row.use:SetEnabled(message~=nil);row.clear:SetEnabled(message~=nil)
        tip(row.use,"Quick message "..slot,message or "Type a message above, then choose Save current.")
    end
end
function U.Compose(reason)
    if not U.composer then return end
    U.composeReason=reason
    if not U.composer:IsShown() then U.messageEdit:SetText("") end
    U.RefreshTemplates();U.composer:Show();U.messageEdit:SetFocus()
end
function U.UpdateAlertMessage(b)
    if U.alertBeacon~=b then return end
    local message=b.message and b.message~="" and b.message
    U.alertMessage:SetText(message and ('"'..message..'"') or "")
    U.alertMessage:SetShown(message~=nil)
    U.banner:SetHeight(message and 158 or 118)
    U.alertBack:SetHeight(message and 136 or 96)
    U.alertHint:ClearAllPoints();U.alertHint:SetPoint("TOPLEFT",82,message and -134 or -94)
end
function U.Alert(b,preview)
    if not U.banner then return end
    if b.owner==B.me or (not preview and B.BeaconMode(b.owner)~="normal") then return end
    if U.answerBanner and U.answerBanner:IsShown() then U.pendingAlert={beacon=b,preview=preview};return end
    U.alertBeacon=b
    U.alertPreview=preview
    U.alertName:SetText(b.name.." calls for aid!")
    U.alertHint:SetText("Click to answer the call  -  Right-click to dismiss")
    U.alertZone:SetText((preview and "PREVIEW - " or "")..C.Zone(b.map).."  |  "..(reasons[b.reason] or "Calls for aid"))
    U.UpdateAlertMessage(b)
    U.banner.elapsed=0;U.banner:Show()
end
function U.PromptDeath(confirmed)
    U.deathConfirmed=confirmed
    U.deathText:SetText(confirmed and "A hostile player struck you down." or "Rally your guildmates to your fallen body.")
    U.deathPrompt:Show()
end
function U.Refresh()
    if not U.frame or not B.db then return end
    local function position(frame,x,y)
        frame:ClearAllPoints();frame:SetPoint("TOPLEFT",x,-y)
    end
    U.main:SetShown(not U.options);U.optionsPanel:SetShown(U.options and not U.settingsPage and true or false)
    U.optionsButton.label:SetText(U.options and "Back" or "Options")
    local list=B.preview and {B.preview} or B.List()
    local selected=B.Selected()
    if not selected and #list>0 then B.selected=list[1].owner;B.Replan();selected=B.Selected() end
    local own=selected and selected.owner==B.me
    local navigating=selected and not own and not B.preview and B.navigating
    local guild=IsInGuild and IsInGuild() and true or false
    local id=selected and selected.id
    if U.selectionID~=id then U.selectionID=id;U.routeScroll:SetVerticalScroll(0) end
    U.pace.label:SetText(B.TravelLabel())
    U.sound:SetChecked(B.db.sound);U.auto:SetChecked(B.db.auto);U.prompt:SetChecked(B.db.prompt)
    U.light.label:SetText(B.own and B.own.expires>C.Now() and "My beacon" or "Light mine")
    U.light:SetEnabled(guild)
    U.status:SetText(guild and (B.db.flightMasterScanned and
        (C.KnownCount().." confirmed flight points. Open a flight master's map to refresh them.") or
        "Open a flight master's map to confirm your discovered flight points.") or "Join a guild to call for aid.")
    local names={};if selected then for _,name in pairs(selected.responders or {}) do names[#names+1]=name end end
    table.sort(names)
    U.destination:SetText(selected and selected.name or "Your guild's watch")
    tip(U.identity,selected and selected.name or "Your guild's watch",selected and
        (C.Zone(selected.map).." - "..(reasons[selected.reason] or reasons.aid)) or "No active calls.")
    local allies=#names..(#names==1 and " ally" or " allies")
    U.summary:SetText(selected and ((B.preview and "PREVIEW - " or own and "Beacon lit - " or C.Zone(selected.map).." - ")..
        allies..(own and " coming to you" or " answering")) or U.confirmedClearUntil and U.confirmedClearUntil>GetTime() and "Beacon extinguished" or guild and "No active calls" or "Join a guild to call for aid")
    U.beacon:SetAlpha(selected and 1 or .45)
    local callMessage=selected and selected.message
    local hasMessage=callMessage and callMessage~=""
    U.callMessage:SetText(hasMessage and ('"'..callMessage..'"') or not selected and "Light a beacon when you need allies at your side." or "")
    U.callMessage:SetShown(hasMessage or not selected)
    local actionsY=(hasMessage or not selected) and 139 or 107
    position(U.answer,16,actionsY);position(U.expand,310,actionsY)
    U.answer.label:SetText(not selected and "Light My Beacon" or own and "Extinguish My Beacon" or B.preview and "Preview only" or
        navigating and "On my way" or selected.responders and selected.responders[B.me] and "Resume route" or "Answer the Call")
    U.answer:SetEnabled(guild and not B.preview and not navigating)
    U.expand.label:SetText(U.expanded and "Less -" or "Details +");U.expand:SetShown(selected~=nil)
    U.map:SetEnabled(selected~=nil and not B.preview)
    U.stop:SetShown(navigating and true or false)
    local plan=selected and not own and B.route
    local routed=plan and not plan.unavailable
    U.eta:SetShown(selected~=nil and not own)
    U.eta:SetText(plan and plan.pendingFlight and "On taxi" or routed and
        (plan.seconds<60 and R.Time(plan.seconds) or "~"..math.floor(plan.seconds/60+.5).." min") or "No route")
    local steps=plan and plan.steps or {}
    local meta={}
    if routed and paces[plan.speed] then meta[#meta+1]=paces[plan.speed] end
    if #steps>0 then meta[#meta+1]=#steps..(#steps==1 and " STEP" or " STEPS") end
    U.routeMeta:SetText(table.concat(meta," - "))
    U.reason:SetText(own and "YOUR BEACON" or "YOUR ROUTE")
    local viewport=math.min(routeHeight,math.max(rowPitch,#steps*rowPitch))
    U.routeScroll:SetHeight(viewport);U.routeChild:SetHeight(math.max(viewport,#steps*rowPitch))
    U.routeScroll:SetShown(#steps>0 and not own)
    local at=navigating and (B.routeIndex or 1) or 0
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
            tip(row,U.StepTitle(step),stepDetail(step).."\nEstimated travel: "..R.Time(step.seconds))
        end
    end
    U.routeScroll:SetVerticalScroll(math.min(U.routeScroll:GetVerticalScroll() or 0,math.max(0,U.routeChild:GetHeight()-viewport)))
    local message=own and "Your beacon is lit. Allies plan their own routes to you." or
        not selected and "The watch is quiet." or #steps==0 and (plan and plan.reason or "Route unavailable. Open the beacon on your map.") or nil
    U.empty:SetText(message or "");U.empty:SetShown(message~=nil)
    local routeBottom=36+(own and 44 or #steps>0 and viewport or 76)
    position(U.routeNote,16,routeBottom+6)
    U.routeNote:SetText(#steps>0 and ("Estimated travel. Follow roads around obstacles."..(#steps*rowPitch>viewport and " Scroll for more steps." or "")) or "")
    local factsY=routeBottom+(#steps>0 and 40 or 8)
    position(U.location,16,factsY);position(U.age,16,factsY+20);position(U.responderBox,16,factsY+44)
    if selected then
        U.location:SetText(C.Zone(selected.map).." - "..math.floor(selected.px*100+.5)..", "..math.floor(selected.py*100+.5).." - "..(reasons[selected.reason] or reasons.aid))
        U.age:SetText("Called "..R.Time(math.max(0,C.Now()-selected.sent)).." ago"..(own and " - Expires in "..R.Time(math.max(0,selected.expires-C.Now())) or ""))
    end
    local responders=#names>0 and "Answering: "..table.concat(names,", ") or "Waiting for a guildmate to answer."
    U.responders:SetText(responders);tip(U.responderBox,"Allies answering",responders)
    position(U.map,16,factsY+94);position(U.stop,204,factsY+94)
    local detailsHeight=factsY+134;U.details:SetHeight(detailsHeight)
    local y=actionsY+38
    U.brief:SetShown(navigating and true or false)
    if navigating then
        position(U.brief,16,y)
        local step=steps[B.routeIndex or 1]
        U.briefText:SetText(step and "Next: "..U.StepTitle(step).." - "..R.Time(step.seconds) or
            plan and plan.pendingFlight and "Finish your current flight. Routing updates on landing." or
            plan and plan.unavailable and "Route unavailable. Open Details to view the map." or "You have reached the beacon area.")
        y=y+46
    end
    local multi=#list>1 and not B.preview
    U.pager:SetShown(multi)
    if multi then
        local index=1;for i,b in ipairs(list) do if selected and b.owner==selected.owner then index=i end end
        U.position:SetText(index.." of "..#list.." active calls")
        position(U.pager,16,y);y=y+30
    end
    U.details:SetShown(U.expanded and selected~=nil and true or false)
    if U.expanded and selected then position(U.details,0,y);y=y+detailsHeight end
    local height=U.options and (U.settingsPage and 510 or 560) or y+7
    U.frame:SetHeight(height);U.frame.surface:SetHeight(height-12)
    U.RefreshControls()
end
function U.MapPins()
    U.LocationPins()
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
                pin:SetNormalTexture(media.."RoyalBrazier.tga");pin:SetFrameLevel(canvas:GetFrameLevel()+15)
                pin:SetScript("OnClick",function(self) if self.beacon then B.Select(self.beacon);U.options=false;U.Refresh();U.frame:Show() end end)
                pin:SetScript("OnEnter",function(self)
                    if not GameTooltip or not self.beacon then return end
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(self.beacon.name.." calls for aid!",1,.8,.3)
                    if self.beacon.message then GameTooltip:AddLine(self.beacon.message,.86,.90,.97,true) end
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
    U.RefreshFloating()
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
