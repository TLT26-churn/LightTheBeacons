local _,B=...
local D,C,G,P={page=1,rows={}},B.Client,B.Grudges,B.Protocol;B.DeathUI=D
local W=B.GrudgeUI.Widgets
local T=B.Theme
local gold,pale,muted=T.colors.gold,T.colors.pale,T.colors.muted
local function label(parent,x,y,w,h,size,face,color,align)
    local t=W.label(parent,x,y,w,h,size,face or "body",color or pale,align)
    T.TrackFont(t,size,nil,"",true);return t
end
local function link(parent,caption,x,y,w,fn,size,style)
    local b=W.link(parent,caption,x,y,w,fn,size,style)
    T.Track(b.background,T.colors.button,"fill")
    for _,edge in ipairs(b.edges or {}) do T.Track(edge,T.colors.controlBorder,"fill") end
    T.Track(b.hover,T.colors.value,"fill",.2);T.Track(b.caption,gold,"text")
    T.TrackFont(b.caption,size or 14,nil,"",true);return b
end
local function position(frame,x,y) frame:ClearAllPoints();frame:SetPoint("TOPLEFT",x,-y) end
function D.Hide()
    if D.frame then D.transition=true;D.frame:Hide();D.transition=nil end
end
function D.Reset()
    D.active=nil;D.draft=nil;D.beacon=nil;D.confirmed=nil;D.dismissed=nil;D.suspended=nil;D.message=nil;D.where=nil;D.page=1
    D.awaitingLayout=nil;D.recapOpen=nil;D.dockStatus="inactive";D.Hide()
end
function D.Dismiss()
    D.dismissed=true;G.CancelDeathPrompt();D.Hide()
end
function D.RemoveGrudge() D.draft=nil;D.message=nil;D.Refresh() end
function D.Suspend() D.suspended=true;D.Hide() end
function D.Resume()
    if not D.suspended then return end
    D.suspended=nil
    if D.active then B.UI.frame:Hide() end
    D.Refresh()
end
function D.Beacon(confirmed)
    if not C.DeathHasPvP(confirmed) then return end
    D.beacon=true;D.confirmed=confirmed;D.Refresh()
end
function D.BeaconSent()
    if D.active then
        B.deathBeaconSent=true
        if B.db.prompt and C.DeathHasPvP() then D.beacon=true end
        D.Refresh()
    end
end
function D.Grudge(draft)
    if D.draft~=draft then D.page=1;D.message=nil end
    D.draft=draft;D.Refresh()
end
function D.Inscribe()
    local count,why=G.InscribeDeathSelection(D.draft)
    D.message=(count>0 and (count..(count==1 and " grudge saved" or " grudges saved").." to the guild ledger.") or "")
        ..(why and (count>0 and " " or "")..why or "")
    D.Refresh()
end
function D.Create()
    if D.frame then return end
    local f=B.UI.Widgets.panel(UIParent,"LightTheBeaconsDeathPrompt",560,440);D.frame=f
    f:SetPoint("CENTER",UIParent,"CENTER",0,20);f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:EnableMouse(true)
    T.Track(f,T.colors.panel,"backdrop");T.Track(f,T.colors.border,"border")
    T.Track(f.surface,T.colors.panel,"fill")
    f:SetScript("OnHide",function() if not D.transition and D.active and not D.dismissed then D.Dismiss() end end)
    UISpecialFrames[#UISpecialFrames+1]="LightTheBeaconsDeathPrompt"
    W.picture(f,"RoyalBrazier",23,19,48,48)
    D.title=label(f,85,20,407,40,31,"title",gold);D.title:SetText("You have fallen")
    D.place=label(f,86,60,410,20,14,"body",muted)
    link(f,"X",510,20,25,D.Dismiss,15,"dark")
    D.aid=CreateFrame("Frame",nil,f);D.aid:SetPoint("TOPLEFT",22,-82);D.aid:SetSize(516,58)
    W.fill(D.aid,0,0,516,58,T.colors.band,1)
    label(D.aid,13,7,290,26,21,"title",gold):SetText("Call for aid")
    D.aidText=label(D.aid,13,34,295,19,13)
    D.call=link(D.aid,"Light the Beacons",321,14,183,function()
        if not C.IsOutdoor() then D.Dismiss();return end
        D.Suspend();B.RequestLight(D.confirmed and "pvp" or "fallen")
    end,16,"dark")
    T.Track(D.call.background,T.colors.button,"fill")
    D.ledger=CreateFrame("Frame",nil,f);D.ledger:SetSize(516,260)
    W.picture(D.ledger,"GrudgeSeal",0,0,30,30)
    label(D.ledger,40,2,300,28,23,"title",gold):SetText("Record a grudge")
    D.all=link(D.ledger,"Select all",396,1,120,function()
        local draft=D.draft;if not draft then return end
        local all=true
        for _,entry in ipairs(draft.attackers) do if not draft.saved[entry.key] and not draft.selected[entry.key] then all=false end end
        for _,entry in ipairs(draft.attackers) do if not draft.saved[entry.key] then draft.selected[entry.key]=not all end end
        D.Refresh()
    end,14,"dark")
    D.explanation=label(D.ledger,0,36,516,34,13,"body",muted)
    for i=1,4 do
        local row=CreateFrame("Frame",nil,D.ledger);D.rows[i]=row;row:SetSize(516,37);row:SetPoint("TOPLEFT",0,-(74+(i-1)*39))
        W.fill(row,0,0,516,37,T.colors.band,.9)
        W.fill(row,0,36,516,1,T.colors.border,.7)
        local check=CreateFrame("CheckButton",nil,row);row.check=check;check:SetSize(22,22);check:SetPoint("TOPLEFT",9,-8)
        check:SetNormalTexture(B.MediaPaths["UI-CheckBox-Up"]);check:SetCheckedTexture(B.MediaPaths["UI-CheckBox-Check"])
        check:SetScript("OnClick",function(self)
            if row.entry and D.draft and not D.draft.saved[row.entry.key] then D.draft.selected[row.entry.key]=self:GetChecked() and true or false;D.Refresh() end
        end)
        row.name=label(row,41,4,310,32,16)
        row.role=label(row,356,12,148,20,12,"body",gold,"RIGHT")
        B.UI.Widgets.tip(row,"Detected attacker","Only readable hostile-player damage to you in the 30 seconds before death is listed. The client may not expose every attacker.")
    end
    D.previous=link(D.ledger,"<",0,260,35,function() D.page=D.page-1;D.Refresh() end,15,"dark")
    D.pageText=label(D.ledger,45,266,426,20,13,"body",muted,"CENTER")
    D.next=link(D.ledger,">",481,260,35,function() D.page=D.page+1;D.Refresh() end,15,"dark")
    D.inscribe=link(D.ledger,"Inscribe selected",0,300,239,D.Inscribe,17,"primary")
    D.manual=link(D.ledger,"Edit / add a name",251,300,265,function() B.GrudgeUI.BeginDeathEntry() end,15,"dark")
    D.privacy=label(D.ledger,0,337,516,20,13,"body",muted,"CENTER")
    D.status=label(f,22,400,367,36,14,"body",gold)
    D.dismiss=link(f,"Hide guild actions",401,400,137,D.Dismiss,15,"dark")
    -- Keep existing callers pointed at the same physical window.
    B.UI.deathPrompt=f;B.UI.deathCall=D.call
    B.GrudgeUI.deathPrompt=f;B.GrudgeUI.deathAction=D.manual;B.GrudgeUI.deathDismiss=D.dismiss;B.GrudgeUI.deathText=D.explanation
    D.Hide()
end
function D.Refresh()
    if not D.frame then return end
    local dead=C.Call(UnitIsDeadOrGhost,"player")
    if D.dismissed or D.suspended or not P.Plain(dead) or dead~=true or B.db.muteBeacons or not C.IsOutdoor()
        or B.guildPending or not B.guild or B.guild=="" then D.Hide();return end
    if not (B.deathEvidence and B.deathEvidence.pvp) then D.Hide();return end
    -- Wait for the one evidence decision; don't flash a second popup over the first.
    if G.pendingDeath and not G.pendingDeath.handled then D.Hide();return end
    local draft=D.draft
    if draft and (draft~=G.pendingDeath or not G.Active() or G.options.deathMode=="off") then draft=nil;D.draft=nil end
    if not D.beacon and not draft then D.Hide();return end
    D.place:SetText(draft and draft.where or D.where or G.Place())
    D.aid:SetShown(D.beacon and true or false)
    local lit=B.own and B.own.expires>C.Now()
    D.aidText:SetText(lit and "Your guild has been called to your aid." or "Rally guildmates to your fallen body.")
    D.call.caption:SetText(lit and "Beacon lit" or "Light the Beacons");D.call:SetEnabled(not lit)
    local y=D.beacon and 158 or 90
    D.ledger:SetShown(draft~=nil);position(D.ledger,22,y)
    if draft then
        local list=draft.attackers or {};local pages=math.max(1,math.ceil(#list/4));D.page=math.max(1,math.min(pages,D.page))
        local selected,remaining=0,0
        for _,entry in ipairs(list) do if not draft.saved[entry.key] then remaining=remaining+1;if draft.selected[entry.key] then selected=selected+1 end end end
        D.explanation:SetText(#list>0 and "Detected damage · death recap / combat log\nChoose the names to share with your guild."
            or "Hostile-player damage detected; the name is unavailable.\nAdd their name to review a grudge before sharing.")
        D.all:SetShown(#list>0);D.all:SetEnabled(remaining>0);D.all.caption:SetText(selected==remaining and remaining>0 and "Clear selection" or "Select all")
        for i,row in ipairs(D.rows) do
            local entry=list[(D.page-1)*4+i];row.entry=entry;row:SetShown(entry~=nil)
            if entry then
                local saved=draft.saved[entry.key];row.name:SetText(entry.name);row.name:SetTextColor(unpack(saved and muted or pale))
                row.role:SetText(saved and "Recorded" or entry.killingBlow and "Killing blow" or "Attacked you")
                row.check:SetChecked(draft.selected[entry.key] and not saved);row.check:SetEnabled(not saved)
                B.UI.Widgets.tip(row,entry.name,saved and "This attacker already has a grudge from this death." or entry.killingBlow and "Confirmed killing blow. The entry will record the death zone."
                    or "Detected damaging you before death. Saved as a manually confirmed grievance, not a killing blow.")
            end
        end
        local bottom=74+math.min(4,#list)*39
        D.previous:SetShown(pages>1);D.next:SetShown(pages>1);D.pageText:SetShown(pages>1)
        if pages>1 then
            position(D.previous,0,bottom+6);position(D.next,481,bottom+6);position(D.pageText,45,bottom+12)
            D.previous:SetEnabled(D.page>1);D.next:SetEnabled(D.page<pages);D.pageText:SetText(D.page.." / "..pages.." · "..#list.." detected attackers")
            bottom=bottom+39
        end
        position(D.inscribe,0,bottom+12);position(D.manual,251,bottom+12)
        D.inscribe:SetShown(#list>0);D.inscribe:SetEnabled(selected>0)
        D.inscribe.caption:SetText(remaining==0 and #list>0 and "Grudges recorded" or "Inscribe selected ("..selected..")")
        if #list==0 then position(D.manual,0,bottom+12) end
        D.manual.caption:SetText(remaining==1 and "Review / edit entry" or #list==0 and "Add a name…" or "Add missing name…")
        D.privacy:SetText(#list>0 and "Inscribe shares the selected entries with guild addon users." or "Nothing is shared until you save in the ledger.")
        position(D.privacy,0,bottom+49);D.ledger:SetHeight(bottom+72);y=y+bottom+76
    end
    D.status:SetText(D.message or (draft and draft.collecting and "Checking for delayed recap details…" or ""));position(D.status,22,y);position(D.dismiss,401,y)
    local height=y+52;D.frame:SetHeight(height);D.frame.surface:SetHeight(height-20)
    if not D.ApplyPosition() then D.Hide();return end
    D.frame:Show()
end
