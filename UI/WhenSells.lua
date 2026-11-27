-- Wolf Lab: When it sells, at a glance. Three answers first (when to sell, when to buy, the busiest day), then one
-- strip of the 24 hours (blue cheaper, gold pricier, now marked). The charts only behind "Show the charts".
local ADDON, FT = ...
local UI, L = FT.UI, FT.L
local D, Lab = FT.Data, FT.Lab

local WS = {}
FT.WhenSells = WS

local W, H, H_CHARTS = 540, 340, 520
-- wider with the larger text sizes
local function Width() return W + 40 * (tonumber(FT.S and FT.S.textSize) or 0) end
local f

-- 0 (cheapest) .. 1 (priciest) -> a colour from the game's blue through dark leather to gold
local function HourColor(v)
    local blue, mid, gold = { 0.30, 0.62, 1 }, { 0.17, 0.15, 0.12 }, { 1, 0.82, 0 }
    local a, b, t
    if v < 0.45 then a, b, t = blue, mid, v / 0.45 else a, b, t = mid, gold, (v - 0.45) / 0.55 end
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

local function Answer(parent, y)
    local r = UI.Panel(parent, "bg2", "line")
    r:SetPoint("TOPLEFT", 16, y)
    r:SetPoint("RIGHT", -16, 0)
    r:SetHeight(UI.RowH(36))
    r.badge = Lab.Badge(r, 58, 20)
    r.badge:SetPoint("LEFT", 10, 0)
    r.text = UI.Text(r, 15, "text")
    r.text:SetPoint("LEFT", r.badge, "RIGHT", 12, 0)
    r.text:SetPoint("RIGHT", -10, 0)
    return r
end

local function Build()
    f = CreateFrame("Frame", "WolfLabWhenSells", UIParent, UI.EdgeTemplate())
    f:SetSize(Width(), H)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.Skin(f, "popup", "bg1")
    table.insert(UISpecialFrames, "WolfLabWhenSells")

    f.icon = UI.Icon(f, 32)
    f.icon:SetPoint("TOPLEFT", 16, -14)
    f.title = UI.Text(f, 17, "accent")
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, 0)
    f.title:SetText(L["When it sells"])
    f.item = UI.Text(f, 13, "text")
    f.item:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    local x = UI.CloseButton(f, function() f:Hide() end, 28)
    x:SetPoint("TOPRIGHT", -4, -4)

    local top = -58
    f.sell = Answer(f, top)
    f.buy = Answer(f, top - UI.RowH(42))
    f.day = Answer(f, top - UI.RowH(42) * 2)

    -- the 24 hours
    local y = top - UI.RowH(42) * 3 - 10
    f.stripTitle = UI.Text(f, 13, "muted")
    f.stripTitle:SetPoint("TOPLEFT", 16, y)
    f.stripTitle:SetText(L["Hour by hour"])
    f.strip = CreateFrame("Frame", nil, f)
    f.strip:SetPoint("TOPLEFT", 16, y - 20)
    f.strip:SetPoint("RIGHT", -16, 0)
    f.strip:SetHeight(26)
    f.cells = {}
    for h = 1, 24 do f.cells[h] = f.strip:CreateTexture(nil, "ARTWORK") end
    f.now = CreateFrame("Frame", nil, f.strip)
    f.now.edge = {}
    for k = 1, 4 do f.now.edge[k] = UI.Tex(f.now, "OVERLAY", "text", 1) end
    f.labels = {}
    for k, h in ipairs({ 0, 6, 12, 18 }) do
        local t = UI.Text(f, 11, "dim")
        t:SetText(FT.Hour(h))
        f.labels[k] = { t = t, h = h }
    end
    f.nowText = UI.Text(f, 11, "text")
    f.nowText:SetText(L["now"])
    f.legend = UI.Text(f, 11, "dim")
    f.legend:SetPoint("TOPLEFT", f.strip, "BOTTOMLEFT", 0, -22)
    f.legend:SetText(FT.C("blue", "■") .. " " .. L["cheaper"] .. "     " .. FT.C("accent", "■") .. " " .. L["pricier"])

    -- the charts, for anyone who wants them: price by hour and sales by weekday, as bars
    f.charts = CreateFrame("Frame", nil, f)
    f.charts:SetPoint("TOPLEFT", f.legend, "BOTTOMLEFT", 0, -14)
    f.charts:SetPoint("RIGHT", -16, 0)
    f.charts:SetHeight(160)
    f.charts:Hide()
    local ct1 = UI.Text(f.charts, 12, "muted"); ct1:SetPoint("TOPLEFT", 0, 0); ct1:SetText(L["Price by hour of the day"])
    local ct2 = UI.Text(f.charts, 12, "muted"); ct2:SetPoint("TOPLEFT", 330, 0); ct2:SetText(L["Sales by day"])
    f.hbars, f.dbars, f.dlabels = {}, {}, {}
    for h = 1, 24 do f.hbars[h] = f.charts:CreateTexture(nil, "ARTWORK") end
    local DAYS = { "M", "T", "W", "T", "F", "S", "S" }
    for d = 1, 7 do
        f.dbars[d] = f.charts:CreateTexture(nil, "ARTWORK")
        local t = UI.Text(f.charts, 11, "dim", "CENTER")
        t:SetText(L[DAYS[d]])
        f.dlabels[d] = t
    end

    f.toggle = UI.Button(f, L["Show the charts"], nil, 22, "default", function()
        f.showCharts = not f.showCharts
        WS.Fill()
    end)
    f.toggle:SetPoint("BOTTOMLEFT", 16, 14)
    f.note = UI.Text(f, 11, "dim", "RIGHT")
    f.note:SetPoint("BOTTOMRIGHT", -16, 18)
    f.note:SetText(L["Your clock · from 12 days of prices (sample)"])
    f:Hide()
end

function WS.Fill()
    local id = f.id
    local it = D.items[id]
    if not it then return end
    f.icon:SetItem(id)
    f.item:SetText(FT.ItemText(id))
    local hi, lo = math.floor(it.price * 1.03), math.floor(it.price * 0.93)
    f.sell.badge:Set("SELL")
    f.sell.text:SetText(FT.C("text", FT.Hour(it.sell[1]) .. "–" .. FT.Hour(it.sell[2])) .. FT.C("muted", "  ·  " ..
        string.format(L["priciest (~%s): post just before"], FT.Money(hi, "short"))))
    f.buy.badge:Set("BUY")
    f.buy.text:SetText(FT.C("text", FT.Hour(it.buy[1]) .. "–" .. FT.Hour(it.buy[2])) .. FT.C("muted", "  ·  " ..
        string.format(L["cheapest (~%s)"], FT.Money(lo, "short"))))
    f.day.badge:Set("DAY")
    f.day.badge.text:SetText(L["DAY"])
    f.day.text:SetText(FT.C("text", it.day) .. FT.C("muted", "  ·  " .. L["busiest day of the week"]))

    local hours = D.Hours(id)
    local w = f.strip:GetWidth()
    if not w or w <= 0 then w = Width() - 32 end
    local cw = (w - 23 * 2) / 24
    for h = 1, 24 do
        local c = f.cells[h]
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", f.strip, "TOPLEFT", (h - 1) * (cw + 2), 0)
        c:SetSize(cw, 26)
        c:SetColorTexture(HourColor(hours[h]))
    end
    local nowH = tonumber(date("%H")) or 0
    local nx = nowH * (cw + 2)
    f.now:ClearAllPoints()
    f.now:SetPoint("TOPLEFT", f.strip, "TOPLEFT", nx - 2, 2)
    f.now:SetSize(cw + 4, 30)
    local e = f.now.edge
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(2)
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(2)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(2)
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(2)
    for _, lb in ipairs(f.labels) do
        lb.t:ClearAllPoints()
        lb.t:SetPoint("TOPLEFT", f.strip, "BOTTOMLEFT", lb.h * (cw + 2), -4)
        -- the "now" label takes the place of an hour label it would sit on
        lb.t:SetShown(math.abs(lb.h - nowH) > 2)
    end
    f.nowText:ClearAllPoints()
    f.nowText:SetPoint("TOP", f.now, "BOTTOM", 0, -2)

    f.charts:SetShown(f.showCharts and true or false)
    f.toggle:SetLabel(f.showCharts and L["Hide the charts"] or L["Show the charts"])
    f.toggle:FitText(26)
    f:SetHeight(f.showCharts and H_CHARTS or H)
    if f.showCharts then
        local bw = (300 - 23) / 24
        for h = 1, 24 do
            local b = f.hbars[h]
            local bh = 12 + hours[h] * 100
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", f.charts, "BOTTOMLEFT", (h - 1) * (bw + 1), 18)
            b:SetSize(bw, bh)
            b:SetColorTexture(HourColor(hours[h]))
        end
        local busy = { Monday = 1, Tuesday = 2, Wednesday = 3, Thursday = 4, Friday = 5, Saturday = 6, Sunday = 7 }
        local peak = busy[it.day] or 2
        for d = 1, 7 do
            local b = f.dbars[d]
            local v = (d == peak) and 1 or (0.45 + ((d * 37) % 30) / 100)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", f.charts, "BOTTOMLEFT", 330 + (d - 1) * 24, 18)
            b:SetSize(18, 12 + v * 100)
            local r, g, bb = UI.RGB(d == peak and "accent" or "line")
            b:SetColorTexture(r, g, bb, 1)
            f.dlabels[d]:ClearAllPoints()
            f.dlabels[d]:SetPoint("TOP", b, "BOTTOM", 0, -3)
        end
    end
end

function WS.Open(id)
    if not f then Build() end
    f.id = id or f.id or 12363
    f:Show()
    f:Raise()
    WS.Fill()
end
