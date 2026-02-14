package com.xx.daypick

import android.Manifest
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CALENDAR_CHANNEL = "daypick/calendar_constraints"
        private const val CALENDAR_PERMISSION_REQUEST_CODE = 4201
        private const val CALENDAR_PREFS_NAME = "daypick_permissions"
        private const val CALENDAR_PREF_KEY_REQUESTED = "calendar_permission_requested"
    }

    private var pendingCalendarPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALENDAR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPermissionState" -> {
                        result.success(getCalendarPermissionState())
                    }

                    "requestPermission" -> {
                        requestCalendarPermission(result)
                    }

                    "getBusyIntervals" -> {
                        val startMs = call.argument<Number>("start_ms")?.toLong()
                        val endMs = call.argument<Number>("end_ms")?.toLong()
                        if (startMs == null || endMs == null) {
                            result.error("bad_args", "Missing start_ms/end_ms", null)
                            return@setMethodCallHandler
                        }
                        result.success(getBusyIntervals(startMs = startMs, endMs = endMs))
                    }

                    "getTitledEvents" -> {
                        val startMs = call.argument<Number>("start_ms")?.toLong()
                        val endMs = call.argument<Number>("end_ms")?.toLong()
                        if (startMs == null || endMs == null) {
                            result.error("bad_args", "Missing start_ms/end_ms", null)
                            return@setMethodCallHandler
                        }
                        result.success(getTitledEvents(startMs = startMs, endMs = endMs))
                    }

                    "openAppSettings" -> {
                        openAppSettings()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun getCalendarPermissionState(): String {
        val granted =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_CALENDAR
            ) == PackageManager.PERMISSION_GRANTED
        if (granted) return "granted"

        val prefs = getSharedPreferences(CALENDAR_PREFS_NAME, MODE_PRIVATE)
        val requested = prefs.getBoolean(CALENDAR_PREF_KEY_REQUESTED, false)
        return if (requested) "denied" else "unknown"
    }

    private fun requestCalendarPermission(result: MethodChannel.Result) {
        if (pendingCalendarPermissionResult != null) {
            result.error("permission_in_progress", "Calendar permission request in progress", null)
            return
        }
        if (getCalendarPermissionState() == "granted") {
            result.success("granted")
            return
        }
        val prefs = getSharedPreferences(CALENDAR_PREFS_NAME, MODE_PRIVATE)
        prefs.edit().putBoolean(CALENDAR_PREF_KEY_REQUESTED, true).apply()
        pendingCalendarPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_CALENDAR),
            CALENDAR_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == CALENDAR_PERMISSION_REQUEST_CODE) {
            val granted =
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingCalendarPermissionResult?.success(if (granted) "granted" else "denied")
            pendingCalendarPermissionResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = Uri.fromParts("package", packageName, null)
        startActivity(intent)
    }

    private fun getBusyIntervals(startMs: Long, endMs: Long): List<Map<String, Long>> {
        if (endMs <= startMs) return emptyList()
        if (getCalendarPermissionState() != "granted") return emptyList()

        val uriBuilder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(uriBuilder, startMs)
        ContentUris.appendId(uriBuilder, endMs)
        val uri = uriBuilder.build()

        val results = mutableListOf<Map<String, Long>>()
        val projection = arrayOf(
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END
        )
        try {
            contentResolver.query(uri, projection, null, null, null).use { cursor ->
                if (cursor == null) return@use
                val beginIndex = cursor.getColumnIndex(CalendarContract.Instances.BEGIN)
                val endIndex = cursor.getColumnIndex(CalendarContract.Instances.END)
                if (beginIndex < 0 || endIndex < 0) return@use

                while (cursor.moveToNext()) {
                    val begin = cursor.getLong(beginIndex)
                    val end = cursor.getLong(endIndex)
                    if (end <= begin) continue
                    results.add(
                        mapOf(
                            "start_ms" to begin,
                            "end_ms" to end
                        )
                    )
                }
            }
        } catch (_: SecurityException) {
            return emptyList()
        } catch (_: RuntimeException) {
            return emptyList()
        }
        return results
    }

    private fun getTitledEvents(startMs: Long, endMs: Long): List<Map<String, Any?>> {
        if (endMs <= startMs) return emptyList()
        if (getCalendarPermissionState() != "granted") return emptyList()

        val uriBuilder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(uriBuilder, startMs)
        ContentUris.appendId(uriBuilder, endMs)
        val uri = uriBuilder.build()

        val results = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.TITLE
        )
        try {
            contentResolver.query(
                uri,
                projection,
                null,
                null,
                "${CalendarContract.Instances.BEGIN} ASC"
            ).use { cursor ->
                if (cursor == null) return@use
                val beginIndex = cursor.getColumnIndex(CalendarContract.Instances.BEGIN)
                val endIndex = cursor.getColumnIndex(CalendarContract.Instances.END)
                val titleIndex = cursor.getColumnIndex(CalendarContract.Instances.TITLE)
                if (beginIndex < 0 || endIndex < 0 || titleIndex < 0) return@use

                while (cursor.moveToNext()) {
                    val begin = cursor.getLong(beginIndex)
                    val end = cursor.getLong(endIndex)
                    if (end <= begin) continue
                    val title = if (cursor.isNull(titleIndex)) null else cursor.getString(titleIndex)
                    results.add(
                        mapOf(
                            "start_ms" to begin,
                            "end_ms" to end,
                            "title" to title
                        )
                    )
                }
            }
        } catch (_: SecurityException) {
            return emptyList()
        } catch (_: RuntimeException) {
            return emptyList()
        }
        return results
    }

    override fun getInitialRoute(): String? {
        val route = extractRoute(intent)
        return route ?: super.getInitialRoute()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = extractRoute(intent) ?: return
        flutterEngine?.navigationChannel?.pushRouteInformation(route)
    }

    private fun extractRoute(intent: Intent?): String? {
        if (intent == null) return null

        val fromExtra = intent.getStringExtra("route")?.trim()
        if (!fromExtra.isNullOrEmpty() && fromExtra.startsWith("/")) {
            return fromExtra
        }

        val fromAction = routeFromAction(intent)
        if (fromAction != null) return fromAction

        val uri: Uri = intent.data ?: return null
        if (uri.scheme != "daypick") return null

        val path = uri.path?.trim().orEmpty()
        if (path.isEmpty() || !path.startsWith("/")) return null
        val query = uri.encodedQuery
        return if (query.isNullOrEmpty()) {
            path
        } else {
            "$path?$query"
        }
    }

    private fun routeFromAction(intent: Intent): String? {
        return when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type?.startsWith("text/") != true) return null
                val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
                buildQuickCreateRoute(text)
            }
            Intent.ACTION_PROCESS_TEXT -> {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
                buildQuickCreateRoute(text)
            }
            else -> null
        }
    }

    private fun buildQuickCreateRoute(raw: String?): String? {
        if (raw.isNullOrBlank()) return null
        val text = raw.trimEnd()
        val maxChars = 4000
        val limited = if (text.length > maxChars) text.substring(0, maxChars) else text
        val encoded = Uri.encode(limited)
        return "/create?type=memo&text=$encoded"
    }
}
