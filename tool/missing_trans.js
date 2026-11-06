const fs = require('fs');
function keys(l) {
  const s = fs.readFileSync(`lib/core/app_strings_${l}.dart`, 'utf8');
  return new Set(
    [...s.matchAll(/^  '((?:[^'\\]|\\.)*)':/gm)].map((m) =>
      m[1].replace(/\\'/g, "'"),
    ),
  );
}
const en = keys('en');
for (const l of ['ja', 'fr', 'es']) {
  const k = keys(l);
  console.log(l, [...en].filter((x) => !k.has(x)));
}
