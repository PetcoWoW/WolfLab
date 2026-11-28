-- Wolf Lab: a preview of Wolf's next look, with sample data only. It reads nothing from the game's auction
-- house, your bags, mail or other addons, and sends nothing: every item, price and verdict is built in (Data.lua).
-- Its own saved data (WolfLabDB: the window's place, the look, the text size), its own /wolflab, its own frame
-- names: it can sit next to Wolf and never touch Wolf's prices or settings.
local ADDON, FT = ...

local L = setmetatable({}, { __index = function(_, k) return k end })
FT.L = L

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
FT.VERSION = (GetMeta and GetMeta(ADDON, "Version")) or "dev"
FT.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
-- Wolf's logo: the game's own black wolf icon (nothing to ship)
FT.LOGO = "Interface\\Icons\\Ability_Mount_BlackDireWolf"

---------------------------------------------------------------------------
-- Events: game events and our own ("FT_*") share one dispatcher
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

function FT.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        if not event:find("^FT_") then pcall(eventFrame.RegisterEvent, eventFrame, event) end
    end
    table.insert(handlers[event], fn)
end

function FT.Fire(event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...) FT.Fire(event, ...) end)

-- the widgets show a search countdown on rows when a list asks for one; the Lab never searches
FT.Scanner = {}
function FT.Scanner.LiveTick() return nil end

---------------------------------------------------------------------------
-- Formatting (as in Wolf)
---------------------------------------------------------------------------
FT.HEX = {
    text = "eaecef", muted = "848e9c", dim = "5e6673", up = "0ecb81", down = "f6465d",
    accent = "f0b90b", blue = "3b82f6", purple = "a78bfa", orange = "ff9a2e", gold = "e8b923", silver = "c0c6cc", copper = "d9894a",
}

function FT.C(hex, s)
    return "|cff" .. (FT.HEX[hex] or hex) .. tostring(s) .. "|r"
end

local function Coin(kind)
    return "|TInterface\\MoneyFrame\\UI-" .. kind .. "Icon:0:0:1:0|t"
end
FT.COIN = { gold = Coin("Gold"), silver = Coin("Silver"), copper = Coin("Copper") }

function FT.Thousands(n)
    local s = tostring(math.floor(n))
    local out, k = s, 0
    repeat
        out, k = out:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until k == 0
    return out
end

-- copper -> "42g 12s 30c"; mode "short": at most two units ("42g 12s", "1,204g"); "gold": gold only ("14g")
function FT.Money(c, mode)
    if c == nil then return "|cff5e6673—|r" end
    local neg = c < 0
    c = math.floor(math.abs(c) + 0.5)
    local g = math.floor(c / 10000)
    local s = math.floor((c % 10000) / 100)
    local cp = c % 100
    local G, S, Cc = FT.COIN.gold, FT.COIN.silver, FT.COIN.copper
    local out
    if mode == "gold" and g >= 1 then
        out = FT.Thousands(math.floor(c / 10000 + 0.5)) .. G
    elseif mode == "short" or mode == "gold" then
        if g >= 1000 then
            out = FT.Thousands(g) .. G
        elseif g >= 1 then
            out = g .. G .. (s > 0 and (" " .. s .. S) or "")
        elseif s >= 1 then
            out = s .. S .. (cp > 0 and (" " .. cp .. Cc) or "")
        else
            out = cp .. Cc
        end
    else
        local parts = {}
        if g > 0 then parts[#parts + 1] = FT.Thousands(g) .. G end
        if s > 0 or (g > 0 and cp > 0) then parts[#parts + 1] = s .. S end
        if cp > 0 or #parts == 0 then parts[#parts + 1] = cp .. Cc end
        out = table.concat(parts, " ")
    end
    return (neg and "-" or "") .. out
end

function FT.SignedMoney(c, mode)
    if c and c > 0 then return "+" .. FT.Money(c, mode or "short") end
    return FT.Money(c, mode or "short")
end

function FT.GoldNumber(c)
    if not c then return "" end
    local g = c / 10000
    if math.abs(g) >= 1000 then return FT.Thousands(g) end
    if math.abs(g) >= 100 then return string.format("%.1f", g) end
    if math.abs(g) >= 1 then return string.format("%.2f", g) end
    return string.format("%.4f", g)
end

-- 0.12 -> "+12%" (whole percents: the Lab rounds the way the new Wolf will)
function FT.Pct(v, plain)
    if v == nil or v ~= v then return "|cff5e6673—|r" end
    local p = v * 100
    local s = string.format("%+.0f%%", p)
    if s == "+0%" or s == "-0%" then s = "0%" end
    if plain then return s end
    if p >= 0.5 then return FT.C("up", s) end
    if p <= -0.5 then return FT.C("down", s) end
    return FT.C("muted", s)
end

function FT.Num(n)
    if not n then return "—" end
    return FT.Thousands(n)
end

function FT.TimeOfDay(t)
    if not t then return "" end
    local s = date("%I:%M %p", t):gsub("^0", ""):lower()
    if date("%Y%m%d", t) ~= date("%Y%m%d") then s = date("%a", t) .. " " .. s end
    return s
end

-- 7 -> "7 am", 19 -> "7 pm", 0 -> "12 am"
function FT.Hour(h)
    h = h % 24
    local n = h % 12
    if n == 0 then n = 12 end
    return n .. (h < 12 and " am" or " pm")
end

---------------------------------------------------------------------------
-- Items: the sample book first (Data.lua), so names and quality show even before the game has loaded an item
---------------------------------------------------------------------------
function FT.Item(itemID)
    if not itemID then return nil end
    local d = FT.Data and FT.Data.items[itemID]
    local name, link, quality, icon
    if GetItemInfo then
        local n, lk, q, _, _, _, _, _, _, ic = GetItemInfo(itemID)
        name, link, quality, icon = n, lk, q, ic
    end
    if not icon and GetItemInfoInstant then icon = select(5, GetItemInfoInstant(itemID)) end
    name = name or (d and d.name)
    quality = quality or (d and d.q) or 1
    return name, quality, icon, nil, link
end

function FT.QualityHex(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c and c.hex then return (c.hex:gsub("^|c", "")) end
    if q == 2 then return "ff1eff00" end
    if q == 3 then return "ff0070dd" end
    if q == 4 then return "ffa335ee" end
    return "ffffffff"
end

function FT.ItemText(itemID, _)
    local name, quality = FT.Item(itemID)
    if not name then return "|cff5e6673#" .. tostring(itemID) .. "|r" end
    return "|c" .. FT.QualityHex(quality) .. name .. "|r"
end

function FT.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cfff0b90bWolf Lab|r: " .. tostring(msg))
end

---------------------------------------------------------------------------
-- The six verdicts: one word and one colour each, everywhere. Meme words only with Settings > Meme words on.
---------------------------------------------------------------------------
FT.SIGNAL_COLORS = { BUY = "blue", SELL = "up", HOLD = "accent", WAIT = "muted", CRAFT = "purple", FARM = "orange", DAY = "muted" }
local MEME = { BUY = "APE IN", SELL = "CASH OUT", HOLD = "HODL" }

function FT.SignalText(kind)
    if FT.S and FT.S.meme and MEME[kind] then return MEME[kind] end
    return kind
end

---------------------------------------------------------------------------
-- Saved data and start
---------------------------------------------------------------------------
local DEFAULTS = { look = "classic", textSize = 0, font = "condensed", meme = false, scale = 1 }

FT.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    WolfLabDB = type(WolfLabDB) == "table" and WolfLabDB or {}
    local db = WolfLabDB
    db.settings = type(db.settings) == "table" and db.settings or {}
    for k, v in pairs(DEFAULTS) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    db.frame = type(db.frame) == "table" and db.frame or {}
    db.watch = type(db.watch) == "table" and db.watch or {}
    db.ui = type(db.ui) == "table" and db.ui or {}
    FT.db, FT.S = db, db.settings
    FT.Fire("FT_DB_READY")
end)

SLASH_WOLFLAB1 = "/wolflab"
SlashCmdList["WOLFLAB"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "reset" then
        if FT.db then FT.db.frame = {} end
        if FT.ResetWindow then FT.ResetWindow() end
        FT.Print(L["window put back in the middle."])
        return
    end
    if FT.Toggle then FT.Toggle(msg ~= "" and msg or nil) end
end
