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
const base = {
  en: [allKeys('lib/core/app_strings_en.dart'), allKeys('lib/core/app_strings_generated.dart'), allKeys('lib/core/app_strings_extra.dart'), allKeys('lib/core/app_strings_long.dart'), allKeys('lib/core/app_strings_stats.dart')],
};
const keys = new Set();
for (const f of walk('lib')) {
  const s = fs.readFileSync(f, 'utf8');
  for (const m of s.matchAll(/(?:LText|AppStrings\.tr)\(\s*'((?:[^'\\]|\\.)*)'/g)) {
    const k = m[1].replace(/\\'/g, "'");
    if (/[\u4e00-\u9fff]/.test(k)) keys.add(k);
  }
  for (const m of s.matchAll(/(?:LText|AppStrings\.tr)\(\s*"((?:[^"\\]|\\.)*)"/g)) {
    if (/[\u4e00-\u9fff]/.test(m[1])) keys.add(m[1]);
  }
}
const missing = [...keys].filter((k) => !base.en.some((m) => m[k]));
console.log('han keys', keys.size, 'missing en', missing.length);
missing
  .filter((k) => !k.includes('$') && !k.includes('\n'))
  .forEach((k) => console.log(' ', k));
