ComfyBag = ComfyBag or {}
local A = ComfyBag

A.version = "0.6"
A.buildDate = "04.10.2026"

local function EnsureDefaults()
    if not A.db then return end
    A.db.bag = A.db.bag or {}
    local b = A.db.bag
    local defaults = {
        replaceOriginal = false,
        showBorder = true,
        showBackground = true,
        backgroundAlpha = 92,
        windowOpacity = 100,
        autoOpenMerchant = false,
        autoOpenBank = false,
        autoOpenMail = false,
        autoCloseContext = true,
    }
    for k, v in pairs(defaults) do if b[k] == nil then b[k] = v end end
end

local originalInitializeDB = A.InitializeDB
function A:InitializeDB(...)
    local result
    if originalInitializeDB then result = originalInitializeDB(self, ...) end
    EnsureDefaults()
    return result
end

local function SetPieceAlpha(piece, alpha)
    if piece and piece.SetAlpha then pcall(piece.SetAlpha, piece, alpha) end
end

local function SetNineSliceBorderAlpha(nine, alpha)
    if not nine then return end
    local pieces = {
        "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
        "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
    }
    for _, key in ipairs(pieces) do SetPieceAlpha(nine[key], alpha) end
end

function A:ApplyBagAppearance()
    EnsureDefaults()
    local f = self.bagFrame
    if not f or not self.db then return end
    local cfg = self.db.bag
    local opacity = math.max(0, math.min(100, tonumber(cfg.windowOpacity) or 100)) / 100
    local bgAlpha = math.max(0, math.min(100, tonumber(cfg.backgroundAlpha) or 92)) / 100
    local showBg = cfg.showBackground ~= false
    local showBorder = cfg.showBorder ~= false

    f:SetAlpha(opacity)
    SetNineSliceBorderAlpha(f.NineSlice, showBorder and 1 or 0)
    if f.Inset then
        SetNineSliceBorderAlpha(f.Inset.NineSlice, showBorder and 1 or 0)
        SetPieceAlpha(f.Inset.Bg, showBg and bgAlpha or 0)
    end
    SetPieceAlpha(f.Bg, showBg and bgAlpha or 0)
    SetPieceAlpha(f.TitleBg, showBorder and 1 or 0)
    SetPieceAlpha(f.TopTileStreaks, showBorder and 1 or 0)
end

local originalCreateBagWindow = A.CreateBagWindow
function A:CreateBagWindow(...)
    if originalCreateBagWindow then originalCreateBagWindow(self, ...) end
    if self.bagFrame and not self.bagFrame.__comfyAppearanceHook then
        self.bagFrame.__comfyAppearanceHook = true
        self.bagFrame:HookScript("OnShow", function() A:ApplyBagAppearance() end)
    end
    self:ApplyBagAppearance()
end

local originalRefreshFeature = A.RefreshFeature
function A:RefreshFeature(...)
    if originalRefreshFeature then originalRefreshFeature(self, ...) end
    self:ApplyBagAppearance()
end

function A:OpenBag()
    self:CreateBagWindow()
    if not self.db or not self.db.enabled then return end
    self.bagFrame:Show()
    self:RefreshFeature()
end

function A:CloseBag()
    if self.bagFrame then self.bagFrame:Hide() end
end

function A:ResetBagPosition()
    if not self.db then return end
    self.db.bagWindow = {point="CENTER", relativePoint="CENTER", x=0, y=0}
    if self.bagFrame then
        self.bagFrame:ClearAllPoints()
        self.bagFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function HideOriginalContainerFrames()
    if not A.db or not A.db.bag or not A.db.bag.replaceOriginal then return end
    local maxFrames = tonumber(_G.NUM_CONTAINER_FRAMES) or 20
    for i = 1, maxFrames do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then pcall(frame.Hide, frame) end
    end
    if _G.CombinedBagContainer and _G.CombinedBagContainer:IsShown() then pcall(_G.CombinedBagContainer.Hide, _G.CombinedBagContainer) end
end

local function DeferredHideOriginal()
    if C_Timer and C_Timer.After then C_Timer.After(0, HideOriginalContainerFrames) else HideOriginalContainerFrames() end
end

local function HookContainerFrame(frame)
    if not frame or frame.__ComfyBagReplaceHook or type(frame.HookScript) ~= "function" then return end
    frame.__ComfyBagReplaceHook = true
    frame:HookScript("OnShow", function(self)
        if A.db and A.db.bag and A.db.bag.replaceOriginal then
            if C_Timer and C_Timer.After then C_Timer.After(0, function() if self:IsShown() then self:Hide() end end) else self:Hide() end
        end
    end)
end

local function HookOriginalContainers()
    local maxFrames = tonumber(_G.NUM_CONTAINER_FRAMES) or 20
    for i = 1, maxFrames do HookContainerFrame(_G["ContainerFrame" .. i]) end
    HookContainerFrame(_G.CombinedBagContainer)
end

local function HookMainBagButtons()
    local names = {
        "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
        "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot",
    }
    for _, name in ipairs(names) do
        local button = _G[name]
        if button and not button.__ComfyBagClickHook and type(button.HookScript) == "function" then
            button.__ComfyBagClickHook = true
            button:HookScript("OnClick", function()
                if A.db and A.db.enabled and A.db.bag and A.db.bag.replaceOriginal then
                    A:ToggleBag()
                    DeferredHideOriginal()
                end
            end)
        end
    end
end

local function InstallBagFunctionHooks()
    if A.__bagFunctionHooksInstalled or type(hooksecurefunc) ~= "function" then return end
    A.__bagFunctionHooksInstalled = true

    if type(OpenAllBags) == "function" then
        hooksecurefunc("OpenAllBags", function()
            if A.db and A.db.enabled and A.db.bag and A.db.bag.replaceOriginal then
                A.__lastOriginalBagAction = "open"
                A.__lastOriginalBagActionAt = type(GetTime) == "function" and GetTime() or 0
                A:OpenBag(); DeferredHideOriginal()
            end
        end)
    end
    if type(CloseAllBags) == "function" then
        hooksecurefunc("CloseAllBags", function()
            if A.db and A.db.enabled and A.db.bag and A.db.bag.replaceOriginal then
                A.__lastOriginalBagAction = "close"
                A.__lastOriginalBagActionAt = type(GetTime) == "function" and GetTime() or 0
                A:CloseBag(); DeferredHideOriginal()
            end
        end)
    end
    if type(ToggleAllBags) == "function" then
        hooksecurefunc("ToggleAllBags", function()
            if not (A.db and A.db.enabled and A.db.bag and A.db.bag.replaceOriginal) then return end
            local now = type(GetTime) == "function" and GetTime() or 0
            if not A.__lastOriginalBagActionAt or (now - A.__lastOriginalBagActionAt) > 0.08 then A:ToggleBag() end
            A.__lastOriginalBagActionAt = nil
            A.__lastOriginalBagAction = nil
            DeferredHideOriginal()
        end)
    end
    if type(ContainerFrame_GenerateFrame) == "function" then
        hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
            HookContainerFrame(frame)
            DeferredHideOriginal()
        end)
    end
end

function A:ApplyOriginalBagReplacement()
    EnsureDefaults()
    HookOriginalContainers()
    HookMainBagButtons()
    InstallBagFunctionHooks()
    if self.db.bag.replaceOriginal then DeferredHideOriginal() end
end

local function AutoOpen(context)
    if not A.db or not A.db.enabled or not A.db.bag then return end
    local enabled = context == "merchant" and A.db.bag.autoOpenMerchant
        or context == "bank" and A.db.bag.autoOpenBank
        or context == "mail" and A.db.bag.autoOpenMail
    if enabled then A._autoOpenedContext = context; A:OpenBag() end
end

local function AutoClose(context)
    if not A.db or not A.db.bag or not A.db.bag.autoCloseContext then return end
    if A._autoOpenedContext == context then A._autoOpenedContext = nil; A:CloseBag() end
end

local originalInitializeFeature = A.InitializeFeature
function A:InitializeFeature(...)
    if originalInitializeFeature then originalInitializeFeature(self, ...) end
    EnsureDefaults()
    self:ApplyOriginalBagReplacement()

    local e = CreateFrame("Frame")
    local events = {"PLAYER_ENTERING_WORLD","MERCHANT_SHOW","MERCHANT_CLOSED","BANKFRAME_OPENED","BANKFRAME_CLOSED","MAIL_SHOW","MAIL_CLOSED"}
    for _, ev in ipairs(events) do pcall(e.RegisterEvent, e, ev) end
    e:SetScript("OnEvent", function(_, ev)
        if ev == "PLAYER_ENTERING_WORLD" then A:ApplyOriginalBagReplacement()
        elseif ev == "MERCHANT_SHOW" then AutoOpen("merchant")
        elseif ev == "MERCHANT_CLOSED" then AutoClose("merchant")
        elseif ev == "BANKFRAME_OPENED" then AutoOpen("bank")
        elseif ev == "BANKFRAME_CLOSED" then AutoClose("bank")
        elseif ev == "MAIL_SHOW" then AutoOpen("mail")
        elseif ev == "MAIL_CLOSED" then AutoClose("mail") end
    end)
    self.enhancementEvents = e
end

local originalBuildGeneralOptions = A.BuildGeneralOptions
function A:BuildGeneralOptions(page, ui)
    if originalBuildGeneralOptions then originalBuildGeneralOptions(self, page, ui) end
    EnsureDefaults()
    if not ui then return end

    ui.CreateCheck(page, "Originaltaschen ersetzen", 380, -120,
        function() return A.db.bag.replaceOriginal end,
        function(v) A.db.bag.replaceOriginal = v; A:ApplyOriginalBagReplacement() end)
    ui.CreateCheck(page, "Taschen-Rahmen anzeigen", 380, -155,
        function() return A.db.bag.showBorder end,
        function(v) A.db.bag.showBorder = v; A:ApplyBagAppearance() end)
    ui.CreateCheck(page, "Taschen-Hintergrund anzeigen", 380, -190,
        function() return A.db.bag.showBackground end,
        function(v) A.db.bag.showBackground = v; A:ApplyBagAppearance() end)
    ui.CreateCheck(page, "Beim Händler öffnen", 380, -225,
        function() return A.db.bag.autoOpenMerchant end,
        function(v) A.db.bag.autoOpenMerchant = v end)
    ui.CreateCheck(page, "Bei Bank öffnen", 380, -260,
        function() return A.db.bag.autoOpenBank end,
        function(v) A.db.bag.autoOpenBank = v end)
    ui.CreateCheck(page, "Bei Post öffnen", 380, -295,
        function() return A.db.bag.autoOpenMail end,
        function(v) A.db.bag.autoOpenMail = v end)
    ui.CreateCheck(page, "Automatisch wieder schließen", 380, -330,
        function() return A.db.bag.autoCloseContext end,
        function(v) A.db.bag.autoCloseContext = v end)

    ui.CreateSlider(page, "Hintergrund-Transparenz", 0, 100, 5, 35, -415,
        function() return A.db.bag.backgroundAlpha end,
        function(v) A.db.bag.backgroundAlpha = math.floor(v + 0.5); A:ApplyBagAppearance() end,
        function(v) return math.floor(v + 0.5) .. "%" end)
    ui.CreateSlider(page, "Fenster-Deckkraft", 0, 100, 5, 365, -415,
        function() return A.db.bag.windowOpacity end,
        function(v) A.db.bag.windowOpacity = math.floor(v + 0.5); A:ApplyBagAppearance() end,
        function(v) return math.floor(v + 0.5) .. "%" end)
    ui.CreateButton(page, "Taschenposition zurücksetzen", 380, -365, 210, function() A:ResetBagPosition() end)
end
