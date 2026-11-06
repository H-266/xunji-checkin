const fs = require('fs');
const s = fs.readFileSync('lib/core/app_strings_en.dart', 'utf8');
const rows = [...s.matchAll(/^  '((?:[^'\\]|\\.)*)':/gm)].map((m) => m[1]);
const short = rows.filter((x) => x.length <= 10);
console.log(short.length);
console.log(short.join('\n'));
