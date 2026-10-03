import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/prompts.dart';
import '../models/models.dart';

/// Offline-First Smart Cache (Hive).
/// Every generated lesson / summary / flashcard set is serialised to JSON and
/// stored locally so students can study without connectivity.
class CacheService {
  static const _sessionsBox = 'sessions';
  static const _progressBox = 'progress';

  late final Box<String> _sessions;
  late final Box _progress;

  Future<void> init() async {
    await Hive.initFlutter();
    _sessions = await Hive.openBox<String>(_sessionsBox);
    _progress = await Hive.openBox(_progressBox);
  }

  // ---- Sessions ----
  Future<void> saveSession(StudySession s) => _sessions.put(s.id, jsonEncode(s.toJson()));

  List<StudySession> allSessions({StudyModule? module}) {
    final list = _sessions.values
        .map((raw) => StudySession.fromJson(Map<String, dynamic>.from(jsonDecode(raw))))
        .where((s) => module == null || s.module == module)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  StudySession? session(String id) {
    final raw = _sessions.get(id);
    return raw == null ? null : StudySession.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  Future<void> deleteSession(String id) => _sessions.delete(id);

  /// Notifies the History tab whenever a session is added or removed.
  Box<String> get sessionsBox => _sessions;
  ValueListenable<Box<String>> get sessionsListenable => _sessions.listenable();

  /// Wipes cached lessons (Settings → Clear cache). Gamification is preserved.
  Future<void> clearAll() async {
    await _sessions.clear();
  }

  // ---- Generic KV for gamification state ----
  T? read<T>(String key) => _progress.get(key) as T?;
  Future<void> write(String key, dynamic value) => _progress.put(key, value);
}
