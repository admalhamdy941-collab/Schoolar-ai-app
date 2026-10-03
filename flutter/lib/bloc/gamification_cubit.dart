import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/prompts.dart';
import '../services/cache_service.dart';

class Badge extends Equatable {
  final String code, name, emoji, description;
  const Badge(this.code, this.name, this.emoji, this.description);
  @override
  List<Object?> get props => [code];
}

const kBadgeCatalog = <String, Badge>{
  'first_session': Badge('first_session', 'First Spark', '✨', 'Completed your first study session.'),
  'text_scholar': Badge('text_scholar', 'Text Scholar', '📚', 'Prepared 5 texts for class.'),
  'math_ninja': Badge('math_ninja', 'Math Ninja', '🥷', 'Solved 5 problems step by step.'),
  'summary_sage': Badge('summary_sage', 'Summary Sage', '🧠', 'Summarised 5 lessons.'),
  'word_smith': Badge('word_smith', 'Wordsmith', '✒️', 'Completed 5 grammar analyses.'),
  'streak_3': Badge('streak_3', 'On Fire', '🔥', '3-day study streak.'),
  'streak_7': Badge('streak_7', 'Week Warrior', '🗓️', '7-day study streak.'),
  'streak_30': Badge('streak_30', 'Iron Discipline', '🛡️', '30-day study streak.'),
  'level_5': Badge('level_5', 'Rising Star', '⭐', 'Reached level 5.'),
  'level_10': Badge('level_10', 'Honour Roll', '🏆', 'Reached level 10.'),
  'perfect_quiz': Badge('perfect_quiz', 'Sharp Mind', '🎯', 'Scored 3/3 on a micro-quiz.'),
  'dialect_fluent': Badge('dialect_fluent', 'Darija Fluent', '🗣️', 'Explained 3 lessons in dialect.'),
};

class GamificationState extends Equatable {
  final int xp, currentStreak, longestStreak;
  final DateTime? lastStudyDate;
  final Map<StudyModule, int> moduleCounts;
  final List<String> badgeCodes;
  final List<Badge> justUnlocked; // transient, for toasts

  const GamificationState({
    this.xp = 0, this.currentStreak = 0, this.longestStreak = 0, this.lastStudyDate,
    this.moduleCounts = const {}, this.badgeCodes = const [], this.justUnlocked = const [],
  });

  /// Triangular level curve: level n needs 100·n XP to advance.
  int get level {
    var l = 1, rem = xp;
    while (rem >= 100 * l) { rem -= 100 * l; l++; }
    return l;
  }
  int get xpIntoLevel { var l = 1, rem = xp; while (rem >= 100 * l) { rem -= 100 * l; l++; } return rem; }
  int get xpForNextLevel => 100 * level;
  bool get studiedToday => lastStudyDate != null && _sameDay(lastStudyDate!, DateTime.now());
  int get liveStreak {
    if (lastStudyDate == null) return 0;
    final gap = DateTime.now().difference(DateTime(lastStudyDate!.year, lastStudyDate!.month, lastStudyDate!.day)).inDays;
    return gap <= 1 ? currentStreak : 0;
  }
  List<Badge> get badges => badgeCodes.map((c) => kBadgeCatalog[c]!).toList();

  GamificationState copyWith({int? xp, int? currentStreak, int? longestStreak, DateTime? lastStudyDate, Map<StudyModule, int>? moduleCounts, List<String>? badgeCodes, List<Badge>? justUnlocked}) =>
      GamificationState(
        xp: xp ?? this.xp, currentStreak: currentStreak ?? this.currentStreak, longestStreak: longestStreak ?? this.longestStreak,
        lastStudyDate: lastStudyDate ?? this.lastStudyDate, moduleCounts: moduleCounts ?? this.moduleCounts,
        badgeCodes: badgeCodes ?? this.badgeCodes, justUnlocked: justUnlocked ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'xp': xp, 'currentStreak': currentStreak, 'longestStreak': longestStreak,
        'lastStudyDate': lastStudyDate?.toIso8601String(),
        'moduleCounts': moduleCounts.map((k, v) => MapEntry(k.name, v)), 'badgeCodes': badgeCodes,
      };
  factory GamificationState.fromJson(Map j) => GamificationState(
        xp: j['xp'] ?? 0, currentStreak: j['currentStreak'] ?? 0, longestStreak: j['longestStreak'] ?? 0,
        lastStudyDate: j['lastStudyDate'] != null ? DateTime.parse(j['lastStudyDate']) : null,
        moduleCounts: {for (final e in (j['moduleCounts'] as Map? ?? {}).entries) StudyModule.values.byName(e.key): e.value as int},
        badgeCodes: List<String>.from(j['badgeCodes'] ?? []),
      );

  @override
  List<Object?> get props => [xp, currentStreak, longestStreak, lastStudyDate, moduleCounts, badgeCodes, justUnlocked];
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Student Streak & XP Gamification System (persisted in Hive).
class GamificationCubit extends Cubit<GamificationState> {
  GamificationCubit(this._cache) : super(const GamificationState()) {
    final saved = _cache.read<Map>('gamification');
    if (saved != null) emit(GamificationState.fromJson(saved));
  }
  final CacheService _cache;
  int previousXp = 0;

  static const xpPerModule = {StudyModule.text: 25, StudyModule.solver: 30, StudyModule.summary: 25, StudyModule.grammar: 20, StudyModule.dialect: 25};

  void recordSession(StudyModule module) {
    final counts = Map<StudyModule, int>.from(state.moduleCounts)..update(module, (v) => v + 1, ifAbsent: () => 1);
    _apply(xpDelta: xpPerModule[module]!, moduleCounts: counts);
  }

  void recordQuiz({required int correct, required int total}) {
    final perfect = total > 0 && correct == total;
    _apply(xpDelta: correct * 10 + (perfect ? 15 : 0), perfectQuiz: perfect);
  }

  void _apply({required int xpDelta, Map<StudyModule, int>? moduleCounts, bool perfectQuiz = false}) {
    final now = DateTime.now();
    var streak = state.currentStreak;
    if (state.lastStudyDate == null) {
      streak = 1;
    } else {
      final last = state.lastStudyDate!;
      final gap = DateTime(now.year, now.month, now.day).difference(DateTime(last.year, last.month, last.day)).inDays;
      if (gap == 1) streak += 1; else if (gap > 1) streak = 1;
    }
    var next = state.copyWith(
      xp: state.xp + xpDelta, currentStreak: streak,
      longestStreak: streak > state.longestStreak ? streak : state.longestStreak,
      lastStudyDate: now, moduleCounts: moduleCounts,
    );

    final counts = next.moduleCounts;
    final total = counts.values.fold(0, (a, b) => a + b);
    final candidates = <String>[
      if (total >= 1) 'first_session',
      if ((counts[StudyModule.text] ?? 0) >= 5) 'text_scholar',
      if ((counts[StudyModule.solver] ?? 0) >= 5) 'math_ninja',
      if ((counts[StudyModule.summary] ?? 0) >= 5) 'summary_sage',
      if ((counts[StudyModule.grammar] ?? 0) >= 5) 'word_smith',
      if ((counts[StudyModule.dialect] ?? 0) >= 3) 'dialect_fluent',
      if (streak >= 3) 'streak_3', if (streak >= 7) 'streak_7', if (streak >= 30) 'streak_30',
      if (next.level >= 5) 'level_5', if (next.level >= 10) 'level_10',
      if (perfectQuiz) 'perfect_quiz',
    ];
    final unlocked = candidates.where((c) => !next.badgeCodes.contains(c)).map((c) => kBadgeCatalog[c]!).toList();
    next = next.copyWith(badgeCodes: [...next.badgeCodes, ...unlocked.map((b) => b.code)], justUnlocked: unlocked);

    previousXp = state.xp;
    _cache.write('gamification', next.toJson());
    emit(next);
  }
}
