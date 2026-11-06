const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const dart = fs.readFileSync(path.join(root, 'lib/core/zh_hant_map.dart'), 'utf8');
const sections = dart.split('zhHantChars');
function parseMap(text) {
  const out = {};
  const re = /'((?:\\.|[^'])*)': '((?:\\.|[^'])*)'/g;
  let m;
  while ((m = re.exec(text))) {
    const dec = (s) => s.replace(/\\'/g, "'").replace(/\\\\/g, '\\');
    out[dec(m[1])] = dec(m[2]);
  }
  return out;
}
const phrases = parseMap(sections[0]);
const chars = parseMap(sections[1] || '');
const ordered = Object.entries(phrases).sort((a, b) => b[0].length - a[0].length);

function convert(input) {
  let text = input;
  for (const [from, to] of ordered) {
    if (text.includes(from)) text = text.split(from).join(to);
  }
  return [...text].map((ch) => chars[ch] || ch).join('');
}

module.exports = { convert, phrases, chars };
