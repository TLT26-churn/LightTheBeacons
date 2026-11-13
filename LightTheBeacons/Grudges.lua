local _,B=...
local P,C=B.Protocol,B.Client
local G={prefix="LTBGR1",retention=90*86400,limit=1200,pageSize=12};B.Grudges=G
local deathBatch={}
G.defaultPhrases={incurred="Grudge recorded.",sighted="Known enemy sighted.",avenged="Grudge avenged."}
G.phrases={
    incurred={"A debt is entered. Let stone remember.","Ink the wrong. Name the debtor.","Another wrong. Another reckoning.","The ledger grows.","Set this grievance down in iron and ink."},
    sighted={"A debtor stands before us.","That name is known.","The debt remains unpaid.","An oathbreaker approaches.","The book remembers this one."},
    avenged={"The debt is paid.","Strike the line.","One wrong answered.","Cross it out—but never forget it."},
}
local function plainTable(t) return P.Plain(t) and type(t)=="table" end
local function integer(n,lo,hi) return P.Number(n,lo,hi) and n%1==0 end
local function idOK(s) return P.Text(s,68) and s:match("^[%w%.%-]+$")~=nil end
local function nonceOK(s) return P.Text(s,28) and s:match("^[%d%.]+$")~=nil end
function G.Hash(s)
    local h=5381;for i=1,#s do h=(h*33+s:byte(i))%2147483647 end
    return string.format("%08x",h)
end
-- All fields are plain single-line UTF-8. Pipes and WoW formatting never survive.
function G.Clean(s,chars,bytes)
    local value=P.Message(s,false,chars or 160)
    if #value>(bytes or 640) then
        local stop=bytes or 640
        while stop>0 and value:byte(stop+1)>=128 and value:byte(stop+1)<=191 do stop=stop-1 end
        value=value:sub(1,stop)
    end
    return value
end
local function nameOK(s) return P.Text(s,100) and s==G.Clean(s,70,100) and P.Identity(s) end
local function optional(s,max) return s=="" or P.Text(s,max) end
local function guidOK(s) return s=="" or P.Text(s,80) and s:match("^Player%-%x+%-%x+$")~=nil end
local function fields(s)
    local f={};for part in (s.."|"):gmatch("(.-)|") do f[#f+1]=part end;return f
end
function G.Encode(e)
    return table.concat({"1",e.kind,e.id,e.author,tostring(e.at),e.target or "",e.enemy or "",e.guid or "",e.where or "",e.note or "",e.evidence or "manual",e.guild},"|")
end
function G.Parse(raw,now)
    if not P.Plain(raw) or type(raw)~="string" or #raw>1500 or raw:find("%c") then return end
    local f=fields(raw);if #f~=12 or f[1]~="1" or f[12]~=G.scope or not P.Text(f[12],100) then return end
    local e={kind=f[2],id=f[3],author=f[4],at=tonumber(f[5]),target=f[6],enemy=f[7],guid=f[8],where=f[9],note=f[10],evidence=f[11],guild=f[12]}
    if not nameOK(e.author) or not idOK(e.id) or not integer(e.at,now-G.retention,now+60)
        or e.id:sub(1,9)~=G.Hash(P.Identity(e.author)).."." then return end
    if not optional(e.where,100) or e.where~=G.Clean(e.where,70,100) or not guidOK(e.guid) then return end
    if e.kind=="I" then
        if e.target~="" or not nameOK(e.enemy) or not P.Text(e.note,640) or e.note~=G.Clean(e.note)
            or (e.evidence~="manual" and e.evidence~="pvp") then return end
    elseif e.kind=="V" then
        if not idOK(e.target) or e.enemy~="" or e.note~="" or (e.evidence~="manual" and e.evidence~="kill")
            or e.evidence=="kill" and e.guid=="" then return end
    elseif e.kind=="D" then
        if not idOK(e.target) or e.enemy~="" or e.guid~="" or e.note~="" or e.where~="" or e.evidence~="manual" then return end
    else return end
    return e
end
function G.Active() return G.store and G.options.enabled and P.Text(B.me) and P.Text(B.name,100) and not B.guildPending and B.guild and B.guild~="" and IsInGuild and IsInGuild() end
function G.Initialize()
    B.db.grudgeOptions=plainTable(B.db.grudgeOptions) and B.db.grudgeOptions or {}
    B.db.grudgeSightings=plainTable(B.db.grudgeSightings) and B.db.grudgeSightings or {}
    G.options=B.db.grudgeOptions
    for k,v in pairs({enabled=true,autoRecord=true,autoAvenge=true,sightingAlerts=true,notices=true}) do
        if type(G.options[k])~="boolean" then G.options[k]=v end
    end
    -- Older builds silently saved confirmed deaths. Introduce the requested
    -- confirmation flow without re-enabling a previously disabled death option.
    if G.options.deathMode~="prompt" and G.options.deathMode~="auto" and G.options.deathMode~="off" then
        G.options.deathMode=G.options.autoRecord and "prompt" or "off"
    end
    G.options.hidden=plainTable(G.options.hidden) and G.options.hidden or {}
    G.options.phrases=plainTable(G.options.phrases) and G.options.phrases or {}
    G.GuildChanged()
end
function G.GuildChanged()
    if not B.db or not G.options or not B.guild then return end
    local old=B.db.grudges
    if not plainTable(old) or old.guild~=B.guild or old.version~=1 then old={version=1,guild=B.guild,events={},outbox={}} end
    if G.store==old and G.scope==B.guild then return end
    G.scope=B.guild;G.store=old;B.db.grudges=old
    if not integer(old.sequence,0,1000000000) then old.sequence=0 end
    old.events=plainTable(old.events) and old.events or {};old.outbox=plainTable(old.outbox) and old.outbox or {}
    local clean,n={},0
    -- Reloaded saves are validated just like received records.
    for id,e in pairs(old.events) do
        if plainTable(e) and P.Text(e.kind,1) and P.Text(e.author,100) and integer(e.at,0,C.Now()+60) and idOK(e.id) then
            local ok,raw=pcall(G.Encode,e);local parsed=ok and G.Parse(raw,C.Now())
            if parsed and parsed.id==id and n<G.limit then clean[id]=parsed;n=n+1 end
        end
    end
    old.events=clean;for id in pairs(old.outbox) do if not clean[id] or P.Identity(clean[id].author)~=B.me then old.outbox[id]=nil end end
    local savedSightings=plainTable(B.db.grudgeSightings[B.guild]) and B.db.grudgeSightings[B.guild] or {}
    local sightings={}
    for key,seen in pairs(savedSightings) do
        if P.Text(key,100) and plainTable(seen) and P.Text(seen.where,100) and
            integer(seen.at,C.Now()-G.retention,C.Now()+60) then
            sightings[key]={where=G.Clean(seen.where,70,100),at=seen.at}
        end
    end
    B.db.grudgeSightings[B.guild]=sightings
    G.queue={};G.queued={};G.pending={};G.budgets={};G.offers={};G.served={};G.sightings=sightings;G.seenAlert={};G.killSeen={}
    G.request=nil;G.offerDue=nil;G.nextQuery=GetTime()+7;G.lastTick=nil;G.deathActive=nil;G.deathSerial=(G.deathSerial or 0)+1
    G.pendingDeath=nil
    C.ClearAttackers()
    if B.DeathUI then B.DeathUI.Reset() end
    G.Rebuild();G.status=B.guild=="" and "Join a guild to open its shared book." or "Waiting for guild sync."
    if B.GrudgeUI then B.GrudgeUI.Reset() end
end
function G.Rebuild()
    local log={};for _,e in pairs(G.store and G.store.events or {}) do log[#log+1]=e end
    table.sort(log,function(a,b) if a.at~=b.at then return a.at<b.at end;return a.id<b.id end)
    local entries,deleted={},{}
    for _,e in ipairs(log) do if e.kind=="I" then entries[e.id]={entry=e} end end
    for _,e in ipairs(log) do
        local r=entries[e.target]
        if e.kind=="D" and r and e.at>=r.entry.at and P.Identity(e.author)==P.Identity(r.entry.author) then deleted[e.target]=true end
    end
    local kills={}
    for _,e in ipairs(log) do
        local r=entries[e.target]
        if e.kind=="V" and r and not deleted[e.target] and e.at>=r.entry.at then
            local duplicate=false
            if e.evidence=="kill" then
                for _,at in ipairs(kills[e.guid] or {}) do if math.abs(e.at-at)<=8 then duplicate=true;break end end
                if not duplicate then kills[e.guid]=kills[e.guid] or {};table.insert(kills[e.guid],e.at) end
            end
            if not duplicate and not r.seal and (e.guid=="" or r.entry.guid=="" or e.guid==r.entry.guid) then r.seal=e end
        end
    end
    local people={}
    for id,r in pairs(entries) do if not deleted[id] then
        local key=P.Identity(r.entry.enemy);local person=people[key]
        if not person then person={key=key,name=r.entry.enemy,debts={},open=0};people[key]=person end
        person.debts[#person.debts+1]=r;if not r.seal then person.open=person.open+1 end
    end end
    for _,p in pairs(people) do
        table.sort(p.debts,function(a,b) if a.entry.at~=b.entry.at then return a.entry.at<b.entry.at end;return a.entry.id<b.entry.id end)
        p.firstAt=p.debts[1] and p.debts[1].entry.at
        p.latestAt=p.debts[#p.debts] and p.debts[#p.debts].entry.at
    end
    G.entries,G.people,G.log=entries,people,log;G.deleted=deleted
    local ids={};for _,e in ipairs(log) do ids[#ids+1]=e.id end;table.sort(ids)
    G.ids=ids;G.digest=G.Hash(table.concat(ids,","))
end
function G.List(query)
    local out={};query=(query or ""):lower()
    for key,p in pairs(G.people or {}) do if not G.options.hidden[key] and (query=="" or p.name:lower():find(query,1,true)) then out[#out+1]=p end end
    table.sort(out,function(a,b)
        if (a.open>0)~=(b.open>0) then return a.open>0 end
        if a.latestAt~=b.latestAt then return (a.latestAt or 0)>(b.latestAt or 0) end
        return a.name<b.name
    end)
    return out
end
function G.Phrase(kind,balanced)
    if balanced then return "All grudges avenged." end
    local lines=G.phrases[kind];local chosen=G.options.phrases[kind]
    if integer(chosen,1,#lines) then return lines[chosen] end
    return G.defaultPhrases[kind]
end
function G.Notify(kind,e)
    local r=e.kind=="I" and G.entries[e.id] or G.entries[e.target]
    local enemy=r and r.entry.enemy or e.enemy;local key=enemy and P.Identity(enemy)
    if not key or G.options.hidden[key] then return end
    B.Chat.Grudge(kind,e,enemy,r and r.entry)
    local balanced=kind=="avenged" and G.people[key] and G.people[key].open==0
    local title=G.Phrase(kind,balanced)
    if B.GrudgeUI then B.GrudgeUI.Notify(title,(enemy or "").." - "..e.author,kind) end
end
function G.Merge(e,sender,history,quiet)
    if not G.Active() or e.guild~=G.scope then return false end
    if not history and P.Identity(e.author)~=sender then return false end
    if G.store.events[e.id] then return false end
    if #G.ids>=G.limit then G.status="The book is full (1,200 records; 90-day retention).";return false end
    local previous=G.entries[e.target]
    local wasVisible=previous and not G.deleted[e.target]
    local wasOpen=e.kind=="V" and wasVisible and not previous.seal
    G.store.events[e.id]=e;G.Rebuild()
    if not history and not quiet and ((e.kind=="I" and not G.deleted[e.id]) or
        (wasOpen and G.entries[e.target].seal and G.entries[e.target].seal.id==e.id)) then
        G.Notify(e.kind=="I" and "incurred" or "avenged",e)
    end
    if e.kind=="D" and not history and not quiet and wasVisible and G.deleted[e.target] then
        B.Chat.Grudge("withdrawn",e,previous.entry.enemy,previous.entry)
    end
    if B.GrudgeUI then B.GrudgeUI.Refresh() end
    return true
end
local function splitUTF8(s,max)
    local out={};while #s>max do
        local cut=max;while cut>0 and s:byte(cut+1)>=128 and s:byte(cut+1)<=191 do cut=cut-1 end
        out[#out+1]=s:sub(1,cut);s=s:sub(cut+1)
    end;out[#out+1]=s;return out
end
function G.Packets(e,nonce,target)
    local parts=splitUTF8(G.Encode(e),128);local packets={}
    for i,part in ipairs(parts) do
        packets[i]=nonce and table.concat({"1","S",nonce,target,e.id,i,#parts,part},"|") or table.concat({"1","E",e.id,i,#parts,part},"|")
        assert(#packets[i]<=250,"Grudge packet too long")
    end
    return packets
end
function G.Queue(msg,done)
    if #G.queue>=256 then return false end
    G.queue[#G.queue+1]={msg=msg,done=done};return true
end
function G.New(kind,enemy,note,target,guid,evidence,where,batch)
    if not G.Active() then return nil,"Enable the shared book and join a guild first." end
    if #G.ids>=G.limit then return nil,"The book is full; older records expire after 90 days." end
    if batch~=deathBatch and (not evidence or evidence=="manual") and G.lastWrite and GetTime()-G.lastWrite<2 then return nil,"Wait two seconds before adding another entry." end
    G.store.sequence=(tonumber(G.store.sequence) or 0)+1
    local at=math.floor(C.Now());local id=G.Hash(B.me).."."..at.."."..B.nonce.."."..G.store.sequence
    local e={kind=kind,id=id,author=B.name,at=at,guild=G.scope,enemy=enemy or "",note=note or "",target=target or "",guid=guid or "",where=where or "",evidence=evidence or "manual"}
    local parsed=G.Parse(G.Encode(e),C.Now())
    if not parsed then return nil,"Use a full player name and a short, plain-text grievance." end
    if not G.Merge(parsed,B.me,false,batch==deathBatch) then return nil,"The entry could not be written." end
    G.store.outbox[id]=true;G.lastWrite=GetTime();G.status="Written. Waiting to share with the guild."
    return parsed
end
function G.Place()
    local p=C.Location();return p and G.Clean(C.Zone(p.map),70,100) or "Unknown location"
end
function G.Inscribe(enemy,note,guid,evidence,where,batch)
    enemy=G.Clean(enemy,70,100);note=G.Clean(note)
    if P.Identity(enemy)==B.me then return nil,"The book records your enemies, not yourself." end
    if B.members[P.Identity(enemy)] then return nil,"This name belongs to your guild." end
    return G.New("I",enemy,note,nil,guid,evidence,where and G.Clean(where,70,100) or G.Place(),batch)
end
function G.Avenge(id,guid,evidence)
    local r=G.entries[id]
    if not r or r.seal or G.deleted[id] then return nil,"That debt is already answered or withdrawn." end
    return G.New("V",nil,nil,id,guid,evidence,G.Place())
end
function G.Withdraw(id)
    local r=G.entries[id]
    if not r or G.deleted[id] or P.Identity(r.entry.author)~=B.me then return nil,"Only the scribe who entered a wrong may withdraw it." end
    return G.New("D",nil,nil,id)
end
function G.SetEnabled(value)
    G.options.enabled=value==true;G.queue={};G.queued={};G.pending={};G.request=nil;G.offerDue=nil
    G.nextQuery=GetTime()+2;G.status=value and "Waiting for guild sync." or "Sharing paused. The saved book is read-only."
    if not value then G.CancelDeathPrompt();C.ClearAttackers() end
    if B.GrudgeUI then B.GrudgeUI.Refresh() end
end
local function requestPage(peer,cursor)
    G.request.peer=peer;G.request.deadline=GetTime()+150
    G.Queue("1|W|"..G.request.nonce.."|"..G.Hash(peer).."|"..(cursor or ""))
end
function G.Sync()
    if not G.Active() or G.request then return end
    local nonce=tostring(math.floor(C.Now())).."."..B.nonce
    G.request={nonce=nonce,deadline=GetTime()+8,offers={}}
    G.Queue("1|Q|"..nonce.."|"..G.digest);G.nextQuery=GetTime()+180
    G.status="Syncing guild records."
end
function G.Receive(msg,sender,channel)
    if not G.Active() or not P.Plain(channel) or channel~="GUILD" or not P.Plain(msg) or type(msg)~="string" or #msg>250 or msg:find("%c") then return end
    local key=P.Identity(sender);if not key or key==B.me or not B.members[key] then return end
    local now=GetTime();local b=G.budgets[key]
    if not b or now-b.at>=10 then b={at=now,count=0};G.budgets[key]=b end
    b.count=b.count+1;if b.count>40 then return end
    local f=fields(msg);if f[1]~="1" then return end
    if f[2]=="Q" and #f==4 and nonceOK(f[3]) and f[4]:match("^%x%x%x%x%x%x%x%x$") then
        if f[4]~=G.digest and #G.ids>0 and (not G.offers[key] or now-G.offers[key]>30) then
            G.offers[key]=now
            G.Queue("1|O|"..f[3].."|"..G.Hash(key).."|"..G.digest.."|"..#G.ids)
        end;return
    end
    local q=G.request
    if f[2]=="O" and #f==6 and q and not q.peer and q.nonce==f[3] and f[4]==G.Hash(B.me) and integer(tonumber(f[6]),1,G.limit) then
        q.offers[key]=tonumber(f[6]);return
    end
    if f[2]=="W" and #f==5 and nonceOK(f[3]) and f[4]==G.Hash(B.me) and (f[5]=="" or idOK(f[5])) then
        if G.served[key] and now-G.served[key]<5 then return end
        if #G.queue>64 then return end
        G.served[key]=now
        local page={};for _,id in ipairs(G.ids) do if id>f[5] and #page<G.pageSize then page[#page+1]=id end end
        local last=page[#page] or f[5];local more=G.ids[#G.ids] and last<G.ids[#G.ids]
        for _,id in ipairs(page) do for _,packet in ipairs(G.Packets(G.store.events[id],f[3],G.Hash(key))) do G.Queue(packet) end end
        G.Queue("1|Z|"..f[3].."|"..G.Hash(key).."|"..last.."|"..(more and "1" or "0"));return
    end
    if f[2]=="Z" and #f==6 and q and q.peer==key and q.nonce==f[3] and f[4]==G.Hash(B.me) and (f[5]=="" or idOK(f[5])) then
        if f[6]=="1" and f[5]~=(q.cursor or "") then q.cursor=f[5];requestPage(key,f[5])
        elseif f[6]=="0" then G.request=nil;G.status="Guild pages received. Listening for further entries." end
        if B.GrudgeUI then B.GrudgeUI.Refresh() end;return
    end
    local id,part,total,chunk,history
    if f[2]=="E" then
        id,part,total,chunk=msg:match("^1|E|([^|]+)|(%d+)|(%d+)|(.*)$")
    elseif f[2]=="S" and q and q.peer==key and q.nonce==f[3] and f[4]==G.Hash(B.me) then
        id,part,total,chunk=msg:match("^1|S|[^|]+|[^|]+|([^|]+)|(%d+)|(%d+)|(.*)$");history=true
    end
    part,total=tonumber(part),tonumber(total)
    if not idOK(id) or not integer(total,1,12) or not integer(part,1,total) or not chunk or #chunk>128 then return end
    if G.store.events[id] then return end
    local token=key..":"..(history and q.nonce or "live")..":"..id
    local assembly=G.pending[token]
    if not assembly then
        local count,owned=0,0;for _,a in pairs(G.pending) do count=count+1;if a.sender==key then owned=owned+1 end end
        if count>=64 or owned>=16 then return end
        assembly={sender=key,total=total,parts={},at=now};G.pending[token]=assembly
    end
    if assembly.total~=total or assembly.parts[part] and assembly.parts[part]~=chunk then G.pending[token]=nil;return end
    assembly.parts[part]=chunk
    for i=1,total do if not assembly.parts[i] then return end end
    G.pending[token]=nil
    local e=G.Parse(table.concat(assembly.parts),C.Now())
    if e and e.id==id then G.Merge(e,key,history) end
end
function G.Tick()
    if not G.store then return end
    local now=GetTime()
    if G.lastTick and now-G.lastTick<.25 then return end;G.lastTick=now
    for token,a in pairs(G.pending) do if now-a.at>150 then G.pending[token]=nil end end
    for key,b in pairs(G.budgets) do if now-b.at>30 then G.budgets[key]=nil end end
    if not G.Active() then return end
    if not G.lastPrune or now-G.lastPrune>60 then
        G.lastPrune=now;local changed=false
        for id,e in pairs(G.store.events) do if e.at<C.Now()-G.retention then G.store.events[id]=nil;G.store.outbox[id]=nil;changed=true end end
        for key,seen in pairs(G.sightings) do
            if not G.people[key] or seen.at<C.Now()-G.retention then G.sightings[key]=nil end
        end
        if changed then G.Rebuild();if B.GrudgeUI then B.GrudgeUI.Refresh() end end
    end
    if not G.request and now>=(G.nextQuery or 0) then G.Sync() end
    local q=G.request
    if q and now>=q.deadline then
        local peer,count=nil,-1
        if not q.peer then for k,n in pairs(q.offers) do if n>count or n==count and k<(peer or k) then peer,count=k,n end end end
        if peer then requestPage(peer)
        else G.request=nil;G.status=q.peer and "A page was delayed. Sync will retry." or "Listening for guild pages." end
    end
    if #G.queue<16 then for id in pairs(G.store.outbox) do
        if not G.queued[id] and G.store.events[id] then
            G.queued[id]=true;local packets=G.Packets(G.store.events[id])
            for i,packet in ipairs(packets) do G.Queue(packet,i==#packets and id or nil) end
            break
        end
    end end
    if #G.queue>0 and (not G.lastSend or now-G.lastSend>=.5) then
        G.lastSend=now;local item=G.queue[1]
        local ok=C.Send(item.msg,G.prefix)
        if ok then
            table.remove(G.queue,1)
            if item.done then G.store.outbox[item.done]=nil;G.queued[item.done]=nil;G.status="Shared with guild addon users." end
        else G.status="Waiting for the game to allow guild messages." end
    end
end
function G.CancelDeathPrompt()
    G.pendingDeath=nil
    if B.DeathUI then B.DeathUI.RemoveGrudge() end
end
function G.InscribeDeathSelection(draft)
    if not draft or draft~=G.pendingDeath or not draft.handled or draft.scope~=G.scope or not G.Active()
        or G.options.deathMode=="off" or not C.IsOutdoor() then return 0,"This death is no longer available." end
    local chosen={}
    for _,entry in ipairs(draft.attackers or {}) do
        if draft.selected[entry.key] and not draft.saved[entry.key] then chosen[#chosen+1]=entry end
    end
    if #chosen==0 then return 0,"Select at least one attacker." end
    if #G.ids+#chosen>G.limit then return 0,"The book is full; select fewer names or wait for older records to expire." end
    for _,entry in ipairs(chosen) do
        if entry.key==B.me or B.members[entry.key] then return 0,"A selected name now belongs to your guild. Deselect it before saving." end
    end
    local count,recorded=0,{}
    for _,entry in ipairs(chosen) do
        local note=(entry.killingBlow and "Killed me in " or "Attacked me before my death in ")..draft.where.."."
        local saved,why=G.Inscribe(entry.name,note,entry.guid,entry.killingBlow and "pvp" or "manual",draft.where,deathBatch)
        if not saved then B.Chat.GrudgeBatch(recorded);return count,why end
        recorded[#recorded+1]=saved
        draft.saved[entry.key]=saved.id;draft.selected[entry.key]=false;count=count+1
    end
    B.Chat.GrudgeBatch(recorded);return count
end
function G.SetDeathMode(mode)
    if mode~="prompt" and mode~="auto" and mode~="off" then return end
    G.options.deathMode=mode;G.options.autoRecord=mode~="off"
    if mode=="off" then C.ClearAttackers() end
    G.CancelDeathPrompt()
end
function G.OnDeath()
    if G.deathActive or not G.Active() or G.options.deathMode=="off" or not C.IsOutdoor() then return end
    G.deathActive=true
    G.deathSerial=(G.deathSerial or 0)+1;local serial,scope=G.deathSerial,G.scope
    local draft={serial=serial,scope=scope,at=GetTime(),where=G.Place(),enemy="",guid="",evidence="manual",selected={},saved={}}
    G.pendingDeath=draft
    local function attempt(fallback,finished)
        local dead=C.Call(UnitIsDeadOrGhost,"player")
        if G.pendingDeath~=draft or serial~=G.deathSerial or scope~=G.scope
            or not G.Active() or G.options.deathMode=="off" or not C.IsOutdoor()
            or not P.Plain(dead) or dead~=true then return end
        local confirmed,evidence=C.ConfirmedDeath()
        local incoming=C.DeathAttackers(draft.at,confirmed and evidence or nil)
        if not C.DeathHasPvP(confirmed,incoming) then
            if finished then G.CancelDeathPrompt() end
            return
        end
        local incomingByGUID={};for _,entry in ipairs(incoming) do incomingByGUID[entry.guid]=entry end
        local list,seen,newNames={}, {},0
        -- Keep visible rows in place while the player is clicking. Late recap
        -- results may enrich a row or append an unchecked one, never reorder it.
        for _,old in ipairs(draft.attackers or {}) do
            local entry=incomingByGUID[old.guid] or old;entry.key=old.key;entry.name=old.name
            list[#list+1]=entry;seen[entry.guid]=true
        end
        for _,entry in ipairs(incoming) do
            if not seen[entry.guid] and #list<32 then
                if draft.selected[entry.key]==nil then
                    draft.selected[entry.key]=not draft.handled;newNames=newNames+1
                end
                list[#list+1]=entry;seen[entry.guid]=true
            end
        end
        draft.attackers=list;draft.collecting=not finished
        local first=draft.attackers[1]
        if first then
            draft.enemy=first.name;draft.guid=first.guid;draft.evidence=first.killingBlow and "pvp" or "manual"
            draft.note=(first.killingBlow and "Killed me in " or "Attacked me before my death in ")..draft.where.."."
            if G.options.deathMode=="auto" then
                local lethal;for _,entry in ipairs(list) do if entry.killingBlow then lethal=entry;break end end
                if lethal and not draft.saved[lethal.key] then
                    local entry=G.Inscribe(lethal.name,"Killed me in "..draft.where..".",lethal.guid,"pvp",draft.where)
                    if entry then
                        draft.saved[lethal.key]=entry.id;draft.selected[lethal.key]=false
                    end
                end
            end
        elseif not fallback then return end
        if fallback or first then
            if draft.handled and newNames>0 then B.DeathUI.message="Recap updated. New names are unchecked." end
            draft.handled=true;draft.note=draft.note or "PvP death in "..draft.where.."."
            local remaining=0;for _,entry in ipairs(draft.attackers) do if not draft.saved[entry.key] then remaining=remaining+1 end end
            if #draft.attackers>0 and remaining==0 and not B.DeathUI.draft then B.DeathUI.RemoveGrudge()
            else B.GrudgeUI.PromptDeath(draft) end
        end
    end
    if C_Timer then
        C_Timer.After(.7,function() attempt(false) end)
        C_Timer.After(1.8,function() attempt(false) end)
        C_Timer.After(3.2,function() attempt(true,false) end)
        C_Timer.After(5.5,function() attempt(true,true) end)
    else attempt(true,true) end
end
-- Some Forever recaps expose only a given name. Preserve that readable label
-- but match subsequent sightings/kills by the stored player GUID as well.
function G.PersonFor(name,guid)
    if guidOK(guid) and guid~="" then
        for _,record in ipairs(G.log or {}) do
            local person=record.kind=="I" and record.guid==guid and G.people[P.Identity(record.enemy)]
            local debt=person and G.entries[record.id]
            if debt and not debt.seal and not G.deleted[record.id] then return person,P.Identity(record.enemy) end
        end
    end
    local key=P.Identity(name);local person=key and G.people[key]
    for _,debt in ipairs(person and person.debts or {}) do
        if not debt.seal and (debt.entry.guid=="" or debt.entry.guid==guid) then return person,key end
    end
end
function G.Combat(e)
    if not G.Active() or not G.options.autoAvenge or not C.IsOutdoor() or not P.Text(e[2]) or e[2]~="PARTY_KILL" then return end
    local me=C.Call(UnitGUID,"player")
    if not P.Text(me) or not P.Text(e[4]) or e[4]~=me or not C.HostilePlayer(e[8],e[10]) or not nameOK(e[9]) then return end
    local now=GetTime();local old=G.killSeen[e[8]]
    if old and now-old<8 then return end
    G.killSeen[e[8]]=now
    local person=G.PersonFor(e[9],e[8])
    for _,r in ipairs(person and person.debts or {}) do
        if not r.seal and (r.entry.guid=="" or r.entry.guid==e[8]) then G.Avenge(r.entry.id,e[8],"kill");break end
    end
end
function G.ObserveUnit(unit)
    if not G.Active() then return end
    local player,attack=C.Call(UnitIsPlayer,unit),C.Call(UnitCanAttack,"player",unit)
    if not P.Plain(player) or not P.Plain(attack) or player~=true or attack~=true then return end
    local name=C.UnitName(unit);local guid=C.Call(UnitGUID,unit)
    if not P.Plain(guid) then guid=nil end
    local person,key=G.PersonFor(name,guid)
    if not person or person.open==0 or G.options.hidden[key] then return end
    if not P.Text(name,100) then name=person.name end
    G.sightings[key]={where=G.Place(),at=C.Now()}
    if G.options.sightingAlerts and (not G.seenAlert[key] or GetTime()-G.seenAlert[key]>60) then
        G.seenAlert[key]=GetTime()
        B.Chat.Sighted(name,G.sightings[key].where,person.open)
        if B.GrudgeUI then B.GrudgeUI.Notify(G.Phrase("sighted"),name.." - "..person.open.." debts unpaid","sighted") end
    end
    if B.GrudgeUI then B.GrudgeUI.Refresh() end
end
