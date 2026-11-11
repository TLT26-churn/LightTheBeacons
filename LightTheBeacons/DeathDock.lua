local _,B=...
local D,C,P=B.DeathUI,B.Client,B.Protocol
-- A read-only attachment to the native death window. Never hide, reparent,
-- resize, reskin, replace handlers on, or click a Blizzard frame. Protected
-- release/self-res controls and UI skinning addons remain their sole owners.
local function shown(f)
    local value=C.Call(f.IsShown,f);return P.Plain(value) and value==true
end
local function nativeDeath()
    local f=C.Call(StaticPopup_FindVisible,"DEATH")
    if P.Plain(f) and (type(f)=="table" or type(f)=="userdata") and shown(f) then return f end
    for i=1,4 do
        f=_G["StaticPopup"..i]
        if f and P.Plain(f.which) and f.which=="DEATH" and shown(f) then return f end
    end
end
local function rect(f)
    local left,bottom,width,height=C.Call(f.GetRect,f)
    local scale=C.Call(f.GetEffectiveScale,f);local parentScale=C.Call(UIParent.GetEffectiveScale,UIParent)
    if not P.Number(left,-100000,100000) or not P.Number(bottom,-100000,100000)
        or not P.Number(width,1,100000) or not P.Number(height,1,100000)
        or not P.Number(scale,.01,100) or not P.Number(parentScale,.01,100) then return end
    local factor=scale/parentScale
    return left*factor,bottom*factor,width*factor,height*factor
end
function D.ApplyPosition()
    local f=D.frame;if not f then return false end
    D.awaitingLayout=nil;D.recapOpen=nil
    if DeathRecapFrame and shown(DeathRecapFrame) then
        D.recapOpen=true;D.dockStatus="hidden while recap is open";return false
    end
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local fh=f:GetHeight();local base=math.min(1,(width-32)/560,(height-32)/fh)
    local native=nativeDeath();local x,y,scale=16,height-80,base
    if native then
        local left,bottom,nw,nh=rect(native)
        if not left then D.awaitingLayout=true;D.dockStatus="waiting for native layout";return false end
        if B.db.deathDock~=false and bottom-24>=fh*math.min(.72,base) then
            scale=math.min(base,(bottom-24)/fh)
            x=math.max(16,math.min(width-16-560*scale,left+nw/2-280*scale));y=math.min(height-16,bottom-8)
            D.dockStatus="below Blizzard death controls"
        else
            -- If docking would shrink the actions excessively, use the larger
            -- side space. Do not let screen clamping cover the native controls.
            local right=width-left-nw-24;local leftSpace=left-24
            local side=right>=leftSpace and "right" or "left";local room=math.max(right,leftSpace)
            scale=math.min(base,room/560)
            if scale<math.min(.65,base) then D.awaitingLayout=true;D.dockStatus="native controls kept clear; waiting for space";return false end
            x=side=="right" and left+nw+8 or left-8-560*scale
            y=math.max(16+fh*scale,math.min(height-16,bottom+nh))
            D.dockStatus="beside Blizzard death controls"
        end
        D.title:SetText("Guild actions")
    else
        -- Spirit released, or no accessible native popup: keep the guild panel
        -- independent at the left edge, away from the usual central dialogs.
        y=math.max(16+fh*scale,math.min(height-16,y))
        D.title:SetText("You have fallen");D.dockStatus="standalone guild actions"
    end
    if f.SetScale then f:SetScale(scale) end
    f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x/scale,y/scale)
    return true
end
local elapsed=0
function D.Tick(delta)
    if not D.active or D.dismissed or D.suspended or not D.frame then return end
    elapsed=elapsed+delta;if elapsed<.25 then return end;elapsed=0
    if D.frame:IsShown() or D.awaitingLayout or D.recapOpen then D.Refresh() end
end
