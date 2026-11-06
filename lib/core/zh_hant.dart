import 'zh_hant_map.dart';

/// 简体中文 → 繁体中文（台湾用语）。
///
/// 先按词替换软件术语（设置→設定、数据→資料…），再按字转换。
/// 生成表来自 `tool/gen_hant_map.js`；App 运行时无额外依赖。
String toTraditionalChinese(String input) {
  var text = input;
  final phrases = zhHantPhrases.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  for (final entry in phrases) {
    if (text.contains(entry.key)) {
      text = text.replaceAll(entry.key, entry.value);
    }
  }
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(zhHantChars[ch] ?? ch);
  }
  return buffer.toString();
}
