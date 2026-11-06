import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:xunji_checkin/models/task.dart';
import 'package:xunji_checkin/providers/task_provider.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

void main() {
  test('real provider on sqlite ffi', () async {
    final tmp = Directory.systemTemp.createTempSync('xunji_promo');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final p = TaskProvider();
    await p.load();
    // ignore: avoid_print
    print('loaded tasks=${p.allTasks.length} loading=${p.isLoading} err=${p.loadError}');

    await p.addTask(title: '冥想 10 分钟', type: TaskType.daily);
    await p.addTask(title: '读 20 页书', type: TaskType.daily);
    await p.addTask(title: '给客户回邮件', type: TaskType.todo, dueDate: p.today);
    // ignore: avoid_print
    print('tasks=${p.allTasks.length} stat=${p.todayStat.completed}/${p.todayStat.total}');
    final first = p.dailyTasks.first;
    await p.toggleDaily(first);
    // ignore: avoid_print
    print('after toggle done=${p.isDailyDone(first)} stat=${p.todayStat.completed}/${p.todayStat.total}');
  });
}
