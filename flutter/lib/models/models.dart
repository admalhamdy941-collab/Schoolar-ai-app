import 'package:equatable/equatable.dart';
import '../core/prompts.dart';

/// Typed result models. Stored in Hive as JSON maps (no codegen needed for the
/// result payload itself; adapters are only used for the lightweight session index).

class QuizQuestion extends Equatable {
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  const QuizQuestion({required this.question, required this.options, required this.answerIndex, required this.explanation});
  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        question: j['question']?.toString() ?? '',
        options: (j['options'] as List? ?? []).map((e) => e.toString()).toList(),
        answerIndex: (j['answerIndex'] as num?)?.toInt() ?? 0,
        explanation: j['explanation']?.toString() ?? '',
      );
  @override
  List<Object?> get props => [question, options, answerIndex, explanation];
}

class Flashcard extends Equatable {
  final String front, back;
  const Flashcard({required this.front, required this.back});
  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(front: j['front']?.toString() ?? '', back: j['back']?.toString() ?? '');
  @override
  List<Object?> get props => [front, back];
}

class ActiveRecall extends Equatable {
  final List<QuizQuestion> quiz;
  final List<Flashcard> flashcards;
  const ActiveRecall({required this.quiz, required this.flashcards});
  factory ActiveRecall.fromJson(Map<String, dynamic>? j) => ActiveRecall(
        quiz: ((j?['quiz'] as List?) ?? []).take(3).map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e))).toList(),
        flashcards: ((j?['flashcards'] as List?) ?? []).take(3).map((e) => Flashcard.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
  @override
  List<Object?> get props => [quiz, flashcards];
}

class SolutionStep extends Equatable {
  final String title, content;
  final String? why;
  const SolutionStep({required this.title, required this.content, this.why});
  factory SolutionStep.fromJson(Map<String, dynamic> j) =>
      SolutionStep(title: j['title']?.toString() ?? '', content: j['content']?.toString() ?? '', why: j['why']?.toString());
  @override
  List<Object?> get props => [title, content, why];
}

/// Generic AI result: keeps the raw JSON for rendering flexibility and
/// exposes strongly-typed accessors for the parts the UI depends on.
class AIResult extends Equatable {
  final StudyModule module;
  final String title;
  final Map<String, dynamic> raw;
  final ActiveRecall recall;
  const AIResult({required this.module, required this.title, required this.raw, required this.recall});

  factory AIResult.fromJson(StudyModule module, Map<String, dynamic> j) => AIResult(
        module: module,
        title: j['title']?.toString() ?? 'Study Result',
        raw: j,
        recall: ActiveRecall.fromJson(j['recall'] is Map ? Map<String, dynamic>.from(j['recall']) : null),
      );

  List<String> strings(String key) => ((raw[key] as List?) ?? []).map((e) => e.toString()).toList();
  List<Map<String, dynamic>> maps(String key) => ((raw[key] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
  List<SolutionStep> get steps => maps('steps').map(SolutionStep.fromJson).toList();
  String get finalAnswer => raw['finalAnswer']?.toString() ?? '';

  Map<String, dynamic> toJson() => raw;
  @override
  List<Object?> get props => [module, title, raw];
}

/// Cached study session (offline-first).
class StudySession extends Equatable {
  final String id;
  final StudyModule module;
  final AppLang lang;
  final String input;
  final AIResult result;
  final DateTime createdAt;
  final int? quizScore;
  const StudySession({required this.id, required this.module, required this.lang, required this.input, required this.result, required this.createdAt, this.quizScore});

  StudySession copyWith({int? quizScore}) =>
      StudySession(id: id, module: module, lang: lang, input: input, result: result, createdAt: createdAt, quizScore: quizScore ?? this.quizScore);

  Map<String, dynamic> toJson() => {
        'id': id, 'module': module.name, 'lang': lang.name, 'input': input,
        'result': result.toJson(), 'createdAt': createdAt.toIso8601String(), 'quizScore': quizScore,
      };
  factory StudySession.fromJson(Map<String, dynamic> j) {
    final module = StudyModule.values.byName(j['module']);
    return StudySession(
      id: j['id'], module: module, lang: AppLang.values.byName(j['lang']), input: j['input'] ?? '',
      result: AIResult.fromJson(module, Map<String, dynamic>.from(j['result'])),
      createdAt: DateTime.parse(j['createdAt']), quizScore: j['quizScore'],
    );
  }
  @override
  List<Object?> get props => [id, quizScore];
}
