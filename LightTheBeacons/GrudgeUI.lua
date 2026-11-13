local _,B=...
local G,C,P=B.Grudges,B.Client,B.Protocol
local U={mode="index",indexPage=1,recordPage=1,debt=1,rows={},recordRows={},bookText={},skinButtons={},skinFields={},skinPageButtons={}}
B.GrudgeUI=U

local root="Interface\\AddOns\\LightTheBeacons\\"
local fonts={body="Fonts\\FRIZQT__.TTF",italic="Fonts\\FRIZQT__.TTF",title="Fonts\\MORPHEUS.ttf"}
local ink={.15,.11,.075};local faded={.30,.22,.14};local red={.45,.12,.08};local brass={.70,.59,.42}

local function label(parent,x,y,w,h,size,face,color,align)
    local t=parent:CreateFontString(nil,"OVERLAY")
    local ok=t:SetFont(fonts[face or "body"],size,face=="italic" and "OUTLINE" or "")
    if ok==false then t:SetFont("Fonts\\FRIZQT__.TTF",size,"") end
    t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);t:SetJustifyH(align or "LEFT");t:SetJustifyV("TOP")
    t:SetWordWrap(true);t:SetNonSpaceWrap(true);color=color or ink;t:SetTextColor(unpack(color));B.Theme.Track(t,color,"text")
    return t
end
local function bookLabel(parent,x,y,w,h,size,face,color,align)
    local t=label(parent,x,y,w,h,size,face,color,align);t.bookColor=color or ink;U.bookText[#U.bookText+1]=t;return t
end
local function fill(parent,x,y,w,h,color,alpha)
    local t=parent:CreateTexture(nil,"BACKGROUND");t:SetColorTexture(color[1],color[2],color[3],alpha or 1)
    B.Theme.Track(t,color,"fill",alpha);t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);return t
end
local function picture(parent,file,x,y,w,h,layer)
    local t=parent:CreateTexture(nil,layer or "ARTWORK");t:SetTexture(root.."Media\\"..file..".tga")
    t:SetPoint("TOPLEFT",x,-y);t:SetSize(w,h);return t
end
local function border(parent,x,y,w,h,color,alpha)
    return {fill(parent,x,y,w,1,color,alpha),fill(parent,x,y+h-1,w,1,color,alpha),
        fill(parent,x,y,1,h,color,alpha),fill(parent,x+w-1,y,1,h,color,alpha)}
end

-- This remains the small themed control used by the death-review window.
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
        self.edges[2]:SetPoint("TOPLEFT",0,-height+1);self.edges[3]:SetHeight(height);self.edges[4]:SetHeight(height)
    end
    return b
end
local function field(parent,x,y,w,h,multi,limit,hint)
    fill(parent,x,y,w,h,{.82,.73,.54},.38);local edges=border(parent,x,y,w,h,faded,.8)
    local e=CreateFrame("EditBox",nil,parent);e:SetPoint("TOPLEFT",x+8,-y-5);e:SetSize(w-16,h-10)
    e:SetFont(fonts.body,15,"");e:SetTextColor(unpack(ink));e:SetAutoFocus(false);e:SetMultiLine(multi)
    e:SetMaxLetters(limit);e:SetMaxBytes(limit*4)
    e.hint=bookLabel(e,0,0,w-16,h-10,13,"body",faded);e.hint:SetText(hint or "Type here")
    local function updateHint() e.hint:SetShown(not e.focused and (e:GetText() or "")=="") end
    e:SetScript("OnTextChanged",updateHint)
    e:SetScript("OnEditFocusGained",function() e.focused=true;for _,edge in ipairs(edges) do edge:SetColorTexture(.43,.17,.10,1) end;updateHint() end)
    e:SetScript("OnEditFocusLost",function() e.focused=nil;for _,edge in ipairs(edges) do edge:SetColorTexture(unpack(faded)) end;updateHint() end)
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    if not multi then e:SetScript("OnEnterPressed",function(self) self:ClearFocus() end) end
    U.skinFields[#U.skinFields+1]=e;return e
end
local function nativeButton(parent,caption,x,y,w,h,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,-y);b:SetSize(w,h or 24);b:SetText(caption)
    b:SetScript("OnClick",fn)
    local fs=b.GetFontString and b:GetFontString()
    if not fs then fs=bookLabel(b,4,4,w-8,(h or 24)-7,12,"body",ink,"CENTER");fs:SetText(caption) end
    b.caption=fs;U.skinButtons[#U.skinButtons+1]=b;return b
end
local function pageButton(parent,direction,x,y,fn)
    local b=CreateFrame("Button",nil,parent);b:SetPoint("TOPLEFT",x,-y);b:SetSize(32,32)
    local side=direction<0 and "Prev" or "Next"
    b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-"..side.."Page-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-"..side.."Page-Down")
    b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-"..side.."Page-Disabled")
    b:SetScript("OnClick",fn);U.skinPageButtons[#U.skinPageButtons+1]=b;return b
end
local function tooltip(frame,title,body) B.UI.Widgets.tip(frame,title,body) end
U.Widgets={label=label,fill=fill,picture=picture,link=link}

local function formatDate(at) return date and date("%d %b %Y, %H:%M",at) or tostring(at) end
local function shortDate(at) return at and (date and date("%d %b %Y",at) or tostring(at)) or "Unknown" end
function U.RecordAge(at)
    local days=math.max(0,math.floor((C.Now()-at)/86400))
    return days==0 and "Recorded today" or days..(days==1 and " day old" or " days old")
end
local function recordDetails(record)
    return (record.level and ("Level at recording: "..record.level) or "Level not recorded").." | "..U.RecordAge(record.entry.at)
end
local function countPeople()
    local enemies,entries,open=0,0,0
    for _,person in pairs(G.people or {}) do enemies=enemies+1;entries=entries+#person.debts;open=open+person.open end
    return enemies,entries,open
end
function U.Person() return U.selected and G.people and G.people[U.selected] end
function U.Record() local p=U.Person();return p and p.debts[U.debt] end
function U.Reset()
    U.selected=nil;U.indexPage=1;U.recordPage=1;U.debt=1;U.query="";U.confirming=nil;U.deathDraft=nil;U.editing=nil;U.mode="index"
    if U.frame then U.search:SetText("");U.name:SetText("");U.note:SetText("");U.Refresh() end
end
function U.Mode(mode)
    if mode=="settings" or mode=="words" then
        local page=mode=="words" and "phrases" or "grudges"
        if B.Settings and B.Settings.Open and B.Settings.Open(page) then if U.frame then U.frame:Hide() end;return end
    end
    if mode=="book" then mode=U.selected and "person" or "index" end
    if mode~="index" and mode~="person" and mode~="inscribe" then mode="index" end
    U.mode=mode;U.confirming=nil;U.deathDraft=nil;U.editing=nil
    if U.confirm then U.confirm:Hide() end
    if mode=="inscribe" then local p=U.Person();U.name:SetText(p and p.name or "");U.note:SetText("") end
    U.Refresh()
end
function U.Select(key)
    if not key or not G.people[key] then return end
    U.selected=key;U.debt=1;U.recordPage=1;U.mode="person";U.confirming=nil;U.Refresh()
end
function U.Edit(id)
    local r=G.entries[id]
    if not r or G.deleted[id] or not B.GrudgePermissions.CanChange(r,"edit") then return end
    U.Mode("inscribe");U.editing=id;U.name:ClearFocus();U.name:SetText(r.entry.enemy);U.note:SetText(r.revision and r.revision.note or r.entry.note);U.Refresh()
end
function U.Turn(delta)
    local p=U.Person();if not p then return end
    U.debt=math.max(1,math.min(#p.debts,U.debt+delta));U.recordPage=math.floor((U.debt-1)/4)+1;U.confirming=nil;U.Refresh()
end
function U.Confirm(kind,id)
    local person=U.Person()
    if id and person then for i,r in ipairs(person.debts) do if r.entry.id==id then U.debt=i;break end end end
    local r=U.Record();if not r then return end
    U.confirming={kind=kind,id=r.entry.id};U.Refresh()
end
function U.CommitConfirmation()
    local pending=U.confirming;if not pending then return end
    local e,why
    if pending.kind=="withdraw" then e,why=G.Withdraw(pending.id) else e,why=G.Avenge(pending.id) end
    U.confirming=nil;if not e then U.notice=why;U.noticeUntil=GetTime()+12 end;U.Refresh()
end

function U.ApplyElvUISkin()
    if U.elvSkinned or not U.frame or B.Theme.current~="dark" then return end
    local addon=_G.ElvUI;local E=type(addon)=="table" and type(addon[1])=="table" and addon[1]
    local S=E and E.GetModule and E:GetModule("Skins",true)
    if not S then return end
    U.elvSkinned=true
    if U.frame.StripTextures then U.frame:StripTextures() end
    if U.frame.SetTemplate then U.frame:SetTemplate("Transparent") end
    local function skin(method,widget,...) if widget and S[method] then pcall(S[method],S,widget,...) end end
    skin("HandleCloseButton",U.close)
    for _,b in ipairs(U.skinButtons) do skin("HandleButton",b,true) end
    for _,b in ipairs(U.skinPageButtons) do skin("HandleNextPrevButton",b) end
    for _,e in ipairs(U.skinFields) do skin("HandleEditBox",e) end
    local remove=E.private and E.private.skins and E.private.skins.parchmentRemoverEnable
    if remove then
        U.pageBg:Hide();U.pageBgRight:Hide();U.pageShade:Show();U.pageShadeRight:Show()
        for _,t in ipairs(U.bookText) do t:SetTextColor(.92,.92,.92) end
        for _,e in ipairs(U.skinFields) do e:SetTextColor(.92,.92,.92) end
    elseif U.pagePanel.CreateBackdrop then U.pagePanel:CreateBackdrop("Transparent") end
end
function U.ApplyTheme()
    if not U.frame then return end
    if B.Theme.current=="dark" then U.ApplyElvUISkin() end
    local dark=B.Theme.current=="dark" and U.elvSkinned
    local addon=_G.ElvUI;local E=type(addon)=="table" and type(addon[1])=="table" and addon[1]
    local remove=dark and E and E.private and E.private.skins and E.private.skins.parchmentRemoverEnable
    U.pageBg:SetShown(not remove);U.pageBgRight:SetShown(not remove)
    U.pageShade:SetShown(remove and true or false);U.pageShadeRight:SetShown(remove and true or false)
    if not remove then
        for _,t in ipairs(U.bookText) do local c=t.bookColor or ink;t:SetTextColor(c[1],c[2],c[3],c[4] or 1) end
        for _,e in ipairs(U.skinFields) do e:SetTextColor(unpack(ink)) end
    end
end

function U.Create()
    if U.frame then return end
    local f=CreateFrame("Frame","LightTheBeaconsGrudgeBook",UIParent,"ButtonFrameTemplate");U.frame=f
    f:SetSize(1000,640);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true)
    f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self) self:StartMoving() end);f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    f:SetScript("OnHide",function() B.DeathUI.Resume() end)
    f:SetScript("OnShow",function() if f.SetScale then f:SetScale(math.min(1,(UIParent:GetWidth()-30)/1000,(UIParent:GetHeight()-30)/640)) end;U.Refresh() end)
    UISpecialFrames[#UISpecialFrames+1]="LightTheBeaconsGrudgeBook"

    U.shell=CreateFrame("Frame",nil,f);U.shell:SetAllPoints(f)
    fill(U.shell,0,0,1000,640,B.Theme.colors.panel,1);fill(U.shell,0,0,1000,52,B.Theme.colors.header,1);border(U.shell,0,0,1000,640,B.Theme.colors.border,1)
    -- Keep parchment above the opaque shell on every renderer. Sibling frames
    -- at the same level do not guarantee a texture drawing order.
    U.pagePanel=CreateFrame("Frame",nil,U.shell);U.pagePanel:SetPoint("TOPLEFT",20,-62);U.pagePanel:SetSize(960,558)
    local function pageTexture(x,mirror)
        local t=U.pagePanel:CreateTexture(nil,"BACKGROUND");t:SetPoint("TOPLEFT",x,0);t:SetSize(475,558)
        local atlas,info
        if t.SetAtlas and C_Texture and C_Texture.GetAtlasInfo then
            for _,candidate in ipairs({"Book-bg","QuestBG-Parchment"}) do
                info=C_Texture.GetAtlasInfo(candidate)
                if info then atlas=candidate;break end
            end
        end
        local left,right,top,bottom=0,.586,.02,.655
        if atlas then
            t:SetAtlas(atlas,false)
            left,right,top,bottom=info.leftTexCoord,info.rightTexCoord,info.topTexCoord,info.bottomTexCoord
        else t:SetTexture("Interface\\QuestFrame\\QuestBG") end
        -- Mirror only this atlas region, not the whole texture sheet. The
        -- eight-corner form preserves the crop while reversing the left leaf.
        if mirror then t:SetTexCoord(right,top,right,bottom,left,top,left,bottom)
        else t:SetTexCoord(left,right,top,bottom) end
        return t
    end
    U.pageBg=pageTexture(0,true);U.pageBgRight=pageTexture(485,false)
    U.pageShade=U.pagePanel:CreateTexture(nil,"BACKGROUND");U.pageShade:SetPoint("TOPLEFT",0,0);U.pageShade:SetSize(475,558);U.pageShade:SetColorTexture(.055,.055,.055,.98);U.pageShade:Hide()
    U.pageShadeRight=U.pagePanel:CreateTexture(nil,"BACKGROUND");U.pageShadeRight:SetPoint("TOPLEFT",485,0);U.pageShadeRight:SetSize(475,558);U.pageShadeRight:SetColorTexture(.055,.055,.055,.98);U.pageShadeRight:Hide()
    fill(U.pagePanel,479,8,2,542,{.21,.15,.09},.38)
    U.frameTitle=bookLabel(U.shell,28,28,420,25,18,"body",B.Theme.colors.gold);U.frameTitle:SetText("Book of Grudges")
    U.close=f.CloseButton or CreateFrame("Button",nil,f,"UIPanelCloseButton")
    U.close:ClearAllPoints();U.close:SetPoint("TOPRIGHT",-5,-5);U.close:SetSize(28,28);U.close:SetScript("OnClick",function() f:Hide() end)
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(f) end
    local function hidePortrait(portrait) if portrait then portrait:Hide() end end
    hidePortrait(f.PortraitContainer);hidePortrait(f.Portrait);hidePortrait(f.portrait);hidePortrait(_G.LightTheBeaconsGrudgeBookPortrait)
    U.indexTab=nativeButton(f,"Ledger",670,26,82,26,function() U.Mode("index") end)
    U.addTab=nativeButton(f,"Add grudge",756,26,100,26,function() U.Mode("inscribe") end)
    U.optionsTab=nativeButton(f,"Options",860,26,82,26,function() U.Mode("settings") end)
    for _,b in ipairs({U.indexTab,U.addTab,U.optionsTab}) do if b.caption then B.Theme.Track(b.caption,B.Theme.colors.gold,"text") end end

    U.index=CreateFrame("Frame",nil,U.pagePanel);U.index:SetAllPoints(U.pagePanel)
    bookLabel(U.index,32,30,410,44,34,"title",ink,"CENTER"):SetText("Book of Grudges")
    U.indexSummary=bookLabel(U.index,32,76,410,42,13,"body",faded,"CENTER")
    bookLabel(U.index,44,128,390,18,12,"body",faded):SetText("Search enemies")
    U.search=field(U.index,44,151,390,32,false,70,"Player name")
    U.search:HookScript("OnTextChanged",function(self) U.query=G.Clean(self:GetText(),70,100);U.indexPage=1;U.Refresh() end)
    nativeButton(U.index,"Add a grudge",145,194,188,30,function() U.Mode("inscribe") end)
    bookLabel(U.index,44,235,390,22,14,"body",red):SetText("NEWEST UNAVENGED")
    for i=1,10 do
        local x,y
        if i<=4 then x,y=32,264+(i-1)*65 else x,y=510,58+(i-5)*75 end
        local row=CreateFrame("Button",nil,U.index);U.rows[i]=row;row:SetPoint("TOPLEFT",x,-y);row:SetSize(420,60)
        row.hover=fill(row,0,0,420,60,brass,.12);row.hover:Hide()
        row.name=bookLabel(row,8,5,220,22,17,"body",ink);row.state=bookLabel(row,230,7,182,18,11,"body",red,"RIGHT")
        row.detail=bookLabel(row,8,31,404,24,10,"body",faded)
        row:SetScript("OnEnter",function(self) self.hover:Show() end);row:SetScript("OnLeave",function(self) self.hover:Hide() end)
        row:SetScript("OnClick",function(self) if self.key then U.Select(self.key) end end)
    end
    U.emptyIndex=bookLabel(U.index,525,185,390,120,17,"body",faded,"CENTER")
    U.prevIndex=pageButton(U.index,-1,675,500,function() U.indexPage=math.max(1,U.indexPage-1);U.Refresh() end)
    U.indexCount=bookLabel(U.index,715,507,88,18,12,"body",faded,"CENTER")
    U.nextIndex=pageButton(U.index,1,811,500,function() U.indexPage=U.indexPage+1;U.Refresh() end)
    U.status=bookLabel(U.pagePanel,240,536,480,18,11,"body",faded,"CENTER")

    U.read=CreateFrame("Frame",nil,U.pagePanel);U.read:SetAllPoints(U.pagePanel)
    U.back=nativeButton(U.read,"< Enemies",30,24,100,26,function() U.Mode("index") end)
    U.enemy=bookLabel(U.read,138,18,300,42,28,"title",ink,"CENTER");U.personState=bookLabel(U.read,314,64,120,18,11,"body",red,"RIGHT")
    U.personMeta=bookLabel(U.read,31,88,410,55,11,"body",faded,"CENTER");fill(U.read,31,145,410,1,faded,.35)
    U.recordsHeader=bookLabel(U.read,31,155,410,23,14,"body",red);U.recordsHeader:SetText("ENTERED GRUDGES")
    for i=1,4 do
        local x,y
        if i<=2 then x,y=31,187+(i-1)*168 else x,y=515,62+(i-3)*188 end
        local row=CreateFrame("Frame",nil,U.read);U.recordRows[i]=row;row:SetPoint("TOPLEFT",x,-y);row:SetSize(410,158)
        row.rule=fill(row,0,157,410,1,faded,.22);row.heading=bookLabel(row,0,0,180,19,13,"body",red)
        row.state=bookLabel(row,205,0,205,19,11,"body",red,"RIGHT");row.prose=bookLabel(row,0,36,270,67,12,"body",ink)
        row.recorded=bookLabel(row,0,20,270,14,9,"body",faded)
        row.revision=bookLabel(row,0,105,270,14,9,"body",faded)
        row.signature=bookLabel(row,0,121,270,31,9,"body",faded);row.result=bookLabel(row,278,25,132,58,9,"body",faded,"RIGHT")
        row.avenge=nativeButton(row,"Mark avenged",282,116,128,26,function() if row.recordID then U.Confirm("avenge",row.recordID) end end)
        row.edit=nativeButton(row,"Edit",282,85,60,26,function() if row.recordID then U.Edit(row.recordID) end end)
        row.withdraw=nativeButton(row,"Delete",346,85,64,26,function() if row.recordID then U.Confirm("withdraw",row.recordID) end end)
    end
    U.prevRecords=pageButton(U.read,-1,662,500,function() U.recordPage=math.max(1,U.recordPage-1);U.Refresh() end)
    U.recordCount=bookLabel(U.read,702,507,122,18,12,"body",faded,"CENTER")
    U.nextRecords=pageButton(U.read,1,833,500,function() U.recordPage=U.recordPage+1;U.Refresh() end)
    U.addForPerson=nativeButton(U.read,"Add grudge",515,455,160,30,function() U.Mode("inscribe") end)
    U.hide=nativeButton(U.read,"Hide this enemy",765,455,160,30,function() if U.selected then G.options.hidden[U.selected]=true;U.selected=nil;U.mode="index";U.Refresh() end end)
    U.confirm=CreateFrame("Frame",nil,U.read,"BackdropTemplate");U.confirm:SetPoint("TOPLEFT",258,-326);U.confirm:SetSize(444,128)
    U.confirm:SetBackdrop({bgFile=B.MediaPaths["UI-DialogBox-Background"],edgeFile=B.MediaPaths["UI-DialogBox-Border"],tile=true,tileSize=32,edgeSize=16})
    U.confirm:SetBackdropColor(.12,.08,.05,1);U.confirm:SetBackdropBorderColor(.40,.29,.18,1)
    U.confirmText=bookLabel(U.confirm,20,18,404,48,14,"body",brass,"CENTER")
    U.accept=nativeButton(U.confirm,"Mark avenged",28,79,184,30,U.CommitConfirmation)
    nativeButton(U.confirm,"Cancel",232,79,184,30,function() U.confirming=nil;U.Refresh() end);U.confirm:Hide()

    U.compose=CreateFrame("Frame",nil,U.pagePanel);U.compose:SetAllPoints(U.pagePanel)
    nativeButton(U.compose,"< Ledger",30,24,100,26,function() U.Mode(U.selected and "person" or "index") end)
    U.composeTitle=bookLabel(U.compose,124,72,330,42,30,"title",ink,"CENTER");U.composeTitle:SetText("Enter a Grudge")
    bookLabel(U.compose,44,132,390,20,14,"body",red):SetText("Enemy player")
    U.name=field(U.compose,44,158,390,38,false,70,"Full character name");U.name:SetMaxBytes(100)
    U.editEnemy=bookLabel(U.compose,52,168,374,22,15,"body",ink);U.editEnemy:Hide()
    U.targetButton=nativeButton(U.compose,"Use hostile target",252,203,182,27,function()
        local player,attack=C.Call(UnitIsPlayer,"target"),C.Call(UnitCanAttack,"player","target")
        if P.Plain(player) and P.Plain(attack) and player==true and attack==true then U.name:SetText(C.UnitName("target") or "")
        else U.notice="Select a hostile player, or write their full name.";U.noticeUntil=GetTime()+8;U.Refresh() end
    end)
    bookLabel(U.compose,44,250,390,20,14,"body",red):SetText("Grievance")
    U.note=field(U.compose,44,276,390,170,true,160,"Describe what happened (up to 160 characters)")
    U.charCount=bookLabel(U.compose,204,451,230,18,11,"body",faded,"RIGHT")
    U.note:HookScript("OnTextChanged",function(self) local _,n=P.Message(self:GetText(),true,160);U.charCount:SetText(n.." / 160 characters") end)
    bookLabel(U.compose,530,78,380,38,28,"title",ink,"CENTER"):SetText("Set It in Ink")
    U.composeHelp=bookLabel(U.compose,540,145,360,180,14,"body",faded,"CENTER")
    U.composeBy=bookLabel(U.compose,540,350,360,52,12,"body",faded,"CENTER")
    U.submit=nativeButton(U.compose,"Save to guild ledger",575,425,290,36,function()
        if U.editing then
            local e,why=G.Edit(U.editing,U.note:GetText())
            if e then U.editing=nil;U.mode="person";U.note:ClearFocus();U.note:SetText("")
            else U.notice=why;U.noticeUntil=GetTime()+12 end
            U.Refresh();return
        end
        local draft=U.deathDraft;local identity=P.Identity(G.Clean(U.name:GetText(),70,100))
        if draft and draft.incident and draft.incident.saved[identity] then U.notice="This player already has a grudge from this death.";U.noticeUntil=GetTime()+12;U.Refresh();return end
        local verified=draft and draft.scope==G.scope and draft.evidence=="pvp" and identity==P.Identity(draft.enemy)
        local e,why=G.Inscribe(U.name:GetText(),U.note:GetText(),verified and draft.guid or nil,verified and "pvp" or "manual",draft and draft.where)
        if e then
            if draft and draft.incident then draft.incident.saved[P.Identity(e.enemy)]=e.id;draft.incident.selected[P.Identity(e.enemy)]=false;B.DeathUI.message="Grudge saved to the guild ledger." end
            U.selected=P.Identity(e.enemy);U.debt=#G.people[U.selected].debts;U.recordPage=math.floor((U.debt-1)/4)+1;U.mode="person";U.deathDraft=nil
            U.name:ClearFocus();U.note:ClearFocus();U.name:SetText("");U.note:SetText("")
        else U.notice=why;U.noticeUntil=GetTime()+12 end
        U.Refresh();if e and G.pendingDeath and G.pendingDeath.handled then U.PromptDeath(G.pendingDeath);U.frame:Hide() end
    end)

    local toast=CreateFrame("Button",nil,UIParent,"BackdropTemplate");U.toast=toast
    toast:SetSize(460,82);toast:SetPoint("BOTTOM",UIParent,"BOTTOM",0,160);toast:SetFrameStrata("DIALOG")
    toast:SetBackdrop({bgFile=B.MediaPaths["UI-DialogBox-Background"],edgeFile=B.MediaPaths["UI-DialogBox-Border"],tile=true,tileSize=32,edgeSize=16})
    toast:SetBackdropColor(.12,.08,.05,1);toast:SetBackdropBorderColor(.40,.29,.18,1)
    U.toastTitle=label(toast,17,14,426,31,20,"body",brass);U.toastBody=label(toast,17,48,426,24,13,"body",brass)
    toast:RegisterForClicks("LeftButtonUp","RightButtonUp");toast:SetScript("OnClick",function(_,mouse) toast:Hide();if mouse~="RightButton" then U.Toggle(true) end end)
    toast:SetScript("OnUpdate",function() if GetTime()>=(U.toastUntil or 0) then toast:Hide() end end);toast:Hide();f:Hide();U.ApplyTheme()
end

function U.PromptDeath(draft)
    if B.db.muteBeacons or not G.Active() or G.options.deathMode=="off" then G.CancelDeathPrompt();return end
    if G.pendingDeath~=draft or draft.scope~=G.scope then return end;B.DeathUI.Grudge(draft)
end
function U.BeginDeathEntry()
    local incident=G.pendingDeath
    if not incident or incident.scope~=G.scope or not G.Active() or not C.IsOutdoor() then G.CancelDeathPrompt();return end
    U.Create();B.DeathUI.Suspend()
    if U.mode=="inscribe" and (U.name:GetText()~="" or U.note:GetText()~="") then U.Toggle(true);U.notice="Finish your current entry. The death prompt will return after you save, while you are still dead.";U.noticeUntil=GetTime()+12;U.Refresh();return end
    local entry,count=nil,0;for _,candidate in ipairs(incident.attackers or {}) do if not incident.saved[candidate.key] then entry=candidate;count=count+1 end end
    if count~=1 then entry=nil end
    local draft={scope=incident.scope,where=incident.where,incident=incident,enemy=entry and entry.name or "",guid=entry and entry.guid or "",evidence=entry and entry.killingBlow and "pvp" or "manual"}
    draft.note=(entry and (entry.killingBlow and "Killed me in " or "Attacked me before my death in ") or "PvP death in ")..draft.where.."."
    U.Toggle(true);U.Mode("inscribe");U.deathDraft=draft;U.name:SetText(draft.enemy);U.note:SetText(draft.note);U.Refresh()
end
function U.Notify(title,body,kind)
    U.notice=title.." "..body;U.noticeUntil=GetTime()+10
    if U.frame and U.frame:IsShown() then U.status:SetText(U.notice);return end
    if not G.options.notices or B.db.muteBeacons then return end
    U.Create();if U.lastToast and GetTime()-U.lastToast<3 then return end
    U.lastToast=GetTime();U.toastTitle:SetText(title);U.toastBody:SetText(body);U.toastUntil=GetTime()+8;U.toast:Show();if kind=="avenged" then B.Sound(false,true) end
end

function U.Refresh()
    if not U.frame or not G.store then return end
    local list=G.List(U.query);local pages=math.max(1,math.ceil(#list/10));U.indexPage=math.max(1,math.min(pages,U.indexPage))
    for i,row in ipairs(U.rows) do
        local person=list[(U.indexPage-1)*10+i];row:SetShown(person~=nil);row.key=person and person.key
        if person then
            row.name:SetText(person.name);row.state:SetText(person.open>0 and (person.open.." NOT YET AVENGED") or "ALL AVENGED")
            local seen=G.sightings[person.key]
            row.detail:SetText("First recorded "..shortDate(person.firstAt).."  |  Latest "..shortDate(person.latestAt).."  |  "..(seen and ("Last seen "..shortDate(seen.at).." in "..seen.where) or "No local sighting"))
            tooltip(row,person.name,#person.debts.." recorded grievances; "..person.open.." not yet avenged.")
        end
    end
    U.emptyIndex:SetShown(#list==0);U.emptyIndex:SetText(U.query~="" and "No matching enemies." or "The ledger is empty.\nAdd a grudge, or wait for guild pages to sync.")
    U.prevIndex:SetEnabled(U.indexPage>1);U.nextIndex:SetEnabled(U.indexPage<pages);U.indexCount:SetText(U.indexPage.." / "..pages)
    local enemies,entries,open=countPeople();U.indexSummary:SetText(enemies.." enemies  |  "..entries.." entered grudges  |  "..open.." not yet avenged")
    local person=U.Person()
    if U.mode=="person" and (not person or G.options.hidden[U.selected]) then U.mode="index";U.selected=nil;person=nil end
    U.index:SetShown(U.mode=="index");U.read:SetShown(U.mode=="person" and person~=nil);U.compose:SetShown(U.mode=="inscribe")
    if person then
        U.enemy:SetText(person.name);U.personState:SetText(person.open>0 and (person.open.." OPEN") or "AVENGED")
        local seen=G.sightings[person.key]
        U.personMeta:SetText("First recorded "..formatDate(person.firstAt).."  |  Latest entry "..formatDate(person.latestAt).."\n"..(seen and ("Last seen by you "..formatDate(seen.at).." in "..seen.where) or "No local sighting recorded."))
        local recordPages=math.max(1,math.ceil(#person.debts/4));U.recordPage=math.max(1,math.min(recordPages,U.recordPage))
        for i,row in ipairs(U.recordRows) do
            local debtIndex=(U.recordPage-1)*4+i;local record=person.debts[debtIndex];row:SetShown(record~=nil);row.recordID=record and record.entry.id
            if record then
                local entry=record.entry;row.heading:SetText("GRIEVANCE "..debtIndex);row.state:SetText(record.seal and "AVENGED" or "NOT YET AVENGED")
                row.recorded:SetText(recordDetails(record))
                row.prose:SetText(record.revision and record.revision.note or entry.note);row.signature:SetText("Entered by "..entry.author.." - "..shortDate(entry.at).." - "..entry.where)
                row.revision:SetText(record.revision and ("Edited by "..record.revision.author.." - "..shortDate(record.revision.at)) or "")
                row.result:SetText(record.seal and ("Avenged by "..record.seal.author.."\n"..shortDate(record.seal.at).." - "..record.seal.where) or "Awaiting an answer")
                local mine=P.Identity(entry.author)==B.me;row.avenge:SetShown(not record.seal and not mine);row.avenge:SetEnabled(G.Active() and true or false)
                row.edit:SetShown(B.GrudgePermissions.CanChange(record,"edit"));row.edit:SetEnabled(G.Active() and true or false)
                row.withdraw:SetShown(B.GrudgePermissions.CanChange(record,"delete"));row.withdraw:SetEnabled(G.Active() and true or false)
            end
        end
        U.prevRecords:SetEnabled(U.recordPage>1);U.nextRecords:SetEnabled(U.recordPage<recordPages);U.recordCount:SetText(U.recordPage.." / "..recordPages)
    end
    U.confirm:SetShown(U.confirming~=nil and U.mode=="person")
    if U.confirming then
        local withdraw=U.confirming.kind=="withdraw"
        U.confirmText:SetText(withdraw and "Delete this entry from the shared ledger? A deletion record prevents older copies from restoring it." or "Confirm this enemy's defeat? This keeps the original grievance and records who avenged it.")
        local text=withdraw and "Delete entry" or "Mark avenged";U.accept:SetText(text);if U.accept.caption then U.accept.caption:SetText(text) end
    end
    local editing=U.editing and G.entries[U.editing]
    U.composeTitle:SetText(editing and "Edit Grievance" or "Enter a Grudge")
    U.name:SetShown(not editing);U.targetButton:SetShown(not editing);U.editEnemy:SetShown(editing~=nil)
    U.editEnemy:SetText(editing and editing.entry.enemy or "")
    U.composeHelp:SetText(editing and "Revise the grievance text. The original enemy, author, date and location remain unchanged.\n\nYour name is recorded with the revision, which is shared with guild addon users." or "Every entry is signed with its author, date and zone, then shared with guild members who use Light the Beacons.\n\nMembers control their own entries. Permitted guild ranks can edit or delete other members' entries.")
    local caption=editing and "Save changes" or "Save to guild ledger";U.submit:SetText(caption);if U.submit.caption then U.submit.caption:SetText(caption) end
    U.composeBy:SetText((editing and "Edited by " or "Recorded by ")..(B.name or "you")..". Shared with guild addon users.")
    U.submit:SetEnabled(G.Active() and (not editing or not G.deleted[U.editing] and B.GrudgePermissions.CanChange(editing,"edit")) and true or false)
    U.status:SetText(U.noticeUntil and GetTime()<U.noticeUntil and U.notice or G.status or "Guild ledger ready.")
end
function U.Toggle(force)
    if not B.db then return end
    if not G.store then B.Print("Your guild information is still loading. Try the book again shortly.");return end
    U.Create();if U.frame:IsShown() and not force then U.frame:Hide();return end
    B.UI.frame:Hide();U.toast:Hide();U.mode="index";U.frame:Show();U.Refresh()
end
function U.Tick()
    if U.frame and U.frame:IsShown() then
        U.status:SetText(U.noticeUntil and GetTime()<U.noticeUntil and U.notice or G.status or "Guild ledger ready.")
        if U.mode=="person" then for _,row in ipairs(U.recordRows) do
            local record=row.recordID and G.entries[row.recordID]
            if row:IsShown() and record then row.recorded:SetText(recordDetails(record)) end
        end end
    end
end
