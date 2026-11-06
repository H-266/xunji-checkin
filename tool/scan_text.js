const fs = require('fs');
const path = require('path');
const mapSrc = fs.readFileSync('lib/core/app_strings_en.dart', 'utf8');
const keys = new Set(
  [...mapSrc.matchAll(/^  '((?:[^'\\]|\\.)*)':/gm)].map((m) =>
    m[1].replace(/\\'/g, "'"),
  ),
);
const missing = new Set();
function walk(d) {
  for (const f of fs.readdirSync(d)) {
    const p = path.join(d, f);
    const s = fs.statSync(p);
    if (s.isDirectory()) {
      walk(p);
    } else if (
      f.endsWith('.dart') &&
      !['l_text.dart', 'app_strings.dart', 'app_strings_en.dart'].includes(f)
    ) {
      const src = fs.readFileSync(p, 'utf8');
      for (const m of src.matchAll(/\bText\(\s*'((?:[^'\\]|\\.)*)'/g)) {
        const t = m[1].replace(/\\'/g, "'");
        if (!t.includes('$') && !keys.has(t)) missing.add(t);
      }
    }
  }
}
walk('lib');
console.log('keys', keys.size, 'missing', missing.size);
console.log([...missing].join('\n---\n'));
