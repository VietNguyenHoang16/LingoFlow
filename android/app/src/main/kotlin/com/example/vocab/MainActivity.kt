package com.example.vocab

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cau noi cho widget man hinh chinh: Flutter day so tu den han sang,
        // widget luu lai va cap nhat RemoteViews (xem DueWidgetProvider).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateDueCount" -> {
                        val count = call.argument<Int>("count") ?: 0
                        DueWidgetProvider.setCount(applicationContext, count)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val CHANNEL = "vocab/due_widget"
    }
}
