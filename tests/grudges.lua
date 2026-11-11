-- Real modules in isolated client environments, including live and historical delivery.
local client,check=...
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function member(a,b) a.B.members[b.B.me]=true;b.B.members[a.B.me]=true end
local function deliver(a,b,packets,reverse)
    for i=1,#packets do
        local packet=packets[reverse and #packets-i+1 or i]
        check(#packet<=250,"Every grudge packet fits the WoW addon-message limit")
        b.B.eventFrame.scripts.OnEvent(b.B.eventFrame,"CHAT_MSG_ADDON",a.B.Grudges.prefix,packet,"GUILD",a.B.name)
    end
end
local function pump(peers,seconds,drop)
    for _=1,math.ceil(seconds*2) do
        for _,c in ipairs(peers) do c.advance(.5);c.B.Grudges.Tick() end
        for _,a in ipairs(peers) do
            for i=(a.networkCursor or 0)+1,#a.s.sent do
                local p=a.s.sent[i]
                if p[1]==a.B.Grudges.prefix then
                    check(#p[2]<=250 and p[3]=="GUILD","Grudges use bounded guild addon packets only")
                    if not drop or not drop(p[2]) then
                        for _,b in ipairs(peers) do if a~=b then
                            b.B.eventFrame.scripts.OnEvent(b.B.eventFrame,"CHAT_MSG_ADDON",p[1],p[2],p[3],a.B.name)
                        end end
                    end
                end
            end
            a.networkCursor=#a.s.sent
        end
    end
end
local a=client("Aldric","Stoneward");local b=client("Elowen","Dawnwatch");member(a,b)
local A,D=a.B.Grudges,b.B.Grudges
local note="A wrong written in iron and ink. "..string.rep("é",110)
local e=assert(A.Inscribe("Doctor Deathjuice",note,"Player-2-00AB"))
check(e.note==note and #note>128,"Grievances retain complete multi-byte text beyond beacon-message length")
local packets=A.Packets(e);check(#packets>1,"Long entries are fragmented")
deliver(a,b,packets,true)
check(D.entries[e.id] and D.entries[e.id].entry.note==note,"Reversed fragments reconstruct UTF-8 exactly")
deliver(a,b,packets)
check(#D.ids==1,"Duplicate delivery never duplicates a grievance")
check(D.people[D.entries[e.id] and b.B.Protocol.Identity(e.enemy)].open==1,"Shared debt remains open")
local raw=A.Encode(e)
check(not A.Parse(raw.."|extra",a.s.time),"Extra serialized fields rejected")
check(not A.Parse(raw:gsub("1|I","2|I",1),a.s.time),"Unknown schema rejected")
check(not A.Parse(raw:gsub("Doctor Deathjuice","|Hitem:1|h",1),a.s.time),"Game hyperlinks cannot enter a grievance")
local stranger=client("Nobody","Else")
for _,packet in ipairs(packets) do stranger.B.Grudges.Receive(packet,a.B.name,"PARTY") end
check(#stranger.B.Grudges.ids==0,"Party traffic is rejected")
stranger.B.members[a.B.me]=nil
for _,packet in ipairs(packets) do stranger.B.Grudges.Receive(packet,a.B.name,"GUILD") end
check(#stranger.B.Grudges.ids==0,"Non-guild senders are rejected")
local forged=client("Elowen","Dawnwatch")
for _,packet in ipairs(packets) do forged.B.Grudges.Receive(packet,"Elowen Dawnwatch","GUILD") end
check(#forged.B.Grudges.ids==0,"A live author cannot be spoofed by another guild sender")
local adversary=client("Aldric","Stoneward");member(adversary,b)
check(not D.Withdraw(e.id),"Only the entry's author can withdraw through the UI/API")
b.advance(3);local seal=assert(D.Avenge(e.id))
deliver(b,a,D.Packets(seal))
check(A.entries[e.id].seal.author==b.B.name and A.people[a.B.Protocol.Identity(e.enemy)].open==0,"A guildmate may avenge a shared debt with attribution")
check(A.entries[e.id].entry.note==note,"Vengeance retains the original account")
check(not A.Avenge(e.id),"A settled debt cannot be settled twice")
local reordered=client("Aldric","Stoneward");member(reordered,b)
deliver(b,reordered,D.Packets(seal))
-- Deliver entry as history through Merge to model the later arrival of its author packet.
check(reordered.B.Grudges.Merge(e,a.B.me,false),"An inscription may arrive after its seal")
check(reordered.B.Grudges.entries[e.id].seal.id==seal.id,"Reordered seal and inscription converge")
a.advance(3);local withdrawal=assert(A.Withdraw(e.id));deliver(a,b,A.Packets(withdrawal))
check(not D.people[b.B.Protocol.Identity(e.enemy)],"Author withdrawal hides the shared entry")
check(D.store.events[e.id] and D.store.events[withdrawal.id],"Withdrawal tombstone prevents stale replay resurrection")
deliver(a,b,packets);check(not D.people[b.B.Protocol.Identity(e.enemy)],"Stale inscription cannot undo withdrawal")
local illicit={kind="D",id=D.Hash(b.B.me)..".2000000001.123.1",author=b.B.name,at=math.floor(b.s.time),target=e.id,enemy="",guid="",where="",note="",evidence="manual",guild=D.scope}
-- Separate fresh record for permission check.
a.advance(3);local own=assert(A.Inscribe("Mogrash Ironjaw","Attacked our wounded."))
illicit.target=own.id;check(A.Merge(illicit,b.B.me,false),"Authenticated but unauthorized claim is retained for deterministic replay")
check(not A.deleted[own.id],"A peer's withdrawal cannot remove another author's wrong")
local reloaded=client("Aldric","Stoneward",a.B.db,a.s.time)
check(reloaded.B.Grudges.entries[own.id] and reloaded.B.Grudges.deleted[e.id],"Saved records and withdrawal tombstones survive reload")
reloaded.env.C_Club.GetGuildClubId=function() return 99 end;reloaded.B.GuildChanged()
check(#reloaded.B.Grudges.ids==0 and reloaded.B.Grudges.store.guild=="99","Changing guild clears the previous guild's cache and outbox")
check(#reloaded.B.Grudges.queue==0,"No old-guild packets survive a guild change")
deliver(a,reloaded,A.Packets(own))
check(#reloaded.B.Grudges.ids==0,"Delayed previous-guild traffic is rejected even when its author remains a guildmate")
local uncertain=client("Aldric","Stoneward")
assert(uncertain.B.Grudges.Inscribe("Waiting Enemy","A queued wrong."))
uncertain.env.C_Club.GetGuildClubId=function() return nil end;uncertain.B.GuildChanged()
check(uncertain.B.guildPending and not uncertain.B.Grudges.Active(),"Unknown guild identity suspends ledger traffic")
uncertain.s.sent={};uncertain.advance(2);uncertain.B.Grudges.Tick()
check(#uncertain.s.sent==0,"A queued entry is not broadcast while guild identity is uncertain")
local malicious=client("Elowen","Dawnwatch");local MG=malicious.B.Grudges
local oversizedNonce=string.rep("1",68)
MG.Receive("1|W|"..oversizedNonce.."|"..MG.Hash(malicious.B.me).."|",a.B.name,"GUILD")
check(#MG.queue==0,"Oversized request nonces cannot cause overlong response packets")
local biggest={kind="I",author=string.rep("é",50),at=math.floor(a.s.time),target="",enemy=string.rep("é",50),
    guid="Player-1-"..string.rep("A",71),where=string.rep("é",50),note=string.rep("\240\159\148\165",160),evidence="manual",guild=A.scope}
biggest.id=A.Hash(a.B.Protocol.Identity(biggest.author)).."."..string.rep("1",59)
check(A.Parse(A.Encode(biggest),a.s.time),"Largest legal UTF-8 fields survive the record codec")
for _,packet in ipairs(A.Packets(biggest,string.rep("1",28),"12345678")) do check(#packet<=250,"Maximum legal sync headers and text remain within packet budget") end
local isolated=client("Elowen","Dawnwatch");local IG=isolated.B.Grudges
IG.Receive("1|S|1|"..IG.Hash(isolated.B.me).."|"..own.id.."|1|2|bad",a.B.name,"GUILD")
check(count(IG.pending)==0,"Unsolicited historical fragments are ignored")
IG.Receive("1|E|"..own.id.."|1|2|partial",a.B.name,"GUILD")
check(count(IG.pending)==1,"An incomplete live record remains bounded in assembly")
isolated.advance(151);IG.Tick();check(count(IG.pending)==0,"Incomplete fragment buffers expire")
-- A quiet new client learns missed inscriptions and seals from an online peer.
local s1=client("Aldric","Stoneward");local s2=client("Elowen","Dawnwatch");member(s1,s2)
local historic={}
for i=1,16 do
    historic[i]=assert(s1.B.Grudges.Inscribe("Enemy "..i,"A witnessed wrong, number "..i));s1.advance(3)
end
pump({s1,s2},100)
check(#s2.B.Grudges.ids==16,"Live queue reaches another client without oversize packets")
s2.advance(3);local hseal=assert(s2.B.Grudges.Avenge(historic[1].id));pump({s1,s2},20)
local late=client("Whitebeard","Tinkerton",nil,s1.s.time);member(s1,late);member(s2,late)
late.s.now=s1.s.now;late.B.Grudges.nextQuery=late.s.now
pump({s1,s2,late},160)
check(#late.B.Grudges.ids==17,"A new client receives more than one page of offline history")
check(late.B.Grudges.entries[historic[1].id].seal.id==hseal.id,"Offline sync includes avenged history")
check(s1.B.Grudges.digest==late.B.Grudges.digest,"Peer inventories converge")
check(not late.B.GrudgeUI.toast or not late.B.GrudgeUI.toast:IsShown(),"Historical sync does not replay incident alerts")
-- Lost live packet: anti-entropy repairs it without reannouncing the event.
s1.advance(3);local lost=assert(s1.B.Grudges.Inscribe("Lost Page","The live ink was delayed."))
pump({s1,late},12,function(packet) return packet:match("^1|E|")~=nil end)
check(not late.B.Grudges.entries[lost.id],"Test actually loses the new live entry")
late.B.Grudges.request=nil;late.B.Grudges.nextQuery=late.s.now;s1.B.Grudges.offers={}
pump({s1,late},100)
check(late.B.Grudges.entries[lost.id],"Periodic inventory sync repairs a lost live packet")
local queued=assert(late.B.Grudges.Inscribe("Queue Test","Written during chat lockdown."));late.s.restricted=true
pump({late},3);check(late.B.Grudges.store.outbox[queued.id],"Lockdown retains the local outbox")
late.s.restricted=false;pump({late,s1},15)
check(s1.B.Grudges.entries[queued.id] and not late.B.Grudges.store.outbox[queued.id],"Queued entry retries after restrictions end")
late.B.Grudges.SetEnabled(false);late.advance(3)
check(not late.B.Grudges.Inscribe("Paused","This must not be sent."),"Paused sharing makes the book read-only")
check(#late.B.Grudges.queue==0,"Pausing sharing clears unsent transport packets")
-- Confirmed death attribution: never guess from a caster name alone.
local death=client("Aldric","Stoneward");local DG=death.B.Grudges;death.s.dead=true
DG.SetDeathMode("auto")
local hit={0,"SPELL_DAMAGE",false,"Player-2-00FF","Doctor Deathjuice",0x440,0,"Player-1-Aldric","Aldric Stoneward",0,0,1,"Strike",1,100,0}
death.B.Client.CombatEvent(unpack(hit));death.B.Death();death.advance(1)
check(#DG.ids==1 and DG.log[1].enemy=="Doctor Deathjuice" and DG.log[1].evidence=="pvp","Confirmed hostile-player killing blow inscribes a death")
death.B.Death();death.advance(5);check(#DG.ids==1,"Repeated death notifications produce one inscription")
death.s.dead=false;death.B.eventFrame.scripts.OnEvent(death.B.eventFrame,"PLAYER_ALIVE")
death.s.dead=true;death.B.Client.CombatEvent(unpack(hit));death.B.Death();death.advance(1)
check(#DG.ids==2,"A later real death creates a distinct grievance")
local unknown=client("Aldric","Stoneward");unknown.s.dead=true;unknown.B.Death();unknown.advance(4)
check(#unknown.B.Grudges.ids==0,"An unattributed death does not invent an enemy")
local npc=client("Aldric","Stoneward");npc.s.dead=true;hit[4]="Creature-2-00FF";npc.B.Client.CombatEvent(unpack(hit));npc.B.Death();npc.advance(4)
check(#npc.B.Grudges.ids==0,"An NPC death is not a grudge")
local restricted=client("Aldric","Stoneward");restricted.s.combatRestricted=true;restricted.s.dead=true
restricted.env.CombatLogGetCurrentEventInfo=function() error("Restricted reader must not be called") end
restricted.B.Client.ReadCombatEvent();restricted.B.Death();restricted.advance(4)
check(#restricted.B.Grudges.ids==0,"Restricted combat data stays unread")
local killer=client("Aldric","Stoneward");local K=killer.B.Grudges
local victim="Player-2-00AA"
local k1=assert(K.Inscribe("Doctor Deathjuice","First wrong.",victim));killer.advance(3)
local k2=assert(K.Inscribe("Doctor Deathjuice","Second wrong.",victim));killer.advance(3)
local kill={0,"PARTY_KILL",false,"Player-1-Aldric","Aldric Stoneward",0x410,0,victim,"Doctor Deathjuice",0x440,0}
killer.B.Client.CombatEvent(unpack(kill));killer.B.Client.CombatEvent(unpack(kill))
check(K.entries[k1.id].seal and not K.entries[k2.id].seal,"One confirmed killing blow settles exactly one oldest debt")
killer.advance(10);kill[4]="Player-1-Other";killer.B.Client.CombatEvent(unpack(kill))
check(not K.entries[k2.id].seal,"Party member kills are not falsely credited as your own")
kill[4]="Player-1-Aldric";killer.B.Client.CombatEvent(unpack(kill));check(K.entries[k2.id].seal,"A later own killing blow settles the next debt")
check(K.Phrase("avenged",true)=="All grudges avenged.","Balanced phrase is reserved for zero debt")
-- Hostile target/mouseover sightings are local, rate limited, and hideable.
local watch=client("Aldric","Stoneward");local W=watch.B.Grudges
assert(W.Inscribe("Doctor Deathjuice","The book knows this one."));watch.s.sent={};watch.networkCursor=0
watch.env.UnitNameUnmodified=function(unit) if unit=="target" then return "Doctor","Deathjuice" end;return "Aldric","Stoneward" end
watch.env.UnitIsPlayer=function() return true end;watch.env.UnitCanAttack=function() return true end
W.ObserveUnit("target");check(W.sightings[watch.B.Protocol.Identity("Doctor Deathjuice")],"Observed hostile debtor records a local sighting")
check(#watch.s.sent==0,"Sightings never broadcast the observer's location")
local seenAt=W.seenAlert[watch.B.Protocol.Identity("Doctor Deathjuice")];watch.advance(2);W.ObserveUnit("target")
check(W.seenAlert[watch.B.Protocol.Identity("Doctor Deathjuice")]==seenAt,"Repeated sightings do not spam alerts")
watch.env.UnitCanAttack=function() return {secret=true} end
local ok=pcall(W.ObserveUnit,"target");check(ok,"Restricted target eligibility is ignored without comparing it")
watch.env.UnitCanAttack=function() return true end
watch.B.MuteBeacons(true);check(not watch.B.GrudgeUI.toast:IsShown(),"Global mute dismisses an already-visible grudge notice")
W.options.hidden[watch.B.Protocol.Identity("Doctor Deathjuice")]=true;check(#W.List()==0,"Personal hide removes a debtor only from your view")
check(count(W.people)==1,"Personal hide leaves shared data intact")
W.options.hidden={};watch.B.GrudgeUI.Toggle(true)
check(watch.B.GrudgeUI.frame:IsShown() and watch.B.GrudgeUI.read:IsShown(),"Native book opens the real guild ledger")
watch.B.GrudgeUI.Mode("inscribe");watch.B.GrudgeUI.name:SetText("Mogrash Ironjaw");watch.B.GrudgeUI.note:SetText("A second written grievance.")
watch.advance(3);watch.B.GrudgeUI.submit.scripts.OnClick()
check(W.people[watch.B.Protocol.Identity("Mogrash Ironjaw")],"Native inscription button writes an entry")
watch.B.GrudgeUI.Confirm("avenge");check(watch.B.GrudgeUI.confirm:IsShown(),"Manual vengeance asks for a witnessed defeat")
watch.advance(3);watch.B.GrudgeUI.CommitConfirmation()
check(watch.B.GrudgeUI.Record().seal,"Native seal action preserves and strikes the entry")
watch.B.GrudgeUI.Mode("settings");check(watch.B.GrudgeUI.settings:IsShown(),"Book settings are reachable")
watch.B.GrudgeUI.Mode("words");check(watch.B.GrudgeUI.words:IsShown(),"Approved phrase choices are reachable")
-- Expiry keeps the bounded history honest and does not affect flight data.
local oldCount=#W.ids;watch.s.time=watch.s.time+W.retention+2;watch.s.now=watch.s.now+61;W.Tick()
check(oldCount>0 and #W.ids==0 and watch.B.db.known[2],"Retention removes aged ledger records while preserving flight knowledge")
-- A representative real-widget scene for visual QA.
local preview=client("Sample","Scribe",nil,os.time({year=2026,month=11,day=11,hour=15,min=42}));local V=preview.B.Grudges
assert(V.Inscribe("Example Enemy","Fell upon our company at Zoram Strand while our wounded were being tended. Two of our own were slain before the beacon could be answered."));preview.advance(3)
local paid=assert(V.Inscribe("Example Enemy","Struck down our healer while the company held the road."));preview.advance(3)
assert(V.Avenge(paid.id));preview.advance(3)
assert(V.Inscribe("Sample Rival","Lay in wait upon the road and struck our wounded."));preview.advance(3)
local settled=assert(V.Inscribe("Training Foe","Broke the truce at the river crossing."));preview.advance(3)
assert(V.Avenge(settled.id));preview.B.GrudgeUI.Toggle(true)
preview.B.GrudgeUI.Select(preview.B.Protocol.Identity("Example Enemy"))
preview.B.GrudgeUI.noticeUntil=nil;preview.B.Grudges.status="Guild ledger ready.";preview.B.GrudgeUI.Refresh()
return preview
