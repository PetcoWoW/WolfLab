-- Wolf Lab: You. What used to be Portfolio, Sell yours, Sessions and Characters. Sell yours is gone as a page of its
-- own: every holding carries its verdict (SELL, HOLD...) right in the row.
local ADDON, FT = ...
local UI, L = FT.UI, FT.L
local D, Lab = FT.Data, FT.Lab

local P = {}
FT.Pages.you = P

local PAD = 14
local current = "holdings"
local BuildDonutBox, LIQ_TIP -- below

-- a header and a list on the same columns
local function Table(parent, cols, update, onClick, onEnter)
    local box = UI.Panel(parent, "bg1", "line")
    box.head = UI.Header(box, cols)
    box.head:SetPoint("TOPLEFT", 4, -4)
    box.head:SetPoint("TOPRIGHT", -4, -4)
    box.list = UI.List(box, { rowHeight = UI.RowH(30), cols = cols, update = update, onClick = onClick, onEnter = onEnter })
    box.list:SetPoint("TOPLEFT", box.head, "BOTTOMLEFT", 0, -2)
    box.list:SetPoint("BOTTOMRIGHT", -4, 4)
    return box
end

local HOLD_COLS = {
    { key = "name", title = L["Item"], width = "fill", size = 14 },
    { key = "qty", title = L["How many"], width = 90, justify = "RIGHT", size = 14 },
    { key = "where", title = L["Where"], width = 110, size = 13, color = "muted" },
    { key = "worth", title = L["Worth"], width = 120, justify = "RIGHT", size = 14 },
    { key = "call", title = L["What to do"], width = 100, justify = "CENTER", make = function(row) return Lab.Badge(row, 76, 20) end },
}
local SESS_COLS = {
    { key = "name", title = L["Session"], width = "fill", size = 14 },
    { key = "zone", title = L["Zone"], width = 190, size = 13, color = "muted" },
    { key = "time", title = L["Time"], width = 80, justify = "RIGHT", size = 14 },
    { key = "gold", title = L["Found"], width = 100, justify = "RIGHT", size = 14 },
    { key = "rate", title = L["An hour"], width = 100, justify = "RIGHT", size = 14 },
    { key = "top", title = L["Best find"], width = 200, size = 14 },
}
local CHAR_COLS = {
    { key = "name", title = L["Character"], width = 200, size = 14 },
    { key = "profs", title = L["Professions"], width = "fill", size = 13, color = "muted" },
    { key = "gold", title = L["Gold"], width = 110, justify = "RIGHT", size = 14 },
    { key = "seen", title = L["Last seen"], width = 120, justify = "RIGHT", size = 13, color = "muted" },
}


---------------------------------------------------------------------------
-- The donut: where it is, or how liquid it is
---------------------------------------------------------------------------
local WHERE = { { "Gold", L["Gold"], "accent" }, { "Bags", L["Bags"], "blue" }, { "Bank", L["Bank"], "up" },
    { "Mail", L["Mail"], "purple" }, { "Bank alt", L["Bank alt"], "orange" }, { "On the AH", L["On the AH"], "muted" } }
local LIQUID = { { "cash", L["Gold on hand"], "accent" }, { "today", L["Sells today"], "up" }, { "week", L["Sells this week"], "blue" },
    { "slow", L["Slow to sell"], "orange" }, { "listed", L["Listed on the AH"], "muted" } }
LIQ_TIP = {
    today = L["Sells today: the market takes this many in a day."],
    week = L["Sells this week: a few days of the market's sales."],
    slow = L["Slow to sell: more than a week of what the market takes. Gold tied up."],
    listed = L["Listed on the AH: waiting for a buyer."],
}
local view = "where"

local function Value(h) return D.items[h.id].price * h.qty end

local function Slices()
    local defs = view == "where" and WHERE or LIQUID
    local sums = {}
    for _, dd in ipairs(defs) do sums[dd[1]] = 0 end
    sums[view == "where" and "Gold" or "cash"] = D.gold
    for _, h in ipairs(D.holdings) do
        local k = view == "where" and h.where or D.Liquidity(h)
        sums[k] = (sums[k] or 0) + Value(h)
    end
    local out = {}
    for _, dd in ipairs(defs) do
        if (sums[dd[1]] or 0) > 0 then
            out[#out + 1] = { key = dd[1], label = dd[2], color = dd[3], value = sums[dd[1]], tip = LIQ_TIP[dd[1]] }
        end
    end
    return out
end

-- the rows the table shows for a slice (nil: everything)
local function RowsFor(key)
    local rows = {}
    local coinKey = view == "where" and "Gold" or "cash"
    if not key or key == coinKey then
        for _, c in ipairs(D.characters) do rows[#rows + 1] = { coins = true, name = c.name, gold = c.gold } end
    end
    if key ~= coinKey then
        for _, h in ipairs(D.holdings) do
            local k = view == "where" and h.where or D.Liquidity(h)
            if not key or k == key then rows[#rows + 1] = h end
        end
    end
    table.sort(rows, function(a, b) return (a.coins and a.gold or Value(a)) > (b.coins and b.gold or Value(b)) end)
    return rows
end

BuildDonutBox = function(parent)
    local box = UI.Panel(parent, "bg1", "line")
    box:SetPoint("TOPLEFT", 0, 0)
    box:SetPoint("BOTTOMLEFT", 0, 0)
    box:SetWidth(400 + 20 * (tonumber(FT.S.textSize) or 0))
    P.donutBox = box
    box.seg = UI.Segmented(box, { { "where", L["Where it is"] }, { "liquid", L["How liquid"] } }, function(v)
        view = v
        P.donut.picked = nil
        P.FillHoldings()
    end, 22)
    box.seg:SetPoint("TOP", 0, -12)
    P.donut = Lab.Donut(box, 112, 36, function() P.FillHoldings() end)
    P.donut:SetPoint("TOP", box.seg, "BOTTOM", 0, -10)
    box.legend = {}
    for i = 1, 6 do
        local r = CreateFrame("Button", nil, box)
        r:SetHeight(UI.RowH(22))
        r:SetPoint("TOPLEFT", P.donut, "BOTTOMLEFT", -40, -6 - (i - 1) * UI.RowH(23))
        r:SetPoint("TOPRIGHT", P.donut, "BOTTOMRIGHT", 40, -6 - (i - 1) * UI.RowH(23))
        r.hover = UI.Tex(r, "BACKGROUND", "hl", 0.6)
        r.hover:SetAllPoints()
        r.hover:Hide()
        r.sw = UI.Tex(r, "ARTWORK", "accent", 1)
        r.sw:SetSize(10, 10)
        r.sw:SetPoint("LEFT", 6, 0)
        r.pct = UI.Text(r, 13, "muted", "RIGHT")
        r.pct:SetPoint("RIGHT", -6, 0); r.pct:SetWidth(40)
        r.val = UI.Text(r, 13, "text", "RIGHT")
        r.val:SetPoint("RIGHT", r.pct, "LEFT", -8, 0); r.val:SetWidth(80)
        r.label = UI.Text(r, 13, "text")
        r.label:SetPoint("LEFT", r.sw, "RIGHT", 8, 0)
        r.label:SetPoint("RIGHT", r.val, "LEFT", -6, 0)
        r:SetScript("OnEnter", function(self) self.hover:Show(); if self.key then P.donut.hover = self.key; P.donut:Draw() end end)
        r:SetScript("OnLeave", function(self) self.hover:Hide(); P.donut.hover = nil; P.donut:Draw() end)
        r:SetScript("OnClick", function(self) if self.key then P.donut:Pick(self.key) end end)
        box.legend[i] = r
    end
end

function P.FillHoldings()
    local slices = Slices()
    local total, liquid = 0, 0
    for _, sl in ipairs(slices) do total = total + sl.value end
    for _, h in ipairs(D.holdings) do if D.Liquidity(h) == "today" then liquid = liquid + Value(h) end end
    liquid = liquid + D.gold
    P.donutBox.seg:SetValue(view)
    P.donut:SetSlices(slices, FT.Money(total, "gold"),
        string.format(L["%d%% liquid"], total > 0 and math.floor(liquid / total * 100 + 0.5) or 0))
    for i, r in ipairs(P.donutBox.legend) do
        local sl = slices[i]
        r:SetShown(sl ~= nil)
        if sl then
            r.key = sl.key
            local c = UI.C[sl.color] or UI.C.text
            r.sw:SetColorTexture(c[1], c[2], c[3], 1)
            r.label:SetText(sl.label)
            r.val:SetText(FT.Money(sl.value, "gold"))
            r.pct:SetText(string.format("%d%%", math.floor(sl.share * 100 + 0.5)))
            UI.SetTextColor(r.label, P.donut.picked == sl.key and "accent" or "text")
        end
    end
    local key = P.donut.picked
    local sl = key and P.donut.byKey[key]
    P.filter:SetText(sl and (FT.C("accent", sl.label) .. "  " .. FT.Money(sl.value, "gold") .. FT.C("dim", string.format("  ·  %d%%", math.floor(sl.share * 100 + 0.5))))
        or (L["Everything"] .. FT.C("dim", "  ·  " .. L["click a slice to see just that"])))
    P.showAll:SetShown(sl ~= nil)
    P.holdings.list:SetItems(RowsFor(key))
end

function P.Build(p)
    P.seg = UI.Segmented(p, { { "holdings", L["Holdings"] }, { "sessions", L["Sessions"] }, { "chars", L["Characters"] } },
        function(v) current = v; P.Show() end, 24)
    P.seg:SetPoint("TOPLEFT", PAD, -PAD)

    P.total = UI.Text(p, 18, "text", "RIGHT")
    P.total:SetPoint("TOPRIGHT", -PAD, -PAD - 2)
    P.totalLabel = UI.Text(p, 13, "muted", "RIGHT")
    P.totalLabel:SetPoint("RIGHT", P.total, "LEFT", -10, -1)

    P.lead = UI.Text(p, 13, "dim")
    P.lead:SetPoint("TOPLEFT", P.seg, "BOTTOMLEFT", 2, -12)
    P.lead:SetPoint("RIGHT", -PAD, 0)

    local function Place(box)
        box:SetPoint("TOPLEFT", P.lead, "BOTTOMLEFT", -2, -10)
        box:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        box:Hide()
        return box
    end

    -- Holdings: the donut on the left, the table (what the chosen slice holds) on the right
    P.hold = CreateFrame("Frame", nil, p)
    P.hold:SetPoint("TOPLEFT", P.lead, "BOTTOMLEFT", -2, -10)
    P.hold:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    P.hold:Hide()
    BuildDonutBox(P.hold)
    P.filter = UI.Text(P.hold, 14, "text")
    P.filter:SetPoint("TOPLEFT", P.donutBox, "TOPRIGHT", 14, -6)
    P.showAll = UI.Button(P.hold, L["Show everything"], nil, 22, "default", function() P.donut:Pick(nil) end)
    P.showAll:FitText(24)
    P.showAll:SetPoint("TOPRIGHT", 0, -2)
    P.holdings = Table(P.hold, HOLD_COLS, function(row, h)
        if h.coins then
            row.cells.name:SetText(FT.C("accent", h.name) .. FT.C("dim", "  " .. L["gold on hand"]))
            row.cells.qty:SetText("")
            row.cells.where:SetText(L["Coins"])
            row.cells.worth:SetText(FT.Money(h.gold, "gold"))
            row.cells.call:Hide()
            return
        end
        local it = D.items[h.id]
        row.cells.call:Show()
        row.cells.name:SetText(FT.ItemText(h.id))
        row.cells.qty:SetText(FT.Num(h.qty))
        row.cells.where:SetText(L[h.where])
        row.cells.worth:SetText(FT.Money(it.price * h.qty, "gold"))
        row.cells.call:Set(it.verdict)
    end, function(h) if h.id then Lab.OpenItem(h.id) end end, function(row, h)
        if h.id then Lab.ItemTip(row, h.id, LIQ_TIP[D.Liquidity(h)]) end
    end)
    P.holdings:SetPoint("TOPLEFT", P.donutBox, "TOPRIGHT", 12, -34)
    P.holdings:SetPoint("BOTTOMRIGHT", 0, 0)

    P.sessions = Place(Table(p, SESS_COLS, function(row, s)
        row.cells.name:SetText(s.name)
        row.cells.zone:SetText(s.zone)
        row.cells.time:SetText(string.format(L["%d min"], s.minutes))
        row.cells.gold:SetText(FT.Money(s.gold, "gold"))
        row.cells.rate:SetText(FT.Money(math.floor(s.gold * 60 / s.minutes), "gold"))
        row.cells.top:SetText(FT.ItemText(s.top))
    end, nil, function(row, s)
        UI.TipText(row, s.name, string.format(L["%d things found in %d minutes. Best find: %s."], s.found, s.minutes, FT.Item(s.top) or ""))
    end))

    P.chars = Place(Table(p, CHAR_COLS, function(row, c)
        row.cells.name:SetText(c.name .. FT.C("dim", "  " .. c.level .. " " .. L[c.class]))
        row.cells.profs:SetText(c.profs)
        row.cells.gold:SetText(FT.Money(c.gold, "gold"))
        row.cells.seen:SetText(L[c.seen])
    end))
end

function P.Show()
    P.seg:SetValue(current)
    local worth = D.gold
    for _, h in ipairs(D.holdings) do worth = worth + D.items[h.id].price * h.qty end
    P.totalLabel:SetText(L["Everything you own"])
    P.total:SetText(FT.Money(worth, "gold"))
    P.hold:SetShown(current == "holdings")
    P.sessions:SetShown(current == "sessions")
    P.chars:SetShown(current == "chars")
    if current == "holdings" then
        P.lead:SetText(L["Where your gold sits, at today's prices: hover a slice for its numbers, click one to see just that. The badge says what to do with each."])
        P.FillHoldings()
    elseif current == "sessions" then
        P.lead:SetText(L["Farming sessions: right-click the minimap button to start one (in Wolf)."])
        P.sessions.list:SetItems(D.sessions)
    else
        P.lead:SetText(L["Every character that has logged in with Wolf: log one in to bring it up to date."])
        P.chars.list:SetItems(D.characters)
    end
end

function P.Dirty() if P.holdings and P.hold:IsShown() then P.FillHoldings() end end
