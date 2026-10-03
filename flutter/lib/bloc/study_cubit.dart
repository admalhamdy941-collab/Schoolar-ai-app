import 'dart:async';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/prompts.dart';
import '../models/models.dart';
import '../services/cache_service.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';
import 'gamification_cubit.dart';

enum StudyStatus { idle, loading, success, failure }

class StudyState extends Equatable {
  final StudyStatus status;
  final StudySession? current;
  final List<StudySession> history;
  final String? error;
  const StudyState({this.status = StudyStatus.idle, this.current, this.history = const [], this.error});
  StudyState copyWith({StudyStatus? status, StudySession? current, List<StudySession>? history, String? error, bool clearCurrent = false}) =>
      StudyState(status: status ?? this.status, current: clearCurrent ? null : (current ?? this.current), history: history ?? this.history, error: error);
  @override
  List<Object?> get props => [status, current, history, error];
}

/// One cubit per module tab. Orchestrates Gemini → cache → gamification.
class StudyCubit extends Cubit<StudyState> {
  StudyCubit({required this.module, required GeminiService gemini, required CacheService cache, required GamificationCubit gamification})
      : _gemini = gemini, _cache = cache, _gamification = gamification,
        super(StudyState(history: cache.allSessions(module: module)));

  final StudyModule module;
  final GeminiService _gemini;
  final CacheService _cache;
  final GamificationCubit _gamification;

  Future<void> generate({required String input, required AppLang lang, Uint8List? imageBytes, String? imageMime, String? targetLanguage, StudyLevel level = StudyLevel.bac}) async {
    emit(state.copyWith(status: StudyStatus.loading));
    try {
      final result = await _gemini.generate(module: module, lang: lang, input: input, imageBytes: imageBytes, imageMime: imageMime ?? 'image/jpeg', targetLanguage: targetLanguage, level: level);
      final session = StudySession(
        id: DateTime.now().microsecondsSinceEpoch.toString(), module: module, lang: lang,
        input: input.isEmpty ? '[image]' : input, result: result, createdAt: DateTime.now(),
      );
      await _cache.saveSession(session); // offline-first: persist before showing
      _gamification.recordSession(module);
      await FirebaseService.logEvent('ai_generate', <String, Object>{'module': module.name, 'cached': false});
      unawaited(FirebaseService.trackValueMoment());
      emit(state.copyWith(status: StudyStatus.success, current: session, history: _cache.allSessions(module: module)));
    } catch (e) {
      emit(state.copyWith(status: StudyStatus.failure, error: e.toString()));
    }
  }

  Future<void> completeQuiz(String sessionId, int correct, int total) async {
    final s = _cache.session(sessionId);
    if (s == null || s.quizScore != null) return;
    await _cache.saveSession(s.copyWith(quizScore: correct));
    _gamification.recordQuiz(correct: correct, total: total);
    emit(state.copyWith(current: _cache.session(sessionId), history: _cache.allSessions(module: module)));
  }

  void open(String id) => emit(state.copyWith(status: StudyStatus.success, current: _cache.session(id)));
  void close() => emit(state.copyWith(status: StudyStatus.idle, clearCurrent: true));
}
