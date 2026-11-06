const fs = require('fs');
const path = require('path');

function walk(d, out = []) {
  for (const f of fs.readdirSync(d)) {
    const p = path.join(d, f);
    const s = fs.statSync(p);
    if (s.isDirectory()) walk(p, out);
    else if (f.endsWith('.dart')) out.push(p);
  }
  return out;
}

for (const p of walk('lib')) {
  if (p.endsWith('l_text.dart')) continue;
  let src = fs.readFileSync(p, 'utf8');
  let changed = false;
  src = src.replace(/(?<![A-Za-z0-9_.])Text\(\s*'/g, (m) => {
    changed = true;
    return m.replace('Text(', 'LText(');
  });
  if (!changed) continue;
  const isScreens = p.includes(`${path.sep}screens${path.sep}`);
  const isWidgets = p.includes(`${path.sep}widgets${path.sep}`);
  const importLine = isScreens
    ? "import '../widgets/l_text.dart';"
    : isWidgets
    ? "import 'l_text.dart';"
    : "import 'widgets/l_text.dart';";
  if (!src.includes(importLine)) {
    const imports = [...src.matchAll(/^import .*;$/gm)];
    if (imports.length) {
      const last = imports[imports.length - 1];
      const at = last.index + last[0].length;
      src = src.slice(0, at) + '\n' + importLine + src.slice(at);
    } else {
      src = importLine + '\n' + src;
    }
  }
  fs.writeFileSync(p, src, 'utf8');
  console.log('wrapped', p);
}
