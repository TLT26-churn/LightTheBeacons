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
    "ZONE_CHANGED_NEW_AREA SKILL_LINES_CHANGED SPELLS_CHANGED COMBAT_LOG_EVENT_UNFILTERED PLAYER_TARGET_CHANGED UPDATE_MOUSEOVER_UNIT"):gmatch("%S+") do validEvents[name]=true end
local function client(first,surname,saved,startTime,coldLogin,skipTaxi)
    local env=setmetatable({}, {__index=_G});env._G=env
    env.LightTheBeaconsDB=saved
    local B,objects,frames={},{},{}
    local state={now=1000,time=startTime or 2000000000,dead=false,ghost=false,guild=true,sent={},sounds={},soundFiles={},timers={},messages={},
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
    function methods:SetScale(v) self.scale=v end
    function methods:GetScale() return self.scale or 1 end
    function methods:GetEffectiveScale() return self:GetScale()*(self.parent and self.parent:GetEffectiveScale() or 1) end
    function methods:SetOrientation(v) self.orientation=v end
    function methods:SetMinMaxValues(lo,hi) self.minimum=lo;self.maximum=hi end
    function methods:SetValueStep(v) self.step=v end
    function methods:SetObeyStepOnDrag(v) self.obeyStep=v end
    function methods:SetThumbTexture(v) self.thumb=v end
    function methods:SetValue(v)
        local changed=self.value~=v;self.value=v
        if self.thumb then self.thumb:SetPoint("CENTER",self,"LEFT",self:GetWidth()*(v-self.minimum)/(self.maximum-self.minimum),0) end
        if changed and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end
    end
    function methods:GetValue() return self.value end
    function methods:SetScript(e,f) self.scripts[e]=f end
    function methods:HookScript(e,f) local old=self.scripts[e];self.scripts[e]=function(...) if old then old(...) end;f(...) end end
    function methods:RegisterEvent(e) assert(validEvents[e],"Unknown Forever event: "..tostring(e));self.events[e]=true end
    function methods:UnregisterEvent(e) self.events[e]=nil end
    function methods:Show() local was=self.shown;self.shown=true;if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
    function methods:Hide() local was=self.shown;self.shown=false;if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
    function methods:SetShown(v) self.shown=v and true or false end
    function methods:IsShown() return self.shown end
    function methods:SetEnabled(v) self.enabled=v;local f=self.scripts[v and "OnEnable" or "OnDisable"];if f then f(self) end end
    function methods:SetChecked(v) self.checked=v;if self.CheckedTexture then self.CheckedTexture.shown=v and true or false end end
    function methods:GetChecked() return self.checked end
    function methods:SetText(v) self.text=v;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
    function methods:GetText() return self.text end
    function methods:SetFocus() self.focused=true end
    function methods:ClearFocus() self.focused=false end
    function methods:SetFont(path,size) self.fontSize=size;self.font=path end
    function methods:SetTextColor(...) self.color={...} end
    function methods:SetVertexColor(...) self.vertexColor={...} end
    function methods:SetColorTexture(...) self.solid={...} end
    function methods:SetTexture(v) self.file=v end
    function methods:SetTexCoord(...) self.coords={...} end
    function methods:SetAlpha(v) self.alpha=v end
    function methods:SetDesaturated(v) self.desaturated=v end
    function methods:GetCenter() return self.centerX or 720,self.centerY or 500 end
    function methods:SetRotation(v) self.rotation=v end
    function methods:SetJustifyH(v) self.align=v end
    function methods:SetWordWrap(v) self.wrap=v end
    function methods:SetNonSpaceWrap(v) self.nonSpaceWrap=v end
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
        "SetOwner","AddLine","SetParent","SetAutoFocus","SetMultiLine","SetMaxLetters","SetMaxBytes","SetCursorPosition"}) do methods[name]=function() end end
    function methods:SetParent(parent) self.parent=parent end
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
    env.UISpecialFrames={};env.SlashCmdList={};env.DEFAULT_CHAT_FRAME={AddMessage=function(_,m) state.lastMessage=m;state.messages[#state.messages+1]=m end}
    env.GetTime=function() return state.now end;env.GetServerTime=function() return state.time end
    env.date=os.date
    env.IsShiftKeyDown=function() return state.shift==true end
    env.IsLoggedIn=function() return not coldLogin end
    env.RegionalUniqueNamesEnabled=function() return true end
    env.UnitNameUnmodified=function() return first,surname end;env.UnitName=env.UnitNameUnmodified
    env.UnitGUID=function() return "Player-1-"..first end
    env.GetNormalizedRealmName=function() return "Realm" end
    env.IsInGuild=function() return state.guild end
    env.UnitFactionGroup=function() return "Alliance" end
    env.UnitIsDeadOrGhost=function() return state.dead or state.ghost end
    env.UnitOnTaxi=function() return state.taxi end
    env.C_SkillInfo={GetSkillLineInfoByID=function(id) assert(id==762);return {skillID=762,rank=state.riding or 0,maxRank=300} end}
    env.IsInInstance=function() return not state.outdoor,state.outdoor and "none" or "pvp" end
    env.GetPlayerFacing=function() return 0 end
    env.C_Club={GetGuildClubId=function() return state.guild and 42 or nil end,
        GetClubMembers=function() return {1,2} end,GetMemberInfo=function(_,id) return {name=id==1 and "Aldric Stoneward" or "Elowen Dawnwatch"} end}
    env.C_ChatInfo={RegisterAddonMessagePrefix=function() return true end,InChatMessagingLockdown=function() return state.restricted end,
        SendAddonMessage=function(prefix,msg,channel) state.sent[#state.sent+1]={prefix,msg,channel};return state.sendResult end}
    env.SendChatMessage=function() error("Ordinary chat must NEVER be used") end
    env.C_Sound={PlaySound=function(id) state.sounds[#state.sounds+1]={id};return state.soundSuccess~=false,42 end}
    env.PlaySoundFile=function(id,channel)
        assert(id==566064 or id==569543,"Only the two native WoW FileDataIDs may play; never a bundled recording")
        assert(channel=="Master","Native alert files use the Master channel")
        state.soundFiles[#state.soundFiles+1]={id,channel}
        state.sounds[#state.sounds+1]={id==566064 and 10843 or 8173}
        return state.soundSuccess~=false,42
    end
    env.StopSound=function(handle) state.stoppedSound=handle;state.stoppedSounds=state.stoppedSounds or {};state.stoppedSounds[handle]=true end
    env.GetCVar=function(name) return name=="Sound_MasterVolume" and "0.3" or "1" end
    env.C_Timer={After=function(delay,fn) state.timers[#state.timers+1]={at=state.now+delay,fn=fn} end}
    env.CreateVector2D=function(x,y) return {x=x,y=y} end
    local maps={
        [1429]={c=0,x=-8000,y=1000,w=4000,h=2000,name="Elwynn Forest",parentMapID=1415},
        [1433]={c=0,x=-8800,y=-1600,w=2000,h=1500,name="Redridge Mountains",parentMapID=1415},
        [1415]={c=0,x=5000,y=6000,w=17000,h=25000,name="Eastern Kingdoms",parentMapID=947},
        [1414]={c=1,x=10000,y=5000,w=16000,h=20000,name="Kalimdor",parentMapID=947},
        [1446]={c=1,x=-7000,y=-3000,w=7000,h=6000,name="Tanaris",parentMapID=1414},
        [947]={name="Azeroth",parentMapID=0}}
    env.C_Map={GetBestMapForUnit=function() return state.pos.map end,
        GetPlayerMapPosition=function() return {x=state.pos.px,y=state.pos.py} end,
        GetMapInfo=function(id) return maps[id] end,
        GetMapRectOnMap=function(id,parent)
            local m,top=maps[id],maps[parent]
            if parent==947 and id==1415 then return .55,.95,.15,.85 end
            if parent==947 and id==1414 then return .05,.45,.1,.8 end
            if m and top and m.c==top.c and m.c then return (top.y-m.y)/top.w,(top.y-m.y+m.w)/top.w,(top.x-m.x)/top.h,(top.x-m.x+m.h)/top.h end
        end,
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
    env.hooksecurefunc=function(name,fn,hook)
        if type(name)=="table" then local old=name[fn];name[fn]=function(...) local result={old(...)};hook(...);return unpack(result) end
        else state.hook=fn end
    end;env.TakeTaxiNode=function() end
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
    advance(5);state.sent={};state.sounds={};state.soundFiles={}
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
check(b.s.sounds[1][1]==10843,"Beacon uses native Horn of Cenarius sound kit")
check(a.B.UI.answerBanner:IsShown() and a.B.UI.answerName:GetText()==b.B.name,"Caller gets a named first-response celebration")
check(a.B.UI.answerTitle:GetText()=="THE ALLIANCE ANSWERS!" and a.B.UI.answerCount:GetText()=="1 ALLY ON THE WAY","First responder gets the full rally")
check(a.s.sounds[#a.s.sounds][1]==8173,"First response uses native Alliance capture fanfare")
check(not b.B.UI.answerBanner:IsShown(),"Responder does not celebrate someone else's beacon")
local soundCount=#a.s.sounds
local answerPacket=b.s.sent[1][2]
a.B.Receive(answerPacket,b.B.name,"GUILD")
check(#a.s.sounds==soundCount and a.B.UI.answerCount:GetText()=="1 ALLY ON THE WAY","Duplicate responses never replay the rally")
a.B.members["whitebeard tinkerton"]=true
a.B.Receive(answerPacket,"Whitebeard Tinkerton","GUILD")
check(#a.s.sounds==soundCount and a.B.UI.answerCount:GetText()=="2 ALLIES ON THE WAY","Additional allies update the count without another fanfare")
check(a.B.UI.answerTitle:GetText()=="REINFORCEMENTS INBOUND" and a.B.UI.answerBanner.duration==4,"Additional allies get a shorter celebration")
a.B.UI.answerBanner.scripts.OnUpdate(a.B.UI.answerBanner,5)
check(not a.B.UI.answerBanner:IsShown(),"Rally animation expires")
local restoredRally=client("Aldric","Stoneward",a.B.db,a.s.time)
check(restoredRally.B.own.responders[b.B.me]==b.B.name,"Confirmed responder survives caller reload")
restoredRally.B.Receive(answerPacket,b.B.name,"GUILD")
check(#restoredRally.s.sounds==0 and not restoredRally.B.UI.answerBanner:IsShown(),"Reload cannot replay a duplicate first-response fanfare")
a.B.UI.Answered(b.B.name,2,false,a.B.own)

a.B.Extinguish();b.B.Receive(a.s.sent[#a.s.sent][2],a.B.name,"GUILD")
check(#b.B.List()==0 and not b.B.navigating,"Extinguish stops navigation")
a.B.UI.answerBanner.scripts.OnUpdate(a.B.UI.answerBanner,.1)
check(not a.B.UI.answerBanner:IsShown(),"Extinguishing the beacon dismisses its rally")
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
local npc=client("Aldric","Stoneward");npc.B.db.auto=true;npc.s.dead=true;npc.B.Death();npc.advance(3.3)
check(#npc.s.sent==0 and not npc.B.UI.deathPrompt:IsShown(),"Unconfirmed death stays quiet without sending")
npc.s.outdoor=false;npc.B.UI.deathPrompt:Hide();npc.B.Death();npc.advance(1)
check(not npc.B.UI.deathPrompt:IsShown(),"Battleground/instance suppression")
local restricted=client("Aldric","Stoneward");restricted.s.restricted=true
check(not restricted.B.Light() and not restricted.B.own and #restricted.s.sent==0,"Messaging lockdown is respected")
restricted.s.restricted=false;restricted.s.sendResult=5
check(not restricted.B.Light() and not restricted.B.own,"Failed send never claims delivery")
local preview=client("Elowen","Dawnwatch");preview.B.Preview()
check(#preview.s.sent==0 and #preview.s.sounds==0,"Preview never broadcasts or sounds automatically")
local rallyPreview=client("Aldric","Stoneward")
rallyPreview.env.SlashCmdList.LIGHTTHEBEACONS("rally")
check(#rallyPreview.s.sent==0 and #rallyPreview.s.sounds==0 and not rallyPreview.B.UI.answerBanner:IsShown(),"Removed rally command cannot trigger a test fanfare")
local mutedRally=client("Aldric","Stoneward",{sound=false})
mutedRally.B.Light();mutedRally.B.Receive("1|R|"..mutedRally.B.own.id.."|"..mutedRally.B.me,"Elowen Dawnwatch","GUILD")
check(#mutedRally.s.sounds==0 and mutedRally.B.UI.answerBanner:IsShown(),"Mute suppresses both sounds without hiding the celebration")
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
local expired=client("Aldric","Stoneward",{guild="42",active=original.B.db.active,
    messages={[1]="Keep my template"},shareLocation=false},original.s.time+301)
check(not expired.B.own and not expired.B.db.active,"Login clears a beacon that expired while offline, including its message and responders")
check(expired.B.db.messages[1]=="Keep my template" and not expired.B.db.shareLocation,"Expired-beacon cleanup preserves templates and sharing opt-out")
local invalid=client("Aldric","Stoneward",{guild="42",active={id="broken",sent=original.s.time,map="invalid",message="Old incident"}})
check(not invalid.B.own and not invalid.B.db.active,"Login discards invalid saved incident data")
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
-- Automatic pace uses trained rank, is local to the character, and replans on training.
local rider=client("Aldric","Stoneward",{pace=14})
check(rider.B.TravelSpeed()==7 and rider.B.db.travelMode=="auto","Old manual 100% setting does not grant untrained riding")
rider.s.riding=75;rider.B.UpdateTravelPace()
check(rider.B.TravelSpeed()==11.2,"Apprentice riding selects 60% movement speed")
rider.s.riding=150;rider.B.UpdateTravelPace()
check(rider.B.TravelSpeed()==14,"Journeyman riding selects 100% movement speed")
rider.s.riding=300;rider.B.UpdateTravelPace()
check(rider.B.TravelSpeed()==14,"Higher riding ranks never inflate ground speed above 100%")
rider.env.C_SkillInfo.GetSkillLineInfoByID=function() return {skillID=762,rank=75,maxRank=300,name="Reiten"} end
rider.B.UpdateTravelPace()
check(rider.B.TravelSpeed()==11.2,"Uses trained rank, not max rank or localized skill name")
rider.env.C_SkillInfo=nil
rider.env.C_SpellBook={IsSpellKnown=function(id) return id==33388 or id==33391 end}
rider.B.UpdateTravelPace()
check(rider.B.TravelSpeed()==14,"Spellbook fallback checks highest learned riding tier first")
rider.env.C_SpellBook.IsSpellKnown=function(id) return id==33388 end;rider.B.UpdateTravelPace()
check(rider.B.TravelSpeed()==11.2,"Spellbook apprentice fallback selects 60%")
rider.env.C_SpellBook=nil;rider.env.IsPlayerSpell=function(id) return id==33391 end;rider.B.UpdateTravelPace()
check(rider.B.TravelSpeed()==14,"Legacy player-spell fallback works")
rider.env.IsPlayerSpell=nil;rider.env.IsSpellKnown=function(id) return id==33388 end;rider.B.UpdateTravelPace()
check(rider.B.TravelSpeed()==11.2,"Legacy known-spell fallback works")
rider.env.IsSpellKnown=nil;rider.B.UpdateTravelPace()
check(rider.B.TravelSpeed()==7 and not rider.B.ridingKnown,"Missing training APIs fall back to walking without guessing")
rider.env.C_SkillInfo={GetSkillLineInfoByID=function() return {skillID=762,rank={secret=true}} end}
rider.env.C_SpellBook={IsSpellKnown=function() return {secret=true} end};rider.B.UpdateTravelPace()
check(rider.B.TravelSpeed()==7 and not rider.B.ridingKnown,"Restricted training data cannot unlock a mount tier")
rider.env.C_SkillInfo.GetSkillLineInfoByID=function() error("not ready") end
rider.env.C_SpellBook.IsSpellKnown=function() error("not ready") end
check(pcall(rider.B.UpdateTravelPace) and rider.B.TravelSpeed()==7,"Unavailable APIs never abort addon loading")
local walker=client("Aldric","Stoneward")
local mounted=client("Elowen","Dawnwatch")
mounted.s.riding=150;mounted.B.UpdateTravelPace()
check(walker.B.TravelSpeed()==7 and mounted.B.TravelSpeed()==14,"Two characters use their own trained speeds")
local owner="elowen dawnwatch"
walker.B.session.beacons[owner]={owner=owner,name="Elowen Dawnwatch",id="riding-test",sent=walker.s.time,expires=walker.s.time+300,map=1429,px=.15,py=.46,reason="aid",responders={}}
walker.B.selected=owner;walker.B.Replan()
local footTime=walker.B.route.seconds
check(walker.B.route.speed==7 and #walker.B.route.steps==1,"Untrained local rescue plans a walking leg")
walker.B.navigating=true
walker.s.riding=75;walker.B.eventFrame.scripts.OnEvent(walker.B.eventFrame,"SKILL_LINES_CHANGED")
check(walker.B.route.speed==11.2 and math.abs(walker.B.route.seconds-footTime/1.6)<.001,"Learning 60% riding automatically shortens the ground ETA")
check(walker.B.navigating and walker.s.waypoint~=nil,"Training replans active guidance and updates the waypoint")
walker.s.riding=150;walker.B.eventFrame.scripts.OnEvent(walker.B.eventFrame,"SPELLS_CHANGED")
check(walker.B.route.speed==14 and math.abs(walker.B.route.seconds-footTime/2)<.001,"Learning 100% riding automatically halves walking time")
walker.B.ToggleTravelMode()
check(walker.B.route.speed==7 and walker.B.db.travelMode=="foot" and walker.B.navigating,"On-foot override replans an active mounted route")
walker.B.ToggleTravelMode()
check(walker.B.route.speed==14 and walker.B.db.travelMode=="auto","Auto restores the trained mount speed")
walker.s.taxi=true;walker.s.riding=75;walker.B.eventFrame.scripts.OnEvent(walker.B.eventFrame,"SKILL_LINES_CHANGED")
check(walker.B.route.pendingFlight,"Training while on a taxi waits for landing to replan")
local slowFlight=R.Plan(start,goal,{[2]=true,[5]=true},"A",11.2)
for _,step in ipairs(slowFlight.steps) do if step.kind=="flight" then
    for _,original in ipairs(known.steps) do if original.kind=="flight" and step.fromID==original.fromID and step.toID==original.toID then
        check(step.seconds==original.seconds,"Mount training does not accelerate flight travel")
    end end
end end

-- Optional messages, saved templates and mixed-version protocol delivery.
do
    local caller=client("Aldric","Stoneward")
    local ally=client("Elowen","Dawnwatch")
    local u=caller.B.UI
    caller.env.SlashCmdList.LIGHTTHEBEACONS("light")
    check(u.composer:IsShown() and #caller.s.sent==0,"Manual call opens a composer without broadcasting")
    check(u.messageEdit:GetText()=="" and u.messageEdit.focused,"Composer starts blank and accepts typing")
    local notes={"Three Horde at the cave. Need a healer!","Escort needed to the flight master.","Rally here. We ride together!"}
    for slot=1,3 do
        u.messageEdit:SetText(notes[slot]);u.templates[slot].save.scripts.OnClick()
    end
    check(#caller.B.db.messages==3 and #caller.s.sent==0,"Three quick messages save locally without sending")
    check(not caller.B.SaveTemplate(4,"Fourth") and not caller.B.SaveTemplate(1.5,"Fraction"),"Only the three integer slots are accepted")
    u.templates[1].use.scripts.OnClick()
    check(u.messageEdit:GetText()==notes[1] and #caller.s.sent==0,"Selecting a quick message fills the draft only")
    u.messageEdit:SetText("Two Horde at the cave. Need a healer!");u.templates[1].save.scripts.OnClick()
    notes[1]=u.messageEdit:GetText()
    check(caller.B.db.messages[1]==notes[1],"Saving an edited template replaces that slot")
    u.messageEdit.scripts.OnEnterPressed(u.messageEdit)
    check(#caller.s.sent==0 and not u.messageEdit.focused,"Enter finishes editing without accidentally lighting a beacon")
    u.composeCancel.scripts.OnClick()
    check(not u.composer:IsShown() and #caller.s.sent==0,"Cancelling a draft never broadcasts")
    caller.B.RequestLight();check(u.messageEdit:GetText()=="","A new manual call never reuses an abandoned draft")
    u.templates[1].use.scripts.OnClick();u.composeSend.scripts.OnClick()
    check(not u.composer:IsShown() and #caller.s.sent==2,"Send closes the composer and sends a note plus a normal beacon")
    local notePacket,basePacket=caller.s.sent[1][2],caller.s.sent[2][2]
    check(caller.s.sent[1][3]=="GUILD" and caller.s.sent[2][3]=="GUILD","Both message packets stay on the private guild addon channel")
    check(basePacket==P.Encode(caller.B.own) and select(2,basePacket:gsub("|",""))==7,"Beacon remains in the exact eight-field legacy format")
    ally.B.Receive(notePacket,caller.B.name,"WHISPER");ally.B.Receive(notePacket,"Outsider","GUILD")
    check(next(ally.B.session.pending)==nil,"Notes from other channels or non-guild members are ignored")
    ally.B.Receive(notePacket,caller.B.name,"GUILD")
    check(#ally.B.List()==0 and #ally.s.sounds==0 and not ally.B.UI.banner:IsShown(),"A note alone never creates a call, toast or horn")
    ally.B.Receive(basePacket,caller.B.name,"GUILD")
    check(ally.B.Selected().message==notes[1] and caller.B.own.message==notes[1],"Caller and ally retain the same message")
    check(ally.B.UI.callMessage:GetText()=='"'..notes[1]..'"' and ally.B.UI.alertMessage:GetText()=='"'..notes[1]..'"',"Ally sees the note in both caller card and alert")
    check(#ally.s.sounds==1 and ally.B.UI.banner:GetHeight()==158,"A message-bearing call plays one horn and makes room in the toast")
    ally.B.Receive(notePacket,caller.B.name,"GUILD");ally.B.Receive(basePacket,caller.B.name,"GUILD")
    check(#ally.s.sounds==1,"Duplicate notes and beacons do not replay the horn")
    local reordered=client("Elowen","Dawnwatch")
    reordered.B.Receive(basePacket,caller.B.name,"GUILD");reordered.B.UI.banner.elapsed=8
    reordered.B.Receive(notePacket,caller.B.name,"GUILD")
    check(reordered.B.Selected().message==notes[1] and reordered.B.UI.alertMessage:GetText()=='"'..notes[1]..'"',"A late note updates an already received beacon")
    check(#reordered.s.sounds==1 and reordered.B.UI.banner.elapsed==8,"Late note never resets the banner timer or sounds again")
    reordered.B.UI.banner:Hide();reordered.B.Receive(notePacket,caller.B.name,"GUILD")
    check(not reordered.B.UI.banner:IsShown(),"Late duplicate does not reopen a dismissed alert")
    local spoof=client("Elowen","Dawnwatch")
    spoof.B.Receive(basePacket,caller.B.name,"GUILD");spoof.B.Receive(notePacket,spoof.B.name,"GUILD")
    check(not spoof.B.Selected().message,"A guildmate cannot attach a note to someone else's beacon ID")
    local restored=client("Aldric","Stoneward",caller.B.db,caller.s.time)
    check(restored.B.own.message==notes[1] and restored.B.db.messages[3]==notes[3],"Active note and three saved templates survive reload")
    restored.B.Receive("1|Q",ally.B.name,"GUILD")
    check(#restored.s.sent==2 and restored.s.sent[1][2]==notePacket and restored.s.sent[2][2]==basePacket,"Reloaded caller includes the message when a late guildmate queries active calls")
    check(next(ally.B.db.messages)==nil,"Templates are private to the sender's character")
    restored.B.UI.Compose();restored.B.UI.templates[2].clear.scripts.OnClick()
    local cleared=client("Aldric","Stoneward",restored.B.db,restored.s.time)
    check(cleared.B.db.messages[1]==notes[1] and not cleared.B.db.messages[2] and cleared.B.db.messages[3]==notes[3],"Clearing one template preserves the other two across reloads")
    local badSave=client("Aldric","Stoneward",{messages={[1]={secret=true},[2]="ok",[3]="",[4]="extra",garbage="extra"}})
    check(not badSave.B.db.messages[1] and badSave.B.db.messages[2]=="ok" and not badSave.B.db.messages[4] and not badSave.B.db.messages.garbage,"Saved template migration discards malformed values and extra slots")
    local failed=client("Aldric","Stoneward");failed.B.RequestLight();failed.B.UI.messageEdit:SetText(notes[1]);failed.s.sendResult=3
    failed.B.UI.composeSend.scripts.OnClick()
    check(failed.B.UI.composer:IsShown() and failed.B.UI.messageEdit:GetText()==notes[1] and not failed.B.own,"Failed sends keep the typed draft for retry")
    local failedBase=client("Aldric","Stoneward")
    local sendCount=0;failedBase.env.C_ChatInfo.SendAddonMessage=function() sendCount=sendCount+1;return sendCount==1 and 0 or 3 end
    check(not failedBase.B.Light(nil,notes[1]) and not failedBase.B.own and not failedBase.B.db.lastSent,"A note sent before a failed beacon never marks a call as successful")
    local abandoned=client("Elowen","Dawnwatch")
    abandoned.B.Receive(notePacket,caller.B.name,"GUILD");abandoned.advance(16)
    abandoned.B.Protocol.Prune(abandoned.B.session,abandoned.s.time)
    check(next(abandoned.B.session.pending)==nil,"Orphaned notes expire promptly")
    local cancelled=client("Elowen","Dawnwatch")
    cancelled.B.Receive(notePacket,caller.B.name,"GUILD")
    cancelled.B.Receive("1|C|"..caller.B.own.id,caller.B.name,"GUILD")
    cancelled.B.Receive(notePacket,caller.B.name,"GUILD");cancelled.B.Receive(basePacket,caller.B.name,"GUILD")
    check(next(cancelled.B.session.pending)==nil and #cancelled.B.List()==0,"Cancellation discards pending messages and blocks delayed resurrection")
    local auto=client("Aldric","Stoneward",{auto=true,messages=notes});auto.B.RequestLight();auto.B.UI.messageEdit:SetText("Do not send this draft")
    auto.s.dead=true;auto.s.recapLink="new";auto.s.recap={{sourceGUID="Player-2-enemy",sourceFlags=0x440,overkill=1,timeBeforeDeath=0}}
    auto.B.Death();auto.advance(1)
    check(auto.B.own.reason=="pvp" and not auto.B.own.message and #auto.s.sent==1,"Automatic PvP calls bypass the composer and never send an old draft or template")
    check(not auto.B.UI.composer:IsShown(),"Automatic send dismisses a now-stale composer")
    local fallen=client("Aldric","Stoneward");fallen.B.Client.RememberAttacker("Player-2-00AA","Example Enemy",0x440,100)
    fallen.s.dead=true;fallen.B.Death();fallen.advance(1)
    fallen.B.UI.deathCall.scripts.OnClick();fallen.B.UI.messageEdit:SetText("Horde camping my body.")
    check(fallen.B.UI.composer:IsShown() and #fallen.s.sent==0,"Manual death prompt lets the caller add a message")
    fallen.B.UI.composeSend.scripts.OnClick()
    check(fallen.B.own.reason=="fallen" and fallen.B.own.message=="Horde camping my body.","Manual death call retains its reason and custom message")
    local blank=client("Aldric","Stoneward");blank.B.RequestLight();blank.B.UI.composeSend.scripts.OnClick()
    check(#blank.s.sent==1 and not blank.B.own.message and blank.B.UI.banner:GetHeight()==118,"Blank message remains optional and keeps the compact alert")
    local accent="\195\169";local emoji="\240\159\155\161"
    check(P.Message(string.rep(accent,49))==string.rep(accent,48),"Accented characters are limited by character count without splitting UTF-8")
    local unicode,count=P.Message(string.rep(emoji,49))
    local unicodePacket=P.EncodeMessage({id=string.rep("x",40),message=unicode})
    check(count==48 and #unicode==192 and #unicodePacket<=250 and P.Parse(unicodePacket,caller.s.time).message==unicode,"Maximum-width Unicode plus maximum ID stays within the addon-message limit")
    check(P.Message("  Hold\n the| bridge!  ")=="Hold the bridge!","Messages normalize whitespace and remove WoW markup/payload separators")
    check(P.Message({secret=true})=="" and P.Message("\255x\237\160\128")=="x","Restricted values and invalid Unicode cannot enter a message")
    for _,bad in ipairs({"1|M|id|", "1|M|id|"..string.rep("a",49),"1|M|id|a|b","1|M|id|\255","1|M|id|hi\nthere","1|M|id| leading"}) do
        check(not P.Parse(bad,caller.s.time),"Malformed, overlong or noncanonical note is rejected")
    end
    caller.B.RequestLight();u.messageEdit:SetText(string.rep(accent,50))
    check(u.messageEdit:GetText()==string.rep(accent,48) and u.messageCount:GetText()=="48 / 48","Composer enforces and displays the Unicode character limit")
    local bounded=P.NewSession();local members={}
    for i=1,90 do
        local sender="Guildmate"..i;members[P.Identity(sender)]=true
        P.Receive(bounded,"1|M|id|Help",sender,"GUILD",members,caller.s.time)
    end
    local n=0;for _ in pairs(bounded.pending) do n=n+1 end
    check(n==80,"Pending note storage is bounded across a large guild")
end

-- Own-call actions must never acknowledge or navigate back to the caller.
do
    local own=client("Aldric","Stoneward");own.B.Light()
    check(not own.B.UI.banner:IsShown() and own.B.UI.summary:GetText():find("Beacon lit"),"Own call confirms in the card without a popup")
    local sent=#own.s.sent
    own.B.UI.frame:Show();own.B.UI.light.scripts.OnClick()
    own.B.UI.Tick()
    check(not own.B.navigating and not own.B.UI.hud:IsShown() and not own.s.waypoint,"Viewing one's own card never starts route guidance or a waypoint")
    check(own.B.UI.frame:IsShown() and own.B.Selected()==own.B.own and #own.s.sent==sent,"Own card remains useful without sending a response")
    own.B.navigating=true;own.B.UI.hud:Show();own.B.Answer()
    check(not own.B.navigating and not own.B.UI.hud:IsShown() and next(own.B.own.responders)==nil,"Core guard rejects direct self-answer and clears stale guidance")
    own.B.Receive("1|R|"..own.B.own.id.."|"..own.B.me,own.B.name,"GUILD")
    check(next(own.B.own.responders)==nil,"Network self-response never counts as an ally")
    local helper=client("Elowen","Dawnwatch")
    helper.B.Receive(own.s.sent[1][2],own.B.name,"GUILD")
    helper.B.UI.banner.scripts.OnClick(helper.B.UI.banner,"LeftButton")
    check(helper.B.navigating and #helper.s.sent==1,"Other guildmates still answer from the alert")
    helper.B.Light()
    check(not helper.B.navigating and helper.B.selected==helper.B.me,"Lighting one's own call stops previous rescue guidance")
end
-- Sound kits can fail silently on Forever while their native assets play.
do
    local c=client("Aldric","Stoneward")
    c.env.C_Sound.PlaySound=function() error("Kit lookup should not run after successful direct playback") end
    check(c.B.Sound(true) and c.s.soundFiles[1][1]==566064,"Beacon plays the live-confirmed DwarfHorn FileDataID")
    check(c.B.Sound(true,true) and c.s.soundFiles[2][1]==569543,"Response fanfare uses its native file too")
    local count=#c.s.soundFiles;c.B.db.sound=false;c.B.Sound();c.B.Sound(false,true)
    check(#c.s.soundFiles==count,"Muted addon never plays either alert")
    c.B.Sound(true);check(#c.s.soundFiles==count+1,"Explicit sound test works when addon alerts are muted")
    local fallback=client("Aldric","Stoneward")
    fallback.env.PlaySoundFile=function() return nil end
    check(fallback.B.Sound(true) and fallback.s.sounds[1][1]==10843,"Sound-kit fallback remains available if direct file playback is unavailable")
    fallback.env.PlaySoundFile=nil;fallback.env.C_Sound=nil
    fallback.env.PlaySound=function(id) return id==10843,77 end
    check(fallback.B.Sound(true),"Older global sound API remains a guarded fallback")
    local failed=client("Aldric","Stoneward")
    failed.env.PlaySoundFile=function() return nil end;failed.env.C_Sound.PlaySound=function() return nil end
    check(failed.B.Sound(true)==false and failed.s.lastMessage:find("did not start"),"Nil/no-result playback is reported as failure rather than silently accepted")
    check(not failed.B.lastHorn,"Failed playback does not consume the successful-sound cooldown")
    failed.env.PlaySoundFile=function() error("Unavailable API") end
    check(pcall(failed.B.Sound,true),"Playback API errors cannot break beacon delivery")
    failed.env.PlaySoundFile=function() return {secret=true},42 end
    check(not failed.B.Sound(true),"Restricted playback results are not treated as success")
    failed.B.Print=function(s) failed.s.lastMessage=s end
    failed.env.GetCVar=function() return {secret=true} end
    failed.env.SlashCmdList.LIGHTTHEBEACONS("sound")
    check(failed.s.lastMessage:find("unknown"),"Sound diagnostics handle unavailable or restricted settings")
end

-- Exercise the compact card through its buttons, including private networking.
do
    local caller=client("Aldric","Stoneward")
    local helper=client("Elowen","Dawnwatch")
    local u=helper.B.UI
    helper.env.SlashCmdList.LIGHTTHEBEACONS("")
    check(u.frame:GetWidth()==400 and u.frame:GetHeight()<=190 and not u.details:IsShown(),"Rally card opens compact by default")
    check(u.answer.label:GetText()=="Light My Beacon" and not u.expand:IsShown(),"Quiet watch offers a call without empty route controls")
    check(u.credit.parent==u.optionsPanel and not u.optionsPanel:IsShown(),"Credit belongs exclusively to hidden settings")
    u.answer.scripts.OnClick()
    check(u.composer:IsShown() and #helper.s.sent==0,"Idle primary action opens a draft without broadcasting")
    u.composeCancel.scripts.OnClick()
    caller.B.Light(nil,"Need a healer at the bridge!")
    for _,packet in ipairs(caller.s.sent) do helper.B.Receive(packet[2],caller.B.name,"GUILD") end
    local collapsed=u.frame:GetHeight()
    check(collapsed<=190 and u.callMessage:IsShown() and not u.brief:IsShown(),"Incoming call fits the compact card with its message")
    u.expand.scripts.OnClick()
    check(u.details:IsShown() and u.frame:GetHeight()>collapsed and #helper.s.sent==0 and not helper.s.waypoint,"Expanding reveals details without answering or changing a waypoint")
    u.map.scripts.OnClick()
    check(helper.s.mapOpened==caller.B.own.map and #helper.s.sent==0,"Details map action opens the incident map without answering")
    u.expand.scripts.OnClick()
    check(not u.details:IsShown() and u.frame:GetHeight()==collapsed,"Collapsing restores the compact size")
    u.answer.scripts.OnClick()
    check(helper.B.navigating and u.brief:IsShown() and u.briefText:GetText():find("Next:"),"Answer adds current-step guidance even while details are collapsed")
    check(#helper.s.sent==1 and not u.answer.enabled and u.answer.label:GetText()=="On my way","Answer sends exactly one private response and disables repeat clicks")
    u.expand.scripts.OnClick();u.stop.scripts.OnClick()
    check(not helper.B.navigating and not u.brief:IsShown() and not u.hud:IsShown() and u.answer.label:GetText()=="Resume route","Stop guidance leaves an answered call available to resume")
    u.answer.scripts.OnClick()
    check(helper.B.navigating and #helper.s.sent==1,"Resuming does not send another acknowledgement")
    u.optionsButton.scripts.OnClick()
    check(u.optionsPanel:IsShown() and not u.main:IsShown() and u.frame:GetHeight()==638,"Options replaces the compact contents and reveals the credit")
    u.optionsButton.scripts.OnClick()
    check(u.main:IsShown() and not u.optionsPanel:IsShown() and u.details:IsShown(),"Back restores the expanded card without resetting its state")
    helper.B.db.combineBeacons=false;helper.B.Light()
    check(u.answer.label:GetText()=="Extinguish My Beacon" and not u.eta:IsShown() and not u.routeScroll:IsShown() and not u.brief:IsShown(),"Own card exposes extinguish, with no rescue route or ETA to oneself")
    check(u.pager:IsShown() and u.position:GetText():find("2 beacons"),"Two beacons expose a compact call pager")
    local own=helper.B.own;u.nextCall.scripts.OnClick()
    check(helper.B.Selected().owner~=helper.B.me and u.eta:IsShown(),"Pager switches to the other caller")
    u.light.scripts.OnClick()
    check(helper.B.Selected()==own and not helper.B.navigating,"Header's My beacon action returns to own call without navigation")
    local sent=#helper.s.sent;u.answer.scripts.OnClick()
    check(not helper.B.own and #helper.s.sent==sent+1 and helper.s.sent[#helper.s.sent][2]:find('^1|C|'),"Own primary action sends cancellation, never a response")
    check(not u.pager:IsShown(),"Pager disappears when only one call remains")
    helper.B.route={steps={},unavailable=true,pendingFlight=true,reason="Your route will update when you land."};u.Refresh()
    check(u.eta:GetText()=="On taxi" and u.empty:GetText():find("when you land"),"Pending flight state stays understandable in both views")
    helper.B.route={steps={},unavailable=true,reason="This map is unsupported."};u.Refresh()
    check(u.eta:GetText()=="No route" and u.empty:GetText()=="This map is unsupported.","Unsupported route retains the map fallback in details")
    helper.env.SlashCmdList.LIGHTTHEBEACONS("options")
    local before=#helper.s.sent;u.expanded=false;helper.B.Preview()
    check(helper.B.preview and not u.options and u.main:IsShown() and not u.details:IsShown() and not u.answer.enabled,"Internal render fixture opens a clearly marked compact sample without actionable answers")
    check(#helper.s.sent==before and u.summary:GetText():find("PREVIEW"),"Preview stays private and visibly identified")
    local step=helper.B.route.steps[1];helper.B.route.steps={}
    for i=1,8 do helper.B.route.steps[i]=step end
    u.expanded=true;u.Refresh();u.routeScroll.scripts.OnMouseWheel(u.routeScroll,-100)
    check(u.routeScroll:GetHeight()==144 and u.routeScroll:GetVerticalScroll()==240 and u.frame:GetHeight()<600,"Long routes scroll within a bounded expanded card")
    local selected=helper.B.preview;selected.message=string.rep("W",48);u.Refresh()
    check(u.callMessage:GetText()=='"'..selected.message..'"' and u.callMessage.nonSpaceWrap,"Maximum-length unbroken messages remain wrapped, not truncated by protocol")
    local fresh=client("Aldric","Stoneward",helper.B.db)
    check(not fresh.B.UI.expanded and fresh.B.UI.frame:GetWidth()==400,"Reload starts compact while preserving character saves")
end

-- Own confirmation, non-overlapping notifications, floating control, player filters.
do
    local c=client("Aldric","Stoneward");local u=c.B.UI
    c.B.RequestLight();u.messageEdit:SetText("Rally here");u.composeSend.scripts.OnClick()
    check(u.frame:IsShown() and not u.banner:IsShown() and u.summary:GetText():find("Beacon lit"),"Manual light confirms inside the card, never in an own-call popup")
    local helper=client("Elowen","Dawnwatch");helper.s.pos.px=.3;helper.B.Light()
    local packet=helper.s.sent[#helper.s.sent][2];c.B.Receive(packet,helper.B.name,"GUILD")
    check(u.banner:IsShown(),"An ally call still shows the incoming alert")
    u.Answered("Elowen Dawnwatch",1,true,c.B.own)
    check(u.answerBanner:IsShown() and not u.banner:IsShown() and u.pendingAlert,"First responder celebration suspends an incoming alert")
    u.Alert(c.B.session.beacons[helper.B.me])
    check(not u.banner:IsShown(),"An incoming call cannot overlap an active rally")
    u.answerBanner:Hide()
    check(u.banner:IsShown() and not u.pendingAlert,"Pending ally alert resumes after the celebration")
    u.Answered("Elowen Dawnwatch",1,true,c.B.own)
    c.B.SetPlayerFilter(helper.B.name,"silent",false);u.answerBanner:Hide()
    check(not u.banner:IsShown(),"Muting a queued caller prevents the queued popup from resurfacing")
    c.B.SetPlayerFilter(helper.B.name,"hidden",false)
    check(#c.B.List()==1 and c.B.List()[1].owner==c.B.me,"Hidden beacon is removed from the call list while own remains")
    c.B.SetPlayerFilter(helper.B.name,"normal",false);c.B.Select(c.B.session.beacons[helper.B.me]);c.B.Answer()
    c.B.SetPlayerFilter(helper.B.name,"hidden",false)
    check(not c.B.navigating and not u.hud:IsShown() and c.B.Selected().owner~=helper.B.me,"Hiding the followed caller stops their route and selects a visible call")
    c.B.RemovePlayerFilter(helper.B.me)
    check(#c.B.List()==2,"Removing a filter restores an active call without another horn")
    check(not c.B.SetPlayerFilter(c.B.name,"hidden",true) and not c.B.SetPlayerFilter("Bad|Name","silent",false),"Filters reject self and markup-containing names")
    local silent=client("Aldric","Stoneward");silent.B.SetPlayerFilter(" Elowen   Dawnwatch ","silent",false)
    silent.B.Receive(packet,helper.B.name,"GUILD")
    check(#silent.B.List()==1 and not silent.B.UI.banner:IsShown() and #silent.s.sounds==0,"Silence matches the canonical full name and keeps a quiet call")
    silent.B.SetPlayerFilter(helper.B.name,"hidden",true)
    local reload=client("Aldric","Stoneward",silent.B.db)
    check(reload.B.Filter(helper.B.me).beacons=="hidden" and reload.B.Filter(helper.B.me).hideLocation,"Player filter modes survive reload")
    local fresh=client("Aldric","Stoneward");local f=fresh.B.UI.floating
    check(f:IsShown() and fresh.B.db.floatingButton,"Floating beacon control is enabled by default")
    fresh.env.SlashCmdList.LIGHTTHEBEACONS("button")
    local hidden=client("Aldric","Stoneward",fresh.B.db)
    check(not f:IsShown() and not hidden.B.UI.floating:IsShown() and not hidden.B.db.floatingButton,"An explicit hidden-button preference survives reload")
    fresh.env.SlashCmdList.LIGHTTHEBEACONS("button")
    check(f:IsShown() and f.label:GetText()=="Light" and f.icon.desaturated,"Floating button is visible and clearly unlit when enabled")
    fresh.s.shift=true;f.scripts.OnDragStart(f);f.centerX=360;f.centerY=250;f.scripts.OnDragStop(f);fresh.s.shift=false
    f.scripts.OnClick(f,"LeftButton")
    check(#fresh.s.sent==0 and fresh.B.db.buttonPosition.x==.25 and fresh.B.db.buttonPosition.y==.25,"Shift-drag saves normalized position and never ignites on release")
    fresh.advance(1);f.scripts.OnClick(f,"LeftButton")
    check(fresh.B.own and f.label:GetText()=="Lit" and not f.icon.desaturated and not fresh.B.UI.frame:IsShown() and not fresh.B.UI.banner:IsShown(),"One-click ignition stays compact and confirms on the lit icon")
    f.scripts.OnClick(f,"RightButton")
    check(fresh.B.UI.frame:IsShown() and fresh.B.Selected()==fresh.B.own,"Right-click opens the full own-beacon card")
    f.scripts.OnClick(f,"LeftButton")
    check(not fresh.B.own and f.icon.desaturated and f.label:GetText():find("s") and fresh.B.UI.summary:GetText()=="Beacon extinguished","Extinguish updates the icon, cooldown and card confirmation")
    local saved=client("Aldric","Stoneward",fresh.B.db)
    check(saved.B.UI.floating:IsShown() and saved.B.db.buttonPosition.x==.25 and saved.B.UI.floating.anchor[4]==360,"Floating visibility and placement survive reload")
    saved.B.UI.OpenSettingsPage("controls");saved.B.UI.resetFloating.scripts.OnClick()
    check(not saved.B.db.buttonPosition and saved.B.UI.floating.anchor[1]=="TOPRIGHT","Reset returns the floating button to its default anchor")
end

-- Private periodic positions, consent withdrawal, world-map projection and filters.
do
    local sender=client("Aldric","Stoneward");local viewer=client("Elowen","Dawnwatch")
    local function locationPacket(c)
        c.B.lastLocationAttempt=nil;c.B.BroadcastLocation();return c.s.sent[#c.s.sent][2]
    end
    local packet=locationPacket(sender)
    check(packet:find('^1|L|') and not sender.B.own and sender.B.db.shareLocation,"Default sharing works without a lit beacon")
    viewer.B.Receive(packet,sender.B.name,"WHISPER");viewer.B.Receive(packet,"Stranger","GUILD")
    check(#viewer.B.Locations()==0,"Position sharing accepts only guild-addon traffic from roster members")
    viewer.B.Receive(packet,sender.B.name,"GUILD")
    check(#viewer.B.Locations()==1 and #viewer.B.List()==0 and not viewer.B.UI.banner:IsShown() and #viewer.s.sounds==0,"Locations never create beacons, horns or popup alerts")
    local sent=#sender.s.sent;sender.B.BroadcastLocation()
    check(#sender.s.sent==sent,"Position heartbeats are rate-limited to one every ten seconds")
    sender.advance(10);sender.s.pos.px=.7;sender.B.BroadcastLocation();packet=sender.s.sent[#sender.s.sent][2]
    viewer.advance(10);viewer.B.Receive(packet,sender.B.name,"GUILD")
    check(viewer.B.Locations()[1].px==.7,"A new heartbeat updates the live marker position")
    sender.B.ShareLocation(false);local withdraw=sender.s.sent[#sender.s.sent][2];viewer.B.Receive(withdraw,sender.B.name,"GUILD")
    check(withdraw:find('^1|H|') and #viewer.B.Locations()==0,"Opt-out immediately withdraws the remote marker")
    viewer.B.Receive(packet,sender.B.name,"GUILD")
    check(#viewer.B.Locations()==0,"An in-flight location from the same second cannot undo a privacy withdrawal")
    sent=#sender.s.sent;sender.advance(15);sender.B.BroadcastLocation()
    check(#sender.s.sent==sent,"Disabled sharing stops future location heartbeats")
    local restored=client("Aldric","Stoneward",sender.B.db)
    check(not restored.B.db.shareLocation,"Opt-out survives reload and character saves")
    sender.B.ShareLocation(true);viewer.advance(15);packet=sender.s.sent[#sender.s.sent][2];viewer.B.Receive(packet,sender.B.name,"GUILD")
    check(#viewer.B.Locations()==1,"Turning sharing back on publishes a fresh position")
    viewer.B.SetPlayerFilter(sender.B.name,"hidden",false)
    check(#viewer.B.Locations()==1,"Hiding someone's beacons does not silently hide their separate location")
    viewer.B.SetPlayerFilter(sender.B.name,"normal",true)
    check(#viewer.B.Locations()==0,"Individual location filter hides the marker independently of beacon mode")
    viewer.B.RemovePlayerFilter(sender.B.me);viewer.B.db.showLocations=false
    check(#viewer.B.Locations()==0 and viewer.B.db.shareLocation,"Hide-all map display is independent of one's own sharing consent")
    viewer.B.db.showLocations=true
    local env=viewer.env;local world=env.CreateFrame("Frame","WorldMapFrame",env.UIParent);env.WorldMapFrame=world;world:SetSize(900,600)
    local canvas=env.CreateFrame("Frame",nil,world);canvas:SetSize(900,600);canvas:SetAllPoints(world)
    viewer.s.worldMapID=947;world.GetCanvas=function() return canvas end;world.GetMapID=function() return viewer.s.worldMapID end
    world.SetMapID=function(_,id) viewer.s.worldMapID=id end
    viewer.B.UI.MapPins()
    local pin=viewer.B.UI.locationPins[1]
    check(pin and pin:IsShown() and pin.location.owner==sender.B.me,"Guildmate marker appears on the full Azeroth world map")
    local p=viewer.B.Locations()[1];local id,cx,cy=viewer.B.Client.MapPoint(p,1415);local wid,wx,wy=viewer.B.Client.MapPoint(p,947)
    check(id==1415 and wid==947 and math.abs(wx-(.55+cx*.4))<1e-8 and math.abs(wy-(.15+cy*.7))<1e-8,"Continent-to-world placement uses the client's atlas rectangles")
    world:SetMapID(1429)
    check(pin:IsShown() and math.abs(pin.anchor[4]-.7*900)<.01,"Zooming to the zone immediately repositions the marker")
    world:SetMapID(1414)
    check(not pin:IsShown(),"Eastern Kingdoms marker is absent on the unrelated Kalimdor map")
    world:SetMapID(947)
    check(pin:IsShown(),"Zooming back out immediately restores the world marker")
    viewer.B.SetPlayerFilter(sender.B.name,"normal",true)
    check(not pin:IsShown(),"Changing a player location filter immediately removes an already visible pin")
    viewer.B.RemovePlayerFilter(sender.B.me)
    local savedWorld=env.C_Map.GetWorldPosFromMapPos;env.C_Map.GetWorldPosFromMapPos=nil
    local fallback,x,y=viewer.B.Client.MapPoint(p,947)
    check(fallback==947 and math.abs(x-wx)<1e-8 and math.abs(y-wy)<1e-8,"World markers still use the map hierarchy when world-coordinate conversion is unavailable")
    env.C_Map.GetWorldPosFromMapPos=savedWorld
    local kalimdor={map=1446,px=.4,py=.3};local kid,kx,ky=viewer.B.Client.MapPoint(kalimdor,947)
    check(kid==947 and kx<.5 and ky>=0 and ky<=1,"Kalimdor zones project into their side of the world atlas")
    local rect=env.C_Map.GetMapRectOnMap;env.C_Map.GetMapRectOnMap=function() return nil end
    check(viewer.B.Client.MapPoint(p,947)==nil,"Missing map transforms never invent a world-marker position")
    env.C_Map.GetMapRectOnMap=rect
    local before=#viewer.s.sent;pin.scripts.OnClick(pin,"RightButton")
    check(viewer.B.UI.filtersPanel:IsShown() and viewer.B.UI.filterName:GetText()==sender.B.name and #viewer.s.sent==before,"Right-click a marker opens that player's local filter setup")
    viewer.B.UI.addFilter.scripts.OnClick();viewer.B.UI.filterRows[1].mode.scripts.OnClick()
    check(viewer.B.BeaconMode(sender.B.me)=="silent","Player filter controls switch the stored beacon mode")
    viewer.B.UI.filterRows[1].location:SetChecked(true);viewer.B.UI.filterRows[1].location.scripts.OnClick(viewer.B.UI.filterRows[1].location)
    check(viewer.B.Filter(sender.B.me).hideLocation and not pin:IsShown(),"Player filter checkbox controls marker visibility")
    viewer.B.RemovePlayerFilter(sender.B.me);viewer.advance(46);viewer.B.Protocol.Prune(viewer.B.session,viewer.B.Client.Now());viewer.B.UI.MapPins()
    check(#viewer.B.Locations()==0 and not pin:IsShown(),"Offline/stale locations expire and disappear without a new packet")
    local failed=client("Aldric","Stoneward");failed.s.sendResult=3;failed.B.ShareLocation(false)
    check(not failed.B.db.shareLocation and failed.B.locationWithdrawPending,"A throttled privacy withdrawal disables sharing immediately and queues a retry")
    failed.s.sendResult=0;failed.advance(2);failed.B.BroadcastLocation()
    check(not failed.B.locationWithdrawPending and failed.s.sent[#failed.s.sent][2]:find('^1|H|'),"Privacy withdrawal retries without leaking another location")
    local missing=client("Aldric","Stoneward");missing.env.C_Map.GetPlayerMapPosition=function() return nil end
    check(locationPacket(missing):find('^1|H|'),"Unreadable positions withdraw stale coordinates instead of rebroadcasting them")
    local parser=viewer.B.Protocol
    for _,bad in ipairs({"1|L|"..viewer.s.time.."|1429|1.1|0.2","1|L|"..viewer.s.time.."|1429|0.1|nan","1|H|"..viewer.s.time.."|someone", "1|L|"..(viewer.s.time-46).."|1429|0.2|0.3"}) do
        check(not parser.Parse(bad,viewer.s.time),"Malformed/stale location packets are rejected")
    end
end

-- Global alert mute and private Friends map filtering remain independent of sharing.
do
    local caller=client("Aldric","Stoneward");local viewer=client("Elowen","Dawnwatch")
    local b,u=viewer.B,viewer.B.UI
    check(not b.db.muteBeacons and not b.db.friendsOnly,"Existing alert and all-guild map defaults remain unchanged")
    local overlap=client("Aldric","Stoneward");local handle=60
    overlap.env.PlaySoundFile=function() handle=handle+1;return true,handle end
    overlap.B.Sound(true);overlap.B.Sound(true);overlap.B.MuteBeacons(true)
    check(overlap.s.stoppedSounds[61] and overlap.s.stoppedSounds[62],"Global mute stops overlapping addon sounds, not just the last horn")
    caller.s.pos.px=.3;caller.B.Light();local packet=caller.s.sent[#caller.s.sent][2]
    b.Receive(packet,caller.B.name,"GUILD");u.Answered(caller.B.name,1,true,nil)
    u.PromptDeath(false)
    local sent=#viewer.s.sent;u.mute:SetChecked(true);u.mute.scripts.OnClick(u.mute)
    check(not u.banner:IsShown() and not u.answerBanner:IsShown() and not u.deathPrompt:IsShown() and not u.pendingAlert,"Global mute dismisses current popups and queued notifications")
    check(viewer.s.stoppedSound==42 and #viewer.s.sent==sent,"Global mute stops the addon's sound handle without broadcasting a setting")
    local soundCount=#viewer.s.sounds
    b.Light();local own=b.own
    caller.B.Receive(viewer.s.sent[#viewer.s.sent][2],b.name,"GUILD")
    caller.B.Select(caller.B.session.beacons[b.me]);caller.B.Answer()
    b.Receive(caller.s.sent[#caller.s.sent][2],caller.B.name,"GUILD")
    u.PromptDeath(false)
    check(#viewer.s.sounds==soundCount and not u.answerBanner:IsShown() and not u.deathPrompt:IsShown(),"Muted own calls and responses cannot play sounds or show rallies/death prompts")
    check(own.responders[caller.B.me] and b.db.answeredBeaconID==own.id,"Muted responses still update the caller's ally count and duplicate tracking")
    caller.advance(61);viewer.advance(61);caller.B.Light();b.Receive(caller.s.sent[#caller.s.sent][2],caller.B.name,"GUILD")
    check(#b.List()==2 and not u.banner:IsShown() and #viewer.s.sounds==soundCount,"New guild calls remain available quietly under global mute")
    caller.B.BroadcastLocation();b.Receive(caller.s.sent[#caller.s.sent][2],caller.B.name,"GUILD")
    b.BroadcastLocation()
    check(#b.Locations()==1 and viewer.s.sent[#viewer.s.sent][2]:find('^1|L|'),"Muted clients still share and receive live guild locations")
    local restored=client("Elowen","Dawnwatch",b.db)
    check(restored.B.db.muteBeacons and restored.B.db.shareLocation and restored.B.db.sound,"Global mute survives reload without overwriting sharing or sound preferences")
    b.MuteBeacons(false);u.answerBanner:Hide()
    check(not u.banner:IsShown() and not u.pendingAlert,"Unmuting never replays dismissed or queued calls")
    b.MuteBeacons(true);b.Sound(true);u.Answered("Preview",1,true,nil,true)
    check(#viewer.s.sounds==soundCount+1 and u.answerBanner:IsShown(),"Internal render fixtures can simulate sounds and celebrations while live alerts are muted")
    b.MuteBeacons(true)
    local before=#viewer.s.sent
    b.SetPlayerFilter(caller.B.name,"silent",true);b.SetFriend("  Aldric   Stoneward  ",true)
    check(b.IsFriend(caller.B.me) and b.Filter(caller.B.me).hideLocation and b.BeaconMode(caller.B.me)=="silent","Friend marking normalizes names and preserves existing beacon/location filters")
    b.SetPlayerFilter(caller.B.name,"hidden",false)
    check(b.IsFriend(caller.B.me),"Editing ordinary filters preserves the Friend mark")
    b.SetPlayerFilter(caller.B.name,"normal",false)
    local env=viewer.env;local world=env.CreateFrame("Frame","WorldMapFrame",env.UIParent);env.WorldMapFrame=world
    local canvas=env.CreateFrame("Frame",nil,world);canvas:SetSize(900,600)
    world.GetCanvas=function() return canvas end;world.GetMapID=function() return 947 end
    world.SetMapID=function() end
    u.OpenSettingsPage("controls");u.friendsOnly:SetChecked(true);u.friendsOnly.scripts.OnClick(u.friendsOnly)
    check(b.db.friendsOnly and #b.Locations()==1 and u.locationPins[1]:IsShown(),"Friends-only control shows a marked friend's world-map location")
    local icon=u.locationPins[1].icon
    check(icon.file==b.MediaPaths.AllianceShield and icon.coords[1]==.125 and icon.coords[2]==.875 and icon.width==13.5 and icon.height==18,"Friends use the approved native Alliance shield with the reviewed crop and aspect ratio")
    b.SetFriend(caller.B.name,false)
    check(#b.Locations()==0 and not u.locationPins[1]:IsShown(),"Removing Friend status immediately hides a location while filtering")
    local function shownBeacons() local n=0;for _,pin in ipairs(u.pins) do if pin:IsShown() then n=n+1;check(pin.beacon.owner==b.me,"Own beacon remains visible under the Friends-only filter") end end;return n end
    check(shownBeacons()==1 and #b.List()==2,"Friends-only also filters non-friend beacon pins but keeps own pin and call list")
    u.OpenSettingsPage("filters");local row=u.filterRows[1];row.friend:SetChecked(true);row.friend.scripts.OnClick(row.friend)
    check(b.IsFriend(caller.B.me) and #b.Locations()==1 and u.locationPins[1]:IsShown(),"Friend checkbox immediately restores the filtered marker")
    check(u.locationPins[1].icon==icon and icon.file==b.MediaPaths.AllianceShield,"Reused map pins restore the Friend's shield immediately")
    for _,pin in ipairs(u.pins) do
        if pin:IsShown() then check(pin.NormalTexture.file==b.MediaPaths.RoyalBrazier,"Friend status leaves active beacon brazier markers unchanged") end
    end
    b.SetPlayerFilter(caller.B.name,"silent",true)
    check(#b.Locations()==0,"Individual Hide location still wins for a marked Friend")
    b.SetPlayerFilter(caller.B.name,"silent",false);b.db.showLocations=false
    check(#b.Locations()==0,"Hide all locations still wins over Friends-only")
    b.db.showLocations=true
    local reload=client("Elowen","Dawnwatch",b.db)
    check(reload.B.db.friendsOnly and reload.B.IsFriend(caller.B.me) and reload.B.BeaconMode(caller.B.me)=="silent","Friends, map filtering and prior per-player settings survive reload")
    check(#viewer.s.sent==before,"Friend and map display choices never transmit names or settings")
    b.RemovePlayerFilter(caller.B.me)
    check(not b.IsFriend(caller.B.me) and #b.Locations()==0,"Removing the player row clears its Friend mark too")
    check(not b.SetFriend(b.name,true) and not b.SetFriend("Bad|Name",true),"Friend marking rejects self and malformed names")
    b.db.friendsOnly=false
    check(#b.Locations()==1,"Disabling Friends-only restores normal guild map visibility")
    u.MapPins()
    check(u.locationPins[1].icon==icon and icon.file==b.MediaPaths.AllianceCrest and icon.coords[1]==.175 and icon.coords[2]==.825 and icon.width==15 and icon.height==18 and icon.anchor[4]==0,"Unmarking a Friend resets the reused pin to the original guildmate lion and geometry")
end

local perf=os.clock()
local allKnown={};for id in pairs(data.nodes) do allKnown[id]=true end
for _=1,50 do R.Plan(start,{c=1,x=6400,y=700},allKnown,"A",14) end
check(os.clock()-perf<2,"Bounded route planner performance")
-- Render preview with a full Forever character name, not a short placeholder.
preview.B.preview.name="Aldric Stoneward";preview.B.preview.point.n="Aldric Stoneward's beacon"
preview.B.preview.responders.other="Elowen Dawnwatch"
preview.B.preview.route=preview.B.Routing.Plan({c=0,x=-8900,y=600},preview.B.preview.point,{[2]=true,[5]=true},"A",7)
preview.B.route=preview.B.preview.route;preview.B.UI.Alert(preview.B.preview,true);preview.B.UI.Refresh()
-- Representative sample data for rendering the actual native UI.
local sample={name="Example Ally",owner="example ally",id="design-preview",sent=preview.B.Client.Now()-43,
    expires=preview.B.Client.Now()+257,map=1446,px=.47,py=.50,reason="aid",message="Three Horde at the cave. Need a healer!",
    point={c=1,x=-7224,y=-3734,n="Example Ally's beacon"},
    responders={one="Sample Scout",two="Sample Healer"}}
preview.B.preview=nil;preview.B.session.beacons={[sample.owner]=sample};preview.B.selected=sample.owner
preview.B.db.known={[80]=true,[32]=true};preview.B.db.flightMasterScanned=true
preview.B.route=preview.B.Routing.Plan(preview.B.TravelData.nodes[80],sample.point,preview.B.db.known,"A",7)
preview.B.Client.Zone=function() return "Tanaris" end
preview.B.UI.Alert(sample);preview.B.UI.Refresh()

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
            frameLevel=o.frameLevel,layer=o.layer,text=o.text,fontSize=o.fontSize,font=o.font,color=o.color,align=o.align,
            wrap=o.wrap,nonSpaceWrap=o.nonSpaceWrap,file=o.file,coords=o.coords,solid=o.solid,alpha=o.alpha,desaturated=o.desaturated,vertexColor=o.vertexColor,backdrop=o.backdrop,
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
assert(loadfile("tests/pve-death-guards.lua"))(client,check)
local groupPreview=assert(loadfile("tests/beacon-settings.lua"))(client,check)
assert(loadfile("tests/chat-notices.lua"))(client,check)
local grudgePreview=assert(loadfile("tests/grudges.lua"))(client,check)
local deathPreview=assert(loadfile("tests/grudge-deaths.lua"))(client,check)
local combinedPreview=assert(loadfile("tests/combined-death.lua"))(client,check)
assert(loadfile("tests/death-instance-guards.lua"))(client,check)
local nativePreview=assert(loadfile("tests/death-reliability.lua"))(client,check)
-- Optional pinned Blizzard source is kept outside the repo and addon package.
if arg[3] and arg[3]~="" then assert(loadfile("tests/native-death-contract.lua"))(client,check,arg[3]) end
if arg[2] and arg[2]~="" then
    groupPreview.B.db.combineBeacons=true;groupPreview.B.UI.expanded=true;groupPreview.B.UI.Refresh()
    for _,o in ipairs(groupPreview.objects) do o.box=nil end
    snapshot(groupPreview,groupPreview.B.UI.frame,arg[2].."-group.json")
    groupPreview.B.UI.OpenSettingsPage("beacons")
    for _,o in ipairs(groupPreview.objects) do o.box=nil end
    snapshot(groupPreview,groupPreview.B.UI.frame,arg[2].."-beacon-settings.json")
    snapshot(nativePreview,nativePreview.B.DeathUI.frame,arg[2].."-death-client-test.json")
    snapshot(combinedPreview.main,combinedPreview.main.B.DeathUI.frame,arg[2].."-combined-death.json")
    snapshot(combinedPreview.unknown,combinedPreview.unknown.B.DeathUI.frame,arg[2].."-combined-unknown.json")
    local replacement=assert(loadfile("tests/death-replacement-layout.lua"))(combinedPreview.main)
    for _,o in ipairs(replacement.objects) do o.box=nil end
    snapshot(replacement,replacement.B.DeathUI.frame,arg[2].."-death-replacement-proposal.json")
    snapshot(deathPreview,deathPreview.B.GrudgeUI.deathPrompt,arg[2].."-grudge-death.json")
    snapshot(grudgePreview,grudgePreview.B.GrudgeUI.frame,arg[2].."-grudges.json")
    grudgePreview.B.GrudgeUI.Turn(1)
    for _,o in ipairs(grudgePreview.objects) do o.box=nil end
    snapshot(grudgePreview,grudgePreview.B.GrudgeUI.frame,arg[2].."-grudges-avenged.json")
    grudgePreview.B.GrudgeUI.Mode("inscribe")
    for _,o in ipairs(grudgePreview.objects) do o.box=nil end
    snapshot(grudgePreview,grudgePreview.B.GrudgeUI.frame,arg[2].."-grudges-inscribe.json")
    grudgePreview.B.GrudgeUI.name:SetText("")
    for _,o in ipairs(grudgePreview.objects) do o.box=nil end
    snapshot(grudgePreview,grudgePreview.B.GrudgeUI.frame,arg[2].."-grudges-fields.json")
    grudgePreview.B.GrudgeUI.Mode("words")
    for _,o in ipairs(grudgePreview.objects) do o.box=nil end
    snapshot(grudgePreview,grudgePreview.B.GrudgeUI.frame,arg[2].."-grudges-phrases.json")
    grudgePreview.B.GrudgeUI.Mode("settings")
    for _,o in ipairs(grudgePreview.objects) do o.box=nil end
    snapshot(grudgePreview,grudgePreview.B.GrudgeUI.frame,arg[2].."-grudges-settings.json")
    local emptyBook=client("Sample","Scribe");emptyBook.B.GrudgeUI.Toggle(true)
    snapshot(emptyBook,emptyBook.B.GrudgeUI.frame,arg[2].."-grudges-empty.json")
    snapshot(preview,preview.B.UI.frame,arg[2].."-window.json")
    preview.B.UI.expanded=true;preview.B.UI.Refresh()
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.frame,arg[2].."-expanded.json")
    preview.B.navigating=true;preview.B.routeIndex=1;preview.B.UI.expanded=false;preview.B.UI.Refresh()
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.frame,arg[2].."-guidance.json")
    preview.B.navigating=false;preview.B.UI.Refresh()
    snapshot(preview,preview.B.UI.banner,arg[2].."-alert.json")
    preview.B.UI.Answered("Sample Scout",1,true,nil)
    snapshot(preview,preview.B.UI.answerBanner,arg[2].."-answer.json")
    preview.B.UI.options=true;preview.B.UI.Refresh()
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.frame,arg[2].."-options.json")
    preview.B.UI.OpenSettingsPage("chat")
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.frame,arg[2].."-chat.json")
    preview.B.UI.settingsPage=nil
    preview.B.db.messages={"Three Horde at the cave. Need a healer!","Escort needed to the flight master.","Rally here. We ride together!"}
    preview.B.UI.Compose();preview.B.UI.templates[1].use.scripts.OnClick()
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.composer,arg[2].."-composer.json")
    preview.B.UI.options=false;preview.B.UI.composer:Hide();sample.owner=preview.B.me;preview.B.session.beacons={[sample.owner]=sample};preview.B.selected=sample.owner
    preview.B.own=sample;preview.B.UI.expanded=true;preview.B.UI.Refresh()
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.frame,arg[2].."-own.json")
    preview.B.UI.OpenSettingsPage("controls")
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.frame,arg[2].."-controls.json")
    preview.B.SetPlayerFilter("Example Ally","silent",false)
    preview.B.SetPlayerFilter("Sample Scout","hidden",true)
    preview.B.SetFriend("Example Ally",true)
    preview.B.UI.OpenSettingsPage("filters")
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.frame,arg[2].."-filters.json")
    preview.B.db.floatingButton=true;preview.B.UI.RefreshFloating()
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.floating,arg[2].."-floating-lit.json")
    preview.B.own=nil;preview.B.UI.RefreshFloating()
    for _,o in ipairs(preview.objects) do o.box=nil end
    snapshot(preview,preview.B.UI.floating,arg[2].."-floating-idle.json")
end
print("Light the Beacons: "..total.." checks passed (protocol, routing, two clients, death detection, UI).")
