const fs = require('fs');
const path = require('path');

const files = [
  'lib/screens/batch_manage_screen.dart',
  'lib/screens/heatmap_screen.dart',
  'lib/screens/settings_screen.dart',
  'lib/screens/tag_management_screen.dart',
  'lib/screens/task_search_screen.dart',
  'lib/screens/today_screen.dart',
  'lib/screens/widget_config_screen.dart',
  'lib/widgets/onboarding_overlay.dart',
];

function ensureImport(src) {
  if (src.includes("core/app_strings.dart")) return src;
  const lines = src.split('\n');
  let idx = lines.findIndex((l) => l.startsWith('import '));
  if (idx < 0) return src;
  lines.splice(idx, 0, "import '../core/app_strings.dart';");
  return lines.join('\n');
}

for (const rel of files) {
  const full = path.join(__dirname, '..', rel);
  let src = fs.readFileSync(full, 'utf8');
  const before = src;
  src = src.replace(/(labelText|hintText|helperText): '([^'\n]*[一-鿿][^'\n]*)'/g,
    (m, prop, text) => `${prop}: AppStrings.tr('${text}')`);
  if (src !== before) {
    src = src.replace(/decoration: const InputDecoration\(/g, 'decoration: InputDecoration(');
    src = ensureImport(src);
    fs.writeFileSync(full, src, 'utf8');
    console.log('localized props', rel);
  }
}
