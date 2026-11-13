local client,check=...
local roster={
    {name="Aldric Stoneward",guildRankOrder=1,guildRank="High Warden"},
    {name="Elowen Dawnwatch",guildRankOrder=2,guildRank="Council"},
    {name="Sample Scribe",guildRankOrder=3,guildRank="Veteran"},
    {name="Tessa Oakguard",guildRankOrder=4,guildRank="Member"},
}
local function make(first,last,saved,time)
    return client(first,last,saved,time,nil,nil,true,{guildRoster=roster})
end
local gm=make("Aldric","Stoneward");local officer=make("Elowen","Dawnwatch");local member=make("Sample","Scribe");local other=make("Tessa","Oakguard")
local peers={gm,officer,member,other}
local function advance(n) for _,c in ipairs(peers) do c.advance(n or 3) end end
local function deliver(source,target,e)
    for _,packet in ipairs(source.B.Grudges.Packets(e)) do
        check(#packet<=250,"Management and level metadata fit addon-message limits")
        target.B.eventFrame.scripts.OnEvent(target.B.eventFrame,"CHAT_MSG_ADDON",source.B.Grudges.prefix,packet,"GUILD",source.B.name)
    end
end
local function share(source,e) for _,c in ipairs(peers) do if c~=source then deliver(source,c,e) end end end
local function policy()
    gm.B.GrudgePermissions.Tick();local p=gm.s.sent[#gm.s.sent]
    check(p and p[1]==gm.B.GrudgePermissions.prefix and p[3]=="GUILD" and #p[2]<=250,"Guild Master policy uses bounded guild-only messages")
    for _,c in ipairs(peers) do if c~=gm then c.B.eventFrame.scripts.OnEvent(c.B.eventFrame,"CHAT_MSG_ADDON",p[1],p[2],p[3],gm.B.name) end end
    return p[2]
end
check(gm.B.GrudgePermissions.IsMaster() and officer.B.GrudgePermissions.CanManage(officer.B.me,"edit"),"Default access follows rank order even with customized rank names")
check(not member.B.GrudgePermissions.CanManage(member.B.me,"edit") and not member.B.GrudgePermissions.SetRank(3,"edit",true),"Members cannot manage other entries or change guild permissions")
local firstPolicy=policy()
local entry=assert(member.B.Grudges.Inscribe("Example Enemy","Original grievance."));share(member,entry)
advance()
local revision=assert(member.B.Grudges.Edit(entry.id,"Corrected by its author."));share(member,revision)
check(other.B.Grudges.entries[entry.id].revision.note=="Corrected by its author." and other.B.Grudges.entries[entry.id].entry.note=="Original grievance.","Authors can revise their own entry while the original account is retained")
check(not other.B.Grudges.Edit(entry.id,"Not mine") and not other.B.Grudges.Withdraw(entry.id),"Members cannot edit or delete another author's entry")
advance()
local moderated=assert(officer.B.Grudges.Edit(entry.id,"Clarified by the Council."));share(officer,moderated)
check(member.B.Grudges.entries[entry.id].revision.author==officer.B.name and member.s.lastMessage:find("edited",1,true),"Officer edits sync with editor attribution")
local U=member.B.GrudgeUI;U.Toggle(true);U.Select(member.B.Protocol.Identity(entry.enemy))
check(U.recordRows[1].edit:IsShown() and U.recordRows[1].withdraw:IsShown() and U.recordRows[1].prose:GetText()==moderated.note,"Entry owners see edit/delete controls and the latest text")
U.Edit(entry.id)
check(U.editing==entry.id and not U.name:IsShown() and U.editEnemy:GetText()==entry.enemy,"Editing locks the original enemy and preloads the current grievance")
advance();U.note:SetText("Saved through the book editor.");U.submit.scripts.OnClick()
local fromUI=member.B.Grudges.entries[entry.id].revision;share(member,fromUI)
check(fromUI.note=="Saved through the book editor." and U.mode=="person","The book editor saves a shared revision and returns to the folio")
local outsiderUI=other.B.GrudgeUI;outsiderUI.Toggle(true);outsiderUI.Select(other.B.Protocol.Identity(entry.enemy))
check(not outsiderUI.recordRows[1].edit:IsShown() and not outsiderUI.recordRows[1].withdraw:IsShown(),"Unpermitted ranks do not see management actions for others")
advance();check(gm.B.GrudgePermissions.SetRank(2,"edit",false),"Guild Master may revoke Officer editing separately from deletion")
local restrictedPolicy=policy()
check(not officer.B.Grudges.Edit(entry.id,"Revoked") and officer.B.GrudgePermissions.CanManage(officer.B.me,"delete"),"A received policy takes effect at the write boundary")
check(member.B.Grudges.entries[entry.id].revision.id==fromUI.id,"Permission changes never undo previously accepted revisions")
local forged=restrictedPolicy:gsub("|10", "|11")
member.B.GrudgePermissions.Receive(forged,other.B.name,"GUILD")
check(not member.B.GrudgePermissions.CanManage(officer.B.me,"edit"),"A non-master cannot forge a guild permission update")
member.B.GrudgePermissions.Receive(firstPolicy,gm.B.name,"GUILD")
check(not member.B.GrudgePermissions.CanManage(officer.B.me,"edit"),"An older policy cannot overwrite a newer Guild Master decision")
advance();check(gm.B.GrudgePermissions.SetRank(3,"edit",true) and gm.B.GrudgePermissions.SetRank(3,"delete",true),"Guild Master can grant a custom rank both permissions")
policy()
local othersEntry=assert(other.B.Grudges.Inscribe("Training Foe","Another member's account."));share(other,othersEntry)
advance();local deletion=assert(member.B.Grudges.Withdraw(othersEntry.id));share(member,deletion)
check(other.B.Grudges.deleted[othersEntry.id] and other.s.lastMessage:find("deleted",1,true),"Custom rank deletion syncs with accurate author/moderator chat attribution")
deliver(other,officer,othersEntry)
check(officer.B.Grudges.deleted[othersEntry.id],"A stale inscription cannot restore a moderated deletion")
local canvas=gm.B.Settings.categories.permissions.canvas
check(#canvas.rows==4 and not canvas.rows[1].edit.enabled and canvas.rows[3].edit.enabled,"Native guild settings show actual ranks and protect Guild Master access")
check(not other.B.Settings.categories.permissions.canvas.rows[3].edit.enabled,"Non-master settings remain read-only")
local reload=make("Sample","Scribe",member.B.db,member.s.time)
check(reload.B.GrudgePermissions.CanManage(reload.B.me,"edit") and reload.B.Grudges.deleted[othersEntry.id],"Saved policies and authorized deletion receipts survive reload")
-- An ordinary relay cannot invent a moderator action. A currently permitted
-- moderator can relay history they previously accepted, including an action
-- whose original moderator has since been demoted.
local late=make("Tessa","Oakguard",nil,member.s.time)
late.B.GrudgePermissions.Receive(restrictedPolicy,gm.B.name,"GUILD")
check(late.B.Grudges.Merge(entry,member.B.me,true),"Late client receives the original inscription")
check(late.B.Grudges.Merge(moderated,other.B.me,true) and not late.B.Grudges.entries[entry.id].revision,"Unprivileged history relay cannot vouch for another person's edit")
local late2=make("Tessa","Oakguard",nil,member.s.time)
late2.B.GrudgePermissions.Receive(firstPolicy,gm.B.name,"GUILD")
late2.B.Grudges.Merge(entry,member.B.me,true);late2.B.Grudges.Merge(moderated,gm.B.me,true)
check(late2.B.Grudges.entries[entry.id].revision.id==moderated.id,"Guild Master can relay a previously authorized moderation event")
check(late.B.Grudges.digest~=late2.B.Grudges.digest,"Unverified moderator history has a distinct digest so sync will retry")
local beforeNotices=#late.s.messages
late.B.Grudges.request={nonce="123",peer=gm.B.me,deadline=late.s.now+20}
for _,packet in ipairs(gm.B.Grudges.Packets(moderated,"123",late.B.Grudges.Hash(late.B.me))) do
    late.B.Grudges.Receive(packet,gm.B.name,"GUILD")
end
check(late.B.Grudges.entries[entry.id].revision.id==moderated.id and late.B.Grudges.digest==late2.B.Grudges.digest,
    "A later authoritative replay verifies an already received event and converges")
check(#late.s.messages==beforeNotices,"Verifying historical moderation does not replay chat notifications")
local tampered={};for k,v in pairs(moderated) do tampered[k]=v end;tampered.note="Changed payload under an existing ID"
late.B.Grudges.Merge(tampered,gm.B.me,true)
check(late.B.Grudges.entries[entry.id].revision.note==moderated.note,"An existing event ID cannot be replaced by another payload")
local guard=make("Aldric","Stoneward",nil,member.s.time)
guard.B.Grudges.Merge(entry,member.B.me,false)
local bad={};for k,v in pairs(moderated) do bad[k]=v end
bad.author=other.B.name;bad.id=guard.B.Grudges.Hash(other.B.me).."."..math.floor(member.s.time)..".111.1";bad.at=math.floor(member.s.time)
guard.B.Grudges.Merge(bad,other.B.me,false)
check(not guard.B.Grudges.entries[entry.id].revision,"A Guild Master receiver ignores an ordinary member's unauthorized edit")
guard.B.Grudges.queue={};guard.B.Grudges.Receive("1|W|456|"..guard.B.Grudges.Hash(guard.B.me).."|",member.B.name,"GUILD")
local relayed=false;for _,packet in ipairs(guard.B.Grudges.queue) do if packet.msg:find("|"..bad.id.."|",1,true) then relayed=true end end
check(not relayed,"A moderator's history response never launders an ignored unauthorized claim")
local oldRelay=make("Tessa","Oakguard",nil,member.s.time)
oldRelay.B.Grudges.Merge(entry,member.B.me,true);oldRelay.B.Grudges.Merge(moderated,gm.B.me,true)
check(not oldRelay.B.Grudges.entries[entry.id].revision,"A legacy peer that has not advertised permission support cannot vouch for moderator history")
local ownerHistory=make("Tessa","Oakguard",nil,member.s.time)
ownerHistory.B.Grudges.Merge(entry,member.B.me,true)
ownerHistory.B.Grudges.Merge(fromUI,other.B.me,true)
check(not ownerHistory.B.Grudges.entries[entry.id].revision,"An ordinary relay cannot forge a revision by claiming the original author's name")
deliver(member,ownerHistory,fromUI)
check(ownerHistory.B.Grudges.entries[entry.id].revision.id==fromUI.id,"Direct owner delivery verifies a previously untrusted revision")
local legacy=client("Sample","Scribe")
local legacyEntry=assert(legacy.B.Grudges.Inscribe("Legacy Foe","Saved before permissions existed."));legacy.advance(3)
assert(legacy.B.Grudges.Withdraw(legacyEntry.id));legacy.B.db.grudgePermissions=nil
local upgraded=client("Sample","Scribe",legacy.B.db,legacy.s.time)
check(upgraded.B.Grudges.deleted[legacyEntry.id],"Installing permissions preserves owner withdrawals already trusted in an older saved ledger")
local paused=make("Tessa","Oakguard",nil,member.s.time);paused.B.Grudges.SetEnabled(false)
paused.B.GrudgePermissions.Receive(firstPolicy,gm.B.name,"GUILD")
check(not paused.B.GrudgePermissions.store.policy,"Pausing the guild book also pauses incoming permission policy")
local retained=officer.B.Grudges.entries[entry.id].revision.id
roster[2].guildRankOrder=4;roster[2].guildRank="Member"
officer.B.GuildChanged()
check(not officer.B.GrudgePermissions.CanManage(officer.B.me,"delete") and officer.B.Grudges.entries[entry.id].revision.id==retained,"Roster demotion blocks new moderation without rewriting history")
-- Unknown or secret rank data never grants access.
officer.s.guildRoster={{name=officer.B.name,guildRankOrder={secret=true}}};officer.B.GuildChanged()
check(not officer.B.GrudgePermissions.CanManage(officer.B.me,"edit"),"Unreadable guild rank fails closed for other members' entries")
reload.env.C_Club.GetGuildClubId=function() return 99 end;reload.B.GuildChanged()
check(not reload.B.GrudgePermissions.store.policy and not next(reload.B.GrudgePermissions.store.accepted),"Changing guild discards the former guild's policy and receipts")

do
    local c=client("Sample","Scribe");local G=c.B.Grudges
    c.env.UnitIsPlayer=function(unit) return unit=="target" end;c.env.UnitCanAttack=function(_,unit) return unit=="target" end
    c.env.UnitNameUnmodified=function(unit) if unit=="target" then return "Example","Enemy" end;return "Sample","Scribe" end
    c.env.UnitGUID=function(unit) return unit=="target" and "Player-2-00AA" or "Player-1-Sample" end
    local level=42;c.env.UnitLevel=function() return level end
    local e=assert(G.Inscribe("Example Enemy","Recorded while the enemy was visible.","Player-2-00AA"))
    check(G.entries[e.id].level==42,"Inscription captures a matching hostile player's readable level")
    local metadata;for _,event in ipairs(G.log) do if event.kind=="L" then metadata=event end end
    local receiver=client("Aldric","Stoneward");receiver.B.members[c.B.me]=true
    deliver(c,receiver,metadata);deliver(c,receiver,e)
    check(receiver.B.Grudges.entries[e.id].level==42,"Level metadata survives reversed delivery and reconstructs with the original entry")
    level=60;c.advance(3);G.Edit(e.id,"Revised text.")
    check(G.entries[e.id].level==42,"Later level readings and text edits never change the recorded level")
    local saved=client("Sample","Scribe",c.B.db,c.s.time)
    check(saved.B.Grudges.entries[e.id].level==42,"Recorded level survives reload")
    local ui=c.B.GrudgeUI;ui.Toggle(true);ui.Select(c.B.Protocol.Identity(e.enemy))
    check(ui.recordRows[1].recorded:GetText()=="Level at recording: 42 | Recorded today","Book explicitly labels the recording-time level and new-entry age")
    c.s.time=e.at+86400;ui.Tick()
    check(ui.recordRows[1].recorded:GetText():find("1 day old",1,true),"Age uses singular wording after one full day")
    c.s.time=e.at+3*86400;ui.Tick()
    check(ui.recordRows[1].recorded:GetText():find("3 days old",1,true),"Age increases with elapsed days without changing the entry date")
    level=-1;c.advance(3);local unknown=assert(G.Inscribe("Example Enemy","Unreadable level."))
    check(not G.entries[unknown.id].level,"Skull-level enemies are not assigned an invented level")
    c.env.UnitLevel=function() return {secret=true} end;c.advance(3)
    local secret=assert(G.Inscribe("Example Enemy","Restricted level."))
    check(not G.entries[secret.id].level,"Restricted level values remain unread")
    c.env.UnitLevel=function() return 60 end;c.advance(3)
    local different=assert(G.Inscribe("Training Foe","Another enemy is selected."))
    check(not G.entries[different.id].level,"An unrelated target's level is never attached to a manually named enemy")
    c.advance(3);local mismatch=assert(G.Inscribe("Example Enemy","Name matches, but GUID differs.","Player-2-00BB"))
    check(not G.entries[mismatch.id].level,"A conflicting GUID prevents attaching the selected player's level")
    local oldMeta={};for k,v in pairs(metadata) do oldMeta[k]=v end
    oldMeta.at=e.at+60;oldMeta.id=G.Hash(c.B.me).."."..oldMeta.at..".111.1";oldMeta.note="60"
    G.Merge(oldMeta,c.B.me,false)
    check(G.entries[e.id].level==42,"Later metadata cannot rewrite an entry's historical level")
end
