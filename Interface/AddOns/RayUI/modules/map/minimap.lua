﻿local R, L, P, G = unpack(select(2, ...)) --Import: Engine, Locales, ProfileDB, GlobalDB
local MM = R:NewModule("MiniMap", "AceEvent-3.0", "AceHook-3.0")

--Cache global variables
--Lua functions
local _G = _G
local select, unpack, pairs, string, math = select, unpack, pairs, string, math
local strfind, gsub = string.find, string.gsub
local floor = math.floor
local sqrt = math.sqrt

--WoW API / Variables
local CreateFrame = CreateFrame
local GetWorldPVPAreaInfo = GetWorldPVPAreaInfo
local GameTime_UpdateTooltip = GameTime_UpdateTooltip
local GetMinimapShape = GetMinimapShape
local UIFrameFadeIn = UIFrameFadeIn
local UIFrameFadeOut = UIFrameFadeOut
local CalendarGetNumPendingInvites = CalendarGetNumPendingInvites
local ToggleCharacter = ToggleCharacter
local ShowUIPanel = ShowUIPanel
local HideUIPanel = HideUIPanel
local ToggleAchievementFrame = ToggleAchievementFrame
local ToggleFriendsFrame = ToggleFriendsFrame
local IsInGuild = IsInGuild
local ToggleFrame = ToggleFrame
local IsAddOnLoaded = IsAddOnLoaded
local LoadAddOn = LoadAddOn
local ToggleCollectionsJournal = ToggleCollectionsJournal
local ToggleHelpFrame = ToggleHelpFrame
local GarrisonLandingPageMinimapButton_OnClick = GarrisonLandingPageMinimapButton_OnClick
local IsShiftKeyDown = IsShiftKeyDown
local GetCursorPosition = GetCursorPosition
local Minimap_SetPing = Minimap_SetPing
local Minimap_ZoomIn = Minimap_ZoomIn
local Minimap_ZoomOut = Minimap_ZoomOut
local ToggleGuildFrame = ToggleGuildFrame
local ToggleLFDParentFrame = ToggleLFDParentFrame
local Minimap_OnClick = Minimap_OnClick
local GetNumTrackingTypes = GetNumTrackingTypes
local UnitClass = UnitClass
local ClearAllTracking = ClearAllTracking
local GetTrackingInfo = GetTrackingInfo
local MiniMapTrackingDropDown_IsNoTrackingActive = MiniMapTrackingDropDown_IsNoTrackingActive
local MiniMapTrackingDropDownButton_IsActive = MiniMapTrackingDropDownButton_IsActive
local MiniMapTracking_SetTracking = MiniMapTracking_SetTracking

--Global variables that we don't cache, list them here for the mikk's Find Globals script
-- GLOBALS: GameTooltip, Minimap, HIGHLIGHT_FONT_COLOR, NORMAL_FONT_COLOR, TimeManagerClockButton, Settings
-- GLOBALS: TIMEMANAGER_ALARM_TOOLTIP_TURN_OFF, GAMETIME_TOOLTIP_TOGGLE_CLOCK, GarrisonLandingPageMinimapButton
-- GLOBALS: MinimapCluster, MiniMapTracking, MiniMapInstanceDifficulty, Lib_UIDropDownMenu_CreateInfo, MINIMAP_TRACKING_NONE
-- GLOBALS: GuildInstanceDifficulty, MiniMapChallengeMode, MiniMapMailFrame, MiniMapMailIcon, GameTimeCalendarInvitesTexture
-- GLOBALS: FeedbackUIButton, StreamingIcon, MinimapZoneText, DropDownList1, LFGDungeonReadyStatus, HelpOpenTicketButton
-- GLOBALS: CHARACTER_BUTTON, SPELLBOOK_ABILITIES_BUTTON, TALENTS_BUTTON, ACHIEVEMENT_BUTTON, SOCIAL_BUTTON
-- GLOBALS: LookingForGuildFrame, StopwatchFrame, ACHIEVEMENTS_GUILD_TAB, ENCOUNTER_JOURNAL, COLLECTIONS
-- GLOBALS: LFG_TITLE, BLIZZARD_STORE, HELP_BUTTON, GARRISON_LANDING_PAGE_TITLE, CALENDAR, LOOT_ROLLS
-- GLOBALS: SpellBookFrame, PlayerTalentFrame, GuildFrame, EncounterJournal, RaidFinderFrame, StoreMicroButton
-- GLOBALS: CalendarFrame, LootHistoryFrame, MiniMapTrackingDropDown, BlizzardStopwatchOptions, GameTimeFrame, TimeManagerFrame
-- GLOBALS: GuildFrame_LoadUI, EncounterJournal_LoadUI, TalentFrame_LoadUI, UIParent, MinimapButtonCollectFrame
-- GLOBALS: MinimapZoomIn, MinimapZoomOut, Lib_UIDropDownMenu_AddButton, HUNTER_TRACKING, HUNTER_TRACKING_TEXT, TOWNSFOLK_TRACKING_TEXT
-- GLOBALS: TOWNSFOLK, LIB_UIDROPDOWNMENU_MENU_VALUE, Lib_ToggleDropDownMenu

MM.modName = L["小地图"]

local function MiniMapTrackingDropDown_Initialize(self, level)
    local name, texture, active, category, nested, numTracking;
    local count = GetNumTrackingTypes();
    local info;
    local _, class = UnitClass("player");

    if (level == 1) then
        info = Lib_UIDropDownMenu_CreateInfo();
        info.text=MINIMAP_TRACKING_NONE;
        info.checked = MiniMapTrackingDropDown_IsNoTrackingActive;
        info.func = ClearAllTracking;
        info.icon = nil;
        info.arg1 = nil;
        info.isNotRadio = true;
        info.keepShownOnClick = true;
        Lib_UIDropDownMenu_AddButton(info, level);

        if (class == "HUNTER") then --only show hunter dropdown for hunters
            numTracking = 0;
            -- make sure there are at least two options in dropdown
            for id=1, count do
                name, texture, active, category, nested = GetTrackingInfo(id);
                if (nested == HUNTER_TRACKING and category == "spell") then
                    numTracking = numTracking + 1;
                end
            end
            if (numTracking > 1) then
                info.text = HUNTER_TRACKING_TEXT;
                info.func = nil;
                info.notCheckable = true;
                info.keepShownOnClick = false;
                info.hasArrow = true;
                info.value = HUNTER_TRACKING;
                Lib_UIDropDownMenu_AddButton(info, level)
            end
        end

        info.text = TOWNSFOLK_TRACKING_TEXT;
        info.func = nil;
        info.notCheckable = true;
        info.keepShownOnClick = false;
        info.hasArrow = true;
        info.value = TOWNSFOLK;
        Lib_UIDropDownMenu_AddButton(info, level)
    end
    for id=1, count do
        name, texture, active, category, nested = GetTrackingInfo(id);
        info = Lib_UIDropDownMenu_CreateInfo();
        info.text = name;
        info.checked = MiniMapTrackingDropDownButton_IsActive;
        info.func = MiniMapTracking_SetTracking;
        info.icon = texture;
        info.arg1 = id;
        info.isNotRadio = true;
        info.keepShownOnClick = true;
        if ( category == "spell" ) then
            info.tCoordLeft = 0.0625;
            info.tCoordRight = 0.9;
            info.tCoordTop = 0.0625;
            info.tCoordBottom = 0.9;
        else
            info.tCoordLeft = 0;
            info.tCoordRight = 1;
            info.tCoordTop = 0;
            info.tCoordBottom = 1;
        end
        if (level == 1 and
            (nested < 0 or -- this tracking shouldn't be nested
                (nested == HUNTER_TRACKING and class ~= "HUNTER") or
                (numTracking == 1 and category == "spell"))) then -- this is a hunter tracking ability, but you only have one
            Lib_UIDropDownMenu_AddButton(info, level);
        elseif (level == 2 and (nested == TOWNSFOLK or (nested == HUNTER_TRACKING and class == "HUNTER")) and nested == LIB_UIDROPDOWNMENU_MENU_VALUE) then
            Lib_UIDropDownMenu_AddButton(info, level);
        end
    end
end
local RayUI_MinimapTrackDropDown = CreateFrame("Frame", "RayUI_MinimapTrackDropDown", UIParent, "Lib_UIDropDownMenuTemplate")
RayUI_MinimapTrackDropDown:SetID(1)
RayUI_MinimapTrackDropDown:SetClampedToScreen(true)
RayUI_MinimapTrackDropDown:Hide()
Lib_UIDropDownMenu_Initialize(RayUI_MinimapTrackDropDown, MiniMapTrackingDropDown_Initialize, "MENU");
RayUI_MinimapTrackDropDown.noResize = true

local menuFrame = CreateFrame("Frame", "RayUI_MinimapRightClickMenu", R.UIParent)
local menuList = {
    {text = CHARACTER_BUTTON,
        func = function() ToggleCharacter("PaperDollFrame") end},
    {text = SPELLBOOK_ABILITIES_BUTTON,
        func = function() if not SpellBookFrame:IsShown() then ShowUIPanel(SpellBookFrame) else HideUIPanel(SpellBookFrame) end end},
    {text = TALENTS_BUTTON,
        func = function()
            if not PlayerTalentFrame then
                TalentFrame_LoadUI()
            end

            if not PlayerTalentFrame:IsShown() then
                ShowUIPanel(PlayerTalentFrame)
            else
                HideUIPanel(PlayerTalentFrame)
            end
        end
    },
    {text = ACHIEVEMENT_BUTTON,
        func = function() ToggleAchievementFrame() end},
    {text = SOCIAL_BUTTON,
        func = function() ToggleFriendsFrame() end},
    {text = ACHIEVEMENTS_GUILD_TAB,
        func = function() ToggleGuildFrame() end},
    {text = ENCOUNTER_JOURNAL,
        func = function() if not IsAddOnLoaded("Blizzard_EncounterJournal") then EncounterJournal_LoadUI() end ToggleFrame(EncounterJournal) end},
    {text = COLLECTIONS,
        func = function() ToggleCollectionsJournal() end},
    {text = LFG_TITLE,
        func = function() ToggleLFDParentFrame() end},
    {text = BLIZZARD_STORE,
        func = function() StoreMicroButton:Click() end},
    {text = HELP_BUTTON,
        func = function() ToggleHelpFrame() end},
    {text = GARRISON_LANDING_PAGE_TITLE,
        func = function() GarrisonLandingPageMinimapButton_OnClick() end},
    {text = CALENDAR,
        func = function() GameTimeFrame:Click() end},
    {text = LOOT_ROLLS,
        func = function() ToggleFrame(LootHistoryFrame) end},
}

function MM:TimeManagerClockButton_UpdateTooltip()
    GameTooltip:SetOwner(Minimap, "ANCHOR_BOTTOMRIGHT", 5, 142)
    GameTooltip:ClearLines()

    if ( TimeManagerClockButton.alarmFiring ) then
        if ( gsub(Settings.alarmMessage, "%s", "") ~= "" ) then
            GameTooltip:AddLine(Settings.alarmMessage, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, 1)
            GameTooltip:AddLine(" ")
        end
        GameTooltip:AddLine(TIMEMANAGER_ALARM_TOOLTIP_TURN_OFF)
    else
        GameTime_UpdateTooltip()
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(GAMETIME_TOOLTIP_TOGGLE_CLOCK)
    end
    GameTooltip:Show()
end

local function PositionGarrisonButton(self, screenQuadrant)
    GarrisonLandingPageMinimapButton:SetScale(0.7)
    screenQuadrant = screenQuadrant or R:GetScreenQuadrant(self)
    if strfind(screenQuadrant, "RIGHT") then
        GarrisonLandingPageMinimapButton:ClearAllPoints()
        GarrisonLandingPageMinimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -100, 10)
    else
        GarrisonLandingPageMinimapButton:ClearAllPoints()
        GarrisonLandingPageMinimapButton:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 100, 10)
    end
end

function MM:SkinMiniMap()
    local frames = {
        "GameTimeFrame",
        "MinimapBorderTop",
        "MinimapNorthTag",
        "MinimapBorder",
        "MinimapZoneTextButton",
        "MinimapZoomOut",
        "MinimapZoomIn",
        "MiniMapVoiceChatFrame",
        "MiniMapWorldMapButton",
        "MiniMapMailBorder",
    }
    for i in pairs(frames) do
        _G[frames[i]]:Kill()
    end
    Minimap:Size(175, 175)
    Minimap:CreateShadow("Background", nil, true)
    Minimap:SetPlayerTexture("Interface\\AddOns\\RayUI\\media\\MinimapArrow")
    Minimap.shadow:SetBackdrop( {
            edgeFile = R["media"].glow,
            bgFile = R["media"].blank,
            edgeSize = R:Scale(4),
            tile = false,
            tileSize = 0,
            insets = {left = R:Scale(4), right = R:Scale(4), top = R:Scale(4), bottom = R:Scale(4)},
        })
    MinimapCluster:EnableMouse(false)
    MiniMapTracking:Hide()
    MiniMapInstanceDifficulty:ClearAllPoints()
    MiniMapInstanceDifficulty:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 2, 2)
    MiniMapInstanceDifficulty:SetScale(0.75)
    MiniMapInstanceDifficulty:SetFrameStrata("LOW")
    GuildInstanceDifficulty:ClearAllPoints()
    GuildInstanceDifficulty:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 2, 2)
    GuildInstanceDifficulty:SetScale(0.75)
    GuildInstanceDifficulty:SetFrameStrata("LOW")
    MiniMapChallengeMode:SetParent(MinimapCluster)
    MiniMapChallengeMode:ClearAllPoints()
    MiniMapChallengeMode:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, -2)
    MiniMapChallengeMode:SetScale(0.75)
    MiniMapChallengeMode:SetFrameStrata("LOW")
    MiniMapMailFrame:ClearAllPoints()
    MiniMapMailFrame:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 2, -6)
    MiniMapMailIcon:SetTexture("Interface\\AddOns\\RayUI\\media\\mail")
    GameTimeCalendarInvitesTexture:ClearAllPoints()
    GameTimeCalendarInvitesTexture:SetParent(Minimap)
    GameTimeCalendarInvitesTexture:SetPoint("TOPRIGHT")
    if FeedbackUIButton then
        FeedbackUIButton:Kill()
    end
    if StreamingIcon then
        StreamingIcon:ClearAllPoints()
        StreamingIcon:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 8, 8)
        StreamingIcon:SetScale(0.8)
    end
    function GetMinimapShape()
        return "SQUARE"
    end
    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
    local zoneTextFrame = CreateFrame("Frame", nil, R.UIParent)
    zoneTextFrame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 10)
    zoneTextFrame:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 0, 10)
    zoneTextFrame:SetHeight(19)
    zoneTextFrame:SetAlpha(0)
    MinimapZoneText:SetParent(zoneTextFrame)
    MinimapZoneText:ClearAllPoints()
    MinimapZoneText:SetPoint("LEFT", 2, 1)
    MinimapZoneText:SetPoint("RIGHT", -2, 1)
    MinimapZoneText:SetFont(R["media"].font, R["media"].fontsize, R["media"].fontflag)
    Minimap:HookScript("OnEnter", function(self)
            UIFrameFadeIn(zoneTextFrame, 0.3, zoneTextFrame:GetAlpha(), 1)
        end)
    Minimap:HookScript("OnLeave", function(self)
            UIFrameFadeOut(zoneTextFrame, 0.3, zoneTextFrame:GetAlpha(), 0)
        end)
    DropDownList1:SetClampedToScreen(true)
    LFGDungeonReadyStatus:SetClampedToScreen(true)
    HelpOpenTicketButton:SetParent(Minimap)
    HelpOpenTicketButton:ClearAllPoints()
    HelpOpenTicketButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT")
end

function MM:CheckMail()
    local inv = CalendarGetNumPendingInvites()
    local mail = MiniMapMailFrame:IsShown() and true or false
    if inv > 0 and mail then -- New invites and mail
        Minimap.shadow:SetBackdropBorderColor(1, .5, 0)
        R:GetModule("Skins"):CreatePulse(Minimap.shadow, 1, 1)
    elseif inv > 0 and not mail then -- New invites and no mail
        Minimap.shadow:SetBackdropBorderColor(1, 30/255, 60/255)
        R:GetModule("Skins"):CreatePulse(Minimap.shadow, 1, 1)
    elseif inv==0 and mail then -- No invites and new mail
        Minimap.shadow:SetBackdropBorderColor(.5, 1, 1)
        R:GetModule("Skins"):CreatePulse(Minimap.shadow, 1, 1)
    else -- None of the above
        Minimap.shadow:SetScript("OnUpdate", nil)
        if not R.PixelMode then
            Minimap.shadow:SetAlpha(1)
        else
            Minimap.shadow:SetAlpha(0)
        end
        Minimap.shadow:SetBackdropBorderColor(unpack(R["media"].bordercolor))
    end
end

function MM:ADDON_LOADED(event, addon)
    if addon == "Blizzard_TimeManager" then
        self:UnregisterEvent(event)
        if ( not BlizzardStopwatchOptions ) then
            BlizzardStopwatchOptions = {}
        end

        if ( BlizzardStopwatchOptions.position ) then
            StopwatchFrame:ClearAllPoints()
            StopwatchFrame:SetPoint("CENTER", R.UIParent, "BOTTOMLEFT", BlizzardStopwatchOptions.position.x, BlizzardStopwatchOptions.position.y)
            StopwatchFrame:SetUserPlaced(true)
        else
            StopwatchFrame:SetPoint("TOPRIGHT", R.UIParent, "TOPRIGHT", -250, -300)
        end
        self:RawHook("TimeManagerClockButton_UpdateTooltip", true)

        local clockFrame, clockTime = TimeManagerClockButton:GetRegions()
        clockFrame:Hide()
        clockTime:SetFont(R["media"].font, R["media"].fontsize, R["media"].fontflag)
        clockTime:SetTextColor(1,1,1)
        TimeManagerClockButton:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, -3)
        TimeManagerClockButton:SetScript("OnClick", function(_,btn)
                if btn == "LeftButton" then
                    ToggleFrame(TimeManagerFrame)
                end
                if btn == "RightButton" then
                    GameTimeFrame:Click()
                end
            end)
    end
end

function MM:Minimap_OnMouseUp(btn)
    local position = self:GetPoint()
    if btn == "MiddleButton" or (btn == "RightButton" and IsShiftKeyDown()) then
        if position:match("LEFT") then
            R:DropDown(menuList, menuFrame)
        else
            R:DropDown(menuList, menuFrame, -160, 0)
        end
    elseif btn == "RightButton" then
        Lib_ToggleDropDownMenu(1, nil, RayUI_MinimapTrackDropDown, "cursor")
    else
        Minimap_OnClick(self)
    end
end

function MM:CreateMenu()
    Minimap:SetScript("OnMouseUp", MM.Minimap_OnMouseUp)
    R:GetModule("Skins"):CreateBD(menuFrame)
    R:GetModule("Skins"):CreateStripesThin(menuFrame)
end

function MM:Info()
    return L["|cff7aa6d6Ray|r|cffff0000U|r|cff7aa6d6I|r小地图模块."]
end

local function MinimapPostDrag(self, screenQuadrant)
    MM:PositionButtonCollector(self, screenQuadrant)
    PositionGarrisonButton(self, screenQuadrant)
    if screenQuadrant == "TOPLEFT" then
        UIParent:SetAttribute("LEFT_OFFSET", MinimapButtonCollectFrame:GetLeft() + MinimapButtonCollectFrame:GetWidth() + 5)
    else
        UIParent:SetAttribute("LEFT_OFFSET", 16)
    end
end

function MM:Minimap_OnMouseWheel(d)
    if d > 0 then
        MinimapZoomIn:Click()
    elseif d < 0 then
        MinimapZoomOut:Click()
    end
end

function MM:Initialize()
    self:SkinMiniMap()
    self:CreateMenu()
    self:ButtonCollector()

    Minimap:ClearAllPoints()
    Minimap:Point("TOPLEFT", R.UIParent, "TOPLEFT", 10, -20)
    Minimap:SetFrameLevel(10)
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", MM.Minimap_OnMouseWheel)

    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES", "CheckMail")
    self:RegisterEvent("UPDATE_PENDING_MAIL", "CheckMail")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckMail")
    self:HookScript(MiniMapMailFrame, "OnHide", "CheckMail")
    self:HookScript(MiniMapMailFrame, "OnShow", "CheckMail")

    R:CreateMover(Minimap, "MinimapMover", L["小地图锚点"], true, MinimapPostDrag)
end

R:RegisterModule(MM:GetName())
