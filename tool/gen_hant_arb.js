const fs = require('fs');
const path = require('path');
const { convert } = require('./hant_convert');

const root = path.resolve(__dirname, '..');
const zh = JSON.parse(fs.readFileSync(path.join(root, 'lib/l10n/app_zh.arb'), 'utf8'));
const out = { '@@locale': 'zh_Hant' };
for (const [key, value] of Object.entries(zh)) {
  if (key === '@@locale') continue;
  out[key] = typeof value === 'string' ? convert(value) : value;
}
fs.writeFileSync(
  path.join(root, 'lib/l10n/app_zh_Hant.arb'),
  JSON.stringify(out, null, 2) + '\n',
  'utf8',
);
console.log('wrote zh_Hant ARB', Object.keys(out).length - 1);
