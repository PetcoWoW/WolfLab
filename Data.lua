-- Wolf Lab: the sample market. Real item IDs (so the game shows their icons and quality colours), made-up prices.
-- Nothing here is read from the game: the Lab is a picture of the new screens, not a working Wolf.
local ADDON, FT = ...

local D = {}
FT.Data = D

local G, S = 10000, 100

-- price: now; normal: its usual price; ch1/ch7/ch30: change over a day / week / month; perDay: sold a day.
-- verdict + reason: the call. sell / buy: its best hours; day: its busiest day. trend: how its 90 days ran.
D.items = {
    [13463] = { name = "Dreamfoil", q = 1, kind = "Herb", price = 1 * G + 40 * S, normal = 1 * G + 25 * S, ch1 = 0.12, ch7 = 0.09, ch30 = 0.16,
        perDay = 300, verdict = "SELL", reason = "12% above normal and it sells about 300 a day.", market = "Healthy",
        sell = { 19, 21 }, buy = { 4, 7 }, day = "Tuesday", trend = 0.20,
        craft = "Flask of the Titans uses 30: worth more as herbs today.", farm = "Felwood and Un'Goro, herb skill 270+." },
    [12363] = { name = "Arcane Crystal", q = 2, kind = "Trade Goods", price = 38 * G + 20 * S, normal = 35 * G, ch1 = 0.02, ch7 = 0.04, ch30 = 0.18,
        perDay = 45, verdict = "HOLD", reason = "Still climbing (+6% a week) and the raids need it from Dec 9. Sell Dec 5–8.", market = "Healthy",
        sell = { 19, 21 }, buy = { 4, 7 }, day = "Tuesday", trend = 0.30,
        craft = "Arcanite Bar: +6g a bar (you know it).", farm = "Rich Thorium veins: Un'Goro, Burning Steppes." },
    [10620] = { name = "Thorium Ore", q = 1, kind = "Metal & Stone", price = 1 * G + 40 * S, normal = 1 * G + 35 * S, ch1 = -0.01, ch7 = 0.03, ch30 = 0.05,
        perDay = 300, verdict = "FARM", reason = "Sells about 300 a day. Good spots for your level in Un'Goro.", market = "Busy",
        sell = { 18, 20 }, buy = { 3, 6 }, day = "Sunday", trend = 0.05,
        craft = "Thorium Bar: smelting adds nothing today.", farm = "Un'Goro Crater, Burning Steppes, Winterspring." },
    [12359] = { name = "Thorium Bar", q = 1, kind = "Metal & Stone", price = 1 * G + 12 * S, normal = 1 * G + 18 * S, ch1 = -0.03, ch7 = -0.04, ch30 = -0.02,
        perDay = 180, verdict = "WAIT", reason = "Sliding this week: wait for it to settle before buying.", market = "Flooded",
        sell = { 18, 21 }, buy = { 4, 8 }, day = "Sunday", trend = -0.08,
        craft = "Arcanite Bar needs 1 with an Arcane Crystal.", farm = "Smelt Thorium Ore." },
    [12360] = { made = true, name = "Arcanite Bar", q = 2, kind = "Metal & Stone", price = 48 * G, normal = 46 * G, ch1 = 0.01, ch7 = 0.05, ch30 = 0.14,
        perDay = 20, verdict = "CRAFT", reason = "Costs about 39g to make, sells for 48g. Once a day.", market = "Thin",
        sell = { 19, 22 }, buy = { 5, 8 }, day = "Tuesday", trend = 0.22,
        craft = "Transmute: Arcane Crystal + Thorium Bar, once a day.", farm = "Made, not farmed." },
    [13444] = { made = true, name = "Major Mana Potion", q = 1, kind = "Potion", price = 6 * G + 5 * S, normal = 5 * G + 13 * S, ch1 = 0.18, ch7 = 0.10, ch30 = 0.12,
        perDay = 140, verdict = "SELL", reason = "18% up today ahead of raid night. Post before 7 pm.", market = "Busy",
        sell = { 17, 19 }, buy = { 2, 6 }, day = "Tuesday", trend = 0.10,
        craft = "Alchemy 295: Dreamfoil + Icecap + Crystal Vial.", farm = "Made, not farmed." },
    [13457] = { made = true, name = "Greater Fire Protection Potion", q = 1, kind = "Potion", price = 5 * G + 40 * S, normal = 4 * G + 80 * S, ch1 = 0.04, ch7 = 0.12, ch30 = 0.30,
        perDay = 35, verdict = "HOLD", reason = "Onyxia's Lair needs it: rises into Dec 9.", market = "Healthy",
        sell = { 19, 21 }, buy = { 4, 7 }, day = "Tuesday", trend = 0.35,
        craft = "Elemental Fire + Dreamfoil.", farm = "Made, not farmed." },
    [13510] = { made = true, name = "Flask of the Titans", q = 1, kind = "Flask", price = 148 * G, normal = 138 * G, ch1 = 0.01, ch7 = 0.03, ch30 = 0.09,
        perDay = 6, verdict = "CRAFT", reason = "Materials about 129g, sells for 148g. Thin market: 6 a day.", market = "Thin",
        sell = { 19, 21 }, buy = { 5, 8 }, day = "Tuesday", trend = 0.12,
        craft = "30 Stonescale Oil, 10 Gromsblood, 1 Black Lotus.", farm = "Made, not farmed." },
    [13468] = { name = "Black Lotus", q = 2, kind = "Herb", price = 94 * G, normal = 92 * G, ch1 = 0.02, ch7 = 0.01, ch30 = 0.06,
        perDay = 8, verdict = "HOLD", reason = "Steady, and flasks need it once raids start.", market = "Thin",
        sell = { 20, 22 }, buy = { 4, 7 }, day = "Tuesday", trend = 0.06,
        craft = "Every flask uses 1.", farm = "Rare spawns: Burning Steppes, Winterspring, Silithus." },
    [14342] = { made = true, name = "Mooncloth", q = 1, kind = "Cloth", price = 7 * G + 80 * S, normal = 7 * G + 20 * S, ch1 = 0.07, ch7 = 0.05, ch30 = 0.08,
        perDay = 25, verdict = "SELL", reason = "7% up today: a good day to post yours.", market = "Healthy",
        sell = { 19, 21 }, buy = { 3, 6 }, day = "Wednesday", trend = 0.08,
        craft = "Tailoring cooldown: 2 Felcloth, every 4 days.", farm = "Made, not farmed." },
    [14047] = { name = "Runecloth", q = 1, kind = "Cloth", price = 32 * S, normal = 30 * S, ch1 = 0.01, ch7 = -0.02, ch30 = 0.01,
        perDay = 900, verdict = "FARM", reason = "Sells about 900 a day: easy to farm on any level-55+ humanoid.", market = "Busy",
        sell = { 18, 21 }, buy = { 3, 6 }, day = "Sunday", trend = 0.0,
        craft = "Runecloth Bag: worth less than the cloth.", farm = "Humanoids 55+: Eastern Plaguelands, Winterspring." },
    [8170] = { name = "Rugged Leather", q = 1, kind = "Leather", price = 62 * S, normal = 70 * S, ch1 = -0.09, ch7 = -0.05, ch30 = -0.04,
        perDay = 400, verdict = "BUY", reason = "Down 9% today and back to normal within 2 days 7 times out of 10.", market = "Busy",
        sell = { 18, 21 }, buy = { 4, 7 }, day = "Sunday", trend = -0.05,
        craft = "Rugged Armor Kit: worth less than the leather.", farm = "Beasts 50+: Un'Goro, Winterspring." },
    [7068] = { name = "Elemental Fire", q = 1, kind = "Elemental", price = 3 * G + 10 * S, normal = 2 * G + 80 * S, ch1 = 0.11, ch7 = 0.13, ch30 = 0.20,
        perDay = 90, verdict = "HOLD", reason = "Fire potions need it before Onyxia's Lair: still climbing.", market = "Healthy",
        sell = { 19, 21 }, buy = { 4, 7 }, day = "Tuesday", trend = 0.24,
        craft = "Greater Fire Protection Potion.", farm = "Fire elementals: Searing Gorge, Burning Steppes." },
    [13926] = { name = "Golden Pearl", q = 2, kind = "Gem", price = 11 * G, normal = 12 * G + 50 * S, ch1 = -0.12, ch7 = -0.08, ch30 = -0.10,
        perDay = 10, verdict = "BUY", reason = "12% under normal: it usually comes back within a week.", market = "Thin",
        sell = { 19, 21 }, buy = { 4, 7 }, day = "Saturday", trend = -0.10,
        craft = "Jewelry later: hold for the next phase.", farm = "Big-mouth Clams: Azshara, Feralas." },
    [12808] = { name = "Essence of Undeath", q = 1, kind = "Reagent", price = 2 * G + 60 * S, normal = 2 * G + 40 * S, ch1 = 0.03, ch7 = 0.06, ch30 = 0.09,
        perDay = 70, verdict = "SELL", reason = "Above normal and sells steadily: no reason to hold.", market = "Healthy",
        sell = { 18, 21 }, buy = { 4, 7 }, day = "Tuesday", trend = 0.08,
        craft = "Flask of Supreme Power, Arcanite transmute fuel.", farm = "Undead 55+: Eastern Plaguelands, Scholomance." },
    [14344] = { name = "Large Brilliant Shard", q = 3, kind = "Enchanting", price = 14 * G, normal = 13 * G, ch1 = 0.02, ch7 = 0.04, ch30 = 0.07,
        perDay = 40, verdict = "SELL", reason = "Up a little and sells every day.", market = "Healthy",
        sell = { 19, 21 }, buy = { 4, 7 }, day = "Wednesday", trend = 0.07,
        craft = "Crusader, Agility to weapon: enchanters buy it.", farm = "Disenchant level 56+ blues." },
}

-- the market list's order: the busiest first
D.order = { 13463, 12363, 10620, 12359, 12360, 13444, 13457, 13510, 13468, 14342, 14047, 8170, 7068, 13926, 12808, 14344 }

-- what "you" own (bags, bank, mail, alts), what you watch
D.holdings = {
    { id = 13463, qty = 400, where = "Bank" }, { id = 12363, qty = 12, where = "Bags" }, { id = 14047, qty = 640, where = "Bank" },
    { id = 13468, qty = 3, where = "Bank alt" }, { id = 10620, qty = 120, where = "Bags" }, { id = 7068, qty = 18, where = "Mail" },
    { id = 14344, qty = 9, where = "Bags" }, { id = 12808, qty = 14, where = "Bags" }, { id = 8170, qty = 60, where = "Bags" },
    { id = 13926, qty = 2, where = "Bags" }, { id = 13444, qty = 20, where = "On the AH" }, { id = 14342, qty = 4, where = "On the AH" },
    { id = 13510, qty = 2, where = "Bank alt" }, { id = 12360, qty = 3, where = "Bank" },
}
D.watch = { 13444, 13457, 13510, 13926 }
D.gold = 1240 * G -- coins on the characters
D.worthLine = { 4040, 4055, 4050, 4080, 4075, 4100, 4098, 4120, 4118, 4140, 4150, 4148, 4170, 4210 } -- 14 days, gold

-- what you own was worth at each of the last 24 price updates (the API's hourly prices and your scans): how much
-- each one moved it, in gold, oldest first. The newest is the update that's on screen now.
D.updateMoves = { 3, -2, 5, 1, -6, 4, 8, -3, 2, 6, -1, 4, -5, 7, 3, 9, -2, 4, 6, -4, 5, 2, -3, 12 }
D.updateEvery = 60 -- minutes between them
D.lastUpdateAgo = 20 -- minutes since the newest

D.characters = {
    { name = "Raja", class = "Rogue", level = 60, gold = 812 * G, seen = "now", profs = "Mining 300, Herbalism 290" },
    { name = "Rajabank", class = "Mage", level = 12, gold = 390 * G, seen = "2 days ago", profs = "—" },
    { name = "Rajalock", class = "Warlock", level = 47, gold = 38 * G, seen = "5 days ago", profs = "Tailoring 220, Enchanting 225" },
}

D.sessions = {
    { name = "Un'Goro ore run", zone = "Un'Goro Crater", minutes = 62, gold = 118 * G, top = 10620, found = 84 },
    { name = "Felwood herbs", zone = "Felwood", minutes = 45, gold = 96 * G, top = 13463, found = 71 },
    { name = "EPL cloth", zone = "Eastern Plaguelands", minutes = 80, gold = 74 * G, top = 14047, found = 210 },
}

-- Your top 3 on Today
D.top = {
    { id = 13463, kind = "SELL", gold = 560 * G, qty = 400, text = "12% above normal, sells ~300 a day. Best around 7 pm." },
    { id = 12363, kind = "HOLD", gold = 458 * G, qty = 12, text = "Still climbing and the raids need it. Sell Dec 5–8." },
    { id = 10620, kind = "FARM", each = 1 * G + 40 * S, text = "Sells ~300 a day. Spots for your level in Un'Goro." },
}

-- Make gold: each section's list (id, kind, gold, text)
D.make = {
    flip = {
        { id = 8170, kind = "BUY", gold = 22 * G, text = "Buy 300 at 62s, back to 70s within 2 days 7 times in 10." },
        { id = 13926, kind = "BUY", gold = 9 * G, text = "Buy 6 under 11g: usually back to 12g 50s within a week." },
        { id = 12359, kind = "WAIT", text = "Cheap but still sliding: wait." },
    },
    craft = {
        { id = 12360, kind = "CRAFT", gold = 6 * G, text = "Transmute today: costs ~39g, sells for 48g." },
        { id = 13510, kind = "CRAFT", gold = 11 * G, text = "Costs ~129g, sells for 148g; 6 sell a day." },
        { id = 13444, kind = "CRAFT", gold = 60 * S, text = "60s a potion, sells 140 a day." },
    },
    farm = {
        { id = 10620, kind = "FARM", each = 1 * G + 40 * S, text = "~300 sell a day. Un'Goro, Burning Steppes." },
        { id = 14047, kind = "FARM", each = 32 * S, text = "~900 sell a day. Humanoids 55+." },
        { id = 13463, kind = "FARM", each = 1 * G + 40 * S, text = "~300 sell a day. Felwood, Un'Goro." },
    },
    raid = {
        { id = 12363, kind = "HOLD", text = "Climbing into the raids: sell Dec 5–8." },
        { id = 13457, kind = "HOLD", text = "Onyxia's Lair: fire resistance sells in raid week." },
        { id = 7068, kind = "HOLD", text = "Fire potions need it: still climbing." },
        { id = 13444, kind = "SELL", text = "Already up 18%: sell into raid nights." },
    },
}

-- crafted items: what goes in (an item id or a name, how many, each), and a note
D.made = {
    [12360] = { mats = { { 12363, 1 }, { 12359, 1 } }, note = "Alchemy transmute, once a day." },
    [13444] = { mats = { { 13463, 3 }, { "Icecap", 2, 45 * S }, { "Crystal Vial", 1, 4 * S } }, note = "Alchemy 295." },
    [13457] = { mats = { { 7068, 1 }, { 13463, 1 }, { "Crystal Vial", 1, 4 * S } }, note = "Alchemy 290." },
    [13510] = { mats = { { "Stonescale Oil", 30, 1 * G }, { "Gromsblood", 10, 50 * S }, { 13468, 1 } }, note = "Alchemy 300." },
    [14342] = { mats = { { "Felcloth", 2, 90 * S } }, note = "Tailoring, every 4 days." },
}

-- materials: the best things they're made into (product, gold one use of it brings), where to farm them
D.crafts = {
    [13463] = { { 13444, 60 * S }, { 13457, 59 * S } },
    [12363] = { { 12360, 6 * G }, { 13510, 0 } },
    [10620] = { { 12359, -23 * S } },
    [12359] = { { 12360, 3 * G } },
    [7068] = { { 13457, 59 * S } },
    [13468] = { { 13510, 11 * G } },
    [14047] = { { "Runecloth Bag", -1 * G } },
    [8170] = { { "Rugged Armor Kit", -40 * S } },
    [12808] = { { "Flask of Supreme Power", 2 * G } },
    [13926] = { { "Jewelry (next phase)", 0 } },
    [14344] = { { "Enchant Weapon: Crusader", 4 * G } },
}
D.spots = {
    [13463] = { { "Felwood", "herb 270+" }, { "Un'Goro Crater", "herb 270+" }, { "Azshara", "herb 270+" } },
    [12363] = { { "Un'Goro Crater", "Rich Thorium veins" }, { "Burning Steppes", "Rich Thorium veins" }, { "Eastern Plaguelands", "Rich Thorium veins" } },
    [10620] = { { "Un'Goro Crater", "mining 245+" }, { "Burning Steppes", "mining 245+" }, { "Winterspring", "mining 245+" } },
    [13468] = { { "Burning Steppes", "rare spawn" }, { "Winterspring", "rare spawn" }, { "Silithus", "rare spawn" } },
    [14047] = { { "Eastern Plaguelands", "humanoids 55+" }, { "Winterspring", "humanoids 55+" }, { "Silithus", "humanoids 55+" } },
    [8170] = { { "Un'Goro Crater", "beasts 50+" }, { "Winterspring", "beasts 50+" }, { "Felwood", "beasts 50+" } },
    [7068] = { { "Searing Gorge", "fire elementals" }, { "Burning Steppes", "fire elementals" }, { "Un'Goro Crater", "fire elementals" } },
    [12808] = { { "Eastern Plaguelands", "undead 55+" }, { "Western Plaguelands", "undead 55+" }, { "Scholomance", "undead" } },
    [13926] = { { "Azshara", "Big-mouth Clams" }, { "Feralas", "Big-mouth Clams" } },
    [14344] = { { "Disenchanting", "blues of level 56+" } },
}

-- how quickly what you hold turns into gold: one seller can take about a fifth of a day's sales
function D.Liquidity(h)
    if h.where == "On the AH" then return "listed" end
    local it = D.items[h.id]
    local days = h.qty / math.max(1, (it.perDay or 1) * 0.2)
    if days <= 1 then return "today" elseif days <= 7 then return "week" end
    return "slow"
end

-- the moves of the day (Today)
D.up = { 13444, 7068, 13463 }
D.down = { 13926, 8170, 12359 }

-- a sample freshness: how old the prices are, in minutes
D.pricesAge = 20

---------------------------------------------------------------------------
-- A made-up 90 days per item (the same every time: a seed from its id) and its price by hour of the day
---------------------------------------------------------------------------
local function Seeded(id)
    local s = id % 2147483647
    return function()
        s = (s * 16807) % 2147483647
        return s / 2147483647
    end
end

function D.History(id, days)
    local it = D.items[id]
    if not it then return {} end
    local rnd = Seeded(id)
    local now = time()
    local start = it.price / (1 + (it.trend or 0))
    local out = {}
    for i = 1, 90 do
        local base = start + (it.price - start) * (i - 1) / 89
        local v = base * (1 + (rnd() - 0.5) * 0.06)
        if i == 90 then v = it.price end
        out[i] = { t = now - (90 - i) * 86400, value = math.floor(v) }
    end
    local from = math.max(1, 90 - (days or 30) + 1)
    local shown = {}
    for i = from, 90 do shown[#shown + 1] = out[i] end
    return shown
end

-- 24 numbers, 0 (its cheapest hour) to 1 (its priciest)
function D.Hours(id)
    local it = D.items[id]
    local out = {}
    for h = 0, 23 do
        local v = 0.45
        if it then
            if h >= it.buy[1] and h < it.buy[2] then v = 0.05
            elseif h >= it.sell[1] and h < it.sell[2] then v = 1
            elseif h == it.sell[1] - 1 or h == it.sell[2] then v = 0.75
            elseif h == it.buy[1] - 1 or h == it.buy[2] then v = 0.22
            elseif h >= 9 and h <= 15 then v = 0.4
            else v = 0.5 end
        end
        out[h + 1] = v
    end
    return out
end
