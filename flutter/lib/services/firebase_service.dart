import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Fault-tolerant Firebase facade.
///
/// Every Firebase call is guarded so the app remains fully functional when
/// Firebase is not configured yet (e.g. before `flutterfire configure`).
/// Nothing here may throw into the UI.
/// ─────────────────────────────────────────────────────────────────────────
class FirebaseService {
  FirebaseService._();
  static bool ready = false;

  static FirebaseAnalytics? _analytics;
  static final Map<String, bool> _flags = <String, bool>{};

  /// Remote Config keys — server-side kill switches for the viral loops.
  static const kCameraLocked = 'is_camera_locked';
  static const kDialectLocked = 'is_dialect_locked';

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      ready = true;
    } catch (e) {
      // Expected when firebase_options.dart has not been generated yet.
      ready = false;
      debugPrint(' Firebase not configured — running in standalone mode ($e)');
    }
  }

  static Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (!ready) return;
    try {
      await _analytics?.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  static Future<void> logAppOpen() async {
    if (!ready) return;
    try {
      await _analytics?.logAppOpen();
    } catch (_) {}
  }

  static Future<void> setUserProperty(String key, String value) async {
    if (!ready) return;
    try {
      await _analytics?.setUserProperty(name: key, value: value);
    } catch (_) {}
  }

  static Future<void> recordError(Object error, StackTrace stack, {String? reason}) async {
    if (!ready) return;
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack, reason: reason, fatal: true);
    } catch (_) {}
  }

  /// Fetch Remote Config flags with safe defaults and a short timeout so a
  /// slow network can never block first paint.
  static Future<Map<String, bool>> fetchFlags({Duration timeout = const Duration(seconds: 4)}) async {
    if (!ready) {
      return {kCameraLocked: true, kDialectLocked: true};
    }
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setDefaults(const {kCameraLocked: true, kDialectLocked: true});
      await rc.setConfigSettings(RemoteConfigSettings(fetchTimeout: timeout, minimumFetchInterval: Duration.zero));
      await rc.fetchAndActivate().timeout(timeout, onTimeout: () => false);
      _flags
        ..clear()
        ..addAll({
          kCameraLocked: rc.getBool(kCameraLocked),
          kDialectLocked: rc.getBool(kDialectLocked),
        });
    } catch (e, s) {
      await recordError(e, s, reason: 'RemoteConfig fetch failed');
    }
    return {..._flags, kCameraLocked: _flags[kCameraLocked] ?? true, kDialectLocked: _flags[kDialectLocked] ?? true};
  }

  /* ─────────────── In-app review prompt ─────────────── */
  static int _usageCount = 0;

  /// Call after every completed AI action; asks for a store review once the
  /// student has had three genuine value moments.
  static Future<void> trackValueMoment({int threshold = 3}) async {
    _usageCount++;
    if (_usageCount < threshold) return;
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        _usageCount = 0; // reset so we do not nag on every action
      }
    } catch (_) {}
  }
}
