package com.xunji.checkin.reminder

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * 本地提醒排程。
 *
 * 使用普通 `setAndAllowWhileIdle`，不申请精确闹钟权限；系统省电策略下
 * 可能延迟几分钟。没有开机广播：设备重启后打开一次 App 会自动恢复。
 */
object ReminderScheduler {
    private const val PREFS = "xunji_reminder_prefs"
    private const val KEY_IDS = "scheduled_ids"
    const val EXTRA_ID = "reminder_id"
    const val EXTRA_TITLE = "reminder_title"
    const val EXTRA_TIME = "reminder_time"
    const val EXTRA_REPEAT = "reminder_repeat"
    const val EXTRA_EFFECTIVE_ONLY = "reminder_effective_only"
    const val EXTRA_SCHEDULE = "reminder_schedule"
    const val EXTRA_WEEKDAY_MASK = "reminder_weekday_mask"
    const val EXTRA_INTERVAL_DAYS = "reminder_interval_days"
    const val EXTRA_MONTH_DAYS_MASK = "reminder_month_days_mask"
    const val EXTRA_YEARLY_MONTH = "reminder_yearly_month"
    const val EXTRA_YEARLY_DAY = "reminder_yearly_day"
    const val EXTRA_CREATED_DATE = "reminder_created_date"

    private val DATE_FORMAT = DateTimeFormatter.ISO_LOCAL_DATE

    fun sync(context: Context, reminders: List<Map<String, Any?>>) {
        cancelAll(context)
        val ids = mutableSetOf<String>()
        for (item in reminders) {
            val id = (item["id"] as? Number)?.toInt() ?: continue
            val title = item["title"] as? String ?: "循记打卡"
            val time = item["time"] as? String ?: continue
            val repeat = item["repeat"] as? Boolean ?: true
            val effectiveOnly = item["effective_only"] as? Boolean ?: false
            val schedule = item["schedule"] as? String ?: "daily"
            val mask = (item["weekday_mask"] as? Number)?.toInt() ?: 0x7F
            val interval = (item["interval_days"] as? Number)?.toInt() ?: 1
            val monthMask = (item["month_days_mask"] as? Number)?.toInt() ?: 1
            val yearlyMonth = (item["yearly_month"] as? Number)?.toInt() ?: 0
            val yearlyDay = (item["yearly_day"] as? Number)?.toInt() ?: 0
            val createdDate = item["created_date"] as? String ?: ""
            if (schedule(context, id, title, time, repeat, effectiveOnly, schedule,
                    mask, interval, monthMask, yearlyMonth, yearlyDay, createdDate)) {
                ids.add(id.toString())
            }
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putStringSet(KEY_IDS, ids).apply()
    }

    fun rescheduleFromIntent(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, -1)
        if (id < 0) return
        val repeat = intent.getBooleanExtra(EXTRA_REPEAT, true)
        if (!repeat) return
        schedule(
            context = context,
            id = id,
            title = intent.getStringExtra(EXTRA_TITLE) ?: "循记打卡",
            time = intent.getStringExtra(EXTRA_TIME) ?: return,
            repeat = true,
            effectiveOnly = intent.getBooleanExtra(EXTRA_EFFECTIVE_ONLY, false),
            schedule = intent.getStringExtra(EXTRA_SCHEDULE) ?: "daily",
            weekdayMask = intent.getIntExtra(EXTRA_WEEKDAY_MASK, 0x7F),
            intervalDays = intent.getIntExtra(EXTRA_INTERVAL_DAYS, 1),
            monthDaysMask = intent.getIntExtra(EXTRA_MONTH_DAYS_MASK, 1),
            yearlyMonth = intent.getIntExtra(EXTRA_YEARLY_MONTH, 0),
            yearlyDay = intent.getIntExtra(EXTRA_YEARLY_DAY, 0),
            createdDate = intent.getStringExtra(EXTRA_CREATED_DATE) ?: "",
        )
    }

    private fun schedule(
        context: Context,
        id: Int,
        title: String,
        time: String,
        repeat: Boolean,
        effectiveOnly: Boolean,
        schedule: String,
        weekdayMask: Int,
        intervalDays: Int,
        monthDaysMask: Int,
        yearlyMonth: Int,
        yearlyDay: Int,
        createdDate: String,
    ): Boolean {
        val parts = time.split(":")
        if (parts.size != 2) return false
        val hour = parts[0].toIntOrNull() ?: return false
        val minute = parts[1].toIntOrNull() ?: return false
        if (hour !in 0..23 || minute !in 0..59) return false

        val zone = ZoneId.systemDefault()
        val now = LocalDateTime.now(zone)
        var day = LocalDate.now(zone)
        var target = LocalDateTime.of(day, LocalTime.of(hour, minute))
        if (!target.isAfter(now)) {
            day = day.plusDays(1)
            target = LocalDateTime.of(day, LocalTime.of(hour, minute))
        }
        if (effectiveOnly) {
            // 每年 2 月 29 日最多要向后找 4 年；400 天会让提醒直接失效。
            var guard = 0
            while (guard < 1600 && !isEffectiveDate(
                    day, schedule, weekdayMask, intervalDays, monthDaysMask,
                    yearlyMonth, yearlyDay, createdDate,
                )
            ) {
                day = day.plusDays(1)
                target = LocalDateTime.of(day, LocalTime.of(hour, minute))
                guard++
            }
        }

        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(
            context, id, title, time, repeat, effectiveOnly, schedule,
            weekdayMask, intervalDays, monthDaysMask, yearlyMonth, yearlyDay,
            createdDate,
        )
        return try {
            manager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                target.atZone(zone).toInstant().toEpochMilli(),
                pending,
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    /** 与 Dart `Task.isScheduledOn` 保持同一套判定。 */
    private fun isEffectiveDate(
        day: LocalDate,
        schedule: String,
        weekdayMask: Int,
        intervalDays: Int,
        monthDaysMask: Int,
        yearlyMonth: Int,
        yearlyDay: Int,
        createdDate: String,
    ): Boolean {
        return when (schedule) {
            "weekdays" -> (weekdayMask and (1 shl (day.dayOfWeek.value - 1))) != 0
            "intervalDays" -> {
                val start = runCatching { LocalDate.parse(createdDate, DATE_FORMAT) }
                    .getOrDefault(day)
                val interval = intervalDays.coerceAtLeast(1)
                (ChronoUnit.DAYS.between(start, day) % interval) == 0L
            }
            "monthlyDays" -> (monthDaysMask and (1 shl (day.dayOfMonth - 1))) != 0
            "yearlyDate" -> day.monthValue == yearlyMonth && day.dayOfMonth == yearlyDay
            else -> true
        }
    }

    private fun pendingIntent(
        context: Context,
        id: Int,
        title: String,
        time: String,
        repeat: Boolean,
        effectiveOnly: Boolean,
        schedule: String,
        weekdayMask: Int,
        intervalDays: Int,
        monthDaysMask: Int,
        yearlyMonth: Int,
        yearlyDay: Int,
        createdDate: String,
    ): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_TIME, time)
            putExtra(EXTRA_REPEAT, repeat)
            putExtra(EXTRA_EFFECTIVE_ONLY, effectiveOnly)
            putExtra(EXTRA_SCHEDULE, schedule)
            putExtra(EXTRA_WEEKDAY_MASK, weekdayMask)
            putExtra(EXTRA_INTERVAL_DAYS, intervalDays)
            putExtra(EXTRA_MONTH_DAYS_MASK, monthDaysMask)
            putExtra(EXTRA_YEARLY_MONTH, yearlyMonth)
            putExtra(EXTRA_YEARLY_DAY, yearlyDay)
            putExtra(EXTRA_CREATED_DATE, createdDate)
        }
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun cancelAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(KEY_IDS, emptySet()) ?: emptySet()
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (raw in ids) {
            val id = raw.toIntOrNull() ?: continue
            val intent = Intent(context, ReminderReceiver::class.java)
            val pending = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            manager.cancel(pending)
            pending.cancel()
        }
        prefs.edit().remove(KEY_IDS).apply()
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        val groupId = "xunji_reminder_group"
        manager.createNotificationChannelGroup(
            NotificationChannelGroup(groupId, context.getString(com.xunji.checkin.R.string.reminder_group)),
        )
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(com.xunji.checkin.R.string.reminder_channel),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(com.xunji.checkin.R.string.reminder_channel_desc)
            group = groupId
            setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
    }

    const val CHANNEL_ID = "xunji_reminder"
}
