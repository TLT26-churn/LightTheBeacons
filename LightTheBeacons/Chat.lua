local _,B=...
local P,C=B.Protocol,B.Client
local N={};B.Chat=N

function N.Reset() N.beacons={};N.answered={} end
function N.Initialize()
    for key,value in pairs({chatBeacons=true,chatGrudges=true,chatJoins=false,chatSightings=false}) do
        if type(B.db[key])~="boolean" then B.db[key]=value end
    end
    N.Reset()
end
local function plain(value,limit) return (P.Message(value,false,limit or 100)) end
local function who(name) return P.Identity(name)==B.me and "You" or plain(name) end
local function token(b) return b.owner..":"..b.id end
local function prune()
    for _,records in ipairs({N.beacons,N.answered}) do
        for key,expires in pairs(records) do if expires<=C.Now() then records[key]=nil end end
    end
end
local function beaconAllowed(owner)
    return B.db.chatBeacons and not B.db.muteBeacons and C.BeaconsAllowed() and B.BeaconMode(owner)=="normal"
end
local function grudgeAllowed(enemy)
    local G=B.Grudges;local key=P.Identity(enemy)
    return B.db.chatGrudges and not B.db.muteBeacons and G.Active() and key and not G.options.hidden[key]
end
function N.Beacon(b,joined)
    prune()
    -- Queries can return older active calls. They belong in the card, not a
    -- burst of new-chat announcements on login or reload.
    if not beaconAllowed(b.owner) or C.Now()-b.sent>15 or joined and not B.db.chatJoins then return end
    local message=who(b.name)..(joined and " joined a nearby beacon" or " lit a beacon")..
        " in "..plain(C.Zone(b.map)).." ("..math.floor(b.px*100+.5)..", "..math.floor(b.py*100+.5)..")."
    local note=plain(b.message,48);if note~="" then message=message..' "'..note..'"' end
    B.Print(message);N.beacons[token(b)]=b.expires
end
function N.Cancel(b)
    prune();local heard=N.beacons[token(b)];N.beacons[token(b)]=nil
    if not heard or not beaconAllowed(b.owner) then return end
    B.Print(who(b.name)..(b.owner==B.me and " extinguished your beacon." or " extinguished their beacon."))
end
function N.Response(b,sender,count)
    if not beaconAllowed(b.owner) or B.BeaconMode(P.Identity(sender))~="normal" then return end
    if b.owner==B.me then
        B.Print(plain(sender).." answered your beacon ("..count..(count==1 and " ally" or " allies").." on the way).")
    elseif P.Identity(sender)==B.me then
        prune()
        local group=B.GroupFor(b.owner);local callers=group and group.callers or {b};local already=false
        for _,caller in ipairs(callers) do if N.answered[token(caller)] then already=true end end
        for _,caller in ipairs(callers) do N.answered[token(caller)]=caller.expires end
        if not already then
            B.Print(#callers>1 and ("You are on your way to a shared beacon ("..#callers.." callers).") or
                ("You are on your way to "..plain(b.name).."'s beacon."))
        end
    end
end
function N.Grudge(kind,e,enemy)
    if not grudgeAllowed(enemy) or C.Now()-e.at>60 then return end
    local action=kind=="incurred" and " recorded a grudge against " or kind=="withdrawn" and " withdrew a grudge against " or
        e.evidence=="kill" and " avenged a grudge against " or " marked a grudge avenged against "
    local message=who(e.author)..action..plain(enemy).."."
    if P.Identity(e.author)==B.me then message=message.." Queued for guild sharing." end
    B.Print(message)
end
function N.GrudgeBatch(entries)
    local names={}
    for _,e in ipairs(entries) do if grudgeAllowed(e.enemy) then names[#names+1]=plain(e.enemy) end end
    if #names==0 then return end
    local shown={};for i=1,math.min(3,#names) do shown[i]=names[i] end
    B.Print("You recorded "..#names..(#names==1 and " grudge" or " grudges")..": "..table.concat(shown,", ")..
        (#names>3 and (" and "..(#names-3).." more") or "")..". Queued for guild sharing.")
end
function N.Sighted(name,where,count)
    if not B.db.chatSightings or B.db.muteBeacons then return end
    B.Print("Known enemy sighted: "..plain(name).." in "..plain(where).." ("..count..(count==1 and " open grudge" or " open grudges")..").")
end
