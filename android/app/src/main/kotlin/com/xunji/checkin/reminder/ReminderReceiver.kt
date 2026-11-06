package com.xunji.checkin.reminder

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.xunji.checkin.MainActivity
import com.xunji.checkin.R

/**
 * 提醒到点：发一条本地通知，并安排明天同一时间。
 * 不访问网络、不持有唤醒锁。
 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(ReminderScheduler.EXTRA_ID, -1)
        val title = intent.getStringExtra(ReminderScheduler.EXTRA_TITLE) ?: "循记打卡"
        if (id < 0) return

        ReminderScheduler.ensureChannel(context)
        if (canNotify(context)) {
            val open = Intent(context, MainActivity::class.java).apply {
                data = android.net.Uri.parse("xunji://open?tab=today")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pending = PendingIntent.getActivity(
                context,
                id + 10000,
                open,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = Notification.Builder(
                context,
                ReminderScheduler.CHANNEL_ID,
            )
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(
                    context.getString(R.string.reminder_title, title),
                )
                .setContentText(context.getString(R.string.reminder_text))
                .setContentIntent(pending)
                .setAutoCancel(true)
                .build()
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            manager.notify(id, notification)
        }

        // 每日任务继续排下一天；临时待办只提醒一次。
        // 无论通知权限是否被拒绝，都继续排程，避免用户开启权限后失效。
        ReminderScheduler.rescheduleFromIntent(context, intent)
    }

    private fun canNotify(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return context.checkSelfPermission(
                android.Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        }
        return true
    }
}
