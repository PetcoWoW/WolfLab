-- Wolf Lab: Today, the first page. What you own is worth, then two rows on the same three columns: Your top 3, and
-- under them In your bags, Going down today and Going up today (each scrolls).
local ADDON, FT = ...
local UI, L = FT.UI, FT.L
local D, Lab = FT.Data, FT.Lab

local P = {}
FT.Pages.today = P

local PAD, GAP = 14, 12

---------------------------------------------------------------------------
-- Your top 3: a card each
---------------------------------------------------------------------------
local function Card(parent)
    local c = UI.Panel(parent, "bg1", "line")
    c:EnableMouse(true)
    c.badge = Lab.Badge(c, 64, 20)
    c.badge:SetPoint("TOPLEFT", 12, -12)
    c.gold = UI.Text(c, 16, "text", "RIGHT")
    c.gold:SetPoint("TOPRIGHT", -12, -12)
    c.name = UI.Text(c, 15, "text")
    c.name:SetPoint("TOPLEFT", c.badge, "BOTTOMLEFT", 0, -10)
    c.name:SetPoint("RIGHT", -12, 0)
    c.text = UI.Text(c, 13, "muted")
    c.text:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -6)
    c.text:SetPoint("RIGHT", -12, 0)
    c.text:SetJustifyV("TOP")
    if c.text.SetWordWrap then c.text:SetWordWrap(true) end
    c.text:SetHeight(UI.RowH(36))
    c:SetScript("OnEnter", function(self) if self.id then Lab.ItemTip(self, self.id, self.why) end end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c:SetScript("OnMouseUp", function(self) if self.id then Lab.OpenItem(self.id) end end)
    function c:Set(m)
        self.id, self.why = m.id, m.text
        self.badge:Set(m.kind)
        if m.each then
            self.gold:SetText(FT.Money(m.each, "short") .. FT.C("dim", " " .. L["each"]))
        elseif m.kind == "HOLD" then
            self.gold:SetText(Lab.Gold(m.gold) .. FT.C("dim", " " .. L["held"]))
        else
            self.gold:SetText(FT.C("up", "+") .. Lab.Gold(m.gold))
        end
        self.name:SetText(FT.ItemText(m.id) .. (m.qty and FT.C("dim", "  × " .. FT.Num(m.qty)) or ""))
        self.text:SetText(m.text)
    end
    return c
end

-- a panel with a title line (and room on its right for a control)
local function Box(parent, title)
    local b = UI.Panel(parent, "bg1", "line")
    b.title = UI.Text(b, 14, "muted")
    b.title:SetPoint("TOPLEFT", 14, -12)
    b.title:SetText(title)
    return b
end

---------------------------------------------------------------------------
-- Movers today: a card for what went up, one for what went down; every item that moved, scrolls with the wheel
---------------------------------------------------------------------------
local function Movers(parent, way)
    local box = Box(parent, way == "up" and L["Going up today"] or L["Going down today"])
    box.list = UI.List(box, {
        rowHeight = UI.RowH(26),
        setup = function(row)
            row.ch = UI.Text(row, 14, "text", "RIGHT")
            row.ch:SetPoint("RIGHT", -4, 0); row.ch:SetWidth(52)
            row.price = UI.Text(row, 13, "muted", "RIGHT")
            row.price:SetPoint("RIGHT", row.ch, "LEFT", -8, 0); row.price:SetWidth(UI.RowH(70) + 4 * (tonumber(FT.S.textSize) or 0))
            row.name = UI.Text(row, 14, "text")
            row.name:SetPoint("LEFT", 6, 0)
            row.name:SetPoint("RIGHT", row.price, "LEFT", -6, 0)
        end,
        update = function(row, id)
            local it = D.items[id]
            UI.FitSize(row.name, FT.ItemText(id), 14, 3)
            row.price:SetText(FT.Money(it.price, "short"))
            row.ch:SetText(FT.Pct(it.ch1))
        end,
        onClick = function(id) Lab.OpenItem(id) end,
        onEnter = function(row, id) Lab.ItemTip(row, id) end,
    })
    box.list:SetPoint("TOPLEFT", 8, -38)
    box.list:SetPoint("BOTTOMRIGHT", -6, 8)
    function box:Fill()
        local ids = {}
        for _, id in ipairs(D.order) do
            local ch = D.items[id].ch1
            if (way == "up" and ch > 0.005) or (way == "down" and ch < -0.005) then ids[#ids + 1] = id end
        end
        table.sort(ids, function(x, y)
            if way == "up" then return D.items[x].ch1 > D.items[y].ch1 end
            return D.items[x].ch1 < D.items[y].ch1
        end)
        self.list:SetItems(ids)
        self.list:SetEmptyText(L["Nothing moved much today."])
    end
    return box
end

---------------------------------------------------------------------------
-- In your bags: what you're carrying, its worth and what to do with each (everyone has bags)
---------------------------------------------------------------------------
local function Bags(parent)
    local box = Box(parent, L["In your bags"])
    box.total = UI.Text(box, 14, "text", "RIGHT")
    box.total:SetPoint("TOPRIGHT", -14, -12)
    box.list = UI.List(box, {
        rowHeight = UI.RowH(30),
        setup = function(row)
            row.badge = Lab.Badge(row, 58, 18)
            row.badge:SetPoint("LEFT", 6, 0)
            row.worth = UI.Text(row, 13, "text", "RIGHT")
            row.worth:SetPoint("RIGHT", -4, 0); row.worth:SetWidth(UI.RowH(70) + 4 * (tonumber(FT.S.textSize) or 0))
            row.name = UI.Text(row, 14, "text")
            row.name:SetPoint("LEFT", row.badge, "RIGHT", 10, 0)
            row.name:SetPoint("RIGHT", row.worth, "LEFT", -6, 0)
        end,
        update = function(row, h)
            local it = D.items[h.id]
            row.badge:Set(it.verdict)
            UI.FitSize(row.name, FT.ItemText(h.id) .. FT.C("dim", " ×" .. FT.Num(h.qty)), 14, 3)
            row.worth:SetText(FT.Money(it.price * h.qty, "gold"))
        end,
        onClick = function(h) Lab.OpenItem(h.id) end,
        onEnter = function(row, h) Lab.ItemTip(row, h.id) end,
    })
    box.list:SetPoint("TOPLEFT", 8, -38)
    box.list:SetPoint("BOTTOMRIGHT", -6, 8)
    function box:Fill()
        local rows, total = {}, 0
        for _, h in ipairs(D.holdings) do
            if h.where == "Bags" then
                rows[#rows + 1] = h
                total = total + D.items[h.id].price * h.qty
            end
        end
        table.sort(rows, function(a, b) return D.items[a.id].price * a.qty > D.items[b.id].price * b.qty end)
        self.list:SetItems(rows)
        self.total:SetText(FT.Money(total, "gold"))
    end
    return box
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
-- lay frames on three equal columns of a row
local function Thirds(row, frames)
    UI.OnSize(row, function(self, w, h)
        local cw = math.floor((w - GAP * 2) / 3)
        for i, f in ipairs(frames) do
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * (cw + GAP), 0)
            f:SetSize(cw, h)
        end
    end)
end

function P.Build(p)
    local own = UI.Panel(p, "bg1", "line")
    own:SetPoint("TOPLEFT", PAD, -PAD)
    own:SetPoint("TOPRIGHT", -PAD, -PAD)
    own:SetHeight(UI.RowH(62))
    local label = UI.Text(own, 14, "muted")
    label:SetPoint("LEFT", 16, 0)
    label:SetText(L["Everything you own"])
    P.worth = UI.Text(own, 24, "text")
    P.worth:SetPoint("LEFT", label, "RIGHT", 18, 0)
    -- how much the last price update moved it, and since yesterday
    P.update = UI.Text(own, 14, "up")
    P.update:SetPoint("BOTTOMLEFT", P.worth, "RIGHT", 16, 1)
    P.since = UI.Text(own, 12, "muted")
    P.since:SetPoint("TOPLEFT", P.worth, "RIGHT", 16, -2)
    local days = UI.Text(own, 11, "dim", "RIGHT")
    days:SetPoint("RIGHT", -16, 0)
    days:SetText(L["last 24 updates"])
    P.spark = UI.Sparkline(own, 280, 34)
    P.spark:SetPoint("RIGHT", days, "LEFT", -12, 0)
    own:EnableMouse(true)
    own:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["Everything you own"], 1, 1, 1)
        GameTooltip:AddLine(L["Bags, bank, mail, the auction house and every character, at the latest prices, plus your gold."], 0.75, 0.75, 0.75, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["What each price update did to it"], 1, 0.82, 0)
        local pts = P.points or {}
        for i = #pts, math.max(2, #pts - 5), -1 do
            local p0, p1 = pts[i - 1], pts[i]
            local d = p1.v - p0.v
            GameTooltip:AddDoubleLine(FT.TimeOfDay(p1.t) .. FT.C("dim", "   " .. FT.Money(p1.v, "gold")),
                (d >= 0 and FT.C("up", FT.SignedMoney(d, "gold")) or FT.C("down", FT.Money(d, "gold"))), 0.85, 0.85, 0.85, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Click: where it all is (You)."], 0.58, 0.55, 0.5)
        GameTooltip:Show()
    end)
    own:SetScript("OnLeave", function() GameTooltip:Hide() end)
    own:SetScript("OnMouseUp", function() FT.Show("you") end)

    local title = UI.Text(p, 17, "accent")
    title:SetPoint("TOPLEFT", own, "BOTTOMLEFT", 2, -18)
    title:SetText(L["Your top 3"])
    local hint = UI.Text(p, 12, "dim")
    hint:SetPoint("LEFT", title, "RIGHT", 12, -1)
    hint:SetText(L["what to do with your stuff right now · hover for why"])

    local top = CreateFrame("Frame", nil, p)
    top:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -10)
    top:SetPoint("RIGHT", -PAD, 0)
    top:SetHeight(UI.RowH(118))
    P.cards = { Card(top), Card(top), Card(top) }
    Thirds(top, P.cards)

    local bottom = CreateFrame("Frame", nil, p)
    bottom:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -GAP)
    bottom:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    -- in your bags, going down, going up
    P.bags, P.down, P.up = Bags(bottom), Movers(bottom, "down"), Movers(bottom, "up")
    Thirds(bottom, { P.bags, P.down, P.up })
end

function P.Show()
    local worth = D.gold
    for _, h in ipairs(D.holdings) do worth = worth + D.items[h.id].price * h.qty end
    P.worth:SetText(Lab.Gold(worth))
    -- the worth at each of the last 24 updates, back from now
    local pts, v = {}, worth
    local t = time() - D.lastUpdateAgo * 60
    for i = #D.updateMoves, 1, -1 do
        pts[i + 1] = { t = t, v = v }
        v = v - D.updateMoves[i] * 10000
        t = t - D.updateEvery * 60
    end
    pts[1] = { t = t, v = v }
    P.points = pts
    local last = D.updateMoves[#D.updateMoves] * 10000
    P.update:SetText((last >= 0 and FT.C("up", FT.SignedMoney(last, "gold")) or FT.C("down", FT.Money(last, "gold"))) ..
        FT.C("muted", " " .. string.format(L["with the last prices (%s)"], FT.TimeOfDay(pts[#pts].t))))
    -- since yesterday: the same 24 hourly updates added up, so the two numbers always agree
    local day = pts[#pts].v - pts[1].v
    P.since:SetText((day >= 0 and FT.SignedMoney(day, "gold") or FT.Money(day, "gold")) .. " " .. L["since yesterday"])
    local vals = {}
    for i, pt in ipairs(pts) do vals[i] = pt.v end
    P.spark:SetValues(vals, "up")
    for i, c in ipairs(P.cards) do c:Set(D.top[i]) end
    P.bags:Fill()
    P.down:Fill()
    P.up:Fill()
end

function P.Dirty()
    if P.cards and P.cards[1]:IsVisible() then P.Show() end
end
