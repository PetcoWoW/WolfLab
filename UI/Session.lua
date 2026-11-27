-- Wolf Lab: a sample farming session panel, to try the fold (batch item 11). Folded: only the top line (the gold
-- this session and gold an hour). Unfolded: the items found too. Fold state and place stay after /reload. Its
-- loot is made up: nothing is read from the game.
local ADDON, FT = ...
local UI, L = FT.UI, FT.L
local D, Lab = FT.Data, FT.Lab

local S = {}
FT.Session = S

local ROWS, ROW_H = 6, 16
local hud, run

-- what the sample session "finds": item, how many a minute
local LOOT = { { 10620, 1.4 }, { 7068, 0.18 }, { 12363, 0.05 }, { 14047, 0.9 }, { 12808, 0.12 }, { 13926, 0.02 } }

local function Found()
    local mins = run and (time() - run.start) / 60 or 0
    local items, worth = {}, 0
    for _, l in ipairs(LOOT) do
        -- a quick start: something shows from the first minute
        local qty = math.floor((mins + 3) * l[2] + 0.5)
        if qty > 0 then
            local v = D.items[l[1]].price * qty
            worth = worth + v
            items[#items + 1] = { id = l[1], qty = qty, value = v }
        end
    end
    table.sort(items, function(a, b) return a.value > b.value end)
    return items, worth, mins
end

local function Height()
    local folded = FT.db.ui and FT.db.ui.sessionFolded
    if folded then return UI.RowH(50) end
    return UI.RowH(60) + ROWS * UI.RowH(ROW_H) + 34
end

local function Build()
    UI.ResolveFont()
    local h = CreateFrame("Frame", "WolfLabSession", UIParent, UI.EdgeTemplate())
    h:SetSize(270, Height())
    h:SetFrameStrata("MEDIUM")
    h:SetClampedToScreen(true)
    h:EnableMouse(true)
    h:SetMovable(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", h.StartMoving)
    h:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        FT.db.ui.session = { p, rp, x, y }
    end)
    local pos = FT.db.ui.session
    if pos then h:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else h:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80) end
    UI.Skin(h, "popup", "bg1", 0.92)

    h.title = UI.Text(h, 11, "accent")
    h.title:SetPoint("TOPLEFT", 10, -9)
    h.title:SetText(L["Session · Un'Goro Crater"])
    -- the fold: – folds it to the top line, + brings the items back
    h.fold = UI.Button(h, "–", 22, 18, "default", function() S.Fold() end)
    h.fold:SetPoint("TOPRIGHT", -6, -5)
    h.time = UI.Text(h, 11, "muted", "RIGHT")
    h.time:SetPoint("RIGHT", h.fold, "LEFT", -8, 0)
    h.worth = UI.Text(h, 16, "text")
    h.worth:SetPoint("TOPLEFT", 10, -28)
    h.rate = UI.Text(h, 13, "up", "RIGHT")
    h.rate:SetPoint("TOPRIGHT", -10, -30)

    h.body = CreateFrame("Frame", nil, h)
    h.body:SetPoint("TOPLEFT", 0, -UI.RowH(52))
    h.body:SetPoint("BOTTOMRIGHT")
    h.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, h.body)
        r:SetHeight(UI.RowH(ROW_H))
        r:SetPoint("TOPLEFT", 6, -(i - 1) * UI.RowH(ROW_H))
        r:SetPoint("RIGHT", -10, 0)
        r.l = UI.Text(r, 11, "muted")
        r.l:SetPoint("LEFT", 4, 0)
        r.r = UI.Text(r, 11, "text", "RIGHT")
        r.r:SetPoint("RIGHT", -2, 0)
        r.l:SetPoint("RIGHT", r.r, "LEFT", -8, 0)
        r:SetScript("OnEnter", function(self) if self.id then Lab.ItemTip(self, self.id) end end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function(self) if self.id then Lab.OpenItem(self.id) end end)
        h.rows[i] = r
    end
    h.stop = UI.Button(h.body, L["Stop"], nil, 20, "down", function() S.Stop() end)
    h.stop:FitText(16)
    h.stop:SetPoint("BOTTOMLEFT", 8, 6)
    h.open = UI.Button(h.body, L["Details"], nil, 20, "default", function() FT.Show("you") end)
    h.open:FitText(16)
    h.open:SetPoint("BOTTOMRIGHT", -8, 6)

    h.elapsed = 0
    h:SetScript("OnUpdate", function(self, e)
        self.elapsed = self.elapsed + e
        if self.elapsed >= 1 then self.elapsed = 0; S.Update() end
    end)
    hud = h
end

function S.Update()
    if not (hud and run) then return end
    local items, worth, mins = Found()
    local folded = FT.db.ui.sessionFolded and true or false
    hud.time:SetText(string.format("%d:%02d", math.floor(mins / 60), math.floor(mins % 60)))
    hud.worth:SetText(FT.Money(worth, "gold"))
    hud.rate:SetText(FT.Money(math.floor(worth * 60 / math.max(mins, 10)), "gold") .. FT.C("muted", " " .. L["an hour"]))
    hud.fold:SetLabel(folded and "+" or "–")
    hud.fold:SetTip(folded and L["Show the items"] or L["Fold it"],
        folded and L["Brings back what you've found."] or L["Just the gold and gold an hour: takes less room."])
    hud.body:SetShown(not folded)
    hud:SetHeight(Height())
    for i, r in ipairs(hud.rows) do
        local it = items[i]
        r:SetShown(it ~= nil)
        if it then
            r.id = it.id
            r.l:SetText(FT.ItemText(it.id) .. FT.C("dim", " ×" .. it.qty))
            r.r:SetText(FT.Money(it.value, "short"))
        end
    end
end

function S.Running() return run ~= nil end

function S.Start()
    if not FT.db then return end
    if not hud then Build() end
    run = { start = time() }
    hud:Show()
    S.Update()
    FT.Fire("FT_SESSION")
end

function S.Stop()
    run = nil
    if hud then hud:Hide() end
    FT.Fire("FT_SESSION")
end

function S.Fold()
    FT.db.ui.sessionFolded = not FT.db.ui.sessionFolded or nil
    S.Update()
end
