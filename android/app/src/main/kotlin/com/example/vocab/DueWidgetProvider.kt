package com.example.vocab

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews

/**
 * Widget man hinh chinh: hien so tu den han on tap.
 *
 * So duoc Flutter day sang qua MethodChannel (MainActivity) va luu trong
 * SharedPreferences, vi vay widget van hien dung so cu ca khi app chua chay.
 * Widget KHONG tu tinh toan — so chi moi khi app mo va tai lai review stats
 * (xem lib/pages/recent_page.dart). Co y khong dat updatePeriodMillis de
 * khong dot pin cho mot con so chi doi vai lan/ngay.
 */
class DueWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    companion object {
        private const val PREFS = "due_widget"
        private const val KEY_COUNT = "count"
        private const val KEY_UPDATED_AT = "updated_at"
        private const val UNKNOWN = -1

        private fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        /** Flutter goi sau moi lan tai review stats. */
        fun setCount(context: Context, count: Int) {
            prefs(context).edit()
                .putInt(KEY_COUNT, if (count < 0) 0 else count)
                .putLong(KEY_UPDATED_AT, System.currentTimeMillis())
                .apply()
            updateAll(context)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, DueWidgetProvider::class.java)
            )
            if (ids == null || ids.isEmpty()) return
            val views = buildViews(context)
            for (id in ids) {
                manager.updateAppWidget(id, views)
            }
        }

        private fun buildViews(context: Context): RemoteViews {
            val count = prefs(context).getInt(KEY_COUNT, UNKNOWN)
            val views = RemoteViews(context.packageName, R.layout.due_widget)

            views.setTextViewText(
                R.id.widget_count,
                if (count == UNKNOWN) "--" else count.toString()
            )
            views.setTextViewText(
                R.id.widget_hint,
                when {
                    count == UNKNOWN -> "Mở app để cập nhật"
                    count == 0 -> "Hôm nay xong hết 🎉"
                    else -> "từ cần ôn"
                }
            )

            val openApp = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val pending = PendingIntent.getActivity(
                context,
                0,
                openApp,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            return views
        }
    }
}
