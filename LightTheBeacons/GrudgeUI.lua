local _,B=...
local G,C,P=B.Grudges,B.Client,B.Protocol
local U={mode="book",indexPage=1,debt=1,rows={},strikes={},phraseRows={}};B.GrudgeUI=U
local root="Interface\\AddOns\\LightTheBeacons\\"
local fonts={body=root.."Fonts\\IMFeENrm28P.ttf",italic=root.."Fonts\\IMFeENit28P.ttf",title=root.."Fonts\\PirataOne-Regular.ttf"}
local ink={.15,.11,.075};local faded={.30,.22,.14};local red={.39,.15,.11};local brass={.70,.59,.42}
local function label(parent,x,y,w,h,size,face,color,align)
    local t=parent:CreateFontString(nil,"OVERLAY")
    local ok=t:SetFont(fonts[face or "body"],size,"")
    if ok==false then t:SetFont("Fonts\\FRIZQT__.TTF",size,"") end
    t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);t:SetJustifyH(align or "LEFT");t:SetJustifyV("TOP")
    t:SetWordWrap(true);t:SetNonSpaceWrap(true);t:SetTextColor(unpack(color or ink));return t
end
local function fill(parent,x,y,w,h,color,alpha)
    local t=parent:CreateTexture(nil,"BACKGROUND");t:SetColorTexture(color[1],color[2],color[3],alpha or 1)
    t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);return t
end
local function picture(parent,file,x,y,w,h,layer)
    local t=parent:CreateTexture(nil,layer or "ARTWORK");t:SetTexture(root.."Media\\"..file..".tga")
    t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);return t
end
local function border(parent,x,y,w,h,color,alpha)
    return {fill(parent,x,y,w,1,color,alpha),fill(parent,x,y+h-1,w,1,color,alpha),
        fill(parent,x,y,1,h,color,alpha),fill(parent,x+w-1,y,1,h,color,alpha)}
end
local function link(parent,caption,x,y,w,fn,size,style)
    local b=CreateFrame("Button",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,27)
    local dark=style=="dark" or style=="primary"
    b.background=fill(b,0,0,w,27,dark and {.21,.12,.075} or {.55,.44,.28},dark and .95 or .23)
    b.edges=border(b,0,0,w,27,dark and brass or faded,.7)
    b.hover=fill(b,1,1,w-2,25,brass,.2);b.hover:Hide()
    b.caption=label(b,5,5,w-10,20,size or 14,"body",dark and brass or red,"CENTER");b.caption:SetText(caption)
    b:SetScript("OnClick",fn)
    b:SetScript("OnEnter",function() if b:IsEnabled() then b.hover:Show() end end)
    b:SetScript("OnLeave",function() b.hover:Hide() end)
    b:SetScript("OnEnable",function() b.caption:SetTextColor(unpack(dark and brass or red)) end)
    b:SetScript("OnDisable",function() b.caption:SetTextColor(.43,.37,.28);b.hover:Hide() end)
    function b:Resize(height)
        self:SetHeight(height);self.background:SetHeight(height);self.hover:SetHeight(height-2)
        self.edges[2]:SetPoint("TOPLEFT",0,-height+1)
        self.edges[3]:SetHeight(height);self.edges[4]:SetHeight(height)
    end
    return b
end
local function field(parent,x,y,w,h,multi,limit,hint)
    fill(parent,x,y,w,h,{.82,.73,.54},.38)
    local edges=border(parent,x,y,w,h,faded,.8)
    local e=CreateFrame("EditBox",nil,parent);e:SetPoint("TOPLEFT",x+8,-y-5);e:SetSize(w-16,h-10)
    e:SetFont(fonts.body,17,"");e:SetTextColor(unpack(ink));e:SetAutoFocus(false);e:SetMultiLine(multi)
    e:SetMaxLetters(limit);e:SetMaxBytes(limit*4)
    e.hint=label(e,0,0,w-16,h-10,14,"body",faded);e.hint:SetText(hint or "Type here")
    local function updateHint() e.hint:SetShown(not e.focused and (e:GetText() or "")=="") end
    e:SetScript("OnTextChanged",updateHint)
    e:SetScript("OnEditFocusGained",function() e.focused=true;for _,edge in ipairs(edges) do edge:SetColorTexture(.43,.17,.10,1) end;updateHint() end)
    e:SetScript("OnEditFocusLost",function() e.focused=nil;for _,edge in ipairs(edges) do edge:SetColorTexture(unpack(faded)) end;updateHint() end)
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    if not multi then e:SetScript("OnEnterPressed",function(self) self:ClearFocus() end) end
    return e
end
local function tooltip(frame,title,body) B.UI.Widgets.tip(frame,title,body) end
U.Widgets={label=label,fill=fill,picture=picture,link=link}
local function formatDate(at)
    return date and date("%d %b, %H:%M",at) or tostring(at)
end
local function numeral(n)
    local out="";for _,p in ipairs({{1000,"m"},{900,"cm"},{500,"d"},{400,"cd"},{100,"c"},{90,"xc"},{50,"l"},{40,"xl"},{10,"x"},{9,"ix"},{5,"v"},{4,"iv"},{1,"i"}}) do
        while n>=p[1] do out=out..p[2];n=n-p[1] end
    end;return out
end
function U.Person() return U.selected and G.people and G.people[U.selected] end
function U.Record() local p=U.Person();return p and p.debts[U.debt] end
function U.Reset()
    U.selected=nil;U.indexPage=1;U.debt=1;U.query="";U.confirming=nil;U.deathDraft=nil
    if U.frame then U.search:SetText("");U.name:SetText("");U.note:SetText("");U.Refresh() end
end
function U.Mode(mode)
    U.mode=mode;U.confirming=nil;U.deathDraft=nil;U.confirm:Hide()
    if mode=="inscribe" then local p=U.Person();U.name:SetText(p and p.name or "");U.note:SetText("") end
    U.Refresh()
end
function U.Select(key)
    U.selected=key;U.debt=1;U.mode="book";U.confirming=nil;U.Refresh()
end
function U.Turn(delta)
    local p=U.Person();if not p then return end
    U.debt=math.max(1,math.min(#p.debts,U.debt+delta));U.confirming=nil;U.Refresh()
end
function U.Confirm(kind)
    local r=U.Record();if not r then return end
    U.confirming={kind=kind,id=r.entry.id};U.Refresh()
end
function U.CommitConfirmation()
    local pending=U.confirming;if not pending then return end
    local e,why
    if pending.kind=="withdraw" then e,why=G.Withdraw(pending.id) else e,why=G.Avenge(pending.id) end
    U.confirming=nil
    if not e then U.notice=why;U.noticeUntil=GetTime()+12 end
    U.Refresh()
end
function U.Create()
    if U.frame then return end
    local f=CreateFrame("Frame","LightTheBeaconsGrudgeBook",UIParent);U.frame=f
    f:SetSize(960,640);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true)
    f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    f:SetScript("OnHide",function() B.DeathUI.Resume() end)
    f:SetScript("OnShow",function()
        if f.SetScale then f:SetScale(math.min(1,(UIParent:GetWidth()-30)/960,(UIParent:GetHeight()-30)/640)) end
        U.Refresh()
    end)
    UISpecialFrames[#UISpecialFrames+1]="LightTheBeaconsGrudgeBook"
    picture(f,"GrudgeTome",0,0,960,640,"BACKGROUND")
    label(f,52,20,260,18,12,"body",brass):SetText("LIGHT THE BEACONS")
    U.tabs={}
    local chapters={{"Ledger","book"},{"Add grudge","inscribe"},{"Phrases","words"},{"Settings","settings"}}
    for i,item in ipairs(chapters) do
        local b=link(f,item[1],510+(i-1)*98,15,94,function() U.Mode(item[2]) end,13,"dark")
        U.tabs[item[2]]=b
    end
    link(f,"X",915,15,25,function() f:Hide() end,15,"dark")
    label(f,55,90,363,60,46,"title",ink,"CENTER"):SetText("Grudges")
    label(f,55,156,363,18,13,"body",faded,"CENTER"):SetText("Shared guild ledger")
    fill(f,86,190,303,1,faded,.35)
    label(f,55,205,363,28,23,"title"):SetText("Enemies")
    for i=1,4 do
        local row=CreateFrame("Button",nil,f);U.rows[i]=row;row:SetPoint("TOPLEFT",55,-(243+(i-1)*52));row:SetSize(363,48)
        row.name=label(row,0,0,308,27,23,"title");row.page=label(row,313,7,50,17,13,"body",faded,"RIGHT")
        row.detail=label(row,37,28,324,19,13,"italic",faded)
        row.tallies={};row.slashes={}
        for j=1,5 do
            local t=row:CreateTexture(nil,"ARTWORK");t:SetColorTexture(.24,.16,.09,.9);t:SetSize(2,11);t:SetPoint("TOPLEFT",(j-1)*6+2,-31);t:SetRotation(.08*j);row.tallies[j]=t
            local slash=row:CreateTexture(nil,"OVERLAY");slash:SetColorTexture(.43,.16,.11,.85);slash:SetSize(7,2);slash:SetPoint("TOPLEFT",(j-1)*6,-36);slash:SetRotation(.3);row.slashes[j]=slash
        end
        row.cut=row:CreateTexture(nil,"OVERLAY");row.cut:SetColorTexture(.43,.16,.11,.85);row.cut:SetSize(30,2);row.cut:SetPoint("TOPLEFT",0,-37);row.cut:SetRotation(.25)
        row:SetScript("OnClick",function(self) if self.key then U.Select(self.key) end end)
    end
    U.emptyIndex=label(f,55,246,363,155,17,"italic",faded)
    label(f,55,446,238,16,12,"body",faded):SetText("Search enemies")
    U.search=field(f,55,463,238,30,false,70,"Type a player name")
    U.search:HookScript("OnTextChanged",function(self) U.query=G.Clean(self:GetText(),70,100);U.indexPage=1;U.Refresh() end)
    tooltip(U.search,"Search enemies","Filter this character's view of the shared book.")
    U.hide=link(f,"Hide this name",305,463,115,function()
        if U.selected then G.options.hidden[U.selected]=true;U.selected=nil;U.Refresh() end
    end,13)
    U.prevIndex=link(f,"< Previous",55,497,130,function() U.indexPage=math.max(1,U.indexPage-1);U.Refresh() end,13)
    U.indexCount=label(f,188,502,105,18,12,"body",faded,"CENTER")
    U.nextIndex=link(f,"Next >",299,497,121,function() U.indexPage=U.indexPage+1;U.Refresh() end,13)
    U.sighting=label(f,55,535,363,37,13,"italic",faded)
    picture(f,"GrudgeSeal",174,569,38,38)
    label(f,181,579,24,22,18,"title",brass,"CENTER"):SetText("G")
    U.ledgerSummary=label(f,219,575,186,27,12,"body",faded)
    U.status=label(f,48,617,865,17,12,"italic",brass,"CENTER")
    -- Every content mode lives on the facing leaf; no stacked popups over the book.
    U.read=CreateFrame("Frame",nil,f);U.read:SetPoint("TOPLEFT",521,-65);U.read:SetSize(384,535);U.read:EnableMouse(true)
    label(U.read,0,0,384,16,11,"body",faded,"CENTER"):SetText("ENEMY")
    U.enemy=label(U.read,0,25,384,65,31,"title",ink,"CENTER")
    U.grievance=label(U.read,0,98,220,20,15,"body",red)
    U.state=label(U.read,224,98,160,20,15,"body",red,"RIGHT")
    U.prose=label(U.read,0,135,384,177,18,"body")
    for i=1,10 do
        local line=U.read:CreateTexture(nil,"OVERLAY");line:SetColorTexture(.42,.13,.09,.68);line:SetSize(376,1.5);line:SetRotation(.012)
        U.strikes[i]=line
    end
    U.evidence=label(U.read,0,311,384,19,12,"italic",faded)
    U.signature=label(U.read,0,345,384,56,14,"italic",faded)
    U.seal=picture(U.read,"GrudgeSeal",0,397,48,48)
    U.sealLetter=label(U.read,12,408,24,25,22,"title",brass,"CENTER")
    U.avenged=label(U.read,57,397,327,51,14,"italic",red)
    U.strike=link(U.read,"Mark avenged",0,448,176,function() U.Confirm("avenge") end)
    U.add=link(U.read,"Add grudge",193,448,191,function() U.Mode("inscribe") end)
    U.withdraw=link(U.read,"Withdraw my entry",0,478,176,function() U.Confirm("withdraw") end,12)
    U.prev=link(U.read,"< Previous entry",0,508,139,function() U.Turn(-1) end,13)
    U.folio=label(U.read,155,513,74,18,12,"body",faded,"CENTER")
    U.next=link(U.read,"Next entry >",245,508,139,function() U.Turn(1) end,13)
    U.confirm=CreateFrame("Frame",nil,U.read);U.confirm:SetPoint("TOPLEFT",0,-405);U.confirm:SetSize(384,104)
    fill(U.confirm,0,0,384,104,{.63,.53,.38},1)
    fill(U.confirm,0,0,384,1,red,.6)
    U.confirmText=label(U.confirm,8,8,368,55,15,"body",ink)
    U.accept=link(U.confirm,"Mark avenged",8,70,176,U.CommitConfirmation,14)
    link(U.confirm,"Cancel",193,70,180,function() U.confirming=nil;U.Refresh() end,14)
    U.confirm:Hide()
    U.blank=CreateFrame("Frame",nil,f);U.blank:SetPoint("TOPLEFT",521,-65);U.blank:SetSize(384,535)
    label(U.blank,0,58,384,45,30,"title",ink,"CENTER"):SetText("No grudge selected")
    U.emptyText=label(U.blank,10,137,364,160,18,"italic",faded,"CENTER")
    U.emptyAdd=link(U.blank,"+ Add grudge",90,300,204,function() U.Mode("inscribe") end,17,"primary")
    -- Inscription is deliberately explicit about guild visibility.
    U.compose=CreateFrame("Frame",nil,f);U.compose:SetPoint("TOPLEFT",521,-65);U.compose:SetSize(384,535)
    label(U.compose,0,15,384,45,31,"title",ink,"CENTER"):SetText("Add a grudge")
    label(U.compose,0,80,384,23,16,"body",red):SetText("Enemy player")
    U.name=field(U.compose,0,109,384,38,false,70,"Full character name");U.name:SetMaxBytes(100)
    link(U.compose,"Use hostile target",213,151,170,function()
        local player,attack=C.Call(UnitIsPlayer,"target"),C.Call(UnitCanAttack,"player","target")
        if P.Plain(player) and P.Plain(attack) and player==true and attack==true then
            U.name:SetText(C.UnitName("target") or "")
        else U.notice="Select a hostile player, or write their full name.";U.noticeUntil=GetTime()+8;U.Refresh() end
    end,13)
    label(U.compose,0,191,384,24,16,"body",red):SetText("Grievance")
    U.note=field(U.compose,0,224,384,150,true,160,"Describe what happened (up to 160 characters)")
    U.charCount=label(U.compose,210,379,174,18,12,"italic",faded,"RIGHT")
    U.note:HookScript("OnTextChanged",function(self) local _,n=P.Message(self:GetText(),true,160);U.charCount:SetText(n.." / 160 characters") end)
    U.composeBy=label(U.compose,0,406,384,42,14,"italic",faded)
    picture(U.compose,"GrudgeSeal",0,464,48,48)
    U.submit=link(U.compose,"Save to guild ledger",62,471,272,function()
        local draft=U.deathDraft
        local identity=P.Identity(G.Clean(U.name:GetText(),70,100))
        if draft and draft.incident and draft.incident.saved[identity] then
            U.notice="This player already has a grudge from this death.";U.noticeUntil=GetTime()+12;U.Refresh();return
        end
        local verified=draft and draft.scope==G.scope and draft.evidence=="pvp"
            and identity==P.Identity(draft.enemy)
        local e,why=G.Inscribe(U.name:GetText(),U.note:GetText(),verified and draft.guid or nil,
            verified and "pvp" or "manual",draft and draft.where)
        if e then
            if draft and draft.incident then
                draft.incident.saved[P.Identity(e.enemy)]=e.id;draft.incident.selected[P.Identity(e.enemy)]=false
                B.DeathUI.message="Grudge saved to the guild ledger."
            end
            U.selected=P.Identity(e.enemy);U.debt=#G.people[U.selected].debts;U.mode="book";U.deathDraft=nil
            U.name:ClearFocus();U.note:ClearFocus();U.name:SetText("");U.note:SetText("")
        else U.notice=why;U.noticeUntil=GetTime()+12 end
        U.Refresh()
        if e and G.pendingDeath and G.pendingDeath.handled then U.PromptDeath(G.pendingDeath);U.frame:Hide() end
    end,17,"primary")
    -- A page of the book's voice, using the approved phrases.
    U.words=CreateFrame("Frame",nil,f);U.words:SetPoint("TOPLEFT",521,-65);U.words:SetSize(384,535)
    label(U.words,0,15,384,40,31,"title",ink,"CENTER"):SetText("Alert phrases")
    local kinds={{"Recorded","incurred"},{"Sighted","sighted"},{"Avenged","avenged"}}
    for i,k in ipairs(kinds) do link(U.words,k[1],(i-1)*128,77,122,function() U.phraseKind=k[2];U.Refresh() end) end
    U.phraseKind="incurred"
    for i=1,5 do
        local row=link(U.words,"",0,131+(i-1)*57,384,function() G.options.phrases[U.phraseKind]=i;U.Refresh() end,17)
        row:Resize(52);row.caption:SetHeight(48);U.phraseRows[i]=row
    end
    U.phraseNote=label(U.words,0,432,384,48,14,"italic",faded)
    link(U.words,"Standard wording",0,495,198,function() G.options.phrases[U.phraseKind]=nil;U.Refresh() end)
    link(U.words,"Preview",252,495,132,function() U.Notify(G.Phrase(U.phraseKind),"Local preview. No guild message is sent.","preview") end)
    U.settings=CreateFrame("Frame",nil,f);U.settings:SetPoint("TOPLEFT",521,-65);U.settings:SetSize(384,535)
    label(U.settings,0,15,384,40,31,"title",ink,"CENTER"):SetText("Settings")
    U.checks={}
    local rules={
        {"enabled","Use the guild-shared book","Off pauses all grudge sending, receiving and automatic recording."},
        {"deathMode","After an outdoor PvP death","Unknown killer: ask you to enter the name."},
        {"autoAvenge","Record my confirmed victories","Your readable killing blow settles one oldest unpaid debt."},
        {"sightingAlerts","Warn when a debtor is seen","Only a hostile player you target or mouse over. No shared tracking."},
        {"notices","Show grudge notices","One notice at a time. Beacon alert mute also silences these notices."},
    }
    for i,item in ipairs(rules) do
        local y=70+(i-1)*68
        if item[1]=="deathMode" then
            label(U.settings,0,y,384,23,16,"body",ink):SetText(item[2])
            U.deathModes={}
            for j,choice in ipairs({{"prompt","Ask first"},{"auto","Auto-save"},{"off","Off"}}) do
                local b=link(U.settings,choice[2],(j-1)*128,y+23,122,function() G.SetDeathMode(choice[1]);U.Refresh() end,14)
                U.deathModes[choice[1]]=b
                tooltip(b,choice[2],choice[1]=="auto" and "Share confirmed killers automatically. Ask for a name when attribution is unavailable."
                    or choice[1]=="prompt" and "Review a grudge after death. Nothing is shared until you save."
                    or "Do not prompt or automatically save death grudges.")
            end
            label(U.settings,0,y+52,384,16,12,"italic",faded):SetText(item[3])
        else
            local check=CreateFrame("CheckButton",nil,U.settings);check:SetPoint("TOPLEFT",0,-y);check:SetSize(22,22)
            check:SetNormalTexture(B.MediaPaths["UI-CheckBox-Up"]);check:SetCheckedTexture(B.MediaPaths["UI-CheckBox-Check"])
            label(U.settings,30,y,354,23,16,"body",ink):SetText(item[2])
            label(U.settings,30,y+24,354,34,12,"italic",faded):SetText(item[3])
            check:SetScript("OnClick",function(self) if item[1]=="enabled" then G.SetEnabled(self:GetChecked()) else G.options[item[1]]=self:GetChecked() and true or false end;U.Refresh() end)
            U.checks[item[1]]=check
        end
    end
    U.restore=link(U.settings,"Restore hidden names",0,410,232,function() G.options.hidden={};U.Refresh() end)
    link(U.settings,"Sync pages",249,410,135,function() G.Sync();U.Refresh() end)
    label(U.settings,0,451,384,68,13,"italic",faded):SetText("History is shared with guild addon users, retained for 90 days, and restored from online guildmates. Only the original scribe may withdraw a wrong. Hidden names affect only your view.")
    label(U.settings,0,521,384,16,11,"italic",faded):SetText("Made by Whitebeard Tinkerton - US PVP")
    -- Separate bottom placement avoids the beacon/rally banner stack at the top.
    local toast=CreateFrame("Button",nil,UIParent,"BackdropTemplate");U.toast=toast
    toast:SetSize(460,82);toast:SetPoint("BOTTOM",UIParent,"BOTTOM",0,160);toast:SetFrameStrata("DIALOG")
    toast:SetBackdrop({bgFile=B.MediaPaths["UI-DialogBox-Background"],edgeFile=B.MediaPaths["UI-DialogBox-Border"],tile=true,tileSize=32,edgeSize=16})
    toast:SetBackdropColor(.12,.08,.05,1);toast:SetBackdropBorderColor(.40,.29,.18,1)
    U.toastTitle=label(toast,17,14,426,31,22,"title",brass)
    U.toastBody=label(toast,17,48,426,24,13,"italic",brass)
    toast:RegisterForClicks("LeftButtonUp","RightButtonUp")
    toast:SetScript("OnClick",function(_,mouse) toast:Hide();if mouse~="RightButton" then U.Toggle(true) end end)
    toast:SetScript("OnUpdate",function() if GetTime()>=(U.toastUntil or 0) then toast:Hide() end end)
    toast:Hide()
    f:Hide()
end
function U.PromptDeath(draft)
    if B.db.muteBeacons or not G.Active() or G.options.deathMode=="off" then G.CancelDeathPrompt();return end
    if G.pendingDeath~=draft or draft.scope~=G.scope then return end
    B.DeathUI.Grudge(draft)
end
function U.BeginDeathEntry()
    local incident=G.pendingDeath
    if not incident or incident.scope~=G.scope or not G.Active() then G.CancelDeathPrompt();return end
    U.Create();B.DeathUI.Suspend()
    -- Preserve an entry the player was already writing, even if its window is closed.
    if U.mode=="inscribe" and (U.name:GetText()~="" or U.note:GetText()~="") then
        U.Toggle(true);U.notice="Finish your current entry. The death prompt will return after you save, while you are still dead.";U.noticeUntil=GetTime()+12;U.Refresh();return
    end
    -- A single remaining detected attacker can be reviewed. Otherwise this action
    -- adds a missing name, while the multi-selection remains suspended and intact.
    local entry,count=nil,0
    for _,candidate in ipairs(incident.attackers or {}) do
        if not incident.saved[candidate.key] then entry=candidate;count=count+1 end
    end
    if count~=1 then entry=nil end
    local draft={scope=incident.scope,where=incident.where,incident=incident,
        enemy=entry and entry.name or "",guid=entry and entry.guid or "",evidence=entry and entry.killingBlow and "pvp" or "manual"}
    draft.note=(entry and (entry.killingBlow and "Killed me in " or "Attacked me before my death in ") or "PvP death in ")..draft.where.."."
    U.Toggle(true);U.Mode("inscribe");U.deathDraft=draft
    U.name:SetText(draft.enemy);U.note:SetText(draft.note)
    U.Refresh()
end
function U.Notify(title,body,kind)
    U.notice=title.." "..body;U.noticeUntil=GetTime()+10
    if U.frame and U.frame:IsShown() then U.status:SetText(U.notice);return end
    if not G.options.notices or B.db.muteBeacons then return end
    U.Create()
    if U.lastToast and GetTime()-U.lastToast<3 then return end
    U.lastToast=GetTime();U.toastTitle:SetText(title);U.toastBody:SetText(body);U.toastUntil=GetTime()+8;U.toast:Show()
    if kind=="avenged" then B.Sound(false,true) end
end
function U.Refresh()
    if not U.frame or not G.store then return end
    for mode,tab in pairs(U.tabs) do tab.background:SetColorTexture(.31,.23,.13,U.mode==mode and 1 or .45) end
    local list=G.List(U.query);local pages=math.max(1,math.ceil(#list/4));U.indexPage=math.max(1,math.min(pages,U.indexPage))
    if not U.selected or not G.people[U.selected] or G.options.hidden[U.selected] then U.selected=list[1] and list[1].key;U.debt=1 end
    for i,row in ipairs(U.rows) do
        local p=list[(U.indexPage-1)*4+i];row:SetShown(p~=nil);row.key=p and p.key
        if p then
            row.name:SetText(p.name);row.name:SetTextColor(unpack(p.key==U.selected and red or ink));row.page:SetText(numeral((U.indexPage-1)*4+i))
            row.detail:SetText(p.open==0 and "All avenged" or p.open..(p.open==1 and " unpaid grudge" or " unpaid grudges"))
            for j,t in ipairs(row.tallies) do t:SetShown(j<=math.min(5,#p.debts));row.slashes[j]:SetShown(j<=math.min(5,#p.debts) and j>p.open) end
            row.cut:SetShown(p.open==0);tooltip(row,p.name,#p.debts.." recorded wrongs; "..p.open.." unpaid.")
        end
    end
    U.emptyIndex:SetShown(#list==0);U.emptyIndex:SetText(U.query and U.query~="" and "No matching players." or "No grudges recorded.\nAdd an entry or wait for guildmates to sync.")
    U.prevIndex:SetEnabled(U.indexPage>1);U.nextIndex:SetEnabled(U.indexPage<pages);U.indexCount:SetText(U.indexPage.." / "..pages)
    U.hide:SetEnabled(U.selected~=nil)
    local enemies,entries=0,0;for _,p in pairs(G.people or {}) do enemies=enemies+1;entries=entries+#p.debts end
    U.ledgerSummary:SetText(enemies.." enemies\n"..entries.." recorded grudges")
    local person=U.Person();local seen=person and G.sightings[person.key]
    U.sighting:SetText(seen and ("Seen by you in "..seen.where..", "..formatDate(seen.at)..".") or "Target or mouse over a recorded enemy to see a sighting.")
    U.read:SetShown(U.mode=="book" and person~=nil);U.blank:SetShown(U.mode=="book" and not person)
    U.compose:SetShown(U.mode=="inscribe");U.words:SetShown(U.mode=="words");U.settings:SetShown(U.mode=="settings")
    U.emptyText:SetText(G.Active() and "Select a player from the index, or add a grudge to share with your guild." or "Join a guild and enable its shared book in Settings.\n\nSaved pages remain readable while sharing is paused.")
    if person then
        U.debt=math.max(1,math.min(#person.debts,U.debt));local r=U.Record();local e=r.entry
        U.enemy:SetText(person.name);U.grievance:SetText("GRIEVANCE "..numeral(U.debt):upper());U.state:SetText(r.seal and "AVENGED" or "UNANSWERED")
        U.prose:SetText(e.note);U.prose:SetTextColor(unpack(r.seal and faded or ink))
        U.evidence:SetText(e.evidence=="pvp" and "Inscribed after a confirmed PvP death." or "Inscribed by a guildmate.")
        U.signature:SetText("Entered by "..e.author.."\n"..formatDate(e.at).." - "..e.where)
        tooltip(U.read,person.name,e.note.."\n\nEntered by "..e.author.."\n"..formatDate(e.at).." - "..e.where..
            (r.seal and ("\n\nAvenged by "..r.seal.author.."\n"..formatDate(r.seal.at).." - "..r.seal.where) or ""))
        local lines=C.Call(U.prose.GetNumLines,U.prose) or math.ceil(#e.note/42)
        local height=C.Call(U.prose.GetStringHeight,U.prose) or lines*21
        if not P.Number(lines,1,10) then lines=1 end
        if not P.Number(height,1,177) then height=lines*20 end
        for i,line in ipairs(U.strikes) do line:SetShown(r.seal and i<=lines or false);line:ClearAllPoints();line:SetPoint("TOPLEFT",0,-(135+(i-.48)*height/lines)) end
        U.seal:SetShown(r.seal~=nil);U.sealLetter:SetShown(r.seal~=nil);U.avenged:SetShown(r.seal~=nil)
        if r.seal then
            local initial=P.Message(r.seal.author,false,1);U.sealLetter:SetText(initial)
            U.avenged:SetText("Avenged by "..r.seal.author.."\n"..formatDate(r.seal.at).." - "..r.seal.where.."\n"..(r.seal.evidence=="kill" and "Confirmed killing blow." or "Witnessed victory; recorded manually."))
        end
        U.strike:SetShown(not r.seal and not U.confirming);U.strike:SetEnabled(G.Active() and true or false)
        U.add:SetShown(not U.confirming);U.withdraw:SetShown(P.Identity(e.author)==B.me and not U.confirming)
        U.withdraw:SetEnabled(G.Active() and true or false)
        U.prev:SetEnabled(U.debt>1);U.next:SetEnabled(U.debt<#person.debts);U.folio:SetText(numeral(U.debt))
    end
    U.confirm:SetShown(U.confirming~=nil and U.mode=="book")
    if U.confirming then
        local withdraw=U.confirming.kind=="withdraw"
        U.confirmText:SetText(withdraw and "Withdraw your entry from the guild ledger? Received copies cannot be erased." or "Confirm this enemy's defeat? Marks one grudge avenged and keeps the original entry.")
        U.accept.caption:SetText(withdraw and "Withdraw entry" or "Mark avenged")
    end
    U.composeBy:SetText("Recorded by "..(B.name or "you")..".\nShared with guild addon users.")
    U.submit:SetEnabled(G.Active() and true or false)
    local phrases=G.phrases[U.phraseKind];local choice=G.options.phrases[U.phraseKind]
    for i,row in ipairs(U.phraseRows) do row:SetShown(phrases[i]~=nil);if phrases[i] then row.caption:SetText((i==choice and "> " or numeral(i)..". ")..phrases[i]) end end
    U.phraseNote:SetText(choice and "Selected wording for this alert." or "Standard wording: "..G.defaultPhrases[U.phraseKind])
    for k,check in pairs(U.checks) do check:SetChecked(G.options[k]) end
    for mode,button in pairs(U.deathModes) do
        button.background:SetColorTexture(.31,.23,.13,mode==G.options.deathMode and .65 or .15)
        button.caption:SetTextColor(unpack(mode==G.options.deathMode and brass or red))
    end
    local hidden=0;for _ in pairs(G.options.hidden) do hidden=hidden+1 end
    U.restore.caption:SetText("Restore hidden names ("..hidden..")");U.restore:SetEnabled(hidden>0)
    U.status:SetText(U.noticeUntil and GetTime()<U.noticeUntil and U.notice or G.status or "Guild ledger ready.")
end
function U.Toggle(force)
    if not B.db then return end
    if not G.store then B.Print("Your guild information is still loading. Try the book again shortly.");return end
    U.Create()
    if U.frame:IsShown() and not force then U.frame:Hide();return end
    B.UI.frame:Hide();U.toast:Hide();U.frame:Show();U.Refresh()
end
function U.Tick()
    if U.frame and U.frame:IsShown() then
        U.status:SetText(U.noticeUntil and GetTime()<U.noticeUntil and U.notice or G.status or "Guild ledger ready.")
    end
end
