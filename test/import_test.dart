import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/services/import_service.dart';

Map<String, Object?> _backup() => {
  'app': '循记打卡',
  'format_version': 1,
  'exported_at': '2026-11-06T00:00:00.000Z',
  'tasks': [
    {
      'id': 1,
      'title': '喝水',
      'type': 'daily',
      'created_at': 1762300800000,
      'completed_at': null,
      'archived_at': null,
      'sort_order': 0,
    },
  ],
  'checkins': [
    {'task_id': 1, 'date': '2026-11-06', 'completed_ts': 1762300800000},
  ],
  'settings': {'heatmap_hue': '220'},
  'tags': [],
};

void main() {
  test('接受最小合法备份', () {
    final preview = ImportService.parse(jsonEncode(_backup()));
    expect(preview.tasks, hasLength(1));
    expect(preview.checkins, hasLength(1));
    expect(preview.settings['heatmap_hue'], '220');
  });

  test('拒绝非 JSON', () {
    expect(
      () => ImportService.parse('not json'),
      throwsA(isA<ImportException>()),
    );
  });

  test('拒绝错误 format_version', () {
    final raw = _backup()..['format_version'] = 99;
    expect(
      () => ImportService.parse(jsonEncode(raw)),
      throwsA(isA<ImportException>()),
    );
  });

  test('拒绝引用不存在任务的打卡', () {
    final raw = _backup();
    (raw['checkins'] as List).first['task_id'] = 999;
    expect(
      () => ImportService.parse(jsonEncode(raw)),
      throwsA(isA<ImportException>()),
    );
  });

  test('拒绝非法日期', () {
    final raw = _backup();
    (raw['checkins'] as List).first['date'] = '2026-02-30';
    expect(
      () => ImportService.parse(jsonEncode(raw)),
      throwsA(isA<ImportException>()),
    );
  });
}
