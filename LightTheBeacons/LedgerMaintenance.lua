local _,B=...
local G,A,C=B.Grudges,B.GrudgePermissions,B.Client
local M={};B.LedgerMaintenance=M
local pending

function M.Preview(resolvedOnly)
    pending=nil
    if not G.Active() or not A.CanManage(B.me,"delete") then
        return nil,"Cleanup requires guild delete permission. Ask your Guild Master."
    end
    local p={guild=G.scope,rows={},resolved=0,open=0,points=0,resolvedOnly=resolvedOnly and true or false}
    local credited={}
    for _,member in ipairs(G.Leaderboard()) do for _,r in ipairs(member.records) do credited[r.entry.id]=true end end
    local ids={}
    for id,r in pairs(G.entries) do
        if not G.deleted[id] and C.Now()-r.entry.at>G.cleanupAge and (not resolvedOnly or r.seal) then
            ids[#ids+1]={id=id,seal=r.seal and r.seal.id}
            p.rows[#p.rows+1]={id=id,name=r.entry.enemy,author=r.entry.author,days=math.floor((C.Now()-r.entry.at)/86400),resolved=r.seal~=nil}
            if r.seal then p.resolved=p.resolved+1 else p.open=p.open+1 end
            if credited[id] then p.points=p.points+1 end
        end
    end
    table.sort(p.rows,function(a,b) if a.days~=b.days then return a.days>b.days end;return a.id<b.id end)
    pending={preview=p,guild=G.scope,ids=ids}
    return p
end
function M.Cancel() pending=nil end
function M.Confirm(preview)
    local batch=pending;pending=nil
    if not batch or batch.preview~=preview or batch.guild~=G.scope then return nil,"Review the old records again before deleting." end
    A.GuildChanged()
    if not G.Active() or not A.CanManage(B.me,"delete") then return nil,"Cleanup permission is no longer available. No records were deleted." end
    -- Bind confirmation to the reviewed IDs. New entries are never swept in;
    -- a newly resolved debt needs a fresh review of the points being removed.
    for _,item in ipairs(batch.ids) do
        local r=G.entries[item.id]
        if r and not G.deleted[item.id] and (r.seal and r.seal.id or nil)~=item.seal then
            return nil,"A reviewed grudge changed. Review again before deleting."
        end
    end
    local events={}
    for _,item in ipairs(batch.ids) do
        local r=G.entries[item.id]
        if r and not G.deleted[item.id] and C.Now()-r.entry.at>G.cleanupAge then
            G.store.sequence=G.store.sequence+1
            local at=math.floor(C.Now())
            local e={kind="D",id=G.Hash(B.me).."."..at.."."..B.nonce.."."..G.store.sequence,
                author=B.name,at=at,target=item.id,enemy="",guid="",where="",note="",evidence="manual",guild=G.scope}
            local parsed=G.Parse(G.Encode(e),C.Now())
            if not parsed then return nil,"Could not prepare cleanup. No records were deleted." end
            events[#events+1]=parsed
        end
    end
    -- Persist the normal deletion events and outbox before rebuilding once.
    -- The paced sender drains large batches without overflowing its packet queue.
    for _,e in ipairs(events) do
        A.RecordAuthorization(e,B.me,false)
        G.store.events[e.id]=e;G.store.outbox[e.id]=true
    end
    G.Rebuild();G.lastWrite=GetTime()
    G.status=#events.." old grudges deleted. Guild sync will share the removals."
    if B.GrudgeUI then B.GrudgeUI.Refresh() end
    return #events
end

local function label(parent,x,y,w,h,text,style)
    local f=parent:CreateFontString(nil,"ARTWORK",style or "GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",x,-y);f:SetSize(w,h);f:SetJustifyH("LEFT");f:SetText(text);return f
end
local function button(parent,x,y,w,text,callback)
    local f=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    f:SetPoint("TOPLEFT",x,-y);f:SetSize(w,28);f:SetText(text);f:SetScript("OnClick",callback);return f
end
local function scroll(parent,y,height)
    local f=CreateFrame("ScrollFrame",nil,parent);f:SetPoint("TOPLEFT",18,-y);f:SetSize(650,height);f:EnableMouseWheel(true)
    local child=CreateFrame("Frame",nil,f);child:SetSize(650,height);f:SetScrollChild(child)
    f:SetScript("OnMouseWheel",function(self,delta) self:SetVerticalScroll(math.max(0,math.min(child:GetHeight()-height,(self:GetVerticalScroll() or 0)-delta*40))) end)
    return f,child
end
function M.AppointmentsCanvas()
    local f=CreateFrame("Frame",nil,UIParent);f:SetSize(700,520);f.rows={}
    label(f,18,18,650,28,"Additional record deleters","GameFontNormalLarge")
    label(f,18,54,650,64,"The Guild Master can appoint individual guildmates to delete any entry and clean up old records, regardless of rank. This does not grant editing rights. Rank permissions still apply independently.")
    label(f,22,126,630,22,"Full guild character name","GameFontNormal")
    f.edit=CreateFrame("EditBox",nil,f,"InputBoxTemplate");f.edit:SetPoint("TOPLEFT",22,-152);f.edit:SetSize(365,28);f.edit:SetAutoFocus(false);f.edit:SetMaxBytes(100)
    f.edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    local refresh
    f.add=button(f,405,152,150,"Grant delete access",function()
        local ok,why=A.SetDeleter(f.edit:GetText(),true);refresh()
        if ok then f.edit:SetText("");f.edit:ClearFocus();f.status:SetText("Appointment saved. Sharing with guild addon users.") else f.status:SetText(why) end
    end)
    f.edit:SetScript("OnEnterPressed",function() f.add:GetScript("OnClick")() end)
    local view,child=scroll(f,230,234)
    f.status=label(f,18,190,650,36,"")
    label(f,18,474,650,36,"All participants need the updated addon. Permission updates sync while the Guild Master is online.")
    refresh=function()
        local master=A.IsMaster() and not B.guildPending;f.add:SetEnabled(master and true or false)
        local list={};for key,p in pairs(A.store and A.store.deleters and A.store.deleters.entries or {}) do
            if p.enabled then list[#list+1]={key=key,name=p.name} end
        end
        table.sort(list,function(a,b) return a.name<b.name end)
        for i=1,math.max(#list,#f.rows) do
            local row=f.rows[i]
            if not row then
                row=CreateFrame("Frame",nil,child);f.rows[i]=row;row:SetPoint("TOPLEFT",0,-(i-1)*40);row:SetSize(650,38)
                row.name=label(row,4,2,465,30,"")
                row.remove=button(row,490,2,130,"Revoke access",function() local ok,why=A.SetDeleter(row.player,false);refresh();if not ok then f.status:SetText(why) end end)
            end
            local p=list[i];row:SetShown(p~=nil)
            if p then row.player=p.name;row.name:SetText(p.name..(A.members[p.key] and "" or " (not in roster)"));row.remove:SetEnabled(master and true or false) end
        end
        child:SetHeight(math.max(234,#list*40));view:SetVerticalScroll(math.min(view:GetVerticalScroll() or 0,child:GetHeight()-234))
        f.status:SetText(master and (next(A.appointmentQueue or {}) and "Permissions saved. Waiting to share with the guild." or "Only listed individuals receive extra delete access.") or "Read-only: only the Guild Master can change appointments.")
    end
    M.RefreshAppointments=refresh;f.OnRefresh=refresh;f:SetScript("OnShow",function() A.GuildChanged();refresh() end);refresh();return f
end
function M.CleanupCanvas()
    local f=CreateFrame("Frame",nil,UIParent);f:SetSize(700,520);f.rows={}
    label(f,18,18,650,28,"Clean up old grudges","GameFontNormalLarge")
    label(f,18,54,650,60,"Nothing expires automatically. Review grudges recorded more than 90 days ago, then confirm removal from the guild's book. Deleting a resolved grudge also removes its leaderboard point. Deletion receipts prevent old copies from restoring it.")
    f.resolved=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate");f.resolved:SetPoint("TOPLEFT",18,-124);f.resolved:SetSize(26,26);f.resolved:SetChecked(true)
    label(f,50,126,360,24,"Resolved grudges only (keep open debts)")
    f.summary=label(f,18,170,650,54,"")
    local view,child=scroll(f,232,216)
    local function clear()
        M.Cancel();f.preview=nil
        for _,row in ipairs(f.rows) do row:Hide() end
        child:SetHeight(216);view:SetVerticalScroll(0)
        if f.confirm then f.confirm:SetEnabled(false) end
    end
    f.review=button(f,455,122,195,"Review records",function()
        clear();A.GuildChanged()
        local p,why=M.Preview(f.resolved:GetChecked());f.preview=p
        if not p then f.summary:SetText(why);return end
        f.summary:SetText(#p.rows.." grudges: "..p.resolved.." resolved, "..p.open.." open.\n"..p.points.." credited resolutions selected. Review every entry below before confirming.")
        for i,r in ipairs(p.rows) do
            local row=f.rows[i] or label(child,4,(i-1)*44,620,42,"");f.rows[i]=row
            row:SetText(r.name.." - "..r.days.." days old - "..(r.resolved and "resolved" or "OPEN").."\nRecorded by "..r.author);row:Show()
        end
        child:SetHeight(math.max(216,#p.rows*44));f.confirm:SetEnabled(#p.rows>0)
    end)
    f.confirm=button(f,18,472,240,"Delete reviewed records",function()
        local count,why=M.Confirm(f.preview);clear()
        f.summary:SetText(count and (count.." old grudges deleted. Removals are queued for guild sync.") or why)
    end)
    f.cancel=button(f,275,472,120,"Cancel",function() clear();f.summary:SetText("Cancelled. No records were deleted.") end)
    M.RefreshCleanup=function()
        local allowed=G.Active() and A.CanManage(B.me,"delete")
        f.review:SetEnabled(allowed and true or false)
        f.confirm:SetEnabled(allowed and f.preview and #f.preview.rows>0 and true or false)
    end
    local function refresh()
        clear();local allowed=G.Active() and A.CanManage(B.me,"delete")
        f.review:SetEnabled(allowed and true or false)
        f.summary:SetText(allowed and "Choose resolved-only or all older grudges, then review. Nothing is deleted until you confirm." or "Requires guild delete permission: Guild Master, permitted ranks, or appointed record deleters.")
    end
    f.resolved:SetScript("OnClick",refresh);f.OnRefresh=refresh
    f:SetScript("OnShow",function() A.GuildChanged();refresh() end);f:SetScript("OnHide",clear);refresh();return f
end
