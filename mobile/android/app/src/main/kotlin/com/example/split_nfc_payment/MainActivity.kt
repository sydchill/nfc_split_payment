package com.example.split_nfc_payment

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Hosts the Flutter app and provides the two Android pieces the browser-based
/// Google sign-in needs:
///
///  1. `open` — hand a URL to the system browser.
///  2. the OAuth redirect — Google sends the user back to
///     `com.example.split_nfc_payment:/oauth2redirect?code=…`, declared as an
///     intent-filter on this activity. `launchMode="singleTop"` means the
///     redirect arrives at [onNewIntent] on the *existing* instance, so the
///     Flutter engine (and the pending sign-in) is still alive.
///
/// This replaces the `flutter_web_auth_2` plugin, which applies the Kotlin
/// Gradle Plugin — something future Flutter versions will refuse to build.
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /// Set when a redirect arrives before Dart has attached its handler.
    private var pendingRedirect: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        channel = methodChannel

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("no_url", "A url argument is required.", null)
                    } else {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("no_browser", e.message, null)
                        }
                    }
                }
                // Dart calls this once it is listening, to collect a redirect
                // that landed while the engine was still starting up.
                "consumePendingRedirect" -> {
                    result.success(pendingRedirect)
                    pendingRedirect = null
                }
                else -> result.notImplemented()
            }
        }

        intent?.let { deliver(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliver(intent)
    }

    private fun deliver(intent: Intent) {
        if (intent.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        if (uri.scheme != REDIRECT_SCHEME) return

        val target = channel
        if (target == null) {
            pendingRedirect = uri.toString()
        } else {
            target.invokeMethod("onRedirect", uri.toString())
        }
    }

    private companion object {
        const val CHANNEL = "patela/oauth"
        const val REDIRECT_SCHEME = "com.example.split_nfc_payment"
    }
}
