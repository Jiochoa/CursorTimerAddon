-- 1. Default Settings & Initialization
local addonName = "CursorTimer"
local defaults = {
    size = 45,
    offsetX = 30,
    offsetY = 30,
    alpha = 1.0,
    fontSize = 18,
    spellNameSize = 12,
    showTimer = true,
    showSpellName = true,
    showIcon = true,
    showBorder = false,
    borderAlpha = 0.8,
    borderPadding = 2,
    autoHide = 0.5,
    minVisible = 0.1
}

local testModeActive = false
local fading = false
local categoryHandle = nil

local function InitializeDB()
    if not CursorTimerDB then CursorTimerDB = {} end
    for k, v in pairs(defaults) do
        if CursorTimerDB[k] == nil then CursorTimerDB[k] = v end
    end
end

-- 2. Setup the Frame
local frame = CreateFrame("Frame", "CursorTimerFrame", UIParent)
frame:SetFrameStrata("TOOLTIP")
frame:Hide()

frame.icon = frame:CreateTexture(nil, "ARTWORK")
frame.icon:SetAllPoints(frame)
frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

frame.border = frame:CreateTexture(nil, "OVERLAY")
frame.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

frame.cd = CreateFrame("Cooldown", "CursorTimerSwipe", frame, "CooldownFrameTemplate")
frame.cd:SetAllPoints(frame)

frame.spellName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.spellName:SetPoint("BOTTOM", frame, "TOP", 0, 5)

-- 3. Settings Menu
local function SetupSettings()
    local category = Settings.RegisterVerticalLayoutCategory("CursorTimer")
    categoryHandle = category

    -- Test Mode Toggle
    local testSetting = Settings.RegisterProxySetting(category, "CT_TestMode", Settings.VarType.Boolean, "Test Mode",
        false,
        function() return testModeActive end,
        function(value)
            testModeActive = value
            fading = false
            if value then
                frame:SetAlpha(CursorTimerDB.alpha)
                frame.icon:SetTexture(136071)
                frame.spellName:SetText("Polymorph")
                frame.cd:SetCooldown(GetTime(), 30)
                frame:Show()
            else
                frame:Hide()
            end
        end
    )
    Settings.CreateCheckbox(category, testSetting, "Shows the icon permanently to adjust sliders.")

    -- Positioning Info
    Settings.CreateSlider(category,
        Settings.RegisterAddOnSetting(category, "CT_X", "offsetX", CursorTimerDB, Settings.VarType.Number,
            "X Position",
            defaults.offsetX), Settings.CreateSliderOptions(-100, 100))
    Settings.CreateSlider(category,
        Settings.RegisterAddOnSetting(category, "CT_Y", "offsetY", CursorTimerDB, Settings.VarType.Number,
            "Y Position",
            defaults.offsetY), Settings.CreateSliderOptions(-100, 100))


    -- Timing and Visibility
    Settings.CreateSlider(category,
        Settings.RegisterAddOnSetting(category, "CT_AutoHide", "autoHide", CursorTimerDB, Settings.VarType.Number,
            "Visibility Duration", defaults.autoHide), Settings.CreateSliderOptions(0.1, 1.0))
    Settings.CreateSlider(category,
        Settings.RegisterAddOnSetting(category, "CT_Alpha", "alpha", CursorTimerDB, Settings.VarType.Number,
            "Overall Opacity", defaults.alpha), Settings.CreateSliderOptions(0.1, 1.0))

    -- Icon and Border
    Settings.CreateCheckbox(category,
        Settings.RegisterAddOnSetting(category, "CT_ShowIcon", "showIcon", CursorTimerDB, Settings.VarType.Boolean,
            "Show Icon", defaults.showIcon))
    Settings.CreateSlider(category,
        Settings.RegisterAddOnSetting(category, "CT_Size", "size", CursorTimerDB, Settings.VarType.Number,
            "Icon Size", defaults.size), Settings.CreateSliderOptions(20, 100))
    Settings.CreateCheckbox(category,
        Settings.RegisterAddOnSetting(category, "CT_ShowBorder", "showBorder", CursorTimerDB,
            Settings.VarType.Boolean, "Show Icon Border", defaults.showBorder))
    Settings.CreateSlider(category,
        Settings.RegisterAddOnSetting(category, "CT_BorderPadding", "borderPadding", CursorTimerDB,
            Settings.VarType.Number, "Border Offset", defaults.borderPadding), Settings.CreateSliderOptions(-10, 20))
    Settings.CreateSlider(category,
        Settings.RegisterAddOnSetting(category, "CT_BorderAlpha", "borderAlpha", CursorTimerDB,
            Settings.VarType.Number, "Border Intensity", defaults.borderAlpha), Settings.CreateSliderOptions(0, 1.0))

    --Text and Timer
    Settings.CreateCheckbox(category,
        Settings.RegisterAddOnSetting(category, "CT_ShowTimer", "showTimer", CursorTimerDB, Settings.VarType.Boolean,
            "Show Timer Numbers", defaults.showTimer))
    Settings.CreateSlider(category,
        Settings.RegisterAddOnSetting(category, "CT_FontSize", "fontSize", CursorTimerDB, Settings.VarType.Number,
            "Timer Font Size", defaults.fontSize), Settings.CreateSliderOptions(10, 40))
    Settings.CreateCheckbox(category,
        Settings.RegisterAddOnSetting(category, "CT_ShowName", "showSpellName", CursorTimerDB,
            Settings.VarType.Boolean, "Show Spell Name", defaults.showSpellName))
    Settings.CreateSlider(category,
        Settings.RegisterAddOnSetting(category, "CT_NameSize", "spellNameSize", CursorTimerDB,
            Settings.VarType.Number, "Spell Name Font Size", defaults.spellNameSize), Settings.CreateSliderOptions(8, 30))


    Settings.RegisterAddOnCategory(category)
end

-- 4. Logic & Fixes
local lastShowTime = 0
local function RequestHide()
    if testModeActive or fading then return end
    if (GetTime() - lastShowTime) < CursorTimerDB.autoHide then
        C_Timer.After(0.05, RequestHide)
    else
        fading = true
        UIFrameFadeOut(frame, 0.2, frame:GetAlpha(), 0)
        C_Timer.After(0.2, function()
            if not testModeActive then frame:Hide() end
            fading = false
        end)
    end
end

local function ShowCooldownIcon(spellID)
    if not spellID or testModeActive then return end
    local cdInfo = C_Spell.GetSpellCooldown(spellID)
    if not cdInfo or cdInfo.isOnGCD then return end

    local startTime = cdInfo.startTime
    local hasCD = (issecretvalue and issecretvalue(startTime)) or (type(startTime) == "number" and startTime > 0)

    if hasCD then
        local spellData = C_Spell.GetSpellInfo(spellID)
        if spellData and spellData.iconID then
            fading = false
            UIFrameFadeIn(frame, 0.1, frame:GetAlpha() or 0, CursorTimerDB.alpha)
            lastShowTime = GetTime()
            frame.icon:SetTexture(spellData.iconID)
            frame.spellName:SetText(spellData.name)
            frame.cd:SetCooldown(startTime, cdInfo.duration)
            frame:Show()
            if frame.hideTimer then frame.hideTimer:Cancel() end
            frame.hideTimer = C_Timer.After(CursorTimerDB.autoHide, RequestHide)
        end
    end
end

-- 5. Events (Macro Fix Included)
local lastAttemptedSpellID = nil
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitializeDB()
        SetupSettings()
    elseif event == "UI_ERROR_MESSAGE" then
        if (arg1 == 50 or arg1 == 61) and lastAttemptedSpellID then
            ShowCooldownIcon(lastAttemptedSpellID)
        end
    end
end)

-- Fixed Macro Detection
hooksecurefunc("UseAction", function(slot)
    local actionType, id = GetActionInfo(slot)
    if actionType == "spell" then
        lastAttemptedSpellID = id
    elseif actionType == "macro" then
        local spellID = nil
        -- Use modern C_Macro if available, fallback to old global check
        if C_Macro and C_Macro.GetMacroSpell then
            spellID = C_Macro.GetMacroSpell(id)
        elseif GetMacroSpell then
            spellID = GetMacroSpell(id)
        end
        lastAttemptedSpellID = spellID
    else
        lastAttemptedSpellID = nil
    end
end)
hooksecurefunc("CastSpellByID", function(id) lastAttemptedSpellID = id end)

-- 6. Movement & Visual Update Loop
frame:SetScript("OnUpdate", function(self)
    if self:IsShown() then
        self:SetSize(CursorTimerDB.size, CursorTimerDB.size)

        -- Apply the Border Offset
        local p = CursorTimerDB.borderPadding
        self.border:ClearAllPoints()
        self.border:SetPoint("TOPLEFT", self, "TOPLEFT", -p, p)
        self.border:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", p, -p)

        -- Visibility Updates
        self.icon:SetShown(CursorTimerDB.showIcon)
        self.border:SetShown(CursorTimerDB.showBorder)
        self.border:SetAlpha(CursorTimerDB.borderAlpha)
        if not fading then self:SetAlpha(CursorTimerDB.alpha) end

        self.spellName:SetShown(CursorTimerDB.showSpellName)
        if CursorTimerDB.showSpellName then
            local font, _, flags = self.spellName:GetFont()
            self.spellName:SetFont(font, CursorTimerDB.spellNameSize, "OUTLINE")
        end

        self.cd:SetHideCountdownNumbers(not CursorTimerDB.showTimer)
        if CursorTimerDB.showTimer then
            for _, region in ipairs({ self.cd:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    local font, _, flags = region:GetFont()
                    region:SetFont(font, CursorTimerDB.fontSize, "OUTLINE")
                end
            end
        end

        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        if scale > 0 then
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (x / scale) + CursorTimerDB.offsetX,
                (y / scale) + CursorTimerDB.offsetY)
        end
    end
end)

SLASH_CURSORTIMER1 = "/ct"
SlashCmdList["CURSORTIMER"] = function()
    Settings.OpenToCategory(categoryHandle)
end
