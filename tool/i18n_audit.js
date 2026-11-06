const fs = require('fs');
function allKeys(file) {
  const s = fs.readFileSync(file, 'utf8');
  const o = {};
  const re = /(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)')\s*:/g;
  let x;
  while ((x = re.exec(s))) {
    const k = x[1] !== undefined ? x[1] : x[2];
    o[k.replace(/\\'/g, "'").replace(/\\"/g, '"').replace(/\\\\/g, '\\')] = 1;
  }
  return o;
}
function walk(d) {
  let o = [];
  for (const f of fs.readdirSync(d)) {
    const p = d + '/' + f;
    if (fs.statSync(p).isDirectory()) o = o.concat(walk(p));
    else if (p.endsWith('.dart')) o.push(p);
  }
  return o;
}
const gen = allKeys('lib/core/app_strings_generated.dart');
const base = {
  en: allKeys('lib/core/app_strings_en.dart'),
  ja: allKeys('lib/core/app_strings_ja.dart'),
  fr: allKeys('lib/core/app_strings_fr.dart'),
  es: allKeys('lib/core/app_strings_es.dart'),
};
const extra = allKeys('lib/core/app_strings_extra.dart');
const long = allKeys('lib/core/app_strings_long.dart');
const stats = allKeys('lib/core/app_strings_stats.dart');
const maps = {
  en: [base.en, extra, long, stats, gen],
  ja: [base.ja, extra, long, stats, gen],
  fr: [base.fr, extra, long, stats, gen],
  es: [base.es, extra, long, stats, gen],
};
const keys = new Set();
for (const f of walk('lib')) {
  const s = fs.readFileSync(f, 'utf8');
  for (const m of s.matchAll(/AppStrings\.tr\(\s*'((?:[^'\\]|\\.)*)'/g)) keys.add(m[1].replace(/\\'/g, "'"));
  for (const m of s.matchAll(/AppStrings\.tr\(\s*"((?:[^"\\]|\\.)*)"/g)) keys.add(m[1]);
}
const missing = { en: [], ja: [], fr: [], es: [] };
for (const k of keys) for (const l of ['en', 'ja', 'fr', 'es']) if (!maps[l].some((m) => m[k])) missing[l].push(k);
console.log('generated keys', Object.keys(gen).length, 'AppStrings.tr keys', keys.size);
for (const l of ['en', 'ja', 'fr', 'es']) {
  console.log('\nMISSING', l, missing[l].length);
  missing[l].slice(0, 80).forEach((k) => console.log(' ', k));
}
