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

-- Coming up: the next sell window of something you own, the raids, your watchlist's biggest move
local RAIDS = time({ year = 2026, month = 12, day = 9, hour = 12 })

local function Until(hour)
    local now = date("*t")
    local mins = (hour - now.hour) * 60 - now.min
    if mins <= 0 then mins = mins + 24 * 60 end
    local hh, mm = math.floor(mins / 60), mins % 60
    if hh == 0 then return string.format(L["in %dm"], mm) end
    return string.format(L["in %dh %dm"], hh, mm)
end

local function ComingUp(parent)
    local box = UI.Panel(parent, "bg1", "line")
    box.title = UI.Text(box, 14, "muted")
    box.title:SetPoint("TOPLEFT", 14, -12)
    box.title:SetText(L["Coming up"])
    box.rows = {}
    for i = 1, 3 do
        local r = CreateFrame("Button", nil, box)
        r:SetHeight(UI.RowH(30))
        r:SetPoint("TOPLEFT", 8, -(34 + (i - 1) * UI.RowH(32)))
        r:SetPoint("RIGHT", -8, 0)
        r.hover = UI.Tex(r, "BACKGROUND", "hl", 0.6)
        r.hover:SetAllPoints()
        r.hover:Hide()
        r.badge = Lab.Badge(r, 58, 18)
        r.badge:SetPoint("LEFT", 6, 0)
        r.when = UI.Text(r, 13, "accent", "RIGHT")
        r.when:SetPoint("RIGHT", -6, 0)
        r.text = UI.Text(r, 14, "text")
        r.text:SetPoint("LEFT", r.badge, "RIGHT", 10, 0)
        r.text:SetPoint("RIGHT", r.when, "LEFT", -10, 0)
        r:SetScript("OnEnter", function(self) self.hover:Show(); if self.id then Lab.ItemTip(self, self.id, self.why) end end)
        r:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
        r:SetScript("OnClick", function(self) if self.id then Lab.OpenItem(self.id) elseif self.page then FT.Show(self.page) end end)
        box.rows[i] = r
    end
    function box:Fill()
        local lines = {}
        -- 1: the next sell window of your most valuable holding
        local best, bestV
        for _, h in ipairs(D.holdings) do
            local it = D.items[h.id]
            if it.verdict == "SELL" and (not bestV or it.price * h.qty > bestV) then best, bestV = h.id, it.price * h.qty end
        end
        if best then
            local it = D.items[best]
            lines[#lines + 1] = { kind = "SELL", id = best, text = string.format(L["%s sells best at %s"], FT.ItemText(best), FT.Hour(it.sell[1])),
                when = Until(it.sell[1]), why = string.format(L["You hold %s. Post just before %s: that's when it's priciest."], FT.Num(400), FT.Hour(it.sell[1])) }
        end
        -- 2: the raids
        local days = math.max(0, math.ceil((RAIDS - time()) / 86400))
        lines[#lines + 1] = { kind = "HOLD", page = "make", text = L["Raids open: hold Arcane Crystal, Elemental Fire"],
            when = string.format(L["%d days"], days) }
        -- 3: the watchlist's biggest move today
        local wid, wch
        local watched = {}
        for _, id in ipairs(D.watch) do watched[id] = true end
        for id in pairs(FT.db and FT.db.watch or {}) do watched[id] = true end
        for id in pairs(watched) do
            local it = D.items[id]
            if it and (not wch or math.abs(it.ch1) > math.abs(wch)) then wid, wch = id, it.ch1 end
        end
        if wid then
            local it = D.items[wid]
            lines[#lines + 1] = { kind = it.verdict, id = wid, text = string.format(L["%s %s today"], FT.ItemText(wid), FT.Pct(it.ch1)),
                when = L["watched"], why = it.reason }
        end
        for i, r in ipairs(self.rows) do
            local m = lines[i]
            r:SetShown(m ~= nil)
            if m then
                r.id, r.page, r.why = m.id, m.page, m.why
                r.badge:Set(m.kind)
                r.text:SetText(m.text)
                r.when:SetText(m.when or "")
            end
        end
    end
    return box
end

-- Last session: how your last farm run went, and a button to start the next one
local function LastSession(parent)
    local box = UI.Panel(parent, "bg1", "line")
    box.title = UI.Text(box, 14, "muted")
    box.title:SetPoint("TOPLEFT", 14, -12)
    box.title:SetText(L["Last session"])
    box.all = UI.Button(box, L["All sessions"], nil, 20, "ghost", function() FT.Show("you") end)
    box.all:FitText(16)
    box.all:SetPoint("TOPRIGHT", -8, -8)
    box.name = UI.Text(box, 14, "text")
    box.name:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -10)
    box.name:SetPoint("RIGHT", -14, 0)
    box.gold = UI.Text(box, 22, "text")
    box.gold:SetPoint("TOPLEFT", box.name, "BOTTOMLEFT", 0, -8)
    box.rate = UI.Text(box, 14, "up")
    box.rate:SetPoint("LEFT", box.gold, "RIGHT", 14, -1)
    box.best = UI.Text(box, 13, "muted")
    box.best:SetPoint("TOPLEFT", box.gold, "BOTTOMLEFT", 0, -8)
    box.best:SetPoint("RIGHT", -14, 0)
    box.start = UI.Button(box, L["Start a session"], nil, 24, "primary", function()
        if FT.Session.Running() then FT.Session.Stop() else FT.Session.Start() end
    end)
    box.start:SetPoint("BOTTOMLEFT", 14, 12)
    box.start:SetTip(L["Start a session"], L["Counts what you loot and the gold an hour, in a small panel you can fold to one line. (Sample loot in the Lab.)"])
    function box:Fill()
        local s = D.sessions[1]
        self.name:SetText(s.name .. FT.C("dim", "  ·  " .. s.zone .. "  ·  " .. string.format(L["%d min"], s.minutes)))
        self.gold:SetText(FT.Money(s.gold, "gold"))
        self.rate:SetText(FT.Money(math.floor(s.gold * 60 / s.minutes), "gold") .. " " .. L["an hour"])
        self.best:SetText(L["Best find"] .. ": " .. FT.ItemText(s.top) .. FT.C("dim", " ×" .. s.found))
        self.start:SetLabel(FT.Session.Running() and L["Stop the session"] or L["Start a session"])
        self.start:FitText(28)
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
    movers:SetPoint("RIGHT", -PAD, 0)
    movers:SetHeight(UI.RowH(124))
    UI.OnSize(movers, function(self, w, h)
        local bw = math.floor((w - GAP) / 2)
        P.up:ClearAllPoints(); P.up:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0); P.up:SetSize(bw, h)
        P.down:ClearAllPoints(); P.down:SetPoint("TOPLEFT", self, "TOPLEFT", bw + GAP, 0); P.down:SetSize(bw, h)
    end)

    local whole = UI.Button(p, L["Whole market"], nil, 22, "default", function() FT.Show("market") end)
    whole:FitText(28)
    whole:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", 0, 8)

    -- what's next: coming up (left) and your last session (right)
    P.coming = ComingUp(p)
    P.last = LastSession(p)
    local bottom = CreateFrame("Frame", nil, p)
    bottom:SetPoint("TOPLEFT", movers, "BOTTOMLEFT", 0, -GAP)
    bottom:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    UI.OnSize(bottom, function(self, w, h)
        local bw = math.floor((w - GAP) / 2)
        P.coming:ClearAllPoints(); P.coming:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0); P.coming:SetSize(bw, h)
        P.last:ClearAllPoints(); P.last:SetPoint("TOPLEFT", self, "TOPLEFT", bw + GAP, 0); P.last:SetSize(bw, h)
    end)
    FT.On("FT_SESSION", function() if P.last and P.last:IsVisible() then P.last:Fill() end end)
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
    P.coming:Fill()
    P.last:Fill()
end
