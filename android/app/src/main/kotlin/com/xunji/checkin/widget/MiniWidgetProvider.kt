package com.xunji.checkin.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.xunji.checkin.MainActivity
import com.xunji.checkin.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/** 1×1 迷你进度卡片：只展示今日完成率，整卡点击进入今日页。 */
class MiniWidgetProvider : HomeWidgetProvider() {

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

    private fun updateCard(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        prefs: SharedPreferences,
    ) {
        val raw = prefs.getString(KEY, null)
        val size = CheckinWidgetProvider.widgetSize(manager, id)
        val bitmap = WidgetRenderer.renderMini(context, size.first, size.second, raw)
        val views = RemoteViews(context.packageName, R.layout.widget_image)
        views.setImageViewBitmap(R.id.widget_image, bitmap)
        views.setOnClickPendingIntent(
            R.id.widget_image,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("xunji://open?tab=today"),
            ),
        )
        manager.updateAppWidget(id, views)
    }

    companion object {
        const val KEY = "xunji_mini_widget_data"
    }
}
