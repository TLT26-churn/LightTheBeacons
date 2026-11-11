local client,check=...
local function fresh() return client("Sample","Scribe") end
local function hit(c)
    c.B.Client.CombatEvent(0,"SPELL_DAMAGE",false,"Player-2-00AA","Example Enemy",0x440,0,
        "Player-1-Sample","Sample Scribe",0,0,1,"Strike",1,100,0)
end
for _,kind in ipairs({"pvp","arena","party","raid","scenario"}) do
    local c=fresh();c.env.IsInInstance=function() return true,kind end
    c.B.db.auto=true;hit(c);c.s.dead=true;c.B.Death();c.advance(4)
    check(not c.B.DeathUI.frame:IsShown() and #c.B.Grudges.ids==0 and not c.B.own and next(c.B.recentAttackers)==nil,
        "Death prompts, automatic calls and attacker recording are disabled in "..kind)
end
local ambiguous=fresh();ambiguous.env.IsInInstance=function() return false,"pvp" end
check(not ambiguous.B.Client.IsOutdoor(),"A battleground type is excluded even if the instance boolean is inconsistent")
ambiguous.env.IsInInstance=function() return false,nil end
check(not ambiguous.B.Client.IsOutdoor(),"An unknown instance type cannot trigger death-window replacement")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA"}) do
    local c=fresh();hit(c);c.s.dead=true;c.B.Death();c.advance(1);local draft=c.B.Grudges.pendingDeath
    c.s.outdoor=false;c.B.eventFrame.scripts.OnEvent(c.B.eventFrame,event)
    local count=c.B.Grudges.InscribeDeathSelection(draft)
    check(not c.B.DeathUI.frame:IsShown() and not c.B.Grudges.pendingDeath and next(c.B.recentAttackers)==nil and count==0,
        "Entering a battleground clears an existing outdoor death window on "..event)
end
local crossing=fresh();crossing.B.db.auto=true;hit(crossing);crossing.s.dead=true;crossing.B.Death()
crossing.s.outdoor=false;crossing.advance(4)
check(not crossing.B.own and not crossing.B.DeathUI.frame:IsShown(),"Crossing into a battleground before death timers run cannot send a delayed beacon")
local stale=fresh();hit(stale);stale.s.dead=true;stale.B.Death();stale.advance(1);stale.s.outdoor=false
stale.B.DeathUI.inscribe.scripts.OnClick();stale.B.DeathUI.call.scripts.OnClick()
check(#stale.B.Grudges.ids==0 and not stale.B.UI.composer:IsShown(),"Stale death action buttons cannot record or compose a call inside a battleground")
