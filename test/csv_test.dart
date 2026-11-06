import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/providers/task_provider.dart';
import 'package:xunji_checkin/services/csv_export_service.dart';

void main() {
  test('CSV 表头与枚举字段保持英文，跨语言通用', () {
    final provider = TaskProvider();
    String header(CsvKind kind) => CsvExportService.build(
      provider,
      kind,
    ).split('\n').first.replaceFirst('\uFEFF', '');
    expect(
      header(CsvKind.checkins),
      'task_id,task_title,date,completed_at,remark',
    );
    expect(
      header(CsvKind.daily),
      'date,active_tasks,completed,completion_rate,perfect_day',
    );
    expect(
      header(CsvKind.tasks),
      'task_id,title,type,schedule,schedule_params,total_days,current_streak,longest_streak,archived',
    );
    expect(header(CsvKind.tags), 'tag,total_days,average_rate,longest_streak');
    expect(header(CsvKind.periods), 'schedule,tasks,total_days');
  });
}
