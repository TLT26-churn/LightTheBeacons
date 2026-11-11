-- Death-to-ledger workflow: use real widgets and events, never saved player data.
local client,check=...
local function event(c,name) c.B.eventFrame.scripts.OnEvent(c.B.eventFrame,name) end
local function hit(c,guid,flags)
    c.B.Client.CombatEvent(0,"SPELL_DAMAGE",false,guid or "Player-2-00FF","Example Enemy",flags or 0x440,0,
        "Player-1-Sample","Sample Scribe",0,0,1,"Strike",1,100,0)
end
local function death(c) c.s.dead=true;event(c,"PLAYER_DEAD") end
local function prompt(c) return c.B.GrudgeUI.deathPrompt and c.B.GrudgeUI.deathPrompt:IsShown() end
local function fresh() return client("Sample","Scribe") end
local known=fresh();local G,U=known.B.Grudges,known.B.GrudgeUI
check(G.options.deathMode=="prompt","New installs ask before sharing a death grudge")
hit(known);death(known);known.advance(1)
check(prompt(known) and #G.ids==0 and #G.queue==0,"Confirmed PvP death prompts without saving or queuing guild data")
check(U.deathText:GetText():find("Example Enemy",1,true),"Confirmed killer appears in the prompt")
death(known);known.advance(1);U.deathAction.scripts.OnClick()
check(U.compose:IsShown() and U.name:GetText()=="Example Enemy" and not prompt(known),"Review opens the prefilled native entry form")
check(not known.B.UI.deathPrompt:IsShown(),"The separate beacon prompt cannot cover the grudge entry form")
check(#G.ids==0,"Reviewing a death does not share it")
known.s.pos.map=1433;known.s.dead=false;event(known,"PLAYER_ALIVE")
U.submit.scripts.OnClick()
check(#G.ids==1 and G.log[1].evidence=="pvp" and G.log[1].guid=="Player-2-00FF","Saving retains confirmed killer evidence after resurrection")
check(G.log[1].where=="Elwynn Forest","Death entry retains its death zone after moving")
known.advance(4);check(#G.ids==1 and not prompt(known),"Repeated death timers cannot reopen or duplicate an accepted entry")

local unknown=fresh();death(unknown);unknown.advance(2)
check(not prompt(unknown),"Unknown attribution waits briefly for the recap")
unknown.advance(1.3);local UU=unknown.B.GrudgeUI
check(prompt(unknown) and #unknown.B.Grudges.ids==0,"Unavailable attribution offers manual fallback without inventing a killer")
check(UU.deathText:GetText():find("couldn't identify",1,true),"Unknown-killer prompt explains the limitation")
UU.deathAction.scripts.OnClick();check(UU.name:GetText()=="","Manual fallback leaves the enemy field empty")
UU.submit.scripts.OnClick();check(#unknown.B.Grudges.ids==0,"An empty enemy name cannot be shared")
UU.name:SetText("Sample Rival");UU.submit.scripts.OnClick()
check(#unknown.B.Grudges.ids==1 and unknown.B.Grudges.log[1].evidence=="manual","User-confirmed fallback is recorded as a manual account")

local changed=fresh();hit(changed);death(changed);changed.advance(1)
changed.B.GrudgeUI.deathAction.scripts.OnClick();changed.B.GrudgeUI.name:SetText("Sample Rival");changed.B.GrudgeUI.submit.scripts.OnClick()
check(changed.B.Grudges.log[1].evidence=="manual" and changed.B.Grudges.log[1].guid=="","Editing the killer name removes automatic verification and GUID")

local dismissed=fresh();hit(dismissed);death(dismissed);dismissed.advance(1)
dismissed.B.GrudgeUI.deathDismiss.scripts.OnClick();death(dismissed);dismissed.advance(4)
check(not prompt(dismissed) and #dismissed.B.Grudges.ids==0,"Dismiss stays dismissed for the same death")
dismissed.s.dead=false;event(dismissed,"PLAYER_ALIVE");hit(dismissed);death(dismissed);dismissed.advance(1)
check(prompt(dismissed),"A new death may prompt after a dismissed one")

local delayed=fresh();death(delayed);delayed.advance(1);hit(delayed);delayed.advance(.9)
check(prompt(delayed) and delayed.B.Grudges.pendingDeath.evidence=="pvp","Late readable killing-blow evidence fills the prompt")
local recap=fresh();death(recap);recap.advance(1);recap.s.recapLink="new"
recap.s.recap={{sourceGUID="Player-2-00FF",sourceName="Example Enemy",sourceFlags=0x440,overkill=0,timeBeforeDeath=.1}}
recap.advance(.9)
check(prompt(recap) and recap.B.Grudges.pendingDeath.enemy=="Example Enemy","A new public death recap can prefill the killer")
local nameless=fresh();hit(nameless);nameless.B.killingBlow.name=nil;death(nameless);nameless.advance(3.3)
check(prompt(nameless) and nameless.B.Grudges.pendingDeath.enemy=="","Player evidence without a readable name still offers manual entry")

local restricted=fresh();restricted.s.combatRestricted=true
restricted.env.CombatLogGetCurrentEventInfo=function() error("Restricted reader must stay unused") end
restricted.B.Client.ReadCombatEvent();death(restricted);restricted.advance(3.3)
check(prompt(restricted) and #restricted.B.Grudges.ids==0,"Restricted combat data uses the manual fallback")
local npc=fresh();hit(npc,"Creature-2-00FF",0xA40);death(npc);npc.advance(3.3)
check(not prompt(npc) and #npc.B.Grudges.ids==0,"Readable lethal NPC damage suppresses the PvP prompt")
local fall=fresh();fall.B.Client.CombatEvent(0,"ENVIRONMENTAL_DAMAGE",false,nil,nil,0,0,"Player-1-Sample","Sample Scribe",0,0,"FALLING",100,0)
death(fall);fall.advance(3.3)
check(not prompt(fall),"Readable lethal environmental damage suppresses the PvP prompt")
local pveRecap=fresh();pveRecap.s.recapLink="new"
pveRecap.s.recap={{sourceGUID="Creature-2-00FF",sourceFlags=0xA40,overkill=0,timeBeforeDeath=.1}}
death(pveRecap);pveRecap.advance(3.3);check(not prompt(pveRecap),"A new readable NPC recap suppresses the PvP prompt")
local pet=fresh();hit(pet,"Creature-2-00FF",0x1940);death(pet);pet.advance(3.3)
check(prompt(pet),"Player-controlled pets are not mistaken for confirmed PvE deaths")

local ghost=fresh();death(ghost);ghost.s.dead=false;ghost.s.ghost=true;event(ghost,"PLAYER_ALIVE");ghost.advance(3.3)
check(prompt(ghost),"Releasing spirit does not cancel the death prompt")
local alive=fresh();death(alive);alive.s.dead=false;event(alive,"PLAYER_ALIVE");alive.advance(4)
check(not prompt(alive),"Resurrection cancels delayed prompts")
local guild=fresh();death(guild);guild.env.C_Club.GetGuildClubId=function() return 99 end;guild.B.GuildChanged();guild.advance(4)
check(not prompt(guild) and #guild.B.Grudges.ids==0,"Guild changes cancel pending prompts")
local editedGuild=fresh();hit(editedGuild);death(editedGuild);editedGuild.advance(1);editedGuild.B.GrudgeUI.BeginDeathEntry()
editedGuild.env.C_Club.GetGuildClubId=function() return 99 end;editedGuild.B.GuildChanged()
check(not editedGuild.B.GrudgeUI.deathDraft and editedGuild.B.GrudgeUI.name:GetText()=="","Guild changes clear accepted death drafts")
local instance=fresh();instance.s.outdoor=false;death(instance);instance.advance(4)
check(not prompt(instance),"Instances and battlegrounds do not create death grudge prompts")
local secret=fresh();secret.env.UnitIsDeadOrGhost=function() return {secret=true} end;secret.B.Grudges.OnDeath();secret.advance(4)
check(not prompt(secret) and #secret.B.Grudges.ids==0,"Unreadable death state cannot produce a prompt or record")

local off=fresh();off.B.Grudges.SetDeathMode("off");hit(off);death(off);off.advance(4)
check(not prompt(off) and #off.B.Grudges.ids==0,"Off disables death prompts and automatic entries")
local stopped=fresh();death(stopped);stopped.B.Grudges.SetDeathMode("off");stopped.advance(4)
check(not prompt(stopped),"Turning death prompts off cancels queued checks")
local disabled=fresh();death(disabled);disabled.B.Grudges.SetEnabled(false);disabled.advance(4)
check(not prompt(disabled),"Pausing the guild ledger cancels queued prompts")
local muted=fresh();muted.B.MuteBeacons(true);hit(muted);death(muted);muted.advance(4)
check(not prompt(muted) and #muted.B.Grudges.ids==0,"Global alert mute suppresses the new prompt")
local muteLater=fresh();hit(muteLater);death(muteLater);muteLater.advance(1);muteLater.B.MuteBeacons(true);muteLater.advance(4)
check(not prompt(muteLater),"Global alert mute dismisses a visible prompt")
local auto=fresh();auto.B.Grudges.SetDeathMode("auto");hit(auto);death(auto);auto.advance(1)
check(#auto.B.Grudges.ids==1 and not prompt(auto),"Explicit Auto-save retains automatic confirmed-death recording")
local autoUnknown=fresh();autoUnknown.B.Grudges.SetDeathMode("auto");death(autoUnknown);autoUnknown.advance(3.3)
check(prompt(autoUnknown) and #autoUnknown.B.Grudges.ids==0,"Auto-save falls back to manual confirmation for an unknown killer")

local prior=fresh();prior.B.GrudgeUI.Toggle(true);prior.B.GrudgeUI.Mode("inscribe")
prior.B.GrudgeUI.name:SetText("Training Foe");prior.B.GrudgeUI.note:SetText("An unfinished account.")
hit(prior);death(prior);prior.advance(1);prior.B.GrudgeUI.deathAction.scripts.OnClick()
check(prior.B.GrudgeUI.name:GetText()=="Training Foe" and prior.B.GrudgeUI.note:GetText()=="An unfinished account." and prior.B.Grudges.pendingDeath,
    "Reviewing a death cannot overwrite an unfinished entry")
prior.B.GrudgeUI.submit.scripts.OnClick()
check(prompt(prior),"A deferred death prompt returns after the unfinished entry is saved")
prior.B.GrudgeUI.deathAction.scripts.OnClick()
check(prior.B.GrudgeUI.name:GetText()=="Example Enemy" and not prompt(prior),"Death review remains available after the previous draft is saved")

local migration=fresh();migration.B.Grudges.options.deathMode=nil;migration.B.Grudges.options.autoRecord=true
local migrated=client("Sample","Scribe",migration.B.db,migration.s.time)
check(migrated.B.Grudges.options.deathMode=="prompt","Existing enabled death recording migrates to Ask first")
migration.B.Grudges.options.deathMode=nil;migration.B.Grudges.options.autoRecord=false
local stayedOff=client("Sample","Scribe",migration.B.db,migration.s.time)
check(stayedOff.B.Grudges.options.deathMode=="off","An existing disabled death option stays disabled")
auto.B.GrudgeUI.Toggle(true);auto.B.GrudgeUI.Mode("settings");auto.B.GrudgeUI.deathModes.prompt.scripts.OnClick()
check(auto.B.Grudges.options.deathMode=="prompt","The native settings control selects Ask first")
auto.B.GrudgeUI.deathModes.auto.scripts.OnClick()
local autoReloaded=client("Sample","Scribe",auto.B.db,auto.s.time)
check(autoReloaded.B.Grudges.options.deathMode=="auto","An explicit Auto-save choice survives reload")

local visual=fresh();hit(visual);death(visual);visual.advance(1)
return visual
