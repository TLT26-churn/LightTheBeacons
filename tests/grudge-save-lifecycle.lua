local client,check=...
local function seed()
    local a=client("Sample","Scribe")
    local entry=assert(a.B.Grudges.Inscribe("Example Enemy","A witnessed wrong."))
    a.advance(3)
    local deleted=assert(a.B.Grudges.Inscribe("Withdrawn Enemy","Correct this entry."))
    a.advance(3);local withdrawal=assert(a.B.Grudges.Withdraw(deleted.id))
    return a,entry,deleted,withdrawal
end
local a,e,d,w=seed()
local events,receipts=a.B.db.grudges.events,a.B.db.grudgePermissions.authored
a.env.GetGuildInfo=function() return "Example Guild" end
for _,read in ipairs({function() return nil end,function() error("Unavailable") end,
    function() return 0 end,function() return {secret=true} end}) do
    a.env.C_Club.GetGuildClubId=read;a.B.GuildChanged()
    check(a.B.guildPending and a.B.guild=="42","Unavailable club ID never changes a guild ID into its name")
    check(a.B.db.grudges.events==events and events[e.id] and receipts[w.id],"Unavailable identity retains entries and deletion receipts")
    a.s.sent={};check(not a.B.Client.Send("1|Q"),"All addon traffic pauses while guild identity is uncertain")
    a.B.Grudges.Tick();check(#a.s.sent==0,"Pending history cannot leak to an uncertain guild")
end
a.env.C_Club.GetGuildClubId=function() return 42 end
a.advance(4);a.B.eventFrame.scripts.OnUpdate(a.B.eventFrame,1)
check(not a.B.guildPending and a.B.Grudges.entries[e.id],"Timed retry restores the same guild without another roster event")
check(a.B.Grudges.deleted[d.id],"Identity recovery preserves author withdrawals")
a.B.GrudgeUI.Toggle(true)
check(a.B.GrudgeUI.frame:IsShown(),"Book is open before membership becomes unavailable")
a.s.guild=false;a.B.GuildChanged()
check(not a.B.Grudges.store and #a.B.Grudges.List()==0,"No-guild state exposes no previous guild book")
check(not a.B.GrudgeUI.frame:IsShown(),"An open book closes when guild membership is unavailable")
check(a.B.db.grudges.events[e.id] and a.B.db.grudgePermissions.authored[w.id],"Absent membership preserves the private last-guild save")
check(#a.B.Grudges.queue==0 and not a.B.Grudges.Active(),"Absent membership discards pending history and suspends book traffic")
a.s.guild=true;a.B.GuildChanged()
check(a.B.Grudges.entries[e.id] and a.B.Grudges.deleted[d.id],"Returning roster restores records and tombstones")

local cold=client("Sample","Scribe",a.B.db,a.s.time,true,true,nil,{noGuildAtLogin=true})
check(not cold.B.Grudges.store and cold.B.db.grudges.events[e.id],"Cold login without a roster does not overwrite saved history")
cold.s.guild=true;cold.B.GuildChanged()
check(cold.B.Grudges.entries[e.id] and cold.B.Grudges.deleted[d.id],"Cold login restores history once the same guild is identified")
local pending=client("Sample","Scribe",cold.B.db,cold.s.time,true,true,nil,{clubUnavailable=true,guildName="Example Guild"})
check(pending.B.guildPending and not pending.B.Grudges.store and pending.B.db.grudges.events[e.id],"Cold login with only a name waits for the club ID")
pending.env.C_Club.GetGuildClubId=function() return 42 end;pending.B.GuildChanged()
check(pending.B.Grudges.entries[e.id] and pending.B.Grudges.deleted[d.id],"Delayed club ID loads the saved guild ledger")
pending.s.guild=false;pending.B.GuildChanged()
pending.s.guild=true;pending.env.C_Club.GetGuildClubId=function() return 99 end;pending.B.GuildChanged()
check(#pending.B.Grudges.ids==0 and pending.B.db.grudges.guild=="99","A confirmed different guild still starts with an empty book")
check(not next(pending.B.GrudgePermissions.store.authored),"Different guilds never inherit old moderation receipts")
check(not pending.B.Grudges.Parse(pending.B.Grudges.Encode(e),pending.s.time),"New guild rejects previous guild's serialized records")
