-- A fake World of Warcraft, just enough to load an addon and click through its UI outside the game.
-- Frames remember their scripts and events; timers run when mock.run(seconds) is called; unknown API calls
-- return nil. mock.errors collects every error with its traceback.
mock = { errors = {}, now = 1795565000, timers = {}, frames = {}, prints = {} }

local function err(where, e)
    mock.errors[#mock.errors + 1] = where .. ": " .. tostring(e)
end
mock.err = err

function mock.call(where, fn, ...)
    local args, n = { ... }, select("#", ...)
    local ok, e = xpcall(function() return fn(unpack(args, 1, n)) end, function(m) return debug.traceback(m, 2) end)
    if not ok then err(where, e) end
    return ok
end

-- clocks
local clock0 = os.clock()
function GetTime() return mock.now - 1795560000 end
function time(t) if t then return os.time(t) end return mock.now end
function GetServerTime() return mock.now end
date = function(fmt, t) return os.date(fmt, t or mock.now) end
debugprofilestop = function() return (os.clock() - clock0) * 1000 end

-- timers
C_Timer = {}
function C_Timer.After(sec, fn) mock.timers[#mock.timers + 1] = { at = mock.now + sec, fn = fn } end
function C_Timer.NewTicker(sec, fn, n)
    local t = { cancelled = false }
    function t:Cancel() self.cancelled = true end
    function t:IsCancelled() return self.cancelled end
    local count = 0
    local function tick()
        if t.cancelled then return end
        count = count + 1
        mock.call("ticker", fn, t)
        if not t.cancelled and (not n or count < n) then
            mock.timers[#mock.timers + 1] = { at = mock.now + math.max(sec, 0.01), fn = tick }
        end
    end
    mock.timers[#mock.timers + 1] = { at = mock.now + math.max(sec, 0.01), fn = tick }
    return t
end
C_Timer.NewTimer = function(sec, fn) return C_Timer.NewTicker(sec, fn, 1) end
-- run timers and OnUpdate scripts for `seconds` of game time, in steps
function mock.run(seconds, step)
    step = step or 0.05
    local stop = mock.now + seconds
    local guard = 0
    while mock.now < stop do
        mock.now = mock.now + step
        guard = guard + 1
        local due = {}
        local keep = {}
        for _, t in ipairs(mock.timers) do
            if t.at <= mock.now then due[#due + 1] = t else keep[#keep + 1] = t end
        end
        mock.timers = keep
        for _, t in ipairs(due) do mock.call("timer", t.fn) end
        for _, f in ipairs(mock.frames) do
            local u = f.__scripts.OnUpdate
            if u and f.__shown then mock.call("OnUpdate", u, f, step) end
        end
        if guard > 200000 then err("run", "too many steps"); break end
    end
end

-- frames: every method exists; a few answer something sensible
local Frame = {}
local methods = {}
local function newObj(kind, name, parent)
    local o = setmetatable({ __kind = kind, __scripts = {}, __events = {}, __shown = true, __text = "",
        __w = 100, __h = 20, __parent = parent, __name = name, __points = 0, __alpha = 1 }, Frame)
    return o
end
Frame.__index = function(self, k)
    local m = methods[k]
    if m then return m end
    -- the game's methods are CamelCase; the addon's own fields (lowercase) are nil until it sets them
    if type(k) == "string" and k:match("^%u") then return function() return nil end end
    return nil
end
function methods:SetScript(s, fn) self.__scripts[s] = fn end
function methods:GetScript(s) return self.__scripts[s] end
function methods:HookScript(s, fn)
    local old = self.__scripts[s]
    self.__scripts[s] = function(...) if old then old(...) end fn(...) end
end
function methods:HasScript() return true end
function methods:RegisterEvent(e) self.__events[e] = true end
function methods:UnregisterEvent(e) self.__events[e] = nil end
function methods:RegisterAllEvents() self.__all = true end
function methods:IsEventRegistered(e) return self.__events[e] and true or false end
function methods:Show() self.__shown = true local s = self.__scripts.OnShow if s then mock.call("OnShow", s, self) end end
function methods:Hide() local was = self.__shown self.__shown = false local s = self.__scripts.OnHide if s and was then mock.call("OnHide", s, self) end end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.__shown end
function methods:IsVisible() return self.__shown end
function methods:SetText(t) self.__text = t == nil and "" or tostring(t) end
function methods:SetFormattedText(f, ...) self.__text = string.format(f, ...) end
function methods:GetText() return self.__text end
function methods:SetWidth(w) self.__w = w end
function methods:SetHeight(h) self.__h = h end
function methods:SetSize(w, h) self.__w, self.__h = w, h or w end
function methods:GetWidth() return self.__w end
function methods:GetHeight() return self.__h end
function methods:GetSize() return self.__w, self.__h end
function methods:GetStringWidth() return #tostring(self.__text) * 6 end
function methods:GetStringHeight() return 12 end
function methods:GetUnboundedStringWidth() return #tostring(self.__text) * 6 end
function methods:GetLineHeight() return 12 end
function methods:GetNumLines() return 1 end
function methods:IsTruncated() return false end
function methods:GetLeft() return 0 end
function methods:GetRight() return self.__w end
function methods:GetTop() return self.__h end
function methods:GetBottom() return 0 end
function methods:GetCenter() return self.__w / 2, self.__h / 2 end
function methods:GetRect() return 0, 0, self.__w, self.__h end
function methods:GetScale() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:GetAlpha() return self.__alpha end
function methods:SetAlpha(a) self.__alpha = a end
function methods:GetParent() return self.__parent end
function methods:SetParent(p) self.__parent = p end
function methods:GetName() return self.__name end
function methods:GetObjectType() return self.__kind end
function methods:IsObjectType(t) return self.__kind == t end
function methods:GetNumPoints() return self.__points end
function methods:SetPoint() self.__points = self.__points + 1 end
function methods:ClearAllPoints() self.__points = 0 end
function methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function methods:IsMouseOver() return false end
function methods:IsMouseEnabled() return true end
function methods:GetFrameLevel() return 1 end
function methods:GetFrameStrata() return "MEDIUM" end
function methods:GetChecked() return self.__checked or false end
function methods:SetChecked(v) self.__checked = v and true or false end
function methods:GetValue() return self.__value or 0 end
function methods:SetValue(v) self.__value = v end
function methods:GetMinMaxValues() return 0, 100 end
function methods:GetVerticalScroll() return 0 end
function methods:GetHorizontalScroll() return 0 end
function methods:GetVerticalScrollRange() return 0 end
function methods:GetNumber() return tonumber(self.__text) or 0 end
function methods:HasFocus() return false end
function methods:GetCursorPosition() return 0 end
function methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function methods:SetFont() return true end
function methods:GetFontObject() return nil end
function methods:GetTextColor() return 1, 1, 1, 1 end
function methods:GetVertexColor() return 1, 1, 1, 1 end
function methods:GetTexture() return self.__tex end
function methods:SetTexture(t) self.__tex = t return true end
function methods:GetChildren() return end
function methods:GetRegions() return end
function methods:GetNumChildren() return 0 end
function methods:GetID() return self.__id or 0 end
function methods:SetID(i) self.__id = i end
function methods:IsEnabled() return true end
function methods:GetButtonState() return "NORMAL" end
function methods:IsDragging() return false end
function methods:IsProtected() return false end
function methods:CanChangeProtectedState() return true end
function methods:GetFontString() if not self.__fs then self.__fs = newObj("FontString", nil, self) end return self.__fs end
function methods:GetNormalTexture() return newObj("Texture", nil, self) end
function methods:GetHighlightTexture() return newObj("Texture", nil, self) end
function methods:GetPushedTexture() return newObj("Texture", nil, self) end
function methods:GetScrollChild() return self.__child end
function methods:SetScrollChild(c) self.__child = c end
function methods:CreateTexture(name) local t = newObj("Texture", name, self) return t end
function methods:CreateMaskTexture(name) return newObj("MaskTexture", name, self) end
function methods:CreateLine(name) return newObj("Line", name, self) end
function methods:CreateFontString(name) return newObj("FontString", name, self) end
function methods:CreateAnimationGroup() return newObj("AnimationGroup", nil, self) end
function methods:CreateAnimation() return newObj("Animation", nil, self) end
-- a tooltip's lines, as the game has them: <name>TextLeftN / TextRightN font strings, reused after ClearLines
function methods:NumLines() return self.__n or 0 end
local function TipLine(self, i)
    local name = self.__name or "Tooltip"
    local l = _G[name .. "TextLeft" .. i]
    if not l then
        l = newObj("FontString", name .. "TextLeft" .. i, self)
        _G[name .. "TextLeft" .. i] = l
        _G[name .. "TextRight" .. i] = newObj("FontString", name .. "TextRight" .. i, self)
    end
    return l, _G[name .. "TextRight" .. i]
end
function methods:GetOwner() return self.__owner end
function methods:SetOwner(o) self.__owner = o end
function methods:GetItem() return nil end
function methods:AddLine(t)
    self.__lines = self.__lines or {}; table.insert(self.__lines, tostring(t))
    self.__n = (self.__n or 0) + 1
    local l, r = TipLine(self, self.__n)
    l:SetText(tostring(t)); l:Show(); r:SetText(""); r:Hide()
end
function methods:AddDoubleLine(a, b)
    self.__lines = self.__lines or {}; table.insert(self.__lines, tostring(a) .. " | " .. tostring(b))
    self.__n = (self.__n or 0) + 1
    local l, r = TipLine(self, self.__n)
    l:SetText(tostring(a)); l:Show(); r:SetText(tostring(b)); r:Show()
end
function methods:ClearLines() self.__lines = {}; self.__n = 0 end

function CreateFrame(kind, name, parent, template)
    local f = newObj(kind or "Frame", name, parent)
    if template and tostring(template):find("Backdrop") then
        f.SetBackdrop = function() end
    end
    mock.frames[#mock.frames + 1] = f
    if name then _G[name] = f end
    return f
end
mock.newObj = newObj

UIParent = CreateFrame("Frame", "UIParent")
WorldFrame = CreateFrame("Frame", "WorldFrame")
Minimap = CreateFrame("Frame", "Minimap")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip", UIParent)
DEFAULT_CHAT_FRAME = CreateFrame("Frame", "DEFAULT_CHAT_FRAME")
DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) mock.prints[#mock.prints + 1] = tostring(msg) end
UISpecialFrames = {}
SlashCmdList = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end })
ITEM_QUALITY_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, hex = "|cffffffff" } end })
SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
NUM_BAG_SLOTS, NUM_BANKBAGSLOTS, BANK_CONTAINER, ATTACHMENTS_MAX_RECEIVE = 4, 6, -1, 16
BackdropTemplateMixin = {}
Enum = setmetatable({}, { __index = function(t, k)
    local sub = setmetatable({}, { __index = function() return 1 end })
    rawset(t, k, sub)
    return sub
end })
Constants = setmetatable({}, { __index = function(t, k) local s = {} rawset(t, k, s) return s end })

-- the player and the world
mock.money = 12345678
-- mock.target = { guid, name, level }: what you have targeted (the farm log names a corpse by it)
mock.level = 60
function UnitName(u)
    if u == "player" then return "Jay" end
    if u == "target" and mock.target then return mock.target.name end
    return nil
end
function UnitGUID(u)
    if u == "player" then return "Player-366-0ABCDEF1" end
    if u == "target" and mock.target then return mock.target.guid end
    return nil
end
function UnitFactionGroup() return "Alliance", "Alliance" end
function UnitClass() return "Rogue", "ROGUE", 4 end
function UnitLevel(u)
    if u == "target" and mock.target then return mock.target.level end
    return mock.level
end
-- the zone, and a loot window: mock.loot = { { id, qty, sources = { guid, qty, ... } }, ... }
mock.zone = "Arathi Highlands"
function GetRealZoneText() return mock.zone end
function GetZoneText() return mock.zone end
mock.loot = {}
function GetNumLootItems() return #mock.loot end
function GetLootSlotLink(i) local x = mock.loot[i] return x and ("|cffffffff|Hitem:" .. x.id .. "::::::::60:::::|h[Item " .. x.id .. "]|h|r") end
function GetLootSlotInfo(i) local x = mock.loot[i] if not x then return nil end return 134400, "Item " .. x.id, x.qty, nil, 1, false end
function GetLootSourceInfo(i) local x = mock.loot[i] if not x then return nil end return unpack(x.sources or {}) end
function IsFishingLoot() return false end
function UnitExists(u) return u == "player" end
function UnitIsPlayer() return true end
function UnitIsConnected() return true end
function GetRealmName() return "Doomhowl" end
function GetRealmID() return 366 end
function GetCurrentRegion() return 1 end
function GetLocale() return "enUS" end
function GetMoney() return mock.money end
function InCombatLockdown() return mock.combat end
function IsInGuild() return false end
function IsInGroup() return false end
function IsInRaid() return false end
function GetNumGroupMembers() return 0 end
function IsShiftKeyDown() return false end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetCursorPosition() return 0, 0 end
function GetAddOnMemoryUsage() return 1000 end
function UpdateAddOnMemoryUsage() end
function GetAddOnMetadata(_, k) if k == "Version" then return "0.9.0" end return nil end
C_AddOns = { GetAddOnMetadata = GetAddOnMetadata, IsAddOnLoaded = function() return false end,
    GetAddOnInfo = function() return nil end, GetNumAddOns = function() return 0 end }
function hooksecurefunc(a, b, c)
    local t, name, fn = a, b, c
    if type(a) == "string" then t, name, fn = _G, a, b end
    local old = t[name]
    if type(old) ~= "function" then return end
    t[name] = function(...) local r = { old(...) } fn(...) return unpack(r) end
end
function geterrorhandler() return function(e) err("errorhandler", e) end end
function PlaySound() return true end
function ReloadUI() end
EventRegistry = { cb = {} }
function EventRegistry:RegisterCallback(ev, fn, owner) self.cb[ev] = self.cb[ev] or {}; table.insert(self.cb[ev], { fn, owner }) end
function SetItemRef(link, ...) for _, c in ipairs(EventRegistry.cb["SetItemRef"] or {}) do c[1](c[2], link, ...) end end
function IsInInstance() return false end
function HideUIPanel(f) if f then f:Hide() end end
function ShowUIPanel(f) if f then f:Show() end end
function UpdateUIPanelPositions() end
function HandleModifiedItemClick() return false end
function ChatFrame_AddMessageEventFilter() end
function PanelTemplates_DeselectTab() end
function PanelTemplates_SelectTab() end
function PanelTemplates_TabResize() end
function FauxScrollFrame_SetOffset() end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function() return r, g, b end } end
function strsplit(sep, s, n)
    local out = {}
    for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
    return unpack(out)
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert, tremove = table.insert, table.remove
function tContains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function Mixin(o, ...) for _, m in ipairs({ ... }) do for k, v in pairs(m) do o[k] = v end end return o end
function CreateFromMixins(...) return Mixin({}, ...) end
function securecall(fn, ...) return fn(...) end
function issecurevariable() return false end
function GetBuildInfo() return "1.16.0", "70338", "Nov 1 2026", 11600 end
function GetGuildRosterInfo() return nil end
function GetNumGuildMembers() return 0 end
function GuildRoster() end
C_GuildInfo = { GuildRoster = function() end }

-- items: a few known, the rest made up from the id
mock.items = {}
local function GetItemInfo(id)
    if type(id) == "string" then id = tonumber(id:match("item:(%d+)")) or tonumber(id) end
    if not id then return nil end
    local name = "Item " .. id
    local gear = id % 5 == 0
    return name, "|cffffffff|Hitem:" .. id .. "::::::::60:::::|h[" .. name .. "]|h|r", gear and 2 or 1, gear and (45 + id % 15) or 30, 0, "Trade Goods", "Herb",
        20, "", 134400, 25 + (id % 100), 7, 9, 1
end
local function GetItemInfoInstant(id)
    if type(id) == "string" then id = tonumber(id:match("item:(%d+)")) or tonumber(id) end
    if not id then return nil end
    local cls = (id % 5 == 0) and 4 or 7
    return id, cls == 7 and "Trade Goods" or "Armor", cls == 7 and "Herb" or "Leather", "", 134400, cls, cls == 7 and 9 or 2
end
function GetItemCount() return 0 end
function GetItemClassInfo(c) return "Class" .. tostring(c) end
function GetItemSubClassInfo(c, s) return "Sub" .. tostring(c) .. ":" .. tostring(s) end
C_Item = { GetItemInfo = GetItemInfo, GetItemInfoInstant = GetItemInfoInstant, GetItemCount = GetItemCount,
    RequestLoadItemDataByID = function() end, IsItemDataCachedByID = function() return true end,
    DoesItemExistByID = function() return true end, GetItemNameByID = function(id) return "Item " .. id end,
    GetItemQualityByID = function() return 1 end, GetItemIconByID = function() return 134400 end }
Item = { CreateFromItemID = function(_, id) return { ContinueOnItemLoad = function(_, fn) fn() end, GetItemID = function() return id end, IsItemEmpty = function() return false end } end }
ItemLocation = { CreateFromBagAndSlot = function() return { IsValid = function() return false end } end }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() return nil end,
    GetContainerItemID = function() return nil end, GetContainerItemLink = function() return nil end }
function GetContainerNumSlots() return 0 end
function GetContainerItemInfo() return nil end
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) mock.tdp = fn end }
mock.combat = false
C_TooltipInfo = {}
C_Map = { GetBestMapForUnit = function() return 1415 end, GetMapInfo = function() return { name = "Stormwind" } end }
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end, SendAddonMessage = function() return true end }
C_PlayerInfo = { GUIDIsPlayer = function() return true end }
C_ToyBox = {}
function PlayerHasToy() return false end
C_TransmogCollection = {}
C_MerchantFrame = {}
C_TradeSkillUI = {}
function GetNumTradeSkills() return 0 end
function GetNumCrafts() return 0 end
function GetNumSkillLines() return 0 end
function GetInboxNumItems() return #(mock.inbox or {}), #(mock.inbox or {}) end
function GetInboxHeaderInfo(i) local m = (mock.inbox or {})[i]; if m then return nil, nil, m.sender, "", m.money or 0, 0, 30 end end
function GetInboxItem(i, j) local m = (mock.inbox or {})[i]; local it = m and m.items and m.items[j]; if it then return "x", it[1], nil, it[2] end end
mock.sendItems, mock.sendMoney = {}, 0
function GetSendMailItem(i) local it = mock.sendItems[i]; if it then return "x", it[1], nil, it[2] end end
function GetSendMailMoney() return mock.sendMoney end
function GetSendMailCOD() return 0 end
function SendMail() end
function GetMerchantNumItems() return 0 end

-- the modern auction house: answers nothing unless told
C_AuctionHouse = setmetatable({}, { __index = function() return function() return nil end end })
C_AuctionHouse.GetNumReplicateItems = function() return 0 end
C_AuctionHouse.GetBrowseResults = function() return {} end
C_AuctionHouse.HasFullBrowseResults = function() return true end
C_AuctionHouse.GetItemKeyInfo = function() return nil end
C_AuctionHouse.MakeItemKey = function(id, lvl, suf) return { itemID = id, itemLevel = lvl or 0, itemSuffix = suf or 0, battlePetSpeciesID = 0 } end
C_AuctionHouse.GetAuctionHouseCut = function() return 0.05 end
C_AuctionHouse.GetTimeLeftBandInfo = function() return 0 end
C_AuctionHouse.IsThrottledMessageSystemReady = function() return true end
C_AuctionHouse.GetCommoditySearchResultsQuantity = function() return 0 end
C_AuctionHouse.GetNumCommoditySearchResults = function() return 0 end
C_AuctionHouse.GetNumItemSearchResults = function() return 0 end
C_AuctionHouse.GetNumOwnedAuctions = function() return 0 end
C_AuctionHouse.GetReplicateItemTimeLeft = function() return 1 end

-- unknown globals: nil (like the game for something that doesn't exist)

-- send an event to every frame that listens
function mock.fire(event, ...)
    for _, f in ipairs(mock.frames) do
        if (f.__events[event] or f.__all) and f.__scripts.OnEvent then
            mock.call("event " .. event, f.__scripts.OnEvent, f, event, ...)
        end
    end
end

-- click a button / show a frame's OnClick
function mock.click(f, button)
    local s = f and f.__scripts.OnClick
    if s then mock.call("OnClick", s, f, button or "LeftButton", false) end
end
