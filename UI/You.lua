-- Wolf Lab: You. What used to be Portfolio, Sell yours, Sessions and Characters. Sell yours is gone as a page of its
-- own: every holding carries its verdict (SELL, HOLD...) right in the row.
local ADDON, FT = ...
local UI, L = FT.UI, FT.L
local D, Lab = FT.Data, FT.Lab

local P = {}
FT.Pages.you = P

local PAD = 14
local current = "holdings"

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

    P.holdings = Place(Table(p, HOLD_COLS, function(row, h)
        local it = D.items[h.id]
        row.cells.name:SetText(FT.ItemText(h.id))
        row.cells.qty:SetText(FT.Num(h.qty))
        row.cells.where:SetText(L[h.where])
        row.cells.worth:SetText(FT.Money(it.price * h.qty, "gold"))
        row.cells.call:Set(it.verdict)
    end, function(h) Lab.OpenItem(h.id) end, function(row, h) Lab.ItemTip(row, h.id) end))

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
    P.holdings:SetShown(current == "holdings")
    P.sessions:SetShown(current == "sessions")
    P.chars:SetShown(current == "chars")
    if current == "holdings" then
        P.lead:SetText(L["Bags, bank, mail and your alts, at today's prices. The badge says what to do with each."])
        local rows = {}
        for _, h in ipairs(D.holdings) do rows[#rows + 1] = h end
        table.sort(rows, function(a, b) return D.items[a.id].price * a.qty > D.items[b.id].price * b.qty end)
        P.holdings.list:SetItems(rows)
    elseif current == "sessions" then
        P.lead:SetText(L["Farming sessions: right-click the minimap button to start one (in Wolf)."])
        P.sessions.list:SetItems(D.sessions)
    else
        P.lead:SetText(L["Every character that has logged in with Wolf: log one in to bring it up to date."])
        P.chars.list:SetItems(D.characters)
    end
end

function P.Dirty() if P.holdings then P.holdings.list:Refresh() end end
