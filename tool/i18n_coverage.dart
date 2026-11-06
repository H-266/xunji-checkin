import 'dart:io';

import 'package:xunji_checkin/core/app_strings.dart';

final _reSingle = RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'");
final _reDouble = RegExp(r'"([^"\\]*(?:\\.[^"\\]*)*)"');
final _han = RegExp(r'[\u4e00-\u9fff]');

String _jsonString(String s) {
  final b = StringBuffer('"');
  for (final r in s.runes) {
    switch (r) {
      case 0x22:
        b.write(r'\"');
      case 0x5c:
        b.write(r'\\');
      case 0x0a:
        b.write(r'\n');
      case 0x0d:
        b.write(r'\r');
      case 0x09:
        b.write(r'\t');
      default:
        b.writeCharCode(r);
    }
  }
  b.write('"');
  return b.toString();
}

void main() {
  final rows = <String, Set<String>>{};
  final dir = Directory('lib');
  for (final e in dir.listSync(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    if (e.path.contains('l10n') || e.path.contains('app_strings')) continue;
    final lines = e.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final s = lines[i].trim();
      if (s.startsWith('//') || s.startsWith('///') || s.startsWith('debugPrint')) continue;
      for (final re in [_reSingle, _reDouble]) {
        for (final m in re.allMatches(lines[i])) {
          final text = m.group(1) ?? '';
          if (!_han.hasMatch(text)) continue;
          rows.putIfAbsent(text, () => <String>{}).add('${e.path}:${i + 1}');
        }
      }
    }
  }
  final langs = ['en', 'ja', 'fr', 'es'];
  final missing = <String, List<String>>{for (final l in langs) l: <String>[]};
  for (final text in rows.keys) {
    for (final lang in langs) {
      AppStrings.languageCode = lang;
      final translated = AppStrings.tr(text);
      if (translated.trim().isEmpty || translated == text) {
        missing[lang]!.add(text);
      }
    }
  }
  AppStrings.languageCode = 'zh';
  print('unique=${rows.length}');
  for (final l in langs) {
    print('$l missing=${missing[l]!.length}');
  }
  for (final l in langs) {
    if (missing[l]!.isNotEmpty) {
      print('--- $l missing ---');
      for (final t in missing[l]!) {
        print(t);
      }
    }
  }
  final all = <String>{};
  for (final l in langs) all.addAll(missing[l]!);
  final ordered = all.toList()..sort();
  File('tool/i18n_missing.json').writeAsStringSync(
    '[${ordered.map((e) => _jsonString(e)).join(',')}]',
  );
  print('union=${ordered.length}');
  for (final t in ordered.take(250)) {
    print(t);
  }
}
