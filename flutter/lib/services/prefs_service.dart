import 'package:hive_flutter/hive_flutter.dart';

/// Student preferences persisted locally (Hive) — no sign-up required.
class PrefsService {
  PrefsService(this._box);
  final Box _box;

  static const kLevel = 'study_level';
  static const kLocale = 'locale';
  static const kCameraUnlocked = 'camera_unlocked';
  static const kDialectUnlocked = 'dialect_unlocked';
  static const kThemeDark = 'theme_dark';

  static const levels = <String, String>{
    'bac': 'Baccalaureate (BAC)',
    'bem': 'BEM Exam',
    'secondary': 'Secondary School',
    'middle': 'Middle School',
  };

  String get level => _box.get(kLevel, defaultValue: 'bac') as String;
  Future<void> setLevel(String v) => _box.put(kLevel, v);

  String get locale => _box.get(kLocale, defaultValue: 'en') as String;
  Future<void> setLocale(String v) => _box.put(kLocale, v);

  bool get cameraUnlocked => _box.get(kCameraUnlocked, defaultValue: false) as bool;
  Future<void> setCameraUnlocked(bool v) => _box.put(kCameraUnlocked, v);

  bool get dialectUnlocked => _box.get(kDialectUnlocked, defaultValue: false) as bool;
  Future<void> setDialectUnlocked(bool v) => _box.put(kDialectUnlocked, v);
}
