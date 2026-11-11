local client,check=...
local function fresh() return client("Sample","Scribe") end
local function event(c,name) c.B.eventFrame.scripts.OnEvent(c.B.eventFrame,name) end
local function death(c) c.s.dead=true;c.B.Death() end
local function row(c,name,guid,age,lethal)
    return {sourceGUID=guid,sourceName=name,sourceFlags=0x440,event="SPELL_DAMAGE",amount=100,
        overkill=lethal and 0 or -1,timestamp=(c.B.deathEvidence and c.B.deathEvidence.server or c.s.time)-age}
end
local function recap(c,rows) c.s.recap=rows;c.s.recapLink="new" end
local function prompt(c) return c.B.DeathUI.frame:IsShown() and c.B.DeathUI.draft end
local function count(c) return #(c.B.Grudges.pendingDeath and c.B.Grudges.pendingDeath.attackers or {}) end

local c=fresh();c.s.combatRestricted=true;death(c)
recap(c,{row(c,"Example Marauder","Player-2-00AA",0,true),row(c,"Sample Ravager","Player-2-00BB",4,false),
    row(c,"Training Raider","Player-2-00CC",12,false),row(c,"Sample Ravager","Player-2-00BB",2,false)})
c.advance(1)
check(prompt(c) and count(c)==3,"Epoch-based Forever recap lists all readable damage contributors without combat logs")
check(c.B.DeathUI.rows[1].role:GetText()=="Killing blow","Zero overkill in epoch recap confirms a killing blow")
check(#c.B.Grudges.ids==0 and not c.B.own,"Reading a recap does not share names or light a beacon")
c.B.DeathUI.rows[2].check:SetChecked(false);c.B.DeathUI.rows[2].check.scripts.OnClick(c.B.DeathUI.rows[2].check)
c.B.DeathUI.inscribe.scripts.OnClick()
check(#c.B.Grudges.ids==2 and not c.B.Grudges.people[c.B.Protocol.Identity("Sample Ravager")],"Recap-derived names obey explicit checkbox consent")
c.advance(5)
check(#c.B.Grudges.ids==2 and not c.B.DeathUI.rows[2].check:GetChecked(),"Later retries preserve saved entries and unchecked choices")

local relative=fresh();death(relative)
local er=row(relative,"Relative Enemy","Player-2-00AA",3,false);er.timestamp=nil;er.timeBeforeDeath=3
recap(relative,{er});relative.advance(1)
check(count(relative)==1 and not relative.B.DeathUI.draft.attackers[1].killingBlow,"Relative-time recaps support nonlethal contributors")

for _,kind in ipairs({"old","future","secret-name","secret-guid","secret-flags","secret-time","secret-amount","zero","heal","friendly","pet","npc","name-only"}) do
    local t=fresh();death(t);local r=row(t,"Rejected Enemy","Player-2-00AA",0,false)
    if kind=="old" then r.timestamp=t.s.time-31
    elseif kind=="future" then r.timestamp=t.s.time+20
    elseif kind=="secret-name" then r.sourceName={secret=true}
    elseif kind=="secret-guid" then r.sourceGUID={secret=true}
    elseif kind=="secret-flags" then r.sourceFlags={secret=true}
    elseif kind=="secret-time" then r.timestamp={secret=true}
    elseif kind=="secret-amount" then r.amount={secret=true}
    elseif kind=="zero" then r.amount=0
    elseif kind=="heal" then r.event="SPELL_HEAL"
    elseif kind=="friendly" then r.sourceFlags=0x410
    elseif kind=="pet" then r.sourceGUID="Pet-2-00AA";r.sourceFlags=0x1140
    elseif kind=="npc" then r.sourceGUID="Creature-2-00AA";r.sourceFlags=0xA40
    elseif kind=="name-only" then r.sourceGUID=nil;r.sourceFlags=nil end
    recap(t,{r});t.advance(3.3)
    check(count(t)==0 and #t.B.Grudges.ids==0,"Recap excludes "..kind.." evidence")
end
local mixed=fresh();death(mixed)
recap(mixed,{{secret=true},{sourceGUID={secret=true},timestamp={secret=true}},row(mixed,"Readable Enemy","Player-2-00AA",1,false)})
mixed.advance(1);check(count(mixed)==1,"One restricted recap row cannot discard other readable attackers")
local broken=fresh();broken.env.C_DeathRecap.GetRecapEvents=function() error("recap unavailable") end;death(broken);broken.advance(3.3)
check(not prompt(broken) and count(broken)==0,"Recap API failures cannot trigger death prompts without PvP evidence")
local stale=fresh();death(stale);stale.s.recap={row(stale,"Old Enemy","Player-2-00AA",0,true)};stale.advance(3.3)
check(count(stale)==0 and not stale.B.Client.ConfirmedDeath(),"An unchanged recap link is never accepted as this death")
local noLink=fresh();noLink.s.recapLink=nil;noLink.B.Client.CaptureLivingRecap();death(noLink)
noLink.s.recap={row(noLink,"New Enemy","Player-2-00AA",0,true)};noLink.advance(1)
check(count(noLink)==1,"Clients without recap links can use new incident-matched timestamps")
local noLinkOld=fresh();noLinkOld.s.recapLink=nil;noLinkOld.s.recap={row(noLinkOld,"Old Enemy","Player-2-00AA",0,true)}
noLinkOld.B.Client.CaptureLivingRecap();death(noLinkOld);noLinkOld.advance(3.3)
check(count(noLinkOld)==0,"Timestamp baseline prevents replay of a previous linkless recap")
local noBaseline=fresh();noBaseline.s.recapLink=nil
noBaseline.env.C_DeathRecap.GetRecapEvents=function() error("not available while alive") end
noBaseline.B.Client.CaptureLivingRecap();death(noBaseline)
noBaseline.env.C_DeathRecap.GetRecapEvents=function() return {row(noBaseline,"Uncertain Enemy","Player-2-00AA",0,true)} end
noBaseline.advance(3.3)
check(count(noBaseline)==0,"A missing living timestamp baseline cannot authorize a linkless old recap")

local late=fresh();death(late);late.advance(3.3)
check(not prompt(late) and count(late)==0,"Unknown attribution stays quiet after the initial wait")
recap(late,{row(late,"Delayed Enemy","Player-2-00AA",0,true)});late.advance(2.3)
check(prompt(late) and count(late)==1 and late.B.DeathUI.inscribe.enabled,"Late positive PvP evidence opens the first review with its detected attacker")
check(#late.B.Grudges.ids==0,"Opening the first review after late evidence still requires explicit sharing")
local expand=fresh();death(expand);recap(expand,{row(expand,"First Enemy","Player-2-00AA",0,true)});expand.advance(1)
expand.B.DeathUI.rows[1].check:SetChecked(false);expand.B.DeathUI.rows[1].check.scripts.OnClick(expand.B.DeathUI.rows[1].check)
expand.s.recap[2]=row(expand,"Later Enemy","Player-2-00BB",5,false);expand.advance(1)
check(count(expand)==2 and expand.B.DeathUI.inscribe.enabled==false,"Growing recaps preserve deselection and leave added names unchecked")
expand.s.recap[3]=row(expand,"Alphabetically Earlier","Player-2-00CC",4,false);expand.advance(1.3)
check(expand.B.DeathUI.rows[1].name:GetText()=="First Enemy" and expand.B.DeathUI.rows[2].name:GetText()=="Later Enemy",
    "Late arrivals do not reorder rows underneath the player's cursor")
local dismissed=fresh();death(dismissed);dismissed.advance(3.3);dismissed.B.DeathUI.Dismiss()
recap(dismissed,{row(dismissed,"Delayed Enemy","Player-2-00AA",0,true)});dismissed.advance(3)
check(not prompt(dismissed) and #dismissed.B.Grudges.ids==0,"A late recap cannot reopen a dismissed review")
local revive=fresh();death(revive);revive.s.dead=false;event(revive,"PLAYER_ALIVE")
recap(revive,{row(revive,"Delayed Enemy","Player-2-00AA",0,true)});revive.advance(6)
check(not prompt(revive) and not revive.B.deathEvidence,"Resurrection cancels delayed recap collection and incident timestamps")
local auto=fresh();auto.B.db.auto=true;death(auto);auto.advance(1)
recap(auto,{row(auto,"Delayed Enemy","Player-2-00AA",0,true)});auto.advance(1)
check(auto.B.own and #auto.B.Grudges.ids==0,"Opt-in automatic beacon can use delayed recap evidence without auto-sharing grudges")
local id=auto.B.own.id;auto.advance(5);check(auto.B.own.id==id,"Multiple recap retries cannot send a second automatic beacon")
local manuallyLit=fresh();manuallyLit.B.db.auto=true;death(manuallyLit);manuallyLit.advance(1)
manuallyLit.B.Light("fallen");manuallyLit.B.Extinguish()
recap(manuallyLit,{row(manuallyLit,"Delayed Enemy","Player-2-00AA",0,true)});manuallyLit.advance(5)
check(not manuallyLit.B.own,"Late automatic detection cannot relight a manually extinguished death beacon")
local pve=fresh();death(pve);local nr=row(pve,"Wild Creature","Creature-2-00AA",0,true);nr.sourceFlags=0xA40
recap(pve,{nr});pve.advance(3.3);check(not pve.B.DeathUI.draft,"Epoch-based NPC lethal damage suppresses the grudge prompt")
local pvpNpc=fresh();death(pvpNpc);local nr2=row(pvpNpc,"Wild Creature","Creature-2-00AA",0,true);nr2.sourceFlags=0xA40
recap(pvpNpc,{nr2,row(pvpNpc,"Player Contributor","Player-2-00BB",2,false)});pvpNpc.advance(1)
check(count(pvpNpc)==1 and not pvpNpc.B.DeathUI.draft.attackers[1].killingBlow,"NPC finishing blow retains player contributors without inventing a player killer")
local duplicate=fresh();duplicate.B.Client.RememberAttacker("Player-2-00AA","Example Fullname",0x440,10);death(duplicate)
recap(duplicate,{row(duplicate,"Example-Realm","Player-2-00AA",0,true)});duplicate.advance(1)
check(count(duplicate)==1 and duplicate.B.DeathUI.draft.enemy=="Example Fullname","Combat and recap names deduplicate by GUID while retaining a readable full name")
local stable=fresh();stable.B.Client.CombatEvent(0,"SPELL_DAMAGE",false,"Player-2-00AA","Stable Enemy",0x440,0,
    "Player-1-Sample","Sample Scribe",0,0,1,"Strike",1,100,0)
death(stable);stable.advance(1);stable.advance(5)
check(stable.B.DeathUI.draft.attackers[1].killingBlow and stable.B.DeathUI.confirmed,"Confirmed incident evidence remains stable after the combat-cache timeout")
local conflict=fresh();death(conflict)
recap(conflict,{row(conflict,"First Claim","Player-2-00AA",0,true),row(conflict,"Second Claim","Player-2-00BB",0,true)})
conflict.advance(1)
check(count(conflict)==2 and not conflict.B.Client.ConfirmedDeath(),"Conflicting lethal recap rows remain contributors without a guessed killer")
local alias=fresh();alias.B.Grudges.Inscribe("Example-Realm","A recorded attack.","Player-2-00AA","manual")
local person=alias.B.Grudges.PersonFor("Example Fullname","Player-2-00AA")
check(person and person.open==1,"A recap's abbreviated name remains identifiable by player GUID")
check(not alias.B.Grudges.PersonFor("Example-Realm","Player-2-00BB"),"An exact name with a different known GUID is not the same debtor")
alias.env.UnitIsPlayer=function() return true end;alias.env.UnitCanAttack=function() return true end
alias.env.UnitNameUnmodified=function() return "Example","Fullname" end;alias.env.UnitGUID=function() return "Player-2-00AA" end
alias.B.Grudges.ObserveUnit("target")
check(alias.B.Grudges.sightings[alias.B.Protocol.Identity("Example-Realm")],"Full-name target sighting resolves an abbreviated recap entry by GUID")
alias.env.UnitNameUnmodified=function() return nil end;alias.B.Grudges.seenAlert={}
alias.B.Grudges.ObserveUnit("target")
check(alias.B.Grudges.seenAlert[alias.B.Protocol.Identity("Example-Realm")],"A readable GUID sighting can use its stored name when the live name is unavailable")
alias.env.UnitGUID=function() return "Player-1-Sample" end
alias.B.Grudges.Combat({0,"PARTY_KILL",false,"Player-1-Sample","Sample Scribe",0,0,"Player-2-00AA","Example Fullname",0x440})
check(alias.B.Grudges.people[alias.B.Protocol.Identity("Example-Realm")].open==0,"Confirmed vengeance matches the same GUID across name formats")
local resumed=fresh();resumed.B.db.auto=true;resumed.s.dead=true;resumed.B.Death(true)
recap(resumed,{row(resumed,"Restored Enemy","Player-2-00AA",0,true)});resumed.advance(6)
check(not resumed.B.own and prompt(resumed),"Recovered review UI cannot automatically light a beacon after reload")

-- A protected / skinned native window is an immutable external surface. Any
-- attempted mutation fails this integration test immediately.
local function withNative()
    local n=fresh();local f=n.env.CreateFrame("Frame","StaticPopup1",n.env.UIParent);f.which="DEATH"
    f.GetRect=function() return 500,650,440,110 end
    f.IsProtected=function() return true end
    f:SetPoint("CENTER",n.env.UIParent,"CENTER",0,100)
    n.env.StaticPopup_FindVisible=function(which) return which=="DEATH" and f:IsShown() and f or nil end
    local release=n.env.CreateFrame("Button",nil,f);local recapButton=n.env.CreateFrame("Button",nil,f)
    release:SetScript("OnClick",function() n.s.releases=(n.s.releases or 0)+1 end)
    recapButton:SetScript("OnClick",function() n.s.recaps=(n.s.recaps or 0)+1 end)
    local handlers={release.scripts.OnClick,recapButton.scripts.OnClick}
    for _,method in ipairs({"SetParent","SetPoint","ClearAllPoints","SetSize","SetHeight","SetWidth","SetScale","SetAlpha",
        "Hide","Show","SetShown","SetScript","HookScript","SetFrameLevel","SetFrameStrata","EnableMouse","UnregisterEvent"}) do
        f[method]=function() error("LTB must not mutate the native death window: "..method) end
        release[method]=f[method];recapButton[method]=f[method]
    end
    death(n);recap(n,{row(n,"Example Marauder","Player-2-00AA",0,true),row(n,"Sample Ravager","Player-2-00BB",3,false),row(n,"Training Raider","Player-2-00CC",9,false)})
    n.advance(1)
    return n,f,release,recapButton,handlers
end
local dock,native,release,recapButton,handlers=withNative();local D=dock.B.DeathUI
check(prompt(dock) and D.dockStatus=="below Blizzard death controls","Guild actions dock below a protected native window without changing it")
check(D.frame.anchor[5]*D.frame:GetScale()<650,"Docked guild actions leave the entire native window above them")
check(release.scripts.OnClick==handlers[1] and recapButton.scripts.OnClick==handlers[2],"Original release and recap click handlers remain identical")
release.scripts.OnClick();recapButton.scripts.OnClick()
check(dock.s.releases==1 and dock.s.recaps==1,"Native controls remain independently usable")
D.Dismiss();release.scripts.OnClick()
check(native:IsShown() and dock.s.releases==2,"Hiding guild actions leaves the native release window usable")
local moved,nf=withNative();nf.GetRect=function() return 500,100,440,110 end
moved.B.DeathUI.Tick(.3)
check(moved.B.DeathUI.dockStatus=="beside Blizzard death controls","A low native window uses side space instead of overlapping release controls")
local narrow,nn=withNative();narrow.env.UIParent:SetSize(800,600);nn.GetRect=function() return 180,50,440,110 end;narrow.B.DeathUI.Tick(.3)
check(not narrow.B.DeathUI.frame:IsShown() and nn:IsShown(),"Insufficient layout space hides only guild actions, never native controls")
nn.GetRect=function() return 180,500,440,90 end;narrow.B.DeathUI.Tick(.3)
check(narrow.B.DeathUI.frame:IsShown(),"Guild actions recover automatically when layout space becomes available")
local unreadable,un=withNative();un.GetRect=function() return {secret=true},0,440,110 end;unreadable.B.DeathUI.Tick(.3)
check(not unreadable.B.DeathUI.frame:IsShown() and un:IsShown(),"Unreadable native geometry cannot cause an overlapping replacement")
local protectedScale,sn=withNative();protectedScale.env.UIParent:SetScale(.8);sn.GetEffectiveScale=function() return .64 end
protectedScale.B.DeathUI.Tick(.3)
check(protectedScale.B.DeathUI.frame.anchor[5]*protectedScale.B.DeathUI.frame:GetScale()<650*.8,"Native and root UI scales are reconciled before docking")
local opened,on=withNative();local recapFrame=opened.env.CreateFrame("Frame","DeathRecapFrame",opened.env.UIParent)
opened.B.DeathUI.Tick(.3)
check(not opened.B.DeathUI.frame:IsShown() and on:IsShown(),"Opening Death Recap hides only the guild extension")
recapFrame:Hide();opened.B.DeathUI.Tick(.3)
check(opened.B.DeathUI.frame:IsShown(),"Closing Death Recap restores the same review selections")
local released,rn=withNative();rn.shown=false;released.s.dead=false;released.s.ghost=true;event(released,"PLAYER_ALIVE");released.B.DeathUI.Tick(.3)
check(prompt(released) and released.B.DeathUI.dockStatus=="standalone guild actions","Releasing spirit retains pending grudge review independently")
local bg,bn=withNative();bg.s.outdoor=false;event(bg,"ZONE_CHANGED_NEW_AREA");bg.B.DeathUI.Tick(.3)
check(not bg.B.DeathUI.frame:IsShown() and bn:IsShown(),"Entering a battleground removes the extension without touching native controls")
local reuse,rfn=withNative();rfn.which="CONFIRM_SOMETHING";reuse.env.StaticPopup_FindVisible=function() return nil end;reuse.B.DeathUI.Tick(.3)
check(reuse.B.DeathUI.dockStatus=="standalone guild actions","Reused StaticPopup frames are not mistaken for death windows")
local preview=withNative();preview.B.DeathUI.rows[3].check:SetChecked(false);preview.B.DeathUI.rows[3].check.scripts.OnClick(preview.B.DeathUI.rows[3].check)
preview.advance(5)
return preview
