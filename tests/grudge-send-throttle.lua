local client,check=...
local a=client("Sample","Scribe");local G=a.B.Grudges
G.nextQuery=math.huge;G.queue={};a.s.sendResult=3
G.Queue("1|O|123.456|12345678|87654321|1")
G.Tick()
check(#G.queue==1 and G.status:find("rate%-limiting") and G.status:find("1 pending"),"Throttle reports the actual cause and retains the queued message")
local function attempts()
    local n=0;for _,p in ipairs(a.s.sent) do if p[1]==G.prefix then n=n+1 end end;return n
end
local tries=attempts()
for _=1,9 do a.advance(.5);G.Tick() end
check(attempts()==tries,"Throttled queue gives the game five seconds to recover")
a.advance(.5);G.Tick()
check(attempts()==tries+1 and G.retryDelay==10,"Repeated throttle increases retry delay instead of busy retrying")
a.s.sendResult=0;a.advance(10);G.Tick()
check(#G.queue==0 and not G.sendError and not G.status:find("rate%-limiting") and not G.status:find("Waiting for the game"),"Successful control packet clears stale failure status")
local ok,why,code
a.s.sendResult=8;ok,why,code=a.B.Client.Send("1|Q",G.prefix)
check(not ok and code==8 and why:find("rate%-limiting"),"Channel throttling is distinguished from lockdown")
a.s.sendResult=11;ok,why,code=a.B.Client.Send("1|Q",G.prefix)
check(not ok and code==11 and why:find("restricting"),"Actual lockdown result is reported without claiming delivery")
a.s.sendResult=2;ok,why,code=a.B.Client.Send("1|Q",G.prefix)
check(not ok and code==2 and why:find("code 2",1,true),"Other API failures retain a useful diagnostic code")
a.env.C_ChatInfo.SendAddonMessage=function() error("simulated API error") end
ok,why=a.B.Client.Send("1|Q",G.prefix)
check(not ok and why and not why:find("simulated",1,true),"API exceptions remain failures without exposing raw error text")

local b=client("Sample","Scout");local D=b.B.Grudges
D.queue={};D.nextQuery=math.huge;b.s.sendResult=3
D.Sync();local request=D.request;D.Tick()
for _=1,40 do b.advance(.5);D.Tick() end
check(D.request==request and not request.deadline,"Inventory request cannot time out while still waiting to send")
b.s.sendResult=0;b.advance(60);D.Tick()
b.advance(1.5);D.Tick()
check(D.request==request and request.deadline==b.s.now+8,"Offer timeout starts when WoW accepts the inventory request")

-- A recovered ledger has no live outbox: it must reach a guildmate through
-- normal paginated history, including when an initial send is throttled.
local donor=client("Archive","Keeper");local peer=client("Guild","Reader")
donor.B.members[peer.B.me]=true;peer.B.members[donor.B.me]=true
for i=1,36 do
    assert(donor.B.Grudges.Inscribe("Sample Enemy "..i,"Recorded wrong "..i..". "..string.rep("é",150)))
    donor.advance(3)
end
donor.B.Grudges.store.outbox={};donor.B.Grudges.queue={};donor.B.Grudges.queued={}
local inherited=donor.B.Grudges.ids[1]
-- Exercise a delayed live outbox separately from the restored history.
donor.advance(3);local live=assert(donor.B.Grudges.Inscribe("Recent Enemy","Newly recorded during throttling."))
local states={}
for _,c in ipairs({donor,peer}) do
    c.s.now=donor.s.now;c.s.time=donor.s.time;c.s.sent={}
    c.B.Grudges.nextQuery=c.s.now
    local state={attempts=0,throttles=0,successes=0,blockedUntil=c.s.now+20,attemptTimes={}}
    states[c]=state
    c.env.C_ChatInfo.SendAddonMessage=function(prefix,msg,channel)
        if prefix~=c.B.Grudges.prefix then return 0 end
        state.attempts=state.attempts+1;state.attemptTimes[#state.attemptTimes+1]=c.s.now
        -- An initially empty bucket, then a strict one-message/second limit.
        if c.s.now<state.blockedUntil or state.lastSuccess and c.s.now-state.lastSuccess<1 then
            state.throttles=state.throttles+1;return 3
        end
        state.lastSuccess=c.s.now;state.successes=state.successes+1
        c.s.sent[#c.s.sent+1]={prefix,msg,channel};return 0
    end
end
local function pump(seconds)
    for _=1,seconds*2 do
        for _,c in ipairs({donor,peer}) do c.advance(.5);c.B.Grudges.Tick() end
        for _,pair in ipairs({{donor,peer},{peer,donor}}) do
            local from,to=pair[1],pair[2]
            for _,p in ipairs(from.s.sent) do to.B.Grudges.Receive(p[2],from.B.name,p[3]) end
            from.s.sent={}
        end
    end
end
pump(15)
check(donor.B.Grudges.store.outbox[live.id] and donor.B.Grudges.store.events[inherited],"Throttling never discards new or recovered saved records")
pump(600)
check(peer.B.Grudges.entries[inherited] and peer.B.Grudges.entries[live.id] and #peer.B.Grudges.ids==37,"Recovered history and new records converge through rate-limited guild transport")
check(not donor.B.Grudges.store.outbox[live.id],"Outbox is cleared only after all live fragments are accepted")
check(donor.B.Grudges.digest==peer.B.Grudges.digest,"Throttled multi-page history converges without duplicate records")
for _,c in ipairs({donor,peer}) do
    check(states[c].throttles==3,"After initial backoff, conservative pacing stays below one packet per second")
    check(not c.B.Grudges.sendError,"Recovered transport clears its retry error")
end
