local client,check=...

do
    local c=client("Elowen","Dawnwatch",{theme="horde",chatEnabled=false},nil,nil,nil,true)
    local B,S,e=c.B,c.B.Settings,c.env
    check(S.registered and e.Settings.registered==S.categories.general,"Native Forever AddOns settings register after login")
    check(B.db.theme=="horde" and not B.db.chatEnabled,"Existing saved choices import into native settings without migration")
    check(B.UI.crest.file==B.MediaPaths.HordeCrest,"The saved Horde theme applies before the UI is created")
    check(B.UI.answer.backdrop.edgeFile==B.MediaPaths.FlatBlank and B.UI.answer.backdrop.edgeSize==1,
        "Horde action buttons use a flat one-pixel border instead of clipped dialog slices")
    check(B.UI.light.width==72 and B.UI.optionsButton.width==55 and B.UI.light.label.wrap==false,
        "Header actions reserve enough width and never ellipsize or wrap their labels")
    B.UI.frame:Hide();e.SlashCmdList.LIGHTTHEBEACONS("options")
    check(c.s.settingsCategory==S.categories.general:GetID() and not B.UI.frame:IsShown(),"The options command opens the native AddOns category")
    e.SlashCmdList.LIGHTTHEBEACONS("chat")
    check(c.s.settingsCategory==S.categories.chat:GetID(),"The chat command opens its native settings subcategory")
    B.GrudgeUI.Toggle(true);B.GrudgeUI.Mode("settings")
    check(c.s.settingsCategory==S.categories.grudges:GetID() and not B.GrudgeUI.frame:IsShown(),"The book's Options button opens the native Grudges category")
    S.settings.theme:SetValue("dark")
    check(B.db.theme=="dark" and B.UI.crest.file==B.MediaPaths.Torch and B.Theme.colors.gold[2]==.93,"Theme changes apply immediately and persist")
    check(B.UI.frame.backdrop.edgeFile=="Interface\\AddOns\\LightTheBeacons\\Media\\FlatBlank.tga" and B.UI.frame.backdrop.edgeSize==1,
        "Dark theme uses the addon's own flat primitive for its one-pixel frame")
    check(B.UI.frame.border[1]==B.Theme.colors.border[1] and B.UI.frame.border[1]==.10 and B.Theme.colors.value[3]==209/255,
        "Dark theme reapplies ElvUI-like border and value colors after changing backdrop assets")
    check(B.UI.destination.font=="Fonts\\ARIALN.TTF",
        "Dark theme uses a clean condensed WoW font when ElvUI is not installed")
    S.settings.theme:SetValue("ellesmere")
    check(B.db.theme=="ellesmere" and B.UI.frame.backdrop.edgeFile==B.MediaPaths.FlatBlank,
        "EllesmereUI theme is independently selectable and uses bundled primitives")
    check(B.Theme.colors.gold[1]==220/255 and B.Theme.colors.controlBorder[4]==.30,
        "EllesmereUI fallback reproduces its Forever accent and control-border treatment")
    S.settings.chatEnabled:SetValue(true)
    check(B.db.chatEnabled,"Native controls write back to the existing per-character saved variables")
    check(B.Settings.Open("filters","Sample Scout") and S.pendingFilter==nil,"Native Friends and filters canvas accepts a player from a map marker")
end

do
    local c=client("Elowen","Dawnwatch")
    c.B.Theme.Apply("horde");c.B.Print("Theme check")
    check(c.B.db.theme=="horde" and c.B.UI.crest.file==c.B.MediaPaths.HordeCrest,"Horde theme updates existing addon windows")
    check(c.s.lastMessage:find("^|cffff7048"),"Chat prefix follows the selected theme")
    c.B.Theme.Apply("not-a-theme")
    check(c.B.db.theme=="alliance" and c.B.UI.crest.file==c.B.MediaPaths.AllianceCrest,"Unknown saved themes fall back safely")
end

do
    local c=client("Elowen","Dawnwatch",nil,nil,nil,nil,true,{elvui=true,ellesmere=true})
    local B=c.B
    B.GrudgeUI.Toggle(true)
    check(B.GrudgeUI.frame:GetWidth()==1000 and B.GrudgeUI.pageBg:IsShown() and B.GrudgeUI.pageBgRight:IsShown() and not B.GrudgeUI.elvSkinned,
        "Alliance keeps a native two-page parchment spread even when ElvUI is installed")
    check(B.GrudgeUI.pageBg.coords[1]>B.GrudgeUI.pageBg.coords[2] and B.GrudgeUI.pageBgRight.coords[1]<B.GrudgeUI.pageBgRight.coords[2]
        and c.s.portraitHidden and not B.GrudgeUI.frame.PortraitContainer:IsShown(),"The left leaf uses reversed atlas coordinates and Blizzard's portrait helper removes the empty medallion")
    B.Theme.Apply("dark")
    check(B.UI.frame.backdrop.edgeFile==B.MediaPaths.FlatBlank and B.UI.frame.backdrop.edgeSize==.75,
        "ElvUI Dark uses the bundled primitive with ElvUI's live pixel scale")
    check(B.Theme.colors.panel[1]==.20 and B.Theme.colors.border[1]==.30 and B.Theme.colors.value[2]==.52,
        "ElvUI Dark inherits the active ElvUI backdrop, border and value colors")
    check(B.UI.destination.font=="ElvExpressway","ElvUI Dark inherits ElvUI's live Expressway font path")
    check(B.GrudgeUI.elvSkinned and not B.GrudgeUI.pageBg:IsShown() and B.GrudgeUI.pageShade:IsShown() and c.s.elvHandled>0,
        "The private Blizzard book is handed to ElvUI's public skin helpers and honors its parchment-removal setting")
    B.Theme.Apply("ellesmere")
    check(c.s.ellesmereSkinName=="LightTheBeacons" and B.Theme.colors.gold[1]==.31 and B.Theme.colors.panel[1]==.071,
        "EllesmereUI theme consumes its public live skin accent and panel values")
    check(B.UI.destination.font=="EllesmereSkinFont" and B.Theme.ChatColor()=="ff4fb894",
        "EllesmereUI theme inherits the public skin font and chat accent")
end
