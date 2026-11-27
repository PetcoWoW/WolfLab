-- The test mock's layout: where every frame and text would sit on a 1920x1080 screen, from their anchors, sizes and
-- an estimate of how wide the game draws each text. Then: texts that draw over each other. The game's own fonts
-- aren't here, so widths are estimates (a little generous): it finds real collisions, and now and then a near miss.
local Frame = getmetatable(UIParent)
local methods = setmetatable({}, { __index = function(_, k) return Frame.__index(UIParent, k) end })

-- every object knows its children (to walk a window)
local newObj = mock.newObj
local function kids(p) if not p then return nil end p.__kids = p.__kids or {} return p.__kids end
local CF = CreateFrame
CreateFrame = function(kind, name, parent, template)
    local f = CF(kind, name, parent, template)
    -- no parent: the game puts it on the screen itself
    local k = kids(parent or UIParent); if k then k[#k + 1] = f end
    return f
end
local M = {}
mock.layout = M
local idx = Frame.__index
Frame.__index = function(self, k)
    local own = M[k]
    if own then return own end
    return idx(self, k)
end

M.CreateFontString = function(self, name)
    local fs = newObj("FontString", name, self)
    local k = kids(self); k[#k + 1] = fs
    return fs
end
M.GetFontString = function(self)
    if not self.__fs then
        self.__fs = newObj("FontString", nil, self)
        local k = kids(self); k[#k + 1] = self.__fs
        self.__fs.__anch = { CENTER = { point = "CENTER", rel = self, relPoint = "CENTER", x = 0, y = 0 } }
        self.__fs.__justify = "CENTER"
    end
    return self.__fs
end
M.SetParent = function(self, p)
    local old = self.__parent
    if old and old.__kids then
        for i, c in ipairs(old.__kids) do if c == self then table.remove(old.__kids, i) break end end
    end
    self.__parent = p
    local k = kids(p); if k then k[#k + 1] = self end
end

local function pointArgs(self, point, a, b, c, d)
    local rel, relPoint, x, y
    if type(a) == "number" then x, y = a, b
    elseif a == nil and b == nil then
    else
        rel = a
        if type(b) == "number" then relPoint, x, y = point, b, c
        else relPoint, x, y = b or point, c, d end
    end
    if type(rel) == "string" then rel = _G[rel] end
    return { point = point, rel = rel, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end
M.SetPoint = function(self, point, a, b, c, d)
    self.__points = (self.__points or 0) + 1
    self.__anch = self.__anch or {}
    local p = pointArgs(self, point, a, b, c, d)
    self.__anch[point] = p
end
M.ClearAllPoints = function(self) self.__points = 0; self.__anch = {} end
M.SetAllPoints = function(self, rel)
    self.__points = 2
    self.__anch = { TOPLEFT = { point = "TOPLEFT", rel = rel, relPoint = "TOPLEFT", x = 0, y = 0 },
        BOTTOMRIGHT = { point = "BOTTOMRIGHT", rel = rel, relPoint = "BOTTOMRIGHT", x = 0, y = 0 } }
end
M.SetWidth = function(self, w) self.__w = w; self.__wSet = true end
M.SetHeight = function(self, h) self.__h = h; self.__hSet = true end
M.SetSize = function(self, w, h) self.__w, self.__h = w, h or w; self.__wSet, self.__hSet = true, true end
M.SetFont = function(self, _, size) self.__fsize = size; return true end
-- the size set, not a fixed 12 (the Lab's test checks that a section's lines share one size)
M.GetFont = function(self) return "Fonts\\FRIZQT__.TTF", self.__fsize or 12, "" end
M.SetFontObject = function(self) end
M.SetJustifyH = function(self, j) self.__justify = j end
M.SetWordWrap = function(self, v) self.__wrap = v and true or false end
M.SetMaxLines = function(self, n) self.__maxLines = n end
M.GetStringWidth = function(self) return M.TextWidth(self) end
M.GetUnboundedStringWidth = function(self) return M.TextWidth(self) end

-- what the game draws of a text: colour codes, links and textures out (a texture is about a letter's square)
local function Visible(t)
    t = tostring(t or "")
    local icons = 0
    t = t:gsub("|T.-|t", function() icons = icons + 1 return "" end)
    t = t:gsub("|A.-|a", function() icons = icons + 1 return "" end)
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
    return t, icons
end
M.Visible = Visible

-- a line's height: the letters, or the coin icons in it, which the game draws taller and a little low
function M.LineHeight(f)
    local size = f.__fsize or 12
    return tostring(f.__text or ""):find("|T") and size * 1.4 or size * 1.2
end

function M.TextWidth(self)
    local widest = 0
    for line in (tostring(self.__text or "") .. "\n"):gmatch("(.-)\n") do
        widest = math.max(widest, M.LineWidth(self, line))
    end
    return widest
end

function M.LineWidth(self, text)
    local t, icons = Visible(text)
    local size = self.__fsize or 12
    local w = 0
    for ch in t:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if ch == " " then w = w + 0.28
        elseif ch:match("[ilI%.,:;'!|]") then w = w + 0.3
        elseif ch:match("[mwMW]") then w = w + 0.82
        elseif ch:match("[%u%d%%]") then w = w + 0.64
        else w = w + 0.52 end
    end
    return w * size + icons * size
end

-- the rectangle of a frame: left, right, top, bottom (y up), from UIParent's 1920x1080
local SCREEN = { 0, 1920, 1080, 0 }
local function H(point) if point:find("LEFT") then return "l" elseif point:find("RIGHT") then return "r" else return "c" end end
local function V(point) if point:find("TOP") then return "t" elseif point:find("BOTTOM") then return "b" else return "m" end end

local cache, caching, depth = {}, false, 0
function M.Rect(f)
    if f == UIParent or f == nil then return SCREEN end
    if caching and cache[f] then return cache[f] end
    depth = depth + 1
    if depth > 60 then depth = depth - 1; return SCREEN end
    local l, r, cx, t, b, cy
    for _, a in pairs(f.__anch or {}) do
        local rr = M.Rect(a.rel or f.__parent or UIParent)
        local x = (H(a.relPoint) == "l" and rr[1]) or (H(a.relPoint) == "r" and rr[2]) or (rr[1] + rr[2]) / 2
        local y = (V(a.relPoint) == "t" and rr[3]) or (V(a.relPoint) == "b" and rr[4]) or (rr[3] + rr[4]) / 2
        x, y = x + (a.x or 0), y + (a.y or 0)
        local h, v = H(a.point), V(a.point)
        if h == "l" then l = x elseif h == "r" then r = x else cx = x end
        if v == "t" then t = y elseif v == "b" then b = y else cy = y end
    end
    local w, hgt
    if f.__kind == "FontString" then
        w = f.__wSet and f.__w or M.TextWidth(f)
        hgt = f.__hSet and f.__h or M.LineHeight(f)
    else
        w, hgt = f.__w or 100, f.__h or 20
    end
    if l and r then w = r - l elseif l then r = l + w elseif r then l = r - w elseif cx then l, r = cx - w / 2, cx + w / 2
    else
        local pr = M.Rect(f.__parent or UIParent); l, r = pr[1], pr[1] + w
    end
    if t and b then hgt = t - b elseif t then b = t - hgt elseif b then t = b + hgt elseif cy then t, b = cy + hgt / 2, cy - hgt / 2
    else
        local pr = M.Rect(f.__parent or UIParent); t, b = pr[3], pr[3] - hgt
    end
    local rect = { l, r, t, b }
    if caching then cache[f] = rect end
    depth = depth - 1
    return rect
end
function M.Reset() cache = {} end
-- like the game: sizes remembered until something moves (the ms test - it measures the addon, not this solver)
local live = false
function M.Live(on) live, caching, cache = on, on, {} end
for _, k in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetWidth", "SetHeight", "SetSize", "SetParent", "SetText", "SetFormattedText", "Show", "Hide" }) do
    local fn = M[k]
    if fn then M[k] = function(...) if live then cache = {} end return fn(...) end end
end

-- what the addon asks of a frame's size and place: the layout's answers
M.GetWidth = function(self) local r = M.Rect(self) return r[2] - r[1] end
M.GetHeight = function(self) local r = M.Rect(self) return r[3] - r[4] end
M.GetSize = function(self) local r = M.Rect(self) return r[2] - r[1], r[3] - r[4] end
M.GetLeft = function(self) return M.Rect(self)[1] end
M.GetRight = function(self) return M.Rect(self)[2] end
M.GetTop = function(self) return M.Rect(self)[3] end
M.GetBottom = function(self) return M.Rect(self)[4] end
M.GetCenter = function(self) local r = M.Rect(self) return (r[1] + r[2]) / 2, (r[3] + r[4]) / 2 end
M.GetRect = function(self) local r = M.Rect(self) return r[1], r[4], r[2] - r[1], r[3] - r[4] end

-- the game tells frames when their size changes: here, for every shown frame that listens, with its size now
function M.Settle(root)
    for _ = 1, 3 do
        local function walk(f)
            if f.__shown == false then return end
            local fn = f.__scripts and f.__scripts.OnSizeChanged
            if fn then
                local r = M.Rect(f)
                local w, h = r[2] - r[1], r[3] - r[4]
                if f.__lastW ~= w or f.__lastH ~= h then
                    f.__lastW, f.__lastH = w, h
                    mock.call("OnSizeChanged", fn, f, w, h)
                end
            end
            for _, k in ipairs(f.__kids or {}) do walk(k) end
        end
        walk(root)
    end
end

local function Shown(f)
    while f do
        if f.__shown == false then return false end
        if f == UIParent then return true end
        f = f.__parent
    end
    return true
end

-- where the letters of a text land: inside its box, by its justification, cut at the box's width
function M.Ink(f)
    local box = M.Rect(f)
    local tw = M.TextWidth(f)
    local bw = box[2] - box[1]
    local w = math.min(tw, math.max(0, bw))
    local j = f.__justify or "LEFT"
    if f.__kind ~= "FontString" then j = "CENTER" end
    local l
    if j == "RIGHT" then l = box[2] - w elseif j == "CENTER" then l = (box[1] + box[2]) / 2 - w / 2 else l = box[1] end
    local lh = M.LineHeight(f)
    local mid = (box[3] + box[4]) / 2
    if f.__wrap and tw > bw + 1 and bw > 0 then
        -- wrapped: lines down from the top of the box
        local lines = math.min(math.ceil(tw / bw), f.__maxLines or 99)
        return { box[1], box[2], box[3], box[3] - lines * lh }, false
    end
    return { l, l + w, mid + lh / 2, mid - lh / 2 }, tw > bw + 1 and bw > 0
end

-- every text drawn in a window (shown, with letters), its ink and whether it's cut
function M.Texts(root)
    M.Reset()
    caching = true
    local out = {}
    local function walk(f, clip)
        if not Shown(f) then return end
        -- a scroll frame shows only what's inside it
        if f.__kind == "ScrollFrame" then
            local r = M.Rect(f)
            clip = clip and { math.max(clip[1], r[1]), math.min(clip[2], r[2]), math.min(clip[3], r[3]), math.max(clip[4], r[4]) } or r
        end
        local text = f.__text
        if text and text ~= "" and (f.__kind == "FontString" or (f.__kind or ""):find("Button")) and (f.__alpha or 1) > 0 then
            local vis = Visible(text)
            if vis:match("%S") then
                local ink, cut = M.Ink(f)
                if clip then
                    ink = { math.max(ink[1], clip[1]), math.min(ink[2], clip[2]), math.min(ink[3], clip[3]), math.max(ink[4], clip[4]) }
                end
                if ink[2] - ink[1] > 1 and ink[3] - ink[4] > 1 then
                    -- a list row's text that hangs out of its row (into the next one)
                    local spill = false
                    local p = f.__parent
                    if p and p.__kind == "Button" and f.__kind == "FontString" and p.__h and p.__h <= 80 then
                        local pr = M.Rect(p)
                        spill = ink[4] < pr[4] - 2 or ink[3] > pr[3] + 2
                    end
                    -- letters past the left or right side of the frame it's in (its window's edge, a panel's border)
                    local out_ = false
                    local pf = f.__parent
                    if pf and pf ~= UIParent and f.__kind == "FontString" then
                        local pr = M.Rect(pf)
                        out_ = ink[2] > pr[2] + 3 or ink[1] < pr[1] - 3
                    end
                    out[#out + 1] = { f = f, text = vis, ink = ink, cut = cut, spill = spill, out = out_ }
                end
            end
        end
        for _, k in ipairs(f.__kids or {}) do walk(k, clip) end
    end
    walk(root)
    caching = false
    return out
end

-- texts whose letters overlap (by more than a sliver)
function M.Overlaps(root)
    local texts = M.Texts(root)
    local found = {}
    for i = 1, #texts do
        local a = texts[i]
        for j = i + 1, #texts do
            local b = texts[j]
            local w = math.min(a.ink[2], b.ink[2]) - math.max(a.ink[1], b.ink[1])
            local h = math.min(a.ink[3], b.ink[3]) - math.max(a.ink[4], b.ink[4])
            if w > 3 and h > 4 then found[#found + 1] = { a, b, w, h } end
        end
    end
    return found, texts
end

-- a frame's place, for the report: its parents' names or kinds
function M.Where(f)
    local parts = {}
    local p = f.__parent
    for _ = 1, 4 do
        if not p or p == UIParent then break end
        parts[#parts + 1] = p.__name or (p.__tag) or p.__kind
        p = p.__parent
    end
    return table.concat(parts, " < ")
end
