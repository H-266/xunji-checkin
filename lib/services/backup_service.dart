import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/date_utils.dart';
import '../data/app_database.dart';
import '../providers/settings_provider.dart';
import 'export_service.dart';
import 'platform_service.dart';

/// 自动备份配置。全部保存在本地 settings 表，不联网。
class BackupConfig {
  const BackupConfig({
    required this.directoryUri,
    required this.frequencyDays,
    required this.keep,
    required this.lastBackupAt,
  });

  final String? directoryUri;
  final int frequencyDays;
  final int keep;
  final int lastBackupAt;

  bool get enabled => frequencyDays > 0 && (directoryUri?.isNotEmpty ?? false);

  bool get due {
    if (!enabled) return false;
    if (lastBackupAt <= 0) return true;
    final next = DateTime.fromMillisecondsSinceEpoch(lastBackupAt)
        .add(Duration(days: frequencyDays));
    return !DateTime.now().isBefore(next);
  }

  static const empty = BackupConfig(
    directoryUri: null,
    frequencyDays: 0,
    keep: 10,
    lastBackupAt: 0,
  );
}

class BackupResult {
  const BackupResult({
    required this.uri,
    required this.deletedOld,
    required this.fileName,
  });

  final String? uri;
  final int deletedOld;
  final String fileName;
}

/// 自动备份：把完整 JSON 写进用户通过 SAF 选定的目录。
///
/// 不使用后台服务、不申请存储权限；只在 App 启动/回到前台时检查是否到期。
class BackupService {
  BackupService._();

  static const dirKey = 'backup_dir';
  static const frequencyKey = 'backup_frequency_days';
  static const keepKey = 'backup_keep';
  static const lastKey = 'backup_last_at';

  /// 最近一次自动备份的本地快照。
  ///
  /// SAF 目录里的文件读取需要用户再次授权；本地快照放在应用私有目录，
  /// 用于数据完整性异常时“一键回滚”，不申请任何存储权限。
  static Future<File> _snapshotFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/xunji_last_backup.json');
  }

  static Future<void> _saveLocalSnapshot(String json) async {
    try {
      final file = await _snapshotFile();
      await file.writeAsString(json, flush: true);
    } catch (_) {
      // 快照失败不能影响真正的 SAF 备份。
    }
  }

  static Future<String?> readLocalSnapshot() async {
    try {
      final file = await _snapshotFile();
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<BackupConfig> loadConfig() async {
    final values = await AppDatabase.instance.loadSettings();
    return BackupConfig(
      directoryUri: values[dirKey],
      frequencyDays: int.tryParse(values[frequencyKey] ?? '') ?? 0,
      keep: int.tryParse(values[keepKey] ?? '') ?? 10,
      lastBackupAt: int.tryParse(values[lastKey] ?? '') ?? 0,
    );
  }

  static Future<void> saveConfig({
    required String? directoryUri,
    required int frequencyDays,
    required int keep,
  }) async {
    final db = AppDatabase.instance;
    if (directoryUri == null || directoryUri.isEmpty) {
      await db.deleteSetting(dirKey);
    } else {
      await db.setSetting(dirKey, directoryUri);
    }
    await db.setSetting(frequencyKey, frequencyDays.clamp(0, 30).toString());
    await db.setSetting(keepKey, keep.clamp(3, 60).toString());
  }

  /// 到达备份周期时执行一次；返回 null 表示未到期/未启用。
  static Future<BackupResult?> maybeRun(SettingsProvider settings) async {
    final config = await loadConfig();
    if (!config.due) return null;
    return runNow(settings, config: config);
  }

  static Future<BackupResult> runNow(
    SettingsProvider settings, {
    BackupConfig? config,
  }) async {
    final current = config ?? await loadConfig();
    final dir = current.directoryUri;
    if (dir == null || dir.isEmpty) {
      throw StateError('还没有选择备份目录');
    }
    final json = await ExportService.buildJson(settings: settings);
    final now = DateTime.now();
    final fileName =
        'xunji-auto-${AppDateUtils.formatKey(now)}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}.json';
    final uri = await PlatformService.writeBackup(
      dirUri: dir,
      fileName: fileName,
      json: json,
    );
    final deleted = await PlatformService.pruneBackups(
      dirUri: dir,
      keep: current.keep,
    );
    await _saveLocalSnapshot(json);
    await AppDatabase.instance.setSetting(
      lastKey,
      now.millisecondsSinceEpoch.toString(),
    );
    return BackupResult(uri: uri, deletedOld: deleted, fileName: fileName);
  }
}
