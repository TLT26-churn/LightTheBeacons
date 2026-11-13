local _,B=...
local C,P=B.Client,B.Protocol
local A={prefix="LTBGP1",maxRanks=20};B.GrudgePermissions=A
local function rankOK(n) return P.Number(n,1,A.maxRanks) and n%1==0 end
local function maskOK(s) return type(s)=="string" and #s==A.maxRanks and not s:find("[^01]") and s:sub(1,1)=="1" end
local defaults="11"..string.rep("0",A.maxRanks-2)
local function notify()
    if B.Settings and B.Settings.RefreshPermissions then B.Settings.RefreshPermissions() end
    if B.GrudgeUI then B.GrudgeUI.Refresh() end
end
function A.ReadRoster()
    local members,ranks={},{}
    local function add(name,order,title)
        local key=P.Identity(name)
        if key and rankOK(order) then
            members[key]=order
            if P.Text(title,100) then ranks[order]=title end
        end
    end
    local club=C_Club and C.Call(C_Club.GetGuildClubId)
    if not P.Plain(club) then club=nil end
    local ids=club and C_Club.GetClubMembers and C.Call(C_Club.GetClubMembers,club)
    if type(ids)=="table" then for _,id in ipairs(ids) do
        local m=C.Call(C_Club.GetMemberInfo,club,id)
        if type(m)=="table" and P.Plain(m) then add(m.name,m.guildRankOrder,m.guildRank) end
    end end
    local count=C.Call(GetNumGuildMembers)
    if P.Number(count,0,10000) then for i=1,count do
        local name,title,index=C.Call(GetGuildRosterInfo,i)
        if P.Number(index,0,A.maxRanks-1) then add(name,index+1,title) end
    end end
    local _,title,index=C.Call(GetGuildInfo,"player")
    if P.Number(index,0,A.maxRanks-1) then add(B.name,index+1,title) end
    local guid=C.Call(UnitGUID,"player")
    if P.Text(guid,100) and C_GuildInfo and C_GuildInfo.GetGuildRankOrder then
        add(B.name,C.Call(C_GuildInfo.GetGuildRankOrder,guid),title)
    end
    local n=C.Call(GuildControlGetNumRanks)
    if rankOK(n) then for i=1,n do
        local name=C.Call(GuildControlGetRankName,i)
        if P.Text(name,100) then ranks[i]=name end
    end end
    local leader
    for key,order in pairs(members) do
        ranks[order]=ranks[order] or (order==1 and "Guild Master" or order==2 and "Officer" or "Rank "..order)
        if order==1 then leader=key end
    end
    A.members,A.ranks,A.leader=members,ranks,leader
end
function A.IsMaster(key) return A.members and A.members[key or B.me]==1 end
function A.PolicyValid(p)
    return type(p)=="table" and P.Plain(p) and P.Text(p.by,150) and P.Number(p.at,0,C.Now()+60)
        and p.at%1==0 and P.Number(p.serial,1,1000000000) and p.serial%1==0 and maskOK(p.edit) and maskOK(p.delete)
end
function A.GuildChanged()
    if not B.db or not B.guild then return end
    local changed=not A.store or A.scope~=B.guild
    if changed then
        local saved=B.db.grudgePermissions
        if type(saved)~="table" or not P.Plain(saved) or saved.guild~=B.guild then saved={guild=B.guild} end
        saved.accepted=type(saved.accepted)=="table" and P.Plain(saved.accepted) and saved.accepted or {}
        saved.authored=type(saved.authored)=="table" and P.Plain(saved.authored) and saved.authored or {}
        A.migrateWithdrawals=saved.schema~=1;saved.schema=1
        if not A.PolicyValid(saved.policy) then saved.policy=nil end
        A.store=saved;A.scope=B.guild;B.db.grudgePermissions=saved
        A.nextRequest=GetTime()+2;A.nextBroadcast=GetTime()+3;A.dirty=nil;A.lastSend=nil;A.lastRequest=nil;A.peers={}
    end
    A.ReadRoster()
    if A.store.policy and A.leader and A.store.policy.by~=A.leader then A.store.policy=nil end
    if A.IsMaster() and not A.store.policy then
        A.store.policy={by=B.me,at=math.floor(C.Now()),serial=1,edit=defaults,delete=defaults};A.dirty=true
    end
    notify()
end
function A.RankAllowed(rank,action)
    if action~="edit" and action~="delete" then return false end
    if not rankOK(rank) then return false end
    if rank==1 then return true end
    local policy=A.store and A.store.policy
    local mask=policy and policy[action] or defaults
    return type(mask)=="string" and mask:sub(rank,rank)=="1"
end
function A.CanManage(key,action)
    if not A.store or B.guildPending or not IsInGuild or not IsInGuild() then return false end
    return A.RankAllowed(A.members and A.members[key],action)
end
function A.CanChange(record,action,key)
    key=key or B.me
    return record and (P.Identity(record.entry.author)==key or A.CanManage(key,action)) or false
end
function A.CanVouch(key,action)
    -- Older addon versions relay every cached claim without checking moderation.
    -- Only peers advertising this permissions protocol may vouch for history.
    return (key==B.me or A.peers and A.peers[key]) and A.CanManage(key,action) or false
end
function A.SetRank(rank,action,enabled)
    if not A.IsMaster() or not A.store or B.guildPending then return false,"Only the Guild Master can change guild permissions." end
    if not rankOK(rank) or rank==1 or not A.ranks[rank] or (action~="edit" and action~="delete") then return false,"Choose an editable guild rank." end
    local p=A.store.policy
    local nextPolicy={by=B.me,at=math.floor(C.Now()),serial=(p and p.serial or 0)+1,edit=p and p.edit or defaults,delete=p and p.delete or defaults}
    local mask=nextPolicy[action];nextPolicy[action]=mask:sub(1,rank-1)..(enabled and "1" or "0")..mask:sub(rank+1)
    A.store.policy=nextPolicy;A.dirty=true;notify();return true
end
function A.RecordAuthorization(e,sender,history)
    if not A.store or (e.kind~="U" and e.kind~="D") then return end
    local hash=B.Grudges.Hash(B.Grudges.Encode(e))
    if sender==P.Identity(e.author) then A.store.authored[e.id]=hash end
    local action=e.kind=="U" and "edit" or "delete"
    -- Live changes use the authenticated author. A historical moderator action
    -- must be vouched for by a currently authorized moderator, never an ordinary
    -- member claiming that somebody else held a rank. Owner changes need direct
    -- author delivery or the same authorized moderator verification.
    local allowed=history and A.CanVouch(sender,action) or not history and A.CanManage(P.Identity(e.author),action)
    if allowed then A.store.accepted[e.id]=hash end
end
function A.Authorized(e,record)
    if not A.store then return false end
    local hash=B.Grudges.Hash(B.Grudges.Encode(e))
    return P.Identity(e.author)==P.Identity(record.entry.author) and A.store.authored[e.id]==hash
        or A.store.accepted[e.id]==hash
end
function A.Receive(msg,sender,channel)
    if not A.store or not B.Grudges.Active() or B.guildPending or not P.Plain(channel) or channel~="GUILD"
        or not P.Plain(msg) or type(msg)~="string" or #msg>250 or msg:find("%c") then return end
    local key=P.Identity(sender);if not key or key==B.me or not B.members[key] then return end
    local scope=msg:match("^1|Q|([^|]+)$")
    if scope==A.scope then
        A.peers[key]=true
        if A.IsMaster() and (not A.lastRequest or GetTime()-A.lastRequest>=15) then A.dirty=true;A.lastRequest=GetTime() end
        return
    end
    local guild,at,serial,edit,delete=msg:match("^1|P|([^|]+)|(%d+)|(%d+)|([01]+)|([01]+)$")
    if guild~=A.scope or not A.IsMaster(key) then return end
    local p={by=key,at=tonumber(at),serial=tonumber(serial),edit=edit,delete=delete}
    if not A.PolicyValid(p) then return end
    A.peers[key]=true
    local old=A.store.policy
    if old and old.by==key and (p.at<old.at or p.at==old.at and p.serial<=old.serial) then return end
    A.store.policy=p;A.dirty=nil;notify()
end
function A.Tick()
    if not A.store or not B.Grudges.Active() or (A.lastSend and GetTime()-A.lastSend<2) then return end
    local now=GetTime()
    if A.IsMaster() then
        if not A.dirty and now<(A.nextBroadcast or 0) then return end
        local p=A.store.policy;if not p then return end
        A.lastSend=now
        if C.Send(table.concat({"1","P",A.scope,p.at,p.serial,p.edit,p.delete},"|"),A.prefix) then
            A.dirty=nil;A.nextBroadcast=now+180;notify()
        end
    elseif now>=(A.nextRequest or 0) then
        A.lastSend=now
        if C.Send("1|Q|"..A.scope,A.prefix) then A.nextRequest=now+180 end
    end
end
