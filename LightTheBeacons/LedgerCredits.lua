local _,B=...
local G,P,C=B.Grudges,B.Protocol,B.Client
local L={};B.LedgerCredits=L
local function plain(t) return P.Plain(t) and type(t)=="table" end
local function integer(n,lo,hi) return P.Number(n,lo,hi) and n%1==0 end
local function idOK(s) return P.Text(s,68) and s:match("^[%w%.%-]+$")~=nil end
local function nameOK(s) return P.Text(s,100) and s==G.Clean(s,70,100) and P.Identity(s) end
local function guidOK(s) return s=="" or P.Text(s,80) and s:match("^Player%-%x+%-%x+$")~=nil end
local function before(a,b)
    if a.at~=b.at then return a.at<b.at end
    if a.enemy~=b.enemy then return a.enemy<b.enemy end
    return G.Encode(a)<G.Encode(b)
end

-- R: resolution receipt; X: authorized withdrawal receipt. These use the
-- existing paginated guild transport, with distinct IDs from ordinary events.
-- Only attribution, source IDs, times and GUIDs survive; no enemy names,
-- grievance text, locations or edited text are archived.
function L.Parse(f,now)
    local kind=f[2]
    if kind~="R" and kind~="X" then return end
    local e={kind=kind,id=f[3],author=f[4],at=tonumber(f[5]),target=f[6],enemy=f[7],guid=f[8],where=f[9],note=f[10],evidence=f[11],guild=f[12]}
    local recorded,victim=e.note:match("^(%d+):(.*)$");recorded=tonumber(recorded)
    if not idOK(e.target) or e.id~=(kind=="R" and "r." or "x.")..e.target
        or not nameOK(e.author) or not nameOK(e.where) or not idOK(e.enemy)
        or e.enemy:sub(1,9)~=G.Hash(P.Identity(e.author)).."."
        or e.target:sub(1,9)~=G.Hash(P.Identity(e.where)).."."
        or not integer(e.at,0,now+60) or not integer(recorded,0,e.at) or not guidOK(victim) then return end
    if kind=="R" then
        if not guidOK(e.guid) or (e.evidence~="kill" and e.evidence~="manual")
            or e.evidence=="kill" and e.guid=="" or victim~="" and e.guid~="" and victim~=e.guid then return end
    elseif e.guid~="" or e.evidence~="manual" then return end
    return e
end

local function remember(e)
    local store=G.store;local old=store.lifetime[e.id]
    if old and not before(e,old) then return false end
    store.lifetime[e.id]=e
    if e.kind=="X" then store.lifetimeAccepted[e.id]=G.Hash(G.Encode(e)) end
    return true
end

function L.Initialize(store)
    local saved=plain(store.lifetime) and store.lifetime or {}
    local accepted=plain(store.lifetimeAccepted) and store.lifetimeAccepted or {}
    store.lifetime={};store.lifetimeAccepted={}
    for id,e in pairs(saved) do
        if plain(e) then
            local ok,raw=pcall(G.Encode,e);local parsed=ok and G.Parse(raw,C.Now())
            if parsed and (parsed.kind=="R" or parsed.kind=="X") and parsed.id==id
                and (parsed.kind=="R" or accepted[id]==G.Hash(raw)) then remember(parsed) end
        end
    end
end

local function receipt(kind,event,entry)
    return {kind=kind,id=(kind=="R" and "r." or "x.")..entry.id,author=event.author,at=event.at,
        target=entry.id,enemy=event.id,guid=event.guid,where=entry.author,
        note=tostring(entry.at)..":"..entry.guid,evidence=event.evidence,guild=G.scope}
end

function L.Capture(entries,log)
    if not G.store then return end
    for _,r in pairs(entries) do
        -- Manual seals also persist as zero-point receipts. An earlier manual
        -- resolution must not be upgraded by a later replayed kill claim.
        if r.seal then remember(receipt("R",r.seal,r.entry)) end
    end
    for _,e in ipairs(log) do
        local r=entries[e.target]
        if e.kind=="D" and r and e.at>=r.entry.at and B.GrudgePermissions.Authorized(e,r) then
            remember(receipt("X",e,r.entry))
        end
    end
end

local function canWithdraw(e,key,history)
    local author=P.Identity(e.author)
    if key==author and (author==P.Identity(e.where) or B.GrudgePermissions.CanManage(key,"delete")) then return true end
    return history and B.GrudgePermissions.CanVouch(key,"delete") or false
end
function L.CanRelay(e)
    return e.kind~="X" or canWithdraw(e,B.me,true)
end
function L.Merge(e,sender,history)
    -- Receipts are cached history, never a second live scoring announcement.
    if not history or e.guild~=G.scope then return false end
    local r=G.entries[e.target]
    if r and (P.Identity(r.entry.author)~=P.Identity(e.where)
        or e.note~=tostring(r.entry.at)..":"..r.entry.guid) then return false end
    if e.kind=="X" and not canWithdraw(e,sender,true) then return false end
    if not remember(e) then return false end
    G.Rebuild();if B.GrudgeUI then B.GrudgeUI.Refresh() end
    return true
end

function L.Leaderboard()
    local store=G.store;if not store then return {} end
    local receipts={}
    for _,e in pairs(store.lifetime) do
        if e.kind=="R" and not store.lifetime["x."..e.target] then receipts[#receipts+1]=e end
    end
    table.sort(receipts,before)
    local byAuthor,out,kills={},{},{}
    for _,e in ipairs(receipts) do
        local duplicate=false
        if e.evidence=="kill" then
            for _,at in ipairs(kills[e.guid] or {}) do if math.abs(e.at-at)<=8 then duplicate=true;break end end
            if not duplicate then
                kills[e.guid]=kills[e.guid] or {};table.insert(kills[e.guid],e.at)
                local key=P.Identity(e.author);local member=byAuthor[key]
                if not member then member={key=key,count=0,records={}};byAuthor[key]=member;out[#out+1]=member end
                member.count=member.count+1;member.name=e.author
                local r=G.entries[e.target]
                if r and not G.deleted[e.target] and r.seal and r.seal.id==e.enemy then
                    member.records[#member.records+1]=r
                end
            end
        end
    end
    for _,member in ipairs(out) do
        table.sort(member.records,function(a,b)
            if a.seal.at~=b.seal.at then return a.seal.at>b.seal.at end
            return a.seal.id<b.seal.id
        end)
    end
    table.sort(out,function(a,b) if a.count~=b.count then return a.count>b.count end;return a.key<b.key end)
    for i,member in ipairs(out) do member.rank=i>1 and member.count==out[i-1].count and out[i-1].rank or i end
    return out
end
