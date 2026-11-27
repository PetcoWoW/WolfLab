-- Wolf Lab: Today, the first page. Four things only: what you own is worth, Your top 3, and what's going up and
-- down today. The old overview's stat cards, the listed-value chart and Market Makers are gone.
local ADDON, FT = ...
local UI, L = FT.UI, FT.L
local D, Lab = FT.Data, FT.Lab

local P = {}
FT.Pages.today = P

local PAD, GAP = 14, 12

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

local function MoveList(parent, title)
    local box = UI.Panel(parent, "bg1", "line")
    box.title = UI.Text(box, 14, "muted")
    box.title:SetPoint("TOPLEFT", 14, -12)
    box.title:SetText(title)
    box.rows = {}
    for i = 1, 3 do
        local r = CreateFrame("Button", nil, box)
        r:SetHeight(UI.RowH(26))
        r:SetPoint("TOPLEFT", 8, -(34 + (i - 1) * UI.RowH(28)))
        r:SetPoint("RIGHT", -8, 0)
        r.hover = UI.Tex(r, "BACKGROUND", "hl", 0.6)
        r.hover:SetAllPoints()
        r.hover:Hide()
        r.name = UI.Text(r, 14, "text")
        r.name:SetPoint("LEFT", 6, 0)
        r.ch = UI.Text(r, 14, "text", "RIGHT")
        r.ch:SetPoint("RIGHT", -6, 0)
        r.price = UI.Text(r, 13, "muted", "RIGHT")
        r.price:SetPoint("RIGHT", r.ch, "LEFT", -18, 0)
        r.name:SetPoint("RIGHT", r.price, "LEFT", -10, 0)
        r:SetScript("OnEnter", function(self) self.hover:Show(); Lab.ItemTip(self, self.id) end)
        r:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
        r:SetScript("OnClick", function(self) Lab.OpenItem(self.id) end)
        box.rows[i] = r
    end
    function box:Set(ids)
        for i, r in ipairs(self.rows) do
            local id = ids[i]
            r:SetShown(id ~= nil)
            if id then
                local it = D.items[id]
                r.id = id
                r.name:SetText(FT.ItemText(id))
                r.price:SetText(FT.Money(it.price, "short"))
                r.ch:SetText(FT.Pct(it.ch1))
            end
        end
    end
    return box
end

function P.Build(p)
    -- what you own is worth
    local own = UI.Panel(p, "bg1", "line")
    own:SetPoint("TOPLEFT", PAD, -PAD)
    own:SetPoint("TOPRIGHT", -PAD, -PAD)
    own:SetHeight(UI.RowH(62))
    local label = UI.Text(own, 14, "muted")
    label:SetPoint("LEFT", 16, 0)
    label:SetText(L["Everything you own"])
    P.worth = UI.Text(own, 24, "text")
    P.worth:SetPoint("LEFT", label, "RIGHT", 18, 0)
    P.since = UI.Text(own, 14, "up")
    P.since:SetPoint("LEFT", P.worth, "RIGHT", 16, -1)
    local days = UI.Text(own, 11, "dim", "RIGHT")
    days:SetPoint("RIGHT", -16, 0)
    days:SetText(L["14 days"])
    P.spark = UI.Sparkline(own, 300, 34)
    P.spark:SetPoint("RIGHT", days, "LEFT", -12, 0)
    own:EnableMouse(true)
    own:SetScript("OnEnter", function(self)
        UI.TipText(self, L["Everything you own"], L["Bags, bank, mail and every character, at today's prices, plus your gold. Click: You."])
    end)
    own:SetScript("OnLeave", function() GameTooltip:Hide() end)
    own:SetScript("OnMouseUp", function() FT.Show("you") end)

    -- Your top 3
    local title = UI.Text(p, 17, "accent")
    title:SetPoint("TOPLEFT", own, "BOTTOMLEFT", 2, -18)
    title:SetText(L["Your top 3"])
    local hint = UI.Text(p, 12, "dim")
    hint:SetPoint("LEFT", title, "RIGHT", 12, -1)
    hint:SetText(L["what to do with your stuff right now · hover for why"])

    P.cards = {}
    local row = CreateFrame("Frame", nil, p)
    row:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -10)
    row:SetPoint("RIGHT", -PAD, 0)
    row:SetHeight(UI.RowH(118))
    for i = 1, 3 do P.cards[i] = Card(row) end
    UI.OnSize(row, function(self, w)
        local cw = math.floor((w - GAP * 2) / 3)
        for i, c in ipairs(P.cards) do
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", (i - 1) * (cw + GAP), 0)
            c:SetSize(cw, self:GetHeight())
        end
    end)

    -- going up / going down
    P.up = MoveList(p, L["Going up today"])
    P.down = MoveList(p, L["Going down today"])
    local movers = CreateFrame("Frame", nil, p)
    movers:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -GAP)
    movers:SetPoint("BOTTOMRIGHT", -PAD, PAD + UI.RowH(30))
    UI.OnSize(movers, function(self, w, h)
        local bw = math.floor((w - GAP) / 2)
        P.up:ClearAllPoints(); P.up:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0); P.up:SetSize(bw, math.min(h, UI.RowH(124)))
        P.down:ClearAllPoints(); P.down:SetPoint("TOPLEFT", self, "TOPLEFT", bw + GAP, 0); P.down:SetSize(bw, math.min(h, UI.RowH(124)))
    end)

    local whole = UI.Button(p, L["Whole market"], nil, 24, "default", function() FT.Show("market") end)
    whole:FitText(28)
    whole:SetPoint("BOTTOMRIGHT", -PAD, PAD)
end

function P.Show()
    local worth = D.gold
    for _, h in ipairs(D.holdings) do worth = worth + D.items[h.id].price * h.qty end
    P.worth:SetText(Lab.Gold(worth))
    P.since:SetText(FT.SignedMoney(D.since, "gold") .. " " .. L["since yesterday"])
    P.spark:SetValues(D.worthLine, "up")
    for i, c in ipairs(P.cards) do c:Set(D.top[i]) end
    P.up:Set(D.up)
    P.down:Set(D.down)
end
