# 架构说明

## 分层

```
lib/
  main.dart                 入口、主题、语言、隐私门
  core/                     日期、统计、动效、文案表、引导目标
  models/                   Task / Tag / CheckinRecord / TaskSchedule
  data/app_database.dart    SQLite v4、迁移、事务、完整性检查
  providers/                TaskProvider / SettingsProvider
  screens/                  今日、热力、统计、小组件、设置、二级页
  services/                 Widget、提醒、导入导出、备份、日志
  theme/                    Material 3 + 固定色相热力色
  widgets/                  任务行、进度环、趋势图、引导遮罩
android/.../widget/         RemoteViews 位图渲染、午夜间刷新
android/.../reminder/       本地通知调度
```

## 关键规则

1. **日期作用域**：每日打卡的完成状态存 `checkins(task_id, date)`；跨天重置只换查询日期，不改写历史。
2. **周期**：`Task.isScheduledOn(date)` 是唯一生效日入口；统计、补卡、提醒、组件都复用它。
3. **软归档**：任务不物理删除；`archivedAt` 为归档日，历史热力保留。永久删除只发生在回收站，且事务删除 checkins。
4. **统计同源**：今日、热力、年度、统计页、CSV 都走 `StatsCalculator` / `TaskProvider.statsFor`，避免多套口径。
5. **隐私**：`privacyAccepted=false` 时只显示隐私门，不启动 AppShell，不读取任务数据。
6. **文件**：所有导入/导出/备份/长图保存走 SAF；无存储权限。
7. **组件**：Dart 写 SharedPreferences JSON，Kotlin Canvas 渲染位图；点击通过 `HomeWidgetLaunchIntent` 回 App。

## 数据库版本

| 版本 | 变更 |
| --- | --- |
| v1 | tasks / checkins / settings |
| v2 | 周期、标签、备注、提醒字段 |
| v3 | due_at、reminder_effective_only、完整性检查 |
| v4 | interval_days、month_days_mask、yearly_month/yearly_day |

升级全部使用 `ALTER TABLE` / `CREATE TABLE IF NOT EXISTS`，旧数据默认映射为每日任务。
