package com.xunji.checkin.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.xunji.checkin.MainActivity
import com.xunji.checkin.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 打卡任务卡片 Provider。
 *
 * 卡片只读：不注册任何任务点击，整张卡片点击打开今日页；
 * 打卡动作仍在 App 内完成，随后由 App 主动刷新。
 */
class CheckinWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            updateCard(context, appWidgetManager, id, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateCard(
            context,
            appWidgetManager,
            appWidgetId,
            HomeWidgetPlugin.getData(context),
        )
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetUpdateScheduler.scheduleNext(context)
    }

    private fun updateCard(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        prefs: SharedPreferences,
    ) {
        val tagId = boundTagId(prefs, id)
        val raw = if (tagId > 0) {
            prefs.getString("${KEY}_tag_$tagId", null) ?: prefs.getString(KEY, null)
        } else {
            prefs.getString(KEY, null)
        }
        val size = widgetSize(manager, id)
        val bitmap = WidgetRenderer.renderCheckin(context, size.first, size.second, raw)

        val views = RemoteViews(context.packageName, R.layout.widget_image)
        views.setImageViewBitmap(R.id.widget_image, bitmap)
        views.setOnClickPendingIntent(
            R.id.widget_image,
            openToday(context),
        )
        manager.updateAppWidget(id, views)
    }

    private fun openToday(context: Context): PendingIntent {
        return HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("xunji://open?tab=today"),
        )
    }

    /**
     * 卡片标签绑定：首次渲染时消费 App 写入的待绑定标签；未绑定返回 0（全局）。
     * 每张卡片独立存储，因此可以同时放多张不同标签的卡片。
     */
    private fun boundTagId(prefs: SharedPreferences, id: Int): Int {
        val boundKey = "xunji_widget_tag_checkin_$id"
        if (prefs.contains(boundKey)) return prefs.getInt(boundKey, 0)
        val pending = prefs.getString(PENDING_TAG_KEY, null)?.toIntOrNull() ?: 0
        if (pending > 0) {
            prefs.edit()
                .putInt(boundKey, pending)
                .remove(PENDING_TAG_KEY)
                .apply()
        }
        return pending
    }

    companion object {
        const val KEY = "xunji_checkin_widget_data"
        const val PENDING_TAG_KEY = "xunji_pending_tag_checkin"

        fun widgetSize(manager: AppWidgetManager, id: Int): Pair<Int, Int> {
            val options = manager.getAppWidgetOptions(id)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            return Pair(
                if (width <= 0) 250 else width,
                if (height <= 0) 110 else height,
            )
        }
    }
}
