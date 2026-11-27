// node tools/test/luacheck.js . : every .lua file parses as Lua 5.1 (needs luaparse: npm i luaparse)
const fs = require("fs"), path = require("path"), lp = require(process.env.LUAPARSE || "luaparse");
let bad = 0;
function walk(d) {
  for (const f of fs.readdirSync(d)) {
    if (f === ".git" || f === "node_modules") continue;
    const p = path.join(d, f);
    if (fs.statSync(p).isDirectory()) walk(p);
    else if (p.endsWith(".lua")) {
      try { lp.parse(fs.readFileSync(p, "utf8"), { luaVersion: "5.1" }); } catch (e) { bad++; console.log(p + ": " + e.message); }
    }
  }
}
walk(process.argv[2] || ".");
console.log(bad ? bad + " file(s) with errors" : "all lua files parse");
process.exit(bad ? 1 : 0);
