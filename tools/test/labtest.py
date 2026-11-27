# Load Wolf Lab in the fake WoW (wowmock.lua, from Wolf), open every page and popup, click through the folds,
# sections and settings, and print every error plus any text that overlaps, runs out of its frame or is cut short.
# WOLF_LOOK=dark for the dark look, WOLF_TEXT=2 for the largest text.
import sys, os, re
import lupa.lua51 as L51
root = sys.argv[1] if len(sys.argv) > 1 else '.'
here = os.path.dirname(os.path.abspath(__file__))
lua = L51.LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(here, 'wowmock.lua')).read())
lua.execute(open(os.path.join(here, 'layout.lua')).read())
toc = [l.strip().replace('\\', '/') for l in open(os.path.join(root, 'WolfLab.toc')) if l.strip() and not l.startswith('#')]
loader = lua.eval('''function(src, name, ns)
  local f, e = loadstring(src, "@" .. name)
  if not f then mock.err("load " .. name, e) return end
  mock.call("run " .. name, f, "WolfLab", ns)
end''')
look, text = os.environ.get('WOLF_LOOK', 'classic'), os.environ.get('WOLF_TEXT', '0')
lua.execute('WolfLabDB = { settings = { look = "%s", textSize = %s } }' % (look, text))
ns = lua.eval('{}')
for f in toc:
    loader(open(os.path.join(root, f), encoding='utf-8').read(), f, ns)
lua.execute('''
mock.fire("ADDON_LOADED", "WolfLab")
mock.fire("PLAYER_LOGIN")
mock.fire("PLAYER_ENTERING_WORLD", true, false)
mock.run(2)
''')
script = r'''
local FT = ...
local function step(name, fn) mock.call("step " .. name, fn) end
local seen, overlaps, cuts = {}, 0, 0
local function check(key, root)
  mock.layout.Settle(root)
  mock.run(0.5)
  mock.layout.Settle(root)
  local found, texts = mock.layout.Overlaps(root)
  for _, t in ipairs(texts) do
    if not t.f.__tape then for _, kind in ipairs({ "out", "spill", "cut" }) do
      if t[kind] and not seen[kind .. "|" .. t.text] then
        seen[kind .. "|" .. t.text] = true
        cuts = cuts + 1
        print(string.format("%s [%s] %q  in %s", kind:upper(), key, t.text:sub(1, 70), mock.layout.Where(t.f)))
      end
    end end
  end
  for _, o in ipairs(found) do
    local k = o[1].text .. "|" .. o[2].text
    if not seen[k] then
      seen[k] = true
      overlaps = overlaps + 1
      print(string.format("OVERLAP [%s] %q x %q (%dx%d px)  in %s", key, o[1].text:sub(1, 50), o[2].text:sub(1, 50), o[3], o[4], mock.layout.Where(o[1].f)))
    end
  end
end

step("slash", function() SlashCmdList["WOLFLAB"]("") end)
mock.run(1)
for _, key in ipairs({ "today", "market", "make", "you", "settings" }) do
  step("page " .. key, function() FT.Show(key) end)
  mock.run(0.5)
  check(key, WolfLabFrame)
end
for _, v in ipairs({ "flip", "craft", "farm", "coming" }) do
  step("make " .. v, function() FT.Show("make"); FT.Pages.make.seg.buttons[1].onClick() end)
  step("make view " .. v, function()
    for _, b in ipairs(FT.Pages.make.seg.buttons) do if b.value == v then b.onClick() end end
  end)
  mock.run(0.3)
  check("make " .. v, WolfLabFrame)
end
for _, v in ipairs({ "holdings", "sessions", "chars" }) do
  step("you " .. v, function()
    FT.Show("you")
    for _, b in ipairs(FT.Pages.you.seg.buttons) do if b.value == v then b.onClick() end end
  end)
  mock.run(0.3)
  check("you " .. v, WolfLabFrame)
end
-- every item's page, every fold open in turn, every range
for _, id in ipairs(FT.Data.order) do
  step("item " .. id, function() FT.Lab.OpenItem(id) end)
  mock.run(0.2)
  check("item " .. id, WolfLabFrame)
  -- a crafted item: Craft it, never Best crafts or Where to farm; a material: never Craft it
  local titles = {}
  for _, f in ipairs(FT.Pages.market.item.folds.secs) do
    if f:IsShown() then
      titles[#titles + 1] = f.title:GetText()
      -- a list section: every line the same size
      if f.title:GetText() == "Where to farm" or f.title:GetText() == "Best crafts" or f.title:GetText() == "Craft it" then
        local _, size = f.sum:GetFont()
        for _, t in ipairs(f.more) do
          if t:IsShown() then
            local _, s2 = t:GetFont()
            if s2 ~= size then mock.err("sizes " .. id, f.title:GetText() .. ": lines at " .. tostring(size) .. " and " .. tostring(s2)) end
          end
        end
      end
    end
  end
  local t = table.concat(titles, ",")
  if FT.Data.items[id].made then
    if t:find("Best crafts") or t:find("Where to farm") or not t:find("Craft it") then mock.err("sections " .. id, "crafted item shows: " .. t) end
  elseif t:find("Craft it") then mock.err("sections " .. id, "material shows: " .. t) end
end
for _, r in ipairs({ "7D", "30D", "90D" }) do
  step("range " .. r, function()
    for _, b in ipairs(FT.Pages.market.item.range.buttons) do if b.value == r then b.onClick() end end
  end)
end
step("watch", function() FT.Lab.ToggleWatch(12363); FT.Lab.ToggleWatch(13463) end)
step("watchlist filter", function()
  for _, b in ipairs(FT.Pages.market.item and {} or {}) do end
  FT.Show("market")
end)
step("search", function() FT.Pages.market.FillList() end)
step("share", function() FT.Lab.Share(12363) end)
step("wowhead", function() FT.Lab.Wowhead(12363) end)
check("link box", WolfLabLink)
-- When it sells, then with its charts
step("when it sells", function() FT.WhenSells.Open(12363) end)
mock.run(0.3)
check("when it sells", WolfLabWhenSells)
step("when charts", function() WolfLabWhenSells.toggle.onClick() end)
check("when it sells + charts", WolfLabWhenSells)
for _, id in ipairs(FT.Data.order) do step("when " .. id, function() FT.WhenSells.Open(id) end) end
-- meme words on, every page again
step("meme on", function() FT.S.meme = true; FT.RefreshAll() end)
for _, key in ipairs({ "today", "market", "make", "you" }) do
  step("meme page " .. key, function() FT.Show(key) end)
  check("meme " .. key, WolfLabFrame)
end
-- the sample session: open, folded, unfolded, from Today's button and the minimap's right-click
-- Today's movers both ways
-- Today's bottom row, left to right: In your bags, Going down, Going up; each with rows
step("today row", function()
  FT.Show("today")
  local T = FT.Pages.today
  local order = { { T.bags, "In your bags" }, { T.down, "Going down today" }, { T.up, "Going up today" } }
  local lastX = -1
  for _, o in ipairs(order) do
    local x = mock.layout.Rect(o[1])[1]
    if o[1].title:GetText() ~= o[2] then mock.err("today row", "card says " .. tostring(o[1].title:GetText())) end
    if x <= lastX then mock.err("today row", o[2] .. " is out of order") end
    if #o[1].list.items == 0 then mock.err("today row", o[2] .. " is empty") end
    lastX = x
  end
  for _, id in ipairs(T.down.list.items) do if FT.Data.items[id].ch1 >= 0 then mock.err("today row", "a riser in Going down") end end
end)
-- You: the donut, both views, every slice picked and picked again
for _, v in ipairs({ "where", "liquid" }) do
  step("donut view " .. v, function()
    FT.Show("you")
    for _, b in ipairs(FT.Pages.you.donutBox.seg.buttons) do if b.value == v then b.onClick() end end
  end)
  check("donut " .. v, WolfLabFrame)
  for _, sl in ipairs(FT.Pages.you.donut.slices) do
    step("pick " .. sl.key, function() FT.Pages.you.donut:Pick(sl.key) end)
    check("donut " .. v .. " " .. sl.key, WolfLabFrame)
    if #FT.Pages.you.holdings.list.items == 0 then mock.err("donut", "slice " .. sl.key .. " shows no rows") end
    step("unpick " .. sl.key, function() FT.Pages.you.donut:Pick(sl.key) end)
  end
  step("legend click", function() local r = FT.Pages.you.donutBox.legend[2]; r:GetScript("OnClick")(r) end)
  step("donut hover", function() local dn = FT.Pages.you.donut; dn.hover = dn.slices[1].key; dn:Draw() end)
end
step("session start", function() FT.Session.Start() end)
mock.run(65)
check("session", WolfLabSession)
step("session fold", function() WolfLabSession.fold.onClick() end)
mock.run(1.5)
check("session folded", WolfLabSession)
if WolfLabSession.body:IsShown() then mock.err("session", "folded but the items still show") end
step("session unfold", function() WolfLabSession.fold.onClick() end)
mock.run(1.5)
if not WolfLabSession.body:IsShown() then mock.err("session", "unfolded but the items are hidden") end
check("today, session running", WolfLabFrame)
step("minimap stop", function() WolfLabMinimapButton:GetScript("OnClick")(WolfLabMinimapButton, "RightButton") end)
if FT.Session.Running() then mock.err("minimap", "right-click didn't stop the session") end
step("minimap open", function() WolfLabFrame:Hide(); WolfLabMinimapButton:GetScript("OnClick")(WolfLabMinimapButton, "LeftButton") end)
if not WolfLabFrame:IsShown() then mock.err("minimap", "click didn't open the window") end
step("minimap tip", function() WolfLabMinimapButton:GetScript("OnEnter")(WolfLabMinimapButton) end)
step("reset", function() SlashCmdList["WOLFLAB"]("reset") end)
step("toggle", function() SlashCmdList["WOLFLAB"]("") end)
step("logout", function() mock.fire("PLAYER_LOGOUT") end)
print(string.format("layout: %d overlapping text pairs, %d texts cut short or out of their frame", overlaps, cuts))
'''
lua.execute('return function(...) ' + script + ' end')(ns)
errs = list(lua.eval('mock.errors').values())
seen = set()
for e in errs:
    key = e.split('\n')[0]
    if key in seen: continue
    seen.add(key)
    print('ERROR', e[:1500]); print('---')
print(len(errs), 'errors,', len(seen), 'distinct')
for p in list(lua.eval('mock.prints').values())[:10]:
    print('  chat:', re.sub(r'\|c\w{8}|\|r', '', p)[:200])
