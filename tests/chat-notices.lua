-- Exercise actual receive/write/UI paths. The client stub rejects ordinary chat.
local client,check=...
local function fresh(saved) return client("Elowen","Dawnwatch",saved) end
local seq=0
local function add(c,name,x,age,note)
    seq=seq+1;local p=c.B.Protocol
    c.B.members[p.Identity(name)]=true
    local b={id="notice."..seq,sent=c.s.time-(age or 0),map=1429,px=x or .1,py=.45,reason="aid",message=note}
    local msg=p.EncodeMessage(b);if msg then c.B.Receive(msg,name,"GUILD") end
    local packet=p.Encode(b);c.B.Receive(packet,name,"GUILD")
    return c.B.session.beacons[p.Identity(name)],packet
end
local function clear(c) c.s.messages={};c.s.lastMessage=nil end
local function has(c,part) return c.s.lastMessage and c.s.lastMessage:find(part,1,true)~=nil end
local function cancel(c,b) c.B.Receive("1|C|"..b.id,b.name,"GUILD") end
local function deliver(a,b,e,history)
    b.B.members[a.B.me]=true
    if history then b.B.Grudges.Merge(e,a.B.me,true)
    else for _,packet in ipairs(a.B.Grudges.Packets(e)) do b.B.Grudges.Receive(packet,a.B.name,"GUILD") end end
end

do
    local c=fresh();local b,u=c.B,c.B.UI
    check(b.db.chatEnabled and b.db.chatBeacons and b.db.chatGrudges and not b.db.chatJoins and not b.db.chatSightings,"Activity defaults are on; joins and sightings opt in")
    c.env.SlashCmdList.LIGHTTHEBEACONS("chat")
    check(u.chatPanel:IsShown() and u.frame:GetHeight()==510 and not u.filtersPanel:IsShown(),"Chat settings are accessible and fit the window")
    for _,key in ipairs({"chatBeacons","chatGrudges","chatJoins","chatSightings"}) do
        u[key]:SetChecked(not b.db[key]);u[key].scripts.OnClick(u[key])
    end
    local saved=fresh(b.db).B.db
    check(not saved.chatBeacons and not saved.chatGrudges and saved.chatJoins and saved.chatSightings,"All four preferences survive reload")
    local repaired=fresh({chatBeacons=1,chatGrudges="yes",chatJoins={},chatSightings=5}).B.db
    check(repaired.chatBeacons and repaired.chatGrudges and not repaired.chatJoins and not repaired.chatSightings,"Invalid settings restore typed defaults")
end

do
    local c=fresh();clear(c);local before=#c.s.sent
    local b,packet=add(c,"Sample Scout",.1,0,"Need help at the bridge.")
    check(#c.s.messages==1 and has(c,'Sample Scout has lit a beacon in Elwynn Forest (10, 45). "Need help at the bridge."'),"Fresh calls name the caller, place and optional note")
    c.B.Receive(packet,b.name,"GUILD");check(#c.s.messages==1,"Duplicate delivery cannot duplicate chat")
    add(c,"Sample Ranger",.5);check(#c.s.messages==2 and #c.s.sounds==1,"The shared horn cooldown does not suppress distinct chat calls")
    check(#c.s.sent==before,"Local notices produce no outgoing packets")
    cancel(c,b);check(has(c,"Sample Scout extinguished their beacon in Elwynn Forest."),"A logged call has a matching extinguish notice")
    local old=add(c,"Sample Veteran",.8,30);local n=#c.s.messages;cancel(c,old)
    check(#c.s.messages==n,"Older query replies and their cancellations stay quiet")
    clear(c);local first=add(c,"Sample Leader",.1);local join=add(c,"Sample Follower",.11)
    check(#c.s.messages==1,"Nearby joins are quiet by default")
    cancel(c,join);check(#c.s.messages==1,"Quiet joins do not create cancellation noise")
    c.B.db.chatJoins=true;local sounds=#c.s.sounds
    local joined=add(c,"Sample Guard",.12)
    check(#c.s.messages==2 and has(c,"Sample Guard joined a nearby beacon") and #c.s.sounds==sounds,"Optional join text never replays a horn")
    cancel(c,joined);check(has(c,"Sample Guard extinguished their beacon in Elwynn Forest."),"Opted-in joins have matching cancellation text")
    c.B.db.chatBeacons=false;clear(c);add(c,"Sample Silent",.9);cancel(c,first)
    check(#c.s.messages==0,"Beacon chat toggle also disables join and cancellation text")
end

for _,mode in ipairs({"silent","hidden","global","instance","chat master"}) do
    local c=fresh();clear(c)
    if mode=="global" then c.B.MuteBeacons(true)
    elseif mode=="instance" then c.env.IsInInstance=function() return true,"party" end
    elseif mode=="chat master" then c.B.db.chatEnabled=false
    else c.B.SetPlayerFilter("Sample Scout",mode,false) end
    local b=add(c,"Sample Scout");cancel(c,b)
    check(#c.s.messages==0,"Beacon notices respect "..mode.." suppression")
end

do
    local scribe=client("Aldric","Stoneward");local avenger=fresh();local witness=client("Karkin","Ironward")
    clear(scribe);clear(avenger);clear(witness)
    local entry=assert(scribe.B.Grudges.Inscribe("Sample Enemy","An old debt."));deliver(scribe,avenger,entry)
    avenger.advance(3);clear(avenger)
    local seal=assert(avenger.B.Grudges.Avenge(entry.id,"Player-2-00AA","kill"))
    check(has(avenger,"Elowen Dawnwatch avenged Aldric Stoneward's grudge against Sample Enemy in Elwynn Forest."),
        "The avenger sees the original scribe, enemy and zone")
    deliver(scribe,witness,entry);clear(witness);deliver(avenger,witness,seal)
    check(has(witness,"Elowen Dawnwatch avenged Aldric Stoneward's grudge against Sample Enemy in Elwynn Forest."),
        "Every live addon recipient sees the attributed vengeance line")
end

do
    local c=fresh();clear(c);c.B.Light()
    check(has(c,"Elowen Dawnwatch has lit a beacon"),"A successful own call gets local confirmation")
    local b=c.B.own;local response="1|R|"..b.id.."|"..b.owner
    c.B.Receive(response,"Aldric Stoneward","GUILD")
    check(has(c,"Aldric Stoneward answered Elowen Dawnwatch's beacon (1 ally on the way)."),"Your responder is named in chat")
    local n=#c.s.messages;c.B.Receive(response,"Aldric Stoneward","GUILD")
    check(#c.s.messages==n,"Repeated responses remain quiet")
    c.B.SetPlayerFilter("Sample Ally","silent",false);c.B.members[c.B.Protocol.Identity("Sample Ally")]=true
    c.B.Receive(response,"Sample Ally","GUILD");check(#c.s.messages==n,"Silenced responders do not create chat notices")
    c.B.Extinguish();check(has(c,"Elowen Dawnwatch extinguished their beacon in Elwynn Forest."),"A successful own extinguish is confirmed")
    local failed=fresh();failed.s.sendResult=5;clear(failed);failed.B.Light()
    check(not has(failed,"lit a beacon") and not failed.B.own,"Send failures never claim a successful call")
    local group=fresh();for i=1,20 do add(group,"Sample Ally "..i,.1+i*.0001) end
    clear(group);group.B.Answer()
    for _=1,20 do group.advance(2);group.B.TickAnswers() end
    check(#group.s.messages==1 and has(group,"shared beacon (20 callers)"),"Answering a group prints once across paced acknowledgements")
    group.B.Answer();check(#group.s.messages==1,"Resuming guidance cannot duplicate the answer confirmation")
end

do
    local a=client("Aldric","Stoneward");local b=fresh();clear(a);clear(b)
    local G=a.B.Grudges;G.options.notices=false
    local e=assert(G.Inscribe("Sample Enemy","An ambush."))
    check(#a.s.messages==1 and has(a,"Aldric Stoneward etched a grudge against Sample Enemy in Elwynn Forest. Queued for guild sharing."),"Grudge confirmation states queued sharing and is independent of popup settings")
    deliver(a,b,e);check(#b.s.messages==1 and has(b,"Aldric Stoneward etched a grudge against Sample Enemy in Elwynn Forest."),"Live guild records identify the scribe, enemy and place")
    deliver(a,b,e);check(#b.s.messages==1,"Duplicate grudge packets do not repeat chat")
    local history=fresh();clear(history);deliver(a,history,e,true)
    check(#history.s.messages==0 and history.B.Grudges.entries[e.id],"History syncing populates the book without activity chat")
    a.advance(3);local v=assert(G.Avenge(e.id));deliver(a,b,v)
    check(has(b,"Aldric Stoneward marked Aldric Stoneward's grudge against Sample Enemy avenged in Elwynn Forest."),"Manual vengeance names the avenger, original scribe, enemy and place")
    a.advance(3);local d=assert(G.Withdraw(e.id));deliver(a,b,d)
    check(has(b,"Aldric Stoneward withdrew their grudge against Sample Enemy in Elwynn Forest."),"Valid withdrawals have attributed notices")
    a.advance(3);local second=assert(G.Inscribe("Another Enemy","Another ambush."));deliver(a,b,second);clear(b)
    local illicit={kind="D",id=b.B.Grudges.Hash(b.B.me)..".2000000005.1.1",author=b.B.name,at=b.s.time,target=second.id,
        enemy="",guid="",where="",note="",evidence="manual",guild=b.B.Grudges.scope}
    local parsed=assert(G.Parse(G.Encode(illicit),a.s.time));clear(a);deliver(b,a,parsed)
    check(#a.s.messages==0 and not G.deleted[second.id],"An unauthorized withdrawal cannot create a false chat claim")
    a.advance(3);local kill=assert(G.Avenge(second.id,"Player-2-00AA","kill"));deliver(a,b,kill)
    check(has(b,"Aldric Stoneward avenged Aldric Stoneward's grudge against Another Enemy in Elwynn Forest."),"Confirmed vengeance names the avenger and original scribe")
    a.advance(3);local stale=assert(G.Inscribe("Delayed Enemy","A delayed entry."));local late=fresh(nil);late.advance(100);clear(late)
    deliver(a,late,stale);check(#late.s.messages==0 and late.B.Grudges.entries[stale.id],"Delayed live packets still sync without replaying old chat activity")
    for _,mode in ipairs({"hidden","global","off"}) do
        local c=fresh();clear(c)
        if mode=="hidden" then c.B.Grudges.options.hidden[c.B.Protocol.Identity(e.enemy)]=true
        elseif mode=="global" then c.B.MuteBeacons(true) else c.B.db.chatGrudges=false end
        deliver(a,c,e);check(#c.s.messages==0,"Grudge text respects "..mode.." suppression")
    end
end

do
    local c=fresh();local G=c.B.Grudges
    for i=1,5 do
        c.B.Client.CombatEvent(0,"SPELL_DAMAGE",false,"Player-2-000"..i,"Example Attacker "..i,0x440,0,
            "Player-1-Elowen",c.B.name,0,0,1,"Strike",1,100,i==5 and 0 or -1)
    end
    c.s.dead=true;c.B.Death();c.advance(1);clear(c)
    c.B.DeathUI.inscribe.scripts.OnClick()
    check(#G.ids==5 and #c.s.messages==1 and has(c,"Elowen Dawnwatch etched 5 grudges in Elwynn Forest:") and has(c,"and 2 more"),"Death selections produce one bounded summary, not one chat line per enemy")
    c.B.DeathUI.inscribe.scripts.OnClick();check(#c.s.messages==1,"Saving the same death selection twice remains quiet")
end

do
    local c=fresh();local G=c.B.Grudges
    assert(G.Inscribe("Example Enemy","A remembered wrong."));clear(c)
    c.env.UnitNameUnmodified=function(unit) if unit=="target" then return "Example","Enemy" end;return "Elowen","Dawnwatch" end
    c.env.UnitIsPlayer=function() return true end;c.env.UnitCanAttack=function() return true end
    G.ObserveUnit("target");check(#c.s.messages==0,"Sightings do not add chat by default")
    c.B.db.chatSightings=true;c.advance(61);G.ObserveUnit("target")
    check(#c.s.messages==1 and has(c,"Known enemy sighted: Example Enemy in Elwynn Forest (1 open grudge)."),"Optional sightings name the known enemy and place")
    G.ObserveUnit("target");check(#c.s.messages==1,"Repeated target/mouseover checks share the per-enemy cooldown")
    c.advance(61);G.options.hidden[c.B.Protocol.Identity("Example Enemy")]=true;G.ObserveUnit("target")
    check(#c.s.messages==1,"Hidden enemies cannot appear in sighting chat")
    c.B.Chat.beacons.old=c.s.time+100;c.B.Chat.answered.old=c.s.time+100
    c.env.C_Club.GetGuildClubId=function() return 99 end;c.B.GuildChanged()
    check(not next(c.B.Chat.beacons) and not next(c.B.Chat.answered),"Changing guild clears chat session tracking")
    clear(c);c.B.Client.Zone=function() return "Unsafe|Ttexture|t\nZone" end
    add(c,"Sample Scout",.9,0,"|Hlink|h\nHelp")
    local body=(c.s.lastMessage or ""):gsub("^|cffffc55cLight the Beacons:|r ","")
    check(not body:find("[|%c]") and has(c,"Help"),"Untrusted place and note text cannot inject markup or multiple lines")
end
