package com.xx.daypick

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class QuickActionsWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_actions_widget)
            views.setOnClickPendingIntent(
                R.id.quick_action_memo,
                pendingIntentForRoute(context, "/create?type=memo", "memo"),
            )
            views.setOnClickPendingIntent(
                R.id.quick_action_task,
                pendingIntentForRoute(context, "/create?type=task", "task"),
            )
            views.setOnClickPendingIntent(
                R.id.quick_action_focus,
                pendingIntentForRoute(context, "/focus", "focus"),
            )
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun pendingIntentForRoute(
        context: Context,
        route: String,
        key: String,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "com.xx.daypick.widget.$key"
            putExtra("route", route)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        return PendingIntent.getActivity(
            context,
            key.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

