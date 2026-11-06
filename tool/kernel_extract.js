const fs = require('fs');
const path = require('path');
const kernelPath = 'C:/kernel_good.bin';
const outRoot = 'C:/xunji_recovered';
const b = fs.readFileSync(kernelPath);
const marker = Buffer.from('file:///V:/lib/', 'utf8');

const best = new Map();
let at = 0;
while ((at = b.indexOf(marker, at)) >= 0) {
  let end = at + marker.length;
  while (end < b.length && b[end] >= 0x20 && b[end] < 0x80) end++;
  const rel = b.subarray(at + marker.length, end).toString('utf8');
  if (!rel.includes('.dart') || rel.includes('://')) {
    at += marker.length;
    continue;
  }

  const limit = Math.min(b.length, end + 500);
  let start = -1;
  for (const token of [Buffer.from("import '"), Buffer.from('//'), Buffer.from('library')]) {
    const i = b.indexOf(token, end);
    if (i >= 0 && i < limit && (start < 0 || i < start)) start = i;
  }
  if (start < 0) {
    at += marker.length;
    continue;
  }

  let stop = start;
  while (stop < b.length) {
    const c = b[stop];
    const ok =
      c === 9 ||
      c === 10 ||
      c === 13 ||
      (c >= 0x20 && c !== 0x7f) ||
      c >= 0x80;
    if (!ok) break;
    stop++;
  }

  let raw = b.subarray(start, stop).toString('utf8');
  const lastBrace = raw.lastIndexOf('}');
  if (lastBrace < 0) {
    at += marker.length;
    continue;
  }
  raw = raw.slice(0, lastBrace + 1) + '\n';
  if (raw.length < 1000) {
    at += marker.length;
    continue;
  }

  const old = best.get(rel);
  if (!old || old.length < raw.length) best.set(rel, raw);
  at += marker.length;
}

for (const [rel, src] of best) {
  const target = path.join(outRoot, rel);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, src, 'utf8');
  console.log('OK', rel, src.length);
}
console.log('recovered', best.size);
