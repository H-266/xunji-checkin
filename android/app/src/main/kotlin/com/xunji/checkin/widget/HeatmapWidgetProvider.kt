package com.xunji.checkin.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import com.xunji.checkin.MainActivity
import com.xunji.checkin.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/** 热力日历卡片 Provider。整张卡片点击进入热力统计页。 */
class HeatmapWidgetProvider : HomeWidgetProvider() {

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
        newOptions: Bundle,
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
        val size = CheckinWidgetProvider.widgetSize(manager, id)
        val bitmap = WidgetRenderer.renderHeatmap(context, size.first, size.second, raw)

        val views = RemoteViews(context.packageName, R.layout.widget_image)
        views.setImageViewBitmap(R.id.widget_image, bitmap)
        views.setOnClickPendingIntent(
            R.id.widget_image,
            openHeatmap(context),
        )
        manager.updateAppWidget(id, views)
    }

    private fun openHeatmap(context: Context): PendingIntent {
        return HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("xunji://open?tab=heatmap"),
        )
    }

    private fun boundTagId(prefs: SharedPreferences, id: Int): Int {
        val boundKey = "xunji_widget_tag_heatmap_$id"
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
        const val KEY = "xunji_heatmap_widget_data"
        const val PENDING_TAG_KEY = "xunji_pending_tag_heatmap"
    }
}
