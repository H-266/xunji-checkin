const fs = require('fs');
const path = require('path');

function walk(dir) {
  for (const name of fs.readdirSync(dir)) {
    const p = path.join(dir, name);
    if (fs.statSync(p).isDirectory()) continue;
    if (!p.endsWith('.dart') || name === 'l_text.dart') continue;
    let src = fs.readFileSync(p, 'utf8');
    const before = (src.match(/(?<![\w.])Text\(/g) || []).length;
    if (!before) continue;
    src = src.replace(/(?<![\w.])Text\(/g, 'LText(');
    if (!src.includes('l_text.dart')) {
      const imp = dir.endsWith('screens') ? "import '../widgets/l_text.dart';" : "import 'l_text.dart';";
      const idx = src.lastIndexOf('\nimport ');
      const end = src.indexOf('\n', idx + 1);
      src = src.slice(0, end + 1) + imp + '\n' + src.slice(end + 1);
    }
    fs.writeFileSync(p, src, 'utf8');
    console.log(p, before);
  }
}
walk('lib/screens');
walk('lib/widgets');
