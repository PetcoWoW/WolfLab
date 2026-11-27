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
for _, v in ipairs({ "flip", "craft", "farm", "raid" }) do
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
  for _, f in ipairs(FT.Pages.market.item.folds.folds) do
    step("fold " .. f.key, function() f:GetScript("OnClick")(f) end)
    check("item " .. id .. " fold " .. f.key, WolfLabFrame)
  end
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
