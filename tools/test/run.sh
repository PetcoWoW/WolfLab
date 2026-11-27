#!/usr/bin/env bash
# Every check: bash tools/test/run.sh. Installs luaparse and lupa the first time. Exit 1 if anything failed.
cd "$(dirname "$0")/../.." || exit 1
T=$(mktemp -d)
npm ls --prefix "$T/n" luaparse >/dev/null 2>&1 || npm i --silent --prefix "$T/n" luaparse >/dev/null 2>&1
export NODE_PATH="$T/n/node_modules"
python3 -c "import lupa" 2>/dev/null || pip install -q lupa --break-system-packages >/dev/null 2>&1 || pip install -q lupa >/dev/null 2>&1
fail=0
line() { printf '%-28s %s\n' "$1" "$2"; }
node tools/test/luacheck.js . >"$T/lc.txt" 2>&1 && line "lua syntax" ok || { line "lua syntax" FAIL; cat "$T/lc.txt"; fail=1; }
node tools/test/audit.js . >"$T/au.txt" 2>&1 && line "audit" ok || { line "audit" FAIL; tail -5 "$T/au.txt"; fail=1; }
for look in classic dark; do for t in 0 1 2; do
  WOLF_LOOK=$look WOLF_TEXT=$t python3 tools/test/labtest.py . >"$T/lt.txt" 2>&1
  e=$(grep -E "errors, " "$T/lt.txt" | tail -1); l=$(grep -E "^layout:" "$T/lt.txt" | tail -1)
  if [[ "$e" == "0 errors, 0 distinct" && "$l" == *"0 overlapping text pairs, 0 texts"* ]]; then line "load test $look, text $t" ok
  else line "load test $look, text $t" FAIL; grep -E "^ERROR|^(OVERLAP|CUT|SPILL|OUT)" "$T/lt.txt" | head -20; fail=1; fi
done; done
rm -rf "$T"
[[ $fail == 0 ]] && echo "ALL GOOD" || echo "SOMETHING FAILED"
exit $fail
