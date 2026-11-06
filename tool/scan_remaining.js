const fs = require('fs');
const path = require('path');
const rows = [];
function walk(dir) {
  for (const name of fs.readdirSync(dir)) {
    const p = path.join(dir, name);
    const st = fs.statSync(p);
    if (st.isDirectory()) walk(p);
    else if (p.endsWith('.dart') && !p.includes('l10n') && !path.basename(p).startsWith('app_strings')) {
      const lines = fs.readFileSync(p, 'utf8').split(/\r?\n/);
      lines.forEach((line, idx) => {
        const s = line.trim();
        if (s.startsWith('//') || s.startsWith('///') || s.startsWith('debugPrint')) return;
        const re = /'([^'\\]*(?:\\.[^'\\]*)*)'|"([^"\\]*(?:\\.[^"\\]*)*)"/g;
        let m;
        while ((m = re.exec(line))) {
          const txt = m[1] || m[2] || '';
          if (/[\u4e00-\u9fff]/.test(txt)) rows.push([p, idx + 1, txt]);
        }
      });
    }
  }
}
walk('lib');
const uniq = [...new Set(rows.map(r => r[2]))];
console.log('count', rows.length, 'unique', uniq.length);
for (const [p, i, t] of rows) console.log(`${p}:${i}: ${t}`);
