import '../core/date_utils.dart';

/// 任务类型：
/// - [daily] 每日固定打卡，状态按天存在 checkins 表中；
/// - [todo] 临时待办，一次性任务，完成后从今日列表消失。
enum TaskType {
  daily,
  todo;

  String get dbValue => name;

  String get label => switch (this) {
    TaskType.daily => '打卡任务',
    TaskType.todo => '临时待办',
  };

  static TaskType fromDb(String? value) {
    return switch (value) {
      'daily' => TaskType.daily,
      'todo' => TaskType.todo,
      _ => TaskType.todo,
    };
  }
}

/// 打卡任务的周期规则。
///
/// 临时待办忽略该字段。所有周期规则只影响“某天是否计入任务总数”，
/// 不在零点改写任何完成状态。
enum TaskSchedule {
  /// 每天生效。
  daily,

  /// 每天都可以打卡，但按周统计目标次数；不改变单日完成率口径。
  weeklyTarget,

  /// 只在选中的星期几生效；非生效日不计入总数。
  weekdays,

  /// 从创建日起，每 N 天生效一次。
  intervalDays,

  /// 每月选中的日期生效；不存在的日期（如 2 月 30 日）自动跳过。
  monthlyDays,

  /// 每年指定月日生效；2 月 29 日只在闰年生效。
  yearlyDate;

  String get dbValue => name;

  String get label => switch (this) {
    TaskSchedule.daily => '每日',
    TaskSchedule.weeklyTarget => '每周目标',
    TaskSchedule.weekdays => '自定义星期',
    TaskSchedule.intervalDays => '间隔天数',
    TaskSchedule.monthlyDays => '每月日期',
    TaskSchedule.yearlyDate => '每年日期',
  };

  static TaskSchedule fromDb(String? value) {
    return switch (value) {
      'weeklyTarget' || 'weekly' => TaskSchedule.weeklyTarget,
      'weekdays' || 'custom' => TaskSchedule.weekdays,
      'intervalDays' || 'interval' => TaskSchedule.intervalDays,
      'monthlyDays' || 'monthly' => TaskSchedule.monthlyDays,
      'yearlyDate' || 'yearly' => TaskSchedule.yearlyDate,
      _ => TaskSchedule.daily,
    };
  }
}

/// 任务实体。
///
/// 时间字段统一使用毫秒时间戳，便于 SQLite 存储和跨平台比较。
class Task {
  /// 置顶排序编码：sort_order < 0 视为置顶。
  /// 复用 sort_order，不新增数据库列；-pinnedOffset + 原顺序 可保留置顶组内顺序。
  static const int pinnedOffset = 1000000;

  final int? id;
  final String title;
  final TaskType type;
  final int createdAt;
  final int? completedAt;
  final int? archivedAt;
  final int sortOrder;

  /// 以下字段只对 [TaskType.daily] 有意义，临时待办保留默认值。
  final TaskSchedule schedule;
  final int weeklyTarget;

  /// 周一 = bit 0，周日 = bit 6。
  final int weekdayMask;

  /// 间隔天数，仅 [TaskSchedule.intervalDays] 使用，最小 1。
  final int intervalDays;

  /// 每月日期掩码：1 号 = bit 0，31 号 = bit 30。
  final int monthDaysMask;

  /// 每年周期：月份 1~12 与日期 1~31。
  final int? yearlyMonth;
  final int? yearlyDay;

  final int? tagId;
  final String? reminderTime;
  final bool reminderEnabled;

  /// 临时待办的截止日（当天 00:00 的毫秒时间戳），null 表示不设截止。
  final int? dueAt;

  /// 周期任务是否只在生效日提醒；默认 false，保持旧行为。
  final bool reminderEffectiveOnly;

  const Task({
    this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    this.completedAt,
    this.archivedAt,
    this.sortOrder = 0,
    this.schedule = TaskSchedule.daily,
    this.weeklyTarget = 7,
    this.weekdayMask = 0x7F,
    this.intervalDays = 1,
    this.monthDaysMask = 0x1,
    this.yearlyMonth,
    this.yearlyDay,
    this.tagId,
    this.reminderTime,
    this.reminderEnabled = false,
    this.dueAt,
    this.reminderEffectiveOnly = false,
  });

  bool get isArchived => archivedAt != null;
  bool get isTodo => type == TaskType.todo;
  bool get isDaily => type == TaskType.daily;

  /// 置顶任务用负数 sort_order 表示，始终排在普通任务前。
  bool get isPinned => sortOrder < 0;

  DateTime get createdDate => DateTime.fromMillisecondsSinceEpoch(createdAt);

  DateTime? get completedDate => completedAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(completedAt!);

  DateTime? get archivedDate => archivedAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(archivedAt!);

  DateTime? get dueDate =>
      dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(dueAt!);

  /// 未完成且已经过了截止日。
  bool get isOverdue {
    final due = dueDate;
    if (due == null || completedAt != null) return false;
    final today = DateTime.now();
    return DateTime(
      today.year,
      today.month,
      today.day,
    ).isAfter(DateTime(due.year, due.month, due.day));
  }

  /// 周一 = bit 0，周日 = bit 6。
  bool isWeekdayEnabled(int weekday) {
    return (weekdayMask & (1 << (weekday - 1))) != 0;
  }

  /// 每月日期掩码中是否包含 [day]（1~31）。
  bool isMonthDayEnabled(int day) =>
      day >= 1 && day <= 31 && (monthDaysMask & (1 << (day - 1))) != 0;

  /// 该任务在 [date] 是否属于“排班日”。临时待办恒为 true。
  ///
  /// 这是全 App 唯一生效日判定入口：统计、补卡、提醒、小组件都走这里，
  /// 避免不同模块各自实现一套周期规则。
  bool isScheduledOn(DateTime date) {
    if (type == TaskType.todo) return true;
    final day = AppDateUtils.dayOnly(date);
    return switch (schedule) {
      TaskSchedule.daily || TaskSchedule.weeklyTarget => true,
      TaskSchedule.weekdays => isWeekdayEnabled(day.weekday),
      TaskSchedule.intervalDays =>
        AppDateUtils.daysBetween(createdDate, day) %
                (intervalDays < 1 ? 1 : intervalDays) ==
            0,
      TaskSchedule.monthlyDays => isMonthDayEnabled(day.day),
      TaskSchedule.yearlyDate =>
        day.month == yearlyMonth && day.day == yearlyDay,
    };
  }

  /// 从 [from] 起（含）最近的 [count] 个生效日，用于详情页展示。
  List<DateTime> upcomingScheduleDates({
    required DateTime from,
    int count = 5,
  }) {
    final result = <DateTime>[];
    var cursor = AppDateUtils.dayOnly(from);
    // 闰年 2 月 29 日最多可能隔 4 年才出现一次；732 天会直接扫空。
    // 1600 天覆盖一个完整闰年周期，保证“近期生效日”至少能拿到下一次。
    for (var i = 0; i < 1600 && result.length < count; i++) {
      if (isScheduledOn(cursor)) result.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return result;
  }

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      type: TaskType.fromDb(map['type'] as String?),
      createdAt: map['created_at'] as int? ?? 0,
      completedAt: map['completed_at'] as int?,
      archivedAt: map['archived_at'] as int?,
      sortOrder: map['sort_order'] as int? ?? 0,
      schedule: TaskSchedule.fromDb(map['schedule_type'] as String?),
      weeklyTarget: (map['weekly_target'] as int? ?? 7).clamp(1, 7),
      weekdayMask: (map['weekday_mask'] as int? ?? 0x7F) & 0x7F,
      intervalDays: (map['interval_days'] as int? ?? 1).clamp(1, 365),
      monthDaysMask: (map['month_days_mask'] as int? ?? 0x1) & 0x7FFFFFFF,
      yearlyMonth: map['yearly_month'] as int?,
      yearlyDay: map['yearly_day'] as int?,
      tagId: map['tag_id'] as int?,
      reminderTime: map['reminder_time'] as String?,
      reminderEnabled: (map['reminder_enabled'] as int? ?? 0) != 0,
      dueAt: map['due_at'] as int?,
      reminderEffectiveOnly: (map['reminder_effective_only'] as int? ?? 0) != 0,
    );
  }

  /// 写库时默认包含 id；新建任务应传 `includeId: false`，让 SQLite 自增。
  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'title': title,
      'type': type.dbValue,
      'created_at': createdAt,
      'completed_at': completedAt,
      'archived_at': archivedAt,
      'sort_order': sortOrder,
      'schedule_type': schedule.dbValue,
      'weekly_target': weeklyTarget,
      'weekday_mask': weekdayMask,
      'interval_days': intervalDays,
      'month_days_mask': monthDaysMask,
      'yearly_month': yearlyMonth,
      'yearly_day': yearlyDay,
      'tag_id': tagId,
      'reminder_time': reminderTime,
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'due_at': dueAt,
      'reminder_effective_only': reminderEffectiveOnly ? 1 : 0,
    };
  }

  /// 用哨兵区分“不修改”和“显式置空”。
  static const Object _unset = Object();

  Task copyWith({
    int? id,
    String? title,
    TaskType? type,
    int? createdAt,
    Object? completedAt = _unset,
    Object? archivedAt = _unset,
    int? sortOrder,
    TaskSchedule? schedule,
    int? weeklyTarget,
    int? weekdayMask,
    int? intervalDays,
    int? monthDaysMask,
    Object? yearlyMonth = _unset,
    Object? yearlyDay = _unset,
    Object? tagId = _unset,
    Object? reminderTime = _unset,
    bool? reminderEnabled,
    Object? dueAt = _unset,
    bool? reminderEffectiveOnly,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as int?,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as int?,
      sortOrder: sortOrder ?? this.sortOrder,
      schedule: schedule ?? this.schedule,
      weeklyTarget: weeklyTarget ?? this.weeklyTarget,
      weekdayMask: weekdayMask ?? this.weekdayMask,
      intervalDays: intervalDays ?? this.intervalDays,
      monthDaysMask: monthDaysMask ?? this.monthDaysMask,
      yearlyMonth: identical(yearlyMonth, _unset)
          ? this.yearlyMonth
          : yearlyMonth as int?,
      yearlyDay: identical(yearlyDay, _unset)
          ? this.yearlyDay
          : yearlyDay as int?,
      tagId: identical(tagId, _unset) ? this.tagId : tagId as int?,
      reminderTime: identical(reminderTime, _unset)
          ? this.reminderTime
          : reminderTime as String?,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      dueAt: identical(dueAt, _unset) ? this.dueAt : dueAt as int?,
      reminderEffectiveOnly:
          reminderEffectiveOnly ?? this.reminderEffectiveOnly,
    );
  }

  @override
  String toString() =>
      'Task(id: $id, title: $title, type: ${type.name}, '
      'createdAt: $createdAt, completedAt: $completedAt, archivedAt: $archivedAt)';
}

/// 每日打卡记录。
///
/// `(taskId, date)` 是联合主键，同一任务同一天最多一条。
class CheckinRecord {
  final int taskId;
  final String date;
  final int completedTs;

  /// 打卡时可选的一句话备注。
  final String? remark;

  const CheckinRecord({
    required this.taskId,
    required this.date,
    required this.completedTs,
    this.remark,
  });

  factory CheckinRecord.fromMap(Map<String, Object?> map) {
    return CheckinRecord(
      taskId: map['task_id'] as int? ?? 0,
      date: map['date'] as String? ?? '',
      completedTs: map['completed_ts'] as int? ?? 0,
      remark: map['remark'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'task_id': taskId,
      'date': date,
      'completed_ts': completedTs,
      'remark': remark,
    };
  }

  CheckinRecord copyWith({
    int? completedTs,
    String? remark,
    bool clearRemark = false,
  }) {
    return CheckinRecord(
      taskId: taskId,
      date: date,
      completedTs: completedTs ?? this.completedTs,
      remark: clearRemark ? null : (remark ?? this.remark),
    );
  }

  @override
  String toString() => 'CheckinRecord($taskId, $date)';
}
