import 'package:flutter/foundation.dart';
import '../core/models.dart';

enum LocalClosureCleanup { idle, cleaning, restartRequired, failed }

/// Firestore cannot be reused after terminate. Keep all private routes closed
/// until the app restarts; never silently continue with a terminated cache.
class CustomerLocalPrivacy {
  static final state = ValueNotifier(LocalClosureCleanup.idle);
  static Future<void> Function()? _pending;
  static Future<void>? _running;

  static Future<void> afterClosure({
    required Future<void> Function() closeSession,
    required Future<void> Function() clearStore,
  }) {
    if (state.value == LocalClosureCleanup.restartRequired) {
      return Future.value();
    }
    _pending ??= () async {
      UserSession.clearPersonalData();
      await closeSession();
      await clearStore();
    };
    return retry();
  }

  static Future<void> retry() {
    if (_running != null) return _running!;
    if (_pending == null) return Future.value();
    state.value = LocalClosureCleanup.cleaning;
    final task = _clean();
    _running = task;
    return task;
  }

  static Future<void> _clean() async {
    try {
      await _pending!();
      _pending = null;
      state.value = LocalClosureCleanup.restartRequired;
    } catch (_) {
      state.value = LocalClosureCleanup.failed;
      rethrow;
    } finally {
      _running = null;
    }
  }
}
