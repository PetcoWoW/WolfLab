-- Wolf: the price chart. Candles or a line with a soft fill, moving averages, a lower panel
-- (listed quantity or profit), a dashed last-price line with its tag on the axis, a crosshair with an
-- OHLC legend, mouse-wheel zoom and drag to look back in time.
local ADDON, FT = ...
local UI = FT.UI
local C = UI.C
local L = FT.L

local AXIS_W = 64
local TIME_H = 18
local LEGEND_H = 22

local function NiceStep(x)
    if x <= 0 then return 1 end
    local e = 10 ^ math.floor(math.log10(x))
    local f = x / e
    local nice = (f < 1.5 and 1) or (f < 3 and 2) or (f < 7 and 5) or 10
    return nice * e
end

local function Col(name)
    return type(name) == "table" and name or C[name] or C.text
end

function UI.Chart(parent)
    -- the price axis: wider with the larger text sizes (a whole session has one)
    AXIS_W = 64 + 7 * (tonumber(FT.S and FT.S.textSize) or 0)
    local ch = CreateFrame("Frame", nil, parent)
    UI.Fill(ch, "bg1")

    ch.plot = CreateFrame("Frame", nil, ch)
    ch.lower = CreateFrame("Frame", nil, ch)
    ch.mouse = CreateFrame("Frame", nil, ch)
    ch.mouse:SetFrameLevel(ch:GetFrameLevel() + 10)
    ch.mouse:EnableMouse(true)
    ch.mouse:EnableMouseWheel(true)

    ch.grid = UI.Pool(ch.plot, function(o) return o:CreateTexture(nil, "BACKGROUND", nil, 2) end)
    ch.fills = UI.Pool(ch.plot, function(o) return o:CreateTexture(nil, "BORDER") end)
    ch.rects = UI.Pool(ch.plot, function(o) return o:CreateTexture(nil, "ARTWORK") end)
    ch.lines = UI.Pool(ch.plot, function(o) return UI.NewLine(o, "OVERLAY") end)
    ch.dashes = UI.Pool(ch.plot, function(o) return o:CreateTexture(nil, "OVERLAY") end)
    ch.bars = UI.Pool(ch.lower, function(o) return o:CreateTexture(nil, "ARTWORK") end)
    ch.lgrid = UI.Pool(ch.lower, function(o) return o:CreateTexture(nil, "BACKGROUND", nil, 2) end)
    -- the numbers: a size up, and no drop shadow (at this size a shadow doubles the letters and looks blurry)
    local function Crisp(fs)
        fs:SetShadowOffset(0, 0)
        return fs
    end
    ch.ylabels = UI.Pool(ch, function(o) return Crisp(UI.Text(o, 11, "muted", "LEFT")) end)
    ch.tlabels = UI.Pool(ch, function(o) return Crisp(UI.Text(o, 11, "dim", "CENTER")) end)
    -- the high and the low: their number on a small dark plate, so the line never runs through it
    ch.marks = UI.Pool(ch, function(o)
        local m = CreateFrame("Frame", nil, o)
        m:SetFrameLevel(ch.mouse:GetFrameLevel() - 1)
        m.bg = UI.RoundTex(m, "BACKGROUND", "bg0", 0.82)
        m.bg:SetAllPoints()
        m.text = Crisp(UI.Text(m, 11, "text", "CENTER"))
        m.text:SetPoint("CENTER", 0, 0)
        return m
    end)

    ch.title = UI.Text(ch, 11, "text")
    ch.title:SetPoint("TOPLEFT", 8, -5)
    ch.legend = UI.Text(ch, 11, "muted")
    ch.legend:SetPoint("LEFT", ch.title, "RIGHT", 10, 0)
    ch.legendMA = UI.Text(ch, 11, "muted")
    ch.legendMA:SetPoint("LEFT", ch.legend, "RIGHT", 14, 0)
    ch.lowerText = UI.Text(ch.lower, 10, "dim")
    ch.lowerText:SetPoint("TOPLEFT", 6, -2)

    -- last price tag on the axis
    ch.tag = CreateFrame("Frame", nil, ch)
    ch.tag:SetFrameLevel(ch.mouse:GetFrameLevel() + 1)
    ch.tag:SetSize(AXIS_W - 2, 18)
    ch.tag.bg = UI.RoundTex(ch.tag, "BACKGROUND", "up", 1)
    ch.tag.bg:SetAllPoints()
    ch.tag.text = UI.Text(ch.tag, 11, "black", "CENTER")
    ch.tag.text:SetPoint("CENTER")
    ch.tag.text:SetShadowOffset(0, 0)

    -- crosshair
    ch.cx = UI.Tex(ch.mouse, "OVERLAY", "muted", 0.45)
    ch.cx:SetWidth(1)
    ch.cy = UI.Tex(ch.mouse, "OVERLAY", "muted", 0.45)
    ch.cy:SetHeight(1)
    ch.cyTag = CreateFrame("Frame", nil, ch)
    ch.cyTag:SetFrameLevel(ch.mouse:GetFrameLevel() + 2)
    ch.cyTag:SetSize(AXIS_W - 2, 18)
    ch.cyTag.bg = UI.RoundTex(ch.cyTag, "BACKGROUND", "bg3", 1)
    ch.cyTag.bg:SetAllPoints()
    ch.cyTag.text = Crisp(UI.Text(ch.cyTag, 11, "text", "CENTER"))
    ch.cyTag.text:SetPoint("CENTER")
    ch.cxTag = CreateFrame("Frame", nil, ch)
    ch.cxTag:SetFrameLevel(ch.mouse:GetFrameLevel() + 2)
    ch.cxTag:SetSize(80, TIME_H - 2)
    ch.cxTag.bg = UI.RoundTex(ch.cxTag, "BACKGROUND", "bg3", 1)
    ch.cxTag.bg:SetAllPoints()
    ch.cxTag.text = Crisp(UI.Text(ch.cxTag, 11, "text", "CENTER"))
    ch.cxTag.text:SetPoint("CENTER")
    ch.cx:Hide(); ch.cy:Hide(); ch.cyTag:Hide(); ch.cxTag:Hide()
    ch.hdot = UI.Dot(ch.mouse, 9, "up", 1, "OVERLAY")
    ch.hdot:Hide()

    ch.empty = UI.EmptyState(ch, "", "")
    ch.empty:SetPoint("CENTER", 0, 10)
    ch.empty:Hide()

    function ch:Layout()
        local d = self.data
        local hasLower = d and d.lower ~= nil
        local H = self:GetHeight()
        local lowerH = hasLower and math.floor(H * (d.lowerRatio or 0.2)) or 0
        self.plot:ClearAllPoints()
        self.plot:SetPoint("TOPLEFT", 0, -LEGEND_H)
        self.plot:SetPoint("BOTTOMRIGHT", -AXIS_W, TIME_H + lowerH + (hasLower and 4 or 0))
        self.lower:ClearAllPoints()
        self.lower:SetPoint("BOTTOMLEFT", 0, TIME_H)
        self.lower:SetPoint("BOTTOMRIGHT", -AXIS_W, TIME_H)
        self.lower:SetHeight(math.max(1, lowerH))
        self.lower:SetShown(hasLower)
        self.mouse:ClearAllPoints()
        self.mouse:SetPoint("TOPLEFT", self.plot, "TOPLEFT")
        self.mouse:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -AXIS_W, TIME_H)
    end

    function ch:SetData(data, keepView)
        self.data = data
        if not keepView then
            self.count, self.offset = nil, 0
        end
        self.hoverIndex = nil
        self:Layout()
        self:Render()
    end

    function ch:Clear(title, body)
        self:SetData({ candles = {}, emptyTitle = title, emptyBody = body })
    end

    local function Fmt(d, v)
        local t = (d.fmt or FT.GoldNumber)(v)
        if type(t) == "string" then t = t:gsub("^%-(0[%.,]?0*)$", "%1") end
        return t
    end

    -- dates the American way: 11/25/26, 11/25 3 pm
    local function Hour(t) return (date("%I %p", t):gsub("^0", ""):lower()) end
    local function TimeText(d, t)
        if not t then return "" end
        if d.hourly then return date("%m/%d", t) .. " " .. FT.TimeOfDay(t):gsub("^%a+ ", "") end
        return date("%m/%d/%y", t)
    end

    function ch:Render()
        self.grid:Reset(); self.fills:Reset(); self.rects:Reset(); self.lines:Reset(); self.dashes:Reset()
        self.bars:Reset(); self.lgrid:Reset(); self.ylabels:Reset(); self.tlabels:Reset(); self.marks:Reset()
        local d = self.data
        local candles = d and d.candles or {}
        local n = #candles
        local W, H = self.plot:GetWidth(), self.plot:GetHeight()
        if n == 0 or W <= 10 or H <= 10 then
            self.empty:Set(d and d.emptyTitle or L["No data"], d and d.emptyBody or "")
            self.empty:SetShown(n == 0)
            self.title:SetText(d and d.title or "")
            self.legend:SetText("")
            self.legendMA:SetText("")
            self:FitHead()
            self.lowerText:SetText("")
            self.tag:Hide()
            self.grid:HideRest(); self.fills:HideRest(); self.rects:HideRest(); self.lines:HideRest()
            self.dashes:HideRest(); self.bars:HideRest(); self.lgrid:HideRest(); self.ylabels:HideRest(); self.marks:HideRest()
            self.tlabels:HideRest()
            return
        end
        self.empty:Hide()
        self.title:SetText(d.title or "")

        local count = self.count or math.min(n, d.defaultCount or 90)
        count = math.max(math.min(n, 5), math.min(count, n))
        local offset = math.max(0, math.min(self.offset or 0, n - count))
        self.count, self.offset = count, offset
        local last = n - offset
        local first = last - count + 1
        self.first, self.last = first, last

        -- price range of what is visible
        local lo, hi = math.huge, -math.huge
        for i = first, last do
            local c = candles[i]
            if c.l < lo then lo = c.l end
            if c.h > hi then hi = c.h end
        end
        for _, ov in ipairs(d.overlays or {}) do
            for i = first, last do
                local v = ov.values[i]
                if v then
                    if v < lo then lo = v end
                    if v > hi then hi = v end
                end
            end
        end
        if d.centerZero then
            -- zero in the middle: the same room above (profit) and below (loss)
            local m = math.max(math.abs(lo), math.abs(hi))
            if m <= 0 then m = 1 end
            lo, hi = -m * 1.15, m * 1.15
        else
            if hi <= lo then
                local m = math.abs(lo) > 0 and math.abs(lo) * 0.05 or 1
                lo, hi = lo - m, hi + m
            end
            local pad = (hi - lo) * 0.08
            lo, hi = lo - pad, hi + pad
            if d.floorZero and lo < 0 then lo = 0 end
        end
        self.lo, self.hi = lo, hi
        local function Y(v) return (v - lo) / (hi - lo) * H end
        local slot = W / count
        self.slot = slot
        local function X(i) return (i - first + 0.5) * slot end
        self.X, self.Y = X, Y

        -- horizontal grid and price labels (a label where the last price's tag sits is left out: the tag says it)
        local tagY = (candles[n].c >= lo and candles[n].c <= hi) and Y(candles[n].c) or nil
        local lastLabelY
        -- labels apart by at least their own height (the larger text sizes too), and clear of the price tag
        local labelGap = math.ceil(UI.Size(11) * 1.2) + 2
        local tagGap = 9 + labelGap / 2
        local step = NiceStep((hi - lo) / 4)
        local g = math.ceil(lo / step) * step
        local guard = 0
        while g <= hi and guard < 12 do
            local y = Y(g)
            local t = self.grid:Get()
            t:SetColorTexture(C.line[1], C.line[2], C.line[3], (d.mode == "line" and not d.centerZero) and 0.3 or 0.6)
            t:ClearAllPoints()
            t:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", 0, y)
            t:SetPoint("BOTTOMRIGHT", self.plot, "BOTTOMRIGHT", 0, y)
            t:SetHeight(1)
            t:Show()
            if math.abs(g) < step * 1e-6 then g = 0 end -- never "-0"
            if not (tagY and math.abs(y - tagY) < tagGap) and not (lastLabelY and math.abs(y - lastLabelY) < labelGap) then
                lastLabelY = y
                local fs = self.ylabels:Get()
                fs:ClearAllPoints()
                -- in the axis, right-aligned to the chart's edge: a long number never runs past it
                fs:SetPoint("RIGHT", self.plot, "BOTTOMRIGHT", AXIS_W - 4, y)
                fs:SetJustifyH("RIGHT")
                fs:SetText(Fmt(d, g))
                fs:Show()
            end
            g = g + step
            guard = guard + 1
        end

        -- vertical grid (not on the simple line: its dates are enough) and time labels
        local simpleLine = d.mode == "line" and not d.centerZero
        local every = math.max(1, math.floor(count / 6 + 0.5))
        for i = first, last do
            if (last - i) % every == 0 then
                local x = X(i)
                if not simpleLine then
                    local t = self.grid:Get()
                    t:SetColorTexture(C.line[1], C.line[2], C.line[3], 0.35)
                    t:ClearAllPoints()
                    t:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", x, 0)
                    t:SetPoint("TOPLEFT", self.plot, "TOPLEFT", x, 0)
                    t:SetWidth(1)
                    t:Show()
                end
                local fs = self.tlabels:Get()
                fs:SetText(d.hourly and Hour(candles[i].t) or date("%m/%d", candles[i].t))
                -- never past the chart's edges
                local half = (fs:GetStringWidth() or 0) / 2 + 2
                local cx = math.max(half, math.min((self:GetWidth() or W) - AXIS_W - half, x))
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", self, "BOTTOMLEFT", cx, TIME_H / 2)
                fs:Show()
            end
        end

        local bw = math.max(1, math.floor(slot * 0.66))
        if bw > 2 and bw % 2 == 0 then bw = bw - 1 end

        if d.mode == "line" and d.centerZero then
            local y0 = Y(0)
            local axis = self.grid:Get()
            axis:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 0.85)
            axis:ClearAllPoints()
            axis:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", 0, y0)
            axis:SetPoint("BOTTOMRIGHT", self.plot, "BOTTOMRIGHT", 0, y0)
            axis:SetHeight(1)
            axis:Show()
            if count == 1 then
                local v = candles[first].c
                local t = self.rects:Get()
                local col = v >= 0 and C.up or C.down
                t:SetColorTexture(col[1], col[2], col[3], 1)
                t:ClearAllPoints()
                t:SetPoint("CENTER", self.plot, "BOTTOMLEFT", X(first), Y(v))
                t:SetSize(5, 5)
                t:Show()
            end
            for i = first, last - 1 do
                local v1, v2 = candles[i].c, candles[i + 1].c
                local x1, x2 = X(i), X(i + 1)
                local pieces
                if (v1 >= 0) == (v2 >= 0) or v1 == v2 then
                    pieces = { { x1, v1, x2, v2 } }
                else
                    -- the line crosses zero: split it there, each part in its own colour
                    local xm = x1 + (x2 - x1) * (v1 / (v1 - v2))
                    pieces = { { x1, v1, xm, 0 }, { xm, 0, x2, v2 } }
                end
                for _, pc in ipairs(pieces) do
                    local positive = (pc[2] + pc[4]) >= 0
                    local col = positive and C.up or C.down
                    UI.PlaceLine(self.lines:Get(), pc[1], Y(pc[2]), pc[3], Y(pc[4]), 1.8, col, 1)
                    local px = pc[1]
                    while px < pc[3] do
                        local wcol = math.min(3, pc[3] - px)
                        local frac = (px + wcol / 2 - pc[1]) / math.max(0.001, pc[3] - pc[1])
                        local y = Y(pc[2] + (pc[4] - pc[2]) * frac)
                        local hgt = math.abs(y - y0)
                        if hgt > 1 then
                            local f = self.fills:Get()
                            if positive then
                                UI.Gradient(f, "VERTICAL", col, 0.03, 0.26)
                            else
                                UI.Gradient(f, "VERTICAL", col, 0.26, 0.03)
                            end
                            f:ClearAllPoints()
                            f:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", px, math.min(y, y0))
                            f:SetSize(wcol, hgt)
                            f:Show()
                        end
                        px = px + wcol
                    end
                end
            end
        elseif d.mode == "line" then
            local color = Col(d.lineColor or ((candles[last].c >= candles[first].c) and "up" or "down"))
            if count == 1 then
                local t = self.rects:Get()
                t:SetColorTexture(color[1], color[2], color[3], 1)
                t:ClearAllPoints()
                t:SetPoint("CENTER", self.plot, "BOTTOMLEFT", X(first), Y(candles[first].c))
                t:SetSize(4, 4)
                t:Show()
            end
            local hiI, loI = first, first
            for i = first, last do
                if candles[i].c > candles[hiI].c then hiI = i end
                if candles[i].c < candles[loI].c then loI = i end
            end
            for i = first, last - 1 do
                local x1, y1 = X(i), Y(candles[i].c)
                local x2, y2 = X(i + 1), Y(candles[i + 1].c)
                UI.PlaceLine(self.lines:Get(), x1, y1, x2, y2, 5, color, 0.14) -- the glow
                UI.PlaceLine(self.lines:Get(), x1, y1, x2, y2, 2, color, 1)
                -- soft fill under the line, in fine columns
                local px = x1
                while px < x2 do
                    local wcol = math.min(2, x2 - px)
                    local frac = (px + wcol / 2 - x1) / (x2 - x1)
                    local y = y1 + (y2 - y1) * frac
                    if y > 1 then
                        local f = self.fills:Get()
                        UI.Gradient(f, "VERTICAL", color, 0.0, 0.24)
                        f:ClearAllPoints()
                        f:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", px, 0)
                        f:SetSize(wcol, y)
                        f:Show()
                    end
                    px = px + wcol
                end
            end
            -- the high and the low of what's shown, and the newest point
            if count >= 3 and hiI ~= loI then
                for _, m in ipairs({ { hiI, "H", 1 }, { loI, "L", -1 } }) do
                    local i, tag, side = m[1], m[2], m[3]
                    -- no room under the low (the dates) or over the high (the title): the other side of its dot
                    local py = Y(candles[i].c)
                    if side < 0 and py < 20 then side = 1 elseif side > 0 and py > H - 20 then side = -1 end
                    local dot = self.rects:Get()
                    dot:SetTexture("Interface\\AddOns\\WolfLab\\media\\round.tga")
                    dot:SetVertexColor(color[1], color[2], color[3], 0.9)
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", self.plot, "BOTTOMLEFT", X(i), Y(candles[i].c))
                    dot:SetSize(6, 6)
                    dot:Show()
                    local m = self.marks:Get()
                    m.text:SetText(FT.C("muted", tag .. " ") .. Fmt(d, candles[i].c))
                    local mw = math.ceil((m.text:GetStringWidth() or 60) + 10)
                    m:SetSize(mw, UI.Size(11) + 6)
                    -- inside the plot whatever the point: a plate wholly between its edges
                    local mx = math.max(mw / 2 + 1, math.min(W - mw / 2 - 1, X(i)))
                    m:ClearAllPoints()
                    m:SetPoint(side > 0 and "BOTTOM" or "TOP", self.plot, "BOTTOMLEFT", mx, Y(candles[i].c) + side * 7)
                    m:Show()
                end
            end
        else
            for i = first, last do
                local c = candles[i]
                local col = (c.c >= c.o) and C.up or C.down
                local x = X(i)
                local wick = self.rects:Get()
                wick:SetColorTexture(col[1], col[2], col[3], 1)
                wick:ClearAllPoints()
                wick:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", math.floor(x), Y(c.l))
                wick:SetSize(1, math.max(1, Y(c.h) - Y(c.l)))
                wick:Show()
                local top, bottom = Y(math.max(c.o, c.c)), Y(math.min(c.o, c.c))
                local body = self.rects:Get()
                body:SetColorTexture(col[1], col[2], col[3], 1)
                body:ClearAllPoints()
                body:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", math.floor(x) - (bw - 1) / 2, bottom)
                body:SetSize(bw, math.max(1, top - bottom))
                body:Show()
            end
        end

        -- overlays (moving averages, cost line...)
        for _, ov in ipairs(d.overlays or {}) do
            local v = ov.values
            for i = first + 1, last do
                if v[i - 1] and v[i] then
                    UI.PlaceLine(self.lines:Get(), X(i - 1), Y(v[i - 1]), X(i), Y(v[i]), ov.width or 1.2,
                        Col(ov.color), ov.alpha or 0.95)
                end
            end
        end

        -- a reference line (zero profit, break-even...)
        if d.baseline and d.baseline > lo and d.baseline < hi then
            local y = Y(d.baseline)
            local x = 0
            while x < W do
                local t = self.dashes:Get()
                t:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 0.5)
                t:ClearAllPoints()
                t:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", x, y)
                t:SetSize(math.min(2, W - x), 1)
                t:Show()
                x = x + 5
            end
        end

        -- dashed last price line and its tag
        local lastC = candles[n].c
        if lastC >= lo and lastC <= hi then
            local up = (n < 2) or (candles[n].c >= candles[n].o)
            if d.mode == "line" and n >= 2 then up = candles[n].c >= candles[n - 1].c end
            if d.centerZero then up = lastC >= 0 end
            local col = d.tagColor and Col(d.tagColor) or (up and C.up or C.down)
            local y = Y(lastC)
            local x = (d.mode == "line" and not d.centerZero) and W or 0
            while x < W do
                local t = self.dashes:Get()
                t:SetColorTexture(col[1], col[2], col[3], 0.7)
                t:ClearAllPoints()
                t:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", x, y)
                t:SetSize(math.min(4, W - x), 1)
                t:Show()
                x = x + 7
            end
            self.tag.bg:SetColorTexture(col[1], col[2], col[3], 1)
            self.tag.text:SetText(Fmt(d, lastC))
            self.tag:ClearAllPoints()
            self.tag:SetPoint("LEFT", self.plot, "BOTTOMRIGHT", 1, y)
            self.tag:Show()
        else
            self.tag:Hide()
        end

        -- lower panel
        if d.lower then
            local LH = self.lower:GetHeight()
            local values, signed = {}, false
            local maxAbs = 0
            for i = first, last do
                local v
                if d.lower == "volume" then
                    v = candles[i].v
                else
                    v = d.lower.values[i]
                end
                values[i] = v
                if v then
                    if v < 0 then signed = true end
                    if math.abs(v) > maxAbs then maxAbs = math.abs(v) end
                end
            end
            local t = self.lgrid:Get()
            t:SetColorTexture(C.line[1], C.line[2], C.line[3], 0.6)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self.lower, "TOPLEFT", 0, 0)
            t:SetPoint("TOPRIGHT", self.lower, "TOPRIGHT", 0, 0)
            t:SetHeight(1)
            t:Show()
            local base = signed and LH / 2 or 0
            local span = signed and (LH / 2 - 2) or (LH - 12)
            if maxAbs > 0 then
                for i = first, last do
                    local v = values[i]
                    if v and v ~= 0 then
                        local hgt = math.max(1, math.abs(v) / maxAbs * span)
                        local col
                        if d.lower == "volume" then
                            col = (candles[i].c >= candles[i].o) and C.up or C.down
                        else
                            col = v >= 0 and C.up or C.down
                        end
                        local bar = self.bars:Get()
                        bar:SetColorTexture(col[1], col[2], col[3], 0.45)
                        bar:ClearAllPoints()
                        bar:SetPoint("BOTTOMLEFT", self.lower, "BOTTOMLEFT", math.floor(X(i)) - (bw - 1) / 2,
                            v >= 0 and base or (base - hgt))
                        bar:SetSize(bw, hgt)
                        bar:Show()
                    end
                end
            end
            self.lowerValues = values
        end

        self.grid:HideRest(); self.fills:HideRest(); self.rects:HideRest(); self.lines:HideRest()
        self.dashes:HideRest(); self.bars:HideRest(); self.lgrid:HideRest(); self.ylabels:HideRest(); self.marks:HideRest()
        self.tlabels:HideRest()
        self:UpdateLegend(self.hoverIndex or last)
    end

    -- OHLC of one candle, the overlays' values and the lower panel's value
    function ch:UpdateLegend(i)
        local d = self.data
        local c = d and d.candles and d.candles[i]
        if not c then return end
        local prev = d.candles[i - 1]
        local chg = prev and prev.c > 0 and (c.c / prev.c - 1) or nil
        local function V(v) return FT.C("text", Fmt(d, v)) end
        local when = FT.C("muted", TimeText(d, c.t))
        if d.mode == "line" and d.centerZero then
            self.legend:SetText(when .. "   " .. FT.C(c.c >= 0 and "up" or "down", Fmt(d, c.c)))
        elseif d.mode == "line" then
            self.legend:SetText(when .. "   " .. V(c.c) .. "  " .. FT.Pct(chg))
        else
            self.legend:SetText(when .. "   " .. FT.C("dim", "O ") .. V(c.o) .. "  " .. FT.C("dim", "H ") .. V(c.h)
                .. "  " .. FT.C("dim", "L ") .. V(c.l) .. "  " .. FT.C("dim", "C ") .. V(c.c) .. "  " .. FT.Pct(chg))
        end
        local parts = {}
        for _, ov in ipairs(d.overlays or {}) do
            local v = ov.values[i]
            if v and ov.label then
                local col = Col(ov.color)
                local hex = string.format("%02x%02x%02x", math.floor(col[1] * 255), math.floor(col[2] * 255),
                    math.floor(col[3] * 255))
                parts[#parts + 1] = "|cff" .. hex .. ov.label .. " " .. Fmt(d, v) .. "|r"
            end
        end
        self.legendMA:SetText(table.concat(parts, "   "))
        self:FitHead()
        if d.lower then
            local v = self.lowerValues and self.lowerValues[i]
            local label = d.lowerLabel or ""
            local text
            if v == nil then
                text = "—"
            elseif d.lower == "volume" then
                text = FT.Num(v)
            else
                text = (d.lowerFmt or FT.Money)(v)
            end
            self.lowerText:SetText(label .. "  " .. text)
        end
    end

    -- crosshair, zoom and drag
    local function CursorInPlot()
        local x, y = GetCursorPosition()
        local s = ch.plot:GetEffectiveScale()
        return x / s - (ch.plot:GetLeft() or 0), y / s - (ch.plot:GetBottom() or 0)
    end

    local function Hover()
        local d = ch.data
        if not (d and ch.first and ch.slot) or #d.candles == 0 then return end
        local px, py = CursorInPlot()
        if ch.dragging then
            local moved = math.floor((px - ch.dragX) / ch.slot + 0.5)
            local n = #d.candles
            local o = math.max(0, math.min(ch.dragOffset + moved, n - ch.count))
            if o ~= ch.offset then
                ch.offset = o
                ch:Render()
            end
        end
        local i = ch.first + math.floor(px / ch.slot)
        i = math.max(ch.first, math.min(ch.last, i))
        local x = ch.X(i)
        ch.cx:ClearAllPoints()
        ch.cx:SetPoint("TOP", ch.plot, "TOPLEFT", x, 0)
        ch.cx:SetPoint("BOTTOM", ch, "BOTTOMLEFT", x, TIME_H)
        ch.cx:Show()
        ch.cxTag.text:SetText(TimeText(d, d.candles[i].t))
        ch.cxTag:SetWidth(ch.cxTag.text:GetStringWidth() + 12)
        ch.cxTag:ClearAllPoints()
        ch.cxTag:SetPoint("CENTER", ch, "BOTTOMLEFT", x, TIME_H / 2)
        ch.cxTag:Show()
        local H = ch.plot:GetHeight()
        local simple = d.mode == "line" and not d.centerZero
        if simple then
            ch.hdot:ClearAllPoints()
            ch.hdot:SetPoint("CENTER", ch.plot, "BOTTOMLEFT", x, ch.Y(d.candles[i].c))
            UI.SetTexColor(ch.hdot, (d.candles[ch.last].c >= d.candles[ch.first].c) and "up" or "down", 1)
            ch.hdot:Show()
        else
            ch.hdot:Hide()
        end
        if py >= 0 and py <= H and not simple then
            ch.cy:ClearAllPoints()
            ch.cy:SetPoint("LEFT", ch.plot, "BOTTOMLEFT", 0, py)
            ch.cy:SetPoint("RIGHT", ch.plot, "BOTTOMRIGHT", 0, py)
            ch.cy:Show()
            ch.cyTag.text:SetText(Fmt(d, ch.lo + py / H * (ch.hi - ch.lo)))
            ch.cyTag:ClearAllPoints()
            ch.cyTag:SetPoint("LEFT", ch.plot, "BOTTOMRIGHT", 1, py)
            ch.cyTag:Show()
        else
            ch.cy:Hide()
            ch.cyTag:Hide()
        end
        if ch.hoverIndex ~= i then
            ch.hoverIndex = i
            ch:UpdateLegend(i)
            if ch.onHover then ch.onHover(i, d.candles[i]) end
        end
    end

    ch.mouse:SetScript("OnEnter", function(self) self:SetScript("OnUpdate", Hover) end)
    ch.mouse:SetScript("OnLeave", function(self)
        if ch.dragging then return end
        self:SetScript("OnUpdate", nil)
        ch.cx:Hide(); ch.cy:Hide(); ch.cyTag:Hide(); ch.cxTag:Hide(); ch.hdot:Hide()
        ch.hoverIndex = nil
        if ch.last then ch:UpdateLegend(ch.last) end
        if ch.onHover then ch.onHover(nil) end
    end)
    ch.mouse:SetScript("OnMouseWheel", function(_, delta)
        local d = ch.data
        if not (d and #d.candles > 0 and ch.count) then return end
        local n = #d.candles
        local c = math.floor(ch.count * (delta > 0 and 0.8 or 1.25) + 0.5)
        c = math.max(math.min(n, 8), math.min(n, c))
        if c ~= ch.count then
            ch.count = c
            ch:Render()
        end
    end)
    ch.mouse:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local px = CursorInPlot()
        ch.dragging, ch.dragX, ch.dragOffset = true, px, ch.offset or 0
    end)
    ch.mouse:SetScript("OnMouseUp", function(self)
        ch.dragging = false
        if not self:IsMouseOver() then
            self:GetScript("OnLeave")(self)
        end
    end)
    -- the header line - the title, then the values under the mouse - in the chart's width: what doesn't fit is cut
    -- ("..."), the averages go first
    function ch:FitHead()
        local w = self:GetWidth()
        if not w or w <= 0 then return end
        local avail = w - 16
        self.title:SetWidth(0)
        local tw = math.min(self.title:GetStringWidth(), avail)
        if self.title:GetStringWidth() > avail then self.title:SetWidth(avail) end
        local room = avail - tw - 10
        self.legend:SetWidth(0)
        local lw = self.legend:GetStringWidth()
        local hasMA = (self.legendMA:GetText() or "") ~= ""
        local mw = hasMA and self.legendMA:GetStringWidth() or 0
        if lw + (hasMA and (14 + mw) or 0) <= room then
            self.legendMA:SetShown(hasMA)
            return
        end
        self.legendMA:Hide()
        if lw > room then self.legend:SetWidth(math.max(1, room)) end
    end

    ch:HookScript("OnSizeChanged", function(self)
        self:Layout()
        self:Render()
    end)
    ch:Layout()
    return ch
end

-- candles from a plain list of { t, value } (portfolio worth, market value...)
function UI.LineCandles(points, key)
    local out = {}
    for _, p in ipairs(points) do
        local v = p[key or "value"]
        if v then out[#out + 1] = { t = p.t, o = v, h = v, l = v, c = v } end
    end
    return out
end
