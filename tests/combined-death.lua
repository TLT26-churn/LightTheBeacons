local client,check=...
local function fresh() return client("Sample","Scribe") end
local function hit(c,name,guid,lethal,flags,amount,target)
    c.B.Client.CombatEvent(0,"SPELL_DAMAGE",false,guid,name,flags or 0x440,0,
        target or "Player-1-Sample","Sample Scribe",0,0,1,"Strike",1,amount or 100,lethal and 0 or -1)
end
local function death(c) c.s.dead=true;c.B.Death();c.advance(1) end
local function revive(c) c.s.dead=false;c.B.eventFrame.scripts.OnEvent(c.B.eventFrame,"PLAYER_ALIVE") end
local function three()
    local c=fresh();c.B.Client.Zone=function() return "Ashenvale" end
    hit(c,"Sample Ravager","Player-2-00BB");c.advance(2)
    hit(c,"Training Raider","Player-2-00CC");hit(c,"Example Marauder","Player-2-00AA",true);death(c)
    return c
end
local c=three();local D,G=c.B.DeathUI,c.B.Grudges
check(D.frame==c.B.UI.deathPrompt and D.frame==c.B.GrudgeUI.deathPrompt,"Beacon and grudge prompts share one physical window")
check(D.frame:IsShown() and D.aid:IsShown() and D.ledger:IsShown(),"Both death actions are visible together")
check(#D.draft.attackers==3 and D.draft.attackers[1].killingBlow,"All detected attackers are listed with the killer first")
check(D.rows[1].role:GetText()=="Killing blow" and D.rows[2].role:GetText()=="Attacked you","Contributor labels do not claim a killing blow")
check(#G.ids==0 and not c.B.own and next(G.store.outbox)==nil,"Showing the combined window sends neither grudges nor a beacon")
D.rows[2].check:SetChecked(false);D.rows[2].check.scripts.OnClick(D.rows[2].check)
check(D.inscribe.caption:GetText()=="Inscribe selected (2)","Selection count responds to individual checkboxes")
D.inscribe.scripts.OnClick()
check(#G.ids==2 and not G.people[c.B.Protocol.Identity("Sample Ravager")] and not c.B.own,"Saving affects only checked attackers, without lighting a beacon")
check(G.people[c.B.Protocol.Identity("Example Marauder")].debts[1].entry.evidence=="pvp","Only the killing blow receives confirmed-death evidence")
local other=G.people[c.B.Protocol.Identity("Training Raider")].debts[1].entry
check(other.evidence=="manual" and other.note=="Attacked me before my death in Ashenvale.","A contributor is recorded as an explicitly selected account of damage")
D.inscribe.scripts.OnClick();check(#G.ids==2,"Repeated save clicks cannot duplicate selected death entries")
D.all.scripts.OnClick();D.inscribe.scripts.OnClick()
check(#G.ids==3 and D.inscribe.enabled==false and D.all.enabled==false,"Remaining attackers can be added once, then recording is disabled")
check(D.rows[1].role:GetText()=="Recorded" and D.status:GetText():find("grudge saved",1,true),"The window confirms saved entries inline")
local peer=client("Sample","Guildmate");peer.B.members[c.B.me]=true
for _,entry in ipairs(G.log) do for _,packet in ipairs(G.Packets(entry)) do peer.B.Grudges.Receive(packet,c.B.name,"GUILD") end end
check(#peer.B.Grudges.ids==3,"Bulk selection shares ordinary compatible ledger records with a guildmate")
local manual=three();local manualD,manualU=manual.B.DeathUI,manual.B.GrudgeUI
manualD.rows[2].check:SetChecked(false);manualD.rows[2].check.scripts.OnClick(manualD.rows[2].check)
local held=manualD.draft;manualD.manual.scripts.OnClick()
check(manualU.name:GetText()=="" and manual.B.Grudges.pendingDeath==held and not manualD.frame:IsShown(),"Adding a missing name suspends and preserves the detected attacker list")
manualU.name:SetText("Missing Enemy");manualU.submit.scripts.OnClick()
check(manualD.frame:IsShown() and manualD.draft==held and not held.selected[manual.B.Protocol.Identity("Sample Ravager")],"Saving a manual name restores the same selections")
manual.advance(3);manualD.manual.scripts.OnClick();manualU.name:SetText("Missing Enemy");manualU.submit.scripts.OnClick()
check(#manual.B.Grudges.ids==1 and manualU.notice:find("already",1,true),"A manually entered name cannot duplicate a record from the same death")
manualU.frame:Hide();manualD.inscribe.scripts.OnClick()
check(#manual.B.Grudges.ids==3,"Detected selections still save after a separate manual name")

local call=three();local CD=call.B.DeathUI
CD.rows[2].check:SetChecked(false);CD.rows[2].check.scripts.OnClick(CD.rows[2].check)
local selected=CD.draft.selected;CD.call.scripts.OnClick()
check(call.B.UI.composer:IsShown() and not CD.frame:IsShown() and #call.B.Grudges.ids==0,"Lighting opens the existing message editor without sharing a grudge")
call.B.UI.composeCancel.scripts.OnClick()
check(CD.frame:IsShown() and CD.draft.selected==selected and not selected[call.B.Protocol.Identity("Sample Ravager")],"Cancelling the beacon editor restores the same death choices")
CD.call.scripts.OnClick();call.B.UI.composeSend.scripts.OnClick()
check(call.B.own and CD.frame:IsShown() and CD.call.caption:GetText()=="Beacon lit","Sending a beacon returns to the combined window with confirmation")
check(#call.B.Grudges.ids==0 and CD.ledger:IsShown() and not call.B.UI.frame:IsShown(),"The grudge list remains available after lighting, without an overlapping rally card")
CD.dismiss.scripts.OnClick();call.B.Death();call.advance(4)
check(not CD.frame:IsShown() and call.B.own,"Dismiss and duplicate death events cannot reopen the window or extinguish a call")
revive(call);check(next(call.B.recentAttackers)==nil,"Resurrection clears the temporary attacker cache")
call.s.dead=true;call.B.Death();call.advance(3.3)
check(not call.B.DeathUI.draft and not call.B.DeathUI.frame:IsShown(),"Attackers from a previous life do not trigger a new death prompt")

local stale=fresh();hit(stale,"Old Attacker","Player-2-00A1");stale.advance(31)
hit(stale,"Current Enemy","Player-2-00A2",true);death(stale)
check(#stale.B.DeathUI.draft.attackers==1,"Damage older than 30 seconds is excluded")
local excluded=fresh()
hit(excluded,"Friendly Player","Player-2-00A1",false,0x410)
hit(excluded,"Wild Creature","Creature-2-00A2",false,0xA40)
hit(excluded,"Controlled Pet","Pet-2-00A3",false,0x1140)
hit(excluded,"No Damage","Player-2-00A4",false,0x440,0)
hit(excluded,"Someone Else's Enemy","Player-2-00A5",false,0x440,100,"Player-1-Other")
hit(excluded,"Secret Amount","Player-2-00A6",false,0x440,{secret=true})
hit(excluded,"Aldric Stoneward","Player-2-00A7")
excluded.s.dead=true;excluded.B.Death();excluded.advance(3.3)
check(not excluded.B.DeathUI.draft and not excluded.B.DeathUI.frame:IsShown(),"Friendly players, NPCs, pets, zero/unreadable damage, other victims and guildmates cannot trigger prompts")
local duplicates=fresh();hit(duplicates,"Repeated Enemy","Player-2-00A1");hit(duplicates,"Repeated Enemy","Player-2-00A1",true);death(duplicates)
check(#duplicates.B.DeathUI.draft.attackers==1,"Repeated damage and the killing blow collapse to one attacker")
local direct=fresh()
direct.B.Client.CombatEvent(0,"SWING_DAMAGE",false,"Player-2-00A1","Melee Enemy",0x440,0,"Player-1-Sample","Sample Scribe",0,0,60,-1)
direct.B.Client.CombatEvent(0,"SPELL_PERIODIC_DAMAGE",false,"Player-2-00A2","Periodic Enemy",0x440,0,"Player-1-Sample","Sample Scribe",0,0,1,"Burn",1,60,0)
death(direct);check(#direct.B.DeathUI.draft.attackers==2,"Melee and periodic damage participate in the same evidence window")
local npcEnd=fresh();hit(npcEnd,"Detected Enemy","Player-2-00A1");hit(npcEnd,"Wild Creature","Creature-2-00A2",true,0xA40);death(npcEnd)
check(#npcEnd.B.DeathUI.draft.attackers==1 and not npcEnd.B.DeathUI.draft.attackers[1].killingBlow,"An NPC finishing blow does not erase actual player contributors or invent a PvP killer")

local noBeacon=fresh();noBeacon.B.db.prompt=false;hit(noBeacon,"Example Enemy","Player-2-00A1",true);death(noBeacon)
check(noBeacon.B.DeathUI.frame:IsShown() and not noBeacon.B.DeathUI.aid:IsShown(),"Disabling the beacon death prompt leaves the grudge prompt independent")
local noBook=fresh();noBook.B.Grudges.SetDeathMode("off");hit(noBook,"Example Enemy","Player-2-00A1",true);death(noBook)
check(noBook.B.DeathUI.frame:IsShown() and not noBook.B.DeathUI.ledger:IsShown(),"Disabling death grudges retains the beacon prompt")
local neither=fresh();neither.B.db.prompt=false;neither.B.Grudges.SetDeathMode("off");death(neither)
check(not neither.B.DeathUI.frame:IsShown(),"Disabling both prompts produces no death window")
local paused=three();paused.B.Grudges.SetEnabled(false);paused.B.DeathUI.inscribe.scripts.OnClick()
check(#paused.B.Grudges.ids==0 and not paused.B.DeathUI.ledger:IsShown() and paused.B.DeathUI.aid:IsShown(),"Pausing the ledger invalidates pending selections without dismissing aid")
local auto=three();revive(auto);auto.advance(3);auto.B.Grudges.SetDeathMode("auto")
hit(auto,"Sample Ravager","Player-2-00BB");hit(auto,"Example Marauder","Player-2-00AA",true);death(auto)
check(#auto.B.Grudges.ids==1 and auto.B.DeathUI.ledger:IsShown() and auto.B.DeathUI.rows[1].role:GetText()=="Recorded","Auto-save still saves only the confirmed killer; contributors need confirmation")
local autoBeacon=fresh();autoBeacon.B.db.auto=true;hit(autoBeacon,"Example Enemy","Player-2-00A1",true);death(autoBeacon)
check(autoBeacon.B.own and autoBeacon.B.DeathUI.ledger:IsShown(),"An automatic beacon does not consume the pending grudge choices")
check(autoBeacon.B.DeathUI.aid:IsShown() and autoBeacon.B.DeathUI.call.caption:GetText()=="Beacon lit","An automatic beacon also confirms its lit state inside the combined window")
local capacity=three();capacity.B.Grudges.limit=2;capacity.B.DeathUI.inscribe.scripts.OnClick()
check(#capacity.B.Grudges.ids==0 and capacity.B.DeathUI.status:GetText():find("full",1,true),"An oversized selection is rejected before saving a partial batch")
local joined=three();joined.B.members[joined.B.Protocol.Identity("Sample Ravager")]=true;joined.B.DeathUI.inscribe.scripts.OnClick()
check(#joined.B.Grudges.ids==0,"A newly joined guildmate invalidates a selection before any batch writes")
local guild=three();guild.env.C_Club.GetGuildClubId=function() return 99 end;guild.B.GuildChanged();guild.B.DeathUI.inscribe.scripts.OnClick()
check(#guild.B.Grudges.ids==0 and not guild.B.DeathUI.frame:IsShown() and next(guild.B.recentAttackers)==nil,"Guild changes clear the window, unsaved choices and attacker cache")
local noStore=fresh();noStore.B.Grudges.SetEnabled(false);hit(noStore,"Ignored Enemy","Player-2-00A1")
check(next(noStore.B.recentAttackers)==nil,"A disabled ledger does not collect attackers")

local many=fresh()
for i=1,40 do hit(many,"Example Attacker "..i,string.format("Player-2-%04X",i));many.advance(.1) end
death(many);local MD=many.B.DeathUI
check(#MD.draft.attackers==32,"Recent attacker memory and a single incident list are bounded")
check(MD.next:IsShown() and MD.pageText:GetText():find("32 detected attackers",1,true),"Long lists expose paging and the full participant count")
local height=MD.frame.height
MD.rows[1].check:SetChecked(false);MD.rows[1].check.scripts.OnClick(MD.rows[1].check);local key=MD.rows[1].entry.key
MD.next.scripts.OnClick();check(MD.page==2 and MD.frame.height==height,"Turning pages preserves the window size")
MD.previous.scripts.OnClick();check(MD.rows[1].entry.key==key and not MD.rows[1].check:GetChecked(),"Selections survive page changes")
MD.all.scripts.OnClick();check(MD.inscribe.caption:GetText()=="Inscribe selected (32)","Select all applies across pages")
MD.all.scripts.OnClick();check(MD.inscribe.enabled==false,"Clear selection clears every page")
MD.dismiss.scripts.OnClick();many.advance(4);check(not MD.frame:IsShown() and #many.B.Grudges.ids==0,"Dismissing a large selection never shares it")

local unknown=fresh();hit(unknown,"Unnamed Enemy","Player-2-00AA",true);unknown.B.killingBlow.name=nil;unknown.B.Client.ClearAttackers()
unknown.s.dead=true;unknown.B.Death();unknown.advance(3.3)
check(unknown.B.DeathUI.frame:IsShown() and unknown.B.DeathUI.aid:IsShown() and unknown.B.DeathUI.ledger:IsShown(),"Confirmed player involvement without a name presents one manual review window")
check(not unknown.B.DeathUI.inscribe:IsShown() and unknown.B.DeathUI.manual.caption:GetText()=="Add a name…","Unknown attribution cannot inscribe an invented attacker")
local visual=three();visual.B.DeathUI.rows[3].check:SetChecked(false);visual.B.DeathUI.rows[3].check.scripts.OnClick(visual.B.DeathUI.rows[3].check)
return {main=visual,unknown=unknown}
