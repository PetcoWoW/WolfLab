// Static audit of a WoW addon: module functions called but never defined, globals written, globals read.
const fs = require('fs'), path = require('path'), lp = require(process.env.LUAPARSE || 'luaparse');
const root = process.argv[2];
const toc = fs.readFileSync(path.join(root, (process.env.TOC || 'WolfLab.toc')), 'utf8').split(/\r?\n/)
  .filter(l => l && !l.startsWith('#')).map(l => l.replace(/\\/g, '/'));
const defs = new Set(), uses = [], gWrites = [], gReads = new Map(), early = [];
const MODS = /^(FT|UI|L)$/;
function memberName(n) { // FT.X or FT.Y.Z -> "FT.X" / "FT.Y.Z"
  const parts = [];
  while (n && n.type === 'MemberExpression' && n.indexer === '.') { parts.unshift(n.identifier.name); n = n.base; }
  if (n && n.type === 'Identifier') { parts.unshift(n.name); return parts.join('.'); }
  return null;
}
for (const f of toc) {
  const src = fs.readFileSync(path.join(root, f), 'utf8');
  const ast = lp.parse(src, { luaVersion: '5.1', scope: true, locations: true });
  // local module aliases: local X = FT.Something / local X = {} ; FT.Something = X
  const alias = {};
  // names this file declares as locals anywhere (top level or nested): read as a global somewhere, one of them is
  // being used above its declaration - nil there (ShownDeals, Closed: both errored in game)
  const localNames = new Set();
  const fileReads = [];
  const walk = (n, parent) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(c => walk(c, parent)); return; }
    if (n.type === 'LocalStatement') n.variables.forEach(v => localNames.add(v.name));
    if (n.type === 'FunctionDeclaration' && n.isLocal && n.identifier && n.identifier.type === 'Identifier') localNames.add(n.identifier.name);
    if (n.type === 'LocalStatement') {
      n.variables.forEach((v, i) => { const init = n.init[i]; const m = init && memberName(init); if (m && /^FT\./.test(m)) alias[v.name] = m; });
    }
    if (n.type === 'AssignmentStatement') {
      n.variables.forEach((v, i) => {
        const m = memberName(v); if (m) defs.add(m.replace(/^(\w+)/, (a) => alias[a] || a));
        const init = n.init[i];
        if (m && /^FT\./.test(m) && init && init.type === 'Identifier') alias[init.name] = m;
        if (v.type === 'Identifier' && v.isLocal === false) gWrites.push(`${f}:${v.loc.start.line} ${v.name}`);
      });
    }
    if (n.type === 'FunctionDeclaration' && n.identifier) {
      const id = n.identifier;
      if (id.type === 'MemberExpression') { const m = memberName(id.indexer === ':' ? id.base : id); if (m) defs.add((id.indexer === ':' ? m + '.' + id.identifier.name : m).replace(/^(\w+)/, (a) => alias[a] || a)); }
      else if (id.type === 'Identifier' && id.isLocal === false) gWrites.push(`${f}:${id.loc.start.line} function ${id.name}`);
    }
    if (n.type === 'CallExpression') {
      const m = memberName(n.base);
      if (m && m.includes('.')) uses.push({ name: m.replace(/^(\w+)/, (a) => alias[a] || a), at: `${f}:${n.loc.start.line}` });
    }
    if (n.type === 'Identifier' && n.isLocal === false && parent !== 'skip') {
      gReads.set(n.name, (gReads.get(n.name) || 0) + 1);
      fileReads.push({ name: n.name, line: n.loc.start.line });
    }
    for (const k of Object.keys(n)) if (k !== 'loc' && k !== 'range') walk(n[k], n.type === 'MemberExpression' && k === 'identifier' ? 'skip' : n);
  };
  walk(ast.body);
  for (const r of fileReads) if (localNames.has(r.name)) early.push(`${f}:${r.line} ${r.name}`);
}
const missing = {};
for (const u of uses) {
  if (!/^FT\.|^UI\./.test(u.name)) continue;
  if (defs.has(u.name)) continue;
  (missing[u.name] = missing[u.name] || []).push(u.at);
}
console.log('== called, never defined (FT./UI.):');
for (const [k, v] of Object.entries(missing)) console.log(' ', k, v.slice(0, 3).join(' '));
console.log('== global writes:'); gWrites.forEach(w => console.log(' ', w));
console.log('== global reads:'); console.log([...gReads.keys()].sort().join(' '));
// a lowercase global read is almost always a local used before its declaration (WoW's globals are CamelCase or
// UPPER_CASE; Lua's own are listed)
const LUA = new Set(['ipairs','pairs','next','pcall','xpcall','select','type','tostring','tonumber','unpack','math','string',
  'table','setmetatable','getmetatable','rawset','rawget','rawequal','date','time','error','assert','print','wipe','tinsert',
  'tremove','strsplit','strjoin','strtrim','hooksecurefunc','geterrorhandler','collectgarbage','debugprofilestop','loadstring',
  'format','floor','ceil','abs','max','min','sort','debugstack','securecall','issecurevariable','_G','coroutine','bit','strlower','strupper']);
const odd = [...gReads.keys()].filter(n => (/^[a-z]/.test(n) && !LUA.has(n)) || ['L', 'UI', 'FT', 'T'].includes(n));
if (odd.length) { console.log('== SUSPICIOUS (lowercase globals: a local used before it is declared?): ' + odd.join(' ')); process.exitCode = 1; }

if (early.length) { console.log('== USED BEFORE DECLARED (a global read of a name the same file makes local): ' + early.join('  ')); process.exitCode = 1; }
// a global written that isn't the saved data or a slash command: a local lost its declaration (menu, menuBlock)
const ALLOWED_WRITE = /^(WolfLabDB|SLASH_\w+|BINDING_\w+)$/;
const badWrites = gWrites.filter(w => !ALLOWED_WRITE.test(w.split(' ').pop()));
if (badWrites.length) { console.log('== UNEXPECTED GLOBAL WRITES: ' + badWrites.join('  ')); process.exitCode = 1; }
