-- Wolf Lab: a minimap button with Wolf's black wolf (placed away from Wolf's own). Click: the window.
-- Right-click: start or stop a sample session. Drag: move it around the minimap.
local ADDON, FT = ...
local UI, L = FT.UI, FT.L

local ICON = FT.LOGO
local mb

local function Place()
    local a = math.rad(FT.S.minimapAngle or 235) -- not where Wolf's sits (205)
    local r = (Minimap:GetWidth() or 140) / 2 + 8
    mb:ClearAllPoints()
    mb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function Build()
    mb = CreateFrame("Button", "WolfLabMinimapButton", Minimap)
    mb:SetSize(31, 31)
    mb:SetFrameStrata("MEDIUM")
    mb:SetFrameLevel(8)
    mb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mb:RegisterForDrag("LeftButton")
    mb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = mb:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(22, 22)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("CENTER")
    local icon = mb:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if icon.SetMask then icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    icon:SetPoint("CENTER")
    local border = mb:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    mb:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if FT.Session.Running() then FT.Session.Stop() else FT.Session.Start() end
        else
            FT.Toggle()
        end
    end)
    mb:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            if mx and px and s and s > 0 then
                FT.S.minimapAngle = math.deg(math.atan2(py / s - my, px / s - mx))
                Place()
            end
        end)
    end)
    mb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["Wolf Lab"], 1, 0.82, 0)
        GameTooltip:AddLine(L["The new look, sample data."], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Click: open"], 0.6, 0.6, 0.6)
        GameTooltip:AddLine(FT.Session.Running() and L["Right-click: stop the sample session"] or L["Right-click: start a sample session"], 0.6, 0.6, 0.6)
        GameTooltip:AddLine(L["Drag: move it"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    mb:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

FT.On("PLAYER_LOGIN", function()
    if not (FT.S and Minimap) then return end
    if not mb then Build() end
    Place()
    mb:Show()
end)
