-- Wolf: widgets (buttons, inputs, lists, badges, sparklines...)
local ADDON, FT = ...
local UI = FT.UI
local C = UI.C
local L = FT.L

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local STYLES = {
    default = { bg = "bg2", bgA = 1, hover = "bg3", hoverA = 1, text = "text", border = "line" },
    primary = { bg = "accent", bgA = 1, hover = { 1, 0.80, 0.25 }, hoverA = 1, text = { 0.08, 0.08, 0.08 } },
    ghost = { bg = "bg2", bgA = 0, hover = "bg2", hoverA = 1, text = "muted", hoverText = "text" },
    up = { bg = "up", bgA = 0.14, hover = "up", hoverA = 0.26, text = "up", border = "up", borderA = 0.45 },
    down = { bg = "down", bgA = 0.14, hover = "down", hoverA = 0.26, text = "down", border = "down", borderA = 0.45 },
}

-- the classic look: the game's red button paints itself (normal, pushed, lit, disabled); only the label is ours:
-- gold, white under the mouse or when chosen, grey when off, green / red for the buy and sell styles
local function PaintGame(b, hover)
    local s = b.style
    if b.active then
        UI.SetTextColor(b.label, "text")
        if b.LockHighlight then b:LockHighlight() end
        return
    end
    if b.UnlockHighlight then b:UnlockHighlight() end
    if b.disabled then
        UI.SetTextColor(b.label, "dim")
    elseif s.text == "up" or s.text == "down" then
        UI.SetTextColor(b.label, s.text)
    else
        UI.SetTextColor(b.label, hover and "text" or "accent")
    end
end

local function Paint(b, hover)
    if b.game then return PaintGame(b, hover) end
    local s = b.style
    if b.active then
        UI.SetTexColor(b.bg, s.activeBg or "bg3", 1)
        UI.SetTextColor(b.label, s.activeText or "accent")
        return
    end
    if b.disabled then
        UI.SetTexColor(b.bg, "bg2", (s.bgA or 1) > 0 and 0.7 or 0)
        UI.SetTextColor(b.label, "dim")
        return
    end
    if hover then
        UI.SetTexColor(b.bg, s.hover, s.hoverA or 1)
        UI.SetTextColor(b.label, s.hoverText or s.text)
    else
        UI.SetTexColor(b.bg, s.bg, s.bgA or 1)
        UI.SetTextColor(b.label, s.text)
    end
end

-- a button style by name (for a button that changes its look)
function UI.ButtonStyle(name)
    return STYLES[name] or STYLES.default
end

-- the game's red button (the classic look, every style but ghost); nil when the client hasn't the template
local function GameButton(parent, style)
    if not UI.Classic() or style == "ghost" then return nil end
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not b then return nil end
    -- its own text stays empty: the label is ours (our font, our size)
    local fs = b.GetFontString and b:GetFontString()
    if fs then fs:SetText("") end
    b.game = true
    return b
end

function UI.Button(parent, text, w, h, style, onClick)
    local b = GameButton(parent, style or "default") or CreateFrame("Button", nil, parent)
    h = UI.ControlH(h)
    b:SetSize(w or 80, h)
    b.style = STYLES[style or "default"] or STYLES.default
    b.bg = UI.RoundTex(b, "BACKGROUND", "bg2", b.game and 0 or 1)
    b.bg:SetAllPoints()
    if b.game then b.bg:Hide() end
    if b.style.border and not b.game then UI.Border(b, b.style.border, b.style.borderA) end
    b.label = UI.Text(b, 12, b.style.text, "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(text or "")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self)
        Paint(self, true)
        if self.tip then UI.TipText(self, self.tip[1], self.tip[2]) end
    end)
    b:SetScript("OnLeave", function(self)
        Paint(self, false)
        if self.tip then GameTooltip:Hide() end
    end)
    -- hooked, not set: the game's button swaps its pushed art in these
    local Script = b.game and b.HookScript or b.SetScript
    Script(b, "OnMouseDown", function(self)
        if not self.disabled then self.label:SetPoint("CENTER", self.game and 1 or 0, self.game and -2 or -1) end
    end)
    Script(b, "OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
    b:SetScript("OnClick", function(self, button)
        if self.disabled then return end
        if self.onClick then self.onClick(self, button) end
    end)
    b.onClick = onClick
    function b:SetLabel(t) self.label:SetText(t) end
    function b:SetActive(on)
        self.active = on and true or false
        Paint(self, self:IsMouseOver())
    end
    function b:SetUsable(on)
        self.disabled = not on
        -- the game's button shows its greyed art when disabled (hovering still shows a tip)
        if self.game then
            if on then self:Enable() else self:Disable() end
        end
        Paint(self, false)
    end
    function b:SetTip(title, body) self.tip = title and { title, body } or nil end
    function b:FitText(pad)
        self:SetWidth(math.ceil(self.label:GetStringWidth()) + (pad or 20))
    end
    Paint(b, false)
    return b
end

-- a window's close button: the game's red X in the classic look, a plain × in the dark one
function UI.CloseButton(parent, onClick, size)
    if UI.Classic() then
        local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelCloseButton")
        if ok and b then
            b:SetSize(size or 30, size or 30)
            b:SetScript("OnClick", function() onClick() end)
            return b
        end
    end
    local b = UI.Button(parent, "×", size or 30, size or 30, "ghost", onClick)
    b.label:SetFont(UI.FONT, UI.Size(18), "")
    return b
end

-- a row of buttons where one is chosen: options = { { value, label }, ... }
function UI.Segmented(parent, options, onChange, h)
    h = h or 22
    local f = CreateFrame("Frame", nil, parent)
    -- the classic look: a row of the game's red buttons, the chosen one lit
    local classic = UI.Classic()
    if not classic then
        UI.Fill(f, "bg2")
        UI.Border(f, "line")
    end
    f.buttons = {}
    local x = classic and 0 or 2
    for i, opt in ipairs(options) do
        local b = UI.Button(f, opt[2], 10, classic and h or (h - 4), classic and "default" or "ghost")
        if not b.game then
            b.style = { bg = "bg3", bgA = 0, hover = "bg3", hoverA = 0.6, text = "muted", hoverText = "text",
                activeBg = "bg3", activeText = "accent" }
        end
        b:FitText(18)
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() + (classic and 1 or 2)
        b.value = opt[1]
        b.onClick = function()
            f:SetValue(opt[1])
            if onChange then onChange(opt[1]) end
        end
        f.buttons[i] = b
    end
    f:SetSize(x, h)
    function f:SetValue(v)
        self.value = v
        for _, b in ipairs(self.buttons) do b:SetActive(b.value == v) end
    end
    return f
end

-- the classic look: the game's own tabs (TabButtonTemplate), standing on the header's bottom line; nil when the
-- client hasn't them (then: the text tabs below)
local navN = 0
local function GameTabs(parent, items, onSelect)
    if not (UI.Classic() and PanelTemplates_SelectTab and PanelTemplates_DeselectTab and PanelTemplates_TabResize) then return nil end
    local f = CreateFrame("Frame", nil, parent)
    local ok = pcall(function()
        f.tabs = {}
        local x = 0
        for _, it in ipairs(items) do
            navN = navN + 1
            local b = CreateFrame("Button", "WolfLabNavTab" .. navN, f, "TabButtonTemplate")
            b:SetText(it[2])
            PanelTemplates_TabResize(b, 0)
            local fs = b:GetFontString()
            local w = math.max(b:GetWidth() or 0, math.ceil(fs and fs:GetStringWidth() or 0) + 24)
            b:SetWidth(w)
            b:SetPoint("BOTTOMLEFT", x, -2)
            x = x + w - 2
            b.key = it[1]
            b:SetScript("OnClick", function(self) onSelect(self.key) end)
            f.tabs[#f.tabs + 1] = b
        end
        f:SetSize(x + 2, 44)
        function f:SetValue(key)
            self.value = key
            for _, b in ipairs(self.tabs) do
                if b.key == key then PanelTemplates_SelectTab(b) else PanelTemplates_DeselectTab(b) end
            end
        end
        f:SetValue(items[1] and items[1][1])
    end)
    if ok then return f end
    -- half built: out of sight
    f:Hide()
    return nil
end

-- top navigation: text tabs with an accent line under the chosen one
function UI.NavTabs(parent, items, onSelect)
    local game = GameTabs(parent, items, onSelect)
    if game then return game end
    local f = CreateFrame("Frame", nil, parent)
    f.tabs = {}
    local x = 0
    for _, it in ipairs(items) do
        local b = CreateFrame("Button", nil, f)
        b.text = UI.Text(b, 13, "muted", "CENTER")
        b.text:SetPoint("CENTER", 0, 1)
        b.text:SetText(it[2])
        local w = math.ceil(b.text:GetStringWidth()) + 18
        b:SetSize(w, 44)
        b:SetPoint("LEFT", x, 0)
        x = x + w
        b.line = UI.Tex(b, "OVERLAY", "accent", 1)
        b.line:SetHeight(2)
        b.line:SetPoint("BOTTOMLEFT", 7, 0)
        b.line:SetPoint("BOTTOMRIGHT", -7, 0)
        b.line:Hide()
        b.key = it[1]
        b:SetScript("OnEnter", function(self) if f.value ~= self.key then UI.SetTextColor(self.text, "text") end end)
        b:SetScript("OnLeave", function(self) if f.value ~= self.key then UI.SetTextColor(self.text, "muted") end end)
        b:SetScript("OnClick", function(self) onSelect(self.key) end)
        f.tabs[#f.tabs + 1] = b
    end
    f:SetSize(x, 44)
    function f:SetValue(key)
        self.value = key
        for _, b in ipairs(self.tabs) do
            b.line:SetShown(b.key == key)
            UI.SetTextColor(b.text, b.key == key and "text" or "muted")
        end
    end
    return f
end

-- a filter pill
function UI.Chip(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b.bg = UI.RoundTex(b, "BACKGROUND", "bg2", 1)
    b.bg:SetAllPoints()
    UI.Border(b, "line")
    b.label = UI.Text(b, 11, "muted", "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    b:SetSize(math.ceil(b.label:GetStringWidth()) + 18, 20)
    local function Paint2(self, hover)
        if self.on then
            UI.SetTexColor(self.bg, "accent", 0.12)
            self:SetBorderColor("accent", 0.8)
            UI.SetTextColor(self.label, "accent")
        else
            UI.SetTexColor(self.bg, hover and "bg3" or "bg2", 1)
            self:SetBorderColor("line", 1)
            UI.SetTextColor(self.label, hover and "text" or "muted")
        end
    end
    b:SetScript("OnEnter", function(self) Paint2(self, true) end)
    b:SetScript("OnLeave", function(self) Paint2(self, false) end)
    b:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
    function b:SetOn(on)
        self.on = on and true or false
        Paint2(self, false)
    end
    function b:SetLabel(t)
        self.label:SetText(t)
        self:SetWidth(math.ceil(self.label:GetStringWidth()) + 18)
    end
    Paint2(b, false)
    return b
end

-- lay chips out left to right, wrapping is not needed: returns the width used
function UI.RowLayout(parent, items, x, y, gap)
    for _, it in ipairs(items) do
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        x = x + it:GetWidth() + (gap or 6)
    end
    return x
end

---------------------------------------------------------------------------
-- Text input
---------------------------------------------------------------------------
function UI.Input(parent, w, h, placeholder, onChange, onEnter)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(w or 160, UI.ControlH(h))
    e:SetAutoFocus(false)
    e:SetFont(UI.FONT, UI.Size(12), "")
    e:SetTextColor(UI.RGB("text"))
    e:SetTextInsets(8, 8, 0, 0)
    if not UI.InputEdge(e) then
        UI.Fill(e, "bg2")
        UI.Border(e, "line")
    end
    e.ph = UI.Text(e, 12, "dim")
    e.ph:SetPoint("LEFT", 8, 0)
    e.ph:SetPoint("RIGHT", -8, 0)
    e.ph:SetText(placeholder or "")
    local function PH(self) self.ph:SetShown(self:GetText() == "" and not self:HasFocus()) end
    e:SetScript("OnEditFocusGained", function(self)
        self:SetBorderColor("accent", 0.9)
        PH(self)
    end)
    e:SetScript("OnEditFocusLost", function(self)
        self:SetBorderColor("line", 1)
        PH(self)
    end)
    e:SetScript("OnTextChanged", function(self, user)
        PH(self)
        if user and onChange then onChange(self:GetText()) end
    end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onEnter then onEnter(self:GetText()) end
    end)
    function e:SetValue(t)
        self:SetText(t or "")
        PH(self)
    end
    return e
end

-- A question in the addon's style (dark, light or classic):
-- opts = { title, text, ok, cancel, okStyle, onOK, onCancel (Cancel, Esc or closed any other way), input (a box
--          to type in, with this text: onOK(typed)),
--          owner (the same owner may change its question in place; another one's open question is cancelled
--          first), okDelay (seconds the OK button waits: a price that just changed) }.
-- The game's own popups look like the game and can't show our language on their buttons.
local confirm
function UI.Confirm(opts)
    local d = confirm
    if not d then
        UI.ResolveFont()
        d = CreateFrame("Frame", "WolfLabConfirm", UIParent, UI.EdgeTemplate())
        -- above every window (the full-screen Wolf included)
        d:SetFrameStrata("FULLSCREEN_DIALOG")
        d:SetFrameLevel(100)
        d:SetToplevel(true)
        d:SetClampedToScreen(true)
        d:EnableMouse(true)
        d:SetMovable(true)
        d:RegisterForDrag("LeftButton")
        d:SetScript("OnDragStart", d.StartMoving)
        d:SetScript("OnDragStop", d.StopMovingOrSizing)
        d:SetWidth(420)
        if UI.Skin(d, "window", "bg1") == 1 then
            d.accent = UI.RoundTex(d, "ARTWORK", "accent", 1, nil, "top", UI.RADIUS - 1)
            d.accent:SetHeight(2)
            d.accent:SetPoint("TOPLEFT", 1, -1)
            d.accent:SetPoint("TOPRIGHT", -1, -1)
        end
        d.logo = UI.Icon(d, 22)
        d.logo:SetIcon(FT.LOGO)
        d.logo:SetPoint("TOPLEFT", 18, -18)
        d.title = UI.Text(d, 14, "text")
        d.title:SetPoint("LEFT", d.logo, "RIGHT", 10, 0)
        d.title:SetPoint("RIGHT", d, "RIGHT", -18, 0)
        d.text = UI.Text(d, 12, "muted")
        d.text:SetPoint("TOPLEFT", 18, -54)
        d.text:SetWidth(420 - 36) -- a fixed width: its height is known at once
        if d.text.SetWordWrap then d.text:SetWordWrap(true) end
        d.text:SetJustifyV("TOP")
        d.cancel = UI.Button(d, "", 10, 26, "default", function()
            d:Hide()
        end)
        d.cancel:SetPoint("BOTTOMRIGHT", -18, 16)
        d.ok = UI.Button(d, "", 10, 26, "primary", function()
            local ok = d.onOK
            d.accepted = true
            -- the action first, while the button you clicked is still on the screen (the game lets an addon buy,
            -- post or cancel only right in your click), then the window goes - unless the action asked again
            if ok then ok() end
            if d.accepted then d:Hide() end
        end)
        d:SetScript("OnHide", function()
            local cancel = not d.accepted and d.onCancel
            d.onCancel, d.onOK = nil, nil
            -- hidden with the whole interface (Alt+Z): it doesn't come back without its question
            d:Hide()
            if cancel then cancel() end
        end)
        d.ok:SetPoint("RIGHT", d.cancel, "LEFT", -8, 0)
        table.insert(UISpecialFrames, "WolfLabConfirm")
        d:Hide()
        confirm = d
    end
    local owner = opts.owner or opts
    -- another question open: it is cancelled first (its Cancel runs)
    if d:IsShown() and d.owner ~= owner and d.onCancel then
        local cancel = d.onCancel
        d.onCancel = nil
        cancel()
    end
    d.owner = owner
    d.onOK, d.onCancel, d.accepted = opts.onOK, opts.onCancel, false
    d:SetScale(FT.S.scale or 1)
    d.title:SetText(opts.title or "Wolf")
    d.text:SetText(opts.text or "")
    d.ok.style = UI.ButtonStyle(opts.okStyle or "primary")
    d.ok:SetLabel(opts.ok or L["Continue"])
    d.ok:FitText(32)
    d.ok:SetActive(false)
    d.ok:SetUsable(not opts.okDelay)
    if opts.okDelay then
        C_Timer.After(opts.okDelay, function()
            if d.owner == owner and d:IsShown() then d.ok:SetUsable(true) end
        end)
    end
    d.cancel:SetLabel(opts.cancel or L["Cancel"])
    d.cancel:FitText(32)
    -- a text to type (opts.input = its starting text): Enter is OK, and onOK gets what was typed
    local extra = 0
    if opts.input then
        if not d.input then
            d.input = UI.Input(d, 420 - 36, 26, "", nil, function() d.ok:Click() end)
        end
        d.input:ClearAllPoints()
        d.input:SetPoint("TOPLEFT", d.text, "BOTTOMLEFT", 0, -12)
        d.input:SetValue(opts.input)
        d.input:Show()
        d.input:SetFocus()
        d.input:HighlightText()
        local onOK = opts.onOK
        d.onOK = function() if onOK then onOK(d.input:GetText()) end end
        extra = 38
    elseif d.input then
        d.input:Hide()
    end
    d:SetHeight(54 + math.ceil(d.text:GetStringHeight()) + extra + 20 + 26 + 16)
    d:ClearAllPoints()
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    d:Show()
    d:Raise()
end

-- the question closed from outside (as Cancel); owner: only that one's question
function UI.CloseConfirm(owner)
    if confirm and confirm:IsShown() and (owner == nil or confirm.owner == owner) then confirm:Hide() end
end

-- a "×" at the end of an input that empties it (shown while there is text); onClear() after
function UI.ClearButton(e, onClear)
    local b = UI.Button(e, "×", 20, 20, "ghost", function()
        e:SetValue("")
        e:ClearFocus()
        if onClear then onClear() end
    end)
    b.label:SetFont(UI.FONT, UI.Size(15), "")
    b:SetPoint("RIGHT", -2, 0)
    b:SetFrameLevel(e:GetFrameLevel() + 3)
    b:SetTip(L["Clear"])
    e:SetTextInsets(8, 24, 0, 0)
    e.ph:SetPoint("RIGHT", -24, 0)
    b:Hide()
    e:HookScript("OnTextChanged", function(self) b:SetShown(self:GetText() ~= "") end)
    return b
end

-- "12.5" (gold), "12g 50s", "75s", "3g20s15c" -> copper; nil when empty or unreadable
function FT.ParseMoney(str)
    if type(str) ~= "string" then return nil end
    -- Russian units (з = gold, с = silver, м = copper) are two bytes each: turn them into g / s / c first
    str = str:lower():gsub("з", "g"):gsub("З", "g"):gsub("с", "s"):gsub("С", "s"):gsub("м", "c"):gsub("М", "c")
    str = str:gsub(",", "."):gsub("%s+", "")
    if str == "" then return nil end
    local plain = tonumber(str)
    if plain then return math.floor(plain * 10000 + 0.5) end
    local total, any = 0, false
    for num, unit in str:gmatch("([%d%.]+)([gsc])") do
        local v = tonumber(num)
        if not v then return nil end
        if unit == "g" then
            total = total + v * 10000
        elseif unit == "s" then
            total = total + v * 100
        else
            total = total + v
        end
        any = true
    end
    return any and math.floor(total + 0.5) or nil
end

---------------------------------------------------------------------------
-- Money input: three number boxes - gold, silver, copper - each with its coin
-- onCommit(copper or nil when all are empty) runs on Enter and when a box loses focus
---------------------------------------------------------------------------
-- small: the narrow one for cards (gold up to 99,999); noCopper: gold and silver only (auction prices)
function UI.MoneyInput(parent, onCommit, small, noCopper)
    local f = CreateFrame("Frame", nil, parent)
    f.boxes = {}
    local defs = small and { { "Gold", 42, 5 }, { "Silver", 22, 2 }, { "Copper", 22, 2 } }
        or { { "Gold", 56, 7 }, { "Silver", 34, 2 }, { "Copper", 34, 2 } }
    if noCopper then defs[3] = nil end
    local h, coinSize, coinGap, gap = small and 22 or 24, small and 11 or 13, small and 2 or 3, small and 4 or 8
    local x = 0
    for i, d in ipairs(defs) do
        local e = UI.Input(f, d[2], h, "", nil, function() f:Commit() end)
        e:SetNumeric(true)
        e:SetMaxLetters(d[3])
        e:SetJustifyH("RIGHT")
        if small then e:SetTextInsets(2, 4, 0, 0) else e:SetTextInsets(4, 6, 0, 0) end
        e:SetPoint("LEFT", x, 0)
        e:HookScript("OnEditFocusLost", function()
            if not f.committing then f:Commit() end
        end)
        e:SetScript("OnTabPressed", function()
            local nextBox = f.boxes[i % #defs + 1]
            nextBox:SetFocus()
            nextBox:HighlightText()
        end)
        local coin = f:CreateTexture(nil, "ARTWORK")
        coin:SetTexture("Interface\\MoneyFrame\\UI-" .. d[1] .. "Icon")
        coin:SetSize(coinSize, coinSize)
        coin:SetPoint("LEFT", e, "RIGHT", coinGap, 0)
        f.boxes[i] = e
        x = x + d[2] + coinGap + coinSize + gap
    end
    f:SetSize(x - gap, h)

    function f:GetValue()
        local g, s = tonumber(self.boxes[1]:GetText()), tonumber(self.boxes[2]:GetText())
        local c = self.boxes[3] and tonumber(self.boxes[3]:GetText())
        if not (g or s or c) then return nil end
        return (g or 0) * 10000 + (s or 0) * 100 + (c or 0)
    end

    -- copper -> the three boxes (nil: all empty)
    function f:SetValue(copper)
        if copper == nil then
            for _, e in ipairs(self.boxes) do e:SetValue("") end
            return
        end
        copper = math.max(0, math.floor(copper + 0.5))
        self.boxes[1]:SetValue(tostring(math.floor(copper / 10000)))
        self.boxes[2]:SetValue(tostring(math.floor((copper % 10000) / 100)))
        if self.boxes[3] then self.boxes[3]:SetValue(tostring(copper % 100)) end
    end

    function f:HasFocus()
        for _, e in ipairs(self.boxes) do
            if e:HasFocus() then return true end
        end
        return false
    end

    function f:Commit()
        self.committing = true
        if onCommit then onCommit(self:GetValue()) end
        self.committing = false
    end
    return f
end

---------------------------------------------------------------------------
-- Checkbox
---------------------------------------------------------------------------
function UI.Check(parent, label, onChange)
    local b = CreateFrame("Button", nil, parent)
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(14, 14)
    b.box:SetPoint("LEFT")
    if UI.CheckArt(b.box) then
        b.mark = b.box.tick
    else
        UI.Fill(b.box, "bg2")
        UI.Border(b.box, "line")
        b.mark = UI.RoundTex(b.box, "OVERLAY", "accent", 1, nil, nil, 2)
        b.mark:SetPoint("TOPLEFT", 3, -3)
        b.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    b.text = UI.Text(b, 12, "text")
    b.text:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
    b.text:SetText(label or "")
    b:SetSize(22 + math.ceil(b.text:GetStringWidth()), 18)
    function b:SetChecked(v)
        self.checked = v and true or false
        self.mark:SetShown(self.checked)
        self.box:SetBorderColor(self.checked and "accent" or "line", self.checked and 0.9 or 1)
    end
    b:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        if onChange then onChange(self.checked) end
    end)
    b:SetScript("OnEnter", function(self)
        if not self.checked then self.box:SetBorderColor("muted", 1) end
        if self.tip then UI.TipText(self, self.tip[1], self.tip[2]) end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetChecked(self.checked)
        if self.tip then GameTooltip:Hide() end
    end)
    function b:SetTip(title, body) self.tip = { title, body } end
    b:SetChecked(false)
    return b
end

---------------------------------------------------------------------------
-- Dropdown: options = { { value, text }, ... }
---------------------------------------------------------------------------
local openMenu
local blocker

local function CloseMenu()
    if openMenu then openMenu:Hide() end
    openMenu = nil
    if blocker then blocker:Hide() end
end
UI.CloseMenu = CloseMenu

function UI.Dropdown(parent, w, options, onSelect)
    local b = UI.Button(parent, "", w or 140, 24, "default")
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", 8, 0)
    b.label:SetPoint("RIGHT", -20, 0)
    b.label:SetJustifyH("LEFT")
    b.chev = UI.Chevron(b, 8, "muted")
    b.chev:SetPoint("RIGHT", -8, 0)
    b.options = options or {}
    function b:SetOptions(opts) self.options = opts end
    function b:SetValue(v)
        self.value = v
        for _, o in ipairs(self.options) do
            if o[1] == v then self.label:SetText(o[2]) end
        end
    end
    b.onClick = function(self)
        if openMenu and openMenu.owner == self then
            CloseMenu()
            return
        end
        CloseMenu()
        if not blocker then
            blocker = CreateFrame("Button", nil, UIParent)
            blocker:SetAllPoints(UIParent)
            blocker:SetFrameStrata("FULLSCREEN_DIALOG")
            blocker:SetScript("OnClick", CloseMenu)
        end
        -- over every popup of ours (the Filter popup holds dropdowns)
        blocker:SetFrameLevel(120)
        blocker:Show()
        local m = self.menu
        if not m then
            m = CreateFrame("Frame", nil, UIParent)
            m:SetClampedToScreen(true)
            m:SetFrameStrata("FULLSCREEN_DIALOG")
            m:SetFrameLevel(125)
            UI.Skin(m, "popup", "bg2")
            m.items = {}
            self.menu = m
        end
        m.owner = self
        m:SetScale(self:GetEffectiveScale() / UIParent:GetEffectiveScale())
        local y = -4
        for i, o in ipairs(self.options) do
            local it = m.items[i]
            if not it then
                it = CreateFrame("Button", nil, m)
                it:SetHeight(22)
                it.hl = UI.RoundTex(it, "BACKGROUND", "hl", 1)
                it.hl:SetAllPoints()
                it.hl:Hide()
                it.text = UI.Text(it, 12, "text")
                it.text:SetPoint("LEFT", 10, 0)
                it.text:SetPoint("RIGHT", -10, 0)
                it:SetScript("OnEnter", function(s) s.hl:Show() end)
                it:SetScript("OnLeave", function(s) s.hl:Hide() end)
                m.items[i] = it
            end
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", 1, y)
            it:SetPoint("TOPRIGHT", -1, y)
            it.text:SetText(o[2])
            UI.SetTextColor(it.text, o[1] == self.value and "accent" or "text")
            it:SetScript("OnClick", function()
                CloseMenu()
                self:SetValue(o[1])
                if onSelect then onSelect(o[1]) end
            end)
            it:Show()
            y = y - 22
        end
        for i = #self.options + 1, #m.items do m.items[i]:Hide() end
        m:SetSize(self:GetWidth(), -y + 4)
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        m:Show()
        openMenu = m
    end
    return b
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
function UI.TipText(owner, title, body)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title or "", 1, 1, 1)
    if body then GameTooltip:AddLine(body, 0.75, 0.78, 0.82, true) end
    GameTooltip:Show()
end

function UI.TipItem(owner, itemID, anchor)
    if not itemID then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(itemID)
    else
        GameTooltip:SetHyperlink("item:" .. itemID)
    end
    GameTooltip:Show()
end

-- shift-click links the item in chat, ctrl-click previews it
function UI.ItemClick(itemID)
    if not itemID then return false end
    local _, _, _, _, link = FT.Item(itemID)
    if link and HandleModifiedItemClick then
        return HandleModifiedItemClick(link)
    end
    return false
end

---------------------------------------------------------------------------
-- Columns (shared by a header and the rows of a list)
---------------------------------------------------------------------------
-- cols = { { key, title, width = number | "fill", justify, sort } }
function UI.LayoutColumns(cols, total, pad, gap)
    pad, gap = pad or 10, gap or 8
    local fixed, fills = 0, 0
    for _, c in ipairs(cols) do
        if c.width == "fill" then fills = fills + 1 else fixed = fixed + c.width end
    end
    local fillW = math.max(40, (total - pad * 2 - gap * (#cols - 1) - fixed) / math.max(1, fills))
    local x = pad
    for _, c in ipairs(cols) do
        c._x = x
        c._w = (c.width == "fill") and fillW or c.width
        x = x + c._w + gap
    end
end

function UI.Header(parent, cols, onSort)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(24)
    -- at the top of a panel: its corners follow the panel's
    UI.Fill(h, "bg1", nil, "top", UI.RADIUS - 1)
    local line = UI.HLine(h, "line")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    h.cols, h.cells = cols, {}
    for _, c in ipairs(cols) do
        local b = CreateFrame("Button", nil, h)
        b:SetHeight(24)
        b.text = UI.Text(b, 11, "muted", c.justify or "LEFT")
        b.text:SetAllPoints()
        b.text:SetText(c.title or "")
        b.chev = UI.Chevron(b, 6, "accent")
        b.chev:Hide()
        if c.sort and onSort then
            b:SetScript("OnClick", function() onSort(c.sort) end)
            b:SetScript("OnEnter", function(s) if h.sortKey ~= c.sort then UI.SetTextColor(s.text, "text") end end)
            b:SetScript("OnLeave", function(s) if h.sortKey ~= c.sort then UI.SetTextColor(s.text, "muted") end end)
        end
        if c.tip then
            b:HookScript("OnEnter", function(s) UI.TipText(s, c.title, c.tip) end)
            b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        h.cells[c.key] = b
    end
    function h:Layout()
        -- the same width the list rows use (they leave 10 for the scroll bar)
        UI.LayoutColumns(self.cols, self:GetWidth() - 10)
        for _, c in ipairs(self.cols) do
            local b = self.cells[c.key]
            b:ClearAllPoints()
            b:SetPoint("LEFT", self, "LEFT", c._x, 0)
            b:SetWidth(c._w)
        end
        self:SetSort(self.sortKey, self.sortDesc)
    end
    function h:SetSort(key, desc)
        self.sortKey, self.sortDesc = key, desc
        for _, c in ipairs(self.cols) do
            local b = self.cells[c.key]
            local on = c.sort and c.sort == key
            UI.SetTextColor(b.text, on and "accent" or "muted")
            b.chev:SetShown(on and true or false)
            if on then
                b.chev:SetDir(desc and "down" or "up", "accent")
                b.chev:ClearAllPoints()
                local tw = math.min(b.text:GetStringWidth(), c._w or 0)
                if (c.justify or "LEFT") == "RIGHT" then
                    b.chev:SetPoint("RIGHT", b, "RIGHT", -tw - 4, 0)
                else
                    b.chev:SetPoint("LEFT", b, "LEFT", tw + 4, 0)
                end
            end
        end
    end
    h:HookScript("OnSizeChanged", function(self) self:Layout() end)
    return h
end

---------------------------------------------------------------------------
-- Virtual list: only the visible rows exist
-- opts = { rowHeight, cols, setup(row), update(row, item, index), onClick(item, button, row), onEnter(row, item),
--          onLeave(row, item), isSelected(item) }
---------------------------------------------------------------------------
-- A small round countdown: it fills green until the item's next live search, then starts again.
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
function UI.LiveRing(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local r, g, b = UI.RGB("up")
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetTexture(CIRCLE)
    f.bg:SetVertexColor(r, g, b, 0.3)
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints()
        cd.noCooldownCount = true -- no numbers from cooldown-count addons
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetSwipeTexture then cd:SetSwipeTexture(CIRCLE) end
        if cd.SetSwipeColor then cd:SetSwipeColor(r, g, b, 1) end
        -- the part of the round gone by is drawn: it fills up
        if cd.SetReverse then cd:SetReverse(true) end
        f.cd = cd
    end
    -- start, duration from FT.Scanner.LiveTick; 0: pale, waiting for its first search; nil hides it
    function f:Set(start, duration)
        if not start then
            self.start = nil
            self:Hide()
            return
        end
        self:Show()
        if start == 0 then
            if self.start ~= 0 then
                self.start, self.dur = 0, 0
                if self.cd then
                    if self.cd.Clear then self.cd:Clear() else self.cd:SetCooldown(0, 0) end
                end
            end
            return
        end
        if not self.start or self.start == 0 or math.abs(self.start - start) > 0.05 or math.abs(self.dur - duration) > 0.05 then
            self.start, self.dur = start, duration
            if self.cd then self.cd:SetCooldown(start, duration) end
        end
    end
    f:Hide()
    return f
end

-- a circle that follows one item by itself: getID() -> the item shown there (by the "live" label)
function UI.LiveRingFor(parent, size, getID)
    local ring = UI.LiveRing(parent, size)
    local tick = CreateFrame("Frame", nil, parent)
    tick.elapsed = 0
    tick:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.3 then return end
        self.elapsed = 0
        ring:Set(FT.Scanner.LiveTick(getID()))
    end)
    return ring
end

-- opts.liveID(item) -> itemID: the rows of items kept live show their countdown between the selection bar
-- and the icon
function UI.List(parent, opts)
    local f = CreateFrame("Frame", nil, parent)
    f.opts = opts
    f.rows, f.items, f.offset = {}, {}, 0
    local rh = opts.rowHeight or 26
    f:EnableMouseWheel(true)

    f.track = CreateFrame("Frame", nil, f)
    f.track:SetWidth(6)
    f.track:SetPoint("TOPRIGHT", -2, -2)
    f.track:SetPoint("BOTTOMRIGHT", -2, 2)
    f.thumb = CreateFrame("Button", nil, f.track)
    f.thumb:SetWidth(6)
    f.thumb.tex = UI.RoundTex(f.thumb, "OVERLAY", "line", 1)
    f.thumb.tex:SetAllPoints()
    f.thumb:SetScript("OnEnter", function(s) UI.SetTexColor(s.tex, "muted", 1) end)
    f.thumb:SetScript("OnLeave", function(s) if not s.drag then UI.SetTexColor(s.tex, "line", 1) end end)

    f.empty = UI.Text(f, 12, "dim", "CENTER")
    f.empty:SetPoint("CENTER")
    if f.empty.SetWordWrap then f.empty:SetWordWrap(true) end
    f.empty:SetWidth(260)
    -- a page may ask for a wider one (SetWidth); a narrow list keeps it inside, wrapped
    local setW = f.empty.SetWidth
    f.empty.want = 260
    function f.empty:SetWidth(w) self.want = w; setW(self, math.max(60, math.min(w, (f:GetWidth() or w) - 24))) end
    f:HookScript("OnSizeChanged", function(self) self.empty:SetWidth(self.empty.want) end)

    local function Visible()
        return math.max(1, math.floor((f:GetHeight() or rh) / rh))
    end

    local function MaxOffset()
        return math.max(0, #f.items - Visible())
    end

    local function MakeRow(i)
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(rh)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.hover = UI.RoundTex(row, "BACKGROUND", "hl", 1)
        row.hover:SetAllPoints()
        row.hover:Hide()
        row.sel = UI.RoundTex(row, "BACKGROUND", "sel", UI.SEL_A, 1)
        row.sel:SetAllPoints()
        row.sel:Hide()
        row.selBar = UI.RoundTex(row, "ARTWORK", "accent", 1, nil, "left")
        row.selBar:SetWidth(2)
        row.selBar:SetPoint("TOPLEFT")
        row.selBar:SetPoint("BOTTOMLEFT")
        row.selBar:Hide()
        row.cells = {}
        for _, c in ipairs(opts.cols or {}) do
            local cell
            if c.make then
                cell = c.make(row)
            else
                cell = UI.Text(row, c.size or 12, c.color or "text", c.justify or "LEFT")
            end
            row.cells[c.key] = cell
        end
        if opts.setup then opts.setup(row) end
        if opts.liveID then
            row.live = UI.LiveRing(row, 8)
            row.live:SetPoint("LEFT", row, "LEFT", 2, 0)
        end
        row:SetScript("OnEnter", function(self)
            self.hover:Show()
            if opts.onEnter and self.item then opts.onEnter(self, self.item) end
        end)
        row:SetScript("OnLeave", function(self)
            self.hover:Hide()
            if opts.onLeave and self.item then opts.onLeave(self, self.item) end
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(self, button)
            if opts.onClick and self.item then opts.onClick(self.item, button, self) end
        end)
        f.rows[i] = row
        return row
    end

    function f:LayoutRows()
        local w = self:GetWidth() - 10
        if opts.cols then UI.LayoutColumns(opts.cols, w) end
        for i, row in ipairs(self.rows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(i - 1) * rh)
            row:SetWidth(w)
            for _, c in ipairs(opts.cols or {}) do
                local cell = row.cells[c.key]
                cell:ClearAllPoints()
                cell:SetPoint("LEFT", row, "LEFT", c._x, 0)
                cell:SetWidth(c._w)
                if c.cellHeight then cell:SetHeight(c.cellHeight) end
            end
        end
    end

    function f:Refresh()
        local n = Visible()
        local created = false
        for i = #self.rows + 1, n do
            MakeRow(i)
            created = true
        end
        if created or self.dirtyLayout then
            self.dirtyLayout = false
            self:LayoutRows()
        end
        self.offset = math.max(0, math.min(self.offset, MaxOffset()))
        for i, row in ipairs(self.rows) do
            local idx = self.offset + i
            local item = self.items[idx]
            if i <= n and item then
                row.item, row.index = item, idx
                local sel = opts.isSelected and opts.isSelected(item)
                row.sel:SetShown(sel and true or false)
                row.selBar:SetShown(sel and true or false)
                opts.update(row, item, idx)
                if row.live then row.live:Set(FT.Scanner.LiveTick(opts.liveID(item))) end
                row:Show()
            else
                row.item = nil
                row:Hide()
            end
        end
        -- scroll bar
        local total = #self.items
        if total > n then
            self.track:Show()
            local th = self.track:GetHeight()
            local h = math.max(20, th * n / total)
            self.thumb:SetHeight(h)
            local pos = (MaxOffset() > 0) and (self.offset / MaxOffset()) * (th - h) or 0
            self.thumb:ClearAllPoints()
            self.thumb:SetPoint("TOP", self.track, "TOP", 0, -pos)
        else
            self.track:Hide()
        end
        self.empty:SetShown(total == 0 and self.emptyText ~= nil)
        if self.emptyText then self.empty:SetText(self.emptyText) end
    end

    -- the countdowns follow the searches (the circles animate by themselves; a new round restarts them)
    if opts.liveID then
        local tick = CreateFrame("Frame", nil, f)
        tick.elapsed = 0
        tick:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed < 0.3 then return end
            self.elapsed = 0
            for _, row in ipairs(f.rows) do
                if row.item and row.live and row:IsShown() then
                    row.live:Set(FT.Scanner.LiveTick(opts.liveID(row.item)))
                end
            end
        end)
    end

    function f:SetItems(items, keepOffset)
        self.items = items or {}
        if not keepOffset then self.offset = 0 end
        self:Refresh()
    end

    function f:SetEmptyText(t) self.emptyText = t end

    function f:ScrollTo(index)
        local n = Visible()
        if index <= self.offset then
            self.offset = index - 1
        elseif index > self.offset + n then
            self.offset = index - n
        end
        self:Refresh()
    end

    f:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, math.min(self.offset - delta * 3, MaxOffset()))
        self:Refresh()
    end)
    f:SetScript("OnSizeChanged", function(self)
        self.dirtyLayout = true
        self:Refresh()
    end)

    f.thumb:SetScript("OnMouseDown", function(s)
        s.drag = true
        local _, cy = GetCursorPosition()
        s.startY, s.startOffset = cy / s:GetEffectiveScale(), f.offset
        s:SetScript("OnUpdate", function()
            local _, y = GetCursorPosition()
            y = y / s:GetEffectiveScale()
            local th = f.track:GetHeight() - s:GetHeight()
            if th > 0 then
                local d = (s.startY - y) / th * MaxOffset()
                local o = math.floor(s.startOffset + d + 0.5)
                o = math.max(0, math.min(o, MaxOffset()))
                if o ~= f.offset then
                    f.offset = o
                    f:Refresh()
                end
            end
        end)
    end)
    f.thumb:SetScript("OnMouseUp", function(s)
        s.drag = false
        s:SetScript("OnUpdate", nil)
        UI.SetTexColor(s.tex, "line", 1)
    end)
    return f
end

---------------------------------------------------------------------------
-- Small pieces
---------------------------------------------------------------------------
function UI.Badge(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w or 64, h or 18)
    f.baseW = w or 64
    f.bg = UI.RoundTex(f, "BACKGROUND", "muted", 0.15)
    f.bg:SetAllPoints()
    f.text = UI.Text(f, 10, "muted", "CENTER")
    f.text:SetPoint("CENTER", 0, 0)
    function f:Set(kind, label, strength)
        local color = FT.SIGNAL_COLORS[kind] or "muted"
        UI.SetTexColor(self.bg, color, (strength and strength >= 3) and 0.30 or 0.15)
        UI.SetTextColor(self.text, color)
        if not label and strength and strength >= 3 and FT.S.meme ~= false then
            if kind == "BUY" then label = L["APE IN"] elseif kind == "HOLD" then label = L["DIAMOND HANDS"] end
        end
        self.text:SetText(label or FT.SignalText(kind))
        -- a longer word (DIAMOND HANDS, Plain English) gets smaller type to fit, never a wider badge: a wider
        -- one spilled out of its column and past the window's edge
        self:SetWidth(self.baseW)
        local room = (self.baseW or 64) - 8
        local size = UI.Size(10)
        self.text:SetFont(UI.FONT, size, "")
        while size > UI.Size(10) - 3 and (self.text:GetStringWidth() or 0) > room do
            size = size - 1
            self.text:SetFont(UI.FONT, size, "")
        end
        self.text:SetWidth(room) -- still too long: the end is cut with "..."
    end
    return f
end

function UI.Sparkline(parent, w, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, h)
    f.pool = UI.Pool(f, function(o) return UI.NewLine(o, "ARTWORK") end)
    function f:SetValues(values, color)
        self.pool:Reset()
        local n = values and #values or 0
        if n >= 2 then
            local lo, hi = math.huge, -math.huge
            for i = 1, n do
                if values[i] < lo then lo = values[i] end
                if values[i] > hi then hi = values[i] end
            end
            local W, H = self:GetWidth(), self:GetHeight()
            local span = hi - lo
            local function Y(v)
                if span <= 0 then return H / 2 end
                return 1 + (v - lo) / span * (H - 2)
            end
            local px, py = 0, Y(values[1])
            for i = 2, n do
                local x, y = (i - 1) / (n - 1) * W, Y(values[i])
                UI.PlaceLine(self.pool:Get(), px, py, x, y, 1.2, color or "muted", 0.9)
                px, py = x, y
            end
        end
        self.pool:HideRest()
    end
    return f
end

-- a metric card: small title, big value, small line under it
function UI.Stat(parent, title)
    local f = UI.Panel(parent, "bg1", "line")
    f.title = UI.Text(f, 11, "muted")
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.title:SetText(title or "")
    f.value = UI.Text(f, 16, "text")
    f.value:SetPoint("TOPLEFT", 10, -24)
    f.value:SetPoint("RIGHT", -10, 0)
    f.sub = UI.Text(f, 11, "muted")
    f.sub:SetPoint("TOPLEFT", f.value, "BOTTOMLEFT", 0, -3)
    f.sub:SetPoint("RIGHT", -10, 0)
    function f:Set(value, sub)
        self.value:SetText(value or "—")
        self.sub:SetText(sub or "")
    end
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        local cut = (self.sub.IsTruncated and self.sub:IsTruncated()) or (self.value.IsTruncated and self.value:IsTruncated())
        if cut then UI.TipText(self, self.title:GetText(), (self.value:GetText() or "") .. "\n" .. (self.sub:GetText() or "")) end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

-- section title with a thin line to the right
function UI.SectionTitle(parent, text)
    local fs = UI.Text(parent, 11, "muted")
    fs:SetText(string.upper(text or ""))
    return fs
end

-- scrolling area for long pages (settings): returns scrollFrame, content
function UI.ScrollArea(parent)
    local s = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, s)
    content:SetSize(10, 10)
    s:SetScrollChild(content)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        local maxS = math.max(0, content:GetHeight() - self:GetHeight())
        local v = math.max(0, math.min(self:GetVerticalScroll() - delta * 40, maxS))
        self:SetVerticalScroll(v)
    end)
    s:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)
    return s, content
end

-- run fn(frame, w, h) whenever the frame's size changes, and once now if it already has one (hooked: the rounded
-- corners of its fill and border follow its size too)
function UI.OnSize(frame, fn)
    frame:HookScript("OnSizeChanged", fn)
    local w, h = frame:GetWidth(), frame:GetHeight()
    if w and w > 0 and h and h > 0 then fn(frame, w, h) end
end

-- empty-state message in the middle of a panel
function UI.EmptyState(parent, title, body)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(380, 80)
    f.title = UI.Text(f, 14, "text", "CENTER")
    f.title:SetPoint("TOP", 0, 0)
    f.title:SetWidth(380)
    f.body = UI.Text(f, 12, "muted", "CENTER")
    f.body:SetPoint("TOP", f.title, "BOTTOM", 0, -8)
    f.body:SetWidth(380)
    if f.body.SetWordWrap then f.body:SetWordWrap(true) end
    function f:Set(t, b)
        self.title:SetText(t or "")
        self.body:SetText(b or "")
    end
    f:Set(title, body)
    return f
end
