local _,B=...
local C,P,R=B.Client,B.Protocol,B.Routing

-- Group only the display. Protocol records retain their original owners/IDs,
-- so old clients, cancellation, expiration and individual filters still work.
function B.Groups(mapOnly)
    local list={}
    for _,b in ipairs(B.List()) do
        if b.expires>C.Now() and (not mapOnly or B.MapVisible(b.owner)) then list[#list+1]=b end
    end
    table.sort(list,function(a,b) if a.sent==b.sent then return a.owner<b.owner end;return a.sent<b.sent end)
    local groups,points,eligible={},{},{}
    for _,b in ipairs(list) do
        points[b]=B.Destination(b)
        local info=C_Map and C.Call(C_Map.GetMapInfo,b.map)
        local types=Enum and Enum.UIMapType
        eligible[b]=not (types and type(info)=="table" and P.Plain(info) and
            (info.mapType==types.Dungeon or info.mapType==types.Micro))
    end
    for _,b in ipairs(list) do
        local group
        if B.db.combineBeacons and eligible[b] and points[b] then
            for _,g in ipairs(groups) do
                local fits=true
                -- All members must be nearby: no chain linking separate fights.
                for _,member in ipairs(g.callers) do
                    if not eligible[member] or R.Distance(points[b],points[member])>B.db.mergeDistance then fits=false;break end
                end
                if fits then group=g;break end
            end
        end
        if not group then
            group={leader=b,callers={},responders={},owners={}};groups[#groups+1]=group
        end
        group.callers[#group.callers+1]=b;group.owners[b.owner]=true
        for key,name in pairs(b.responders or {}) do group.responders[key]=name end
    end
    for _,g in ipairs(groups) do
        for key in pairs(g.owners) do g.responders[key]=nil end
        g.name=#g.callers>1 and (#g.callers.." guildmates call for aid") or g.leader.name
    end
    table.sort(groups,function(a,b)
        if a.leader.sent==b.leader.sent then return a.leader.owner<b.leader.owner end
        return a.leader.sent>b.leader.sent
    end)
    return groups
end
function B.GroupFor(owner,mapOnly)
    for _,g in ipairs(B.Groups(mapOnly)) do if g.owners[owner] then return g end end
end
function B.GroupText(g)
    local names,notes={},{}
    for _,b in ipairs(g.callers) do
        names[#names+1]=b.name
        if b.message then notes[#notes+1]=b.name..": "..b.message end
    end
    return table.concat(names,", "),table.concat(notes,"\n")
end
function B.GroupSelection(g)
    return g.owners[B.me] and B.session.beacons[B.me] or g.leader
end
function B.QueueGroupAnswers(g)
    B.answerQueue={}
    for _,b in ipairs(g.callers) do
        if b.owner~=B.me and not (b.responders and b.responders[B.me]) then
            B.answerQueue[#B.answerQueue+1]={owner=b.owner,id=b.id}
        end
    end
    return B.TickAnswers()
end
function B.TickAnswers()
    if not B.answerQueue or #B.answerQueue==0 then return end
    if not C.BeaconsAllowed() or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then B.answerQueue=nil;return end
    if B.lastAnswerSend and GetTime()-B.lastAnswerSend<2 then return end
    local entry=table.remove(B.answerQueue,1)
    local b=B.session.beacons[entry.owner]
    if not b or b.id~=entry.id or b.expires<=C.Now() or B.BeaconMode(b.owner)=="hidden" then return end
    -- Space replies to stay below old clients' 12 messages / 10 seconds limit.
    B.lastAnswerSend=GetTime()
    local msg="1|R|"..b.id.."|"..b.owner
    local ok,why=C.Send(msg)
    if ok then B.Receive(msg,B.name,"GUILD") else B.answerQueue=nil;B.Print(why);return false end
    return true
end
