-- Wolf Lab: a donut chart of where your wealth sits. Drawn from 360 short lines (one a degree: the game has no arcs).
-- Hover a slice: it stands out and its numbers show; click: it stays chosen (again: everything). Used on You.
local ADDON, FT = ...
local UI, L = FT.UI, FT.L

local Lab = FT.Lab

-- parent, outer radius, ring width; onPick(key or nil) when a slice is clicked
function Lab.Donut(parent, R, ringW, onPick)
    local d = CreateFrame("Frame", nil, parent)
    local PADR = 8 -- room for a slice to stand out
    d:SetSize((R + PADR) * 2, (R + PADR) * 2)
    d:EnableMouse(true)
    d.lines = {}
    for i = 1, 360 do d.lines[i] = UI.NewLine(d, "ARTWORK") end
    d.slices, d.of = {}, {}
    d.center = UI.Text(d, 20, "text", "CENTER")
    d.center:SetPoint("CENTER", 0, 8)
    d.sub = UI.Text(d, 12, "muted", "CENTER")
    d.sub:SetPoint("TOP", d.center, "BOTTOM", 0, -4)

    local function SliceAt()
        local x, y = GetCursorPosition()
        local s = d:GetEffectiveScale()
        local l, b = d:GetLeft(), d:GetBottom()
        if not (x and l and s and s > 0) then return nil end
        local cx, cy = l + d:GetWidth() / 2, b + d:GetHeight() / 2
        local dx, dy = x / s - cx, y / s - cy
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < R - ringW - 2 or dist > R + PADR then return nil end
        -- degrees clockwise from the top
        local deg = (90 - math.deg(math.atan2(dy, dx))) % 360
        return d.of[math.floor(deg) + 1]
    end

    function d:Draw()
        local c = (self:GetWidth() or 0) / 2
        for i = 1, 360 do
            local key = self.of[i]
            local sl = key and self.byKey[key]
            if sl then
                local lit = (self.hover == key) or (self.picked == key)
                local dim = self.picked and self.picked ~= key and self.hover ~= key
                local r2 = R + (lit and 6 or 0)
                local r1 = R - ringW
                -- clockwise from the top, a degree a line (thick enough to leave no gaps)
                local a = math.rad(90 - (i - 0.5))
                local ca, sa = math.cos(a), math.sin(a)
                UI.PlaceLine(self.lines[i], c + ca * r1, c + sa * r1, c + ca * r2, c + sa * r2, 3, sl.color, dim and 0.3 or (lit and 1 or 0.85))
            else
                UI.HideLine(self.lines[i])
            end
        end
    end

    -- slices = { { key, label, value, color } }; center / sub: the words in the middle
    function d:SetSlices(slices, center, sub)
        self.slices, self.byKey, self.of = slices, {}, {}
        local total = 0
        for _, sl in ipairs(slices) do total = total + math.max(0, sl.value or 0) end
        self.total = total
        local at = 0
        for _, sl in ipairs(slices) do
            self.byKey[sl.key] = sl
            sl.share = total > 0 and (sl.value / total) or 0
            local n = math.floor(sl.share * 360 + 0.5)
            for k = at + 1, math.min(360, at + n) do self.of[k] = sl.key end
            at = at + n
        end
        -- rounding: the last degrees go to the last slice
        for k = at + 1, 360 do self.of[k] = slices[#slices] and slices[#slices].key end
        if self.picked and not self.byKey[self.picked] then self.picked = nil end
        self.center:SetText(center or "")
        self.sub:SetText(sub or "")
        self:Draw()
    end

    function d:Pick(key)
        self.picked = (key and self.picked ~= key) and key or nil
        self:Draw()
        if onPick then onPick(self.picked) end
    end

    d:SetScript("OnUpdate", function(self)
        if not self:IsMouseOver() then
            if self.hover then self.hover = nil; self:Draw(); GameTooltip:Hide() end
            return
        end
        local key = SliceAt()
        if key ~= self.hover then
            self.hover = key
            self:Draw()
            local sl = key and self.byKey[key]
            if sl then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(sl.label, 1, 0.82, 0)
                GameTooltip:AddDoubleLine(FT.Money(sl.value, "gold"), string.format("%d%%", math.floor(sl.share * 100 + 0.5)), 1, 1, 1, 0.8, 0.8, 0.8)
                if sl.tip then GameTooltip:AddLine(sl.tip, 0.75, 0.75, 0.75, true) end
                GameTooltip:AddLine(self.picked == key and L["Click: show everything again"] or L["Click: just this"], 0.58, 0.55, 0.5)
                GameTooltip:Show()
            else
                GameTooltip:Hide()
            end
        end
    end)
    d:SetScript("OnMouseUp", function(self) local key = SliceAt(); if key then self:Pick(key) end end)
    return d
end
