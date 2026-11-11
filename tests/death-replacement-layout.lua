-- DESIGN RENDER ONLY. These placeholder controls do not replace Blizzard's dialog,
-- call RepopMe, or open a recap. Production must retain native restrictions and
-- every resurrection option before taking over the standard death window.
local c=...
local D,W=c.B.DeathUI,c.B.GrudgeUI.Widgets
local f=D.frame
-- The standard death controls should never disappear behind a generic close X.
for _,object in ipairs(c.objects) do
    if object.parent==f and object.caption and object.caption:GetText()=="X" then object:Hide() end
end
local function shift(frame,dy)
    local a=frame.anchor;frame:ClearAllPoints();frame:SetPoint(a[1],a[2],a[3],a[4],a[5]-dy)
end
local native= c.env.CreateFrame("Frame",nil,f)
native:SetPoint("TOPLEFT",22,-88);native:SetSize(516,88)
local release=W.link(native,"Release Spirit",0,0,251,function() end,23,"primary")
release:Resize(46);release.caption:SetPoint("TOPLEFT",5,-12);release.caption:SetHeight(29)
release.background:SetColorTexture(.43,.28,.075,1);release.caption:SetTextColor(1,.91,.67)
for _,edge in ipairs(release.edges) do edge:SetColorTexture(.95,.78,.40,1) end
local recap=W.link(native,"Death Recap",265,0,251,function() end,23,"dark")
recap:Resize(46);recap.caption:SetPoint("TOPLEFT",5,-12);recap.caption:SetHeight(29)
recap.background:SetColorTexture(.10,.18,.29,1);recap.caption:SetTextColor(.94,.94,.89)
for _,edge in ipairs(recap.edges) do edge:SetColorTexture(.72,.76,.80,1) end
W.label(native,0,66,516,17,12,"body",{.63,.57,.45}):SetText("GUILD ACTIONS")
W.fill(native,0,87,516,1,{.40,.32,.19},1)
for _,frame in ipairs({D.aid,D.ledger,D.status,D.dismiss}) do shift(frame,112) end
D.dismiss.caption:SetText("Hide guild actions")
D.status:SetWidth(367)
D.dismiss:SetWidth(137);D.dismiss.background:SetWidth(137);D.dismiss.hover:SetWidth(135)
D.dismiss.edges[1]:SetWidth(137);D.dismiss.edges[2]:SetWidth(137);D.dismiss.edges[4]:SetPoint("TOPLEFT",136,0)
D.dismiss.caption:SetWidth(127);D.dismiss:SetPoint("TOPLEFT",401,-(D.frame.height-52+112))
f:SetHeight(f.height+112);f.surface:SetHeight(f.height-20)
return c
