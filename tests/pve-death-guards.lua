local client,check=...
local function fresh() return client("Sample","Scribe") end
local function event(c,name) c.B.eventFrame.scripts.OnEvent(c.B.eventFrame,name) end
local function hit(c,guid,name,flags,overkill)
    c.B.Client.CombatEvent(0,"SPELL_DAMAGE",false,guid,name,flags,0,"Player-1-Sample","Sample Scribe",0,0,
        1,"Strike",1,100,overkill)
end
local function die(c) c.s.dead=true;event(c,"PLAYER_DEAD") end
local function quiet(c)
    for i=1,30 do c.advance(.2);if c.B.DeathUI.frame:IsShown() then return false end end
    return not c.B.own and #c.B.Grudges.ids==0 and next(c.B.Grudges.store.outbox)==nil
end
local cases={
    {"mob combat-log killing blow",function(c) hit(c,"Creature-2-00AA","Wild Creature",0xA40,0) end},
    {"environmental killing blow",function(c) c.B.Client.CombatEvent(0,"ENVIRONMENTAL_DAMAGE",false,nil,nil,0,0,
        "Player-1-Sample","Sample Scribe",0,0,"FALLING",100,0) end},
    {"missing combat log and recap",function() end},
    {"unavailable recap API",function(c) c.env.C_DeathRecap=nil end},
    {"recap API error",function(c) c.env.C_DeathRecap.GetRecapEvents=function() error("unavailable") end end},
    {"restricted combat data",function(c) c.s.combatRestricted=true;c.env.CombatLogGetCurrentEventInfo=function() error("must not read") end;c.B.Client.ReadCombatEvent() end},
    {"mob recap without lethal field",function(c) c.s.recapLink="new";c.s.recap={{sourceGUID="Creature-2-00AA",sourceName="Wild Creature",sourceFlags=0xA40,event="SWING_DAMAGE",amount=100,timeBeforeDeath=0}} end},
    {"mob recap killing blow",function(c) c.s.recapLink="new";c.s.recap={{sourceGUID="Creature-2-00AA",sourceFlags=0xA40,event="SWING_DAMAGE",amount=100,overkill=0,timeBeforeDeath=0}} end},
    {"caster name without player identity",function(c) c.s.recapLink="new";c.s.recap={{sourceName="Unknown Caster",event="SPELL_DAMAGE",amount=100,overkill=0,timeBeforeDeath=0}} end},
    {"old PvP recap",function(c) c.s.recap={{sourceGUID="Player-2-00AA",sourceName="Old Enemy",sourceFlags=0x440,event="SWING_DAMAGE",amount=100,overkill=0,timeBeforeDeath=0}} end},
    {"restricted player identity",function(c) c.s.recapLink="new";c.s.recap={{sourceGUID={secret=true},sourceName="Unreadable Enemy",sourceFlags=0x440,event="SWING_DAMAGE",amount=100,overkill=0,timeBeforeDeath=0}} end},
}
for _,case in ipairs(cases) do
    local c=fresh();c.B.db.auto=true;c.B.Grudges.SetDeathMode("auto");case[2](c);die(c)
    check(quiet(c),"No beacon or grudge popup/automatic write for "..case[1])
    check(not c.B.Grudges.pendingDeath,"No unresolved grudge prompt remains after "..case[1])
end
local independent=fresh();independent.B.Grudges.SetDeathMode("off");die(independent)
check(quiet(independent),"Beacon prompt still requires PvP when the book is turned off")
local separate=fresh();separate.B.db.prompt=false;die(separate)
check(quiet(separate),"Book still requires PvP when the beacon prompt is turned off")
local known=fresh();hit(known,"Player-2-00AA","Example Enemy",0x440,0);die(known);known.advance(1)
check(known.B.DeathUI.frame:IsShown() and known.B.DeathUI.aid:IsShown() and known.B.DeathUI.ledger:IsShown(),"Confirmed hostile-player death still offers both actions")
local mixed=fresh();hit(mixed,"Player-2-00AA","Example Enemy",0x440,-1);hit(mixed,"Creature-2-00BB","Wild Creature",0xA40,0)
die(mixed);mixed.advance(1)
check(mixed.B.DeathUI.frame:IsShown() and mixed.B.DeathUI.aid:IsShown() and mixed.B.DeathUI.ledger:IsShown(),"Actual PvP involvement remains reviewable when a mob lands the last hit")
local delayed=fresh();die(delayed);delayed.advance(3.3)
check(not delayed.B.DeathUI.frame:IsShown(),"Unknown death stays quiet while awaiting late PvP evidence")
delayed.s.recapLink="new";delayed.s.recap={{sourceGUID="Player-2-00AA",sourceName="Late Enemy",sourceFlags=0x440,
    event="SWING_DAMAGE",amount=100,overkill=0,timestamp=delayed.B.deathEvidence.server}}
delayed.advance(2.3)
check(delayed.B.DeathUI.frame:IsShown() and delayed.B.DeathUI.aid:IsShown() and delayed.B.DeathUI.ledger:IsShown(),"Late positive PvP recap can open both actions before retries end")
local nextDeath=fresh();die(nextDeath);nextDeath.s.recapLink="first-death"
nextDeath.s.recap={{sourceGUID="Player-2-00AA",sourceName="Previous Enemy",sourceFlags=0x440,event="SWING_DAMAGE",amount=100,overkill=0,timeBeforeDeath=0}}
nextDeath.advance(1);nextDeath.s.dead=false;event(nextDeath,"PLAYER_ALIVE")
die(nextDeath)
check(quiet(nextDeath),"A new death immediately after resurrection cannot reuse the previous PvP recap")
local manual=fresh();die(manual);manual.advance(6);manual.B.RequestLight();manual.B.UI.composeSend.scripts.OnClick()
check(manual.B.own and not manual.B.DeathUI.frame:IsShown(),"Manually lighting a beacon after a PvE death remains available without reopening death prompts")
manual.B.GrudgeUI.Toggle(true);manual.B.GrudgeUI.Mode("inscribe");manual.B.GrudgeUI.name:SetText("Example Rival");manual.B.GrudgeUI.note:SetText("A manually recorded wrong.")
manual.B.GrudgeUI.submit.scripts.OnClick()
check(#manual.B.Grudges.ids==1,"Manual ledger entry remains available without automatic PvP evidence")
