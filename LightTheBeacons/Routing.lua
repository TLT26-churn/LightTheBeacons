local _, B = ...
local R = {}; B.Routing = R
local huge, sqrt = math.huge, math.sqrt
function R.Distance(a,b)
    if not a or not b or a.c ~= b.c then return huge end
    return sqrt((a.x-b.x)^2+(a.y-b.y)^2)
end
-- Separate islands; never offer walking across the ocean. Remaining ground
-- legs are distance estimates, not terrain/navigation-mesh paths.
function R.Land(p)
    if p.land then return p.land end
    if p.c == 1 then
        if p.x > 8000 and p.y > -1200 then return "Teldrassil" end
        if p.x > -5300 and p.x < -3500 and p.y > 2800 then return "Feathermoon" end
    end
    return tostring(p.c)
end
function R.Ground(a,b,speed)
    if a.c ~= b.c or R.Land(a) ~= R.Land(b) then return huge end
    return R.Distance(a,b)*1.4/speed
end
local function allowed(node,faction)
    return node.f and node.f:find(faction,1,true) ~= nil
end
local function copy(t)
    local o={};for k,v in pairs(t) do o[k]=v end;return o
end
-- Dijkstra compares directed known-flight connections, ground approaches and
-- faction-accessible public transports. Undiscovered intermediates are excluded.
function R.Plan(start,goal,known,faction,speed,data,learned)
    data=data or B.TravelData; speed=tonumber(speed) or 7
    if not start or not goal or speed<1 or speed>20 then return end
    local nodes, keys, edges = {start=copy(start),goal=copy(goal)}, {"start","goal"}, {}
    nodes.start.n="Your position";nodes.goal.n=goal.n or "Beacon"
    local function add(id,n)
        if not nodes[id] then nodes[id]=copy(n);keys[#keys+1]=id end
    end
    local function edge(a,b,seconds,kind,extra)
        if not nodes[a] or not nodes[b] or not seconds or seconds<=0 then return end
        edges[a]=edges[a] or {};edges[a][b]={seconds=seconds,kind=kind,extra=extra}
    end
    for id,n in pairs(data.nodes) do
        if known[id] == true and allowed(n,faction) then add(id,n) end
    end
    for a,row in pairs(data.flights) do
        for b,s in pairs(row) do
            local timing=learned and learned[a..":"..b]
            if type(timing)=="number" and timing>5 and timing<3600 then s=timing end
            edge(a,b,s+8,"flight")
        end
    end
    for _,ship in ipairs(data.ships or {}) do
        for i,stop in ipairs(ship.stops) do
            if allowed(stop,faction) then add("port"..ship.id..":"..i,stop) end
        end
        -- Stops are ordered along the ship's loop, never assume reverse travel.
        for i in ipairs(ship.stops) do
            local j=i%#ship.stops+1
            edge("port"..ship.id..":"..i,"port"..ship.id..":"..j,
                (ship.s[i] or 120)+(ship.w or 180),ship.k,{wait=ship.w or 180})
        end
    end
    -- Deterministic ties make the displayed route stable as position updates.
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local dist,prev,closed={start=0},{},{}
    for _=1,#keys do
        local u,best=nil,huge
        for _,id in ipairs(keys) do
            if not closed[id] and (dist[id] or huge)<best then u,best=id,dist[id] end
        end
        if not u or u=="goal" then break end
        closed[u]=true
        for _,v in ipairs(keys) do if v~=u and not closed[v] and v~="start" then
            local seconds=R.Ground(nodes[u],nodes[v],speed)
            local e={seconds=seconds,kind="ground"}
            local direct=edges[u] and edges[u][v]
            if direct and direct.seconds<seconds then e=direct;seconds=direct.seconds end
            local total=best+seconds
            if total<(dist[v] or huge) then dist[v]=total;prev[v]={from=u,edge=e} end
        end end
    end
    if not dist.goal then return {unavailable=true,steps={},reason="No supported connection. Open the beacon on your map."} end
    local rev={};local key="goal"
    while key~="start" do
        local p=prev[key];if not p then return end
        table.insert(rev,1,{kind=p.edge.kind,seconds=p.edge.seconds,from=nodes[p.from],to=nodes[key],
            fromID=p.from,toID=key,extra=p.edge.extra})
        key=p.from
    end
    -- Consecutive flights are one instruction; keep intermediates for display
    -- and advance tracking against the full final destination.
    local steps={}
    for _,step in ipairs(rev) do
        local last=steps[#steps]
        if last and last.kind=="flight" and step.kind=="flight" then
            last.via=last.via or {};last.via[#last.via+1]=last.to.n
            last.to,last.toID=step.to,step.toID;last.seconds=last.seconds+step.seconds
        elseif step.seconds>3 or step.toID=="goal" then steps[#steps+1]=step end
    end
    return {steps=steps,seconds=dist.goal,estimated=true,speed=speed}
end
function R.Time(seconds)
    if not seconds or seconds==huge then return "Unknown" end
    seconds=math.max(0,math.floor(seconds+0.5))
    if seconds<60 then return seconds.." sec" end
    return string.format("%d min%s",math.floor(seconds/60),seconds%60>=30 and " 30 sec" or "")
end
