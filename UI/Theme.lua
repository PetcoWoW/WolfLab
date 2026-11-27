-- Wolf: the look and the basic pieces every window uses. Two looks (Settings > General > Look, after a
-- reload): classic (the game's own auction house: its stone-and-gold dialog edges, red buttons, gold labels; the
-- default) and dark (an exchange terminal at night).
local ADDON, FT = ...

local UI = {}
FT.UI = UI

-- the colours of each look; UI.C holds the chosen one (filled in place: everything keeps its reference to it)
UI.LOOKS = {
    dark = {
        bg0 = { 0.043, 0.051, 0.063 },   -- window
        bg1 = { 0.071, 0.082, 0.102 },   -- panels
        bg2 = { 0.098, 0.114, 0.141 },   -- raised: inputs, rows on hover
        bg3 = { 0.137, 0.157, 0.192 },   -- pressed, selected
        line = { 0.157, 0.180, 0.220 },  -- borders and grid
        text = { 0.918, 0.925, 0.937 },
        muted = { 0.600, 0.635, 0.690 },
        dim = { 0.455, 0.490, 0.545 },
        up = { 0.055, 0.796, 0.506 },
        down = { 0.965, 0.275, 0.365 },
        accent = { 0.941, 0.725, 0.043 },
        blue = { 0.231, 0.510, 0.965 },
        purple = { 0.655, 0.545, 0.980 },
        black = { 0, 0, 0 },
        -- a row under the mouse, a chosen row (with its alpha: UI.SEL_A)
        hl = { 0.098, 0.114, 0.141 },
        sel = { 0.941, 0.725, 0.043 },
    },
    -- the game's own: white values, gold labels (GameFontNormal), its green and red, dark leather behind
    classic = {
        bg0 = { 0.055, 0.043, 0.031 },
        bg1 = { 0.078, 0.060, 0.040 },
        bg2 = { 0.130, 0.100, 0.064 },
        bg3 = { 0.215, 0.165, 0.098 },
        line = { 0.470, 0.385, 0.215 },
        text = { 1, 1, 1 },
        muted = { 0.875, 0.745, 0.420 },
        dim = { 0.580, 0.550, 0.500 },
        up = { 0.120, 1, 0.120 },
        down = { 1, 0.240, 0.240 },
        accent = { 1, 0.820, 0 },
        blue = { 0.300, 0.620, 1 },
        purple = { 0.640, 0.210, 0.930 },
        black = { 0, 0, 0 },
        hl = { 0.300, 0.235, 0.110 },
        sel = { 1, 0.820, 0 },
    },
}
UI.C = {}
for k, v in pairs(UI.LOOKS.dark) do UI.C[k] = { v[1], v[2], v[3] } end
local C = UI.C
UI.SEL_A = 0.07

UI.theme = "dark"
UI.INSET = 1 -- how far the window's content keeps from its edge

-- the game's own look (Settings > General > Look)
function UI.Classic()
    return UI.theme == "classic"
end

-- the height of a control when none is given
UI.H, UI.HS = 24, 20
function UI.ControlH(h)
    return h or UI.H
end

-- A faint tint (a chosen row, a badge, a tinted button) shows on a dark background; on white it is gone: the light
-- style makes it stronger
function UI.Alpha(a)
    if UI.theme == "light" and a and a > 0 and a < 0.35 then return math.min(0.4, a * 2.2) end
    return a
end

local function Hex(c)
    return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

-- once, when the saved settings are known, before any window is built
function UI.ApplyTheme()
    UI.theme = (FT.S and FT.S.look == "dark") and "dark" or "classic"
    local look = UI.LOOKS[UI.theme]
    for k, v in pairs(look) do
        local c = C[k] or {}
        c[1], c[2], c[3] = v[1], v[2], v[3]
        C[k] = c
    end
    local classic = UI.Classic()
    -- the dialog edge is wider than a 1px line; the game's corners are square
    UI.INSET = classic and 8 or 1
    UI.RADIUS = classic and 0 or 3
    UI.SEL_A = classic and 0.14 or 0.07
    -- the colours of coloured text follow
    for k in pairs(FT.HEX) do
        if C[k] then FT.HEX[k] = Hex(C[k]) end
    end
end
FT.On("FT_DB_READY", function() UI.ApplyTheme() end)

function UI.RGB(name)
    local c = C[name] or C.text
    return c[1], c[2], c[3]
end

---------------------------------------------------------------------------
-- Font (Settings > General): the game's own Friz Quadrata (the default: wide and easy to read) or Sofia Sans
-- Condensed Medium (media/, SIL Open Font License: SofiaSansCondensed-OFL.txt), narrow - more fits in a row.
-- Should the chosen one not load (new files show only after the game is restarted): the other, then Arial Narrow.
---------------------------------------------------------------------------
UI.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local OWN_FONT = "Interface\\AddOns\\" .. ADDON .. "\\media\\SofiaSansCondensed-Medium.ttf"
local GAME_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

function UI.ResolveFont()
    if UI.fontResolved then return end
    UI.fontResolved = true
    local candidates = {}
    if FT.S and FT.S.font == "condensed" then
        candidates = { OWN_FONT, GAME_FONT }
    else
        candidates = { GAME_FONT, OWN_FONT }
    end
    candidates[#candidates + 1] = "Fonts\\ARIALN.TTF"
    for _, path in ipairs(candidates) do
        -- a new font string each time: one that didn't take its font has none (one that did tells it)
        local probe = UIParent:CreateFontString(nil, "OVERLAY")
        local ok, res = pcall(probe.SetFont, probe, path, 12, "")
        local got = ok and probe:GetFont()
        probe:Hide()
        if ok and res ~= false and got then
            UI.FONT = path
            break
        end
    end
end

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------
function UI.Tex(parent, layer, color, alpha, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
    local c = type(color) == "table" and color or C[color or "bg1"]
    t:SetColorTexture(c[1], c[2], c[3], UI.Alpha(alpha or 1))
    return t
end

function UI.SetTexColor(tex, color, alpha)
    local c = type(color) == "table" and color or C[color] or C.text
    if tex.isRound then
        tex:SetColor(c, alpha)
    elseif tex.tinted then
        tex:SetVertexColor(c[1], c[2], c[3], UI.Alpha(alpha or 1))
    else
        tex:SetColorTexture(c[1], c[2], c[3], UI.Alpha(alpha or 1))
    end
end

---------------------------------------------------------------------------
-- Slightly rounded corners (in the classic style too: its windows and panels keep the game's edges, the rounded
-- fill hides under them). A rounded rectangle is its
-- rounded corners - quarters of a disc (media\round.tga) - and up to three bands between them; a rounded border
-- is quarters of a ring (media\ringN.tga: 1 wide at radius N) and four lines. The radius shrinks to fit a small
-- rectangle. corners: "all" (the default), "top", "bottom", "left", "right", "none" (square).
---------------------------------------------------------------------------
UI.RADIUS = 3
local WHITE = "Interface\\Buttons\\WHITE8X8"
local DISC = FT.MEDIA .. "round.tga"
local QUARTER = {
    TOPLEFT = { 0, 0.5, 0, 0.5 }, TOPRIGHT = { 0.5, 1, 0, 0.5 },
    BOTTOMLEFT = { 0, 0.5, 0.5, 1 }, BOTTOMRIGHT = { 0.5, 1, 0.5, 1 },
}
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local SETS = {
    all = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
    top = { TOPLEFT = true, TOPRIGHT = true }, bottom = { BOTTOMLEFT = true, BOTTOMRIGHT = true },
    left = { TOPLEFT = true, BOTTOMLEFT = true }, right = { TOPRIGHT = true, BOTTOMRIGHT = true },
}

function UI.Rounded()
    return UI.RADIUS > 0
end

local function Ring(r)
    if r <= 1 then return DISC end
    return FT.MEDIA .. "ring" .. math.min(r, 6) .. ".tga"
end

-- the radius of a rectangle w x h with these corners rounded (two rounded corners on a side share it)
local function Fit(set, w, h, want)
    local r = want or UI.RADIUS
    local cols = ((set.TOPLEFT or set.BOTTOMLEFT) and 1 or 0) + ((set.TOPRIGHT or set.BOTTOMRIGHT) and 1 or 0)
    local rows = ((set.TOPLEFT or set.TOPRIGHT) and 1 or 0) + ((set.BOTTOMLEFT or set.BOTTOMRIGHT) and 1 or 0)
    if w and w > 0 and cols > 0 then r = math.min(r, math.floor(w / cols)) end
    if h and h > 0 and rows > 0 then r = math.min(r, math.floor(h / rows)) end
    return math.max(0, r)
end

-- a rounded rectangle: used like a texture (points, shown, colour through UI.SetTexColor)
local Round = {}
Round.__index = Round

function Round:Layout()
    local b, s = self.base, self.set
    local r = Fit(s, b:GetWidth(), b:GetHeight(), self.want)
    if r == self.r then return end
    self.r = r
    local tl, tr = s.TOPLEFT and r or 0, s.TOPRIGHT and r or 0
    local bl, br = s.BOTTOMLEFT and r or 0, s.BOTTOMRIGHT and r or 0
    local top, bottom = math.max(tl, tr), math.max(bl, br)
    for _, t in pairs(self.corners) do
        if r > 0 then t:SetSize(r, r) end
        self.vis[t] = r > 0
    end
    self.top:ClearAllPoints()
    self.top:SetPoint("TOPLEFT", b, "TOPLEFT", tl, 0)
    self.top:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", -tr, -top)
    self.vis[self.top] = top > 0
    self.bottom:ClearAllPoints()
    self.bottom:SetPoint("TOPLEFT", b, "BOTTOMLEFT", bl, bottom)
    self.bottom:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -br, 0)
    self.vis[self.bottom] = bottom > 0
    self.mid:ClearAllPoints()
    self.mid:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -top)
    self.mid:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, bottom)
    self:SetShown(self.shown)
end

-- its place changed: laid out now, and again once the game has placed it
function Round:Relayout()
    self.r = nil
    self:Layout()
    C_Timer.After(0, function()
        self.r = nil
        self:Layout()
    end)
end

function Round:SetColor(color, alpha)
    local c = type(color) == "table" and color or C[color] or C.text
    alpha = UI.Alpha(alpha or 1)
    for _, t in ipairs(self.parts) do t:SetVertexColor(c[1], c[2], c[3], alpha) end
end
function Round:SetColorTexture(r, g, b, a) self:SetColor({ r, g, b }, a) end
function Round:SetVertexColor(r, g, b, a) self:SetColor({ r, g, b }, a) end
-- (never an explicit nil to the game: SetAllPoints(nil) is the whole screen, not the parent)
function Round:SetAllPoints(rel)
    self.base:SetAllPoints(rel or self.parent)
    self:Relayout()
end
function Round:SetPoint(...)
    self.base:SetPoint(...)
    self:Relayout()
end
function Round:ClearAllPoints() self.base:ClearAllPoints() end
function Round:SetSize(w, h)
    self.base:SetSize(w, h)
    self:Relayout()
end
function Round:SetWidth(w)
    self.base:SetWidth(w)
    self:Relayout()
end
function Round:SetHeight(h)
    self.base:SetHeight(h)
    self:Relayout()
end
function Round:GetWidth() return self.base:GetWidth() end
function Round:GetHeight() return self.base:GetHeight() end
function Round:SetShown(on)
    self.shown = on and true or false
    for _, t in ipairs(self.parts) do t:SetShown(self.shown and self.vis[t] ~= false) end
end
function Round:Show() self:SetShown(true) end
function Round:Hide() self:SetShown(false) end
function Round:IsShown() return self.shown end
function Round:IsVisible() return self.shown and self.base:IsVisible() end
function Round:SetAlpha(a)
    for _, t in ipairs(self.parts) do t:SetAlpha(a) end
end
function Round:SetDrawLayer(layer, sub)
    self.base:SetDrawLayer(layer, sub)
    for _, t in ipairs(self.parts) do t:SetDrawLayer(layer, sub) end
end

-- like UI.Tex, slightly rounded (radius: `radius`, else UI.RADIUS); square in the classic style or with "none"
function UI.RoundTex(parent, layer, color, alpha, sub, corners, radius)
    local set = SETS[corners or "all"]
    if not (UI.Rounded() and set) then return UI.Tex(parent, layer, color, alpha, sub) end
    local o = setmetatable({ isRound = true, parent = parent, set = set, want = radius, parts = {}, corners = {},
        vis = {}, shown = true }, Round)
    layer = layer or "ARTWORK"
    -- the rectangle itself: where the pieces go (never drawn)
    o.base = parent:CreateTexture(nil, layer, nil, sub)
    o.base:SetColorTexture(0, 0, 0, 0)
    local function Piece(file)
        local t = parent:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(file)
        o.parts[#o.parts + 1] = t
        return t
    end
    for _, key in ipairs(CORNERS) do
        if set[key] then
            local t = Piece(DISC)
            t:SetTexCoord(unpack(QUARTER[key]))
            t:SetPoint(key, o.base, key)
            o.corners[key] = t
        end
    end
    o.top, o.bottom, o.mid = Piece(WHITE), Piece(WHITE), Piece(WHITE)
    o:SetColor(color or "bg1", alpha)
    -- the frame it fills changes size: the radius follows
    if parent.HookScript then parent:HookScript("OnSizeChanged", function() o:Layout() end) end
    return o
end

-- a small round dot (a status light)
function UI.Dot(parent, size, color, alpha, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(DISC)
    t:SetSize(size or 7, size or 7)
    t.tinted = true
    UI.SetTexColor(t, color or "dim", alpha)
    return t
end

-- vertical or horizontal fade from (color, a1) to (color, a2)
function UI.Gradient(tex, orientation, color, a1, a2, color2)
    local c1 = type(color) == "table" and color or C[color]
    local c2 = color2 and (type(color2) == "table" and color2 or C[color2]) or c1
    tex:SetColorTexture(1, 1, 1, 1)
    if CreateColor and tex.SetGradient then
        local ok = pcall(tex.SetGradient, tex, orientation, CreateColor(c1[1], c1[2], c1[3], a1),
            CreateColor(c2[1], c2[2], c2[3], a2))
        if ok then return end
    end
    if tex.SetGradientAlpha then
        local ok = pcall(tex.SetGradientAlpha, tex, orientation, c1[1], c1[2], c1[3], a1, c2[1], c2[2], c2[3], a2)
        if ok then return end
    end
    tex:SetColorTexture(c1[1], c1[2], c1[3], (a1 + a2) / 2)
end

-- the classic look: the window's stone shows through the page (bg0) and, darkened, through its panels (bg1)
local CLASSIC_FILL = { bg0 = 0.2, bg1 = 0.6 }

function UI.Fill(frame, color, alpha, corners, radius)
    if UI.Classic() and CLASSIC_FILL[color or "bg1"] then alpha = (alpha or 1) * CLASSIC_FILL[color or "bg1"] end
    local t = UI.RoundTex(frame, "BACKGROUND", color, alpha, -8, corners, radius)
    t:SetAllPoints()
    frame.bg = t
    return t
end

-- 1px border, slightly rounded (see UI.RoundTex; "none": square)
function UI.Border(frame, color, alpha, corners, radius)
    local set = SETS[corners or "all"]
    if UI.Rounded() and set then
        local lines, rings, all = {}, {}, {}
        for i = 1, 4 do
            lines[i] = frame:CreateTexture(nil, "BORDER")
            lines[i]:SetTexture(WHITE)
            all[#all + 1] = lines[i]
        end
        for _, key in ipairs(CORNERS) do
            if set[key] then
                rings[key] = frame:CreateTexture(nil, "BORDER")
                all[#all + 1] = rings[key]
            end
        end
        local lastR
        local function Layout()
            local r = Fit(set, frame:GetWidth(), frame:GetHeight(), radius)
            if r == lastR then return end
            lastR = r
            local tl, tr = set.TOPLEFT and r or 0, set.TOPRIGHT and r or 0
            local bl, br = set.BOTTOMLEFT and r or 0, set.BOTTOMRIGHT and r or 0
            local top, bottom, left, right = lines[1], lines[2], lines[3], lines[4]
            top:ClearAllPoints(); top:SetPoint("TOPLEFT", tl, 0); top:SetPoint("TOPRIGHT", -tr, 0); top:SetHeight(1)
            bottom:ClearAllPoints(); bottom:SetPoint("BOTTOMLEFT", bl, 0); bottom:SetPoint("BOTTOMRIGHT", -br, 0); bottom:SetHeight(1)
            left:ClearAllPoints(); left:SetPoint("TOPLEFT", 0, -tl); left:SetPoint("BOTTOMLEFT", 0, bl); left:SetWidth(1)
            right:ClearAllPoints(); right:SetPoint("TOPRIGHT", 0, -tr); right:SetPoint("BOTTOMRIGHT", 0, br); right:SetWidth(1)
            for key, t in pairs(rings) do
                t:SetTexture(Ring(r))
                t:SetTexCoord(unpack(QUARTER[key]))
                t:ClearAllPoints()
                t:SetPoint(key)
                if r > 0 then t:SetSize(r, r) end
                t:SetShown(r > 0)
            end
        end
        frame.border = all
        function frame:SetBorderColor(c, a)
            local cc = type(c) == "table" and c or C[c] or C.line
            a = UI.Alpha(a or 1)
            for _, t in ipairs(all) do t:SetVertexColor(cc[1], cc[2], cc[3], a) end
        end
        frame:SetBorderColor(color or "line", alpha or 1)
        Layout()
        if frame.HookScript then frame:HookScript("OnSizeChanged", Layout) end
        C_Timer.After(0, function()
            lastR = nil
            Layout()
        end)
        return all
    end
    local b = {}
    for i = 1, 4 do b[i] = UI.Tex(frame, "BORDER", color or "line", alpha or 1) end
    b[1]:SetPoint("TOPLEFT"); b[1]:SetPoint("TOPRIGHT"); b[1]:SetHeight(1)
    b[2]:SetPoint("BOTTOMLEFT"); b[2]:SetPoint("BOTTOMRIGHT"); b[2]:SetHeight(1)
    b[3]:SetPoint("TOPLEFT"); b[3]:SetPoint("BOTTOMLEFT"); b[3]:SetWidth(1)
    b[4]:SetPoint("TOPRIGHT"); b[4]:SetPoint("BOTTOMRIGHT"); b[4]:SetWidth(1)
    frame.border = b
    function frame:SetBorderColor(c, a)
        for i = 1, 4 do UI.SetTexColor(b[i], c, a) end
    end
    return b
end

---------------------------------------------------------------------------
-- The classic look's edges: the game's own dialog (stone and gold) and tooltip edges, drawn with a backdrop
---------------------------------------------------------------------------
local TIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local CLASSIC_EDGE = { edgeFile = TIP_EDGE, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }
local DIALOG = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } }
local POPUP = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = TIP_EDGE,
    tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } }
-- the edges' tint: the dialog's own colours; the tooltip edge goes gold, like the auction house's inner frames
local EDGE_GOLD = { 0.85, 0.70, 0.40 }
UI.EDGE_GOLD = EDGE_GOLD

-- a backdrop on any frame (newer clients: through BackdropTemplateMixin); false when the client can't
local function Backdrop(f, def)
    if not f.SetBackdrop then
        if not (BackdropTemplateMixin and Mixin) then return false end
        Mixin(f, BackdropTemplateMixin)
        if f.OnBackdropSizeChanged and f.HookScript then f:HookScript("OnSizeChanged", f.OnBackdropSizeChanged) end
    end
    return (pcall(f.SetBackdrop, f, def))
end
UI.Backdrop = Backdrop

local function EdgeColorFn(f)
    function f:SetBorderColor(col, a)
        local cc = type(col) == "table" and col or C[col] or EDGE_GOLD
        if col == "line" then cc = EDGE_GOLD end
        self:SetBackdropBorderColor(cc[1], cc[2], cc[3], a or 1)
    end
end

-- frame with the classic look's thin gold edge; false when the look or the client doesn't do it
function UI.ClassicEdge(f, color, edge)
    if not UI.Classic() then return false end
    if not Backdrop(f, edge or CLASSIC_EDGE) then return false end
    EdgeColorFn(f)
    f:SetBorderColor(color or "line", 1)
    return true
end

-- a template that can carry the classic look's edge
function UI.EdgeTemplate()
    return (UI.Classic() and BackdropTemplateMixin) and "BackdropTemplate" or nil
end

-- The outside of a frame of its own (not inside another window). kind: "window" (the game's dialog: stone inside,
-- the stone-and-gold edge) or "popup" (a menu, a toast, a small panel: the tooltip's dark inside and edge).
-- The dark look: a fill (color, alpha) and a 1px border (border). Returns the inset of its content.
function UI.Skin(f, kind, color, alpha, border)
    if UI.Classic() then
        local def = kind == "window" and DIALOG or POPUP
        if Backdrop(f, def) then
            EdgeColorFn(f)
            if kind == "window" then
                -- warm, like the auction house's leather; the gold edge as the game draws it
                f:SetBackdropColor(0.92, 0.82, 0.68, 1)
                f:SetBackdropBorderColor(1, 1, 1, 1)
                function f:SetBorderColor() end
            else
                f:SetBackdropColor(0.045, 0.035, 0.025, math.max(0.9, alpha or 1))
                f:SetBorderColor("line", 1)
            end
            -- the fill some code repaints: under the edge, nearly clear
            local inset = def.insets.left
            f.bg = UI.Tex(f, "BACKGROUND", "bg0", kind == "window" and 0.15 or 0, -8)
            f.bg:SetPoint("TOPLEFT", inset, -inset)
            f.bg:SetPoint("BOTTOMRIGHT", -inset, inset)
            f.skinned = kind
            return inset
        end
    end
    UI.Fill(f, color or "bg1", alpha)
    if border ~= false then UI.Border(f, border or "line") end
    return 1
end

-- the classic look: the game's dialog title banner over the top edge, with a gold title; nil in the dark look
local HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header"
function UI.TitleBanner(f, text, size)
    if not UI.Classic() then return nil end
    local b = CreateFrame("Frame", nil, f)
    b:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
    b.text = UI.Text(b, size or 13, "accent", "CENTER")
    b.text:SetPoint("CENTER", 0, -1)
    local left = b:CreateTexture(nil, "ARTWORK")
    left:SetTexture(HEADER)
    left:SetTexCoord(0.2265625, 0.31640625, 0, 0.640625)
    left:SetSize(23, 41)
    local right = b:CreateTexture(nil, "ARTWORK")
    right:SetTexture(HEADER)
    right:SetTexCoord(0.68359375, 0.7734375, 0, 0.640625)
    right:SetSize(23, 41)
    local mid = b:CreateTexture(nil, "ARTWORK")
    mid:SetTexture(HEADER)
    mid:SetTexCoord(0.31640625, 0.68359375, 0, 0.640625)
    mid:SetHeight(41)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    left:SetPoint("TOPLEFT")
    right:SetPoint("TOPRIGHT")
    function b:SetTitle(t)
        self.text:SetText(t or "")
        self:SetSize(math.max(120, math.ceil(self.text:GetStringWidth()) + 70), 41)
    end
    b:SetPoint("BOTTOM", f, "TOP", 0, -16)
    b:SetTitle(text)
    return b
end

-- the classic look: the game's input box edge (InputBoxTemplate's three pieces) on an edit box; false otherwise
local INPUT = "Interface\\Common\\Common-Input-Border"
function UI.InputEdge(e)
    if not UI.Classic() then return false end
    local l = e:CreateTexture(nil, "BACKGROUND")
    local r = e:CreateTexture(nil, "BACKGROUND")
    local m = e:CreateTexture(nil, "BACKGROUND")
    for _, t in ipairs({ l, r, m }) do t:SetTexture(INPUT) end
    l:SetTexCoord(0, 0.0625, 0, 0.625)
    r:SetTexCoord(0.9375, 1, 0, 0.625)
    m:SetTexCoord(0.0625, 0.9375, 0, 0.625)
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(8)
    r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(8)
    m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    -- a dark inside under the edge: the text reads on any page
    e.bg = UI.Tex(e, "BACKGROUND", "black", 0.55, -8)
    e.bg:SetPoint("TOPLEFT", 3, -3)
    e.bg:SetPoint("BOTTOMRIGHT", -3, 3)
    local parts = { l, r, m }
    function e:SetBorderColor(col)
        local lit = col == "accent"
        for _, t in ipairs(parts) do
            if lit then t:SetVertexColor(1, 0.9, 0.6, 1) else t:SetVertexColor(1, 1, 1, 1) end
        end
    end
    return true
end

-- the classic look: the game's check box (its box and gold tick); false otherwise
function UI.CheckArt(box)
    if not UI.Classic() then return false end
    local t = box:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    t:SetSize(24, 24)
    t:SetPoint("CENTER")
    local tick = box:CreateTexture(nil, "OVERLAY")
    tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    tick:SetSize(24, 24)
    tick:SetPoint("CENTER")
    local lit = box:CreateTexture(nil, "OVERLAY")
    lit:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    lit:SetBlendMode("ADD")
    lit:SetSize(24, 24)
    lit:SetPoint("CENTER")
    box.art, box.tick, box.lit = t, tick, lit
    function box:SetBorderColor(col)
        if col == "muted" then self.lit:Show() else self.lit:Hide() end
    end
    lit:Hide()
    return true
end

-- construction tape: gold and black blocks across its width (redrawn when it changes size)
function UI.HazardTape(parent, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(h or 8)
    f.blocks = {}
    local function Draw(self)
        local w = math.max(0, self:GetWidth() or 0)
        local bw, n = 14, 0
        local x = 0
        while x < w do
            n = n + 1
            local t = self.blocks[n]
            if not t then
                t = self:CreateTexture(nil, "ARTWORK")
                self.blocks[n] = t
            end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", x, 0)
            t:SetPoint("BOTTOMLEFT", x, 0)
            t:SetWidth(math.min(bw, w - x))
            if n % 2 == 1 then t:SetColorTexture(1, 0.78, 0.05, 1) else t:SetColorTexture(0.06, 0.05, 0.04, 1) end
            t:Show()
            x = x + bw
        end
        for i = n + 1, #self.blocks do self.blocks[i]:Hide() end
    end
    f:SetScript("OnSizeChanged", Draw)
    f:SetScript("OnShow", Draw)
    return f
end

-- a round portrait (the game's portrait mask) with the gold ring the minimap buttons have
function UI.Portrait(parent, size, icon)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexture(icon)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if f.CreateMaskTexture then
        local mask = f:CreateMaskTexture()
        mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(f.tex)
        if f.tex.AddMaskTexture then f.tex:AddMaskTexture(mask) end
    end
    local ring = f:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    -- as on a minimap button: a 20px icon in a 31px button, the ring 53px from the button's top left
    ring:SetSize(size * 2.65, size * 2.65)
    ring:SetPoint("TOPLEFT", -size * 0.275, size * 0.275)
    function f:SetIcon(i) self.tex:SetTexture(i) end
    f.SetItem = function(self, itemID)
        local _, _, ic = FT.Item(itemID)
        self.tex:SetTexture(ic or 134400)
    end
    return f
end

-- a filled frame with a border (border false: none), slightly rounded
function UI.Panel(parent, color, border)
    local f = CreateFrame("Frame", nil, parent, border ~= false and UI.EdgeTemplate() or nil)
    UI.Fill(f, color or "bg1")
    if border ~= false then
        if UI.ClassicEdge(f, border or "line") then
            -- the fill inside the edge
            f.bg:ClearAllPoints()
            f.bg:SetPoint("TOPLEFT", 3, -3)
            f.bg:SetPoint("BOTTOMRIGHT", -3, 3)
        else
            UI.Border(f, border or "line")
        end
    end
    return f
end

-- horizontal / vertical 1px line
function UI.HLine(parent, color, alpha)
    local t = UI.Tex(parent, "BORDER", color or "line", alpha or 1)
    t:SetHeight(1)
    return t
end

function UI.VLine(parent, color, alpha)
    local t = UI.Tex(parent, "BORDER", color or "line", alpha or 1)
    t:SetWidth(1)
    return t
end

-- a text's size with the Text size setting added (Settings > General)
function UI.Size(size)
    local bump = FT.S and tonumber(FT.S.textSize) or 0
    return (size or 12) + bump
end

-- A line of "a · b · c" (or "a || b") that keeps only the parts that fit whole, instead of cutting the last one with "...";
-- again when its frame changes size
local function Fit(fs)
    local text = fs.fitText or ""
    fs:SetText(text)
    local w = fs:GetWidth()
    if not w or w <= 0 or (fs:GetStringWidth() or 0) <= w + 0.5 then return end
    -- the places it can end: before each " · " or " || " (from the last one back)
    local cuts = {}
    for _, sep in ipairs({ "·", "||" }) do
        local from = 1
        while true do
            local a = text:find(sep, from, true)
            if not a then break end
            cuts[#cuts + 1] = a
            from = a + #sep
        end
    end
    table.sort(cuts)
    for k = #cuts, 1, -1 do
        local part = text:sub(1, cuts[k] - 1):gsub("|c%x%x%x%x%x%x%x%x%s*$", ""):gsub("%s+$", "")
        fs:SetText(part)
        if (fs:GetStringWidth() or 0) <= w + 0.5 then return end
    end
end

function UI.FitBits(fs, text)
    fs.fitText = text or ""
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    if not fs.fitHooked then
        fs.fitHooked = true
        local p = fs:GetParent()
        if p and p.HookScript then p:HookScript("OnSizeChanged", function() if fs.fitText then Fit(fs) end end) end
    end
    Fit(fs)
end

-- A text that shrinks (up to `less` points, 2 by default) before it would be cut short: a name in a narrow column
function UI.FitSize(fs, text, size, less)
    local full = UI.Size(size or 12)
    fs:SetFont(UI.FONT, full, "")
    fs:SetText(text or "")
    local w = fs:GetWidth()
    if not w or w <= 0 then return end
    for s = full - 1, full - (less or 2), -1 do
        if (fs:GetStringWidth() or 0) <= w + 0.5 then return end
        fs:SetFont(UI.FONT, s, "")
    end
end

-- a two-line row's height: a little more with the larger text sizes
function UI.RowH(base)
    return base + 3 * (FT.S and tonumber(FT.S.textSize) or 0)
end

function UI.Text(parent, size, color, justify, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(UI.FONT, UI.Size(size), "")
    local c = type(color) == "table" and color or C[color or "text"]
    fs:SetTextColor(c[1], c[2], c[3], 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetShadowColor(0, 0, 0, UI.Classic() and 1 or 0.6)
    -- a dark shadow only reads well on a dark background
    if UI.theme == "light" then fs:SetShadowOffset(0, 0) else fs:SetShadowOffset(1, -1) end
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

function UI.SetTextColor(fs, color)
    local c = type(color) == "table" and color or C[color] or C.text
    fs:SetTextColor(c[1], c[2], c[3], 1)
end

-- item icon with a thin dark frame and the inner 8% of the art (the game's icons have a border baked in)
function UI.Icon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local bg = UI.Tex(f, "BACKGROUND", "black", 0.6)
    bg:SetAllPoints()
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    function f:SetItem(itemID)
        local _, _, icon = FT.Item(itemID)
        self.tex:SetTexture(icon or 134400)
    end
    function f:SetIcon(icon)
        self.tex:SetTexture(icon or 134400)
    end
    return f
end

-- a line between two points of a frame (CreateLine where the client has it, else a dotted trail)
function UI.NewLine(parent, layer)
    if parent.CreateLine then
        local l = parent:CreateLine(nil, layer or "ARTWORK")
        l.isLine = true
        l.owner = parent
        return l
    end
    return { parent = parent, dots = {}, layer = layer, isLine = false }
end

function UI.PlaceLine(l, x1, y1, x2, y2, thickness, color, alpha)
    local c = type(color) == "table" and color or C[color] or C.text
    if l.isLine then
        l:SetStartPoint("BOTTOMLEFT", l.owner, x1, y1)
        l:SetEndPoint("BOTTOMLEFT", l.owner, x2, y2)
        l:SetThickness(thickness or 1)
        l:SetColorTexture(c[1], c[2], c[3], alpha or 1)
        l:Show()
        return
    end
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local n = math.max(1, math.floor(len / 2))
    for i = 1, n do
        local d = l.dots[i]
        if not d then
            d = l.parent:CreateTexture(nil, l.layer or "ARTWORK")
            l.dots[i] = d
        end
        d:SetColorTexture(c[1], c[2], c[3], alpha or 1)
        d:SetSize(thickness or 1, thickness or 1)
        d:ClearAllPoints()
        d:SetPoint("CENTER", l.parent, "BOTTOMLEFT", x1 + dx * i / n, y1 + dy * i / n)
        d:Show()
    end
    for i = n + 1, #l.dots do l.dots[i]:Hide() end
end

function UI.HideLine(l)
    if l.isLine then
        l:Hide()
    else
        for _, d in ipairs(l.dots) do d:Hide() end
    end
end

-- a small chevron of two lines ("down", "up", "right", "left")
function UI.Chevron(parent, size, color)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size or 8, size or 8)
    f.a, f.b = UI.NewLine(f, "OVERLAY"), UI.NewLine(f, "OVERLAY")
    function f:SetDir(dir, c)
        local s = self:GetWidth()
        local h = s / 2
        c = c or color or "muted"
        if dir == "up" then
            UI.PlaceLine(self.a, 0, h * 0.5, h, h * 1.5, 1.5, c)
            UI.PlaceLine(self.b, h, h * 1.5, s, h * 0.5, 1.5, c)
        elseif dir == "right" then
            UI.PlaceLine(self.a, h * 0.5, s, h * 1.5, h, 1.5, c)
            UI.PlaceLine(self.b, h * 1.5, h, h * 0.5, 0, 1.5, c)
        elseif dir == "left" then
            UI.PlaceLine(self.a, h * 1.5, s, h * 0.5, h, 1.5, c)
            UI.PlaceLine(self.b, h * 0.5, h, h * 1.5, 0, 1.5, c)
        else
            UI.PlaceLine(self.a, 0, h * 1.5, h, h * 0.5, 1.5, c)
            UI.PlaceLine(self.b, h, h * 0.5, s, h * 1.5, 1.5, c)
        end
    end
    f:SetDir("down")
    return f
end

-- a gear drawn with lines (Settings), in the style's colours: a ring and eight teeth
function UI.Gear(parent, size, color)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.lines = {}
    function f:SetColor(c, alpha)
        local s = self:GetWidth()
        local cx, cy = s / 2, s / 2
        local ring, tip = s * 0.27, s * 0.47
        local i = 0
        local function Line(x1, y1, x2, y2, w)
            i = i + 1
            local l = self.lines[i]
            if not l then
                l = UI.NewLine(self, "OVERLAY")
                self.lines[i] = l
            end
            UI.PlaceLine(l, x1, y1, x2, y2, w, c, alpha or 1)
        end
        local n = 18
        for k = 0, n - 1 do
            local a1, a2 = k / n * 2 * math.pi, (k + 1) / n * 2 * math.pi
            Line(cx + ring * math.cos(a1), cy + ring * math.sin(a1), cx + ring * math.cos(a2), cy + ring * math.sin(a2), s * 0.13)
        end
        for k = 0, 7 do
            local a = (k + 0.5) / 8 * 2 * math.pi
            Line(cx + ring * math.cos(a), cy + ring * math.sin(a), cx + tip * math.cos(a), cy + tip * math.sin(a), s * 0.17)
        end
    end
    f:SetColor(color or "muted")
    return f
end

-- pool of textures / font strings / lines that a widget redraws often
function UI.Pool(owner, make)
    local pool = { items = {}, used = 0 }
    function pool:Get()
        self.used = self.used + 1
        local it = self.items[self.used]
        if not it then
            it = make(owner)
            self.items[self.used] = it
        end
        return it
    end
    function pool:Reset()
        self.used = 0
    end
    function pool:HideRest()
        for i = self.used + 1, #self.items do
            local it = self.items[i]
            if it.isLine == false then UI.HideLine(it) else it:Hide() end
        end
    end
    return pool
end
