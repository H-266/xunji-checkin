package com.xunji.checkin.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 零点刷新接收器。
 *
 * 只负责“让两个 Provider 用 SharedPreferences 里的最后一份数据重绘”，
 * 不启动 Flutter、不访问数据库、不申请开机广播。
 * 若卡片数据已跨天，WidgetRenderer 会根据日期自动切换成新一天的空状态。
 */
class MidnightRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != WidgetUpdateScheduler.ACTION_MIDNIGHT_REFRESH) return
        WidgetUpdateScheduler.refreshAll(context)
        WidgetUpdateScheduler.scheduleNext(context)
    }
}
