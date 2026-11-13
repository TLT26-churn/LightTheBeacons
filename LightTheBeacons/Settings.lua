local _,B=...
local S={categories={},settings={}};B.Settings=S

local function available()
    return Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory and Settings.OpenToCategory
end
local function options(rows)
    return function()
        local container=Settings.CreateControlTextContainer()
        for _,row in ipairs(rows) do container:Add(row[1],row[2],row[3]) end
        return container:GetData()
    end
end
local function setting(category,scope,key,varType,label,default,tooltip,callback)
    local variable="LTB_"..key:upper()
    local item=Settings.RegisterAddOnSetting(category,variable,key,scope,varType,label,default)
    if callback then item:SetValueChangedCallback(function(_,value) callback(value) end) end
    S.settings[key]=item
    return item
end
local function check(category,scope,key,label,default,tooltip,callback)
    local item=setting(category,scope,key,Settings.VarType.Boolean,label,default,tooltip,callback)
    Settings.CreateCheckbox(category,item,tooltip);return item
end
local function dropdown(category,scope,key,label,default,rows,tooltip,callback)
    local item=setting(category,scope,key,type(default)=="number" and Settings.VarType.Number or Settings.VarType.String,label,default,tooltip,callback)
    Settings.CreateDropdown(category,item,options(rows),tooltip);return item
end
local function slider(category,scope,key,label,default,minimum,maximum,step,tooltip,callback,formatValue)
    local item=setting(category,scope,key,Settings.VarType.Number,label,default,tooltip,callback)
    local sliderOptions=Settings.CreateSliderOptions(minimum,maximum,step)
    if formatValue then sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,formatValue) end
    Settings.CreateSlider(category,item,sliderOptions,tooltip);return item
end
local function action(layout,label,buttonText,callback,tooltip)
    if not CreateSettingsButtonInitializer then return end
    layout:AddInitializer(CreateSettingsButtonInitializer(label,buttonText,callback,tooltip,true))
end
local function refreshUI()
    if B.UI then B.UI.Refresh();B.UI.MapPins() end
end

local function makeFiltersCanvas()
    local f=CreateFrame("Frame",nil,UIParent);f:SetSize(700,520)
    local title=f:CreateFontString(nil,"ARTWORK","GameFontNormalLarge");title:SetPoint("TOPLEFT",18,-18);title:SetText("Friends & player filters")
    local help=f:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");help:SetPoint("TOPLEFT",18,-48);help:SetSize(650,38);help:SetJustifyH("LEFT")
    help:SetText("Friend marks and filters are private to this character. Silence keeps calls visible without alerts; Hide removes beacons. Location visibility is separate.")
    local edit=CreateFrame("EditBox",nil,f,"InputBoxTemplate");f.edit=edit;edit:SetPoint("TOPLEFT",22,-96);edit:SetSize(310,28);edit:SetAutoFocus(false);edit:SetMaxBytes(150)
    edit:SetScript("OnEnterPressed",function(self) self:ClearFocus() end);edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    local add=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");add:SetPoint("LEFT",edit,"RIGHT",12,0);add:SetSize(110,26);add:SetText("Add player")
    local status=f:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");status:SetPoint("TOPLEFT",22,-132);status:SetSize(630,22);status:SetJustifyH("LEFT")
    local scroll=CreateFrame("ScrollFrame",nil,f);scroll:SetPoint("TOPLEFT",18,-164);scroll:SetSize(650,320);scroll:EnableMouseWheel(true)
    local child=CreateFrame("Frame",nil,scroll);child:SetSize(650,320);scroll:SetScrollChild(child);f.child=child
    local rows={};f.rows=rows
    local modes={normal="Normal",silent="Silence",hidden="Hide"};local nextMode={normal="silent",silent="hidden",hidden="normal"}
    local function row(index)
        local r=CreateFrame("Frame",nil,child);r:SetPoint("TOPLEFT",0,-((index-1)*44));r:SetSize(650,42)
        r.name=r:CreateFontString(nil,"ARTWORK","GameFontNormal");r.name:SetPoint("LEFT",8,0);r.name:SetSize(190,20);r.name:SetJustifyH("LEFT")
        r.friend=CreateFrame("CheckButton",nil,r,"UICheckButtonTemplate");r.friend:SetPoint("LEFT",205,0);r.friend:SetSize(24,24)
        r.friendLabel=r:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");r.friendLabel:SetPoint("LEFT",r.friend,"RIGHT",0,0);r.friendLabel:SetText("Friend")
        r.mode=CreateFrame("Button",nil,r,"UIPanelButtonTemplate");r.mode:SetPoint("LEFT",300,0);r.mode:SetSize(130,24)
        r.location=CreateFrame("CheckButton",nil,r,"UICheckButtonTemplate");r.location:SetPoint("LEFT",440,0);r.location:SetSize(24,24)
        r.locationLabel=r:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");r.locationLabel:SetPoint("LEFT",r.location,"RIGHT",0,0);r.locationLabel:SetText("Hide location")
        r.remove=CreateFrame("Button",nil,r,"UIPanelButtonTemplate");r.remove:SetPoint("RIGHT",-2,0);r.remove:SetSize(68,24);r.remove:SetText("Remove")
        r.friend:SetScript("OnClick",function(self) local p=B.Filter(r.key);if p then B.SetFriend(p.name,self:GetChecked() and true or false);S.RefreshFilters() end end)
        r.location:SetScript("OnClick",function(self) local p=B.Filter(r.key);if p then B.SetPlayerFilter(p.name,p.beacons,self:GetChecked() and true or false,p.friend);S.RefreshFilters() end end)
        r.mode:SetScript("OnClick",function() local p=B.Filter(r.key);if p then B.SetPlayerFilter(p.name,nextMode[p.beacons],p.hideLocation,p.friend);S.RefreshFilters() end end)
        r.remove:SetScript("OnClick",function() B.RemovePlayerFilter(r.key);S.RefreshFilters() end)
        return r
    end
    function S.RefreshFilters()
        if not f or not B.db then return end
        local list={};for key,p in pairs(B.db.playerFilters or {}) do list[#list+1]={key=key,p=p} end
        table.sort(list,function(a,b) return a.p.name<b.p.name end)
        for i=1,math.max(#list,#rows) do
            local r=rows[i] or row(i);rows[i]=r;local entry=list[i];r:SetShown(entry~=nil)
            if entry then r.key=entry.key;r.name:SetText(entry.p.name);r.friend:SetChecked(entry.p.friend);r.location:SetChecked(entry.p.hideLocation);r.mode:SetText("Beacons: "..modes[entry.p.beacons]) end
        end
        child:SetHeight(math.max(320,#list*44));scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll() or 0,math.max(0,child:GetHeight()-320)))
        status:SetText(#list==0 and "No Friends or player filters are configured." or (#list.." configured player "..(#list==1 and "filter." or "filters.")))
        if S.pendingFilter then edit:SetText(S.pendingFilter);edit:SetFocus();S.pendingFilter=nil end
    end
    add:SetScript("OnClick",function()
        local ok,why=B.SetPlayerFilter(edit:GetText(),"normal",false,false)
        if ok then edit:SetText("");edit:ClearFocus();status:SetText("Player added. Choose their Friend, beacon, and location options below.")
        else status:SetText(why or "That player could not be added.") end;S.RefreshFilters()
    end)
    scroll:SetScript("OnMouseWheel",function(self,delta)
        self:SetVerticalScroll(math.max(0,math.min(child:GetHeight()-320,(self:GetVerticalScroll() or 0)-delta*44)))
    end)
    f.OnRefresh=S.RefreshFilters;f:SetScript("OnShow",S.RefreshFilters)
    return f
end

function S.Open(page,filterName)
    if not S.registered or not available() then return false end
    if filterName then S.pendingFilter=filterName;if S.RefreshFilters then S.RefreshFilters() end end
    local category=S.categories[page or "general"] or S.categories.general
    if not category then return false end
    Settings.OpenToCategory(category:GetID());return true
end

function S.Initialize()
    if S.registered or not available() then return false end
    S.registered=true
    local root,rootLayout=Settings.RegisterVerticalLayoutCategory("Light the Beacons");S.categories.general=root
    root:SetShouldSortAlphabetically(false)
    dropdown(root,B.db,"theme","Theme","alliance",{{"alliance","Alliance"},{"horde","Horde"},{"dark","ElvUI Dark"},{"ellesmere","EllesmereUI"}},
        "Changes the Rally card, beacon alerts, death actions, accents, controls, and faction crest. Installed UI suites supply their live colors, scaling, and font.",function(value) B.Theme.Apply(value) end)
    check(root,B.db,"muteBeacons","Mute all alerts",false,"Stops addon sounds, popups, death prompts, and activity chat while preserving calls and location sharing.",B.MuteBeacons)
    check(root,B.db,"sound","Sound the war horn",true,"Play the native war horn for calls and the rally fanfare for the first responder.")
    check(root,B.db,"auto","Automatic PvP death beacon",false,"Automatically light a beacon only for a readable hostile-player killing blow.")
    check(root,B.db,"prompt","Offer aid after a PvP death",true,"Show the combined death action panel after confirmed hostile-player involvement.")
    check(root,B.db,"deathDock","Dock guild actions beside the death window",true,"Keep Blizzard's death controls untouched and place guild actions in the available space beside or below them.",function() B.DeathUI.Refresh() end)
    dropdown(root,B.db,"travelMode","Travel pace","auto",{{"auto","Automatic (trained riding tier)"},{"foot","On foot override"}},
        "Automatic uses this character's readable riding training.",function() B.UpdateTravelPace();B.Replan();refreshUI() end)
    action(rootLayout,"Quick messages","Edit",function() B.UI.Compose() end,"Edit the three per-character beacon message templates.")
    action(rootLayout,"Flight points","Refresh",function() B.Client.RefreshFlights(true) end,"Refresh confirmed destinations from an open flight-master map.")
    action(rootLayout,"Whitebeard Tinkerton - US PVP","About",function() B.Print("Version "..B.version.." by Whitebeard Tinkerton - US PVP.") end,"Addon author and current version.")

    local beacons,beaconLayout=Settings.RegisterVerticalLayoutSubcategory(root,"Beacons");S.categories.beacons=beacons
    check(beacons,B.db,"combineBeacons","Combine nearby beacons",true,"Display nearby calls as one group while preserving each caller.",function() B.Replan();B.UI.RefreshAlertGroup();refreshUI() end)
    slider(beacons,B.db,"mergeDistance","Combine distance (yards)",100,25,250,25,"Every caller in a group must be within this range of every other caller.",function() B.Replan();B.UI.RefreshAlertGroup();refreshUI() end,
        function(value) return string.format("%.0f yards",value) end)
    check(beacons,B.db,"disableInInstances","Disable beacons in dungeons and raids",true,"Blocks calls, popups, pins, and guidance in party and raid instances.",function() B.UI.EnforceBeaconContext();refreshUI() end)
    check(beacons,B.db,"beaconPopups","Show beacon and response popups",true,"Calls remain in the Rally card when popups are disabled.",function(value) if not value then B.UI.pendingAlert=nil;B.UI.banner:Hide();B.UI.answerBanner:Hide() end end)
    slider(beacons,B.db,"hornCooldown","Shared horn cooldown (seconds)",30,0,120,5,"Separate calls remain visible while the horn is cooling down.")
    slider(beacons,B.db,"mapIconScale","Map marker size (percent)",75,50,150,5,"Scales guildmate, Friend, and beacon markers.",refreshUI)

    local chat=Settings.RegisterVerticalLayoutSubcategory(root,"Chat notifications");S.categories.chat=chat
    check(chat,B.db,"chatEnabled","Enable chat notifications",true,"Master switch for all Light the Beacons activity lines in your local chat window.")
    check(chat,B.db,"chatBeacons","Beacon activity",true,"Report beacon lighting, extinguishing, and responses with a zone.")
    check(chat,B.db,"chatJoins","Nearby beacon joins",false,"Report a caller joining an already grouped beacon.")
    check(chat,B.db,"chatGrudges","Grudge activity",true,"Report inscriptions, withdrawals, and vengeance with scribe, enemy, avenger, and zone.")
    check(chat,B.db,"chatSightings","Enemy sightings",false,"Report local target and mouseover sightings; requires grudge sighting warnings.")

    local map,mapLayout=Settings.RegisterVerticalLayoutSubcategory(root,"Map & controls");S.categories.controls=map
    check(map,B.db,"shareLocation","Share my location with guildmates",true,"Sends an approximate game position to guild addon users about every 10 seconds.",B.ShareLocation)
    check(map,B.db,"showLocations","Show guildmates on my map",true,"Controls only your map display, not outbound sharing.",refreshUI)
    check(map,B.db,"friendsOnly","Show only Friends on the map",false,"Filters both guild location and beacon markers, except your own beacon.",refreshUI)
    check(map,B.db,"floatingButton","Show movable beacon button",true,"Left-click to light or extinguish; Shift-drag to move; right-click opens the Rally card.",refreshUI)
    action(mapLayout,"Movable button position","Reset",function() B.db.buttonPosition=nil;B.UI.RestoreFloating() end,"Restore the floating brazier to its default position.")
    action(mapLayout,"World map","Open",function() if OpenWorldMap then B.Client.Call(OpenWorldMap,947) elseif WorldMapFrame then WorldMapFrame:Show() end end,"Open the full Azeroth map.")

    local G=B.Grudges;local grudges,grudgeLayout=Settings.RegisterVerticalLayoutSubcategory(root,"Grudges");S.categories.grudges=grudges
    check(grudges,G.options,"enabled","Use the guild-shared book",true,"Off pauses sending, receiving, and automatic recording; saved pages remain readable.",G.SetEnabled)
    dropdown(grudges,G.options,"deathMode","After an outdoor PvP death","prompt",{{"prompt","Ask first"},{"auto","Auto-save confirmed killer"},{"off","Off"}},
        "Both automatic modes require positive hostile-player evidence.",G.SetDeathMode)
    check(grudges,G.options,"autoAvenge","Record my confirmed victories",true,"A readable killing blow settles one oldest unpaid debt.")
    check(grudges,G.options,"sightingAlerts","Warn when a debtor is seen",true,"Uses only a hostile player you target or mouse over; sightings are not shared.")
    check(grudges,G.options,"notices","Show grudge popups",true,"Chat reporting is controlled independently in Chat notifications.")
    action(grudgeLayout,"Guild ledger","Sync pages",function() G.Sync() end,"Request missing ledger history from online guild addon users.")
    action(grudgeLayout,"Hidden enemies","Restore all",function() G.options.hidden={};if B.GrudgeUI then B.GrudgeUI.Refresh() end end,"Make every locally hidden enemy visible again.")

    local phrases=Settings.RegisterVerticalLayoutSubcategory(root,"Grudge phrases");S.categories.phrases=phrases
    for _,kind in ipairs({"incurred","sighted","avenged"}) do
        local rows={{0,"Standard wording"}};for index,line in ipairs(G.phrases[kind]) do rows[#rows+1]={index,line} end
        local variable="LTB_GRUDGE_PHRASE_"..kind:upper()
        local proxy=Settings.RegisterProxySetting(phrases,variable,Settings.VarType.Number,kind:gsub("^%l",string.upper),0,
            function() return G.options.phrases[kind] or 0 end,function(value) G.options.phrases[kind]=value~=0 and value or nil end)
        Settings.CreateDropdown(phrases,proxy,options(rows),"Choose the popup wording for this grudge event.")
    end

    local filterCanvas=makeFiltersCanvas();local filters=Settings.RegisterCanvasLayoutSubcategory(root,filterCanvas,"Friends & filters");S.categories.filters=filters
    Settings.RegisterAddOnCategory(root)
    return true
end
