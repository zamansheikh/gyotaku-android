import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The notification that stands in for the app while its window is put
/// away: what is being read, how far along it is, and at the end how it
/// went. Showing it is also what lets the reading carry on in the
/// background, see `ScanService` on the Android side.
///
/// Every call is best effort. A phone with no such service (iOS, for now)
/// or with notifications refused still reads; it just does so unseen.
class ScanNotice {
  static const _channel = MethodChannel('gyotaku/scan');

  /// Called when Pause is pressed on the notification.
  set onPause(VoidCallback? f) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pause') f?.call();
    });
  }

  DateTime _shown = DateTime.fromMillisecondsSinceEpoch(0);
  String? _last;

  /// Whether a notification would be seen. True where there is no telling,
  /// so nothing is asked for on a system that has nothing to ask.
  Future<bool> allowed() async {
    try {
      return await _channel.invokeMethod<bool>('allowed') ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Asks Android for leave to show notifications, and comes back once
  /// that is answered. Only ever called from something that says what the
  /// notification is for: the reading goes on without it, just unseen.
  ///
  /// Android puts its question twice and no more, and before Android 13
  /// has a switch in its settings and no question at all. Where it will
  /// not ask, its settings for the app are opened at that switch instead.
  Future<void> ask() async {
    String? answer;
    try {
      answer = await _channel.invokeMethod<String>('ask');
    } on MissingPluginException {
      // No such service on this system.
    } catch (e) {
      debugPrint('gyotaku: notification ask failed: $e');
    }
    if (answer == 'unasked') await settings();
  }

  /// Opens the system's settings for this app's notifications.
  Future<void> settings() => _call('settings');

  /// Shows or moves the progress. `total` of 0 means "working, no telling
  /// how long". Calls that come faster than Android wants are dropped,
  /// unless `now` says this one matters (a new stage).
  Future<void> show(
    String title,
    String text, {
    int done = 0,
    int total = 0,
    bool now = false,
  }) async {
    final at = DateTime.now();
    final same = '$title|$text|$done|$total' == _last;
    if (same) return;
    if (!now && at.difference(_shown) < const Duration(milliseconds: 700)) {
      return;
    }
    _shown = at;
    _last = '$title|$text|$done|$total';
    await _call('show', {
      'title': title,
      'text': text,
      'done': done,
      'total': total,
    });
  }

  /// Takes the progress away. With a title, leaves a line behind saying how
  /// the reading went.
  Future<void> finish({String? title, String? text}) async {
    _last = null;
    await _call('finish', {'title': title, 'text': text});
  }

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    try {
      await _channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      // No such service on this system.
    } catch (e) {
      debugPrint('gyotaku: notification $method failed: $e');
    }
  }
}
