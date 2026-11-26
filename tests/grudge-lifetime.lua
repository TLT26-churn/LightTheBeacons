local client,check=...
local function copy(t)
    if type(t)~="table" then return t end
    local out={};for k,v in pairs(t) do out[k]=copy(v) end;return out
end
local function join(a,b) a.B.members[b.B.me]=true;b.B.members[a.B.me]=true end
local function award(c,n)
    c.advance(12)
    local guid=string.format("Player-2-%04X",n)
    local e=assert(c.B.Grudges.Inscribe("Example Foe "..n,"Private grievance text "..n,guid))
    c.B.Client.CombatEvent(0,"PARTY_KILL",false,c.env.UnitGUID("player"),c.B.name,0x410,0,guid,e.enemy,0x440,0)
    return e,assert(c.B.Grudges.entries[e.id].seal)
end
local function pump(peers,seconds)
    for _=1,seconds*2 do
        for _,c in ipairs(peers) do c.advance(.5);c.B.Grudges.Tick() end
        for _,a in ipairs(peers) do
            for i=(a.cursor or 0)+1,#a.s.sent do
                local p=a.s.sent[i]
                if p[1]==a.B.Grudges.prefix and a.s.sendResult==0 then
                    check(#p[2]<=250 and p[3]=="GUILD","Lifetime history stays inside bounded guild addon packets")
                    for _,b in ipairs(peers) do if a~=b then b.B.Grudges.Receive(p[2],a.B.name,p[3]) end end
                end
            end
            a.cursor=#a.s.sent
        end
    end
end
local a=client("Sample","Avenger");local G=a.B.Grudges
local e,v=award(a,1)
local receipt=G.store.lifetime["r."..e.id]
check(receipt and receipt.author==a.B.name,"A verified resolution is archived immediately")
check(not G.Encode(receipt):find(e.note,1,true) and not G.Encode(receipt):find(e.enemy,1,true),"Lifetime receipts exclude grievance text and enemy names")
local beforeUpgrade=copy(a.B.db);beforeUpgrade.grudges.lifetime=nil;beforeUpgrade.grudges.lifetimeAccepted=nil
a.s.time=a.s.time+G.retention+30;a.advance(1);G.Tick()
check(#G.ids==0 and G.Leaderboard()[1].count==1,"Ninety-day pruning removes full events but keeps earned points")
local reload=client("Sample","Avenger",copy(a.B.db),a.s.time)
check(reload.B.Grudges.Leaderboard()[1].count==1 and #reload.B.Grudges.ids==0,"Lifetime totals survive a reload after the full book has expired")
local upgrade=client("Sample","Avenger",beforeUpgrade,a.s.time)
check(upgrade.B.Grudges.Leaderboard()[1].count==1 and #upgrade.B.Grudges.ids==0,"First upgrade archives existing saved resolutions before pruning an old book")
check(not upgrade.B.Grudges.Parse(upgrade.B.Grudges.Encode(e),upgrade.s.time),"Live network parsing still rejects expired full grievances")
local saved=copy(upgrade.B.db)
local cold=client("Sample","Avenger",saved,upgrade.s.time,true,true,nil,{noGuildAtLogin=true})
check(#cold.B.Grudges.Leaderboard()==0 and next(cold.B.db.grudges.lifetime),"Unavailable guild membership hides lifetime scores without erasing their save")
cold.s.guild=true;cold.B.GuildChanged()
check(cold.B.Grudges.Leaderboard()[1].count==1,"Restored same-guild identity restores lifetime scores")
cold.env.C_Club.GetGuildClubId=function() return 99 end;cold.B.GuildChanged()
check(#cold.B.Grudges.Leaderboard()==0 and not next(cold.B.db.grudges.lifetime),"A confirmed different guild cannot inherit lifetime credits")

-- A deletion remains effective after both the original grudge and its normal
-- deletion event expire. Archived credit must not revive it through history.
local owner=client("Example","Author");local O=owner.B.Grudges
local removed=award(owner,2);owner.advance(3);assert(O.Withdraw(removed.id))
local tombstone=copy(O.store.lifetime["x."..removed.id]);local stale=copy(O.store.lifetime["r."..removed.id])
check(tombstone and #O.Leaderboard()==0,"Deliberate deletion removes lifetime credit immediately")
local oldDeleted=copy(owner.B.db);oldDeleted.grudges.lifetime=nil;oldDeleted.grudges.lifetimeAccepted=nil
owner.s.time=owner.s.time+O.retention+60;owner.advance(1);O.Tick()
local deletedReload=client("Example","Author",copy(owner.B.db),owner.s.time)
check(#deletedReload.B.Grudges.Leaderboard()==0 and deletedReload.B.Grudges.store.lifetime[tombstone.id],"Deletion receipt and zero score survive pruning and reload")
local deletedUpgrade=client("Example","Author",oldDeleted,owner.s.time)
check(#deletedUpgrade.B.Grudges.Leaderboard()==0 and deletedUpgrade.B.Grudges.store.lifetime[tombstone.id],"Upgrade preserves an old authorized deletion before pruning its source events")
local reader=client("Sample","Reader",nil,owner.s.time);join(owner,reader)
local D=reader.B.Grudges
check(D.Merge(stale,owner.B.me,true) and D.Leaderboard()[1].count==1,"Historical credit can arrive before its withdrawal")
check(D.Merge(tombstone,owner.B.me,true) and #D.Leaderboard()==0,"Original author's archived withdrawal removes historical credit")
D.Merge(stale,owner.B.me,true)
check(#D.Leaderboard()==0,"Repeated stale credit cannot restore a deliberately removed point")
local stranger=client("Another","Member",nil,owner.s.time);join(owner,stranger)
local forged=copy(tombstone);forged.author=stranger.B.name;forged.enemy=O.Hash(stranger.B.me).."."..forged.at..".123.1"
check(D.Parse(D.Encode(forged),reader.s.time) and not D.Merge(forged,stranger.B.me,true),"A syntactically valid ordinary member's withdrawal cannot remove somebody else's lifetime credit")
local unauthorized=copy(reader.B.db);unauthorized.grudges.lifetimeAccepted={}
local unsafe=client("Sample","Reader",unauthorized,reader.s.time)
check(not unsafe.B.Grudges.store.lifetime[tombstone.id],"Unverified saved withdrawal data is not trusted as moderation proof")

local roster={{name="Example Author",guildRankOrder=3,guildRank="Member"},
    {name="Guild Officer",guildRankOrder=2,guildRank="Officer"},
    {name="Sample Reader",guildRankOrder=4,guildRank="Recruit"}}
local moderator=client("Guild","Officer",nil,owner.s.time,nil,nil,nil,{guildRoster=roster})
local moderated=client("Sample","Reader",nil,owner.s.time,nil,nil,nil,{guildRoster=roster})
join(moderator,moderated)
moderated.B.GrudgePermissions.Receive("1|Q|"..moderated.B.guild,moderator.B.name,"GUILD")
moderated.B.Grudges.Merge(stale,owner.B.me,true)
check(moderated.B.Grudges.Merge(tombstone,moderator.B.me,true) and #moderated.B.Grudges.Leaderboard()==0,
    "A currently authorized moderator can vouch for an archived author withdrawal")
local afterModeration=client("Sample","Reader",copy(moderated.B.db),moderated.s.time)
check(#afterModeration.B.Grudges.Leaderboard()==0,"Accepted lifetime moderation survives a later roster or rank change")

local manualFirst=client("Manual","Recorder");local M=manualFirst.B.Grudges
local me=assert(M.Inscribe("Example Opponent","A manual resolution came first."));manualFirst.advance(3)
assert(M.Avenge(me.id));local noPoint=copy(M.store.lifetime["r."..me.id])
local lateClaim=copy(noPoint);lateClaim.at=lateClaim.at+10;lateClaim.guid="Player-2-00AB";lateClaim.evidence="kill"
lateClaim.enemy=M.Hash(manualFirst.B.me).."."..lateClaim.at..".999.1"
local manualReader=client("Sample","Reader",nil,manualFirst.s.time+10)
manualReader.B.Grudges.Merge(lateClaim,manualFirst.B.me,true)
manualReader.B.Grudges.Merge(noPoint,manualFirst.B.me,true)
check(#manualReader.B.Grudges.Leaderboard()==0,"An earlier manual receipt removes a later stale kill claim without awarding a point")

-- Two guild caches remember disjoint old wins by the same avenger. The union
-- must score two, not max(one, one), and must not depend on full grudge text.
local source=client("Shared","Avenger");local i1,s1=award(source,10);local i2,s2=award(source,11)
local left=client("Archive","One",nil,source.s.time);local right=client("Archive","Two",nil,source.s.time)
join(left,right)
for _,e2 in ipairs({i1,s1}) do left.B.Grudges.Merge(e2,source.B.me,true) end
for _,e2 in ipairs({i2,s2}) do right.B.Grudges.Merge(e2,source.B.me,true) end
for _,c in ipairs({left,right}) do
    c.s.time=source.s.time+c.B.Grudges.retention+120;c.B.Grudges.Tick()
    c.B.Grudges.queue={};c.B.Grudges.request=nil;c.B.Grudges.nextQuery=c.s.now;c.s.sent={}
end
check(#left.B.Grudges.ids==0 and #right.B.Grudges.ids==0,"Disjoint cache test has no ordinary ledger history left")
pump({left,right},160)
check(left.B.Grudges.Leaderboard()[1].count==2 and right.B.Grudges.Leaderboard()[1].count==2,"Archive-only guild sync unions disjoint resolutions into the same lifetime total")
check(left.B.Grudges.digest==right.B.Grudges.digest,"Lifetime inventories converge deterministically")
local newcomer=client("New","Reader",nil,left.s.time);join(left,newcomer);join(right,newcomer)
pump({left,right,newcomer},180)
check(newcomer.B.Grudges.Leaderboard()[1].count==2 and #newcomer.B.Grudges.ids==0,"A new guildmate receives lifetime scores without expired grievance text")
newcomer.B.GrudgeUI.Toggle(true);newcomer.B.GrudgeUI.Mode("leaderboard")
check(newcomer.B.GrudgeUI.leaderRows[1].count:GetText()==2 and newcomer.B.GrudgeUI.leaderHelp:IsShown()
    and not newcomer.B.GrudgeUI.resolutionRows[1]:IsShown(),"Lifetime-only leaderboard shows totals and an explanation in place of missing details")

-- A growing lifetime archive does not consume the ordinary book's capacity.
local large=client("Sample","Archivist",nil,left.s.time);local LG=large.B.Grudges
for i=1,LG.limit+5 do
    local old=copy(receipt);old.target=LG.Hash(old.where:lower())..".1990000000.333."..i
    old.id="r."..old.target;old.at=1990000000+i*12;old.note="1989999999:"
    old.enemy=LG.Hash(old.author:lower()).."."..old.at..".333."..i
    old.guid=string.format("Player-2-%08X",i)
    local parsed=assert(LG.Parse(LG.Encode(old),large.s.time));LG.store.lifetime[parsed.id]=parsed
end
LG.Rebuild()
check(#LG.ids==0 and LG.Leaderboard()[1].count==LG.limit+5,"Lifetime credits continue beyond the full-history 1,200-event cap")
check(LG.Inscribe("Current Example Enemy","The active book still has room."),"A full lifetime archive does not prevent new grudges")

-- Legacy requests get ordinary ledger data, never an unbounded credit archive.
local legacy=client("Older","Reader",nil,source.s.time);join(source,legacy)
local S=source.B.Grudges;S.queue={};S.request=nil
S.Receive("1|Q|123.456|00000000",legacy.B.name,"GUILD")
check(S.queue[1] and S.queue[1].msg:match("|"..#S.ids.."$"),"Legacy inventory offers count only ordinary records")
S.queue={};S.Receive("1|W|123.456|"..S.Hash(source.B.me).."|",legacy.B.name,"GUILD")
local legacyPackets=0
for _,item in ipairs(S.queue) do
    if item.msg:find("|S|",1,true) then
        legacyPackets=legacyPackets+1
        check(not item.msg:match("|[rx]%.[^|]+|%d+|%d+|"),"Legacy history never includes lifetime receipt IDs")
    end
end
check(legacyPackets>0,"Legacy compatibility test actually serves a history page")

-- Immutable source identity and guild scope remain mandatory for old credits.
local bad=copy(receipt);bad.author="Wrong Author"
check(not G.Parse(G.Encode(bad),a.s.time),"Forged credit author/source-ID mismatch is rejected")
bad=copy(receipt);bad.note="0:Creature-2-1234"
check(not G.Parse(G.Encode(bad),a.s.time),"Invalid archived victim identity is rejected")
bad=copy(receipt);bad.guild="99"
check(not G.Parse(G.Encode(bad),a.s.time),"Lifetime receipt from a different guild is rejected")
bad=copy(receipt);bad.at=a.s.time+61
check(not G.Parse(G.Encode(bad),a.s.time),"Future-dated lifetime credit is rejected")
