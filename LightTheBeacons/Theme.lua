local _,B=...
local T={colors={},regions={},icons={},backdrops={},fonts={}};B.Theme=T

local flatTexture="Interface\\AddOns\\LightTheBeacons\\Media\\FlatBlank.tga"
local elvFont="Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\Expressway.ttf"
local darkFallbackFont="Fonts\\ARIALN.TTF"
local function addonExists(name)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local ok,info=pcall(C_AddOns.GetAddOnInfo,name);if ok and info then return true end
    end
    if GetAddOnInfo then
        local ok,info=pcall(GetAddOnInfo,name);if ok and info then return true end
    end
    return false
end
local function elvEngine()
    local addon=_G.ElvUI
    return type(addon)=="table" and type(addon[1])=="table" and addon[1] or nil
end
local function color(source,fallback)
    if type(source)~="table" then return fallback end
    local r,g,b=source[1] or source.r,source[2] or source.g,source[3] or source.b
    return type(r)=="number" and type(g)=="number" and type(b)=="number" and {r,g,b} or fallback
end
local function flatBackdrop()
    local E=elvEngine()
    local edge=T.current=="dark" and E and E.Scale and E:Scale(E.twoPixelsPlease and 2 or 1) or 1
    return {bgFile=flatTexture,edgeFile=flatTexture,tile=false,edgeSize=edge}
end

T.order={"alliance","horde","dark","ellesmere"}
T.themes={
    alliance={name="Alliance",chat="ffffc55c",assets={crest="AllianceCrest",shield="AllianceShield",glow="AllianceGlow"},
        colors={gold={1,.82,.43},value={.80,.65,.38},pale={.86,.90,.97},muted={.60,.66,.76},panel={.025,.035,.055},
            header={.045,.12,.27},button={.08,.22,.48},banner={.12,.25,.55},band={.045,.13,.29},border={.80,.65,.38},controlBorder={.80,.65,.38}}},
    horde={name="Horde",chat="ffff7048",assets={crest="HordeCrest",shield="HordeShield",glow="HordeGlow"},
        colors={gold={1,.72,.40},value={.82,.36,.20},pale={.96,.87,.78},muted={.70,.58,.54},panel={.055,.018,.016},
            header={.29,.035,.025},button={.16,.035,.028},banner={.46,.065,.035},band={.24,.03,.025},border={.82,.36,.20},controlBorder={.82,.36,.20}}},
    dark={name="Dark",chat="ff33d1c7",assets={crest="Torch",shield="Torch",glow="RoyalBrazier"},fullIcon=true,
        colors={gold={1,.93,.12},value={23/255,132/255,209/255},pale={.92,.92,.92},muted={.64,.64,.64},panel={.07,.07,.07},
            header={.054,.054,.054},button={.10,.10,.10},banner={.10,.10,.10},band={.054,.054,.054},border={.10,.10,.10},controlBorder={.10,.10,.10}}},
    ellesmere={name="EllesmereUI",chat="ffdca77f",assets={crest="RoyalBrazier",shield="RoyalBrazier",glow="RoyalBrazier"},fullIcon=true,
        colors={gold={220/255,167/255,127/255},value={220/255,167/255,127/255},pale={1,1,1,.92},muted={1,1,1,.53},
            panel={.069,.058,.047},header={.045,.035,.027},button={.089,.080,.072,.60},banner={.069,.058,.047},
            band={0,0,0,.20},border={1,1,1,.05},controlBorder={1,1,1,.30}}},
}

for _,key in ipairs({"gold","value","pale","muted","panel","header","button","banner","band","border","controlBorder"}) do T.colors[key]={} end

local function copyColor(target,source)
    target[1],target[2],target[3],target[4]=source[1],source[2],source[3],source[4]
end
local function setRegion(entry)
    local c=entry.color
    if entry.kind=="text" then entry.region:SetTextColor(c[1],c[2],c[3],entry.alpha or c[4] or 1)
    elseif entry.kind=="fill" then entry.region:SetColorTexture(c[1],c[2],c[3],entry.alpha or c[4] or 1)
    elseif entry.kind=="backdrop" then entry.region:SetBackdropColor(c[1],c[2],c[3],entry.alpha or c[4] or 1)
    elseif entry.kind=="border" then entry.region:SetBackdropBorderColor(c[1],c[2],c[3],entry.alpha or c[4] or 1) end
end
function T.Track(region,color,kind,alpha)
    if not region or not color then return region end
    local entry={region=region,color=color,kind=kind,alpha=alpha};T.regions[#T.regions+1]=entry;setRegion(entry)
    return region
end
local function findEntry(list,region)
    for _,entry in ipairs(list) do if entry.region==region then return entry end end
end
function T.ApplyBackdrop(entry)
    if entry.flat or T.current=="dark" or T.current=="ellesmere" then entry.region:SetBackdrop(flatBackdrop())
    else entry.region:SetBackdrop(entry.original) end
end
function T.TrackBackdrop(region,original,flat)
    if not region then return region end
    local entry=findEntry(T.backdrops,region)
    if entry then entry.original,entry.flat=original,flat and true or false
    else entry={region=region,original=original,flat=flat and true or false};T.backdrops[#T.backdrops+1]=entry end
    T.ApplyBackdrop(entry)
    -- SetBackdrop resets its colors to white, so immediately restore every
    -- tracked color for a frame whose backdrop definition changed.
    for _,tracked in ipairs(T.regions) do if tracked.region==region then setRegion(tracked) end end
    return region
end
function T.DarkFont()
    local E=elvEngine()
    return E and E.Media and E.Media.Fonts and E.Media.Fonts.Expressway or addonExists("ElvUI") and elvFont or darkFallbackFont
end
function T.RegisterElvUI()
    local E=elvEngine()
    local S=E and E.GetModule and E:GetModule("Skins",true)
    if T.elvRegistered or not S or not S.AddCallbackForAddon then return end
    T.elvRegistered=true
    S:AddCallbackForAddon("LightTheBeacons","LightTheBeaconsTheme",function()
        if T.current=="dark" then T.Apply("dark") end
        if B.GrudgeUI and B.GrudgeUI.ApplyElvUISkin then B.GrudgeUI.ApplyElvUISkin() end
    end)
end
function T.RefreshElvUI()
    local E=elvEngine();if not E or not E.media then return end
    local theme=T.themes.dark
    local backdrop=color(E.media.backdropcolor,theme.colors.panel)
    local faded=color(E.media.backdropfadecolor,{.054,.054,.054})
    theme.colors.panel=backdrop;theme.colors.banner=backdrop;theme.colors.button=backdrop
    theme.colors.header=faded;theme.colors.band=faded
    theme.colors.border=color(E.media.bordercolor,theme.colors.border)
    theme.colors.controlBorder=theme.colors.border
    theme.colors.value=color(E.media.rgbvaluecolor,theme.colors.value)
end
function T.RegisterEllesmereUI()
    local EUI=_G.EllesmereUI
    if T.ellesmereRegistered or not EUI or not EUI.RegisterSkin then return end
    T.ellesmereRegistered=true
    EUI.RegisterSkin("LightTheBeacons",function(S)
        T.ellesmereSkin=S
        if T.current=="ellesmere" then T.Apply("ellesmere") end
    end)
end
function T.RefreshEllesmereUI()
    local theme=T.themes.ellesmere
    local EUI,S=_G.EllesmereUI,T.ellesmereSkin
    local r,g,b,a
    if S and S.GetAccentColor then r,g,b=S.GetAccentColor()
    elseif EUI and EUI.ELLESMERE_GREEN then r,g,b=EUI.ELLESMERE_GREEN.r,EUI.ELLESMERE_GREEN.g,EUI.ELLESMERE_GREEN.b end
    if r and g and b then
        theme.colors.gold={r,g,b};theme.colors.value={r,g,b}
        theme.chat=string.format("ff%02x%02x%02x",math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5))
    end
    if S and S.GetPanelColor then
        r,g,b,a=S.GetPanelColor();if r and g and b then
            theme.colors.panel={r,g,b,a};theme.colors.banner={r,g,b,a}
        end
    end
end
function T.EllesmereFont()
    local S,EUI=T.ellesmereSkin,_G.EllesmereUI
    if S and S.GetFont then local path=S.GetFont();if path then return path end end
    if EUI and EUI.GetFontPath then local ok,path=pcall(EUI.GetFontPath);if ok and path then return path end end
    return darkFallbackFont
end
function T.ApplyFont(entry)
    local path=T.current=="dark" and T.DarkFont() or T.current=="ellesmere" and T.EllesmereFont() or entry.default
    if path then
        local ok=entry.region:SetFont(path,entry.size,entry.flags or "")
        if ok==false and path~=darkFallbackFont then entry.region:SetFont(darkFallbackFont,entry.size,entry.flags or "") end
    end
    if entry.shadow and entry.region.SetShadowColor then
        local flat=T.current=="dark" or T.current=="ellesmere"
        entry.region:SetShadowColor(0,0,0,flat and 0 or .9)
        entry.region:SetShadowOffset(flat and 0 or 1,flat and 0 or -1)
    end
end
function T.TrackFont(region,size,default,flags,shadow)
    if not region then return region end
    if not default and region.GetFont then default=region:GetFont() end
    local entry=findEntry(T.fonts,region)
    if entry then entry.size,entry.default,entry.flags,entry.shadow=size,default or entry.default,flags,shadow
    else entry={region=region,size=size,default=default,flags=flags,shadow=shadow};T.fonts[#T.fonts+1]=entry end
    T.ApplyFont(entry);return region
end
function T.TrackIcon(region,role)
    if not region then return region end
    T.icons[#T.icons+1]={region=region,role=role or "crest"};T.ApplyIcon(region,role or "crest")
    return region
end
function T.ApplyIcon(region,role)
    local theme=T.themes[T.current or "alliance"] or T.themes.alliance
    region:SetTexture(B.MediaPaths[theme.assets[role] or theme.assets.crest])
    if theme.fullIcon then region:SetTexCoord(0,1,0,1)
    elseif role=="shield" then region:SetTexCoord(.125,.875,0,1)
    else region:SetTexCoord(.175,.825,.09,.91) end
end
function T.Asset(role)
    local theme=T.themes[T.current or "alliance"] or T.themes.alliance
    return B.MediaPaths[theme.assets[role] or theme.assets.crest]
end
function T.ChatColor() return (T.themes[T.current or "alliance"] or T.themes.alliance).chat end
function T.Apply(id)
    if not T.themes[id] then id="alliance" end
    if id=="dark" then T.RegisterElvUI();T.RefreshElvUI() end
    if id=="ellesmere" then T.RegisterEllesmereUI();T.RefreshEllesmereUI() end
    T.current=id;if B.db then B.db.theme=id end
    for key,color in pairs(T.themes[id].colors) do copyColor(T.colors[key],color) end
    for _,entry in ipairs(T.backdrops) do T.ApplyBackdrop(entry) end
    for _,entry in ipairs(T.fonts) do T.ApplyFont(entry) end
    for _,entry in ipairs(T.regions) do setRegion(entry) end
    for _,entry in ipairs(T.icons) do T.ApplyIcon(entry.region,entry.role) end
    if B.UI and B.UI.frame and B.UI.Refresh then B.UI.Refresh();B.UI.MapPins() end
    if B.DeathUI and B.DeathUI.Refresh then B.DeathUI.Refresh() end
    if B.GrudgeUI and B.GrudgeUI.ApplyTheme then B.GrudgeUI.ApplyTheme() end
end
function T.Initialize()
    T.RegisterElvUI()
    T.RegisterEllesmereUI()
    local id=B.db and B.db.theme or "alliance"
    T.Apply(T.themes[id] and id or "alliance")
end

T.Apply("alliance")
