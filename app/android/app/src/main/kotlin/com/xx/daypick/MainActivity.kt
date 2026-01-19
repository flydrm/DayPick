package com.xx.daypick

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
