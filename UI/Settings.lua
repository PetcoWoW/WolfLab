-- Wolf Lab: Settings, slimmed the way Wolf's will be: the look, the text size, the meme words. The tuning knobs
-- (deal %, minimum profit and the like) are gone from sight.
local ADDON, FT = ...
local UI, L = FT.UI, FT.L

local P = {}
FT.Pages.settings = P

local PAD = 18

local function Row(p, y, label, hint)
    local t = UI.Text(p, 14, "text")
    t:SetPoint("TOPLEFT", PAD, y)
    t:SetText(label)
    local h = UI.Text(p, 12, "dim")
    h:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
    h:SetText(hint or "")
    return t
end

function P.Build(p)
    local title = UI.Text(p, 17, "accent")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(L["Settings"])

    local step = UI.RowH(62)
    local y = -PAD - 40
    Row(p, y, L["Look"], L["Classic: the game's own frames. Dark: the night terminal. Takes a reload."])
    P.look = UI.Segmented(p, { { "classic", L["Classic"] }, { "dark", L["Dark"] } }, function(v)
        FT.S.look = v
        P.reload:Show()
    end, 22)
    P.look:SetPoint("TOPLEFT", 360, y)

    y = y - step
    Row(p, y, L["Text size"], L["Bigger text everywhere. Takes a reload."])
    P.size = UI.Segmented(p, { { 0, L["Normal"] }, { 1, L["Larger"] }, { 2, L["Largest"] } }, function(v)
        FT.S.textSize = v
        P.reload:Show()
    end, 22)
    P.size:SetPoint("TOPLEFT", 360, y)

    y = y - step
    Row(p, y, L["Meme words"], L["CASH OUT for SELL, HODL for HOLD, APE IN for BUY. Off: the six plain verdicts."])
    P.meme = UI.Check(p, L["On"], function(on)
        FT.S.meme = on and true or false
        FT.RefreshAll()
    end)
    P.meme:SetPoint("TOPLEFT", 360, y)

    y = y - step
    Row(p, y, L["Window"], L["Put it back in the middle of the screen (or type /wolflab reset)."])
    local reset = UI.Button(p, L["Put it back"], nil, 22, "default", function() FT.ResetWindow() end)
    reset:FitText(26)
    reset:SetPoint("TOPLEFT", 360, y)

    P.reload = UI.Button(p, L["Reload now"], nil, 26, "primary", function() ReloadUI() end)
    P.reload:FitText(30)
    P.reload:SetPoint("TOPLEFT", PAD, y - step)
    P.reload:Hide()

    local about = UI.Text(p, 13, "muted")
    about:SetPoint("BOTTOMLEFT", PAD, PAD)
    about:SetPoint("RIGHT", -PAD, 0)
    about:SetJustifyV("BOTTOM")
    if about.SetWordWrap then about:SetWordWrap(true) end
    about:SetHeight(UI.RowH(60))
    about:SetText(L["Wolf Lab is a preview of Wolf's next look with sample data. It reads nothing from the auction house, your bags or other addons and sends nothing. Delete it any time: Wolf doesn't need it."])
end

function P.Show()
    P.look:SetValue(FT.S.look == "dark" and "dark" or "classic")
    P.size:SetValue(tonumber(FT.S.textSize) or 0)
    if P.meme.SetChecked then P.meme:SetChecked(FT.S.meme and true or false) end
end
