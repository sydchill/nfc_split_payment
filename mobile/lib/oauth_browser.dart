import 'dart:async';

import 'package:flutter/services.dart';

/// Thrown when the user backs out of the browser without finishing.
class OAuthCancelled implements Exception {
  const OAuthCancelled();
}

/// Opens a URL in the system browser and waits for the OAuth redirect back.
///
/// The Android side lives in `MainActivity.kt`: it launches the browser and
/// forwards the `com.example.split_nfc_payment:/…` redirect over this channel.
/// Doing it in the app rather than through a plugin keeps the build free of
/// third-party Kotlin Gradle Plugin usage, which future Flutter versions reject.
class OAuthBrowser {
  OAuthBrowser({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('patela/oauth');

  final MethodChannel _channel;

  Completer<String>? _pending;

  /// Sends the user to [url] and completes with the redirect URL.
  ///
  /// Throws [OAuthCancelled] if nothing comes back before [timeout] — the user
  /// closed the browser, or never finished signing in.
  Future<String> authenticate({
    required String url,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    // Only one sign-in can be in flight; a second call supersedes the first.
    _pending?.completeError(const OAuthCancelled());
    final pending = _pending = Completer<String>();

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onRedirect' && !pending.isCompleted) {
        pending.complete(call.arguments as String);
      }
    });

    await _channel.invokeMethod<bool>('open', {'url': url});

    // A redirect can land before the handler above is attached (the engine may
    // still be starting), in which case the platform side holds on to it.
    final held = await _channel.invokeMethod<String>('consumePendingRedirect');
    if (held != null && !pending.isCompleted) pending.complete(held);

    try {
      return await pending.future.timeout(timeout,
          onTimeout: () => throw const OAuthCancelled());
    } finally {
      if (identical(_pending, pending)) _pending = null;
      _channel.setMethodCallHandler(null);
    }
  }
}
