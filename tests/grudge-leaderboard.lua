-- Scores are reconstructed from the actual shared event log, not mutable totals.
local client,check=...
local function join(a,b) a.B.members[b.B.me]=true;b.B.members[a.B.me]=true end
local function deliver(a,b,e)
    for _,packet in ipairs(a.B.Grudges.Packets(e)) do b.B.Grudges.Receive(packet,a.B.name,"GUILD") end
end
local function kill(c,guid,name,source)
    c.B.Client.CombatEvent(0,"PARTY_KILL",false,source or c.env.UnitGUID("player"),c.B.name,0x410,0,guid,name,0x440,0)
end
local a=client("Sample","Scribe");local b=client("Example","Avenger");join(a,b)
local A,K=a.B.Grudges,b.B.Grudges
local guid="Player-2-00AB"
local first=assert(A.Inscribe("Example Enemy","Attacked our caravan.",guid))
deliver(a,b,first);b.advance(3)
kill(b,guid,first.enemy,"Player-1-Other")
check(#K.Leaderboard()==0,"Another party member's kill never earns the local player leaderboard credit")
kill(b,"Creature-2-00AB",first.enemy)
check(#K.Leaderboard()==0,"NPC kills do not score")
kill(b,guid,first.enemy)
local seal=K.entries[first.id].seal;deliver(b,a,seal)
local scores=A.Leaderboard()
check(#scores==1 and scores[1].key==b.B.me and scores[1].count==1,"A verified kill earns the avenger exactly one point in the shared leaderboard")
check(scores[1].records[1].entry.author==a.B.name and scores[1].records[1].seal.author==b.B.name,
    "Resolution detail retains both the original grudge author and the actual avenger")
kill(b,guid,first.enemy);deliver(b,a,seal);A.Rebuild()
check(A.Leaderboard()[1].count==1 and K.Leaderboard()[1].count==1,"Duplicate combat callbacks, packets and rebuilds never add points")
a.advance(3);b.advance(3)
local second=assert(A.Inscribe(first.enemy,"A second attack.",guid));deliver(a,b,second)
kill(b,guid,first.enemy)
check(not K.entries[second.id].seal and K.Leaderboard()[1].count==1,"A repeated report of the same kill cannot settle a second grudge")
b.advance(10);kill(b,guid,first.enemy);deliver(b,a,K.entries[second.id].seal)
check(A.Leaderboard()[1].count==2 and A.Leaderboard()[1].records[1].entry.id==second.id,
    "A later distinct kill earns a second point, with newest resolutions first")
a.advance(3)
local manual=assert(A.Inscribe("Sample Rival","A manually confirmed defeat."));deliver(a,b,manual)
b.advance(3);local manualSeal=assert(K.Avenge(manual.id));deliver(b,a,manualSeal)
check(A.Leaderboard()[1].count==2,"Manual Mark avenged actions never award leaderboard points")
check(not K.Avenge(manual.id,guid,"kill"),"A manual resolution cannot be upgraded into an extra score")

-- History can arrive before the inscription, through another guild cache.
local late=client("Sample","Reader");join(a,late);join(b,late)
local L=late.B.Grudges
L.Merge(seal,a.B.me,true)
check(#L.Leaderboard()==0,"An orphan seal does not score until its grudge arrives")
L.Merge(first,a.B.me,true)
check(L.Leaderboard()[1].key==b.B.me and L.Leaderboard()[1].count==1,"Offline history credits the recorded avenger, not the cache that relayed it")
L.Merge(second,a.B.me,true);L.Merge(K.entries[second.id].seal,a.B.me,true)
local reload=client("Sample","Reader",late.B.db,b.s.time)
check(reload.B.Grudges.Leaderboard()[1].count==2,"Existing verified resolutions and scores survive reload without a migration or new protocol")

-- Local filters do not change shared rankings; details honor hidden enemies.
A.options.hidden[a.B.Protocol.Identity(first.enemy)]=true
local U=a.B.GrudgeUI;U.Toggle(true);U.leaderboardTab.scripts.OnClick()
check(U.mode=="leaderboard" and U.leaderboard:IsShown() and not U.index:IsShown() and not U.read:IsShown()
    and not U.compose:IsShown(),"Leaderboard has its own mutually exclusive book tab")
check(U.leaderRows[1].name:GetText()==b.B.name and U.leaderRows[1].count:GetText()==2,
    "The book shows the avenger's name and verified total")
check(U.resolutionRows[1].author:GetText()=="For "..a.B.name and U.resolutionRows[1].enemy:GetText()=="Hidden enemy"
    and not U.resolutionRows[1].enabled,"Hidden enemies retain their score without exposing their name or opening their folio")
check(U.leaderSummary:GetText():find("90 days",1,true) and U.leaderSummary:GetText():find("Manual marks excluded",1,true),
    "The visible summary explains retention and the manual-resolution exclusion")
A.options.hidden={};U.Refresh();U.resolutionRows[1].scripts.OnClick(U.resolutionRows[1])
check(U.mode=="person" and U.Record().entry.id==second.id,"Clicking a resolution opens that exact grudge, not just its enemy")
U.Mode("leaderboard");U.Mode("inscribe")
check(not U.leaderboard:IsShown() and U.compose:IsShown(),"Switching out of the leaderboard hides its contents")
a.advance(3);assert(A.Edit(first.id,"Corrected caravan report."))
check(A.Leaderboard()[1].count==2,"Editing the grievance does not change the avenger's score")
a.advance(3);local deletion=assert(A.Withdraw(first.id));deliver(a,b,deletion)
check(A.Leaderboard()[1].count==1 and K.Leaderboard()[1].count==1,"A deleted grudge is removed from both clients' scores")
deliver(b,a,seal)
check(A.Leaderboard()[1].count==1,"A replay cannot resurrect credit for a deleted entry")
a.s.time=a.s.time+A.retention+1
check(#A.Leaderboard()==0,"Expired entries stop scoring even before pruning or while sharing is paused")
U.Mode("leaderboard")
check(U.emptyLeaders:IsShown() and U.leaderHelp:IsShown() and not U.leaderRows[1]:IsShown()
    and not U.nextLeaders.enabled and not U.nextResolutions.enabled,"Empty history shows an explanation with inactive pagination")
reload.B.GrudgeUI.Toggle(true);reload.B.GrudgeUI.Mode("leaderboard")
reload.env.C_Club.GetGuildClubId=function() return 99 end;reload.B.GuildChanged()
check(#reload.B.Grudges.Leaderboard()==0 and not reload.B.GrudgeUI.selectedLeader
    and reload.B.GrudgeUI.leaderPage==1,"Guild changes clear leaderboard totals and selection with the old ledger")

-- Adversarial ordering: conflicting claims for one kill still award one point.
local race=client("Sample","Scribe");local R=race.B.Grudges
local one=assert(R.Inscribe("Training Foe","First incident.",guid));race.advance(3)
local two=assert(R.Inscribe("Training Foe","Second incident.",guid))
local function claim(c,author,id,target,at,victim,evidence)
    local g=c.B.Grudges
    return assert(g.Parse(g.Encode({kind="V",id=g.Hash(c.B.Protocol.Identity(author)).."."..at..".54321."..id,
        author=author,at=at,target=target,enemy="",guid=victim or "",where="Elwynn Forest",note="",evidence=evidence or "kill",guild=g.scope}),c.s.time))
end
local ca=claim(race,"Example Avenger",1,one.id,race.s.time,guid)
local cb=claim(race,"Sample Defender",2,two.id,race.s.time,guid)
R.Merge(cb,race.B.Protocol.Identity(cb.author),false);R.Merge(ca,race.B.Protocol.Identity(ca.author),false)
local rr=R.Leaderboard()
check(#rr==1 and rr[1].count==1,"Competing same-kill claims for different grudges award only one point")
local reverse=client("Sample","Scribe");local Q=reverse.B.Grudges
for _,e in ipairs({ca,cb,two,one}) do Q.Merge(e,reverse.B.Protocol.Identity(e.author),false) end
check(Q.Leaderboard()[1].key==rr[1].key and Q.Leaderboard()[1].records[1].seal.id==rr[1].records[1].seal.id,
    "Out-of-order event delivery converges on the same leaderboard winner")
race.advance(12)
local unsealed=not R.entries[one.id].seal and one or two
local wrong=claim(race,"Sample Defender",3,unsealed.id,race.s.time,"Player-2-00FF")
R.Merge(wrong,race.B.Protocol.Identity(wrong.author),false)
check(#R.Leaderboard()==1 and R.Leaderboard()[1].count==1,"A kill for a mismatched player GUID cannot earn credit")

-- Full-book pagination, ties and clickable history beyond page one.
local preview=client("Sample","Scribe",nil,os.time({year=2026,month=11,day=13,hour=12,min=0}))
local V=preview.B.Grudges
local names={"Example Avenger","Sample Defender","Training Warden","Example Sentinel","Sample Outrider",
    "Training Vanguard","Example Watchkeeper","Sample Guardian","Training Champion"}
for i,name in ipairs(names) do
    for j=1,(i==1 and 6 or i==2 and 3 or 1) do
        local enemy="Example Rival "..i.." "..j;local victim=string.format("Player-2-%04X",i*10+j)
        local entry=assert(V.Inscribe(enemy,"Attacked the guild patrol.",victim));preview.advance(3)
        local e=claim(preview,name,i*10+j,entry.id,preview.s.time,victim)
        V.Merge(e,preview.B.Protocol.Identity(name),false);preview.advance(3)
    end
end
local board=V.Leaderboard()
check(#board==9 and board[1].count==6 and board[2].count==3 and board[3].rank==3 and board[9].rank==3,
    "Rankings sort by total and give equal scores the same rank")
check(board[3].key<board[4].key,"Ties have deterministic alphabetical display order")
local UI=preview.B.GrudgeUI;UI.Toggle(true);UI.Mode("leaderboard")
UI.Refresh();UI.leaderRows[1].scripts.OnEnter(UI.leaderRows[1]);local hovered=UI.leaderRows[1].hover:IsShown()
UI.leaderRows[1].scripts.OnLeave(UI.leaderRows[1])
check(hovered and not UI.leaderRows[1].hover:IsShown(),"Row hover remains interactive after refreshed tooltips are attached")
check(UI.leaderCount:GetText()=="1 / 2" and UI.nextLeaders.enabled and not UI.prevLeaders.enabled,
    "More than eight ranked guildmates have independent leaderboard pagination")
check(UI.resolutionCount:GetText()=="1 / 2" and UI.nextResolutions.enabled,"Recent resolutions paginate independently")
UI.nextResolutions.scripts.OnClick()
check(UI.resolutionPage==2 and UI.resolutionRows[2]:IsShown() and not UI.resolutionRows[3]:IsShown(),
    "The final resolution page hides unused rows")
local viewed=UI.resolutionRows[1].recordID;UI.resolutionRows[1].scripts.OnClick(UI.resolutionRows[1])
check(UI.Record().entry.id==viewed,"A resolution on a later page opens its exact ledger record")
UI.Mode("leaderboard");UI.leaderRows[2].scripts.OnClick(UI.leaderRows[2])
check(UI.selectedLeader==board[2].key and UI.resolutionPage==1 and UI.resolver:GetText()==board[2].name,
    "Choosing another guildmate resets and updates their recent resolutions")
UI.nextLeaders.scripts.OnClick()
check(UI.leaderPage==2 and UI.selectedLeader==board[9].key and UI.leaderRows[1]:IsShown() and not UI.leaderRows[2]:IsShown(),
    "Turning the leaderboard selects a visible guildmate and hides stale rows")
UI.prevLeaders.scripts.OnClick()
check(UI.leaderPage==1 and UI.selectedLeader==board[1].key,"Returning to the first page selects its first ranked guildmate")
for _,theme in ipairs({"alliance","horde","dark","ellesmere"}) do
    preview.B.Theme.Apply(theme)
    check(UI.leaderboard:IsShown() and UI.leaderRows[1].name:GetText()==board[1].name,"Leaderboard remains usable with the "..theme.." theme")
end
preview.B.Theme.Apply("alliance");V.status="Guild ledger ready.";UI.Refresh()
return preview
