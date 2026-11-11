-- Run actual Blizzard DEATH handlers against simulated game APIs while LTB is
-- present. This tests Lua integration, not the client engine's secure execution.
-- Supply an external pinned GameDialogDefs.lua; never ship Blizzard source.
local client,check,path=...
local source=assert(io.open(path,"r"));local text=source:read("*a");source:close()
local body=assert(text:match('StaticPopupDialogs%["DEATH"%]%s*=%s*(%b{})'),"Missing Blizzard DEATH definition")
local c=client("Sample","Scribe");local env,D=c.env,c.B.DeathUI
local state={timer=300,recap=true,options={},nativeWrites=false}
for _,name in ipairs({"DEATH_RELEASE_TIMER","DEATH_RELEASE","USE_SOULSTONE","DEATH_RECAP","DEATH_RELEASE_SPECTATOR",
    "DEATH_RELEASE_NOTIMER","DEATH_RECAP_UNAVAILABLE","CAN_NOT_RELEASE_IN_COMBAT","CAN_NOT_RELEASE_RIGHT_NOW","ARENA_SPECTATOR"}) do env[name]=name end
env.GetReleaseTimeRemaining=function() return state.timer end
env.IsActiveBattlefieldArena=function() return state.arena or false end
env.C_PvP={IsInBrawl=function() return state.brawl or false end}
env.C_InstanceEncounter={IsEncounterSuppressingRelease=function() return state.encounter or false end}
env.IsFalling=function() return state.falling or false end
env.IsOutOfBounds=function() return state.outOfBounds or false end
env.HasNoReleaseAura=function() return state.noRelease or false,state.duration or 0,state.untilCancelled or false end
env.CannotBeResurrected=function() return state.noRes or false end
env.C_DeathRecap.HasRecapEvents=function() return state.recap end
env.ChatTypeInfo={SYSTEM={r=1,g=1,b=1,id=1}}
env.GameTooltip_Hide=function() end
env.GameDialogDefsUtil={GetDefaultExpirationText=function() end,
    GetSelfResurrectDialogOptions=function() return state.options[1],state.options[2] end,
    OnResurrectButtonClick=function(option,reason) state.usedOption=option;state.reason=reason;return true end}
env.RepopMe=function() state.releases=(state.releases or 0)+1 end
env.OpenDeathRecapUI=function() state.recaps=(state.recaps or 0)+1 end
local chunk=assert(loadstring("return "..body,"@external-Blizzard-DEATH"));setfenv(chunk,env)
local definition=chunk();env.StaticPopupDialogs={DEATH=definition}
local native=env.CreateFrame("Frame","StaticPopup1",env.UIParent);native.which="DEATH"
state.rect={500,650,440,110}
native.GetRect=function() return unpack(state.rect) end
native.IsProtected=function() return true end
native.Resize=function() state.resizes=(state.resizes or 0)+1 end
env.StaticPopup_FindVisible=function(which) return which=="DEATH" and native:IsShown() and native or nil end
local buttons={}
for i=1,4 do
    local b=env.CreateFrame("Button",nil,native);buttons[i]=b;b.enabled=true
    b.Enable=function(self) self:SetEnabled(true) end;b.Disable=function(self) self:SetEnabled(false) end
    b.IsEnabled=function(self) return self.enabled end
    b.SetMotionScriptsWhileDisabled=function(self,value) self.motionWhileDisabled=value end
    native["GetButton"..i]=function() return b end
    b:SetScript("OnClick",function() return definition["OnButton"..i](native,nil,"clicked") end)
end
local oldHandlers={};for i,b in ipairs(buttons) do oldHandlers[i]=b.scripts.OnClick end
-- Only calls explicitly made by the native-driver harness can write a native
-- frame. LTB may read public geometry, but any attempted mutation fails.
for _,f in ipairs({native,unpack(buttons)}) do
    for _,name in ipairs({"SetPoint","ClearAllPoints","SetParent","SetSize","SetWidth","SetHeight","SetScale","SetAlpha",
        "Show","Hide","SetShown","SetScript","HookScript","SetText","SetEnabled","EnableMouse","SetFrameLevel","SetFrameStrata"}) do
        local original=f[name]
        f[name]=function(self,...)
            assert(state.nativeWrites,"LTB modified a native death control: "..name)
            if original then return original(self,...) end
        end
    end
end
local function runNative(fn,...)
    state.nativeWrites=true;local result={pcall(fn,...)};state.nativeWrites=false
    assert(result[1],result[2]);return unpack(result,2)
end
local function update()
    runNative(definition.OnUpdate,native,.1)
    D.Tick(.3)
end
local function click(i)
    if buttons[i]:IsEnabled() then return runNative(buttons[i].scripts.OnClick) end
end
c.s.dead=true;c.B.Death()
c.s.recapLink="new";c.s.recap={{sourceGUID="Player-2-00AA",sourceName="Example Enemy",sourceFlags=0x440,
    event="SWING_DAMAGE",amount=100,overkill=0,timestamp=c.B.deathEvidence.server}}
runNative(definition.OnShow,native);c.advance(1);update()
check(D.frame:IsShown() and native.timeleft==300,"Real Blizzard OnShow preserves its release timer alongside LTB")
check(buttons[1]:IsEnabled() and buttons[4]:IsEnabled(),"Real Blizzard handlers expose release and available recap")
check(not definition.DisplayButton2(native) and not definition.DisplayButton3(native),"Absent self-res options remain absent")

state.falling=true;update();click(1)
check(not buttons[1]:IsEnabled() and not buttons[2]:IsEnabled() and not buttons[3]:IsEnabled() and not state.releases,
    "Actual falling restriction leaves release and self-res disabled with LTB present")
state.outOfBounds=true;update()
check(buttons[1]:IsEnabled(),"Blizzard's out-of-bounds exception remains effective")
state.falling=false;state.outOfBounds=false;state.encounter=true;update()
check(not buttons[1]:IsEnabled() and native:GetText()==env.CAN_NOT_RELEASE_IN_COMBAT,"Encounter release suppression retains Blizzard's message")
state.encounter=false;state.noRelease=true;state.duration=7.8;update()
check(not buttons[1]:IsEnabled() and buttons[1]:GetText()==7,"Timed release aura retains the native countdown label")
state.duration=2.9;update()
check(buttons[1]:GetText()==2,"Native release countdown continues updating while guild actions are visible")
state.untilCancelled=true;update()
check(not buttons[1]:IsEnabled() and buttons[1]:GetText()==env.DEATH_RELEASE,"Indefinite no-release aura stays disabled")
state.noRelease=false;state.untilCancelled=false;update()
check(buttons[1]:IsEnabled() and native.timeleft==300,"Removing a release restriction lets Blizzard re-enable and refresh the dialog")
state.timer=-1;runNative(definition.OnShow,native)
check(native:GetText()==env.DEATH_RELEASE_NOTIMER,"Blizzard's no-timer death text remains intact")

state.options={{name="Example Soulstone",canUse=true},{name="Example Reincarnation",canUse=false}};update()
check(definition.DisplayButton2(native) and definition.DisplayButton3(native),"Both actual native self-res option predicates remain available")
check(buttons[2]:GetText()=="Example Soulstone" and buttons[2]:IsEnabled() and not buttons[3]:IsEnabled(),
    "Self-res names and availability remain controlled by Blizzard")
click(2)
check(state.usedOption==state.options[1] and state.reason=="clicked","Native self-res click reaches its original option handler")
state.options[2].canUse=true;update();click(3)
check(state.usedOption==state.options[2],"A newly available second self-res choice remains usable")
state.recap=false;update();click(4)
check(not buttons[4]:IsEnabled() and buttons[4].scripts.OnEnter and buttons[4].motionWhileDisabled and not state.recaps,
    "Unavailable recap keeps Blizzard's disabled state and tooltip")
state.recap=true;update();local keepOpen=click(4)
check(buttons[4]:IsEnabled() and not buttons[4].scripts.OnEnter and state.recaps==1 and keepOpen==true,
    "Available recap invokes the real native callback and retains its keep-open return value")
state.noRes=true;local cannotResReturn=click(1)
check(state.releases==1 and cannotResReturn==1,"Native release retains CannotBeResurrected handling")
state.noRes=false;click(1)
check(state.releases==2,"Native release remains callable independently of guild actions")
local original=true;for i,b in ipairs(buttons) do original=original and b.scripts.OnClick==oldHandlers[i] end
check(original,"Running LTB and real native updates never replaces any native button callback")

-- Check screen bounds and intersection independently of the layout algorithm.
-- The fixtures represent on-screen dialogs at multiple native/root scales.
local cases=0;local maxWidth,maxHeight=560,D.frame:GetHeight()
for _,screen in ipairs({{800,600},{1024,768},{1440,1000},{2560,1440}}) do
    for _,rootScale in ipairs({.64,1,1.25}) do
        for _,relativeScale in ipairs({.7,1,1.2}) do
            local sw,sh=unpack(screen);env.UIParent:SetSize(sw,sh);env.UIParent:SetScale(rootScale)
            native.GetEffectiveScale=function() return rootScale*relativeScale end
            for _,pos in ipairs({{.5,.9},{.5,.55},{.5,.15},{.15,.5},{.85,.5}}) do
                local w,h=320*relativeScale,100*relativeScale
                local left=math.max(0,math.min(sw-w,sw*pos[1]-w/2))
                local bottom=math.max(0,math.min(sh-h,sh*pos[2]-h/2))
                state.rect={left/relativeScale,bottom/relativeScale,w/relativeScale,h/relativeScale}
                D.Refresh();cases=cases+1
                if D.frame:IsShown() then
                    local scale=D.frame:GetScale();local a=D.frame.anchor
                    local x,top=a[4]*scale,a[5]*scale;local rw,rh=maxWidth*scale,maxHeight*scale
                    assert(x>=-1e-6 and top-rh>=-1e-6 and x+rw<=sw+1e-6 and top<=sh+1e-6,"LTB offscreen in layout case "..cases)
                    assert(x+rw<=left or x>=left+w or top<=bottom or top-rh>=bottom+h,"LTB overlaps native controls in layout case "..cases)
                end
            end
        end
    end
end
check(cases==180,"180 native/root scale and screen-position cases keep guild actions on-screen and clear of the native window")
env.UIParent:SetSize(1440,1000);env.UIParent:SetScale(1);native.GetEffectiveScale=function() return 1 end;state.rect={500,650,440,110}
D.Refresh();D.Dismiss();update();click(1)
check(native:IsShown() and state.releases==3 and not D.frame:IsShown(),"Dismissed LTB actions do not stop native updates or release clicks")
c.s.outdoor=false;state.arena=true;runNative(definition.OnShow,native)
c.B.eventFrame.scripts.OnEvent(c.B.eventFrame,"ZONE_CHANGED_NEW_AREA");update();click(1)
check(not D.frame:IsShown() and native:GetText()==env.DEATH_RELEASE_SPECTATOR and state.releases==4,
    "Arena spectator death behavior stays native with the LTB extension suppressed")
runNative(definition.OnHide,native)
check(buttons[2].option==nil and buttons[3].option==nil and not buttons[4].motionWhileDisabled,
    "Blizzard's OnHide clears temporary resurrection and recap state normally")
print("Native death contract: actual external Blizzard handlers + "..cases.." layout cases passed; engine security is not simulated.")
