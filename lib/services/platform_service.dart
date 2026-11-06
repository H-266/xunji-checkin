import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生平台能力桥。
///
/// 阶段 3 只暴露和桌面小组件有关的能力，不涉及网络、存储、定位：
/// - 让原生侧立即广播刷新两个卡片；
/// - 查询系统是否支持“一键添加”；
/// - 电池优化状态/设置入口（只用于国产 ROM 保活提示，不申请任何权限）。
///
/// 所有方法都做了异常兜底：单元测试或非 Android 环境没有 MethodChannel
/// 时返回安全默认值，避免拖垮页面。
class PlatformService {
  PlatformService._();

  static const MethodChannel _channel = MethodChannel(
    'com.xunji.checkin/platform',
  );

  /// 同步 Android 13+ 的 per-app locale，让原生应用名、通知渠道、
  /// 桌面小组件资源与 App 内语言保持一致。
  static Future<void> setAppLanguage(String languageCode) async {
    try {
      await _channel.invokeMethod<void>('setLanguage', {
        'language': languageCode,
      });
    } on MissingPluginException {
      // 单元测试或旧系统没有原生通道。
    } on PlatformException {
      // 原生语言同步失败不阻断 App 内切换。
    }
  }

  /// 让原生侧广播 APPWIDGET_UPDATE。
  ///
  /// HomeWidget.updateWidget 已经会刷新；这里再走一次原生的显式广播，
  /// 主要覆盖部分国产桌面“插件调用成功但宿主没重绘”的情况。
  static Future<void> refreshWidgets() async {
    try {
      await _channel.invokeMethod<void>('refreshWidgets');
    } on MissingPluginException {
      // 测试环境没有原生插件。
    } on PlatformException catch (error) {
      debugPrint('刷新小组件失败：${error.message}');
    }
  }

  /// 系统桌面是否支持 requestPinAppWidget（Android 8.0+ 才存在）。
  static Future<bool> isRequestPinSupported() async {
    try {
      final value = await _channel.invokeMethod<bool>('isRequestPinSupported');
      return value ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 是否已忽略电池优化。
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final value = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return value ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 打开系统“电池优化”列表；不直接申请 REQUEST_IGNORE_BATTERY_OPTIMIZATIONS。
  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } on MissingPluginException {
      // 测试环境忽略。
    } on PlatformException catch (error) {
      debugPrint('打开电池优化设置失败：${error.message}');
    }
  }

  /// 打开厂商自启动管理页；原生匹配失败会自动回退应用详情页。
  static Future<bool> openAutoStartSettings() async {
    try {
      final value = await _channel.invokeMethod<bool>('openAutoStartSettings');
      return value ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('打开自启动设置失败：${error.message}');
      return false;
    }
  }

  /// 打开本应用详情页，作为自启动入口的兜底。
  static Future<bool> openAppSettings() async {
    try {
      final value = await _channel.invokeMethod<bool>('openAppSettings');
      return value ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('打开应用详情失败：${error.message}');
      return false;
    }
  }

  /// 用系统 SAF 保存 JSON；返回保存后的 URI，用户取消时返回 null。
  ///
  /// 全程不申请存储权限，也不访问应用私有目录之外的位置。
  static Future<String?> exportJson({
    required String json,
    required String fileName,
    String mimeType = 'application/json',
  }) async {
    try {
      return await _channel.invokeMethod<String>('exportJson', {
        'json': json,
        'fileName': fileName,
        'mimeType': mimeType,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('导出失败：${error.message}');
      rethrow;
    }
  }

  /// 让系统文件选择器读取一个 JSON 备份；用户取消返回 null。
  static Future<String?> importJson() async {
    try {
      return await _channel.invokeMethod<String>('importJson');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('导入失败：${error.message}');
      rethrow;
    }
  }

  /// 选择一个长期备份目录（SAF 持久授权）。
  static Future<String?> chooseBackupDirectory() async {
    try {
      return await _channel.invokeMethod<String>('chooseBackupDirectory');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('选择备份目录失败：${error.message}');
      rethrow;
    }
  }

  /// 把自动备份写入已授权目录。
  static Future<String?> writeBackup({
    required String dirUri,
    required String fileName,
    required String json,
  }) async {
    try {
      return await _channel.invokeMethod<String>('writeBackup', {
        'dirUri': dirUri,
        'fileName': fileName,
        'json': json,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('自动备份写入失败：${error.message}');
      rethrow;
    }
  }

  /// 保留最近 [keep] 份自动备份，返回删除数量。
  static Future<int> pruneBackups({
    required String dirUri,
    required int keep,
  }) async {
    try {
      return await _channel.invokeMethod<int>('pruneBackups', {
            'dirUri': dirUri,
            'keep': keep,
          }) ??
          0;
    } on MissingPluginException {
      return 0;
    } on PlatformException catch (error) {
      debugPrint('清理旧备份失败：${error.message}');
      return 0;
    }
  }

  /// 用系统 SAF 保存 PNG 图片；返回 URI，取消返回 null。
  static Future<String?> saveImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      return await _channel.invokeMethod<String>('saveImage', {
        'bytes': bytes,
        'fileName': fileName,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('保存图片失败：${error.message}');
      rethrow;
    }
  }

  /// 同步所有任务提醒。传空数组等价于取消全部提醒。
  static Future<void> syncReminders(
    List<Map<String, Object?>> reminders,
  ) async {
    try {
      await _channel.invokeMethod<void>('syncReminders', {
        'reminders': reminders,
      });
    } on MissingPluginException {
      // 测试环境忽略。
    } on PlatformException catch (error) {
      debugPrint('同步提醒失败：${error.message}');
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('areNotificationsEnabled') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Android 13+ 请求 POST_NOTIFICATIONS；低版本直接返回 true。
  static Future<bool> requestNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 通过系统 mailto 打开邮件应用，只自动填充收件人。
  ///
  /// 不读取通讯录、不发送邮件、不需要任何权限；没有邮件应用时返回 false，
  /// 由关于页给出本地提示。
  static Future<bool> openEmail(String email) async {
    try {
      return await _channel.invokeMethod<bool>('openEmail', {'email': email}) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 厂商名，用于显示“小米/华为/OPPO...”的定制引导。
  static Future<String> deviceBrand() async {
    try {
      final value = await _channel.invokeMethod<String>('deviceBrand');
      return value ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }
}
