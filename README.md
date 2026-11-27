# Wolf Lab

A preview of [Wolf](https://github.com/PetcoWoW/ForeverTrading)'s next look, for WoW Forever, with **sample data only**.
Click through the new screens in game before they ship in Wolf.

- **Install:** WowUp → Get Addons → Install from URL → `https://github.com/PetcoWoW/WolfLab`
- **Open:** `/wolflab` (`/wolflab reset` puts the window back in the middle)
- **Safe next to Wolf:** its own folder, saved data (`WolfLabDB`) and frame names. It reads nothing from the auction
  house, your bags, mail or other addons, and sends nothing. Delete it any time.

## What's in it

- **Today:** what you own is worth, Your top 3, what's going up and down today.
- **Market:** the list on the left; an item's page with the verdict first, the chart (7D / 30D / 90D), and five
  folds that show their answer while closed. Watch, Wowhead, Share.
- **When it sells:** when to sell, when to buy, the busiest day, one hour-by-hour strip; the charts on request.
- **Make gold:** Flip it, Craft it, Farm it, Raid prep.
- **You:** Holdings (each with its verdict), Sessions, Characters.
- **Settings:** look, text size, meme words.

Six verdicts everywhere: BUY, SELL, HOLD, WAIT, CRAFT, FARM.

## Checks

`bash tools/test/run.sh`: Lua syntax, an audit, and a load test in a fake WoW (from Wolf's tools) in both looks and
every text size, failing on any error or overlapping or cut text. Every push to main runs it, then publishes a
release WowUp picks up.

UI code (`UI/Theme.lua`, `UI/Widgets.lua`, `UI/Chart.lua`) and the test tools come from Wolf (Apache-2.0); the
font is Sofia Sans Condensed (SIL Open Font License, `media/SofiaSansCondensed-OFL.txt`).
