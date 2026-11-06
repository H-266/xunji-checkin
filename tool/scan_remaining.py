import re
import pathlib

rows = []
for p in pathlib.Path('lib').rglob('*.dart'):
    parts = set(p.parts)
    if 'l10n' in parts:
        continue
    if p.name.startswith('app_strings'):
        continue
    for i, line in enumerate(p.read_text(encoding='utf-8').splitlines(), 1):
        s = line.strip()
        if s.startswith('//') or s.startswith('///') or s.startswith('debugPrint'):
            continue
        for m in re.finditer(r"'([^'\\]*(?:\\.[^'\\]*)*)'|\"([^\"\\]*(?:\\.[^\"\\]*)*)\"", line):
            txt = m.group(1) or m.group(2) or ''
            if re.search(r'[\u4e00-\u9fff]', txt):
                rows.append((str(p), i, txt))
print('count', len(rows), 'unique', len(set(r[2] for r in rows)))
for p, i, t in rows:
    print(f'{p}:{i}: {t}')
