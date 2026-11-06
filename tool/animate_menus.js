const fs = require('fs');
const path = require('path');

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(p);
    } else if (p.endsWith('.dart')) {
      let s = fs.readFileSync(p, 'utf8');
      const before = s;
      s = s.replace(/\bshowDialog\s*</g, 'showAppDialog<');
      s = s.replace(/\bshowDialog\s*\(/g, 'showAppDialog(');
      s = s.replace(/\bshowModalBottomSheet\s*</g, 'showAppSheet<');
      s = s.replace(/\bshowModalBottomSheet\s*\(/g, 'showAppSheet(');
      if (s !== before && !s.includes("import '../core/app_motion.dart';")) {
        s = s.replace(/^(import .*?;\n)/m, "$1import '../core/app_motion.dart';\n");
      }
      if (s !== before) fs.writeFileSync(p, s);
    }
  }
}

walk('lib');
