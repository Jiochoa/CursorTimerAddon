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
}

local testModeActive = false
local fading = false
local categoryHandle = nil
local hideTimer = nil

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

-- 3. Applying Settings
-- Runs only when a setting changes or the icon is (re)shown, never per frame.
local function ApplySettings()
    local db = CursorTimerDB
    frame:SetSize(db.size, db.size)

    local p = db.borderPadding
    frame.border:ClearAllPoints()
    frame.border:SetPoint("TOPLEFT", frame, "TOPLEFT", -p, p)
    frame.border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", p, -p)

    frame.icon:SetShown(db.showIcon)
    frame.border:SetShown(db.showBorder)
    frame.border:SetAlpha(db.borderAlpha)
    if not fading then frame:SetAlpha(db.alpha) end

    frame.spellName:SetShown(db.showSpellName)
    local nameFont = frame.spellName:GetFont()
    if nameFont then frame.spellName:SetFont(nameFont, db.spellNameSize, "OUTLINE") end

    frame.cd:SetHideCountdownNumbers(not db.showTimer)
    if db.showTimer then
        -- The countdown FontString is created lazily by the Cooldown widget,
        -- so this must re-run after SetCooldown, not just at load.
        for _, region in ipairs({ frame.cd:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                local font = region:GetFont()
                if font then region:SetFont(font, db.fontSize, "OUTLINE") end
            end
        end
    end
end

-- 4. Show / Hide Logic
local function CancelHideTimer()
    if hideTimer then
        hideTimer:Cancel()
        hideTimer = nil
    end
end

local function StartFadeOut()
    hideTimer = nil
    if testModeActive then return end
    fading = true
    UIFrameFadeOut(frame, 0.2, frame:GetAlpha(), 0)
    C_Timer.After(0.2, function()
        if fading then
            fading = false
            if not testModeActive then frame:Hide() end
        end
    end)
end

local function ShowCooldownIcon(spellID)
    if not spellID or testModeActive then return end
    local cdInfo = C_Spell.GetSpellCooldown(spellID)
    if not cdInfo or cdInfo.isOnGCD then return end

    -- In Midnight, cooldown data can be a secret value during combat; treat
    -- secrets as "on cooldown" and let the Cooldown widget consume them.
    local startTime = cdInfo.startTime
    local hasCD = (issecretvalue and issecretvalue(startTime)) or (type(startTime) == "number" and startTime > 0)
    if not hasCD then return end

    local spellData = C_Spell.GetSpellInfo(spellID)
    if not (spellData and spellData.iconID) then return end

    local fromAlpha = frame:IsShown() and frame:GetAlpha() or 0
    fading = false
    frame.icon:SetTexture(spellData.iconID)
    frame.spellName:SetText(spellData.name)
    frame.cd:SetCooldown(startTime, cdInfo.duration)
    frame:Show()
    ApplySettings()
    UIFrameFadeIn(frame, 0.1, fromAlpha, CursorTimerDB.alpha)

    CancelHideTimer()
    hideTimer = C_Timer.NewTimer(CursorTimerDB.autoHide, StartFadeOut)
end

-- 5. Settings Menu
local function AddCheckbox(category, variable, key, name, tooltip)
    local setting = Settings.RegisterAddOnSetting(category, variable, key, CursorTimerDB,
        Settings.VarType.Boolean, name, defaults[key])
    Settings.SetOnValueChangedCallback(variable, ApplySettings)
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function AddSlider(category, variable, key, name, minValue, maxValue, step)
    local setting = Settings.RegisterAddOnSetting(category, variable, key, CursorTimerDB,
        Settings.VarType.Number, name, defaults[key])
    Settings.SetOnValueChangedCallback(variable, ApplySettings)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(category, setting, options)
end

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
            CancelHideTimer()
            if value then
                frame.icon:SetTexture(136071)
                frame.spellName:SetText("Polymorph")
                frame.cd:SetCooldown(GetTime(), 30)
                frame:Show()
                ApplySettings()
            else
                frame:Hide()
            end
        end
    )
    Settings.CreateCheckbox(category, testSetting, "Shows the icon permanently to adjust sliders.")

    -- Positioning
    AddSlider(category, "CT_X", "offsetX", "X Position", -100, 100, 1)
    AddSlider(category, "CT_Y", "offsetY", "Y Position", -100, 100, 1)

    -- Timing and Visibility
    AddSlider(category, "CT_AutoHide", "autoHide", "Visibility Duration", 0.1, 1.0, 0.05)
    AddSlider(category, "CT_Alpha", "alpha", "Overall Opacity", 0.1, 1.0, 0.05)

    -- Icon and Border
    AddCheckbox(category, "CT_ShowIcon", "showIcon", "Show Icon")
    AddSlider(category, "CT_Size", "size", "Icon Size", 20, 100, 1)
    AddCheckbox(category, "CT_ShowBorder", "showBorder", "Show Icon Border")
    AddSlider(category, "CT_BorderPadding", "borderPadding", "Border Offset", -10, 20, 1)
    AddSlider(category, "CT_BorderAlpha", "borderAlpha", "Border Intensity", 0, 1.0, 0.05)

    -- Text and Timer
    AddCheckbox(category, "CT_ShowTimer", "showTimer", "Show Timer Numbers")
    AddSlider(category, "CT_FontSize", "fontSize", "Timer Font Size", 10, 40, 1)
    AddCheckbox(category, "CT_ShowName", "showSpellName", "Show Spell Name")
    AddSlider(category, "CT_NameSize", "spellNameSize", "Spell Name Font Size", 8, 30, 1)

    Settings.RegisterAddOnCategory(category)
end

-- 6. Events
local ERR_SPELL_COOLDOWN = LE_GAME_ERR_SPELL_COOLDOWN or 50
local ERR_ABILITY_COOLDOWN = LE_GAME_ERR_ABILITY_COOLDOWN or 61

local lastAttemptedSpellID = nil
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitializeDB()
        SetupSettings()
        ApplySettings()
    elseif event == "UI_ERROR_MESSAGE" then
        if (arg1 == ERR_SPELL_COOLDOWN or arg1 == ERR_ABILITY_COOLDOWN) and lastAttemptedSpellID then
            ShowCooldownIcon(lastAttemptedSpellID)
        end
    end
end)

-- Macro Detection
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

-- 7. Cursor Tracking
-- Only fires while the frame is shown; everything except position is
-- applied event-driven in ApplySettings to keep this loop allocation-free.
frame:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if scale > 0 then
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (x / scale) + CursorTimerDB.offsetX,
            (y / scale) + CursorTimerDB.offsetY)
    end
end)

SLASH_CURSORTIMER1 = "/ct"
SlashCmdList["CURSORTIMER"] = function()
    if categoryHandle then
        Settings.OpenToCategory(categoryHandle:GetID())
    end
end
