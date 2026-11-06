const fs = require('fs');
const en = fs.readFileSync('lib/core/app_strings_en.dart', 'utf8');
const keys = [...en.matchAll(/^  '((?:[^'\\]|\\.)*)':/gm)].map((m) => m[1]);
const translated = new Set();
for (const f of ['ja', 'fr', 'es']) {
  const s = fs.readFileSync(`lib/core/app_strings_${f}.dart`, 'utf8');
  for (const m of s.matchAll(/^  '((?:[^'\\]|\\.)*)':/gm)) translated.add(m[1]);
}
const left = keys.filter((k) => k.length > 14 && !translated.has(k));
console.log(left.length);
console.log(left.join('\n'));
