local ADDON_NAME, MazeHelper = ...;
local L, E, M = MazeHelper.L, MazeHelper.E, MazeHelper.M;

-- Lua API
local tonumber = tonumber;

-- WoW API
local IsInRaid, IsInGroup, UnitIsGroupLeader, GetMinimapZoneText = IsInRaid, IsInGroup, UnitIsGroupLeader, GetMinimapZoneText;

local ADDON_COMM_PREFIX = 'MAZEHELPER';
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_COMM_PREFIX);

local playerNameWithRealm, playerRole, inInstance, bossKilled, inEncounter, isMinimized;
local startedInMinMode = false;

local FRAME_SIZE = 300;
local X_OFFSET = 2;
local Y_OFFSET = -2;
local BUTTON_SIZE = 64;

local EMPTY_STRING = ''; -- NANO-OPTIMIZATION!

local MAX_BUTTONS = 8;
local MAX_ACTIVE_BUTTONS = 4;
local NUM_ACTIVE_BUTTONS = 0;

local RESERVED_BUTTONS_SEQUENCE = {
    [1] = false,
    [2] = false,
    [3] = false,
    [4] = false,
};

local PASSED_COUNTER = 1;
local SOLUTION_BUTTON_ID;
local PREDICTED_SOLUTION_BUTTON_ID;

local MISTCALLER_ENCOUNTER_ID = 2392;

local buttons = {}
local buttonsData = {
    [1] = {
        name = L['MAZE_HELPER_LEAF_FULL_CIRCLE'],
        aname = L['MAZE_HELPER_ANNOUNCE_LEAF_FULL_CIRCLE'],
        coords = M.Symbols.COORDS_COLOR.LEAF_CIRCLE_FILL,
        coords_white = M.Symbols.COORDS_WHITE.LEAF_CIRCLE_FILL,
        leaf = true,
        flower = false,
        circle = true,
        fill = true,
    },
    [2] = {
        name = L['MAZE_HELPER_LEAF_NOFULL_CIRCLE'],
        aname = L['MAZE_HELPER_ANNOUNCE_LEAF_NOFULL_CIRCLE'],
        coords = M.Symbols.COORDS_COLOR.LEAF_CIRCLE_NOFILL,
        coords_white = M.Symbols.COORDS_WHITE.LEAF_CIRCLE_NOFILL,
        leaf = true,
        flower = false,
        circle = true,
        fill = false,
    },
    [3] = {
        name = L['MAZE_HELPER_FLOWER_FULL_CIRCLE'],
        aname = L['MAZE_HELPER_ANNOUNCE_FLOWER_FULL_CIRCLE'],
        coords = M.Symbols.COORDS_COLOR.FLOWER_CIRCLE_FILL,
        coords_white = M.Symbols.COORDS_WHITE.FLOWER_CIRCLE_FILL,
        leaf = false,
        flower = true,
        circle = true,
        fill = true,
    },
    [4] = {
        name = L['MAZE_HELPER_FLOWER_NOFULL_CIRCLE'],
        aname = L['MAZE_HELPER_ANNOUNCE_FLOWER_NOFULL_CIRCLE'],
        coords = M.Symbols.COORDS_COLOR.FLOWER_CIRCLE_NOFILL,
        coords_white = M.Symbols.COORDS_WHITE.FLOWER_CIRCLE_NOFILL,
        leaf = false,
        flower = true,
        circle = true,
        fill = false,
    },
    [5] = {
        name = L['MAZE_HELPER_LEAF_FULL_NOCIRCLE'],
        aname = L['MAZE_HELPER_ANNOUNCE_LEAF_FULL_NOCIRCLE'],
        coords = M.Symbols.COORDS_COLOR.LEAF_NOCIRCLE_FILL,
        coords_white = M.Symbols.COORDS_WHITE.LEAF_NOCIRCLE_FILL,
        leaf = true,
        flower = false,
        circle = false,
        fill = true,
    },
    [6] = {
        name = L['MAZE_HELPER_LEAF_NOFULL_NOCIRCLE'],
        aname = L['MAZE_HELPER_ANNOUNCE_LEAF_NOFULL_NOCIRCLE'],
        coords = M.Symbols.COORDS_COLOR.LEAF_NOCIRCLE_NOFILL,
        coords_white = M.Symbols.COORDS_WHITE.LEAF_NOCIRCLE_NOFILL,
        leaf = true,
        flower = false,
        circle = false,
        fill = false,
    },
    [7] = {
        name = L['MAZE_HELPER_FLOWER_FULL_NOCIRCLE'],
        aname = L['MAZE_HELPER_ANNOUNCE_FLOWER_FULL_NOCIRCLE'],
        coords = M.Symbols.COORDS_COLOR.FLOWER_NOCIRCLE_FILL,
        coords_white = M.Symbols.COORDS_WHITE.FLOWER_NOCIRCLE_FILL,
        leaf = false,
        flower = true,
        circle = false,
        fill = true,
    },
    [8] = {
        name = L['MAZE_HELPER_FLOWER_NOFULL_NOCIRCLE'],
        aname = L['MAZE_HELPER_ANNOUNCE_FLOWER_NOFULL_NOCIRCLE'],
        coords = M.Symbols.COORDS_COLOR.FLOWER_NOCIRCLE_NOFILL,
        coords_white = M.Symbols.COORDS_WHITE.FLOWER_NOCIRCLE_NOFILL,
        leaf = false,
        flower = true,
        circle = false,
        fill = false,
    },
};

local function GetPartyChatType()
    return (not IsInRaid() and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and 'INSTANCE_CHAT' or (IsInGroup(LE_PARTY_CATEGORY_HOME) and 'PARTY' or false);
end

local function BetterOnDragStop(frame)
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint();

    frame:StopMovingOrSizing();

    frame:ClearAllPoints();
    PixelUtil.SetPoint(frame, point, relativeTo, relativePoint, xOfs, yOfs);
end

local function SwitchSymbolsColorMode(colored)
    for i = 1, MAX_BUTTONS do
        buttons[i].Icon:SetTexCoord(unpack(colored and buttonsData[i].coords or buttonsData[i].coords_white));
    end
end

MazeHelper.frame = CreateFrame('Frame', 'ST_Maze_Helper', UIParent);
PixelUtil.SetPoint(MazeHelper.frame, 'CENTER', UIParent, 'CENTER', -FRAME_SIZE, FRAME_SIZE);
PixelUtil.SetSize(MazeHelper.frame, FRAME_SIZE + X_OFFSET * (MAX_ACTIVE_BUTTONS - 1), FRAME_SIZE * 3/4);
MazeHelper.frame:EnableMouse(true);
MazeHelper.frame:SetMovable(true);
MazeHelper.frame:SetClampedToScreen(true);
MazeHelper.frame:RegisterForDrag('LeftButton');
MazeHelper.frame:SetScript('OnDragStart', function(self)
    if self:IsMovable() then
        self:StartMoving();
    end
end);
MazeHelper.frame:SetScript('OnDragStop', BetterOnDragStop);

do
    local AnimationFadeInGroup = MazeHelper.frame:CreateAnimationGroup();
    local fadeIn = AnimationFadeInGroup:CreateAnimation('Alpha');
    fadeIn:SetDuration(0.3);
    fadeIn:SetFromAlpha(0);
    fadeIn:SetToAlpha(1);
    fadeIn:SetStartDelay(0);

    MazeHelper.frame:HookScript('OnShow', function()
        AnimationFadeInGroup:Play();
    end);
end

-- Background
MazeHelper.frame.background = MazeHelper.frame:CreateTexture(nil, 'BACKGROUND');
PixelUtil.SetPoint(MazeHelper.frame.background, 'TOPLEFT', MazeHelper.frame, 'TOPLEFT', -15, 22);
PixelUtil.SetPoint(MazeHelper.frame.background, 'BOTTOMRIGHT', MazeHelper.frame, 'BOTTOMRIGHT', 15, -98);
MazeHelper.frame.background:SetTexture(M.BACKGROUND_WHITE);
MazeHelper.frame.background:SetVertexColor(0.05, 0.05, 0.05);
MazeHelper.frame.background:SetAlpha(0.85);

-- Close Button
MazeHelper.frame.CloseButton = CreateFrame('Button', nil, MazeHelper.frame);
PixelUtil.SetPoint(MazeHelper.frame.CloseButton, 'TOPRIGHT', MazeHelper.frame, 'TOPRIGHT', -8, -4);
PixelUtil.SetSize(MazeHelper.frame.CloseButton, 10, 10);
MazeHelper.frame.CloseButton:SetNormalTexture(M.Icons.TEXTURE);
MazeHelper.frame.CloseButton:GetNormalTexture():SetTexCoord(unpack(M.Icons.COORDS.CROSS_WHITE));
MazeHelper.frame.CloseButton:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7, 1);
MazeHelper.frame.CloseButton:SetHighlightTexture(M.Icons.TEXTURE, 'BLEND');
MazeHelper.frame.CloseButton:GetHighlightTexture():SetTexCoord(unpack(M.Icons.COORDS.CROSS_WHITE));
MazeHelper.frame.CloseButton:GetHighlightTexture():SetVertexColor(1, 0.85, 0, 1);
MazeHelper.frame.CloseButton:SetScript('OnClick', function()
    if MazeHelper.frame.Settings:IsShown() then
        MazeHelper.frame.SettingsButton:Click();
    end

    MazeHelper.frame:SetShown(false);
end);

-- Settings Button
MazeHelper.frame.SettingsButton = CreateFrame('Button', nil, MazeHelper.frame);
PixelUtil.SetPoint(MazeHelper.frame.SettingsButton, 'RIGHT', MazeHelper.frame.CloseButton, 'LEFT', -10, 0);
PixelUtil.SetSize(MazeHelper.frame.SettingsButton, 11, 11);
MazeHelper.frame.SettingsButton:SetNormalTexture(M.Icons.TEXTURE);
MazeHelper.frame.SettingsButton:GetNormalTexture():SetTexCoord(unpack(M.Icons.COORDS.GEAR_WHITE));
MazeHelper.frame.SettingsButton:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7, 1);
MazeHelper.frame.SettingsButton:SetHighlightTexture(M.Icons.TEXTURE, 'BLEND');
MazeHelper.frame.SettingsButton:GetHighlightTexture():SetTexCoord(unpack(M.Icons.COORDS.GEAR_WHITE));
MazeHelper.frame.SettingsButton:GetHighlightTexture():SetVertexColor(1, 0.85, 0, 1);
MazeHelper.frame.SettingsButton:SetScript('OnClick', function(self)
    local settingsIsShown = MazeHelper.frame.Settings:IsShown();

    if not settingsIsShown then
        self:LockHighlight();
    else
        self:UnlockHighlight();
    end

    MazeHelper.frame.Settings:SetShown(not settingsIsShown);
    MazeHelper.frame.MainHolder:SetShown(settingsIsShown);
    MazeHelper.frame.MinButton:SetShown(settingsIsShown);
end);

-- Minimize Button
MazeHelper.frame.MinButton = CreateFrame('Button', nil, MazeHelper.frame);
PixelUtil.SetPoint(MazeHelper.frame.MinButton, 'RIGHT', MazeHelper.frame.SettingsButton, 'LEFT', -8, 0);
PixelUtil.SetSize(MazeHelper.frame.MinButton, 14, 14);
MazeHelper.frame.MinButton.icon = MazeHelper.frame.MinButton:CreateTexture(nil, 'OVERLAY');
PixelUtil.SetPoint(MazeHelper.frame.MinButton.icon, 'BOTTOM', MazeHelper.frame.MinButton, 'BOTTOM', 0, 2);
PixelUtil.SetSize(MazeHelper.frame.MinButton.icon, 10, 2);
MazeHelper.frame.MinButton.icon:SetTexture('Interface\\Buttons\\WHITE8x8');
MazeHelper.frame.MinButton.icon:SetVertexColor(0.7, 0.7, 0.7, 1);
MazeHelper.frame.MinButton:SetScript('OnClick', function(self)
    isMinimized = true;

    PixelUtil.SetHeight(MazeHelper.frame, 40);
    for i = 1, MAX_BUTTONS do
        buttons[i]:Hide();
    end

    PixelUtil.SetPoint(MazeHelper.frame.SolutionText, 'LEFT', MazeHelper.frame, 'LEFT', 2, 4);

    MazeHelper.frame.BottomButtonsHolder:SetShown(false);

    PixelUtil.SetPoint(MazeHelper.frame.background, 'TOPLEFT', MazeHelper.frame, 'TOPLEFT', -15, 0);
    PixelUtil.SetPoint(MazeHelper.frame.background, 'BOTTOMRIGHT', MazeHelper.frame, 'BOTTOMRIGHT', 15, 0);

    PixelUtil.SetPoint(MazeHelper.frame.CloseButton, 'TOPRIGHT', MazeHelper.frame, 'TOPRIGHT', -8, -9);

    MazeHelper.frame.PassedCounter:ClearAllPoints();
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter, 'LEFT', MazeHelper.frame, 'LEFT', -18, 5);
    MazeHelper.frame.PassedCounter:SetScale(1);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, 0);

    if SOLUTION_BUTTON_ID then
        MazeHelper.frame.MiniSolution:SetShown(true);
        MazeHelper.frame.MiniSolution.Icon:SetTexCoord(unpack(MHMOTSConfig.UseColoredSymbols and buttonsData[SOLUTION_BUTTON_ID].coords or buttonsData[SOLUTION_BUTTON_ID].coords_white));
    else
        MazeHelper.frame.MiniSolution:SetShown(false);
    end

    MazeHelper.frame.PassedCounter:SetShown(not MazeHelper.frame.MiniSolution:IsShown());

    MazeHelper.frame.AnnounceButton:SetShown(false);

    MazeHelper.frame.SettingsButton:SetShown(false);

    MazeHelper.frame.InvisibleMaxButton:SetShown(true);

    MazeHelper.frame.MinButton:SetShown(false);
end);
MazeHelper.frame.MinButton:SetScript('OnEnter', function(self) self.icon:SetVertexColor(1, 0.85, 0, 1); end);
MazeHelper.frame.MinButton:SetScript('OnLeave', function(self) self.icon:SetVertexColor(0.7, 0.7, 0.7, 1); end);

-- Invisible Maximize Button
MazeHelper.frame.InvisibleMaxButton = CreateFrame('Button', nil, MazeHelper.frame);
PixelUtil.SetPoint(MazeHelper.frame.InvisibleMaxButton, 'TOPLEFT', MazeHelper.frame, 'TOPLEFT', 0, 0);
PixelUtil.SetPoint(MazeHelper.frame.InvisibleMaxButton, 'BOTTOMRIGHT', MazeHelper.frame, 'BOTTOMRIGHT', 0, 0);
MazeHelper.frame.InvisibleMaxButton:SetScript('OnClick', function()
    if not isMinimized then
        return;
    end

    isMinimized = false;

    PixelUtil.SetHeight(MazeHelper.frame, FRAME_SIZE * 3/4);
    for i = 1, MAX_BUTTONS do
        buttons[i]:Show();
    end

    PixelUtil.SetPoint(MazeHelper.frame.SolutionText, 'LEFT', MazeHelper.frame, 'LEFT', 2, -54);

    MazeHelper.frame.BottomButtonsHolder:SetShown(true);
    MazeHelper.frame.PassedButton:SetShown(not inEncounter);
    if inEncounter then
        PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.ResetButton:GetWidth(), 22);
    else
        PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.ResetButton:GetWidth() + MazeHelper.frame.PassedButton:GetWidth() + 8, 22);
    end

    PixelUtil.SetPoint(MazeHelper.frame.background, 'TOPLEFT', MazeHelper.frame, 'TOPLEFT', -15, 22);
    PixelUtil.SetPoint(MazeHelper.frame.background, 'BOTTOMRIGHT', MazeHelper.frame, 'BOTTOMRIGHT', 15, -98);

    PixelUtil.SetPoint(MazeHelper.frame.CloseButton, 'TOPRIGHT', MazeHelper.frame, 'TOPRIGHT', -8, -4);

    MazeHelper.frame.PassedCounter:ClearAllPoints();
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter, 'BOTTOM', MazeHelper.frame, 'TOP', 0, -32);
    MazeHelper.frame.PassedCounter:SetScale(1.25);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, -1);
    MazeHelper.frame.PassedCounter:SetShown(true);

    MazeHelper.frame.MiniSolution:SetShown(false);

    MazeHelper.frame.AnnounceButton:SetShown((SOLUTION_BUTTON_ID and not MazeHelper.frame.AnnounceButton.clicked and GetPartyChatType() and not MHMOTSConfig.AutoAnnouncer) and true or false);

    MazeHelper.frame.SettingsButton:SetShown(true);

    MazeHelper.frame.InvisibleMaxButton:SetShown(false);

    MazeHelper.frame.MinButton:Show();
end);
MazeHelper.frame.InvisibleMaxButton:RegisterForDrag('LeftButton');
MazeHelper.frame.InvisibleMaxButton:SetScript('OnDragStart', function()
    if MazeHelper.frame:IsMovable() then
        MazeHelper.frame:StartMoving();
    end
end);
MazeHelper.frame.InvisibleMaxButton:SetScript('OnDragStop', function()
    BetterOnDragStop(MazeHelper.frame);
end);
MazeHelper.frame.InvisibleMaxButton:SetShown(false);

MazeHelper.frame.MainHolder = CreateFrame('Frame', nil, MazeHelper.frame);
MazeHelper.frame.MainHolder:SetAllPoints();

-- Solution Text
MazeHelper.frame.SolutionText = MazeHelper.frame.MainHolder:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge');
PixelUtil.SetPoint(MazeHelper.frame.SolutionText, 'LEFT', MazeHelper.frame, 'LEFT', 2, -54);
PixelUtil.SetPoint(MazeHelper.frame.SolutionText, 'RIGHT', MazeHelper.frame, 'RIGHT', -2, 0);
MazeHelper.frame.SolutionText:SetShadowColor(0.15, 0.15, 0.15);
MazeHelper.frame.SolutionText:SetText(L['MAZE_HELPER_CHOOSE_SYMBOLS_4']);

local function ResetAll()
    NUM_ACTIVE_BUTTONS = 0;
    SOLUTION_BUTTON_ID = nil;
    PREDICTED_SOLUTION_BUTTON_ID = nil;

    for i = 1, #RESERVED_BUTTONS_SEQUENCE do
        RESERVED_BUTTONS_SEQUENCE[i] = false;
    end

    for i = 1, MAX_BUTTONS do
        MazeHelper:SetUnactiveButton(buttons[i]);
        MazeHelper:ResetButtonSequence(buttons[i]);

        buttons[i].state = false;
        buttons[i].sender = nil;
        buttons[i].sequence = nil;
    end

    MazeHelper.frame.SolutionText:SetText(L['MAZE_HELPER_CHOOSE_SYMBOLS_4']);
    MazeHelper.frame.PassedButton:SetEnabled(false);
    MazeHelper.frame.AnnounceButton:SetShown(false);
    MazeHelper.frame.AnnounceButton.clicked = false;

    MazeHelper.frame.MiniSolution:SetShown(false);
    MazeHelper.frame.PassedCounter:SetShown(true);

    MazeHelper.frame.ResetButton:SetEnabled(false);
end

MazeHelper.frame.ResetAll = ResetAll;

MazeHelper.frame.BottomButtonsHolder = CreateFrame('Frame', nil, MazeHelper.frame.MainHolder);
PixelUtil.SetPoint(MazeHelper.frame.BottomButtonsHolder, 'TOP', MazeHelper.frame.SolutionText, 'BOTTOM', 0, -8);
PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.MainHolder:GetWidth(), 22);

-- Reset Button
MazeHelper.frame.ResetButton = CreateFrame('Button', nil, MazeHelper.frame.BottomButtonsHolder, 'SharedButtonSmallTemplate');
PixelUtil.SetPoint(MazeHelper.frame.ResetButton, 'RIGHT', MazeHelper.frame.BottomButtonsHolder, 'RIGHT', 0, 0);
MazeHelper.frame.ResetButton:SetText(L['MAZE_HELPER_RESET']);
PixelUtil.SetSize(MazeHelper.frame.ResetButton, tonumber(MazeHelper.frame.ResetButton:GetTextWidth()) + 20, 22);
MazeHelper.frame.ResetButton:SetScript('OnClick', function()
    if NUM_ACTIVE_BUTTONS == 0 then
        return;
    end

    MazeHelper:SendResetCommand();
    ResetAll();
end);
MazeHelper.frame.ResetButton:SetEnabled(false);

-- Passed Button
MazeHelper.frame.PassedButton = CreateFrame('Button', nil, MazeHelper.frame.BottomButtonsHolder, 'SharedButtonSmallTemplate');
PixelUtil.SetPoint(MazeHelper.frame.PassedButton, 'RIGHT', MazeHelper.frame.ResetButton, 'LEFT', -8, 0);
MazeHelper.frame.PassedButton:SetText(L['MAZE_HELPER_PASSED']);
PixelUtil.SetSize(MazeHelper.frame.PassedButton, tonumber(MazeHelper.frame.PassedButton:GetTextWidth()) + 20, 22);
MazeHelper.frame.PassedButton:SetScript('OnClick', function()
    PASSED_COUNTER = PASSED_COUNTER + 1;

    MazeHelper.frame.PassedCounter.Text:SetText(PASSED_COUNTER);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, isMinimized and 0 or -1);

    MazeHelper:SendPassedCommand(PASSED_COUNTER);

    ResetAll();
end);
MazeHelper.frame.PassedButton:SetEnabled(false);

PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.ResetButton:GetWidth() + MazeHelper.frame.PassedButton:GetWidth() + 8, 22);

-- Passed Counter Text
MazeHelper.frame.PassedCounter = CreateFrame('Frame', nil, MazeHelper.frame.MainHolder);
PixelUtil.SetPoint(MazeHelper.frame.PassedCounter, 'BOTTOM', MazeHelper.frame, 'TOP', 0, -32);
PixelUtil.SetSize(MazeHelper.frame.PassedCounter, 64, 64);
MazeHelper.frame.PassedCounter:SetScale(1.25);
MazeHelper.frame.PassedCounter.Background = MazeHelper.frame.PassedCounter:CreateTexture(nil, 'BACKGROUND');
MazeHelper.frame.PassedCounter.Background:SetAllPoints();
MazeHelper.frame.PassedCounter.Background:SetTexture(M.BBH);
MazeHelper.frame.PassedCounter.Text = MazeHelper.frame.PassedCounter:CreateFontString(nil, 'ARTWORK', 'GameFontNormalShadowHuge2');
PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', -2, -1);
MazeHelper.frame.PassedCounter.Text:SetShadowColor(0.15, 0.15, 0.15);
MazeHelper.frame.PassedCounter.Text:SetText(PASSED_COUNTER);
MazeHelper.frame.PassedCounter.Text:SetJustifyH('CENTER');

-- Mini solution icon
MazeHelper.frame.MiniSolution = CreateFrame('Frame', nil, MazeHelper.frame.MainHolder);
MazeHelper.frame.MiniSolution:SetAllPoints(MazeHelper.frame.PassedCounter);
PixelUtil.SetPoint(MazeHelper.frame.MiniSolution, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', 0, 0);
MazeHelper.frame.MiniSolution.Icon = MazeHelper.frame.MiniSolution:CreateTexture(nil, 'OVERLAY');
PixelUtil.SetPoint(MazeHelper.frame.MiniSolution.Icon, 'CENTER', MazeHelper.frame.MiniSolution, 'CENTER', 0, 0);
PixelUtil.SetSize(MazeHelper.frame.MiniSolution.Icon, 40, 40);
MazeHelper.frame.MiniSolution.Icon:SetTexture(M.Symbols.TEXTURE);
MazeHelper.frame.MiniSolution:SetShown(false);

-- Announce Button
MazeHelper.frame.AnnounceButton = CreateFrame('Button', nil, MazeHelper.frame.MainHolder);
PixelUtil.SetPoint(MazeHelper.frame.AnnounceButton, 'TOPLEFT', MazeHelper.frame, 'TOPLEFT', 2, 4);
PixelUtil.SetSize(MazeHelper.frame.AnnounceButton, 18, 18);
MazeHelper.frame.AnnounceButton:SetNormalTexture(M.Icons.TEXTURE);
MazeHelper.frame.AnnounceButton:GetNormalTexture():SetTexCoord(unpack(M.Icons.COORDS.MEGAPHONE_WHITE));
MazeHelper.frame.AnnounceButton:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7, 1);
MazeHelper.frame.AnnounceButton:SetHighlightTexture(M.Icons.TEXTURE, 'BLEND');
MazeHelper.frame.AnnounceButton:GetHighlightTexture():SetTexCoord(unpack(M.Icons.COORDS.MEGAPHONE_WHITE));
MazeHelper.frame.AnnounceButton:GetHighlightTexture():SetVertexColor(1, 0.85, 0, 1);
MazeHelper.frame.AnnounceButton:SetScript('OnClick', function(self)
    if not SOLUTION_BUTTON_ID then
        return;
    end

    local partyChatType = GetPartyChatType();
    if partyChatType then
        SendChatMessage(string.format(L['MAZE_HELPER_ANNOUNCE_SOLUTION'], buttons[SOLUTION_BUTTON_ID].data.aname), partyChatType);
    end

    self.clicked = true;
    self:SetShown(false);
end);
MazeHelper.frame.AnnounceButton:SetShown(false);

MazeHelper.frame.Settings = CreateFrame('Frame', nil, MazeHelper.frame);
MazeHelper.frame.Settings:SetAllPoints();
MazeHelper.frame.Settings:SetShown(false);

local scrollChild, scrollArea = E.CreateScrollFrame(MazeHelper.frame.Settings, 26);
scrollChild.Data.SyncEnabled = E.CreateRoundedCheckButton(scrollChild);
scrollChild.Data.SyncEnabled:SetPosition('TOPLEFT', scrollChild, 'TOPLEFT', 12, -8);
scrollChild.Data.SyncEnabled:SetArea(26, 26);
scrollChild.Data.SyncEnabled:SetLabel(L['MAZE_HELPER_SETTINGS_SYNC_ENABLED_LABEL']);
scrollChild.Data.SyncEnabled:SetTooltip(L['MAZE_HELPER_SETTINGS_SYNC_ENABLED_TOOLTIP']);
scrollChild.Data.SyncEnabled:SetScript('OnClick', function(self)
    MHMOTSConfig.SyncEnabled = self:GetChecked();

    if MHMOTSConfig.SyncEnabled then
        MazeHelper.frame:RegisterEvent('CHAT_MSG_ADDON');
    else
        MazeHelper.frame:UnregisterEvent('CHAT_MSG_ADDON');
    end
end);

scrollChild.Data.PredictSolution = E.CreateRoundedCheckButton(scrollChild);
scrollChild.Data.PredictSolution:SetPosition('TOPLEFT', scrollChild.Data.SyncEnabled, 'BOTTOMLEFT', 0, 0);
scrollChild.Data.PredictSolution:SetArea(26, 26);
scrollChild.Data.PredictSolution:SetLabel(L['MAZE_HELPER_SETTINGS_PREDICT_SOLUTION_LABEL']);
scrollChild.Data.PredictSolution:SetTooltip(L['MAZE_HELPER_SETTINGS_PREDICT_SOLUTION_TOOLTIP']);
scrollChild.Data.PredictSolution:SetScript('OnClick', function(self)
    MHMOTSConfig.PredictSolution = self:GetChecked();
    ResetAll();
end);

scrollChild.Data.UseColoredSymbols = E.CreateRoundedCheckButton(scrollChild);
scrollChild.Data.UseColoredSymbols:SetPosition('TOPLEFT', scrollChild.Data.PredictSolution, 'BOTTOMLEFT', 0, 0);
scrollChild.Data.UseColoredSymbols:SetArea(26, 26);
scrollChild.Data.UseColoredSymbols:SetLabel(L['MAZE_HELPER_SETTINGS_USE_COLORED_SYMBOLS_LABEL']);
scrollChild.Data.UseColoredSymbols:SetTooltip(L['MAZE_HELPER_SETTINGS_USE_COLORED_SYMBOLS_TOOLTIP']);
scrollChild.Data.UseColoredSymbols:SetScript('OnClick', function(self)
    MHMOTSConfig.UseColoredSymbols = self:GetChecked();
    SwitchSymbolsColorMode(MHMOTSConfig.UseColoredSymbols);
end);

scrollChild.Data.ShowSequenceNumbers = E.CreateRoundedCheckButton(scrollChild);
scrollChild.Data.ShowSequenceNumbers:SetPosition('TOPLEFT', scrollChild.Data.UseColoredSymbols, 'BOTTOMLEFT', 0, 0);
scrollChild.Data.ShowSequenceNumbers:SetArea(26, 26);
scrollChild.Data.ShowSequenceNumbers:SetLabel(L['MAZE_HELPER_SETTINGS_SHOW_SEQUENCE_NUMBERS_LABEL']);
scrollChild.Data.ShowSequenceNumbers:SetTooltip(L['MAZE_HELPER_SETTINGS_SHOW_SEQUENCE_NUMBERS_TOOLTIP']);
scrollChild.Data.ShowSequenceNumbers:SetScript('OnClick', function(self)
    MHMOTSConfig.ShowSequenceNumbers = self:GetChecked();

    for i = 1, MAX_BUTTONS do
        buttons[i].SequenceText:SetShown(MHMOTSConfig.ShowSequenceNumbers);
    end
end);

scrollChild.Data.PrintResettedPlayerName = E.CreateRoundedCheckButton(scrollChild);
scrollChild.Data.PrintResettedPlayerName:SetPosition('TOPLEFT', scrollChild.Data.ShowSequenceNumbers, 'BOTTOMLEFT', 0, 0);
scrollChild.Data.PrintResettedPlayerName:SetArea(26, 26);
scrollChild.Data.PrintResettedPlayerName:SetLabel(L['MAZE_HELPER_SETTINGS_REVEAL_RESETTER_LABEL']);
scrollChild.Data.PrintResettedPlayerName:SetTooltip(L['MAZE_HELPER_SETTINGS_REVEAL_RESETTER_TOOLTIP']);
scrollChild.Data.PrintResettedPlayerName:SetScript('OnClick', function(self)
    MHMOTSConfig.PrintResettedPlayerName = self:GetChecked();
end);

scrollChild.Data.ShowAtBoss = E.CreateRoundedCheckButton(scrollChild);
scrollChild.Data.ShowAtBoss:SetPosition('TOPLEFT', scrollChild.Data.PrintResettedPlayerName, 'BOTTOMLEFT', 0, 0);
scrollChild.Data.ShowAtBoss:SetArea(26, 26);
scrollChild.Data.ShowAtBoss:SetLabel(L['MAZE_HELPER_SETTINGS_SHOW_AT_BOSS_LABEL']);
scrollChild.Data.ShowAtBoss:SetTooltip(L['MAZE_HELPER_SETTINGS_SHOW_AT_BOSS_TOOLTIP']);
scrollChild.Data.ShowAtBoss:SetScript('OnClick', function(self)
    MHMOTSConfig.ShowAtBoss = self:GetChecked();
end);

scrollChild.Data.StartInMinMode = E.CreateRoundedCheckButton(scrollChild);
scrollChild.Data.StartInMinMode:SetPosition('TOPLEFT', scrollChild.Data.ShowAtBoss, 'BOTTOMLEFT', 0, 0);
scrollChild.Data.StartInMinMode:SetArea(26, 26);
scrollChild.Data.StartInMinMode:SetLabel(L['MAZE_HELPER_SETTINGS_START_IN_MINMODE_LABEL']);
scrollChild.Data.StartInMinMode:SetTooltip(L['MAZE_HELPER_SETTINGS_START_IN_MINMODE_TOOLTIP']);
scrollChild.Data.StartInMinMode:SetScript('OnClick', function(self)
    MHMOTSConfig.StartInMinMode = self:GetChecked();
end);

scrollChild.Data.AutoAnnouncer = E.CreateRoundedCheckButton(scrollChild);
scrollChild.Data.AutoAnnouncer:SetPosition('TOPLEFT', scrollChild.Data.StartInMinMode, 'BOTTOMLEFT', 0, 0);
scrollChild.Data.AutoAnnouncer:SetArea(26, 26);
scrollChild.Data.AutoAnnouncer:SetLabel(L['MAZE_HELPER_SETTINGS_AUTOANNOUNCER_LABEL']);
scrollChild.Data.AutoAnnouncer:SetTooltip(L['MAZE_HELPER_SETTINGS_AUTOANNOUNCER_TOOLTIP']);
scrollChild.Data.AutoAnnouncer:SetScript('OnClick', function(self)
    MHMOTSConfig.AutoAnnouncer = self:GetChecked();

    scrollChild.Data.AutoAnnouncerAsPartyLeader:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    scrollChild.Data.AutoAnnouncerAsAlways:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    scrollChild.Data.AutoAnnouncerAsTank:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    scrollChild.Data.AutoAnnouncerAsHealer:SetEnabled(MHMOTSConfig.AutoAnnouncer);
end);

scrollChild.Data.AutoAnnouncerAsPartyLeader = E.CreateCheckButton('MazeHelper_Settings_AutoAnnouncerAsPartyLeader_CheckButton', scrollChild);
scrollChild.Data.AutoAnnouncerAsPartyLeader:SetPosition('TOPLEFT', scrollChild.Data.AutoAnnouncer, 'BOTTOMRIGHT', 0, 2);
scrollChild.Data.AutoAnnouncerAsPartyLeader:SetLabel(M.INLINE_LEADER_ICON);
scrollChild.Data.AutoAnnouncerAsPartyLeader:SetTooltip(L['MAZE_HELPER_SETTINGS_AA_PARTY_LEADER']);
scrollChild.Data.AutoAnnouncerAsPartyLeader:SetScript('OnClick', function(self)
    MHMOTSConfig.AutoAnnouncerAsPartyLeader = self:GetChecked();
end);

scrollChild.Data.AutoAnnouncerAsAlways = E.CreateCheckButton('MazeHelper_Settings_AutoAnnouncerAsAlways_CheckButton', scrollChild);
scrollChild.Data.AutoAnnouncerAsAlways:SetPosition('LEFT', scrollChild.Data.AutoAnnouncerAsPartyLeader.Label, 'RIGHT', 12, 0);
scrollChild.Data.AutoAnnouncerAsAlways:SetLabel(M.INLINE_INFINITY_ICON);
scrollChild.Data.AutoAnnouncerAsAlways:SetTooltip(L['MAZE_HELPER_SETTINGS_AA_ALWAYS']);
scrollChild.Data.AutoAnnouncerAsAlways:SetScript('OnClick', function(self)
    MHMOTSConfig.AutoAnnouncerAsAlways = self:GetChecked();
end);

scrollChild.Data.AutoAnnouncerAsTank = E.CreateCheckButton('MazeHelper_Settings_AutoAnnouncerAsTank_CheckButton', scrollChild);
scrollChild.Data.AutoAnnouncerAsTank:SetPosition('LEFT', scrollChild.Data.AutoAnnouncerAsAlways.Label, 'RIGHT', 12, 0);
scrollChild.Data.AutoAnnouncerAsTank:SetLabel(M.INLINE_TANK_ICON);
scrollChild.Data.AutoAnnouncerAsTank:SetTooltip(L['MAZE_HELPER_SETTINGS_AA_TANK']);
scrollChild.Data.AutoAnnouncerAsTank:SetScript('OnClick', function(self)
    MHMOTSConfig.AutoAnnouncerAsTank = self:GetChecked();
end);

scrollChild.Data.AutoAnnouncerAsHealer = E.CreateCheckButton('MazeHelper_Settings_AutoAnnouncerAsHealer_CheckButton', scrollChild);
scrollChild.Data.AutoAnnouncerAsHealer:SetPosition('LEFT', scrollChild.Data.AutoAnnouncerAsTank.Label, 'RIGHT', 12, 0);
scrollChild.Data.AutoAnnouncerAsHealer:SetLabel(M.INLINE_HEALER_ICON);
scrollChild.Data.AutoAnnouncerAsHealer:SetTooltip(L['MAZE_HELPER_SETTINGS_AA_HEALER']);
scrollChild.Data.AutoAnnouncerAsHealer:SetScript('OnClick', function(self)
    MHMOTSConfig.AutoAnnouncerAsHealer = self:GetChecked();
end);

MazeHelper.frame.Settings.VersionText = MazeHelper.frame.Settings:CreateFontString(nil, 'ARTWORK', 'GameFontDisable');
PixelUtil.SetPoint(MazeHelper.frame.Settings.VersionText, 'BOTTOM', MazeHelper.frame.Settings, 'TOP', 0, 0);
MazeHelper.frame.Settings.VersionText:SetText(GetAddOnMetadata(ADDON_NAME, 'Version'));

local function LeftButton_OnClick(button, send, sender)
    if button.state or NUM_ACTIVE_BUTTONS == MAX_ACTIVE_BUTTONS then
        return;
    end

    MazeHelper.frame.ResetButton:SetEnabled(true);

    NUM_ACTIVE_BUTTONS = math.min(MAX_ACTIVE_BUTTONS, NUM_ACTIVE_BUTTONS + 1);

    button.state  = true;
    button.sender = sender;

    MazeHelper:SetActiveButton(button);
    MazeHelper:UpdateButtonSequence(button);
    MazeHelper.frame.SolutionText:SetText(L['MAZE_HELPER_CHOOSE_SYMBOLS_' .. (MAX_ACTIVE_BUTTONS - NUM_ACTIVE_BUTTONS)]);

    if send then
        MazeHelper:SendButtonID(button.id, 'ACTIVE');
    end

    MazeHelper:UpdateSolution();
end

local function RightButton_OnClick(button, send, sender)
    if not button.state then
        return;
    end

    NUM_ACTIVE_BUTTONS = math.max(0, NUM_ACTIVE_BUTTONS - 1);
    button.state  = false;
    button.sender = sender;

    MazeHelper:SetUnactiveButton(button);
    MazeHelper:ResetButtonSequence(button);

    if NUM_ACTIVE_BUTTONS < MAX_ACTIVE_BUTTONS then
        MazeHelper.frame.SolutionText:SetText(L['MAZE_HELPER_CHOOSE_SYMBOLS_' .. (MAX_ACTIVE_BUTTONS - NUM_ACTIVE_BUTTONS)]);

        if SOLUTION_BUTTON_ID ~= nil then
            MazeHelper:SetUnactiveButton(buttons[SOLUTION_BUTTON_ID]);
        end

        for i = 1, MAX_BUTTONS do
            if buttons[i].state then
                MazeHelper:SetActiveButton(buttons[i]);
            end
        end

        MazeHelper.frame.PassedButton:SetEnabled(false);
        MazeHelper.frame.AnnounceButton:SetShown(false);
        MazeHelper.frame.AnnounceButton.clicked = false;

        MazeHelper:UpdateSolution();
    end

    if NUM_ACTIVE_BUTTONS == 0 then
        MazeHelper.frame.ResetButton:SetEnabled(false);
    end

    if send then
        MazeHelper:SendButtonID(button.id, 'UNACTIVE');
    end
end

function MazeHelper:CreateButton(index)
    local button = CreateFrame('Button', nil, MazeHelper.frame.MainHolder, 'BackdropTemplate');

    if index == 1 then
        PixelUtil.SetPoint(button, 'TOPLEFT', MazeHelper.frame.MainHolder, 'TOPLEFT', 20, -20);
    elseif index == 5 then
        PixelUtil.SetPoint(button, 'TOPLEFT', buttons[1], 'BOTTOMLEFT', 0, Y_OFFSET);
    else
        PixelUtil.SetPoint(button, 'LEFT', buttons[index - 1], 'RIGHT', X_OFFSET, 0);
    end

    PixelUtil.SetSize(button, BUTTON_SIZE, BUTTON_SIZE);

    button.Icon = button:CreateTexture(nil, 'ARTWORK');
    PixelUtil.SetPoint(button.Icon, 'TOPLEFT', button, 'TOPLEFT', 4, -4);
    PixelUtil.SetPoint(button.Icon, 'BOTTOMRIGHT', button, 'BOTTOMRIGHT', -4, 4);
    button.Icon:SetTexture(M.Symbols.TEXTURE);
    button.Icon:SetTexCoord(unpack(MHMOTSConfig.UseColoredSymbols and buttonsData[index].coords or buttonsData[index].coords_white));

    button:SetBackdrop({
        insets   = { top = 1, left = 1, bottom = 1, right = 1 },
        edgeFile = 'Interface\\Buttons\\WHITE8x8',
        edgeSize = 2,
    });

    MazeHelper:SetUnactiveButton(button);

    button.SequenceText = button:CreateFontString(nil, 'ARTWORK', 'GameFontNormal');
    PixelUtil.SetPoint(button.SequenceText, 'BOTTOMRIGHT', button, 'BOTTOMRIGHT', -2, 2);
    button.SequenceText:SetShown(MHMOTSConfig.ShowSequenceNumbers);

    button.id    = index;
    button.data  = buttonsData[index];
    button.state = false;

    button:RegisterForClicks('LeftButtonUp', 'RightButtonUp');

    button:SetScript('OnClick', function(self, b)
        if b == 'LeftButton' then
            LeftButton_OnClick(self, true);
        elseif b == 'RightButton' then
            RightButton_OnClick(self, true);
        end
    end);

    button:SetScript('OnEnter', function(self)
        if not self.sender then
            return;
        end

        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT');
        GameTooltip:AddLine(self.state and string.format(L['MAZE_HELPER_SENDED_BY'], self.sender) or string.format(L['MAZE_HELPER_CLEARED_BY'], self.sender), 1, 0.85, 0, true);
        GameTooltip:Show();
    end);
    button:SetScript('OnLeave', GameTooltip_Hide);

    button:RegisterForDrag('LeftButton');
    button:SetScript('OnDragStart', function()
        if MazeHelper.frame:IsMovable() then
            MazeHelper.frame:StartMoving();
        end
    end);
    button:SetScript('OnDragStop', function()
        BetterOnDragStop(MazeHelper.frame);
    end);

    table.insert(buttons, index, button); -- index for just to be sure
end

function MazeHelper:CreateButtons()
    for i = 1, MAX_BUTTONS do
        MazeHelper:CreateButton(i);
    end
end

local function GetMinimumReservedSequence()
    for i = 1, #RESERVED_BUTTONS_SEQUENCE do
        if RESERVED_BUTTONS_SEQUENCE[i] == false then
            return i;
        end
    end
end

function MazeHelper:UpdateButtonSequence(button)
    button.sequence = GetMinimumReservedSequence();
    RESERVED_BUTTONS_SEQUENCE[button.sequence] = true;

    button.SequenceText:SetText((MHMOTSConfig.PredictSolution and button.sequence == 1) and M.INLINE_ENTRANCE_ICON or button.sequence);
end

function MazeHelper:ResetButtonSequence(button)
    if button.sequence then
        RESERVED_BUTTONS_SEQUENCE[button.sequence] = false;
        button.sequence = nil;
    end

    button.SequenceText:SetText(EMPTY_STRING);
end

function MazeHelper:SetUnactiveButton(button)
    button:SetBackdropBorderColor(0, 0, 0, 0);
end

function MazeHelper:SetActiveButton(button)
    button:SetBackdropBorderColor(0.4, 0.52, 0.95, 1);
end

function MazeHelper:SetReceivedButton(button)
    button:SetBackdropBorderColor(0.9, 1, 0.1, 1);
end

function MazeHelper:SetSolutionButton(button)
    button:SetBackdropBorderColor(0.2, 0.8, 0.4, 1);
end

function MazeHelper:SetPredictedButton(button)
    button:SetBackdropBorderColor(1, 0.9, 0.71, 1);
end

-- Credit to Garthul#2712
-- Main idea: The solution is the opposite of entrance symbol or opposite of an existing symbol that shares two features with entrance symbol. Order of conditions matter.
local TryHeuristicSolution do
    local filterTable = {};

    local reusableOppositeTable = {
        fill   = false,
        leaf   = false,
        circle = false,
    };

    local function Filter(b, f) table.wipe(filterTable); for i, v in pairs(b) do if f(v) then r[i] = v; end end return r; end
    local function Find(b, f) for i, v in pairs(b) do if f(v) then return i, v; end end end
    local function Equals(s1, s2) return s1.fill == s2.fill and s1.leaf == s2.leaf and s1.circle == s2.circle; end
    local function Opposite(s)
        reusableOppositeTable.fill   = not s.fill;
        reusableOppositeTable.leaf   = not s.leaf;
        reusableOppositeTable.circle = not s.circle;

        return reusableOppositeTable;
    end
    local function NumberOfSharedFeatures(s1, s2) return (s1.fill == s2.fill and 1 or 0) + (s1.leaf == s2.leaf and 1 or 0) + (s1.circle == s2.circle and 1 or 0); end

    local IsActiveButtonFunction = function(b) return b.state; end
    local IsEntranceButtonFunction = function(b) return b.state and b.sequence == 1; end

    function TryHeuristicSolution()
        if inEncounter then
            return nil;
        end

        local activeButtons = Filter(buttons, IsActiveButtonFunction);
        local _, entranceButton = Find(activeButtons, IsEntranceButtonFunction);

        if entranceButton ~= nil then
            local IsOppositeOfEntranceFunction = function(b) return Equals(b.data, Opposite(entranceButton.data)); end
            local i, solutionButton = Find(activeButtons, IsOppositeOfEntranceFunction);
            if solutionButton ~= nil then
                return i;
            end

            local IsSharingTwoFeaturesWithEntrance = function(b) return NumberOfSharedFeatures(b.data, entranceButton.data) == 2; end
            local _, helperButton = Find(activeButtons, IsSharingTwoFeaturesWithEntrance);

            if helperButton ~= nil then
                local IsOppositeOfHelperFunction = function(b) return Equals(b.data, Opposite(helperButton.data)); end
                i, solutionButton = Find(activeButtons, IsOppositeOfHelperFunction);
                if solutionButton ~= nil then
                    return i;
                end

                local IsDifferentFromFirstAndSecond = function(b) return not Equals(b.data, helperButton.data) and not Equals(b.data, entranceButton.data); end
                local _, thirdButton = Find(activeButtons, IsDifferentFromFirstAndSecond);

                if thirdButton ~= nil then
                    local solutionSymbol;
                    local numSharedFeatures = NumberOfSharedFeatures(thirdButton.data, entranceButton.data);

                    if numSharedFeatures == 1 then
                        solutionSymbol = Opposite(helperButton.data);
                    elseif numSharedFeatures == 2 then
                        solutionSymbol = Opposite(entranceButton.data);
                    end

                    if solutionSymbol ~= nil then
                        local IsSolutionSymbol = function(b) return Equals(b.data, solutionSymbol); end
                        return Find(buttons, IsSolutionSymbol);
                    end
                end
            end
        end

        return nil;
    end
end

-- DON'T LOOK AT THIS SHIT PLEEEEASE :( I WAS DRUNK, BUT IT STILL WORKS SOMEHOW
function MazeHelper:UpdateSolution()
    local circleSum, flowerSum, leafSum, fillSum = 0, 0, 0, 0;
    for i = 1, MAX_BUTTONS do
        if buttons[i].state then
            if buttons[i].data.circle then
                circleSum = circleSum + 1;
            end

            if buttons[i].data.flower then
                flowerSum = flowerSum + 1;
            end

            if buttons[i].data.leaf then
                leafSum = leafSum + 1;
            end

            if buttons[i].data.fill then
                fillSum = fillSum + 1;
            end
        end
    end

    local fill, flower, leaf, circle;
    if fillSum == 3 then
        fill = false;
    elseif fillSum == 1 then
        fill = true;
    end

    if flowerSum == 3 then
        flower = false
    elseif flowerSum == 1 then
        flower = true;
    end

    if leafSum == 3 then
        leaf = false;
    elseif leafSum == 1 then
        leaf = true;
    end

    if circleSum == 3 then
        circle = false;
    elseif circleSum == 1 then
        circle = true;
    end

    SOLUTION_BUTTON_ID = nil;

    if MHMOTSConfig.PredictSolution and NUM_ACTIVE_BUTTONS < MAX_ACTIVE_BUTTONS then
        SOLUTION_BUTTON_ID = TryHeuristicSolution();
        PREDICTED_SOLUTION_BUTTON_ID = SOLUTION_BUTTON_ID or nil;
    end

    if NUM_ACTIVE_BUTTONS == MAX_ACTIVE_BUTTONS then
        if PREDICTED_SOLUTION_BUTTON_ID then
            if buttons[PREDICTED_SOLUTION_BUTTON_ID].state then
                if buttons[PREDICTED_SOLUTION_BUTTON_ID].sender then
                    MazeHelper:SetReceivedButton(buttons[PREDICTED_SOLUTION_BUTTON_ID]);
                else
                    MazeHelper:SetActiveButton(buttons[PREDICTED_SOLUTION_BUTTON_ID]);
                end
            else
                MazeHelper:SetUnactiveButton(buttons[PREDICTED_SOLUTION_BUTTON_ID]);
            end

            PREDICTED_SOLUTION_BUTTON_ID = nil;
        end

        for i = 1, MAX_BUTTONS do
            if buttons[i].state then
                if buttons[i].data.fill == fill then
                    SOLUTION_BUTTON_ID = i;
                end

                if buttons[i].data.leaf == leaf then
                    SOLUTION_BUTTON_ID = i;
                end

                if buttons[i].data.flower == flower then
                    SOLUTION_BUTTON_ID = i;
                end

                if buttons[i].data.circle == circle then
                    SOLUTION_BUTTON_ID = i;
                end
            end
        end
    end

    if SOLUTION_BUTTON_ID then
        local partyChatType = GetPartyChatType();

        for i = 1, MAX_BUTTONS do
            if not buttons[i].state then
                MazeHelper:SetUnactiveButton(buttons[i]);
            end
        end

        if PREDICTED_SOLUTION_BUTTON_ID then
            MazeHelper:SetPredictedButton(buttons[PREDICTED_SOLUTION_BUTTON_ID]);
        else
            MazeHelper:SetSolutionButton(buttons[SOLUTION_BUTTON_ID]);
        end

        MazeHelper.frame.MiniSolution.Icon:SetTexCoord(unpack(MHMOTSConfig.UseColoredSymbols and buttonsData[SOLUTION_BUTTON_ID].coords or buttonsData[SOLUTION_BUTTON_ID].coords_white));

        MazeHelper.frame.AnnounceButton:SetShown((not isMinimized and partyChatType and not MHMOTSConfig.AutoAnnouncer) and true or false);
        MazeHelper.frame.PassedButton:SetEnabled(true);
        MazeHelper.frame.SolutionText:SetText(string.format(L['MAZE_HELPER_SOLUTION'], buttons[SOLUTION_BUTTON_ID].data.name));

        if isMinimized then
            MazeHelper.frame.MiniSolution:SetShown(true);
            MazeHelper.frame.PassedCounter:SetShown(false);
        end

        if MHMOTSConfig.AutoAnnouncer and partyChatType then
            local announce = false;

            if MHMOTSConfig.AutoAnnouncerAsAlways then
                announce = true;
            elseif MHMOTSConfig.AutoAnnouncerAsPartyLeader and UnitIsGroupLeader('player') then
                announce = true;
            elseif MHMOTSConfig.AutoAnnouncerAsTank and playerRole == 'TANK' then
                announce = true;
            elseif MHMOTSConfig.AutoAnnouncerAsHealer and playerRole == 'HEALER' then
                announce = true;
            end

            if announce then
                SendChatMessage(string.format(L['MAZE_HELPER_ANNOUNCE_SOLUTION'], buttons[SOLUTION_BUTTON_ID].data.aname), partyChatType);
            end
        end
    else
        MazeHelper.frame.MiniSolution:SetShown(false);
        MazeHelper.frame.PassedCounter:SetShown(true);
        MazeHelper.frame.AnnounceButton:SetShown(false);

        MazeHelper.frame.PassedButton:SetEnabled(false);

        if NUM_ACTIVE_BUTTONS == MAX_ACTIVE_BUTTONS then
            for i = 1, MAX_BUTTONS do
                if buttons[i].state then
                    if buttons[i].sender then
                        MazeHelper:SetReceivedButton(buttons[i]);
                    else
                        MazeHelper:SetActiveButton(buttons[i]);
                    end
                else
                    MazeHelper:SetUnactiveButton(buttons[i]);
                end
            end

            MazeHelper.frame.SolutionText:SetText(L['MAZE_HELPER_SOLUTION_NA']);
        end
    end
end

function MazeHelper:SendResetCommand()
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    local partyChatType = GetPartyChatType();
    if not partyChatType then
        return;
    end

    C_ChatInfo.SendAddonMessage(ADDON_COMM_PREFIX, 'SendReset', partyChatType);
end

function MazeHelper:SendPassedCommand(step)
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    local partyChatType = GetPartyChatType();
    if not partyChatType then
        return;
    end

    C_ChatInfo.SendAddonMessage(ADDON_COMM_PREFIX, string.format('SendPassed|%s', step), partyChatType);
end

function MazeHelper:SendPassedCounter()
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    local partyChatType = GetPartyChatType();
    if not partyChatType then
        return;
    end

    C_ChatInfo.SendAddonMessage(ADDON_COMM_PREFIX, string.format('RECPC|%s', PASSED_COUNTER), partyChatType);
end

function MazeHelper:RequestPassedCounter()
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    local partyChatType = GetPartyChatType();
    if not partyChatType then
        return;
    end

    C_ChatInfo.SendAddonMessage(ADDON_COMM_PREFIX, 'REQPC', partyChatType);
end

function MazeHelper:SendButtonID(buttonID, mode)
    if not MHMOTSConfig.SyncEnabled then
        return;
    end

    local partyChatType = GetPartyChatType();
    if not partyChatType then
        return;
    end

    C_ChatInfo.SendAddonMessage(ADDON_COMM_PREFIX, string.format('SendButtonID|%s|%s', buttonID, mode), partyChatType);
end

function MazeHelper:ReceiveResetCommand()
    ResetAll();
end

function MazeHelper:ReceivePassedCommand(step)
    PASSED_COUNTER = step;

    MazeHelper.frame.PassedCounter.Text:SetText(PASSED_COUNTER);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, isMinimized and 0 or -1);
    ResetAll();
end

function MazeHelper:ReceivePassedCounter(step)
    if step and step == PASSED_COUNTER then
        return;
    end

    PASSED_COUNTER = step;

    MazeHelper.frame.PassedCounter.Text:SetText(PASSED_COUNTER);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, isMinimized and 0 or -1);
end

function MazeHelper:ReceiveActiveButtonID(buttonID, sender)
    if not buttons[buttonID] then
        return;
    end

    LeftButton_OnClick(buttons[buttonID], false, sender);
end

function MazeHelper:ReceiveUnactiveButtonID(buttonID, sender)
    if not buttons[buttonID] then
        return;
    end

    RightButton_OnClick(buttons[buttonID], false, sender);
end

local function UpdateShown()
    if MHMOTSConfig.ShowAtBoss then
        MazeHelper.frame:SetShown((not bossKilled and inInstance and GetMinimapZoneText() == L['MAZE_HELPER_ZONE_NAME']));
    else
        MazeHelper.frame:SetShown((not inEncounter and inInstance and GetMinimapZoneText() == L['MAZE_HELPER_ZONE_NAME']));
    end

    if MazeHelper.frame:IsShown() then
        if MHMOTSConfig.StartInMinMode and not startedInMinMode then
            MazeHelper.frame.MinButton:Click();
            startedInMinMode = true;
        end
    end

    if inEncounter then
        PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.ResetButton:GetWidth(), 22);

        MazeHelper.frame.PassedButton:Hide();
        MazeHelper.frame.PassedCounter:Hide();
    else
        PixelUtil.SetSize(MazeHelper.frame.BottomButtonsHolder, MazeHelper.frame.ResetButton:GetWidth() + MazeHelper.frame.PassedButton:GetWidth() + 8, 22);

        MazeHelper.frame.PassedButton:Show();
        MazeHelper.frame.PassedCounter:Show();
    end
end

MazeHelper.frame.UpdateShown = UpdateShown;

MazeHelper.frame:RegisterEvent('ADDON_LOADED');
MazeHelper.frame:SetScript('OnEvent', function(self, event, ...)
    if self[event] then
        return self[event](self, ...);
    end
end);

local function UpdateData(frame) -- Not good name, i know...
    local playerName, playerShortenedRealm = UnitFullName('player');
    playerNameWithRealm = playerName .. '-' .. playerShortenedRealm;

    inInstance = IsInInstance();
    bossKilled = inInstance and (select(3, GetInstanceLockTimeRemainingEncounter(2))) or false;
    inEncounter = not bossKilled and UnitExists('boss1');

    PASSED_COUNTER = 1;
    MazeHelper.frame.PassedCounter.Text:SetText(PASSED_COUNTER);
    PixelUtil.SetPoint(MazeHelper.frame.PassedCounter.Text, 'CENTER', MazeHelper.frame.PassedCounter, 'CENTER', (PASSED_COUNTER == 1) and -2 or 0, isMinimized and 0 or -1);

    MazeHelper:RequestPassedCounter(); -- if you were dc'ed or reloading ui

    startedInMinMode = false;

    if inInstance then
        frame:RegisterEvent('ZONE_CHANGED');
        frame:RegisterEvent('ZONE_CHANGED_INDOORS');
        frame:RegisterEvent('ZONE_CHANGED_NEW_AREA');
        frame:RegisterEvent('ENCOUNTER_START');
        frame:RegisterEvent('ENCOUNTER_END');
        frame:RegisterEvent('BOSS_KILL');
    else
        frame:UnregisterEvent('ZONE_CHANGED');
        frame:UnregisterEvent('ZONE_CHANGED_INDOORS');
        frame:UnregisterEvent('ZONE_CHANGED_NEW_AREA');
        frame:UnregisterEvent('ENCOUNTER_START');
        frame:UnregisterEvent('ENCOUNTER_END');
        frame:UnregisterEvent('BOSS_KILL');
    end

    UpdateShown();
end

function MazeHelper.frame:PLAYER_LOGIN()
    UpdateData(self);
end

function MazeHelper.frame:PLAYER_ENTERING_WORLD()
    UpdateData(self);
end

function MazeHelper.frame:ZONE_CHANGED()
    UpdateShown();
end

function MazeHelper.frame:ZONE_CHANGED_INDOORS()
    UpdateShown();
end

function MazeHelper.frame:ZONE_CHANGED_NEW_AREA()
    UpdateShown();
end

local function UpdateBossState(encounterID, inFight, killed)
    if encounterID ~= MISTCALLER_ENCOUNTER_ID then
        return;
    end

    inEncounter = inFight;

    ResetAll();

    bossKilled = killed;
    UpdateShown();
end

function MazeHelper.frame:ENCOUNTER_START(encounterID)
    UpdateBossState(encounterID, true, false);
end

function MazeHelper.frame:ENCOUNTER_END(encounterID, _, _, _, success)
    UpdateBossState(encounterID, false, success);
end

function MazeHelper.frame:BOSS_KILL(encounterID)
    UpdateBossState(encounterID, false, true);
end

function MazeHelper.frame:CHAT_MSG_ADDON(prefix, message, _, sender)
    if sender == playerNameWithRealm then
        return;
    end

    if prefix == ADDON_COMM_PREFIX then
        local p, buttonID, mode = strsplit('|', message);
        if p == 'SendButtonID'  then
            if mode == 'ACTIVE' then
                MazeHelper:ReceiveActiveButtonID(tonumber(buttonID), sender);
            elseif mode == 'UNACTIVE' then
                MazeHelper:ReceiveUnactiveButtonID(tonumber(buttonID), sender);
            end
        elseif p == 'SendPassed' then
            MazeHelper:ReceivePassedCommand(tonumber(buttonID));

            if MHMOTSConfig.PrintResettedPlayerName then
                print(string.format(L['MAZE_HELPER_PASSED_PLAYER'], sender));
            end
        elseif p == 'SendReset' then
            MazeHelper:ReceiveResetCommand();

            if MHMOTSConfig.PrintResettedPlayerName then
                print(string.format(L['MAZE_HELPER_RESETED_PLAYER'], sender));
            end
        elseif p == 'REQPC' then
            MazeHelper:SendPassedCounter();
        elseif p == 'RECPC' then
            MazeHelper:ReceivePassedCounter(tonumber(buttonID));
        end
    end
end

function MazeHelper.frame:PLAYER_SPECIALIZATION_CHANGED(unit)
    if unit ~= 'player' then
        return;
    end

    playerRole = (select(5, GetSpecializationInfo(GetSpecialization())) or EMPTY_STRING);
end

function MazeHelper.frame:ADDON_LOADED(addonName)
    if addonName ~= ADDON_NAME then
        return;
    end

    self:UnregisterEvent('ADDON_LOADED');

    MHMOTSConfig = MHMOTSConfig or {};
    MHMOTSConfig.SyncEnabled             = MHMOTSConfig.SyncEnabled == nil and true or MHMOTSConfig.SyncEnabled;
    MHMOTSConfig.PredictSolution         = MHMOTSConfig.PredictSolution == nil and false or MHMOTSConfig.PredictSolution;
    MHMOTSConfig.PrintResettedPlayerName = MHMOTSConfig.PrintResettedPlayerName == nil and true or MHMOTSConfig.PrintResettedPlayerName;
    MHMOTSConfig.ShowAtBoss              = MHMOTSConfig.ShowAtBoss == nil and true or MHMOTSConfig.ShowAtBoss;
    MHMOTSConfig.StartInMinMode          = MHMOTSConfig.StartInMinMode == nil and false or MHMOTSConfig.StartInMinMode;
    MHMOTSConfig.UseColoredSymbols       = MHMOTSConfig.UseColoredSymbols == nil and true or MHMOTSConfig.UseColoredSymbols;
    MHMOTSConfig.ShowSequenceNumbers     = MHMOTSConfig.ShowSequenceNumbers == nil and true or MHMOTSConfig.ShowSequenceNumbers;

    MHMOTSConfig.AutoAnnouncer              = MHMOTSConfig.AutoAnnouncer == nil and false or MHMOTSConfig.AutoAnnouncer;
    MHMOTSConfig.AutoAnnouncerAsPartyLeader = MHMOTSConfig.AutoAnnouncerAsPartyLeader == nil and true or MHMOTSConfig.AutoAnnouncerAsPartyLeader;
    MHMOTSConfig.AutoAnnouncerAsAlways      = MHMOTSConfig.AutoAnnouncerAsAlways == nil and false or MHMOTSConfig.AutoAnnouncerAsAlways;
    MHMOTSConfig.AutoAnnouncerAsTank        = MHMOTSConfig.AutoAnnouncerAsTank == nil and false or MHMOTSConfig.AutoAnnouncerAsTank;
    MHMOTSConfig.AutoAnnouncerAsHealer      = MHMOTSConfig.AutoAnnouncerAsHealer == nil and false or MHMOTSConfig.AutoAnnouncerAsHealer;

    scrollChild.Data.SyncEnabled:SetChecked(MHMOTSConfig.SyncEnabled);
    scrollChild.Data.PredictSolution:SetChecked(MHMOTSConfig.PredictSolution);
    scrollChild.Data.UseColoredSymbols:SetChecked(MHMOTSConfig.UseColoredSymbols);
    scrollChild.Data.ShowSequenceNumbers:SetChecked(MHMOTSConfig.ShowSequenceNumbers);
    scrollChild.Data.PrintResettedPlayerName:SetChecked(MHMOTSConfig.PrintResettedPlayerName);
    scrollChild.Data.ShowAtBoss:SetChecked(MHMOTSConfig.ShowAtBoss);
    scrollChild.Data.StartInMinMode:SetChecked(MHMOTSConfig.StartInMinMode);

    scrollChild.Data.AutoAnnouncer:SetChecked(MHMOTSConfig.AutoAnnouncer);
    scrollChild.Data.AutoAnnouncerAsPartyLeader:SetChecked(MHMOTSConfig.AutoAnnouncerAsPartyLeader);
    scrollChild.Data.AutoAnnouncerAsAlways:SetChecked(MHMOTSConfig.AutoAnnouncerAsAlways);
    scrollChild.Data.AutoAnnouncerAsTank:SetChecked(MHMOTSConfig.AutoAnnouncerAsTank);
    scrollChild.Data.AutoAnnouncerAsHealer:SetChecked(MHMOTSConfig.AutoAnnouncerAsHealer);

    scrollChild.Data.AutoAnnouncerAsPartyLeader:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    scrollChild.Data.AutoAnnouncerAsAlways:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    scrollChild.Data.AutoAnnouncerAsTank:SetEnabled(MHMOTSConfig.AutoAnnouncer);
    scrollChild.Data.AutoAnnouncerAsHealer:SetEnabled(MHMOTSConfig.AutoAnnouncer);

    MazeHelper:CreateButtons();

    self:RegisterEvent('PLAYER_LOGIN');
    self:RegisterEvent('PLAYER_ENTERING_WORLD');
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED');

    if MHMOTSConfig.SyncEnabled then
        self:RegisterEvent('CHAT_MSG_ADDON');
    end

    _G['SLASH_MAZEHELPER1'] = '/mh';
    SlashCmdList['MAZEHELPER'] = function()
        MazeHelper.frame:SetShown(not MazeHelper.frame:IsShown());
    end
end