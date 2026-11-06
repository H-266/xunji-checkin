import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/date_utils.dart';
import '../core/stats.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import 'platform_service.dart';

/// 桌面小组件的数据与添加入口。
///
/// 设计约束：
/// - 卡片只读，所有勾选都发生在 App 内；
/// - 每次数据变更后写 JSON 到 home_widget 的 SharedPreferences，
///   再通知原生 Provider 重绘；
/// - 不申请任何额外权限，不启动后台 Service。
class WidgetService {
  WidgetService._();

  /// 原生 Provider 的完整类名。home_widget 需要 qualified name 才能
  /// 在不同 flavor/包名下准确找到 Provider。
  static const String checkinWidgetClass =
      'com.xunji.checkin.widget.CheckinWidgetProvider';
  static const String heatmapWidgetClass =
      'com.xunji.checkin.widget.HeatmapWidgetProvider';
  static const String miniWidgetClass =
      'com.xunji.checkin.widget.MiniWidgetProvider';

  static const String checkinDataKey = 'xunji_checkin_widget_data';
  static const String heatmapDataKey = 'xunji_heatmap_widget_data';
  static const String miniDataKey = 'xunji_mini_widget_data';
  static const String pendingCheckinTagKey = 'xunji_pending_tag_checkin';
  static const String pendingHeatmapTagKey = 'xunji_pending_tag_heatmap';

  static String checkinTagDataKey(int tagId) => '${checkinDataKey}_tag_$tagId';
  static String heatmapTagDataKey(int tagId) => '${heatmapDataKey}_tag_$tagId';

  /// 同步两种卡片。
  ///
  /// [dark] 由调用方根据“跟随系统/强制浅色/强制深色”计算，保证桌面
  /// 卡片和 App 当前主题一致。失败时静默：没有添加卡片、测试环境、
  /// 或桌面宿主暂时不可用都不应该影响打卡主流程。
  static Future<void> updateAllWidgets({
    required TaskProvider tasks,
    required SettingsProvider settings,
    required bool dark,
    String languageCode = 'zh',
  }) async {
    try {
      final checkinPayload = _buildCheckinPayload(
        tasks,
        settings,
        dark,
        languageCode: languageCode,
      );
      final heatmapPayload = _buildHeatmapPayload(
        tasks,
        settings,
        dark,
        languageCode: languageCode,
      );

      await HomeWidget.saveWidgetData<String>(
        checkinDataKey,
        jsonEncode(checkinPayload),
      );
      await HomeWidget.saveWidgetData<String>(
        heatmapDataKey,
        jsonEncode(heatmapPayload),
      );
      await HomeWidget.saveWidgetData<String>(
        miniDataKey,
        jsonEncode(<String, Object?>{
          'percent': tasks.todayStat.percent,
          'hue': settings.hue,
          'dark': dark,
          'lang': languageCode,
          'date': AppDateUtils.formatKey(tasks.today),
        }),
      );

      // 每个标签单独一份数据，原生 Provider 按卡片绑定的标签读取。
      for (final tag in tasks.allTags) {
        final id = tag.id;
        if (id == null) continue;
        await HomeWidget.saveWidgetData<String>(
          checkinTagDataKey(id),
          jsonEncode(
            _buildCheckinPayload(
              tasks,
              settings,
              dark,
              tagId: id,
              languageCode: languageCode,
            ),
          ),
        );
        await HomeWidget.saveWidgetData<String>(
          heatmapTagDataKey(id),
          jsonEncode(
            _buildHeatmapPayload(
              tasks,
              settings,
              dark,
              tagId: id,
              languageCode: languageCode,
            ),
          ),
        );
      }

      await HomeWidget.updateWidget(qualifiedAndroidName: checkinWidgetClass);
      await HomeWidget.updateWidget(qualifiedAndroidName: heatmapWidgetClass);
      await HomeWidget.updateWidget(qualifiedAndroidName: miniWidgetClass);

      // 额外走一次原生显式广播，兼容部分桌面“updateWidget 返回成功
      // 但宿主没有重绘”的情况。
      await PlatformService.refreshWidgets();
    } catch (error, stack) {
      debugPrint('小组件同步失败：$error\n$stack');
    }
  }

  /// 兼容旧调用名，方便后续阶段继续使用。
  static Future<void> sync({
    required TaskProvider tasks,
    required SettingsProvider settings,
    required bool dark,
  }) => updateAllWidgets(tasks: tasks, settings: settings, dark: dark);

  static Map<String, Object?> _buildCheckinPayload(
    TaskProvider tasks,
    SettingsProvider settings,
    bool dark, {
    int? tagId,
    String languageCode = 'zh',
  }) {
    final today = tasks.today;
    final stat = tasks.statsFor(today, tagId: tagId);

    // DayStat 已经包含“当天完成但已从待办列表消失”的任务；
    // 未完成优先，保证 2×2 只显示 3 条时先看到还没做的事。
    final entries = stat.entries.map((entry) {
      return <String, Object?>{
        'id': entry.task.id,
        'title': entry.task.title,
        'type': entry.task.type.name,
        'done': entry.done,
      };
    }).toList();

    entries.sort((a, b) {
      final aDone = a['done']! as bool;
      final bDone = b['done']! as bool;
      if (aDone == bDone) return 0;
      return aDone ? 1 : -1;
    });

    // 额外保存“每日任务 + 未完成待办”。午夜闹钟触发时，原生渲染器
    // 如果发现 payload.date 已不是今天，就用这两组任务重建新一天：
    // 每日任务全部未打卡、昨日已完成待办不再出现，避免卡片显示昨天的勾。
    final daily = tasks
        .tasksForTag(tagId)
        .where((task) => task.type == TaskType.daily)
        .map((task) => <String, Object?>{'id': task.id, 'title': task.title})
        .toList();
    final pending = tasks.todoTasks
        .where((task) => tagId == null || task.tagId == tagId)
        .map((task) => <String, Object?>{'id': task.id, 'title': task.title})
        .toList();

    return <String, Object?>{
      'date': AppDateUtils.formatKey(today),
      'date_label':
          '${AppDateUtils.monthDayLabel(today)} · ${AppDateUtils.shortWeekdayLabel(today)}',
      'total': stat.total,
      'done': stat.completed,
      'percent': stat.percent,
      'hue': settings.hue,
      'dark': dark,
      'lang': languageCode,
      'minimal': settings.widgetMinimal,
      'tasks': entries,
      'daily': daily,
      'pending': pending,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, Object?> _buildHeatmapPayload(
    TaskProvider tasks,
    SettingsProvider settings,
    bool dark, {
    int? tagId,
    String languageCode = 'zh',
  }) {
    final today = tasks.today;
    // 8 个完整周：本周周一往前推 7 周，共 56 天。
    final monday = AppDateUtils.weekStart(today);
    final start = monday.subtract(const Duration(days: 49));
    final days = <Map<String, Object?>>[];

    for (var i = 0; i < 56; i++) {
      final date = start.add(Duration(days: i));
      final stat = date.isAfter(today)
          ? DayStat.empty(date)
          : tasks.statsFor(date, tagId: tagId);
      days.add(<String, Object?>{
        'date': AppDateUtils.formatKey(date),
        'total': stat.total,
        'done': stat.completed,
        'rate': stat.rate,
      });
    }

    // 平均值只统计已经发生的日期，未来格子不参与，避免月底平均被稀释。
    final pastDays = days.where((day) {
      final date = DateTime.parse(day['date']! as String);
      return !date.isAfter(today);
    }).toList();
    final average = pastDays.isEmpty
        ? 0.0
        : pastDays.fold<double>(
                0,
                (sum, day) => sum + (day['rate']! as double),
              ) /
              pastDays.length;

    return <String, Object?>{
      'today': AppDateUtils.formatKey(today),
      'hue': settings.hue,
      'dark': dark,
      'lang': languageCode,
      'average': average,
      'days': days,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// 未来日期不构造统计，避免“未来任务”污染热力卡片。
  static DayStat statsOrEmpty(
    TaskProvider tasks,
    DateTime date,
    DateTime today,
  ) {
    if (date.isAfter(today)) return DayStat.empty(date);
    return tasks.statsFor(date);
  }

  /// 系统桌面是否支持一键添加。优先问原生，插件不可用时再回退到
  /// home_widget 自己的检测。
  static Future<bool> isPinSupported() async {
    final native = await PlatformService.isRequestPinSupported();
    if (native) return true;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 发起系统“添加小组件”确认页。
  ///
  /// 部分国产桌面会直接吞掉这个页面，所以配置页始终同时展示
  /// “长按桌面手动添加”的兜底引导。
  static Future<void> requestPinWidget({
    required bool heatmap,
    int? tagId,
  }) async {
    // 系统确认页不会回传 appWidgetId，所以先把本次选择记成“待绑定”；
    // 原生 Provider 首次渲染该卡片时消费它，实现多卡片分别绑定标签。
    await HomeWidget.saveWidgetData<String>(
      heatmap ? pendingHeatmapTagKey : pendingCheckinTagKey,
      tagId?.toString() ?? '',
    );
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: heatmap ? heatmapWidgetClass : checkinWidgetClass,
    );
  }

  static Future<void> pinCheckin({int? tagId}) =>
      requestPinWidget(heatmap: false, tagId: tagId);

  static Future<void> pinHeatmap({int? tagId}) =>
      requestPinWidget(heatmap: true, tagId: tagId);

  static Future<void> pinMini() async {
    await HomeWidget.requestPinWidget(qualifiedAndroidName: miniWidgetClass);
  }
}
