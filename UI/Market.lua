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
-- The sections beside the chart: each shows its answer and a few lines more, and they share the column's height
-- (no empty space under the last). What shows depends on the item: a material has Best crafts (what it's made
-- into) and Where to farm; a crafted item has Craft it (its materials, what it costs, what it brings) instead.
---------------------------------------------------------------------------
local TITLE = { when = L["When it sells"], market = L["Market"], history = L["Price history"], crafts = L["Best crafts"],
    farm = L["Where to farm"], make = L["Craft it"] }

local function Sections(id)
    local it = D.items[id]
    local list = { "when", "market", "history" }
    if it.made then
        list[#list + 1] = "make"
    else
        if D.crafts[id] then list[#list + 1] = "crafts" end
        if D.spots[id] then list[#list + 1] = "farm" end
    end
    return list
end

local function Name(x) return type(x) == "number" and FT.ItemText(x) or FT.C("text", x) end

-- what a crafted item costs to make: the sum, and a line per material
local function Cost(id)
    local m = D.made[id]
    if not m then return nil end
    local sum, lines = 0, {}
    for _, mat in ipairs(m.mats) do
        local each = type(mat[1]) == "number" and D.items[mat[1]].price or mat[3] or 0
        sum = sum + each * mat[2]
        lines[#lines + 1] = mat[2] .. " " .. Name(mat[1]) .. FT.C("dim", "  " .. FT.Money(each * mat[2], "short"))
    end
    return sum, lines, m.note
end

-- one section's answer, its extra lines, and a button (label, what it does)
local function Texts(key, id)
    local it = D.items[id]
    if key == "when" then
        return string.format(L["Sell %s · buy %s"], FT.Hour(it.sell[1]) .. "–" .. FT.Hour(it.sell[2]), FT.Hour(it.buy[1]) .. "–" .. FT.Hour(it.buy[2])),
            { string.format(L["Busiest day: %s"], it.day), L["Times on your clock."] },
            { L["Hour by hour"], function() if FT.WhenSells then FT.WhenSells.Open(id) end end }
    elseif key == "market" then
        return string.format(L["%s · sells ~%s a day"], L[it.market], FT.Num(it.perDay)),
            { string.format(L["About %d days to sell everything listed"], math.max(1, math.floor(140 / math.max(1, it.perDay) + 0.5))),
              string.format(L["Normal price %s"], FT.Money(it.normal, "short")) }
    elseif key == "history" then
        return string.format(L["7d %s · 30d %s"], FT.Pct(it.ch7), FT.Pct(it.ch30)),
            { string.format(L["30-day high %s, low %s"], FT.Money(math.floor(it.price * 1.07), "short"), FT.Money(math.floor(it.price * 0.86), "short")) }
    elseif key == "crafts" then
        local out = {}
        for _, c in ipairs(D.crafts[id]) do
            local g = c[2] or 0
            local gold = g > 0 and FT.C("up", "+" .. FT.Money(g, "short")) or (g < 0 and FT.C("down", FT.Money(g, "short")) or FT.C("dim", L["no gain"]))
            out[#out + 1] = Name(c[1]) .. ": " .. gold .. FT.C("dim", " " .. L["a use"])
        end
        local first = table.remove(out, 1)
        return first, out
    elseif key == "farm" then
        local out = {}
        for _, sp in ipairs(D.spots[id]) do out[#out + 1] = FT.C("text", sp[1]) .. FT.C("dim", "  " .. sp[2]) end
        local first = table.remove(out, 1)
        return first, out
    else -- make
        local cost, lines, note = Cost(id)
        local after = math.floor(it.price * 0.95)
        local profit = after - cost
        local sum = string.format(L["Costs ~%s, sells %s"], FT.Money(cost, "short"), FT.Money(it.price, "short")) .. "  " ..
            (profit > 0 and FT.C("up", "+" .. FT.Money(profit, "short")) or FT.C("down", FT.Money(profit, "short")))
        local more = {}
        for _, l in ipairs(lines) do more[#more + 1] = l end
        if note then more[#more + 1] = FT.C("dim", note) end
        return sum, more
    end
end

local function BuildFolds(parent)
    local box = UI.Panel(parent, "bg1", "line")
    box.secs = {}
    for i = 1, 5 do
        local f = CreateFrame("Frame", nil, box)
        f.title = UI.Text(f, 13, "muted")
        f.title:SetPoint("TOPLEFT", 12, -10)
        f.sum = UI.Text(f, 14, "text")
        f.sum:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
        f.sum:SetPoint("RIGHT", -12, 0)
        f.more = {}
        for k = 1, 4 do
            local t = UI.Text(f, 12, "muted")
            t:SetPoint("TOPLEFT", f.sum, "BOTTOMLEFT", 0, -5 - (k - 1) * UI.RowH(17))
            t:SetPoint("RIGHT", -12, 0)
            f.more[k] = t
        end
        f.btn = UI.Button(f, "", nil, 20, "default", function(self) if self.fn then self.fn() end end)
        f.btn:SetPoint("TOPRIGHT", -8, -6)
        f.line = UI.HLine(f, "line", 0.5)
        f.line:SetPoint("BOTTOMLEFT", 8, 0)
        f.line:SetPoint("BOTTOMRIGHT", -8, 0)
        box.secs[i] = f
    end
    function box:Lay()
        local keys = Sections(state.id)
        local n = #keys
        local H = (self:GetHeight() or 400) - 8
        local each = math.floor(H / math.max(1, n))
        for i, f in ipairs(self.secs) do
            local key = keys[i]
            f:SetShown(key ~= nil)
            if key then
                local sum, more, btn = Texts(key, state.id)
                f.title:SetText(TITLE[key])
                UI.FitSize(f.sum, sum or "", 14, 3)
                -- as many extra lines as its share of the height holds
                local room = math.max(0, math.floor((each - UI.RowH(48)) / UI.RowH(17)))
                for k, t in ipairs(f.more) do
                    local line = (k <= room) and more and more[k] or nil
                    t:SetShown(line ~= nil)
                    if line then UI.FitSize(t, line, 12, 2) end
                end
                f.btn:SetShown(btn ~= nil)
                if btn then f.btn:SetLabel(btn[1]); f.btn.fn = btn[2]; f.btn:FitText(20) end
                f.line:SetShown(i < n)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", 4, -4 - (i - 1) * each)
                f:SetPoint("RIGHT", -4, 0)
                f:SetHeight(each)
            end
        end
    end
    box:HookScript("OnSizeChanged", function(self) self:Lay() end)
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
