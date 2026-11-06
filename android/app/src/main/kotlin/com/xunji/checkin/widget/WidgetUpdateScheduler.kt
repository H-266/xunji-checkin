package com.xunji.checkin.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import java.time.ZonedDateTime

/**
 * 零点刷新调度。
 *
 * 刻意使用 setAndAllowWhileIdle 而不是 setExactAndAllowWhileIdle：
 * - 不申请 SCHEDULE_EXACT_ALARM，满足“无多余权限”；
 * - 零点后几分钟内刷新对打卡 App 足够；
 * - 不申请 RECEIVE_BOOT_COMPLETED，重启后打开一次 App 会重新调度。
 */
object WidgetUpdateScheduler {

    const val ACTION_MIDNIGHT_REFRESH =
        "com.xunji.checkin.action.MIDNIGHT_REFRESH"

    private const val REQUEST_CODE = 12001

    fun scheduleNext(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val now = ZonedDateTime.now()
        var next = now
            .withHour(0)
            .withMinute(2)
            .withSecond(0)
            .withNano(0)
        if (!next.isAfter(now)) {
            next = next.plusDays(1)
        }

        val intent = Intent(context, MidnightRefreshReceiver::class.java).apply {
            action = ACTION_MIDNIGHT_REFRESH
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val pending = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)

        try {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                next.toInstant().toEpochMilli(),
                pending,
            )
        } catch (_: SecurityException) {
            // 极少数定制 ROM 会限制闹钟；卡片仍会在 App 打开/打卡时刷新。
        }
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, MidnightRefreshReceiver::class.java).apply {
            action = ACTION_MIDNIGHT_REFRESH
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pending = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
        alarmManager.cancel(pending)
    }

    /** 显式刷新两个 Provider，兼容部分桌面忽略 updateWidget 的情况。 */
    fun refreshAll(context: Context) {
        refresh(context, CheckinWidgetProvider::class.java)
        refresh(context, HeatmapWidgetProvider::class.java)
    }

    private fun refresh(context: Context, provider: Class<*>) {
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, provider)
        val ids = manager.getAppWidgetIds(component)
        if (ids.isEmpty()) return

        val intent = Intent(context, provider).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        context.sendBroadcast(intent)
    }
}
