-- Wolf Lab: Make gold. What used to be Money, Craft for profit, Raw mats and Futures, as four sections of one page.
-- Each row: the verdict, the item, the gold, and one line of why. Click a row: the item's page.
local ADDON, FT = ...
local UI, L = FT.UI, FT.L
local D, Lab = FT.Data, FT.Lab

local P = {}
FT.Pages.make = P

local PAD = 14
local SECTIONS = {
    { "flip", L["Flip it"], L["Bought under its usual price, it sells back up: buy now, list again."] },
    { "craft", L["Craft it"], L["Worth more made than its materials cost, with a recipe one of your characters knows."] },
    { "farm", L["Farm it"], L["Worth gathering for your professions and level: how much each and how many sell a day."] },
    { "coming", L["Coming up"], L["What should pay next week, and how sure Wolf is: each kind of call checked against the last 90 days."] },
}
local current = "flip"

-- a list of moves: two lines a row
function Lab.MoveRows(parent)
    local list = UI.List(parent, {
        rowHeight = UI.RowH(52),
        setup = function(row)
            row.badge = Lab.Badge(row, 64, 20)
            row.badge:SetPoint("LEFT", 10, 0)
            row.gold = UI.Text(row, 15, "text", "RIGHT")
            row.gold:SetPoint("RIGHT", -14, 0)
            row.gold:SetWidth(140)
            row.name = UI.Text(row, 15, "text")
            row.name:SetPoint("TOPLEFT", row.badge, "TOPRIGHT", 14, 6)
            row.name:SetPoint("RIGHT", row.gold, "LEFT", -12, 0)
            row.text = UI.Text(row, 13, "muted")
            row.text:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
            row.text:SetPoint("RIGHT", row.gold, "LEFT", -12, 0)
            if row.name.SetWordWrap then row.name:SetWordWrap(false) end
            row.line = UI.HLine(row, "line", 0.35)
            row.line:SetPoint("BOTTOMLEFT", 6, 0)
            row.line:SetPoint("BOTTOMRIGHT", -6, 0)
        end,
        update = function(row, m)
            -- a heading row (Coming up: Best farms next week, The raids)
            row.badge:SetShown(not m.head)
            row.text:SetShown(not m.head)
            if m.head then
                row.name:SetText(FT.C("accent", L[m.head]))
                row.gold:SetText("")
                return
            end
            row.badge:Set(m.kind)
            row.name:SetText(FT.ItemText(m.id))
            if m.sure then
                UI.FitBits(row.text, (m.hour and (FT.C("text", "~" .. FT.Money(m.hour, "gold") .. " " .. L["an hour"]) .. "  ·  ") or "") .. m.text)
            else
                row.text:SetText(m.text)
            end
            if m.sure then
                -- how sure: high from 75, medium from 55, else low - with the number
                local c = m.sure >= 75 and "up" or (m.sure >= 55 and "accent" or "dim")
                local w = m.sure >= 75 and L["High"] or (m.sure >= 55 and L["Medium"] or L["Low"])
                row.gold:SetText(FT.C(c, m.sure .. "%") .. FT.C("dim", " " .. w))
            elseif m.each then
                row.gold:SetText(FT.Money(m.each, "short") .. FT.C("dim", " " .. L["each"]))
            elseif m.gold then
                row.gold:SetText(FT.C("up", "+") .. FT.Money(m.gold, "gold"))
            else
                row.gold:SetText(FT.Money(D.items[m.id].price, "short"))
            end
        end,
        onClick = function(m) if m.id then Lab.OpenItem(m.id) end end,
        onEnter = function(row, m)
            if not m.id then return end
            if m.sure then
                Lab.ItemTip(row, m.id, m.text)
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(L["How sure"], m.sure .. "%", 1, 0.82, 0, 1, 1, 1)
                GameTooltip:AddLine(string.format(L["Calls like this came true %s times in the last 90 days. Behind this one: %s."], m.record, m.data), 0.75, 0.78, 0.82, true)
                GameTooltip:AddLine(L["Each call is scored a week later: the record keeps itself honest."], 0.58, 0.55, 0.5, true)
                GameTooltip:Show()
            else
                Lab.ItemTip(row, m.id, m.text)
            end
        end,
    })
    return list
end

function P.Build(p)
    local opts = {}
    for _, s in ipairs(SECTIONS) do opts[#opts + 1] = { s[1], s[2] } end
    P.seg = UI.Segmented(p, opts, function(v) current = v; P.Show() end, 24)
    P.seg:SetPoint("TOPLEFT", PAD, -PAD)

    P.lead = UI.Text(p, 14, "muted")
    P.lead:SetPoint("TOPLEFT", P.seg, "BOTTOMLEFT", 2, -14)
    P.lead:SetPoint("RIGHT", -PAD, 0)

    local box = UI.Panel(p, "bg1", "line")
    box:SetPoint("TOPLEFT", P.lead, "BOTTOMLEFT", -2, -12)
    box:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    P.list = Lab.MoveRows(box)
    P.list:SetPoint("TOPLEFT", 6, -6)
    P.list:SetPoint("BOTTOMRIGHT", -6, 6)
    P.list:SetEmptyText(L["Nothing worth doing here right now: new prices come every hour."])
end

function P.Show()
    P.seg:SetValue(current)
    for _, s in ipairs(SECTIONS) do
        if s[1] == current then P.lead:SetText(s[3]) end
    end
    P.list:SetItems(D.make[current] or {})
end

function P.Dirty() if P.list then P.list:Refresh() end end
