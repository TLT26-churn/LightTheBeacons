-- Headless integration tests: actual addon files, independent simulated clients.
local root=arg[1] or "LightTheBeacons"
local total=0
local function check(v,message) total=total+1;assert(v,message or ("check "..total)) end
-- Forever 16001 event names from Blizzard_APIDocumentationGenerated.
-- RegisterEvent raises on obsolete names in the real client.
local validEvents={}
for name in ("PLAYER_LOGIN ADDON_LOADED CHAT_MSG_ADDON GUILD_ROSTER_UPDATE PLAYER_GUILD_UPDATE "..
    "CLUB_MEMBER_UPDATED CLUB_MEMBER_ADDED CLUB_MEMBER_REMOVED PLAYER_ENTERING_WORLD TAXIMAP_OPENED TAXIMAP_CLOSED "..
    "TAXI_NODE_STATUS_CHANGED PLAYER_DEAD PLAYER_UNGHOST PLAYER_ALIVE PLAYER_REGEN_ENABLED "..
    "ZONE_CHANGED_NEW_AREA COMBAT_LOG_EVENT_UNFILTERED"):gmatch("%S+") do validEvents[name]=true end
local function client(first,surname,saved,startTime,coldLogin,skipTaxi)
    local env=setmetatable({}, {__index=_G});env._G=env
    env.LightTheBeaconsDB=saved
    local B,objects,frames={},{},{}
    local state={now=1000,time=startTime or 2000000000,dead=false,ghost=false,guild=true,sent={},sounds={},timers={},
        pos={map=1429,px=.1,py=.45},outdoor=true,sendResult=0,known={[2]=true,[5]=true},recapLink="old"}
    local methods={}
    local function obj(name,parent,kind)
        local o=setmetatable({name=name,parent=parent,kind=kind or "Frame",shown=true,scripts={},events={},id=#objects+1,
            frameLevel=(parent and parent.frameLevel or 0)+1,width=0,height=0}, {__index=methods})
        objects[#objects+1]=o;if name then env[name]=o end;return o
    end
    function methods:SetPoint(p,a,b,c,d)
        if type(a)=="number" then self.anchor={p,self.parent,p,a,b or 0}
        else self.anchor={p,a or self.parent,b or p,c or 0,d or 0} end
    end
    function methods:ClearAllPoints() self.anchor=nil;self.allPoints=nil end
    function methods:SetAllPoints(target) self.allPoints=target or self.parent end
    function methods:SetSize(w,h) self.width=w;self.height=h end
    function methods:SetWidth(w) self.width=w end
    function methods:SetHeight(h) self.height=h end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:SetScript(e,f) self.scripts[e]=f end
    function methods:HookScript(e,f) local old=self.scripts[e];self.scripts[e]=function(...) if old then old(...) end;f(...) end end
    function methods:RegisterEvent(e) assert(validEvents[e],"Unknown Forever event: "..tostring(e));self.events[e]=true end
    function methods:UnregisterEvent(e) self.events[e]=nil end
    function methods:Show() self.shown=true end
    function methods:Hide() self.shown=false end
    function methods:SetShown(v) self.shown=v and true or false end
    function methods:IsShown() return self.shown end
    function methods:SetEnabled(v) self.enabled=v;local f=self.scripts[v and "OnEnable" or "OnDisable"];if f then f(self) end end
    function methods:SetChecked(v) self.checked=v;if self.CheckedTexture then self.CheckedTexture.shown=v and true or false end end
    function methods:GetChecked() return self.checked end
    function methods:SetText(v) self.text=v end
    function methods:GetText() return self.text end
    function methods:SetFont(path,size) self.fontSize=size;self.font=path end
    function methods:SetTextColor(...) self.color={...} end
    function methods:SetColorTexture(...) self.solid={...} end
    function methods:SetTexture(v) self.file=v end
    function methods:SetTexCoord(...) self.coords={...} end
    function methods:SetAlpha(v) self.alpha=v end
    function methods:SetRotation(v) self.rotation=v end
    function methods:SetJustifyH(v) self.align=v end
    function methods:SetWordWrap(v) self.wrap=v end
    function methods:SetBackdrop(v) self.backdrop=v end
    function methods:SetBackdropColor(...) self.backdropColor={...} end
    function methods:SetBackdropBorderColor(...) self.border={...} end
    function methods:SetFrameLevel(v) self.frameLevel=v end
    function methods:GetFrameLevel() return self.frameLevel end
    function methods:SetScrollChild(v) self.scrollChild=v;v.scrollOwner=self end
    function methods:SetVerticalScroll(v) self.scroll=v end
    function methods:GetVerticalScroll() return self.scroll or 0 end
    function methods:CreateTexture(_,layer) local t=obj(nil,self,"Texture");t.layer=layer;t.frameLevel=self.frameLevel;return t end
    function methods:CreateFontString() local t=obj(nil,self,"FontString");t.frameLevel=self.frameLevel;t.layer="OVERLAY";return t end
    for _,name in ipairs({"SetShadowColor","SetShadowOffset","SetJustifyV","SetBlendMode","SetMovable","SetClampedToScreen",
        "EnableMouse","RegisterForDrag","StartMoving","StopMovingOrSizing","SetFrameStrata","EnableMouseWheel","RegisterForClicks",
        "SetOwner","AddLine","SetParent"}) do methods[name]=function() end end
    for _,stateName in ipairs({"Normal","Pushed","Disabled","Highlight","Checked"}) do
        methods["Set"..stateName.."Texture"]=function(self,path)
            local t=self:CreateTexture(nil,"ARTWORK");t.file=path;t.allPoints=self;t.state=stateName
            t.shown=stateName=="Normal";self[stateName.."Texture"]=t
        end
        methods["Get"..stateName.."Texture"]=function(self) return self[stateName.."Texture"] end
    end
    env.CreateFrame=function(kind,name,parent,template) local f=obj(name,parent,kind);f.template=template;frames[#frames+1]=f;return f end
    env.UIParent=obj("UIParent");env.UIParent:SetSize(1440,1000)
    env.Minimap=obj("Minimap",env.UIParent);env.Minimap:SetSize(180,180);env.Minimap:SetPoint("TOPRIGHT",env.UIParent,"TOPRIGHT",-20,-20)
    env.GameTooltip=obj("GameTooltip",env.UIParent);env.GameTooltip:Hide()
    env.UISpecialFrames={};env.SlashCmdList={};env.DEFAULT_CHAT_FRAME={AddMessage=function(_,m) state.lastMessage=m end}
    env.GetTime=function() return state.now end;env.GetServerTime=function() return state.time end
    env.IsLoggedIn=function() return not coldLogin end
    env.RegionalUniqueNamesEnabled=function() return true end
    env.UnitNameUnmodified=function() return first,surname end;env.UnitName=env.UnitNameUnmodified
    env.UnitGUID=function() return "Player-1-"..first end
    env.GetNormalizedRealmName=function() return "Realm" end
    env.IsInGuild=function() return state.guild end
    env.UnitFactionGroup=function() return "Alliance" end
    env.UnitIsDeadOrGhost=function() return state.dead or state.ghost end
    env.UnitOnTaxi=function() return state.taxi end
    env.IsInInstance=function() return not state.outdoor,state.outdoor and "none" or "pvp" end
    env.GetPlayerFacing=function() return 0 end
    env.C_Club={GetGuildClubId=function() return state.guild and 42 or nil end,
        GetClubMembers=function() return {1,2} end,GetMemberInfo=function(_,id) return {name=id==1 and "Aldric Stoneward" or "Elowen Dawnwatch"} end}
    env.C_ChatInfo={RegisterAddonMessagePrefix=function() return true end,InChatMessagingLockdown=function() return state.restricted end,
        SendAddonMessage=function(prefix,msg,channel) state.sent[#state.sent+1]={prefix,msg,channel};return state.sendResult end}
    env.SendChatMessage=function() error("Ordinary chat must NEVER be used") end
    env.PlaySoundFile=function(file,channel) state.sounds[#state.sounds+1]={file,channel} end
    env.C_Timer={After=function(delay,fn) state.timers[#state.timers+1]={at=state.now+delay,fn=fn} end}
    env.CreateVector2D=function(x,y) return {x=x,y=y} end
    local maps={
        [1429]={c=0,x=-8000,y=1000,w=4000,h=2000,name="Elwynn Forest",parentMapID=1415},
        [1433]={c=0,x=-8800,y=-1600,w=2000,h=1500,name="Redridge Mountains",parentMapID=1415},
        [1415]={c=0,x=5000,y=6000,w=17000,h=25000,name="Eastern Kingdoms",parentMapID=947},
        [1414]={c=1,x=10000,y=5000,w=16000,h=20000,name="Kalimdor",parentMapID=947},
        [947]={name="Azeroth",parentMapID=0}}
    env.C_Map={GetBestMapForUnit=function() return state.pos.map end,
        GetPlayerMapPosition=function() return {x=state.pos.px,y=state.pos.py} end,
        GetMapInfo=function(id) return maps[id] end,
        GetMapChildrenInfo=function() return {{mapID=1429},{mapID=1433},{mapID=1415},{mapID=1414}} end,
        GetWorldPosFromMapPos=function(map,v) local m=maps[map];if m and m.c then return m.c,{x=m.x-v.y*m.h,y=m.y-v.x*m.w} end end,
        GetMapPosFromWorldPos=function(c,v,override)
            local id=override or (c==1 and 1414 or 1415);local m=maps[id]
            if m and m.c==c then return id,{x=(m.y-v.y)/m.w,y=(m.x-v.x)/m.h} end
        end,
        CanSetUserWaypointOnMap=function() return true end,SetUserWaypoint=function(p) state.waypoint=p end}
    env.UiMapPoint={CreateFromCoordinates=function(map,x,y) return {map=map,x=x,y=y} end}
    env.C_SuperTrack={SetSuperTrackedUserWaypoint=function() end}
    env.OpenWorldMap=function(map) state.mapOpened=map end
    env.C_DeathInfo={GetCorpseMapPosition=function() return nil end}
    env.C_DeathRecap={GetRecapEvents=function() return state.recap or {} end,GetRecapLink=function() return state.recapLink end}
    env.C_CombatLog={IsCombatLogRestricted=function() return state.combatRestricted or false end}
    env.Enum={FlightPathState={Current=0,Reachable=1,Unreachable=2},FlightPathFaction={Neutral=0,Horde=1,Alliance=2},SendAddonMessageResult={Success=0}}
    env.C_TaxiMap={GetTaxiNodesForMap=function(map)
        local a={};for id,known in pairs(state.known) do a[#a+1]={nodeID=id,isUndiscovered=not known,name=id==2 and "Stormwind, Elwynn" or "Lakeshire, Redridge",faction=2} end
        -- Forever can return false here even for a destination never discovered.
        a[#a+1]={nodeID=39,isUndiscovered=false,name="Gadgetzan, Tanaris",faction=2}
        return a
    end,GetAllTaxiNodes=function() return state.taxiNodes or {{nodeID=2,slotIndex=1,state=0},{nodeID=5,slotIndex=2,state=1},{nodeID=39,slotIndex=3,state=2}} end}
    env.GetTaxiMapID=function() return 1415 end
    env.hooksecurefunc=function(name,fn) state.hook=fn end;env.TakeTaxiNode=function() end
    env.issecretvalue=function(v) return type(v)=="table" and rawget(v,"secret")==true end
    for line in io.lines(root.."/LightTheBeacons.toc") do
        if line:match("%.lua$") then local chunk=assert(loadfile(root.."/"..line));setfenv(chunk,env);chunk("LightTheBeacons",B) end
    end
    -- Use the actual startup events; directly calling Initialize hid load failures.
    B.eventFrame.scripts.OnEvent(B.eventFrame,"ADDON_LOADED","LightTheBeacons")
    if coldLogin then
        assert(not B.db,"Cold login must wait for PLAYER_LOGIN")
        B.eventFrame.scripts.OnEvent(B.eventFrame,"PLAYER_LOGIN")
    end
    local function advance(seconds)
        state.now=state.now+seconds;state.time=state.time+seconds
        for _=1,20 do
            local pending=state.timers;state.timers={};local called=false
            for _,t in ipairs(pending) do
                if t.at<=state.now then called=true;t.fn() else state.timers[#state.timers+1]=t end
            end
            if not called then break end
        end
    end
    advance(5);state.sent={};state.sounds={}
    if not skipTaxi then
        B.eventFrame.scripts.OnEvent(B.eventFrame,"TAXIMAP_OPENED",0)
        B.eventFrame.scripts.OnEvent(B.eventFrame,"TAXIMAP_CLOSED")
    end
    return {B=B,env=env,s=state,objects=objects,advance=advance}
end
local unvisited=client("Aldric","Stoneward",nil,nil,nil,true)
check(not unvisited.B.db.known[39],"World-map false discovery flag must not unlock Gadgetzan")
check(unvisited.B.Client.KnownCount()==0,"New install waits for a flight-master confirmation")
unvisited.B.Client.RefreshFlights()
check(unvisited.B.Client.KnownCount()==0,"Refresh away from a flight master cannot trust cached taxi data")
unvisited.B.eventFrame.scripts.OnEvent(unvisited.B.eventFrame,"TAXIMAP_OPENED",0)
check(unvisited.B.db.known[2] and unvisited.B.db.known[5] and not unvisited.B.db.known[39],"Flight master confirms only current and reachable nodes")
unvisited.B.eventFrame.scripts.OnEvent(unvisited.B.eventFrame,"TAXIMAP_CLOSED")
unvisited.s.taxiNodes={{nodeID=2,slotIndex=1,state=0},{nodeID=39,slotIndex=3,state=1}}
unvisited.B.Client.RefreshFlights()
check(not unvisited.B.db.known[39],"Closed flight map cannot confirm a cached reachable node")
local polluted=client("Aldric","Stoneward",{known={[2]=true,[39]=true,[40]=true},nodes={[9999]={n="Wrong map coordinate",c=1,x=1,y=2,f="A"}},sound=false,pace=14,times={["2:5"]=100}},nil,nil,true)
check(polluted.B.Client.KnownCount()==0 and not polluted.B.TravelData.nodes[9999],"Upgrade clears unverified discovery and map-position caches")
check(polluted.B.db.sound==false and polluted.B.db.pace==14 and polluted.B.db.times["2:5"]==100,"Upgrade preserves settings and flight timings")
local a=client("Aldric","Stoneward")
local b=client("Elowen","Dawnwatch")
check(a.env.SLASH_LIGHTTHEBEACONS1=="/ltb","Slash command registered after addon loading")
a.env.SlashCmdList.LIGHTTHEBEACONS("")
check(a.B.UI.frame:IsShown(),"/ltb opens the window after reload")
a.env.SlashCmdList.LIGHTTHEBEACONS("")
check(not a.B.UI.frame:IsShown(),"/ltb closes the window")
local login=client("Aldric","Stoneward",nil,nil,true)
login.env.SlashCmdList.LIGHTTHEBEACONS("")
check(login.B.UI.frame:IsShown(),"/ltb opens after a fresh login")
local P,R=a.B.Protocol,a.B.Routing
check(a.B.me=="aldric stoneward","Forever surname identity")
check(a.B.Client.KnownCount()==2,"Explicit discovery")
check(a.B.Light(),"Manual beacon send")
check(#a.s.sent==1 and a.s.sent[1][3]=="GUILD","Addon data uses GUILD only")
local packet=a.s.sent[1][2]
b.B.Receive(packet,a.B.name,"WHISPER");check(#b.B.List()==0,"Ignore whispers")
b.B.Receive(packet,"Outsider","GUILD");check(#b.B.List()==0,"Ignore non-guild sender")
b.B.Receive(packet,a.B.name,"GUILD");check(#b.B.List()==1 and #b.s.sounds==1,"Private incoming banner + one horn")
check(b.B.UI.banner:IsShown(),"Incoming banner visible")
b.B.Receive(packet,a.B.name,"GUILD");check(#b.s.sounds==1,"Duplicate does not sound again")
check(not a.B.Light() and #a.s.sent==1,"Local cooldown")
local beacon=b.B.List()[1];b.B.Select(beacon);b.B.Answer()
check(b.B.navigating and #b.s.sent==1,"Answer acknowledges privately")
a.B.Receive(b.s.sent[1][2],b.B.name,"GUILD")
check(a.B.own.responders[b.B.me]==b.B.name,"Caller sees responder")
a.B.Extinguish();b.B.Receive(a.s.sent[#a.s.sent][2],a.B.name,"GUILD")
check(#b.B.List()==0 and not b.B.navigating,"Extinguish stops navigation")
b.B.Receive(packet,a.B.name,"GUILD");check(#b.B.List()==0,"Cancellation blocks delayed beacon")
local valid={id="123.456",sent=b.s.time,map=1433,px=.2,py=.5,reason="aid"}
local encoded=P.Encode(valid)
check(P.Parse(encoded,b.s.time)~=nil)
for _,bad in ipairs({"", "1|B|bad|NaN|1|0.5|0.5|aid",encoded.."|extra",encoded:gsub("|aid$","|evil"),string.rep("x",251)}) do
    check(P.Parse(bad,b.s.time)==nil,"Reject malformed protocol")
end
check(P.Parse(P.Encode({id="a",sent=b.s.time-301,map=1433,px=.5,py=.5,reason="aid"}),b.s.time)==nil,"Reject stale beacon")
check(P.Parse(P.Encode({id="a",sent=b.s.time+100,map=1433,px=.5,py=.5,reason="aid"}),b.s.time)==nil,"Reject future beacon")
check(P.Parse(P.Encode({id="a",sent=b.s.time,map=1433,px=3,py=.5,reason="aid"}),b.s.time)==nil,"Reject off-map coordinates")
check(P.Parse({secret=true},b.s.time)==nil,"Ignore secret message")
local data=a.B.TravelData
local start={c=0,x=-8900,y=600};local goal={c=0,x=-9510,y=-2640}
local known=R.Plan(start,goal,{[2]=true,[5]=true},"A",7)
local locked=R.Plan(start,goal,{[2]=true},"A",7)
local n=0;for _,step in ipairs(known.steps) do if step.kind=="flight" then n=n+1;check(step.fromID==2 and step.toID==5,"Correct flight route") end end
check(n==1 and known.seconds<locked.seconds,"Known flights improve route")
for _,step in ipairs(locked.steps) do check(step.kind~="flight","Never suggest an undiscovered destination") end
local disconnected={nodes={[1]={c=0,x=0,y=0,f="A",n="a"},[2]={c=0,x=2000,y=0,f="A",n="b"},[3]={c=0,x=4000,y=0,f="A",n="c"}},
    flights={[1]={[2]=10},[2]={[3]=10}},ships={}}
local intermediate=R.Plan({c=0,x=0,y=0},{c=0,x=4000,y=0},{[1]=true,[3]=true},"A",7,disconnected)
for _,step in ipairs(intermediate.steps) do check(step.kind~="flight","Unknown intermediate excluded") end
local cross=R.Plan({c=0,x=-14277,y=583},{c=1,x=-1006,y=-3842},{},"A",7)
local boat=false;for _,step in ipairs(cross.steps) do if step.kind=="boat" then boat=true end end
check(boat,"Cross-continent transport")
check(R.Ground({c=0,x=0,y=0},{c=1,x=0,y=0},7)==math.huge,"No walking across continents")
check(R.Ground({c=1,x=8500,y=900},{c=1,x=6500,y=800},7)==math.huge,"No walking to Teldrassil")
local different=R.Plan({c=555,x=0,y=0},goal,{},"A",7);check(different.unavailable,"Unsupported maps are explicit")
local e={100,"SPELL_DAMAGE",false,"Player-2-enemy","Enemy",0x440,0,"Player-1-Aldric","Aldric",0,0,133,"Fireball",4,500,0}
a.B.Client.CombatEvent(unpack(e));check(a.B.Client.ConfirmedDeath(),"Lethal hostile-player damage including exactly zero overkill")
e[16]=-1;a.B.Client.CombatEvent(unpack(e));check(not a.B.Client.ConfirmedDeath(),"Nonlethal damage never confirms death")
e[16]=20;e[4]="Creature-2-enemy";a.B.Client.CombatEvent(unpack(e));check(not a.B.Client.ConfirmedDeath(),"NPC death never auto-alerts")
e[4]="Player-2-enemy";e[6]=0x410;a.B.Client.CombatEvent(unpack(e));check(not a.B.Client.ConfirmedDeath(),"Friendly player excluded")
e[6]=0x440;a.B.Client.CombatEvent(unpack(e))
a.B.Client.CombatEvent(100,"ENVIRONMENTAL_DAMAGE",false,nil,nil,0,0,"Player-1-Aldric")
check(not a.B.Client.ConfirmedDeath(),"Environmental damage clears previous evidence")
-- Opt-in automatic death emits one beacon after a readable player killing blow.
a.advance(61);a.B.db.auto=true;a.s.dead=true
a.B.Client.CombatEvent(unpack(e));a.B.Death();a.advance(1)
check(a.B.own and a.B.own.reason=="pvp","Automatic confirmed PvP death")
local saved=a.B.deathPoint;a.s.ghost=true;a.s.pos={map=1429,px=.9,py=.9}
check(a.B.Client.Corpse()==saved,"Corpse destination stays at the incident after release")
local npc=client("Aldric","Stoneward");npc.B.db.auto=true;npc.s.dead=true;npc.B.Death();npc.advance(1)
check(#npc.s.sent==0 and npc.B.UI.deathPrompt:IsShown(),"Unconfirmed death prompts without sending")
npc.s.outdoor=false;npc.B.UI.deathPrompt:Hide();npc.B.Death();npc.advance(1)
check(not npc.B.UI.deathPrompt:IsShown(),"Battleground/instance suppression")
local restricted=client("Aldric","Stoneward");restricted.s.restricted=true
check(not restricted.B.Light() and not restricted.B.own and #restricted.s.sent==0,"Messaging lockdown is respected")
restricted.s.restricted=false;restricted.s.sendResult=5
check(not restricted.B.Light() and not restricted.B.own,"Failed send never claims delivery")
local preview=client("Elowen","Dawnwatch");preview.B.Preview()
check(#preview.s.sent==0 and #preview.s.sounds==0,"Preview never broadcasts or sounds automatically")
preview.B.Answer();check(#preview.s.sent==0,"Preview answer is local")
preview.B.Sound(true);check(#preview.s.sounds==1,"Horn test works")
preview.B.db.sound=false;preview.advance(6);preview.B.Sound();check(#preview.s.sounds==1,"Mute works")
local before=#preview.s.sent;preview.B.UI.options=true;preview.B.UI.Refresh();check(#preview.s.sent==before,"Options never send")
preview.B.UI.options=false;preview.B.UI.Refresh()
-- Saved settings/discovery belong to this character and survive a reload.
local original=client("Aldric","Stoneward");original.B.db.sound=false;original.B.db.known[42]=true
check(original.B.Light(),"Save lifecycle initial beacon")
local restored=client("Aldric","Stoneward",original.B.db,original.s.time+1)
check(restored.B.db.known[42] and restored.B.db.sound==false,"Reload preserves discoveries and settings")
check(restored.B.own and restored.B.own.id==original.B.own.id,"Reload preserves your extinguishable beacon")
check(not restored.B.Light(),"Cooldown survives reload")
restored.B.Extinguish();check(not restored.B.own,"Restored beacon can be extinguished")
local separate=client("Elowen","Dawnwatch");check(not separate.B.db.known[42],"Discovery never leaks across characters")
separate.B.Light();separate.s.guild=false;separate.B.GuildChanged()
check(not separate.B.own and #separate.B.List()==0 and not separate.B.db.active,"Leaving guild clears active data")
check(not separate.B.Light(),"No guild means no outgoing alert")
-- Recaps must be new for this death, not a remembered earlier PvP death.
local recap=client("Aldric","Stoneward")
recap.s.recap={{sourceGUID="Player-2-enemy",sourceFlags=0x440,overkill=1,timeBeforeDeath=0}}
check(not recap.B.Client.ConfirmedDeath(),"Old death recap cannot trigger a fresh alert")
recap.s.recapLink="new";check(recap.B.Client.ConfirmedDeath(),"New readable player recap can confirm")
recap.s.recap[1].sourceGUID="Creature-1-enemy";check(not recap.B.Client.ConfirmedDeath(),"NPC recap rejected")
recap.s.recap[1].sourceGUID={secret=true};check(not recap.B.Client.ConfirmedDeath(),"Secret recap ignored")
recap.s.recapLink={secret=true};check(not recap.B.Client.ConfirmedDeath(),"Secret recap key ignored")
recap.B.Client.CombatEvent(unpack(e));e[16]={secret=true};recap.B.Client.CombatEvent(unpack(e))
check(not recap.B.killingBlow,"Unreadable damage invalidates automatic evidence");e[16]=20
check(P.Parse(P.Encode({id="boundary",sent=b.s.time-P.ttl,map=1433,px=.5,py=.5,reason="aid"}),b.s.time)==nil,"Exact expiry boundary rejected")
-- Known nodes learned from the taxi map are independent of the bundled graph.
local discovered=client("Aldric","Stoneward")
discovered.env.C_TaxiMap.GetAllTaxiNodes=function() return {{nodeID=2,slotIndex=1,state=0},
    {nodeID=9999,slotIndex=2,state=1,name="New Forever Landing",position={x=.4,y=.4}}} end
discovered.env.GetNumRoutes=function(slot) return slot==2 and 1 or 0 end
discovered.env.TaxiGetNodeSlot=function(_,_,source) return source and 1 or 2 end
discovered.B.Client.TaxiOpened()
check(discovered.B.db.known[9999] and discovered.B.TravelData.nodes[9999],"New flight point learned at the flight master")
local observed=discovered.B.Client.World(1415,.4,.4)
check(discovered.B.TravelData.nodes[9999].x==observed.x and discovered.B.TravelData.nodes[9999].y==observed.y,"New node position uses the actual taxi map")
check(discovered.B.TravelData.flights[2][9999]~=nil,"New directed connection learned from actual taxi map")
local savedTime=discovered.B.db.times['2:9999']
discovered.B.Client.TaxiClosed()
discovered.B.Client.TaxiTaken(2);discovered.s.taxi=true;discovered.B.Client.ObserveFlight()
check(discovered.B.Client.flight and discovered.B.Client.flight.seen,"Synchronous flight-map close preserves takeoff timing")
discovered.advance(50);discovered.s.taxi=false;discovered.B.Client.ObserveFlight()
check(discovered.B.db.times['2:9999']==savedTime,"Early landing never corrupts destination flight time")
-- Reproduce the screenshot: world-map data claims Gadgetzan is known, while
-- the actual flight-master map confirms only Ratchet and Theramore.
local gadget=client("Aldric","Stoneward",nil,nil,nil,true)
gadget.s.taxiNodes={{nodeID=80,slotIndex=1,state=0},{nodeID=32,slotIndex=2,state=1},{nodeID=39,slotIndex=3,state=2}}
gadget.B.Client.TaxiOpened()
local route=gadget.B.Routing.Plan(data.nodes[80],{c=1,x=-7224,y=-3734,n="Tanaris beacon"},gadget.B.db.known,"A",7)
for _,step in ipairs(route.steps) do
    check(step.kind~="flight" or step.toID~=39,"Never fly to undiscovered Gadgetzan")
end
check(not gadget.B.db.known[39],"Unreachable Gadgetzan stays unconfirmed")
gadget.s.taxiNodes[3].state=1
gadget.B.Client.TaxiOpened()
check(gadget.B.db.known[39],"Gadgetzan unlocks when the flight master confirms it")
local persisted=client("Aldric","Stoneward",gadget.B.db,nil,nil,true)
check(persisted.B.db.known[39],"Confirmed Gadgetzan survives reload without another flight-master visit")
local partial=client("Aldric","Stoneward",nil,nil,nil,true)
partial.s.taxiNodes={{nodeID=39,slotIndex=3,state=1}}
check(not partial.B.Client.TaxiOpened() and not partial.B.db.known[39],"A partial list without a current flight master proves nothing")
partial.s.taxiNodes={{nodeID=2,slotIndex=1,state=0},{nodeID=39,slotIndex=3,state=1,isMapLayerTransition=true}}
partial.B.Client.TaxiOpened()
check(not partial.B.db.known[39],"Map transition pins are not flight destinations")
partial.s.taxiNodes[2].isMapLayerTransition=false
partial.env.TaxiNodeGetType=function(slot) return slot==1 and "CURRENT" or "NONE" end
partial.B.Client.TaxiOpened()
check(not partial.B.db.known[39],"An explicit unavailable slot cannot confirm discovery")
partial.env.TaxiNodeGetType=nil;partial.s.taxiNodes[2].state={secret=true}
partial.B.Client.TaxiOpened()
check(not partial.B.db.known[39],"Secret flight-state data cannot confirm discovery")
local active=client("Elowen","Dawnwatch",nil,nil,nil,true)
active.B.Receive(packet,a.B.name,"GUILD");active.B.Answer()
local beforeRoute=active.B.route
active.B.Client.TaxiOpened()
check(active.B.route~=beforeRoute and active.B.navigating,"Flight-master discovery replans an active rescue route")
-- Hostile transport rows and directed edges cannot become free cross-map walks.
local horde=R.Plan({c=0,x=-12464,y=232},{c=1,x=1361,y=-4631},{},"H",7)
local zeppelin=false;for _,step in ipairs(horde.steps) do if step.kind=="zeppelin" then zeppelin=true end end
check(zeppelin,"Horde transport network is available")
local flying=client("Elowen","Dawnwatch")
flying.B.Receive(packet,a.B.name,"GUILD");flying.s.taxi=true;flying.B.Answer()
check(flying.B.route.pendingFlight and flying.B.navigating,"A responder already flying waits for landing")
flying.s.taxi=false;flying.B.TickRoute()
check(not flying.B.route.pendingFlight and not flying.B.waitingLanding,"Route replans on actual landing")
local deadResponder=client("Elowen","Dawnwatch")
deadResponder.B.Receive(packet,a.B.name,"GUILD");deadResponder.s.dead=true;deadResponder.B.Answer()
check(not deadResponder.B.navigating and #deadResponder.s.sent==0,"A ghost cannot start a flight rescue route")
local perf=os.clock()
local allKnown={};for id in pairs(data.nodes) do allKnown[id]=true end
for _=1,50 do R.Plan(start,{c=1,x=6400,y=700},allKnown,"A",14) end
check(os.clock()-perf<2,"Bounded route planner performance")
-- Render preview with a full Forever character name, not a short placeholder.
preview.B.preview.name="Aldric Stoneward";preview.B.preview.point.n="Aldric Stoneward's beacon"
preview.B.preview.responders.other="Elowen Dawnwatch"
preview.B.preview.route=preview.B.Routing.Plan({c=0,x=-8900,y=600},preview.B.preview.point,{[2]=true,[5]=true},"A",7)
preview.B.route=preview.B.preview.route;preview.B.UI.Alert(preview.B.preview,true);preview.B.UI.Refresh()
-- Snapshot the actual widget tree for separate visual QA (not a hand-built mockup).
local function snapshot(c,target,path)
    local function bounds(o)
        if o.box then return unpack(o.box) end
        if o==c.env.UIParent then return 0,0,1440,1000 end
        local x,y,w,h=0,0,o.width or 0,o.height or 0
        if o.allPoints then x,y,w,h=bounds(o.allPoints)
        elseif o.anchor then
            local a=o.anchor;local rx,ry,rw,rh=bounds(a[2] or c.env.UIParent)
            local p,q=a[1],a[3]
            x=rx+(q:find("RIGHT") and rw or q:find("LEFT") and 0 or rw/2)+(a[4] or 0)
            y=ry+(q:find("BOTTOM") and rh or q:find("TOP") and 0 or rh/2)-(a[5] or 0)
            x=x-(p:find("RIGHT") and w or p:find("LEFT") and 0 or w/2)
            y=y-(p:find("BOTTOM") and h or p:find("TOP") and 0 or h/2)
        elseif o.parent then x,y=bounds(o.parent) end
        if o.scrollOwner then y=y-(o.scrollOwner.scroll or 0) end
        o.box={x,y,w,h};return x,y,w,h
    end
    local function visible(o)
        if o.shown==false then return false end
        if o.parent then return visible(o.parent) end
        return true
    end
    local function inside(o)
        if o==target then return true end
        return o.parent and inside(o.parent)
    end
    local function json(v)
        local t=type(v)
        if t=="nil" then return "null" end
        if t=="boolean" or t=="number" then return tostring(v) end
        if t=="string" then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')..'"' end
        local a={};local array=#v>0
        if array then for _,val in ipairs(v) do a[#a+1]=json(val) end
        else for k,val in pairs(v) do a[#a+1]=json(k)..":"..json(val) end end
        return (array and "[" or "{")..table.concat(a,",")..(array and "]" or "}")
    end
    local ox,oy,ow,oh=bounds(target);local scene={width=ow,height=oh,items={}}
    for _,o in ipairs(c.objects) do if inside(o) and visible(o) then
        local x,y,w,h=bounds(o);local item={id=o.id,kind=o.kind,x=x-ox,y=y-oy,width=w,height=h,
            frameLevel=o.frameLevel,layer=o.layer,text=o.text,fontSize=o.fontSize,color=o.color,align=o.align,
            wrap=o.wrap,file=o.file,coords=o.coords,solid=o.solid,alpha=o.alpha,backdrop=o.backdrop,
            backdropColor=o.backdropColor,border=o.border}
        local ancestor=o
        while ancestor do
            if ancestor.scrollOwner then
                local cx,cy,cw,ch=bounds(ancestor.scrollOwner);item.clip={cx-ox,cy-oy,cw,ch};break
            end
            ancestor=ancestor.parent
        end
        scene.items[#scene.items+1]=item
    end end
    local f=assert(io.open(path,"w"));f:write(json(scene));f:close()
end
if arg[2] then
    snapshot(preview,preview.B.UI.frame,arg[2].."-window.json")
    snapshot(preview,preview.B.UI.banner,arg[2].."-alert.json")
    preview.B.UI.options=true;preview.B.UI.Refresh()
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.frame,arg[2].."-options.json")
end
print("Light the Beacons: "..total.." checks passed (protocol, routing, two clients, death detection, UI).")
