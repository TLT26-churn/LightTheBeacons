local client,check=...
local function copy(t) if type(t)~="table" then return t end;local o={};for k,v in pairs(t) do o[k]=copy(v) end;return o end
local roster={
    {name="Guild Master",guildRankOrder=1,guildRank="Master"},
    {name="Guild Officer",guildRankOrder=2,guildRank="Officer"},
    {name="Sample Keeper",guildRankOrder=3,guildRank="Member"},
    {name="Example Author",guildRankOrder=3,guildRank="Member"},
}
local function make(first,last,saved,time) return client(first,last,saved,time,nil,nil,true,{guildRoster=roster}) end
local gm=make("Guild","Master");local keeper=make("Sample","Keeper");local author=make("Example","Author")
local officer=make("Guild","Officer");local peers={gm,keeper,author,officer}
local function permissions()
    local messages={}
    for _=1,5 do
        gm.advance(3);gm.B.GrudgePermissions.Tick()
        for i=(gm.cursor or 0)+1,#gm.s.sent do
            local p=gm.s.sent[i]
            if p[1]==gm.B.GrudgePermissions.prefix then
                check(#p[2]<=250 and p[3]=="GUILD","Appointments use bounded guild-only packets")
                messages[#messages+1]=p[2]
                for _,c in ipairs(peers) do if c~=gm then c.B.GrudgePermissions.Receive(p[2],gm.B.name,p[3]) end end
            end
        end
        gm.cursor=#gm.s.sent
        for _,c in ipairs(peers) do if c~=gm then c.advance(3) end end
    end
    return messages
end
local A=gm.B.GrudgePermissions;local KA=keeper.B.GrudgePermissions
check(not keeper.B.LedgerMaintenance.Preview(false),"Ordinary members cannot start bulk cleanup, even for their own entries")
check(not KA.SetDeleter(keeper.B.name,true),"Only the Guild Master can appoint individuals")
check(not A.SetDeleter("Not A Guildmate",true),"Appointments require a current guild roster match")
check(A.SetDeleter(keeper.B.name,true),"Guild Master can appoint a single member")
local grants=permissions();local grant
for _,msg in ipairs(grants) do if msg:find("|N|",1,true) then grant=msg end end
check(grant and KA.CanManage(keeper.B.me,"delete") and not KA.CanManage(keeper.B.me,"edit"),"An appointment grants deletion and cleanup without editing rights")
check(keeper.B.Settings.categories.cleanup.canvas.review.enabled,"Appointed member can review old records in settings")
local reloaded=make("Sample","Keeper",copy(keeper.B.db),keeper.s.time)
check(reloaded.B.GrudgePermissions.CanManage(reloaded.B.me,"delete"),"Named grants persist through reload")
local absent=make("Sample","Keeper",copy(keeper.B.db),keeper.s.time)
absent.s.guild=false;absent.B.GuildChanged()
check(absent.B.db.grudgePermissions.deleters and not absent.B.GrudgePermissions.CanManage(absent.B.me,"delete"),"Unavailable membership suspends appointed access without discarding the saved grant")
absent.s.guild=true;absent.B.GuildChanged()
check(absent.B.GrudgePermissions.IsAppointed(absent.B.me),"The same confirmed guild restores saved appointments")
local successor=make("Sample","Keeper",copy(keeper.B.db),keeper.s.time)
successor.s.guildRoster=copy(roster);successor.s.guildRoster[1].guildRankOrder=3;successor.s.guildRoster[2].guildRankOrder=1
successor.B.GrudgePermissions.GuildChanged()
check(not successor.B.GrudgePermissions.IsAppointed(successor.B.me),"A new Guild Master invalidates the former leader's named grants")
local forged=make("Example","Author")
forged.B.GrudgePermissions.Receive(grant,keeper.B.name,"GUILD")
check(not forged.B.GrudgePermissions.IsAppointed(keeper.B.me),"An ordinary member cannot forge a Guild Master appointment")
forged.B.GrudgePermissions.Receive(grant:gsub("|42|","|99|"),gm.B.name,"GUILD")
check(not forged.B.GrudgePermissions.IsAppointed(keeper.B.me),"Appointments from another guild are rejected")

local G=author.B.Grudges
local paid=assert(G.Inscribe("Example Enemy","An old resolved grudge.","Player-2-ABC1"));author.advance(3)
author.B.Client.CombatEvent(0,"PARTY_KILL",false,author.env.UnitGUID("player"),author.B.name,0x410,0,"Player-2-ABC1",paid.enemy,0x440,0)
local seal=assert(G.entries[paid.id].seal);author.advance(3)
local open=assert(G.Inscribe("Sample Rival","An old open debt."));author.advance(3)
local manual=assert(G.Inscribe("Example Opponent","Resolved by hand."));author.advance(3);local manualSeal=assert(G.Avenge(manual.id))
local later=author.s.time+91*86400
for _,c in ipairs(peers) do
    if c~=author then for _,e in ipairs({paid,seal,open,manual,manualSeal}) do c.B.Grudges.Merge(copy(e),author.B.me,true) end end
    c.s.time=later;c.advance(61);c.B.Grudges.Tick()
end
local K=keeper.B.Grudges;local M=keeper.B.LedgerMaintenance
check(#K.ids==5 and #K.Leaderboard()[1].records==1,"Full records and verified details remain after 90 days")
local p=assert(M.Preview(true))
check(#p.rows==2 and p.resolved==2 and p.open==0 and p.points==1,"Resolved-only preview reports both candidate records and only verified points")
check(A.SetDeleter(keeper.B.name,false),"The Guild Master can revoke an individual appointment")
permissions();check(not M.Confirm(p) and not K.deleted[paid.id],"Revocation between review and confirmation prevents every deletion")
KA.Receive(grant,gm.B.name,"GUILD")
check(not KA.IsAppointed(keeper.B.me),"An older grant cannot undo a newer revocation")
gm.B.Settings.categories.deleters.canvas.edit:SetText(keeper.B.name)
gm.B.Settings.categories.deleters.canvas.add.scripts.OnClick();permissions()
check(KA.IsAppointed(keeper.B.me) and gm.B.Settings.categories.deleters.canvas.rows[1]:IsShown(),"Settings can grant access and show the appointed individual")
p=assert(M.Preview(false))
check(#p.rows==3 and p.open==1,"All-old-records preview includes open debts only when selected")
-- A new resolution changes the confirmation's point impact.
keeper.advance(3);assert(K.Avenge(open.id,"Player-2-ABC2","kill"))
check(not M.Confirm(p) and not K.deleted[open.id],"A newly resolved candidate requires a fresh confirmation")
local canvas=keeper.B.Settings.categories.cleanup.canvas
canvas.OnRefresh();canvas.review.scripts.OnClick()
check(canvas.resolved:GetChecked() and canvas.preview and canvas.confirm.enabled and canvas.summary:GetText():find("2 credited",1,true),"Cleanup defaults to resolved-only and shows credited resolutions before confirmation")
local reviewed=canvas.preview
-- Add another eligible historical entry after the review. It is not in the snapshot.
local late=copy(open);late.id=K.Hash(author.B.me).."."..late.at..".999.123";late.enemy="Late Synced Enemy"
K.Merge(late,author.B.me,true)
canvas.confirm.scripts.OnClick()
check(K.deleted[paid.id] and K.deleted[manual.id] and K.deleted[open.id] and not K.deleted[late.id],"Confirmed cleanup deletes only the reviewed IDs, not newly synced old entries")
check(#K.Leaderboard()==0 and not M.Confirm(reviewed),"Cleanup removes selected points and cannot be confirmed twice")
local deletions=0
for id in pairs(K.store.outbox) do
    local e=K.store.events[id]
    if e.kind=="D" then
        deletions=deletions+1
        for _,packet in ipairs(K.Packets(e)) do G.Receive(packet,keeper.B.name,"GUILD") end
    end
end
check(deletions==3 and G.deleted[paid.id] and #G.Leaderboard()==0,"Appointed cleanup sends normal authenticated deletions to other guild clients")
local after=make("Sample","Keeper",copy(keeper.B.db),keeper.s.time)
check(after.B.Grudges.deleted[paid.id] and next(after.B.Grudges.store.outbox),"Deletion receipts and unsent cleanup survive reload")
local testOfficer=officer.B.LedgerMaintenance.Preview(false)
check(testOfficer and #testOfficer.rows==3,"Officers have bulk cleanup permission by default")
assert(A.SetRank(2,"delete",false));permissions()
check(not officer.B.LedgerMaintenance.Confirm(testOfficer),"A revoked rank permission is also rechecked when confirming cleanup")
local cp=assert(M.Preview(false));keeper.env.C_Club.GetGuildClubId=function() return 99 end;keeper.B.GuildChanged()
check(not M.Confirm(cp) and #keeper.B.Grudges.ids==0,"A guild change invalidates pending cleanup without leaking the previous guild ledger")

-- The cutoff is strictly older than 90 days, based on original inscription time.
local boundary=make("Guild","Officer");local BG=boundary.B.Grudges
local edge=assert(BG.Inscribe("Boundary Foe","Exactly ninety days."));boundary.s.time=edge.at+90*86400
check(#assert(boundary.B.LedgerMaintenance.Preview(false)).rows==0,"Exactly 90 days is not older than 90 days")
boundary.s.time=boundary.s.time+1
check(#assert(boundary.B.LedgerMaintenance.Preview(false)).rows==1,"An entry becomes eligible only after the cutoff")

-- More than 1,200 full records survive load, and there is still room to write.
local largeSaved=copy(boundary.B.db);largeSaved.grudges.events={};largeSaved.grudges.outbox={}
for i=1,1250 do
    local e=copy(edge);e.at=edge.at-5*365*86400;e.id=BG.Hash(boundary.B.me).."."..e.at..".333."..i
    largeSaved.grudges.events[e.id]=e
end
local large=make("Guild","Officer",largeSaved,boundary.s.time);local LG=large.B.Grudges
check(#LG.ids==1250,"Loading a large multi-year ledger never silently truncates to 1,200 records")
local recent=assert(LG.Inscribe("Current Enemy","A new record alongside old history."))
local before=copy(large.B.db);local many=assert(large.B.LedgerMaintenance.Preview(false))
check(#many.rows==1250 and large.B.LedgerMaintenance.Confirm(many)==1250 and not LG.deleted[recent.id],"Large manual cleanup completes without a write cooldown or capacity limit and preserves new records")
check(#LG.queue<=256,"Large cleanup leaves network traffic paced rather than flooding the packet queue")
local loaded=make("Guild","Officer",before,large.s.time+2*365*86400)
check(#loaded.B.Grudges.ids==1251,"Multi-year records survive a further reload without cleanup")
local old=loaded.B.Grudges.store.events[loaded.B.Grudges.ids[1]]
local recipient=make("Example","Author",nil,loaded.s.time)
for _,packet in ipairs(loaded.B.Grudges.Packets(old)) do recipient.B.Grudges.Receive(packet,loaded.B.name,"GUILD") end
check(recipient.B.Grudges.store.events[old.id],"Another client accepts a years-old full ledger record over the real packet path")
