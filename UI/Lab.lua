-- Wolf Lab: the window. Wolf's classic frame (the game's dialog edge, round portrait, red X, the
-- game's tabs on the header line), four pages (Today, Market, Make gold, You) and Settings behind the gear.
local ADDON, FT = ...
local UI, L = FT.UI, FT.L
local D = FT.Data

-- the FARM verdict's colour (the game's legendary orange), in both looks
UI.LOOKS.classic.orange = { 1, 0.604, 0.180 }
UI.LOOKS.dark.orange = { 1, 0.604, 0.180 }

local Lab = {}
FT.Lab = Lab
FT.Pages = FT.Pages or {}

local ORDER = { "today", "market", "make", "you" }
local LABELS = { today = L["Today"], market = L["Market"], make = L["Make gold"], you = L["You"], settings = L["Settings"] }
local W, H = 1240, 740

local win, content, nav, gear
local pages = {}
local current, lastPage

---------------------------------------------------------------------------
-- Shared pieces the pages use
---------------------------------------------------------------------------
-- a verdict badge: one of the six words, its colour
function Lab.Badge(parent, w, h)
    local b = UI.Badge(parent, w or 64, h or 20)
    local set = b.Set
    function b:Set(kind) set(self, kind, FT.SignalText(kind)) end
    return b
end

-- an item's worth line, short: gold only from 1g up ("14g"), silver under it
function Lab.Gold(c) return FT.Money(c, "gold") end

-- a copy box for a link (addons can't open the browser)
local linkBox
function Lab.ShowLink(title, url)
    if not linkBox then
        linkBox = CreateFrame("Frame", "WolfLabLink", UIParent, UI.EdgeTemplate())
        linkBox:SetSize(460, 118)
        linkBox:SetPoint("CENTER", 0, 120)
        linkBox:SetFrameStrata("DIALOG")
        linkBox:EnableMouse(true)
        UI.Skin(linkBox, "popup", "bg1")
        linkBox.title = UI.Text(linkBox, 14, "accent")
        linkBox.title:SetPoint("TOPLEFT", 16, -14)
        linkBox.title:SetPoint("RIGHT", -40, 0)
        linkBox.hint = UI.Text(linkBox, 12, "muted")
        linkBox.hint:SetPoint("TOPLEFT", linkBox.title, "BOTTOMLEFT", 0, -6)
        linkBox.hint:SetText(L["Copy it (Ctrl+C) and paste it in your browser."])
        linkBox.edit = UI.Input(linkBox, 428, 24, "")
        linkBox.edit:SetPoint("BOTTOMLEFT", 16, 16)
        linkBox.edit:SetScript("OnEscapePressed", function() linkBox:Hide() end)
        local x = UI.CloseButton(linkBox, function() linkBox:Hide() end, 26)
        x:SetPoint("TOPRIGHT", -4, -4)
        table.insert(UISpecialFrames, "WolfLabLink")
    end
    linkBox.title:SetText(title or "")
    linkBox.edit:SetText(url or "")
    linkBox:Show()
    linkBox.edit:SetFocus()
    linkBox.edit:HighlightText()
end

function Lab.Wowhead(id)
    Lab.ShowLink(FT.ItemText(id) .. "  " .. FT.C("muted", L["on Wowhead"]), "https://www.wowhead.com/forever/item=" .. id)
end

-- a line about an item for guild chat, put in the chat box: you send it yourself (Enter)
function Lab.Share(id)
    local it = D.items[id]
    if not it then return end
    local name = FT.Item(id) or it.name
    -- chat can't show the coin icons: g / s / c instead
    local price = (FT.Money(it.price, "short"):gsub("|T.-|t", function(t)
        return t:find("Gold") and "g" or (t:find("Silver") and "s" or "c")
    end))
    local text = string.format(L["%s: %s, %s vs normal (Wolf Lab sample)"], name, price, FT.Pct(it.price / it.normal - 1, true))
    if ChatFrame_OpenChat then ChatFrame_OpenChat("/g " .. text) end
end

-- the watchlist (the Lab's own, in WolfLabDB)
function Lab.IsWatched(id) return FT.db and FT.db.watch[id] and true or false end
function Lab.ToggleWatch(id)
    if not FT.db then return end
    FT.db.watch[id] = not FT.db.watch[id] or nil
    FT.Fire("FT_WATCH_CHANGED", id)
end

-- open an item's page (from anywhere)
function Lab.OpenItem(id)
    FT.Show("market")
    if FT.Pages.market and FT.Pages.market.Select then FT.Pages.market.Select(id) end
end

-- an item's tooltip: the game's, then the Lab's two lines
function Lab.ItemTip(owner, id, why)
    UI.TipItem(owner, id)
    local it = D.items[id]
    if it then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(FT.C(FT.SIGNAL_COLORS[it.verdict] or "muted", FT.SignalText(it.verdict)) .. "  " .. FT.Money(it.price, "short"),
            FT.Pct(it.price / it.normal - 1) .. FT.C("dim", " " .. L["vs normal"]))
        GameTooltip:AddLine(why or it.reason, 0.85, 0.85, 0.85, true)
        GameTooltip:AddLine(L["Click: its page"], 0.58, 0.55, 0.5)
    end
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function SavePos()
    local point, _, relPoint, x, y = win:GetPoint(1)
    local p = FT.db.frame
    p.point, p.relPoint, p.x, p.y = point, relPoint, x, y
end

local function Place()
    local p = FT.db.frame
    win:ClearAllPoints()
    win:SetSize(W, H)
    if p.point then
        win:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
end

function FT.ResetWindow() if win then Place() end end

-- the ticker: names and moves, sliding slowly to the left
local function BuildTicker(parent)
    local t = CreateFrame("Frame", nil, parent)
    t:SetHeight(UI.RowH(22))
    UI.Fill(t, "black", 0.45)
    if t.SetClipsChildren then t:SetClipsChildren(true) end
    local parts = {}
    for _, id in ipairs(D.order) do
        local it = D.items[id]
        parts[#parts + 1] = FT.ItemText(id) .. " " .. FT.Money(it.price, "short") .. " " .. FT.Pct(it.ch1)
    end
    local text = table.concat(parts, "      ") .. "      "
    t.a = UI.Text(t, 12, "muted")
    t.b = UI.Text(t, 12, "muted")
    t.a:SetText(text)
    t.b:SetText(text)
    -- the tape runs past the window's edge on purpose (clipped): the layout test leaves it out
    t.a.__tape, t.b.__tape = true, true
    t.x = 0
    local function Lay()
        local w = math.max(200, math.ceil(t.a:GetStringWidth() or 0))
        t.w = w
        t.a:ClearAllPoints(); t.a:SetPoint("LEFT", t, "LEFT", 10 - t.x, 0)
        t.b:ClearAllPoints(); t.b:SetPoint("LEFT", t.a, "LEFT", w, 0)
    end
    Lay()
    t:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() then return end -- it stops under the mouse
        self.x = (self.x + elapsed * 18) % (self.w or 1000) -- slow: 18 px a second
        Lay()
    end)
    return t
end

-- the price light: one dot and its age; the AH-vs-API split in the hover
local function BuildFresh(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(150, 22)
    f:EnableMouse(true)
    UI.Fill(f, "black", 0.5)
    UI.Border(f, "line", 0.8)
    f.dot = UI.Dot(f, 8, "up", 1, "OVERLAY")
    f.dot:SetPoint("LEFT", 9, 0)
    f.text = UI.Text(f, 12, "text")
    f.text:SetPoint("LEFT", f.dot, "RIGHT", 7, 0)
    f.text:SetText(string.format(L["Prices %d min old"], D.pricesAge))
    f:SetWidth(math.ceil(f.text:GetStringWidth()) + 34)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["How fresh the prices are"], 1, 1, 1)
        GameTooltip:AddDoubleLine(L["Your AH scan"], L["20 min ago"], 0.87, 0.75, 0.42, 1, 1, 1)
        GameTooltip:AddDoubleLine(L["Blizzard's prices"], L["45 min ago"], 0.87, 0.75, 0.42, 1, 1, 1)
        GameTooltip:AddLine(L["Green: under an hour. Yellow: a few hours. Red: older. (Sample.)"], 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

local function Page(key)
    local p = pages[key]
    if p then return p end
    p = CreateFrame("Frame", nil, content)
    p:SetAllPoints()
    pages[key] = p
    local mod = FT.Pages[key]
    if mod and mod.Build then
        local ok, err = pcall(mod.Build, p)
        if not ok then geterrorhandler()(err) end
    end
    return p
end

function FT.SelectPage(key)
    if not FT.Pages[key] then key = "today" end
    current = key
    if key ~= "settings" then lastPage = key end
    nav:SetValue(key ~= "settings" and key or nil)
    gear:SetActive(key == "settings")
    local p = Page(key)
    for k, pg in pairs(pages) do pg:SetShown(k == key) end
    local mod = FT.Pages[key]
    if mod and mod.Show then
        local ok, err = pcall(mod.Show, p)
        if not ok then geterrorhandler()(err) end
    end
end

-- every page again (after Settings > Meme words)
function FT.RefreshAll()
    for k, p in pairs(pages) do
        local mod = FT.Pages[k]
        if mod and mod.Show and p:IsShown() then pcall(mod.Show, p) end
        if mod and mod.Dirty then mod.Dirty() end
    end
end

local function Build()
    win = CreateFrame("Frame", "WolfLabFrame", UIParent, UI.EdgeTemplate())
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetScale(FT.S.scale or 1)
    Place()
    UI.Skin(win, "window", "bg0")
    -- (v0.7: no title banner over the top edge - the header has the logo, and drags the window)
    table.insert(UISpecialFrames, "WolfLabFrame")

    -- header: portrait, the name, the four tabs; the price light, Settings and the X on the right
    local header = CreateFrame("Frame", nil, win)
    header:SetPoint("TOPLEFT", UI.INSET, -UI.INSET)
    header:SetPoint("TOPRIGHT", -UI.INSET, -UI.INSET)
    header:SetHeight(48)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() win:StartMoving() end)
    header:SetScript("OnDragStop", function() win:StopMovingOrSizing(); SavePos() end)
    local hl = UI.HLine(header, "line")
    hl:SetPoint("BOTTOMLEFT")
    hl:SetPoint("BOTTOMRIGHT")

    local logo = UI.Classic() and UI.Portrait(header, 22, FT.LOGO) or UI.Icon(header, 24)
    logo:SetIcon(FT.LOGO)
    logo:SetPoint("LEFT", UI.Classic() and 10 or 14, 0)
    local brand = UI.Text(header, 15, "accent")
    brand:SetPoint("LEFT", logo, "RIGHT", UI.Classic() and 18 or 10, 0)
    brand:SetText("WOLF")
    local lab = UI.Text(header, 11, "dim")
    lab:SetPoint("LEFT", brand, "RIGHT", 5, -1)
    lab:SetText(L["LAB"])

    local items = {}
    for _, key in ipairs(ORDER) do items[#items + 1] = { key, LABELS[key] } end
    nav = UI.NavTabs(header, items, function(key) FT.SelectPage(key) end)
    nav:SetPoint("LEFT", lab, "RIGHT", 22, 0)

    local close = UI.CloseButton(header, function() win:Hide() end)
    close:SetPoint("RIGHT", UI.Classic() and -4 or -8, 0)
    gear = UI.Button(header, L["Settings"], nil, 22, "default", function()
        if current == "settings" then FT.SelectPage(lastPage or "today") else FT.SelectPage("settings") end
    end)
    gear:FitText(22)
    gear:SetPoint("RIGHT", close, "LEFT", -8, 0)
    local fresh = BuildFresh(header)
    fresh:SetPoint("RIGHT", gear, "LEFT", -10, 0)

    local ticker = BuildTicker(win)
    ticker:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    ticker:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -1)

    -- status line: what this is
    local status = CreateFrame("Frame", nil, win)
    status:SetPoint("BOTTOMLEFT", UI.INSET, UI.INSET)
    status:SetPoint("BOTTOMRIGHT", -UI.INSET, UI.INSET)
    status:SetHeight(UI.RowH(22))
    local sl = UI.HLine(status, "line")
    sl:SetPoint("TOPLEFT")
    sl:SetPoint("TOPRIGHT")
    local left = UI.Text(status, 11, "dim")
    left:SetPoint("LEFT", 12, 0)
    left:SetText(L["Wolf Lab: the new look with sample data. Nothing here is real or touches Wolf."])
    local right = UI.Text(status, 11, "dim", "RIGHT")
    right:SetPoint("RIGHT", -12, 0)
    right:SetText("/wolflab  ·  " .. tostring(FT.VERSION))

    content = CreateFrame("Frame", nil, win)
    content:SetPoint("TOPLEFT", ticker, "BOTTOMLEFT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", status, "TOPRIGHT", 0, 0)
    win:Hide()
end

function FT.Show(key)
    if not FT.db then return end
    if not win then Build() end
    win:Show()
    win:Raise()
    FT.SelectPage(key or current or "today")
end

function FT.Toggle(key)
    if win and win:IsShown() and not key then win:Hide() else FT.Show(key) end
end

-- once, the first time: a line in chat saying how to open it (never a pop-up)
FT.On("PLAYER_LOGIN", function()
    if FT.db and not FT.db.told then
        FT.db.told = true
        FT.Print(L["the new look, with sample data: type /wolflab to open it."])
    end
end)
