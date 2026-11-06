import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/tag.dart';
import '../models/task.dart';

/// SQLite 单例。
///
/// 数据库放在应用私有目录，不申请任何存储权限。
/// 删除任务只写 archived_at（软归档），不做 DELETE，保证历史统计完整。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'xunji_checkin.db';

  /// v5：标签支持置顶；旧库通过 onUpgrade 原地迁移。
  static const int _dbVersion = 5;

  Database? _database;
  Future<Database>? _opening;

  /// 并发安全地拿到数据库连接。
  ///
  /// 启动时 SettingsProvider 和 TaskProvider 会同时加载数据；
  /// 如果这里不锁住首次 open，两个 Future 可能各打开一次数据库。
  Future<Database> get database {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return Future<Database>.value(existing);
    }
    return _opening ??= _openOnce();
  }

  Future<Database> _openOnce() async {
    try {
      final opened = await _open();
      _database = opened;
      return opened;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$_dbName';

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // 保证 checkins.task_id 的外键约束生效。
        await db.execute('PRAGMA foreign_keys = ON');
        // WAL 提升连续打卡写入与启动读取的并发表现。
        await db.execute('PRAGMA journal_mode = WAL');
      },
      onOpen: (db) async {
        // 兼容旧库：建表/迁移完成后再补归档索引。
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tasks_archived ON tasks (archived_at)',
        );
      },
      onCreate: (db, version) async {
        await _createV2Schema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateV1ToV2(db);
        }
        if (oldVersion < 3) {
          await _migrateV2ToV3(db);
        }
        if (oldVersion < 4) {
          await _migrateV3ToV4(db);
        }
        if (oldVersion < 5) {
          await _migrateV4ToV5(db);
        }
      },
    );
  }

  Future<void> _createV2Schema(Database db) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        completed_at INTEGER,
        archived_at INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        schedule_type TEXT NOT NULL DEFAULT 'daily',
        weekly_target INTEGER NOT NULL DEFAULT 7,
        weekday_mask INTEGER NOT NULL DEFAULT 127,
        tag_id INTEGER,
        reminder_time TEXT,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        due_at INTEGER,
        reminder_effective_only INTEGER NOT NULL DEFAULT 0,
        interval_days INTEGER NOT NULL DEFAULT 1,
        month_days_mask INTEGER NOT NULL DEFAULT 1,
        yearly_month INTEGER,
        yearly_day INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE checkins (
        task_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        completed_ts INTEGER NOT NULL,
        remark TEXT,
        PRIMARY KEY (task_id, date),
        FOREIGN KEY (task_id) REFERENCES tasks (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_checkins_date ON checkins (date)');
    await db.execute('CREATE INDEX idx_tasks_tag ON tasks (tag_id)');
    await db.execute('CREATE INDEX idx_tasks_archived ON tasks (archived_at)');
  }

  /// v1 → v2 迁移：全部使用 ALTER TABLE，保留原有任务与打卡。
  Future<void> _migrateV1ToV2(Database db) async {
    await db.execute(
      "ALTER TABLE tasks ADD COLUMN schedule_type TEXT NOT NULL DEFAULT 'daily'",
    );
    await db.execute(
      'ALTER TABLE tasks ADD COLUMN weekly_target INTEGER NOT NULL DEFAULT 7',
    );
    await db.execute(
      'ALTER TABLE tasks ADD COLUMN weekday_mask INTEGER NOT NULL DEFAULT 127',
    );
    await db.execute('ALTER TABLE tasks ADD COLUMN tag_id INTEGER');
    await db.execute('ALTER TABLE tasks ADD COLUMN reminder_time TEXT');
    await db.execute(
      'ALTER TABLE tasks ADD COLUMN reminder_enabled INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE checkins ADD COLUMN remark TEXT');
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_tag ON tasks (tag_id)');
  }

  Future<void> _migrateV2ToV3(Database db) async {
    await db.execute('ALTER TABLE tasks ADD COLUMN due_at INTEGER');
    await db.execute(
      'ALTER TABLE tasks ADD COLUMN reminder_effective_only INTEGER NOT NULL DEFAULT 0',
    );
  }

  /// v3 → v4：完整周期体系。旧任务默认每日/1 号，不改变原有行为。
  Future<void> _migrateV3ToV4(Database db) async {
    await db.execute(
      'ALTER TABLE tasks ADD COLUMN interval_days INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      'ALTER TABLE tasks ADD COLUMN month_days_mask INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute('ALTER TABLE tasks ADD COLUMN yearly_month INTEGER');
    await db.execute('ALTER TABLE tasks ADD COLUMN yearly_day INTEGER');
  }

  Future<void> _migrateV4ToV5(Database db) async {
    await db.execute(
      'ALTER TABLE tags ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
    );
  }

  // ---------------------------------------------------------------------------
  // 任务
  // ---------------------------------------------------------------------------

  /// 所有任务，包含已归档任务。统计历史时需要归档任务。
  Future<List<Task>> loadAllTasks() async {
    final db = await database;
    final rows = await db.query('tasks', orderBy: 'sort_order ASC, id ASC');
    return rows.map(Task.fromMap).toList(growable: false);
  }

  /// 当前活跃任务（未归档）。
  Future<List<Task>> loadActiveTasks() async {
    final db = await database;
    final rows = await db.query(
      'tasks',
      where: 'archived_at IS NULL',
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(Task.fromMap).toList(growable: false);
  }

  /// 回收站：已归档任务，最近归档的在前。
  Future<List<Task>> loadArchivedTasks() async {
    final db = await database;
    final rows = await db.query(
      'tasks',
      where: 'archived_at IS NOT NULL',
      orderBy: 'archived_at DESC, id DESC',
    );
    return rows.map(Task.fromMap).toList(growable: false);
  }

  /// 新增任务，返回 SQLite 生成的自增 id。
  Future<int> insertTask(Task task) async {
    final db = await database;
    return db.insert(
      'tasks',
      task.toMap(includeId: false),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// 更新任务的完整可编辑字段。业务逻辑仍由 Provider 控制。
  Future<void> updateTask(Task task) async {
    final id = task.id;
    if (id == null) throw ArgumentError('任务尚未保存');
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> updateTaskTitle(int id, String title) async {
    final db = await database;
    await db.update(
      'tasks',
      <String, Object?>{'title': title},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 完成 / 撤销完成临时待办；传 null 表示撤销。
  Future<void> updateTaskCompletedAt(int id, int? completedAt) async {
    final db = await database;
    await db.update(
      'tasks',
      <String, Object?>{'completed_at': completedAt},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 软归档：不删除数据，只记录归档时间。
  Future<void> archiveTask(int id, int archivedAt) async {
    final db = await database;
    await db.update(
      'tasks',
      <String, Object?>{'archived_at': archivedAt},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 从回收站恢复任务。
  Future<void> restoreTask(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      <String, Object?>{'archived_at': null},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 永久删除任务及其打卡记录。只有回收站里的“彻底删除”会调用。
  Future<void> deleteTaskPermanently(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'checkins',
        where: 'task_id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.delete('tasks', where: 'id = ?', whereArgs: <Object?>[id]);
    });
  }

  /// 回收站批量恢复：单事务，避免中途失败留下半恢复状态。
  Future<void> batchRestoreTasks(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.update(
          'tasks',
          <String, Object?>{'archived_at': null},
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
      }
    });
  }

  /// 回收站批量永久删除：任务与打卡在同一事务内删除。
  Future<void> batchDeleteTasksPermanently(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.delete(
          'checkins',
          where: 'task_id = ?',
          whereArgs: <Object?>[id],
        );
        await txn.delete('tasks', where: 'id = ?', whereArgs: <Object?>[id]);
      }
    });
  }

  /// 拖拽排序后批量写 sort_order，保证列表顺序持久化。
  Future<void> updateSortOrders(List<Task> tasks) async {
    if (tasks.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < tasks.length; i++) {
        final id = tasks[i].id;
        if (id == null) continue;
        await txn.update(
          'tasks',
          <String, Object?>{'sort_order': i + 1},
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 打卡
  // ---------------------------------------------------------------------------

  /// 新增/覆盖一条打卡。联合主键保证同一任务同一天最多一条。
  Future<void> setCheckin(CheckinRecord record) async {
    final db = await database;
    await db.insert(
      'checkins',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCheckinRemark(
    int taskId,
    String date,
    String? remark,
  ) async {
    final db = await database;
    await db.update(
      'checkins',
      <String, Object?>{
        'remark': remark?.trim().isEmpty == true ? null : remark,
      },
      where: 'task_id = ? AND date = ?',
      whereArgs: <Object?>[taskId, date],
    );
  }

  /// 修改已有打卡的完成时间（日期不变，只改时分）。
  Future<void> updateCheckinTime(
    int taskId,
    String date,
    int completedTs,
  ) async {
    final db = await database;
    await db.update(
      'checkins',
      <String, Object?>{'completed_ts': completedTs},
      where: 'task_id = ? AND date = ?',
      whereArgs: <Object?>[taskId, date],
    );
  }

  /// 删除打卡。取消每日任务时调用。
  Future<void> deleteCheckin(int taskId, String date) async {
    final db = await database;
    await db.delete(
      'checkins',
      where: 'task_id = ? AND date = ?',
      whereArgs: <Object?>[taskId, date],
    );
  }

  /// 某一天的全部打卡记录（按日期批量查询）。
  Future<List<CheckinRecord>> loadCheckinsForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'checkins',
      where: 'date = ?',
      whereArgs: <Object?>[date],
      orderBy: 'task_id ASC',
    );
    return rows.map(CheckinRecord.fromMap).toList(growable: false);
  }

  /// 一段日期内的打卡记录，月底统计可用。
  Future<List<CheckinRecord>> loadCheckinsForRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'checkins',
      where: 'date >= ? AND date <= ?',
      whereArgs: <Object?>[startDate, endDate],
      orderBy: 'date ASC, task_id ASC',
    );
    return rows.map(CheckinRecord.fromMap).toList(growable: false);
  }

  /// 全量打卡记录。启动时一次载入，避免日历每翻一页都查库。
  Future<List<CheckinRecord>> loadAllCheckins() async {
    final db = await database;
    final rows = await db.query('checkins', orderBy: 'date ASC, task_id ASC');
    return rows.map(CheckinRecord.fromMap).toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // 标签
  // ---------------------------------------------------------------------------

  Future<List<Tag>> loadTags() async {
    final db = await database;
    final rows = await db.query(
      'tags',
      orderBy: 'pinned DESC, created_at DESC, id DESC',
    );
    return rows.map(Tag.fromMap).toList(growable: false);
  }

  Future<int> insertTag(Tag tag) async {
    final db = await database;
    return db.insert(
      'tags',
      tag.toMap(includeId: false),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> updateTag(Tag tag) async {
    final id = tag.id;
    if (id == null) throw ArgumentError('标签尚未保存');
    final db = await database;
    await db.update(
      'tags',
      tag.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 删除标签，同时把引用它的任务 tag_id 置空；任务本身不受影响。
  Future<void> deleteTag(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        <String, Object?>{'tag_id': null},
        where: 'tag_id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.delete('tags', where: 'id = ?', whereArgs: <Object?>[id]);
    });
  }

  /// 批量更新任务可编辑字段，事务保证全成功或全回滚。
  Future<void> batchUpdateTasks(List<Task> tasks) async {
    if (tasks.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final task in tasks) {
        final id = task.id;
        if (id == null) continue;
        await txn.update(
          'tasks',
          task.toMap(includeId: false),
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
      }
    });
  }

  Future<void> batchArchiveTasks(List<int> ids, int archivedAt) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.update(
          'tasks',
          <String, Object?>{'archived_at': archivedAt},
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 数据自检
  // ---------------------------------------------------------------------------

  /// 启动时的轻量校验。返回可直接展示给用户的问题描述。
  Future<List<String>> checkIntegrity() async {
    final db = await database;
    final issues = <String>[];
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    if (integrity.isNotEmpty &&
        integrity.first.values.first?.toString().toLowerCase() != 'ok') {
      issues.add('数据库页结构异常');
    }
    final orphan = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM checkins WHERE task_id NOT IN (SELECT id FROM tasks)',
      ),
    );
    if ((orphan ?? 0) > 0) issues.add('$orphan 条打卡找不到对应任务');
    final badDates = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM checkins WHERE date NOT GLOB "
        "'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'",
      ),
    );
    if ((badDates ?? 0) > 0) issues.add('$badDates 条打卡日期格式异常');
    final badTasks = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM tasks WHERE type NOT IN ('daily','todo') "
        "OR schedule_type NOT IN ('daily','weeklyTarget','weekdays')",
      ),
    );
    if ((badTasks ?? 0) > 0) issues.add('$badTasks 条任务字段异常');
    return issues;
  }

  /// 一键修复：删除孤儿/坏日期打卡，规范化任务枚举值。
  Future<void> repairIntegrity() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM checkins WHERE task_id NOT IN (SELECT id FROM tasks)',
      );
      await txn.rawDelete(
        "DELETE FROM checkins WHERE date NOT GLOB "
        "'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'",
      );
      await txn.rawUpdate(
        "UPDATE tasks SET type='todo' WHERE type NOT IN ('daily','todo')",
      );
      await txn.rawUpdate(
        "UPDATE tasks SET schedule_type='daily' "
        "WHERE schedule_type NOT IN ('daily','weeklyTarget','weekdays')",
      );
      await txn.rawUpdate(
        'UPDATE tasks SET weekly_target=7 WHERE weekly_target < 1 OR weekly_target > 7',
      );
      await txn.rawUpdate(
        'UPDATE tasks SET weekday_mask=127 WHERE weekday_mask < 1 OR weekday_mask > 127',
      );
    });
  }

  // ---------------------------------------------------------------------------
  // 设置
  // ---------------------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', <String, Object?>{
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: <Object?>[key]);
  }

  Future<Map<String, String>> loadSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    return <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  /// 单元测试 / 热重启时可主动关闭连接；正常 UI 不需要调用。
  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}
