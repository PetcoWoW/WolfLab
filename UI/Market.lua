-- Wolf Lab: Market. The list stays on the left as in Wolf (search, a filter, All / Watchlist / I own). On the
-- right an item's page reads top to bottom: the verdict sentence, the chart (7D / 30D / 90D only), and beside it
-- five folded rows that each show their answer while closed. Three buttons: Watch, Wowhead, Share.
local ADDON, FT = ...
local UI, L = FT.UI, FT.L
local D, Lab = FT.Data, FT.Lab

local P = {}
FT.Pages.market = P

local PAD, GAP, LIST_W = 14, 12, 360
local state = { text = "", show = "all", kind = "all", id = 12363 }

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------
local function Owned()
    local o = {}
    for _, h in ipairs(D.holdings) do o[h.id] = (o[h.id] or 0) + h.qty end
    return o
end

local function Rows()
    local out, owned = {}, Owned()
    local q = state.text:lower()
    for _, id in ipairs(D.order) do
        local it = D.items[id]
        local name = (FT.Item(id) or it.name):lower()
        local ok = (q == "" or name:find(q, 1, true))
        if ok and state.kind ~= "all" then ok = it.kind == state.kind end
        if ok and state.show == "fav" then ok = Lab.IsWatched(id) end
        if ok and state.show == "mine" then ok = owned[id] ~= nil end
        if ok then out[#out + 1] = id end
    end
    return out
end

local function BuildList(p)
    -- wider with the larger text sizes
    LIST_W = 360 + 24 * (tonumber(FT.S.textSize) or 0)
    local box = UI.Panel(p, "bg1", "line")
    box:SetPoint("TOPLEFT", PAD, -PAD)
    box:SetPoint("BOTTOMLEFT", PAD, PAD)
    box:SetWidth(LIST_W)

    local search = UI.Input(box, LIST_W - 24, 24, L["Search item..."], function(text)
        state.text = text or ""
        P.FillList()
    end)
    search:SetPoint("TOPLEFT", 12, -12)

    local kinds = { { "all", L["All kinds"] } }
    local seen = {}
    for _, id in ipairs(D.order) do
        local k = D.items[id].kind
        if not seen[k] then seen[k] = true; kinds[#kinds + 1] = { k, L[k] } end
    end
    local kind = UI.Dropdown(box, LIST_W - 24, kinds, function(v)
        state.kind = v
        P.FillList()
    end)
    kind:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -8)
    kind:SetValue("all")

    local seg = UI.Segmented(box, { { "all", L["All"] }, { "fav", L["Watchlist"] }, { "mine", L["I own"] } }, function(v)
        state.show = v
        P.FillList()
    end, 22)
    seg:SetPoint("TOPLEFT", kind, "BOTTOMLEFT", 0, -8)
    seg:SetValue("all")

    local head = CreateFrame("Frame", nil, box)
    head:SetPoint("TOPLEFT", seg, "BOTTOMLEFT", 0, -10)
    head:SetPoint("RIGHT", -12, 0)
    head:SetHeight(UI.RowH(20))
    local h1 = UI.Text(head, 12, "muted"); h1:SetPoint("LEFT", 6, 0); h1:SetText(L["Item"])
    local h3 = UI.Text(head, 12, "muted", "RIGHT"); h3:SetPoint("RIGHT", -12, 0); h3:SetWidth(48); h3:SetText(L["24h"])
    local h2 = UI.Text(head, 12, "muted", "RIGHT"); h2:SetPoint("RIGHT", h3, "LEFT", -8, 0); h2:SetWidth(76); h2:SetText(L["Price"])
    local hl = UI.HLine(head, "line"); hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT")

    P.count = UI.Text(box, 11, "dim")
    P.count:SetPoint("BOTTOMLEFT", 14, 10)

    P.list = UI.List(box, {
        rowHeight = UI.RowH(26),
        setup = function(row)
            row.name = UI.Text(row, 14, "text")
            row.ch = UI.Text(row, 13, "text", "RIGHT")
            row.ch:SetPoint("RIGHT", -6, 0); row.ch:SetWidth(48)
            row.price = UI.Text(row, 13, "text", "RIGHT")
            row.price:SetPoint("RIGHT", row.ch, "LEFT", -8, 0); row.price:SetWidth(76)
            row.name:SetPoint("LEFT", 6, 0)
            row.name:SetPoint("RIGHT", row.price, "LEFT", -6, 0)
        end,
        update = function(row, id)
            local it = D.items[id]
            -- a long name shrinks a size or two before it's cut
            UI.FitSize(row.name, FT.ItemText(id) .. (Lab.IsWatched(id) and FT.C("accent", "  *") or ""), 14, 3)
            row.price:SetText(FT.Money(it.price, "short"))
            row.ch:SetText(FT.Pct(it.ch1))
        end,
        isSelected = function(id) return id == state.id end,
        onClick = function(id, button)
            if button == "RightButton" then Lab.ToggleWatch(id) else P.Select(id) end
        end,
        onEnter = function(row, id) Lab.ItemTip(row, id) end,
    })
    P.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
    P.list:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 28)
    P.list:SetEmptyText(L["Nothing matches"])
    return box
end

function P.FillList()
    if not P.list then return end
    local rows = Rows()
    P.list:SetItems(rows, true)
    P.count:SetText(string.format(L["%d items (sample)"], #rows))
end

---------------------------------------------------------------------------
-- The folds: closed, each shows its answer in one line; open, a few more lines (one open at a time)
---------------------------------------------------------------------------
local FOLDS = { "when", "market", "history", "crafts", "farm" }
local FOLD_TITLE = { when = L["When it sells"], market = L["Market"], history = L["Price history"], crafts = L["Best crafts"], farm = L["Where to farm"] }

local function FoldTexts(key, id)
    local it = D.items[id]
    if key == "when" then
        return string.format(L["Sell %s · buy %s"], FT.Hour(it.sell[1]) .. "–" .. FT.Hour(it.sell[2]), FT.Hour(it.buy[1]) .. "–" .. FT.Hour(it.buy[2])),
            { string.format(L["Busiest day: %s"], it.day), L["Times on your clock."] }, L["Hour by hour"]
    elseif key == "market" then
        return string.format(L["%s · sells ~%s a day"], L[it.market], FT.Num(it.perDay)),
            { string.format(L["About %d days to sell everything listed"], math.max(1, math.floor(140 / math.max(1, it.perDay) + 0.5))),
              string.format(L["Normal price %s"], FT.Money(it.normal, "short")) }
    elseif key == "history" then
        return string.format(L["7d %s · 30d %s"], FT.Pct(it.ch7), FT.Pct(it.ch30)),
            { string.format(L["30-day high %s, low %s"], FT.Money(math.floor(it.price * 1.07), "short"), FT.Money(math.floor(it.price * 0.86), "short")) }
    elseif key == "crafts" then
        return it.craft, {}
    else
        return it.farm, {}
    end
end

local function BuildFolds(parent)
    local box = UI.Panel(parent, "bg1", "line")
    box.folds = {}
    for i, key in ipairs(FOLDS) do
        local f = CreateFrame("Button", nil, box)
        f.key = key
        f.hover = UI.Tex(f, "BACKGROUND", "hl", 0.5)
        f.hover:SetAllPoints()
        f.hover:Hide()
        f.title = UI.Text(f, 13, "muted")
        f.title:SetPoint("TOPLEFT", 12, -9)
        f.title:SetText(FOLD_TITLE[key])
        f.sign = UI.Text(f, 15, "muted", "RIGHT")
        f.sign:SetPoint("TOPRIGHT", -12, -7)
        f.sum = UI.Text(f, 14, "text")
        f.sum:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
        f.sum:SetPoint("RIGHT", -12, 0)
        f.sum:SetJustifyV("TOP")
        if f.sum.SetWordWrap then f.sum:SetWordWrap(true) end
        f.more = {}
        for k = 1, 2 do
            local t = UI.Text(f, 13, "muted")
            t:SetPoint("TOPLEFT", f.sum, "BOTTOMLEFT", 0, -6 - (k - 1) * UI.RowH(18))
            t:SetPoint("RIGHT", -12, 0)
            f.more[k] = t
        end
        f.btn = UI.Button(f, "", nil, 22, "default", function() if FT.WhenSells then FT.WhenSells.Open(state.id) end end)
        if i < #FOLDS then
            f.line = UI.HLine(f, "line", 0.5)
            f.line:SetPoint("BOTTOMLEFT", 8, 0)
            f.line:SetPoint("BOTTOMRIGHT", -8, 0)
        end
        f:SetScript("OnEnter", function(self) self.hover:Show() end)
        f:SetScript("OnLeave", function(self) self.hover:Hide() end)
        f:SetScript("OnClick", function(self)
            box.open = (box.open ~= self.key) and self.key or nil
            box:Lay()
        end)
        box.folds[i] = f
    end
    box.open = "when"
    function box:Lay()
        local y = -4
        for _, f in ipairs(self.folds) do
            local sum, more, btn = FoldTexts(f.key, state.id)
            f.sum:SetText(sum)
            -- a long answer wraps to a second line
            local room = (self:GetWidth() or 300) - 32
            local two = (f.sum:GetStringWidth() or 0) > room
            local sumH = UI.RowH(two and 34 or 17)
            f.sum:SetHeight(sumH)
            local open = self.open == f.key
            f.sign:SetText(open and "–" or "+")
            local h = UI.RowH(31) + sumH
            for k, t in ipairs(f.more) do
                local line = open and more[k] or nil
                t:SetShown(line ~= nil)
                if line then t:SetText(line); h = h + UI.RowH(18) end
            end
            f.btn:SetShown(open and btn ~= nil)
            if open and btn then
                f.btn:SetLabel(btn); f.btn:FitText(24)
                f.btn:ClearAllPoints()
                f.btn:SetPoint("TOPLEFT", f.sum, "BOTTOMLEFT", 0, -(h - UI.RowH(31) - sumH) - 10)
                h = h + 34
            end
            if open then h = h + 4 end
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", 4, y)
            f:SetPoint("RIGHT", -4, 0)
            f:SetHeight(h)
            y = y - h
        end
    end
    return box
end

---------------------------------------------------------------------------
-- The item page
---------------------------------------------------------------------------
local RANGES = { { "7D", L["7D"] }, { "30D", L["30D"] }, { "90D", L["90D"] } }
local RANGE_DAYS = { ["7D"] = 7, ["30D"] = 30, ["90D"] = 90 }
local function MoneyAxis(v) return FT.Money(v, "short") end

local function BuildItem(p, left)
    local v = CreateFrame("Frame", nil, p)
    v:SetPoint("TOPLEFT", left, "TOPRIGHT", GAP, 0)
    v:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    v.icon = UI.Icon(v, 38)
    v.icon:SetPoint("TOPLEFT", 0, -2)
    v.icon:EnableMouse(true)
    v.icon:SetScript("OnEnter", function(self) UI.TipItem(self, state.id) end)
    v.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    v.name = UI.Text(v, 19, "text")
    v.name:SetPoint("TOPLEFT", v.icon, "TOPRIGHT", 12, -1)
    v.kind = UI.Text(v, 12, "dim")
    v.kind:SetPoint("TOPLEFT", v.name, "BOTTOMLEFT", 0, -4)

    v.share = UI.Button(v, L["Share"], nil, 24, "default", function() Lab.Share(state.id) end)
    v.share:FitText(26)
    v.share:SetPoint("TOPRIGHT", 0, -6)
    v.share:SetTip(L["Share"], L["A line about it for guild chat. You send it yourself (Enter)."])
    v.wowhead = UI.Button(v, L["Wowhead"], nil, 24, "default", function() Lab.Wowhead(state.id) end)
    v.wowhead:FitText(26)
    v.wowhead:SetPoint("RIGHT", v.share, "LEFT", -6, 0)
    v.wowhead:SetTip(L["Wowhead"], L["Its page on Wowhead (WoW Forever): a link to copy."])
    v.watch = UI.Button(v, L["Watch"], 84, 24, "default", function()
        Lab.ToggleWatch(state.id)
        P.ShowItem()
        P.FillList()
    end)
    v.watch:SetPoint("RIGHT", v.wowhead, "LEFT", -6, 0)

    v.vs = UI.Text(v, 13, "text", "RIGHT")
    v.vs:SetPoint("TOPRIGHT", v.watch, "TOPLEFT", -18, -14)
    v.price = UI.Text(v, 20, "text", "RIGHT")
    v.price:SetPoint("BOTTOMRIGHT", v.vs, "TOPRIGHT", 0, 2)
    v.name:SetPoint("RIGHT", v.price, "LEFT", -12, 0)

    -- the verdict, first
    v.call = UI.Panel(v, "bg2", "accent")
    v.call:SetPoint("TOPLEFT", 0, -52)
    v.call:SetPoint("TOPRIGHT", 0, -52)
    v.call:SetHeight(UI.RowH(44))
    v.badge = Lab.Badge(v.call, 76, 24)
    v.badge:SetPoint("LEFT", 12, 0)
    v.record = UI.Text(v.call, 12, "dim", "RIGHT")
    v.record:SetPoint("RIGHT", -14, 0)
    v.reason = UI.Text(v.call, 15, "text")
    v.reason:SetPoint("LEFT", v.badge, "RIGHT", 14, 0)
    v.reason:SetPoint("RIGHT", v.record, "LEFT", -12, 0)
    if v.reason.SetWordWrap then v.reason:SetWordWrap(true) end

    -- the chart and the folds
    v.folds = BuildFolds(v)
    v.folds:SetPoint("TOPRIGHT", v.call, "BOTTOMRIGHT", 0, -GAP)
    v.folds:SetPoint("BOTTOMRIGHT", 0, 0)
    v.folds:SetWidth(320)

    local cb = UI.Panel(v, "bg1", "line")
    cb:SetPoint("TOPLEFT", v.call, "BOTTOMLEFT", 0, -GAP)
    cb:SetPoint("BOTTOMRIGHT", v.folds, "BOTTOMLEFT", -GAP, 0)
    local ct = UI.Text(cb, 13, "muted")
    ct:SetPoint("TOPLEFT", 12, -10)
    ct:SetText(L["Price"])
    v.range = UI.Segmented(cb, RANGES, function(r)
        FT.S.range = r
        P.DrawChart()
    end, 20)
    v.range:SetPoint("TOPRIGHT", -10, -6)
    v.chart = UI.Chart(cb)
    v.chart:SetPoint("TOPLEFT", 6, -34)
    v.chart:SetPoint("BOTTOMRIGHT", -6, 6)
    return v
end

function P.DrawChart()
    local v = P.item
    if not v then return end
    local r = RANGE_DAYS[FT.S.range or "30D"] and FT.S.range or "30D"
    v.range:SetValue(r)
    local candles = UI.LineCandles(D.History(state.id, RANGE_DAYS[r]))
    v.chart:SetData({ candles = candles, mode = "line", fmt = MoneyAxis, title = L["Price"], overlays = {},
        defaultCount = #candles, emptyTitle = L["No price history"], emptyBody = "" })
end

function P.ShowItem()
    local v, id = P.item, state.id
    local it = D.items[id]
    if not (v and it) then return end
    v.icon:SetItem(id)
    v.name:SetText(FT.ItemText(id))
    v.kind:SetText(L[it.kind])
    v.price:SetText(FT.Money(it.price, "short"))
    local d = it.price / it.normal - 1
    v.vs:SetText(FT.Pct(d) .. " " .. FT.C("muted", L["vs normal"]))
    v.watch:SetLabel(Lab.IsWatched(id) and L["Watching"] or L["Watch"])
    v.badge:Set(it.verdict)
    v.reason:SetText(it.reason)
    -- a long reason takes a second line: the panel grows, the chart and folds move down
    local two = (v.reason:GetStringWidth() or 0) > ((v.reason:GetWidth() or 600) + 0.5)
    v.reason:SetHeight(UI.RowH(two and 38 or 20))
    v.call:SetHeight(UI.RowH(two and 58 or 44))
    v.record:SetText(L["right 7 of 9"])
    v.folds:Lay()
    P.DrawChart()
end

function P.Select(id)
    if not D.items[id] then return end
    state.id = id
    P.ShowItem()
    if P.list then P.list:Refresh() end
end

function P.Build(p)
    local left = BuildList(p)
    P.item = BuildItem(p, left)
    FT.On("FT_WATCH_CHANGED", function() P.FillList(); if P.item and P.item:IsVisible() then P.ShowItem() end end)
end

function P.Show()
    P.FillList()
    P.ShowItem()
end

function P.Dirty() if P.item then P.ShowItem() end end
