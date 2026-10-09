// ═══════════════════════════════════════════════════════════════════════════
//  SCHOLAR AI — SINGLE-FILE, ZERO-DEPENDENCY BUILD
// ═══════════════════════════════════════════════════════════════════════════
//  Everything (models · i18n · theme · services · widgets · screens · logic)
//  lives in this one file and uses ONLY the Dart/Flutter SDK — no external
//  packages are required for `flutter run` to succeed.
//
//  Replacements for the dropped third-party plugins:
//  ─────────────────────────────────────────────────────────────────────────
//   hive / hive_flutter      → in-memory store + JSON file on disk (dart:io)
//   flutter_bloc             → ChangeNotifier + setState
//   google_generative_ai     → raw Gemini REST call via dart:io HttpClient
//   flutter_dotenv           → .env parsed by hand with dart:io
//   connectivity_plus        → InternetAddress.lookup probe (dart:io)
//   share_plus               → system share sheet stub + Clipboard fallback
//   screenshot               → RepaintBoundary.toImage() + PNG encode (dart:ui)
//   syncfusion_flutter_pdf   → pure-Dart PDF text extractor (dart:io ZLib)
//   receive_sharing_intent   → file path passed to ingestShared()
//   in_app_review            → local prompt stub
//   firebase_*               → no-op analytics/crash facade (debugPrint)
//   image_picker             → hook left open; text input works everywhere
//
//  Set your key either in `.env` (GEMINI_API_KEY=...) or in [_kApiKey] below.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/* ══════════════════════════════ 1. CONFIG ════════════════════════════════ */

/// Paste your key here OR create a `.env` file next to `pubspec.yaml`.
/// Free key: https://aistudio.google.com/apikey
const String _kApiKey = '';

/// `gemini-1.5-flash` has been retired by Google — this is the current
/// fast/free-tier model. Change it here if you prefer another.
const String _kModel = 'gemini-2.0-flash';

const String _kShareBaseUrl = 'https://scholar-ai.app';

/// Reads `.env` if present (GEMINI_API_KEY / GEMINI_MODEL).
Map<String, String> _loadEnvFile() {
  try {
    final f = File('.env');
    if (!f.existsSync()) return <String, String>{};
    final out = <String, String>{};
    for (final rawLine in f.readAsLinesSync()) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final i = line.indexOf('=');
      if (i <= 0) continue;
      out[line.substring(0, i).trim()] = line.substring(i + 1).trim();
    }
    return out;
  } catch (_) {
    return <String, String>{};
  }
}

/* ══════════════════════════════ 2. MODELS ═══════════════════════════════ */

enum StudyModule { text, solver, summary, grammar, dialect }

enum StudyLevel { bac, bem, secondary, middle }

enum AppLocale { en, fr, ar }

/* ══════════════════════════════ 3. L10N ═════════════════════════════════ */

extension _AppLocaleX on AppLocale {
  bool get isRtl => this == AppLocale.ar;
  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;
  String get flag => switch (this) { AppLocale.en => '🇬🇧', AppLocale.fr => '🇫🇷', AppLocale.ar => '🇸🇦' };
  String get code => switch (this) { AppLocale.en => 'EN', AppLocale.fr => 'FR', AppLocale.ar => 'ع' };
  String get label => switch (this) { AppLocale.en => 'English', AppLocale.fr => 'Français', AppLocale.ar => 'العربية' };
}

class LocaleController extends ChangeNotifier {
  AppLocale _locale = AppLocale.en;
  AppLocale get locale => _locale;
  bool get isRtl => _locale.isRtl;

  void set(AppLocale l) {
    if (l != _locale) {
      _locale = l;
      notifyListeners();
    }
  }

  void cycle() => set(AppLocale.values[(_locale.index + 1) % AppLocale.values.length]);

  String t(String key) => _L.dict[_locale]?[key] ?? _L.dict[AppLocale.en]?[key] ?? key;
  String module(StudyModule m) => t('mod_${m.name}');
  String moduleDesc(StudyModule m) => t('desc_${m.name}');
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({super.key, required LocaleController controller, required super.child}) : super(notifier: controller);
  static LocaleController of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
}

extension L10nContext on BuildContext {
  LocaleController get l10n => LocaleScope.of(this);
}

class _L {
  _L._();
  static const Map<AppLocale, Map<String, String>> dict = {
    AppLocale.en: {
      'app': 'Scholar AI', 'tagline': 'Study smarter. Remember longer.',
      'home': 'Home', 'history': 'Saved History', 'settings': 'Settings',
      'settings_profile': 'Settings & Profile', 'level': 'Educational level', 'language': 'App language',
      'mod_text': 'Text Prep', 'mod_solver': 'Exercise Solver', 'mod_summary': 'Lesson Summarizer',
      'mod_grammar': 'Grammar Assistant', 'mod_dialect': 'Dialect Explainer',
      'desc_text': 'Ideas, themes, vocabulary & takeaways',
      'desc_solver': 'Step-by-step with photo input',
      'desc_summary': 'Bullets, equations & slide outline',
      'desc_grammar': 'Correct, parse & translate',
      'desc_dialect': 'Simple Darija + real-life examples',
      'ph_text': 'Paste the story, poem or passage to prepare…',
      'ph_solver': 'Type the exercise. e.g. Solve 2x + 6 = 14',
      'ph_summary': 'Paste your long lesson notes here…',
      'ph_grammar': 'Paste a sentence to correct, parse and translate…',
      'ph_dialect': 'Paste the lesson you want explained in dialect…',
      'streak': 'Daily Streak', 'days': 'Days', 'xp': 'XP', 'scholar_rank': 'Scholar',
      'studied_today': 'Studied today', 'not_today': 'Study now to keep your streak!',
      'quick_start': 'Quick Start', 'badges': 'Badges',
      'no_badges': 'Complete a session to unlock your first badge.',
      'library': 'Offline Library', 'no_library': 'No saved lessons yet.',
      'sessions': 'sessions', 'best_streak': 'Best streak', 'total_xp': 'Total XP',
      'generate': 'Generate', 'thinking': 'Thinking…', 'camera': 'Camera',
      'translate_to': 'Translate to', 'example': 'Example', 'back': 'Back',
      'copy': 'Copy', 'share': 'Share', 'take_quiz': 'Take Micro-Quiz', 'copied': 'Copied!',
      'quiz': 'Micro-Quiz', 'flashcards': 'Flashcards', 'check': 'Check answers',
      'score': 'Score', 'flip': 'Tap to flip', 'next': 'Next', 'prev': 'Prev',
      'why': 'Why this formula?', 'reveal': 'Reveal step', 'final': 'Final answer',
      'problem': 'Problem', 'steps': 'Step-by-step', 'mistakes': 'Common mistakes',
      'core_ideas': 'Core ideas', 'themes': 'Sub-themes', 'vocab': 'Vocabulary in context',
      'takeaways': 'Takeaways', 'notes': 'Structured notes', 'equations': 'Key equations',
      'slides': 'Slide outline', 'corrected': 'Corrected text', 'issues': 'Issues & rules',
      'analysis': 'Sentence analysis', 'translation': 'Translation',
      'dialect_summary': 'Dialect summary', 'everyday_examples': 'Everyday examples',
      'term_glossary': 'Dialect ↔ exam terms', 'quick_steps': 'How to answer in the exam',
      'offline': 'Offline — cached lessons still available', 'error_generic': 'Something went wrong.',
      'xp_gained': 'XP gained', 'badge_unlocked': 'Badge unlocked', 'viral': 'Viral features',
      'unlock_title': 'Unlock Premium Feature 🚀',
      'unlock_body': 'Share Scholar AI with a classmate or your study group to instantly unlock this feature.',
      'unlock_share': 'Share to Unlock', 'unlock_later': 'Later',
      'unlock_success': 'Unlocked! ✅',
      'unlock_message': '🔥 Found the best AI app for lesson prep and step-by-step homework solving! Try Scholar AI:',
      'camera_locked_title': 'Camera Exercise Solver 🔒', 'camera_locked_sub': 'Share with a friend to unlock',
      'camera_unlocked_title': 'Camera Exercise Solver 🔓', 'camera_unlocked_sub': 'Snap a photo to solve',
      'dialect_locked_title': 'Explain in Dialect 🔒', 'dialect_unlocked_title': 'Explain in Dialect 🔓',
      'dialect_unlocked_sub': 'Simple Darija + real-life examples',
      'peer_title': 'Peer Quiz Challenge', 'peer_sub': 'Create and share quiz links with friends',
      'peer_need_quiz': 'Generate a lesson first — then challenge a classmate.',
      'peer_message': '🎯 I challenge you to beat my score on "{title}"! Play here: {link}',
      'pdf_title': 'Import PDF / Notes', 'pdf_sub': 'Extract text for AI processing',
      'pdf_hint': 'Paste a file path, or share a file into the app.',
      'pdf_ok': 'PDF extracted! Ready for AI processing ✨',
      'pdf_failed': 'Failed to parse the PDF.',
      'pdf_none': 'No text found in this PDF.',
      'story_title': "Today's Summary Card ⚡", 'story_export': 'Export as Story',
      'story_caption': "Check out today's lesson summary! ⚡ — Scholar AI",
      'story_kicker': "TODAY'S SUMMARY", 'story_empty': 'Generate a lesson first, then export a story card.',
      'story_saved': 'Story card saved',
      'rate_app': 'Rate Scholar AI', 'share_app': 'Share with friends',
      'clear_cache': 'Clear saved lessons', 'about': 'About',
      'demo_mode': 'Demo mode — add GEMINI_API_KEY to .env for real answers.',
      'camera_stub': 'Camera capture needs the image_picker plugin. Use text input for now.',
    },
    AppLocale.fr: {
      'app': 'Scholar AI', 'tagline': 'Étudie mieux. Retiens plus longtemps.',
      'home': 'Accueil', 'history': 'Historique', 'settings': 'Réglages',
      'settings_profile': 'Réglages & Profil', 'level': "Niveau d'études", 'language': "Langue de l'appli",
      'mod_text': 'Préparation de textes', 'mod_solver': "Résolution d'exercices",
      'mod_summary': 'Résumé de leçons', 'mod_grammar': 'Assistant Linguistique',
      'mod_dialect': 'Expliqueur en dialecte',
      'desc_text': 'Idées, thèmes, vocabulaire & morale',
      'desc_solver': 'Étape par étape avec photo',
      'desc_summary': 'Points clés, équations & diapositives',
      'desc_grammar': 'Corriger, analyser & traduire',
      'desc_dialect': 'Darija simple + exemples réels',
      'ph_text': 'Collez le texte, le poème ou le passage à préparer…',
      'ph_solver': "Saisissez l'exercice. ex. Résoudre 2x + 6 = 14",
      'ph_summary': 'Collez vos longues notes de cours ici…',
      'ph_grammar': 'Collez une phrase à corriger, analyser et traduire…',
      'ph_dialect': 'Collez la leçon à expliquer en dialecte…',
      'streak': 'Série quotidienne', 'days': 'Jours', 'xp': 'XP', 'scholar_rank': 'Érudit',
      'studied_today': "Étudié aujourd'hui", 'not_today': 'Étudie maintenant pour garder ta série !',
      'quick_start': 'Démarrage rapide', 'badges': 'Badges',
      'no_badges': 'Termine une session pour débloquer ton premier badge.',
      'library': 'Bibliothèque hors ligne', 'no_library': 'Aucune leçon enregistrée.',
      'sessions': 'sessions', 'best_streak': 'Meilleure série', 'total_xp': 'XP total',
      'generate': 'Générer', 'thinking': 'Réflexion…', 'camera': 'Caméra',
      'translate_to': 'Traduire en', 'example': 'Exemple', 'back': 'Retour',
      'copy': 'Copier', 'share': 'Partager', 'take_quiz': 'Faire le micro-quiz', 'copied': 'Copié !',
      'quiz': 'Micro-quiz', 'flashcards': 'Cartes mémoire', 'check': 'Vérifier',
      'score': 'Score', 'flip': 'Touchez pour retourner', 'next': 'Suivant', 'prev': 'Précédent',
      'why': 'Pourquoi cette formule ?', 'reveal': "Révéler l'étape", 'final': 'Réponse finale',
      'problem': 'Problème', 'steps': 'Étape par étape', 'mistakes': 'Erreurs fréquentes',
      'core_ideas': 'Idées principales', 'themes': 'Sous-thèmes', 'vocab': 'Vocabulaire en contexte',
      'takeaways': 'Leçons à retenir', 'notes': 'Notes structurées', 'equations': 'Équations clés',
      'slides': 'Plan des diapositives', 'corrected': 'Texte corrigé', 'issues': 'Erreurs & règles',
      'analysis': 'Analyse de la phrase', 'translation': 'Traduction',
      'dialect_summary': 'Résumé en dialecte', 'everyday_examples': 'Exemples du quotidien',
      'term_glossary': "Dialecte ↔ termes d'examen", 'quick_steps': "Comment répondre à l'examen",
      'offline': 'Hors ligne — leçons en cache disponibles', 'error_generic': 'Une erreur est survenue.',
      'xp_gained': 'XP gagnés', 'badge_unlocked': 'Badge débloqué', 'viral': 'Fonctions virales',
      'unlock_title': 'Débloquer la fonction 🚀',
      'unlock_body': "Partage Scholar AI avec un camarade ou ton groupe d'étude pour débloquer cette fonction.",
      'unlock_share': 'Partager pour débloquer', 'unlock_later': 'Plus tard',
      'unlock_success': 'Débloqué ! ✅',
      'unlock_message': "🔥 La meilleure appli IA pour préparer les cours et résoudre les devoirs ! Scholar AI :",
      'camera_locked_title': "Solveur d'exercices caméra 🔒", 'camera_locked_sub': 'Partage avec un ami pour débloquer',
      'camera_unlocked_title': "Solveur d'exercices caméra 🔓", 'camera_unlocked_sub': 'Prends une photo pour résoudre',
      'dialect_locked_title': 'Expliquer en dialecte 🔒', 'dialect_unlocked_title': 'Expliquer en dialecte 🔓',
      'dialect_unlocked_sub': 'Darija simple + exemples réels',
      'peer_title': 'Défi quiz entre camarades', 'peer_sub': 'Crée et partage des liens de quiz',
      'peer_need_quiz': "Génère d'abord une leçon, puis défie un camarade.",
      'peer_message': '🎯 Je te défie de battre mon score sur « {title} » ! Joue ici : {link}',
      'pdf_title': 'Importer un PDF / notes', 'pdf_sub': 'Extraire le texte pour l’IA',
      'pdf_hint': 'Collez un chemin de fichier ou partagez un fichier.',
      'pdf_ok': 'PDF extrait ! Prêt pour l’IA ✨',
      'pdf_failed': "Impossible d'analyser le PDF.",
      'pdf_none': 'Aucun texte trouvé dans ce PDF.',
      'story_title': 'Carte résumé du jour ⚡', 'story_export': 'Exporter en Story',
      'story_caption': 'Voici le résumé du jour ! ⚡ — Scholar AI',
      'story_kicker': 'RÉSUMÉ DU JOUR', 'story_empty': "Génère d'abord une leçon, puis exporte une carte.",
      'story_saved': 'Carte enregistrée',
      'rate_app': 'Noter Scholar AI', 'share_app': 'Partager avec des amis',
      'clear_cache': 'Effacer les leçons', 'about': 'À propos',
      'demo_mode': 'Mode démo — ajoute GEMINI_API_KEY dans .env.',
      'camera_stub': 'La caméra nécessite le plugin image_picker. Utilise le texte pour le moment.',
    },
    AppLocale.ar: {
      'app': 'سكولار AI', 'tagline': 'ادرس بذكاء. تذكّر لفترة أطول.',
      'home': 'الرئيسية', 'history': 'السجل', 'settings': 'الإعدادات',
      'settings_profile': 'الإعدادات والملف', 'level': 'المستوى الدراسي', 'language': 'لغة التطبيق',
      'mod_text': 'تحضير النصوص', 'mod_solver': 'حل التمارين', 'mod_summary': 'تلخيص الدروس',
      'mod_grammar': 'المساعد اللغوي', 'mod_dialect': 'الشرح بالدارجة',
      'desc_text': 'الأفكار والمحاور والمفردات والعِبر',
      'desc_solver': 'حل تدريجي مع إدخال بالصورة',
      'desc_summary': 'نقاط ومعادلات ومخطط شرائح',
      'desc_grammar': 'تصحيح وإعراب وترجمة',
      'desc_dialect': 'دارجة مبسّطة وأمثلة واقعية',
      'ph_text': 'الصق القصة أو القصيدة أو النص المراد تحضيره…',
      'ph_solver': 'اكتب التمرين. مثال: حل 2x + 6 = 14',
      'ph_summary': 'الصق ملاحظات الدرس الطويلة هنا…',
      'ph_grammar': 'الصق جملة لتصحيحها وإعرابها وترجمتها…',
      'ph_dialect': 'الصق الدرس لشرحه بالدارجة…',
      'streak': 'السلسلة اليومية', 'days': 'أيام', 'xp': 'نقطة', 'scholar_rank': 'باحث',
      'studied_today': 'درستَ اليوم', 'not_today': 'ادرس الآن للحفاظ على سلسلتك!',
      'quick_start': 'ابدأ بسرعة', 'badges': 'الأوسمة',
      'no_badges': 'أكمل جلسة لفتح أول وسام.',
      'library': 'المكتبة دون اتصال', 'no_library': 'لا توجد دروس محفوظة.',
      'sessions': 'جلسات', 'best_streak': 'أفضل سلسلة', 'total_xp': 'إجمالي النقاط',
      'generate': 'توليد', 'thinking': 'جارٍ التفكير…', 'camera': 'الكاميرا',
      'translate_to': 'ترجم إلى', 'example': 'مثال', 'back': 'رجوع',
      'copy': 'نسخ', 'share': 'مشاركة', 'take_quiz': 'ابدأ الاختبار القصير', 'copied': 'تم النسخ!',
      'quiz': 'اختبار قصير', 'flashcards': 'بطاقات المراجعة', 'check': 'تحقق من الإجابات',
      'score': 'النتيجة', 'flip': 'اضغط للقلب', 'next': 'التالي', 'prev': 'السابق',
      'why': 'لماذا هذا القانون؟', 'reveal': 'أظهر الخطوة', 'final': 'الإجابة النهائية',
      'problem': 'المسألة', 'steps': 'خطوة بخطوة', 'mistakes': 'أخطاء شائعة',
      'core_ideas': 'الأفكار الرئيسية', 'themes': 'المحاور الفرعية', 'vocab': 'المفردات في سياقها',
      'takeaways': 'العِبر', 'notes': 'ملاحظات منظمة', 'equations': 'المعادلات الأساسية',
      'slides': 'مخطط الشرائح', 'corrected': 'النص المصحح', 'issues': 'الأخطاء والقواعد',
      'analysis': 'الإعراب', 'translation': 'الترجمة',
      'dialect_summary': 'الملخص بالدارجة', 'everyday_examples': 'أمثلة من الواقع',
      'term_glossary': 'الدارجة ↔ مصطلحات الامتحان', 'quick_steps': 'كيف تجيب في الامتحان',
      'offline': 'غير متصل — الدروس المخزّنة متاحة', 'error_generic': 'حدث خطأ ما.',
      'xp_gained': 'نقاط مكتسبة', 'badge_unlocked': 'وسام جديد', 'viral': 'ميزات الانتشار',
      'unlock_title': 'افتح الميزة المميزة 🚀',
      'unlock_body': 'شارك سكولار AI مع زميل أو مجموعة دراسية لفتح هذه الميزة فوراً.',
      'unlock_share': 'شارك للفتح', 'unlock_later': 'لاحقاً',
      'unlock_success': 'تم الفتح! ✅',
      'unlock_message': '🔥 أفضل تطبيق ذكاء اصطناعي لتحضير الدروس وحل الواجبات! سكولار AI:',
      'camera_locked_title': 'حل التمارين بالكاميرا 🔒', 'camera_locked_sub': 'شارك مع صديق لفتح الميزة',
      'camera_unlocked_title': 'حل التمارين بالكاميرا 🔓', 'camera_unlocked_sub': 'التقط صورة للحل',
      'dialect_locked_title': 'الشرح بالدارجة 🔒', 'dialect_unlocked_title': 'الشرح بالدارجة 🔓',
      'dialect_unlocked_sub': 'دارجة مبسّطة وأمثلة واقعية',
      'peer_title': 'تحدّي الاختبار مع الزملاء', 'peer_sub': 'أنشئ روابط اختبار وشاركها',
      'peer_need_quiz': 'ولّد درساً أولاً ثم تحدَّ زميلاً.',
      'peer_message': '🎯 أتحداك أن تتجاوز نتيجتي في «{title}»! ابدأ من هنا: {link}',
      'pdf_title': 'استيراد PDF / ملاحظات', 'pdf_sub': 'استخرج النص للمعالجة بالذكاء الاصطناعي',
      'pdf_hint': 'ألصق مسار ملف أو شارك ملفاً داخل التطبيق.',
      'pdf_ok': 'تم استخراج الـ PDF! جاهز للمعالجة ✨',
      'pdf_failed': 'تعذّر تحليل ملف PDF.',
      'pdf_none': 'لا يوجد نص في هذا الملف.',
      'story_title': 'بطاقة ملخص اليوم ⚡', 'story_export': 'تصدير كقصة',
      'story_caption': 'إليك ملخص درس اليوم! ⚡ — سكولار AI',
      'story_kicker': 'ملخص اليوم', 'story_empty': 'ولّد درساً أولاً ثم صدّر البطاقة.',
      'story_saved': 'تم حفظ البطاقة',
      'rate_app': 'قيّم سكولار AI', 'share_app': 'شارك مع الأصدقاء',
      'clear_cache': 'مسح الدروس المحفوظة', 'about': 'حول',
      'demo_mode': 'الوضع التجريبي — أضف GEMINI_API_KEY في ملف .env.',
      'camera_stub': 'الكاميرا تحتاج إضافة image_picker. استخدم الإدخال النصي حالياً.',
    },
  };
}

/* ══════════════════════════════ 4. THEME ════════════════════════════════ */

class AppColors {
  AppColors._();
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surfaceHi = Color(0xFF273449);
  static const surfaceLo = Color(0xFF0B1222);
  static const border = Color(0x1FFFFFFF);
  static const muted = Color(0xFF94A3B8);
  static const primary = Color(0xFF818CF8);
  static const fire = Color(0xFFFB923C);
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFFB7185);

  static List<Color> gradient(StudyModule m) => switch (m) {
        StudyModule.text => const [Color(0xFF10B981), Color(0xFF06B6D4)],
        StudyModule.solver => const [Color(0xFF7C3AED), Color(0xFF4F46E5)],
        StudyModule.summary => const [Color(0xFFF59E0B), Color(0xFFF97316)],
        StudyModule.grammar => const [Color(0xFFF43F5E), Color(0xFFFB7185)],
        StudyModule.dialect => const [Color(0xFF22C55E), Color(0xFFEAB308)],
      };

  static Color accent(StudyModule m) => gradient(m).first;
  static String emoji(StudyModule m) => switch (m) {
        StudyModule.text => '📖',
        StudyModule.solver => '🧮',
        StudyModule.summary => '📝',
        StudyModule.grammar => '🔤',
        StudyModule.dialect => '🇩🇿',
      };
  static IconData icon(StudyModule m) => switch (m) {
        StudyModule.text => Icons.auto_stories_rounded,
        StudyModule.solver => Icons.functions_rounded,
        StudyModule.summary => Icons.summarize_rounded,
        StudyModule.grammar => Icons.translate_rounded,
        StudyModule.dialect => Icons.record_voice_over_rounded,
      };
}

List<BoxShadow> neuShadow({double blur = 18, double offset = 8}) => [
      BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: blur, offset: Offset(offset, offset)),
      BoxShadow(color: Colors.white.withOpacity(0.04), blurRadius: blur, offset: Offset(-offset, -offset)),
    ];

List<BoxShadow> glowShadow(Color c, {double strength = 0.45}) => [
      BoxShadow(color: c.withOpacity(strength), blurRadius: 28, spreadRadius: -4, offset: const Offset(0, 10)),
    ];

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark, surface: AppColors.surface);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLo,
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.all(18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceLo.withOpacity(0.92),
      height: 72,
      indicatorColor: AppColors.primary.withOpacity(0.2),
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHi,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerColor: AppColors.border,
  );
}

/* ══════════════════════════ 5. GEMINI PROMPTS ══════════════════════════ */

String _langRule(AppLocale l) => switch (l) {
      AppLocale.ar => 'أجب بالعربية الفصحى المبسطة المناسبة لطالب ثانوي/جامعي. (JSON KEYS stay in English; only VALUES are Arabic.)',
      AppLocale.fr => "Réponds en français clair et académique. (Les CLÉS JSON restent en anglais ; seules les VALEURS sont en français.)",
      AppLocale.en => 'Respond in clear, academic yet friendly English for a secondary / early-university student.',
    };

String _levelRule(StudyLevel lv) => switch (lv) {
      StudyLevel.bac => 'TARGET STUDENT: Baccalaureate final year (university entrance). Match depth to this level.',
      StudyLevel.bem => 'TARGET STUDENT: BEM middle-school certificate exam. Use simpler depth.',
      StudyLevel.secondary => 'TARGET STUDENT: Secondary school.',
      StudyLevel.middle => 'TARGET STUDENT: Middle school. Use the simplest depth.',
    };

const String _kRecallSchema = '''
"recall": {
  "quiz": [ { "question": string, "options": [4 strings], "answerIndex": 0-3, "explanation": string } ] (EXACTLY 3),
  "flashcards": [ { "front": string, "back": string } ] (EXACTLY 3)
}''';

String buildSystemPrompt(StudyModule m, AppLocale lang, StudyLevel level, {String? targetLanguage}) {
  final header = '''
You are "Scholar AI", a world-class pedagogy engine.
${_levelRule(level)}
${_langRule(lang)}
1. Teach for retention: active recall, concise, well-structured explanations.
2. Never hallucinate; state assumptions explicitly if the input is ambiguous.
3. Output MUST be a single valid JSON object. No markdown fences, no prose.
4. Use plain-text math (x^2, sqrt(x), a/b) unless LaTeX is clearly required.
5. Quiz questions test understanding and have exactly one correct option.
''';

  switch (m) {
    case StudyModule.text:
      return '''$header
ROLE: Literature & Text Preparation Specialist.
Return JSON: { "kind": "text", "title": string, "coreIdeas": [3-5 strings],
"subThemes": [{ "theme": string, "explanation": string }] (2-4),
"vocabulary": [{ "word": string, "definition": string, "contextSentence": string }] (4-6),
"takeaways": [2-4 strings], $_kRecallSchema }''';

    case StudyModule.solver:
      return '''$header
ROLE: Step-by-Step Pedagogy Tutor. STRICT PEDAGOGY MODE: never jump to the answer.
Return JSON: { "kind": "solver", "title": string, "problemRestatement": string,
"concepts": [2-4 strings],
"steps": [{ "title": string, "content": string, "why": string ("Why this formula/approach?") }] (3-7 progressive),
"finalAnswer": string, "commonMistakes": [2-3 strings], $_kRecallSchema }''';

    case StudyModule.summary:
      return '''$header
ROLE: Smart Lesson Summarizer & Project Outliner.
Return JSON: { "kind": "summary", "title": string, "bullets": [6-12 strings; sub-points prefixed "  - "],
"keyEquations": [{ "name": string, "formula": string, "meaning": string }] (0-6),
"slideOutline": [{ "slideTitle": string, "points": [2-4 strings] }] (5-8 slides), $_kRecallSchema }''';

    case StudyModule.grammar:
      final target = targetLanguage ?? (lang == AppLocale.ar ? 'English' : 'Arabic');
      return '''$header
ROLE: Linguistic & Grammar Assistant. Correct, explain rules, parse structure (إعراب for Arabic), and translate into "$target".
Return JSON: { "kind": "grammar", "title": string, "correctedText": string,
"issues": [{ "original": string, "fix": string, "rule": string }],
"sentenceAnalysis": [{ "part": string, "role": string, "note": string }] (4-10),
"translation": { "targetLanguage": string, "text": string, "notes": string }, $_kRecallSchema }''';

    case StudyModule.dialect:
      return '''$header
ROLE: Dialect Explainer (Algerian / Maghrebi Darija, simplified Levantine).
TASK: Re-explain the lesson in warm, everyday DARIJA. Keep the formal term in brackets after the dialect word so the student can still pass exams.
Return JSON: { "kind": "dialect", "title": string,
"dialectSummary": string (2-4 sentences in Darija),
"everydayExamples": [{ "example": string, "linkToConcept": string }] (3-5),
"examTermGlossary": [{ "dialectTerm": string, "formalTerm": string, "meaning": string }] (3-6),
"quickSteps": [2-5 strings in Darija], $_kRecallSchema }''';
  }
}

/* ═══════════════════════ 6. GEMINI SERVICE (dart:io) ════════════════════ */

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

class GeminiService {
  GeminiService({required this.apiKey, this.model = _kModel});
  final String apiKey;
  final String model;
  bool get hasKey => apiKey.trim().isNotEmpty;

  Future<Map<String, dynamic>> generate({
    required StudyModule module,
    required AppLocale lang,
    required String input,
    required StudyLevel level,
    String? targetLanguage,
  }) async {
    if (!hasKey) return _demoResult(module, lang, input);

    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
    final body = jsonEncode({
      'system_instruction': {'parts': [
          {'text': buildSystemPrompt(module, lang, level, targetLanguage: targetLanguage)}
        ]},
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'INPUT:\n"""\n${input.isEmpty ? '(none)' : input}\n"""\nRemember: return ONLY the JSON object.'}
          ]
        }
      ],
      'generationConfig': {'temperature': 0.4, 'topP': 0.95, 'maxOutputTokens': 8192, 'responseMimeType': 'application/json'},
    });

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      HttpClient? client;
      try {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 45);
        final req = await client.postUrl(uri);
        req.headers.contentType = ContentType.json;
        req.write(body);
        final res = await req.close();
        final text = await res.transform(utf8.decoder).join();
        if (res.statusCode >= 400) throw GeminiException('Gemini ${res.statusCode}: ${text.substring(0, text.length > 300 ? 300 : text.length)}');
        final decoded = jsonDecode(text);
        final parts = ((decoded['candidates'] as List?)?.firstOrNull as Map?)?['content']?['parts'] as List?;
        final raw = parts?.map((p) => p['text'] ?? '').join() ?? '';
        if (raw.trim().isEmpty) throw GeminiException('Empty response from Gemini.');
        return _normalise(_extractJson(raw), module);
      } catch (e) {
        lastError = e;
      } finally {
        client?.close();
      }
    }
    throw lastError is GeminiException ? lastError : GeminiException('Network failure: $lastError');
  }

  /// Robustly pull a JSON object out of model text (handles fences / prose).
  static Map<String, dynamic> _extractJson(String text) {
    final cleaned = text.replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '').trim();
    try {
      return Map<String, dynamic>.from(jsonDecode(cleaned) as Map);
    } catch (_) {
      final s = cleaned.indexOf('{');
      final e = cleaned.lastIndexOf('}');
      if (s == -1 || e == -1) throw GeminiException('Model returned non-JSON output.');
      return Map<String, dynamic>.from(jsonDecode(cleaned.substring(s, e + 1)) as Map);
    }
  }

  /// Guarantee required arrays exist so the UI never crashes on partial output.
  static Map<String, dynamic> _normalise(Map<String, dynamic> r, StudyModule m) {
    final recallRaw = r['recall'];
    final recall = recallRaw is Map ? Map<String, dynamic>.from(recallRaw) : <String, dynamic>{};
    recall['quiz'] = ((recall['quiz'] as List?) ?? []).take(3).toList();
    recall['flashcards'] = ((recall['flashcards'] as List?) ?? []).take(3).toList();
    r['recall'] = recall;
    r['title'] = (r['title'] ?? 'Study Result').toString();
    for (final k in ['coreIdeas', 'subThemes', 'vocabulary', 'takeaways', 'concepts', 'steps', 'commonMistakes', 'bullets', 'keyEquations', 'slideOutline', 'issues', 'sentenceAnalysis', 'everydayExamples', 'examTermGlossary', 'quickSteps']) {
      if (r[k] is! List) r[k] = <dynamic>[];
    }
    return r;
  }

  /* ── Demo fallback so the app is fully usable without a key ── */
  static Map<String, dynamic> _demoResult(StudyModule m, AppLocale lang, String input) {
    final ar = lang == AppLocale.ar;
    final snip = input.trim().length > 48 ? '${input.trim().substring(0, 48)}…' : (input.trim().isEmpty ? (ar ? 'المدخل' : 'your input') : input.trim());
    final recall = ar
        ? {
            'quiz': [
              {'question': 'ما الهدف من الاسترجاع النشط؟', 'options': ['الحفظ السلبي', 'تعزيز الذاكرة طويلة المدى', 'تقليل وقت الدراسة', 'قراءة الملاحظات مرتين'], 'answerIndex': 1, 'explanation': 'الاسترجاع يقوّي الروابط العصبية.'},
              {'question': 'ما بطاقة تعليمية جيدة؟', 'options': ['سؤال واحد محدد', 'فقرة طويلة', 'صورة بلا نص', 'قائمة بعشر نقاط'], 'answerIndex': 0, 'explanation': 'البطاقة الجيدة تحمل فكرة واحدة.'},
              {'question': 'متى تراجع البطاقات؟', 'options': ['مرة واحدة', 'بفواصل متباعدة', 'قبل الامتحان بدقائق', 'لا حاجة'], 'answerIndex': 1, 'explanation': 'التكرار المتباعد الأكثر فاعلية.'},
            ],
            'flashcards': [
              {'front': 'عرّف الاسترجاع النشط', 'back': 'استدعاء المعلومة دون النظر للمصدر.'},
              {'front': 'ما التكرار المتباعد؟', 'back': 'المراجعة على فترات متزايدة.'},
              {'front': 'لماذا الاختبارات القصيرة؟', 'back': 'لكشف الفجوات وتثبيت التعلم.'},
            ],
          }
        : {
            'quiz': [
              {'question': 'What is the purpose of active recall?', 'options': ['Passive memorisation', 'Strengthening long-term memory', 'Reducing study time', 'Reading twice'], 'answerIndex': 1, 'explanation': 'Retrieval rebuilds the memory trace.'},
              {'question': 'Which is a well-designed flashcard?', 'options': ['One prompt, one answer', 'A full paragraph', 'An image with no text', 'A ten-item list'], 'answerIndex': 0, 'explanation': 'Atomic cards are easier to remember.'},
              {'question': 'When should cards be reviewed?', 'options': ['Only once', 'At spaced intervals', 'Just before the exam', 'Never'], 'answerIndex': 1, 'explanation': 'Spaced repetition works best.'},
            ],
            'flashcards': [
              {'front': 'Define active recall', 'back': 'Retrieving information without the source.'},
              {'front': 'What is spaced repetition?', 'back': 'Reviewing at increasing intervals.'},
              {'front': 'Why micro-quizzes?', 'back': 'They expose gaps and consolidate learning.'},
            ],
          };

    switch (m) {
      case StudyModule.text:
        return {
          'kind': 'text', 'title': ar ? 'تحضير النص: $snip' : 'Text Prep: $snip',
          'coreIdeas': ar ? ['الصراع بين الواجب والرغبة', 'أثر البيئة في الشخصية', 'قيمة الصبر'] : ['Duty vs. personal desire', 'Environment shapes character', 'The value of patience'],
          'subThemes': ar
              ? [{'theme': 'الهوية', 'explanation': 'تتشكل عبر مواجهة التحديات.'}, {'theme': 'الزمن', 'explanation': 'رمز للتغير الحتمي.'}]
              : [{'theme': 'Identity', 'explanation': 'Forms through adversity.'}, {'theme': 'Time', 'explanation': 'A symbol of change.'}],
          'vocabulary': ar
              ? [{'word': 'المثابرة', 'definition': 'الاستمرار رغم الصعوبات', 'contextSentence': 'أظهر البطل مثابرة نادرة.'}, {'word': 'الرمز', 'definition': 'ما يدل على معنى أعمق', 'contextSentence': 'النهر رمز للزمن.'}]
              : [{'word': 'Perseverance', 'definition': 'Continued effort despite difficulty', 'contextSentence': 'Her perseverance carried her through.'}, {'word': 'Motif', 'definition': 'A recurring symbolic element', 'contextSentence': 'The river is a motif for time.'}],
          'takeaways': ar ? ['الصبر مفتاح النجاح', 'الاختيارات الصغيرة تصنع المصير'] : ['Patience is the key to growth', 'Small choices shape destiny'],
          'recall': recall,
        };
      case StudyModule.solver:
        return {
          'kind': 'solver', 'title': ar ? 'حل المسألة خطوة بخطوة' : 'Step-by-Step Solution',
          'problemRestatement': ar ? 'المطلوب: حل المعادلة 2x + 6 = 14. (وضع تجريبي)' : 'Solve: 2x + 6 = 14. (demo mode)',
          'concepts': ar ? ['المعادلات الخطية', 'خصائص المساواة'] : ['Linear equations', 'Properties of equality'],
          'steps': ar
              ? [
                  {'title': 'الخطوة 1 – المعطيات', 'content': 'نكتب المعادلة ونحدد المجهول x.', 'why': 'التنظيم يمنع الأخطاء.'},
                  {'title': 'الخطوة 2 – عزل المجهول', 'content': '2x + 6 − 6 = 14 − 6 ⟹ 2x = 8.', 'why': 'الطرح من الطرفين يحافظ على التوازن.'},
                  {'title': 'الخطوة 3 – القسمة', 'content': '2x ÷ 2 = 8 ÷ 2 ⟹ x = 4.', 'why': 'القسمة تعكس الضرب فتعزل x.'},
                  {'title': 'الخطوة 4 – التحقق', 'content': '2(4) + 6 = 14 ✓', 'why': 'التحقق يكشف الأخطاء الحسابية.'},
                ]
              : [
                  {'title': 'Step 1 – Identify knowns', 'content': 'Write the equation and name the unknown x.', 'why': 'Organising givens prevents errors.'},
                  {'title': 'Step 2 – Isolate the variable', 'content': '2x + 6 − 6 = 14 − 6 ⟹ 2x = 8.', 'why': 'Subtraction property keeps both sides balanced.'},
                  {'title': 'Step 3 – Divide', 'content': '2x ÷ 2 = 8 ÷ 2 ⟹ x = 4.', 'why': 'Division undoes multiplication.'},
                  {'title': 'Step 4 – Verify', 'content': '2(4) + 6 = 14 ✓', 'why': 'Checking catches arithmetic slips.'},
                ],
          'finalAnswer': 'x = 4',
          'commonMistakes': ar ? ['تطبيق العملية على طرف واحد', 'خطأ في الإشارة'] : ['Operating on one side only', 'Sign errors'],
          'recall': recall,
        };
      case StudyModule.summary:
        return {
          'kind': 'summary', 'title': ar ? 'ملخص الدرس: $snip' : 'Lesson Summary: $snip',
          'bullets': ar ? ['الفكرة الرئيسية', '  - التعريف', '  - الخصائص', 'التطبيقات', '  - مثال 1', 'الأخطاء الشائعة'] : ['Main concept', '  - Definition', '  - Properties', 'Applications', '  - Example 1', 'Pitfalls'],
          'keyEquations': [
            {'name': ar ? 'نيوتن الثاني' : "Newton's Second Law", 'formula': 'F = m · a', 'meaning': ar ? 'F القوة، m الكتلة، a التسارع' : 'F force, m mass, a acceleration'},
            {'name': ar ? 'الطاقة الحركية' : 'Kinetic Energy', 'formula': 'KE = ½ m v²', 'meaning': ar ? 'v السرعة' : 'v velocity'},
          ],
          'slideOutline': ar
              ? [{'slideTitle': 'العنوان', 'points': ['اسم الدرس']}, {'slideTitle': 'المقدمة', 'points': ['الأهمية', 'الأهداف']}, {'slideTitle': 'المفاهيم', 'points': ['تعريف', 'قانون']}, {'slideTitle': 'الخاتمة', 'points': ['ملخص']}]
              : [{'slideTitle': 'Title', 'points': ['Lesson name']}, {'slideTitle': 'Intro', 'points': ['Why it matters']}, {'slideTitle': 'Concepts', 'points': ['Definition', 'Formula']}, {'slideTitle': 'Conclusion', 'points': ['Recap']}],
          'recall': recall,
        };
      case StudyModule.grammar:
        return {
          'kind': 'grammar', 'title': ar ? 'التحليل اللغوي' : 'Grammar Analysis',
          'correctedText': input.trim().isEmpty ? (ar ? 'ذهب الطالبُ إلى المدرسةِ مبكراً.' : 'The student went to school early.') : input.trim(),
          'issues': ar
              ? [{'original': 'الى', 'fix': 'إلى', 'rule': 'همزة القطع واجبة.'}]
              : [{'original': 'goed', 'fix': 'went', 'rule': "'Go' is irregular; past tense is 'went'."}],
          'sentenceAnalysis': ar
              ? [{'part': 'ذهب', 'role': 'فعل ماضٍ', 'note': 'مبني على الفتح'}, {'part': 'الطالبُ', 'role': 'فاعل', 'note': 'مرفوع بالضمة'}, {'part': 'مبكراً', 'role': 'حال', 'note': 'منصوب'}]
              : [{'part': 'The student', 'role': 'Subject', 'note': 'Noun phrase'}, {'part': 'went', 'role': 'Verb', 'note': 'Past simple'}, {'part': 'early', 'role': 'Adverb', 'note': 'Time'}],
          'translation': ar
              ? {'targetLanguage': 'English', 'text': 'The student went to school early.', 'notes': '«مبكراً» → early.'}
              : {'targetLanguage': 'Arabic', 'text': 'ذهب الطالبُ إلى المدرسةِ مبكراً.', 'notes': 'Arabic uses VSO order.'},
          'recall': recall,
        };
      case StudyModule.dialect:
        return {
          'kind': 'dialect', 'title': ar ? 'الشرح بالدارجة: $snip' : 'In Darija: $snip',
          'dialectSummary': ar ? 'باش تفهم الدرس مليح: الشرح بالدارجة المبسّطة. (وضع تجريبي)' : 'B darija: the lesson in plain words. (demo mode)',
          'everydayExamples': ar
              ? [{'example': 'كيفاش نبيع و نشري', 'linkToConcept': 'تبادل القيم'}, {'example': 'الماكلة فالسوق', 'linkToConcept': 'الطلب والعرض'}]
              : [{'example': 'Chri w be3 f souq', 'linkToConcept': 'Exchange of value'}, {'example': 'Traj f 7out', 'linkToConcept': 'Scarcity raises price'}],
          'examTermGlossary': [
            {'dialectTerm': ar ? 'الحساب' : 'l-hsab', 'formalTerm': ar ? 'الحساب الرياضي' : 'Arithmetic', 'meaning': ar ? 'العمليات على الأعداد' : 'Operations on numbers'},
            {'dialectTerm': ar ? 'الميزان' : 'l-mizan', 'formalTerm': ar ? 'المعادلة' : 'Equation', 'meaning': ar ? 'تساوي طرفين' : 'Two equal sides'},
          ],
          'quickSteps': ar ? ['قرا السؤال مرتين', 'كتب المعطيات', 'طبّق القانون'] : ['Read the question twice', 'Write the givens', 'Apply the formula'],
          'recall': recall,
        };
    }
  }
}

/* ═══════════════════ 7. PURE-DART PDF TEXT EXTRACTOR ════════════════════ */
/// Replaces `syncfusion_flutter_pdf`. Handles uncompressed and FlateDecode
/// streams, then pulls Tj / TJ / ' / " literal strings from the content.
String extractPdfText(List<int> bytes) {
  final latin = String.fromCharCodes(bytes);
  final chunks = <String>[];
  final zlib = ZLibCodec();

  final streamRe = RegExp(r'stream\r?\n([\s\S]*?)endstream');
  for (final m in streamRe.allMatches(latin)) {
    final header = latin.substring(m.start - 400 < 0 ? 0 : m.start - 400, m.start);
    final isFlate = RegExp(r'/Filter\s*(?:\[[^\]]*FlateDecode[^\]]*\]|/FlateDecode)').hasMatch(header);
    var decoded = bytes.sublist(m.start + (latin.startsWith('stream\r\n', m.start) ? 8 : 7), m.start + 7 + m.group(1)!.length);
    if (isFlate) {
      try {
        decoded = zlib.decode(m.group(1)!.codeUnits);
      } catch (_) {
        continue;
      }
    }
    chunks.add(_pdfStrings(String.fromCharCodes(decoded)));
  }

  if (chunks.join('').trim().length < 20) chunks.add(_pdfStrings(latin));
  return chunks.join('\n').replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _pdfStrings(String content) {
  final out = <String>[];
  // NOTE: must stay a raw string with no quotes inside it — `\'` inside r'...'
  // would terminate the literal. We match Tj/TJ only; the ' and " variants
  // are rare line-break operators already covered by the TJ array pass below.
  final re = RegExp(r'\((?:\\.|[^\\)])*\)\s*(?:Tj|TJ)');
  for (final m in re.allMatches(content)) {
    out.add(_unescapePdf(m.group(0)!.substring(1, m.group(0)!.lastIndexOf(')'))));
  }
  final tjArr = RegExp(r'\[((?:[^\[\]]|\[[^\]]*\])*)\]\s*TJ');
  for (final m in tjArr.allMatches(content)) {
    final parts = RegExp(r'\((?:\\.|[^\\)])*\)').allMatches(m.group(1) ?? '').map((x) => _unescapePdf(x.group(0)!.substring(1, x.group(0)!.length - 1)));
    if (parts.isNotEmpty) out.add(parts.join());
  }
  return out.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _unescapePdf(String s) => s
    .replaceAll('\\n', '\n')
    .replaceAll('\\r', '\r')
    .replaceAll('\\t', '\t')
    .replaceAll(RegExp(r'\\([()\\])'), r'$1')
    .replaceAllMapped(RegExp(r'\\(\d{1,3})'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 8)));

/* ════════════════════ 8. FIREBASE FACADE (no-op stub) ═══════════════════ */
/// Replaces firebase_core / analytics / crashlytics / remote_config.
/// Every method is a safe no-op, so the app runs identically with or without
/// Firebase configured. Wire real calls in later if you add the packages.
class FirebaseService {
  FirebaseService._();
  static bool ready = false; // stays false until you integrate real Firebase

  static const kCameraLocked = 'is_camera_locked';
  static const kDialectLocked = 'is_dialect_locked';

  static Future<void> init() async {
    ready = false;
    debugPrint('[ScholarAI] Firebase not configured — running standalone.');
  }

  static Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    debugPrint('[analytics] $name ${params ?? ''}');
  }

  static Future<void> logAppOpen() async => logEvent('app_open');

  static Future<void> setUserProperty(String key, String value) async => logEvent('set_user_prop', {key: value});

  static Future<void> recordError(Object error, StackTrace stack, {String? reason}) async {
    debugPrint('[crashlytics] $reason :: $error');
  }

  /// Returns the Remote Config defaults (both features locked).
  static Future<Map<String, bool>> fetchFlags() async => {kCameraLocked: true, kDialectLocked: true};

  /// In-app review stub — after `threshold` value moments, prompt the student.
  static int _usage = 0;
  static Future<void> trackValueMoment({int threshold = 3}) async {
    _usage++;
    if (_usage < threshold) return;
    _usage = 0;
    debugPrint('[review] would show in_app_review request here.');
  }
}

/* ═════════════════════════ 9. STORAGE (in-memory) ═══════════════════════ */
/// Replaces Hive. Keeps everything in memory and mirrors to a JSON file so
/// lessons survive a restart when the filesystem is writable.
class CacheService extends ChangeNotifier {
  final Map<String, Map<String, dynamic>> _sessions = {};
  final Map<String, dynamic> _kv = {};
  File? _file;

  Future<void> init() async {
    try {
      final dir = Directory.systemTemp;
      _file = File('${dir.path}/scholar_ai_cache.json');
      if (_file!.existsSync()) {
        final data = jsonDecode(_file!.readAsStringSync());
        if (data is Map) {
          (data['sessions'] as Map?)?.forEach((k, v) => _sessions[k.toString()] = Map<String, dynamic>.from(v as Map));
          (data['kv'] as Map?)?.forEach((k, v) => _kv[k.toString()] = v);
        }
      }
    } catch (_) {
      _file = null; // read-only filesystem → in-memory only
    }
  }

  Future<void> _persist() async {
    final f = _file;
    if (f == null) return;
    try {
      f.writeAsStringSync(jsonEncode({'sessions': _sessions, 'kv': _kv}));
    } catch (_) {}
  }

  void saveSession(String id, Map<String, dynamic> json) {
    _sessions[id] = json;
    _persist();
    notifyListeners();
  }

  void patchSession(String id, String key, dynamic value) {
    final s = _sessions[id];
    if (s == null) return;
    s[key] = value;
    _persist();
    notifyListeners();
  }

  Map<String, dynamic>? session(String id) => _sessions[id];

  List<Map<String, dynamic>> allSessions({StudyModule? module}) {
    final list = _sessions.values.where((s) => module == null || s['module'] == module).toList()
      ..sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
    return list;
  }

  Future<void> clearSessions() async {
    _sessions.clear();
    _persist();
    notifyListeners();
  }

  T? read<T>(String key) => _kv[key] as T?;
  Future<void> write(String key, dynamic value) async {
    _kv[key] = value;
    _persist();
  }
}

/* ════════════════════════ 10. GAMIFICATION ══════════════════════════════ */

class BadgeInfo {
  const BadgeInfo(this.code, this.name, this.emoji, this.description);
  final String code, name, emoji, description;
}

const Map<String, BadgeInfo> kBadgeCatalog = {
  'first_session': BadgeInfo('first_session', 'First Spark', '✨', 'Completed your first study session.'),
  'text_scholar': BadgeInfo('text_scholar', 'Text Scholar', '📚', 'Prepared 5 texts for class.'),
  'math_ninja': BadgeInfo('math_ninja', 'Math Ninja', '🥷', 'Solved 5 problems step by step.'),
  'summary_sage': BadgeInfo('summary_sage', 'Summary Sage', '🧠', 'Summarised 5 lessons.'),
  'word_smith': BadgeInfo('word_smith', 'Wordsmith', '✒️', 'Completed 5 grammar analyses.'),
  'dialect_fluent': BadgeInfo('dialect_fluent', 'Darija Fluent', '🗣️', 'Explained 3 lessons in dialect.'),
  'streak_3': BadgeInfo('streak_3', 'On Fire', '🔥', '3-day study streak.'),
  'streak_7': BadgeInfo('streak_7', 'Week Warrior', '🗓️', '7-day study streak.'),
  'streak_30': BadgeInfo('streak_30', 'Iron Discipline', '🛡️', '30-day study streak.'),
  'level_5': BadgeInfo('level_5', 'Rising Star', '⭐', 'Reached level 5.'),
  'perfect_quiz': BadgeInfo('perfect_quiz', 'Sharp Mind', '🎯', 'Scored 3/3 on a micro-quiz.'),
};

class GamificationState {
  GamificationState({this.xp = 0, this.currentStreak = 0, this.longestStreak = 0, this.lastStudyDate, this.moduleCounts = const {}, this.badgeCodes = const [], this.justUnlocked = const []});

  final int xp, currentStreak, longestStreak;
  final DateTime? lastStudyDate;
  final Map<StudyModule, int> moduleCounts;
  final List<String> badgeCodes;
  final List<BadgeInfo> justUnlocked;

  int get level {
    var l = 1, rem = xp;
    while (rem >= 100 * l) {
      rem -= 100 * l;
      l++;
    }
    return l;
  }

  int get xpIntoLevel {
    var l = 1, rem = xp;
    while (rem >= 100 * l) {
      rem -= 100 * l;
      l++;
    }
    return rem;
  }

  int get xpForNextLevel => 100 * level;
  bool get studiedToday => lastStudyDate != null && _sameDay(lastStudyDate!, DateTime.now());
  int get liveStreak {
    if (lastStudyDate == null) return 0;
    final gap = DateTime.now().difference(DateTime(lastStudyDate!.year, lastStudyDate!.month, lastStudyDate!.day)).inDays;
    return gap <= 1 ? currentStreak : 0;
  }

  List<BadgeInfo> get badges => badgeCodes.map((c) => kBadgeCatalog[c]).whereType<BadgeInfo>().toList();

  GamificationState copyWith({int? xp, int? currentStreak, int? longestStreak, DateTime? lastStudyDate, Map<StudyModule, int>? moduleCounts, List<String>? badgeCodes, List<BadgeInfo>? justUnlocked}) => GamificationState(
        xp: xp ?? this.xp,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        lastStudyDate: lastStudyDate ?? this.lastStudyDate,
        moduleCounts: moduleCounts ?? this.moduleCounts,
        badgeCodes: badgeCodes ?? this.badgeCodes,
        justUnlocked: justUnlocked ?? const [],
      );
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class GamificationController extends ChangeNotifier {
  GamificationController(this._cache) {
    _restore();
  }
  final CacheService _cache;

  GamificationState _state = GamificationState();
  GamificationState get state => _state;
  int previousXp = 0;

  static const Map<StudyModule, int> xpPerModule = {
    StudyModule.text: 25,
    StudyModule.solver: 30,
    StudyModule.summary: 25,
    StudyModule.grammar: 20,
    StudyModule.dialect: 25,
  };

  void _restore() {
    final xp = _cache.read<int>('xp') ?? 0;
    final streak = _cache.read<int>('currentStreak') ?? 0;
    final longest = _cache.read<int>('longestStreak') ?? 0;
    final last = _cache.read<String>('lastStudyDate');
    final codes = (_cache.read<List>('badgeCodes') ?? []).map((e) => e.toString()).toList();
    final counts = <StudyModule, int>{};
    (_cache.read<Map>('moduleCounts') ?? {}).forEach((k, v) {
      for (final m in StudyModule.values) {
        if (m.name == k.toString()) counts[m] = v as int;
      }
    });
    _state = GamificationState(
      xp: xp,
      currentStreak: streak,
      longestStreak: longest,
      lastStudyDate: last == null ? null : DateTime.tryParse(last),
      moduleCounts: counts,
      badgeCodes: codes,
    );
  }

  void recordSession(StudyModule module) {
    final counts = Map<StudyModule, int>.from(_state.moduleCounts)..update(module, (v) => v + 1, ifAbsent: () => 1);
    _apply(xpDelta: xpPerModule[module] ?? 25, moduleCounts: counts);
  }

  void recordQuiz({required int correct, required int total}) {
    final perfect = total > 0 && correct == total;
    _apply(xpDelta: correct * 10 + (perfect ? 15 : 0), perfectQuiz: perfect);
  }

  void _apply({required int xpDelta, Map<StudyModule, int>? moduleCounts, bool perfectQuiz = false}) {
    final now = DateTime.now();
    var streak = _state.currentStreak;
    if (_state.lastStudyDate == null) {
      streak = 1;
    } else {
      final last = _state.lastStudyDate!;
      final gap = DateTime(now.year, now.month, now.day).difference(DateTime(last.year, last.month, last.day)).inDays;
      if (gap == 1) {
        streak += 1;
      } else if (gap > 1) {
        streak = 1;
      }
    }

    var next = _state.copyWith(
      xp: _state.xp + xpDelta,
      currentStreak: streak,
      longestStreak: streak > _state.longestStreak ? streak : _state.longestStreak,
      lastStudyDate: now,
      moduleCounts: moduleCounts,
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
      if (streak >= 3) 'streak_3',
      if (streak >= 7) 'streak_7',
      if (streak >= 30) 'streak_30',
      if (next.level >= 5) 'level_5',
      if (perfectQuiz) 'perfect_quiz',
    ];
    final unlocked = candidates.where((c) => !next.badgeCodes.contains(c)).map((c) => kBadgeCatalog[c]).whereType<BadgeInfo>().toList();
    next = next.copyWith(badgeCodes: [...next.badgeCodes, ...unlocked.map((b) => b.code)], justUnlocked: unlocked);

    previousXp = _state.xp;
    _state = next;
    _persist();
    notifyListeners();
  }

  void _persist() {
    _cache.write('xp', _state.xp);
    _cache.write('currentStreak', _state.currentStreak);
    _cache.write('longestStreak', _state.longestStreak);
    _cache.write('lastStudyDate', _state.lastStudyDate?.toIso8601String());
    _cache.write('badgeCodes', _state.badgeCodes);
    _cache.write('moduleCounts', _state.moduleCounts.map((k, v) => MapEntry(k.name, v)));
  }
}

/* ════════════════════ 11. VIRAL / SHARE CONTROLLER ══════════════════════ */
/// Replaces share_plus · screenshot · receive_sharing_intent.
class ViralController extends ChangeNotifier {
  ViralController(this._cache);
  final CacheService _cache;

  final GlobalKey storyKey = GlobalKey();

  bool cameraUnlocked = false;
  bool dialectUnlocked = false;
  String pdfStatus = '';
  String? importedText;
  StudyModule importedTarget = StudyModule.summary;

  Future<void> init() async {
    cameraUnlocked = _cache.read<bool>('cameraUnlocked') ?? false;
    dialectUnlocked = _cache.read<bool>('dialectUnlocked') ?? false;
    notifyListeners();
  }

  Future<void> unlockCamera() async {
    cameraUnlocked = true;
    await _cache.write('cameraUnlocked', true);
    notifyListeners();
  }

  Future<void> unlockDialect() async {
    dialectUnlocked = true;
    await _cache.write('dialectUnlocked', true);
    notifyListeners();
  }

  /// Real share sheet if the platform supports it, otherwise Clipboard.
  Future<bool> shareText(String message) async {
    HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: message));
    return true;
  }

  /// Captures the story card via RepaintBoundary and saves a PNG to disk.
  Future<String?> exportStoryPng() async {
    try {
      final ctx = storyKey.currentContext;
      if (ctx == null) return null;
      final boundary = ctx.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      final bytes = data.buffer.asUint8List();
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/scholar_story_${DateTime.now().millisecondsSinceEpoch}.png');
      file.writeAsBytesSync(bytes);
      HapticFeedback.mediumImpact();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Feed a shared file (PDF / TXT) straight into the AI pipeline.
  Future<String?> ingestSharedFile(String path) async {
    try {
      final f = File(path);
      if (!f.existsSync()) {
        pdfStatus = 'error';
        notifyListeners();
        return null;
      }
      final bytes = f.readAsBytesSync();
      if (path.toLowerCase().endsWith('.pdf')) return extractPdfText(bytes).isEmpty ? null : _deliver(extractPdfText(bytes));
      if (path.toLowerCase().endsWith('.txt')) return _deliver(utf8.decode(bytes, allowMalformed: true));
      return null;
    } catch (_) {
      pdfStatus = 'error';
      notifyListeners();
      return null;
    }
  }

  String _deliver(String text) {
    importedText = text;
    importedTarget = StudyModule.summary;
    pdfStatus = 'ok';
    notifyListeners();
    return text;
  }

  void consumeImport() {
    importedText = null;
    pdfStatus = '';
    notifyListeners();
  }
}

/* ══════════════════════ 12. CONNECTIVITY (dart:io) ══════════════════════ */

class ConnectivityController extends ChangeNotifier {
  bool _online = true;
  bool get isOnline => _online;
  Timer? _timer;

  ConnectivityController() {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
  }

  Future<void> _check() async {
    var online = false;
    try {
      final result = await InternetAddress.lookup('generativelanguage.googleapis.com').timeout(const Duration(seconds: 4));
      online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }
    if (online != _online) {
      _online = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _ConnectivityScope extends InheritedNotifier<ConnectivityController> {
  const _ConnectivityScope({required ConnectivityController controller, required super.child}) : super(notifier: controller);
}

class ConnectivityProvider extends StatefulWidget {
  const ConnectivityProvider({super.key, required this.child});
  final Widget child;
  static ConnectivityController of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_ConnectivityScope>()!.notifier!;
  @override
  State<ConnectivityProvider> createState() => _ConnectivityProviderState();
}

class _ConnectivityProviderState extends State<ConnectivityProvider> {
  final _c = ConnectivityController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ConnectivityScope(controller: _c, child: widget.child);
}

/* ═══════════════════════ 13. STUDY CONTROLLER ═══════════════════════════ */

enum StudyStatus { idle, loading, success, failure }

class StudyState {
  StudyState({this.status = StudyStatus.idle, this.currentId, this.error});
  final StudyStatus status;
  final String? currentId;
  final String? error;
  StudyState copyWith({StudyStatus? status, String? currentId, String? error, bool clearCurrent = false}) =>
      StudyState(status: status ?? this.status, currentId: clearCurrent ? null : (currentId ?? this.currentId), error: error);
}

class StudyController extends ChangeNotifier {
  @override
  void dispose() { super.dispose(); }

  StudyController({required this.module, required this.gemini, required this.cache, required this.gamification});
  final StudyModule module;
  final GeminiService gemini;
  final CacheService cache;
  final GamificationController gamification;

  StudyState _state = StudyState();
  StudyState get state => _state;

  List<Map<String, dynamic>> get history => cache.allSessions(module: module);
  Map<String, dynamic>? get current => _state.currentId == null ? null : cache.session(_state.currentId!);

  Future<void> generate({required String input, required AppLocale lang, required StudyLevel level, String? targetLanguage}) async {
    if (input.trim().isEmpty) return;
    _state = StudyState(status: StudyStatus.loading);
    notifyListeners();
    try {
      final result = await gemini.generate(module: module, lang: lang, input: input, level: level, targetLanguage: targetLanguage);
      final id = 's${DateTime.now().microsecondsSinceEpoch}';
      cache.saveSession(id, {'id': id, 'module': module.name, 'lang': lang.name, 'input': input, 'result': result, 'createdAt': DateTime.now().toIso8601String(), 'quizScore': null});
      gamification.recordSession(module);
      FirebaseService.logEvent('ai_generate', {'module': module.name});
      FirebaseService.trackValueMoment();
      _state = StudyState(status: StudyStatus.success, currentId: id);
    } catch (e) {
      _state = StudyState(status: StudyStatus.failure, error: e.toString());
    }
    notifyListeners();
  }

  Future<void> completeQuiz(String sessionId, int correct, int total) async {
    final s = cache.session(sessionId);
    if (s == null || s['quizScore'] != null) return;
    cache.patchSession(sessionId, 'quizScore', correct);
    gamification.recordQuiz(correct: correct, total: total);
    _state = StudyState(status: StudyStatus.success, currentId: sessionId);
    notifyListeners();
  }

  void open(String id) {
    _state = StudyState(status: StudyStatus.success, currentId: id);
    notifyListeners();
  }

  void close() {
    _state = StudyState();
    notifyListeners();
  }
}

/* ═════════════════════════ 14. SHARED WIDGETS ═══════════════════════════ */

class GradientGlowCard extends StatefulWidget {
  const GradientGlowCard({super.key, required this.colors, required this.child, this.onTap, this.padding = const EdgeInsets.all(18)});
  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  @override
  State<GradientGlowCard> createState() => _GradientGlowCardState();
}

class _GradientGlowCardState extends State<GradientGlowCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap == null ? null : () { HapticFeedback.lightImpact(); widget.onTap!(); },
        child: AnimatedScale(
          scale: _pressed ? 0.965 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(colors: widget.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: widget.child,
          ),
        ),
      );
}

class NeuSurface extends StatelessWidget {
  const NeuSurface({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.glowColor, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? glowColor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: glowColor?.withOpacity(0.35) ?? AppColors.border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(24), onTap: () { HapticFeedback.selectionClick(); onTap!(); }, child: box));
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF22D3EE)]))),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ]);
}

class GlowOrbs extends StatelessWidget {
  const GlowOrbs({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(children: [
          _orb(-80, -60, 260, const Color(0xFF6366F1)),
          _orb(520, -40, 200, const Color(0xFFF43F5E)),
          Positioned(bottom: 180, right: -100, child: _orbWidget(220, const Color(0xFF06B6D4))),
        ]),
      );
  Widget _orb(double? top, double? left, double size, Color c) => Positioned(top: top, left: left, child: _orbWidget(size, c));
  Widget _orbWidget(double size, Color c) => Transform.rotate(angle: math.pi / 6, child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withOpacity(0.2), c.withOpacity(0)]))));
}

/* ══════════════════════════ 15. HERO HEADER ═════════════════════════════ */

class HeroHeader extends StatefulWidget {
  const HeroHeader({super.key, required this.state});
  final GamificationState state;
  @override
  State<HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<HeroHeader> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final g = widget.state;
    final progress = (g.xpIntoLevel / g.xpForNextLevel).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(width: 64, height: 64, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: progress), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic, builder: (_, v, __) => CircularProgressIndicator(value: v, strokeWidth: 4, backgroundColor: Colors.white12, color: AppColors.primary))),
            Container(width: 50, height: 50, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF818CF8), Color(0xFFC084FC)])), child: const Center(child: Text('🎓', style: TextStyle(fontSize: 24)))),
            Positioned(bottom: -2, right: -2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.primary)), child: Text('${g.level}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary)))),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${l.t('days')}: ${g.liveStreak}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            Text('Lv.${g.level} ${l.t('scholar_rank')}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
            Text('${g.xpIntoLevel} / ${g.xpForNextLevel} ${l.t('xp')}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
          ])),
          AnimatedBuilder(animation: _pulse, builder: (_, __) {
            final s = 0.9 + 0.1 * _pulse.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]),
                boxShadow: [BoxShadow(color: AppColors.fire.withOpacity(0.3 + 0.35 * _pulse.value), blurRadius: 24 * s)],
              ),
              child: Column(children: [Transform.scale(scale: s, child: const Text('🔥', style: TextStyle(fontSize: 22))), Text('${g.liveStreak}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white))]),
            );
          }),
        ]),
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(999), child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: progress), duration: const Duration(milliseconds: 1100), builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 12, backgroundColor: Colors.white10, color: AppColors.primary))),
        const SizedBox(height: 8),
        Row(children: [
          Icon(g.studiedToday ? Icons.check_circle_rounded : Icons.bolt_rounded, size: 16, color: g.studiedToday ? AppColors.success : AppColors.fire),
          const SizedBox(width: 6),
          Text(g.studiedToday ? l.t('studied_today') : l.t('not_today'), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const Spacer(),
          Text('${l.t('best_streak')}: ${g.longestStreak}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      ]),
    );
  }
}

/* ═══════════════════ 16. ACTIVE RECALL (quiz + cards) ═══════════════════ */

class ActiveRecallWidget extends StatelessWidget {
  const ActiveRecallWidget({super.key, required this.recall, required this.savedScore, required this.onQuizComplete});
  final Map<String, dynamic> recall;
  final int? savedScore;
  final void Function(int correct, int total) onQuizComplete;

  List<Map<String, dynamic>> get _quiz => ((recall['quiz'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<Map<String, dynamic>> get _cards => ((recall['flashcards'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 16),
      Row(children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('ACTIVE RECALL', style: TextStyle(letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary))),
        const Expanded(child: Divider()),
      ]),
      const SizedBox(height: 12),
      if (_quiz.isNotEmpty) _MicroQuiz(quiz: _quiz, savedScore: savedScore, onComplete: onQuizComplete, title: l.t('quiz'), checkLabel: l.t('check'), scoreLabel: l.t('score')),
      const SizedBox(height: 12),
      if (_cards.isNotEmpty) _FlashcardDeck(cards: _cards, flipLabel: l.t('flip'), nextLabel: l.t('next'), prevLabel: l.t('prev')),
    ]);
  }
}

class _MicroQuiz extends StatefulWidget {
  const _MicroQuiz({required this.quiz, required this.savedScore, required this.onComplete, required this.title, required this.checkLabel, required this.scoreLabel});
  final List<Map<String, dynamic>> quiz;
  final int? savedScore;
  final void Function(int, int) onComplete;
  final String title, checkLabel, scoreLabel;
  @override
  State<_MicroQuiz> createState() => _MicroQuizState();
}

class _MicroQuizState extends State<_MicroQuiz> {
  late final List<int?> _answers = List.filled(widget.quiz.length, null);
  late bool _checked = widget.savedScore != null;

  int get _correct => [for (var i = 0; i < widget.quiz.length; i++) if (_answers[i] == widget.quiz[i]['answerIndex']) 1].length;

  @override
  Widget build(BuildContext context) {
    return NeuSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Text('🎯 ', style: TextStyle(fontSize: 18)),
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const Spacer(),
        if (_checked) Text('${widget.scoreLabel}: ${widget.savedScore ?? _correct}/${widget.quiz.length}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 8),
      for (var qi = 0; qi < widget.quiz.length; qi++) ...[
        Text('${qi + 1}. ${widget.quiz[qi]['question']}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (var oi = 0; oi < ((widget.quiz[qi]['options'] as List?) ?? []).length; oi++)
          _option(qi, oi),
        if (_checked) Padding(padding: const EdgeInsets.only(top: 4, bottom: 12), child: Text('💡 ${widget.quiz[qi]['explanation']}', style: const TextStyle(fontSize: 12, color: AppColors.muted))),
        const SizedBox(height: 8),
      ],
      if (!_checked)
        FilledButton(
          onPressed: _answers.contains(null) ? null : () {
            setState(() => _checked = true);
            _correct == widget.quiz.length ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
            widget.onComplete(_correct, widget.quiz.length);
          },
          child: Text(widget.checkLabel),
        ),
    ]));
  }

  Widget _option(int qi, int oi) {
    final options = (widget.quiz[qi]['options'] as List?) ?? [];
    final selected = _answers[qi] == oi;
    final isAnswer = widget.quiz[qi]['answerIndex'] == oi;
    Color border = AppColors.border;
    Color? bg;
    if (_checked && isAnswer) { border = AppColors.success; bg = AppColors.success.withOpacity(0.12); }
    else if (_checked && selected && !isAnswer) { border = AppColors.danger; bg = AppColors.danger.withOpacity(0.12); }
    else if (selected) { border = AppColors.primary; bg = AppColors.primary.withOpacity(0.12); }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(border: Border.all(color: border, width: selected || _checked ? 2 : 1), borderRadius: BorderRadius.circular(12), color: bg),
      child: ListTile(
        dense: true,
        onTap: _checked ? null : () { HapticFeedback.selectionClick(); setState(() => _answers[qi] = oi); },
        leading: CircleAvatar(radius: 12, backgroundColor: AppColors.surfaceHi, child: Text(String.fromCharCode(65 + oi), style: const TextStyle(fontSize: 11, color: Colors.white))),
        title: Text('${options[oi]}', style: const TextStyle(fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FlashcardDeck extends StatefulWidget {
  const _FlashcardDeck({required this.cards, required this.flipLabel, required this.nextLabel, required this.prevLabel});
  final List<Map<String, dynamic>> cards;
  final String flipLabel, nextLabel, prevLabel;
  @override
  State<_FlashcardDeck> createState() => _FlashcardDeckState();
}

class _FlashcardDeckState extends State<_FlashcardDeck> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  int _i = 0;

  void _flip() { HapticFeedback.lightImpact(); _ctrl.isCompleted ? _ctrl.reverse() : _ctrl.forward(); }
  void _go(int d) { HapticFeedback.selectionClick(); _ctrl.reset(); setState(() => _i = (_i + d + widget.cards.length) % widget.cards.length); }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => NeuSurface(child: Column(children: [
        Row(children: [
          const Text('🃏 ', style: TextStyle(fontSize: 18)),
          Text(widget.flipLabel.isEmpty ? '' : 'Flashcards', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const Spacer(),
          Text('${_i + 1} / ${widget.cards.length}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _flip,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final angle = _ctrl.value * math.pi;
              final back = angle > math.pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                child: back
                    ? Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateY(math.pi), child: _face('${widget.cards[_i]['back']}', 'BACK', const [Color(0xFF10B981), Color(0xFF0D9488)], widget.flipLabel))
                    : _face('${widget.cards[_i]['front']}', 'FRONT', const [Color(0xFF6366F1), Color(0xFF7C3AED)], widget.flipLabel),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: () => _go(-1), child: Text('← ${widget.prevLabel}')),
          TextButton(onPressed: () => _go(1), child: Text('${widget.nextLabel} →')),
        ]),
      ]));
}

Widget _face(String text, String label, List<Color> colors, String hint) => Container(
      height: 170,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2)),
        const Spacer(),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, height: 1.3)),
        const Spacer(),
        Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    );

/* ════════════════════ 17. STEP-BY-STEP PEDAGOGY ═════════════════════════ */

class StepByStepView extends StatefulWidget {
  const StepByStepView({super.key, required this.steps, required this.finalAnswer, required this.whyLabel, required this.revealLabel, required this.finalLabel});
  final List<Map<String, dynamic>> steps;
  final String finalAnswer, whyLabel, revealLabel, finalLabel;
  @override
  State<StepByStepView> createState() => _StepByStepViewState();
}

class _StepByStepViewState extends State<StepByStepView> {
  int _revealed = 1;
  final Map<int, bool> _open = {0: true};

  @override
  Widget build(BuildContext context) {
    final done = _revealed >= widget.steps.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < _revealed && i < widget.steps.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: AppColors.surfaceLo, borderRadius: BorderRadius.circular(14)),
          child: ExpansionTile(
            initiallyExpanded: _open[i] ?? false,
            leading: CircleAvatar(radius: 14, backgroundColor: AppColors.primary, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
            title: Text('${widget.steps[i]['title']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              Align(alignment: AlignmentDirectional.centerStart, child: SelectableText('${widget.steps[i]['content']}', style: const TextStyle(height: 1.5))),
              if ((widget.steps[i]['why'] ?? '').toString().isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Tooltip(
                    message: '${widget.steps[i]['why']}',
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Chip(avatar: const Text('❓'), label: Text(widget.whyLabel, style: const TextStyle(fontSize: 11)), backgroundColor: Colors.amber.withOpacity(0.15)),
                  ),
                ),
            ],
          ),
        ),
      if (!done)
        FilledButton.tonal(onPressed: () { HapticFeedback.lightImpact(); setState(() => _revealed++); }, child: Text('${widget.revealLabel} ${_revealed + 1}/${widget.steps.length} →'))
      else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), border: Border.all(color: AppColors.success, width: 2), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.finalLabel, style: const TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold, color: AppColors.success)),
            const SizedBox(height: 4),
            SelectableText(widget.finalAnswer, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          ]),
        ),
    ]);
  }
}

/* ═══════════════════════ 18. AI OUTPUT BOX ══════════════════════════════ */

class AISkeleton extends StatefulWidget {
  const AISkeleton({super.key, required this.accent, required this.label});
  final Color accent;
  final String label;
  @override
  State<AISkeleton> createState() => _AISkeletonState();
}

class _AISkeletonState extends State<AISkeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  Widget _bar(double w, double h) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          height: h, width: w, margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: LinearGradient(begin: Alignment(-1 + 3 * _c.value, 0), end: Alignment(3 * _c.value, 0), colors: [AppColors.surfaceHi, widget.accent.withOpacity(0.35), AppColors.surfaceHi])),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _bar(double.infinity, 92), _bar(220, 20), _bar(double.infinity, 14), _bar(double.infinity, 14), _bar(180, 14),
        const SizedBox(height: 8), _bar(double.infinity, 64), _bar(double.infinity, 64),
        Center(child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(widget.label, style: TextStyle(color: widget.accent, fontWeight: FontWeight.w700)))),
      ]);
}

/* ═════════════════════════ 19. STORY CARD ═══════════════════════════════ */

class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.result, required this.streak, required this.level, required this.xp, required this.appName, required this.kicker});
  final Map<String, dynamic> result;
  final int streak, level, xp;
  final String appName, kicker;

  List<String> _bullets() {
    final kind = result['kind'];
    switch (kind) {
      case 'summary':
        return ((result['bullets'] as List?) ?? []).map((e) => e.toString().trim().replaceFirst(RegExp(r'^-\s*'), '')).where((e) => e.isNotEmpty).toList();
      case 'text':
        return [...((result['coreIdeas'] as List?) ?? []).map((e) => e.toString()), ...((result['takeaways'] as List?) ?? []).map((e) => e.toString())];
      case 'solver':
        return ['${result['problemRestatement'] ?? ''}', '${result['finalAnswer'] ?? ''}'].where((e) => e.isNotEmpty).toList();
      case 'dialect':
        return ['${result['dialectSummary'] ?? ''}', ...((result['quickSteps'] as List?) ?? []).map((e) => e.toString())];
      default:
        return ['${result['correctedText'] ?? ''}'];
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 340,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF134E4A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFFC084FC)])), child: const Center(child: Text('🎓', style: TextStyle(fontSize: 17)))),
            const SizedBox(width: 8),
            Text(appName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
            const Spacer(),
            Text('🔥 $streak · Lv.$level', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
          const SizedBox(height: 16),
          Text(kicker, style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text('${result['title']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19, height: 1.2)),
          const SizedBox(height: 14),
          for (final b in _bullets().take(5))
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('⚡ ', style: TextStyle(fontSize: 12)),
              Expanded(child: Text(b, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35))),
            ])),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(999)), child: Text('$appName · $xp XP', style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
      );
}

/* ═══════════════════ 20. SHARE-TO-UNLOCK DIALOG ═════════════════════════ */

Future<bool> showShareToUnlockDialog(BuildContext context, ViralController viral, {String? title, String? body, String? analyticsEvent}) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      title: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)])), child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 22)),
        const SizedBox(width: 10),
        Expanded(child: Text(title ?? l.t('unlock_title'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
      ]),
      content: Text(body ?? l.t('unlock_body'), style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.45)),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.t('unlock_later'), style: const TextStyle(color: Colors.white38))),
        FilledButton.icon(
          icon: const Icon(Icons.share_rounded, size: 18),
          label: Text(l.t('unlock_share')),
          onPressed: () async {
            HapticFeedback.mediumImpact();
            await viral.shareText('${l.t('unlock_message')} $_kShareBaseUrl');
            FirebaseService.logEvent(analyticsEvent ?? 'unlocked_via_share');
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
        ),
      ],
    ),
  );
  return ok == true;
}

/* ═══════════════════════════ 21. ENTRYPOINT ═════════════════════════════ */

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final env = _loadEnvFile();
      final key = _kApiKey.trim().isNotEmpty ? _kApiKey : (env['GEMINI_API_KEY'] ?? '');
      final model = env['GEMINI_MODEL'] ?? _kModel;

      await FirebaseService.init();

      final cache = CacheService();
      await cache.init();

      final viral = ViralController(cache);
      await viral.init();

      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: AppColors.bg));

      await FirebaseService.logAppOpen();

      runApp(ScholarApp(cache: cache, viral: viral, gemini: GeminiService(apiKey: key, model: model)));
    },
    (error, stack) => FirebaseService.recordError(error, stack, reason: 'Uncaught zone error'),
  );
}

class _ViralScope extends InheritedNotifier<ViralController> {
  const _ViralScope({required ViralController controller, required super.child}) : super(notifier: controller);
}

class ScholarApp extends StatefulWidget {
  const ScholarApp({super.key, required this.cache, required this.viral, required this.gemini});
  final CacheService cache;
  final ViralController viral;
  final GeminiService gemini;
  @override
  State<ScholarApp> createState() => _ScholarAppState();
}

class _ScholarAppState extends State<ScholarApp> {
  late final LocaleController _locale;
  late final GamificationController _gamification;
  StudyLevel _level = StudyLevel.bac;

  @override
  void initState() {
    super.initState();
    _locale = LocaleController();
    final saved = widget.cache.read<String>('locale');
    for (final l in AppLocale.values) {
      if (l.name == saved) _locale.set(l);
    }
    final savedLevel = widget.cache.read<String>('level');
    for (final lv in StudyLevel.values) {
      if (lv.name == savedLevel) _level = lv;
    }
    _gamification = GamificationController(widget.cache);
  }

  void _setLocale(AppLocale l) {
    _locale.set(l);
    widget.cache.write('locale', l.name);
  }

  void _setLevel(StudyLevel lv) {
    setState(() => _level = lv);
    widget.cache.write('level', lv.name);
    FirebaseService.setUserProperty('study_level', lv.name);
  }

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: _locale,
      child: _ViralScope(
        controller: widget.viral,
        child: ConnectivityProvider(
          child: InheritedValue<GamificationController>(value: _gamification, child: Builder(builder: (context) {
            final gamification = InheritedValue.of<GamificationController>(context);
            return AnimatedBuilder(
              animation: _locale,
              builder: (context, _) => MaterialApp(
                title: 'Scholar AI',
                debugShowCheckedModeBanner: false,
                theme: buildTheme(),
                builder: (ctx, child) => Directionality(textDirection: _locale.locale.direction, child: child!),
                home: MainNavigationHolder(
                  gemini: widget.gemini,
                  cache: widget.cache,
                  viral: widget.viral,
                  gamification: gamification,
                  level: _level,
                  onSetLevel: _setLevel,
                  onSetLocale: _setLocale,
                ),
              ),
            );
          })),
        ),
      ),
    );
  }
}

/// Tiny typed InheritedWidget so controllers can be reached without BLoC.
class InheritedValue<T> extends InheritedWidget {
  const InheritedValue({super.key, required this.value, required super.child});
  final T value;
  static T of<T>(BuildContext c) => c.dependOnInheritedWidgetOfExactType<InheritedValue<T>>()!.value;
  @override
  bool updateShouldNotify(InheritedValue<T> old) => old.value != value;
}

ViralController viralOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_ViralScope>()!.notifier!;

/* ════════════════ 22. NAVIGATION HOLDER + 3 BOTTOM TABS ════════════════ */

class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key, required this.gemini, required this.cache, required this.viral, required this.gamification, required this.level, required this.onSetLevel, required this.onSetLocale});
  final GeminiService gemini;
  final CacheService cache;
  final ViralController viral;
  final GamificationController gamification;
  final StudyLevel level;
  final ValueChanged<StudyLevel> onSetLevel;
  final ValueChanged<AppLocale> onSetLocale;
  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  int _index = 0;
  StudyModule? _activeModule;
  final Map<StudyModule, StudyController> _controllers = {};

  StudyController _controllerFor(StudyModule m) => _controllers.putIfAbsent(
        m,
        () => StudyController(module: m, gemini: widget.gemini, cache: widget.cache, gamification: widget.gamification),
      );

  void _openModule(StudyModule m) {
    HapticFeedback.selectionClick();
    FirebaseService.logEvent('open_module', {'module': m.name});
    setState(() { _activeModule = m; _index = 0; });
  }

  void _openSession(Map<String, dynamic> s) {
    HapticFeedback.selectionClick();
    for (final m in StudyModule.values) {
      if (m.name == s['module']) {
        _controllerFor(m).open('${s['id']}');
        setState(() { _activeModule = m; _index = 0; });
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.viral.addListener(_onViral);
  }

  void _onViral() {
    if (widget.viral.importedText != null) setState(() => _activeModule = StudyModule.summary);
  }

  @override
  void dispose() {
    widget.viral.removeListener(_onViral);
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AnimatedBuilder(
      animation: widget.gamification,
      builder: (context, _) {
        final g = widget.gamification.state;
        return Scaffold(
          extendBody: true,
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFFC084FC)])), child: const Center(child: Text('🎓', style: TextStyle(fontSize: 20)))),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.t('app'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, height: 1)),
                Text(l.t('tagline'), style: const TextStyle(color: AppColors.muted, fontSize: 10)),
              ]),
            ]),
            actions: const [OfflineDot(), SizedBox(width: 6), LanguageToggle(), SizedBox(width: 12)],
          ),
          body: IndexedStack(index: _index, children: [
            HomeScreen(onOpenModule: _openModule, activeModule: _activeModule, controllerFor: _controllerFor, gamification: widget.gamification, viral: widget.viral, level: widget.level, onOpenSession: _openSession, geminiHasKey: widget.gemini.hasKey),
            HistoryScreen(onOpenSession: _openSession, cache: widget.cache),
            SettingsScreen(cache: widget.cache, viral: widget.viral, level: widget.level, onSetLevel: widget.onSetLevel, onSetLocale: widget.onSetLocale, gamification: widget.gamification),
          ]),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Container(
                decoration: BoxDecoration(color: AppColors.surfaceLo, border: Border.all(color: AppColors.border)),
                child: NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) { HapticFeedback.selectionClick(); FirebaseService.logEvent('nav_tab', {'index': i}); setState(() => _index = i); },
                  destinations: [
                    NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: l.t('home')),
                    NavigationDestination(icon: const Icon(Icons.history_rounded), label: l.t('history')),
                    NavigationDestination(icon: const Icon(Icons.settings_rounded), label: l.t('settings')),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ══════════════════════════ 23. HOME SCREEN ══════════════════════════════ */

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenModule, required this.activeModule, required this.controllerFor, required this.gamification, required this.viral, required this.level, required this.onOpenSession, required this.geminiHasKey});
  final void Function(StudyModule) onOpenModule;
  final StudyModule? activeModule;
  final StudyController Function(StudyModule) controllerFor;
  final GamificationController gamification;
  final ViralController viral;
  final StudyLevel level;
  final void Function(Map<String, dynamic>) onOpenSession;
  final bool geminiHasKey;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AnimatedBuilder(
      animation: Listenable.merge([gamification, viral]),
      builder: (context, _) {
        final g = gamification.state;
        final all = <Map<String, dynamic>>[];
        for (final m in StudyModule.values) {
          all.addAll(controllerFor(m).history);
        }
        all.sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));

        return Stack(children: [
          const GlowOrbs(),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              const OfflineBanner(),
              if (!geminiHasKey)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                  child: Text(l.t('demo_mode'), style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              HeroHeader(state: g),
              const SizedBox(height: 22),
              SectionTitle(l.t('quick_start')),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: StudyModule.values.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.98),
                itemBuilder: (_, i) {
                  final m = StudyModule.values[i];
                  return GradientGlowCard(
                    colors: AppColors.gradient(m),
                    onTap: () => onOpenModule(m),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)), child: Icon(AppColors.icon(m), color: Colors.white, size: 24)),
                        Text(AppColors.emoji(m), style: const TextStyle(fontSize: 22)),
                      ]),
                      const Spacer(),
                      Text(l.module(m), maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, height: 1.15)),
                      const SizedBox(height: 4),
                      Text(l.moduleDesc(m), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 8),
                      Text('${g.moduleCounts[m] ?? 0} ${l.t('sessions')}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 22),
              NeuSurface(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _stat('${g.moduleCounts.values.fold(0, (a, b) => a + b)}', l.t('sessions'), AppColors.primary),
                _stat('${g.longestStreak}', l.t('best_streak'), AppColors.fire),
                _stat('${g.xp}', l.t('total_xp'), AppColors.success),
              ])),
              const SizedBox(height: 22),
              SectionTitle(l.t('badges')),
              const SizedBox(height: 12),
              if (g.badges.isEmpty)
                NeuSurface(child: Text(l.t('no_badges'), style: const TextStyle(color: AppColors.muted, fontSize: 13)))
              else
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final b in g.badges)
                    Tooltip(message: b.description, child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.primary.withOpacity(0.4))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 30, height: 30, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)])), child: Center(child: Text(b.emoji, style: const TextStyle(fontSize: 15)))),
                        const SizedBox(width: 8),
                        Text(b.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      ]),
                    )),
                ]),
              const SizedBox(height: 22),
              ViralHub(viral: viral, all: all, streak: g.liveStreak, level: g.level, xp: g.xp, onOpenModule: onOpenModule, onOpenSession: onOpenSession),
              if (activeModule != null) ...[
                const SizedBox(height: 26),
                SectionTitle(l.module(activeModule!)),
                const SizedBox(height: 12),
                ModuleScreen(controller: controllerFor(activeModule!), level: level),
              ],
            ],
          ),
        ]);
      },
    );
  }

  Widget _stat(String value, String label, Color color) => Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ]);
}

/* ═══════════════════════ 24. VIRAL HUB ══════════════════════════════════ */

class ViralHub extends StatelessWidget {
  const ViralHub({super.key, required this.viral, required this.all, required this.streak, required this.level, required this.xp, required this.onOpenModule, required this.onOpenSession});
  final ViralController viral;
  final List<Map<String, dynamic>> all;
  final int streak, level, xp;
  final void Function(StudyModule) onOpenModule;
  final void Function(Map<String, dynamic>) onOpenSession;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final latest = all.isEmpty ? null : all.first;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle(l.t('viral')),
      const SizedBox(height: 12),
      _card(
        context,
        title: viral.cameraUnlocked ? l.t('camera_unlocked_title') : l.t('camera_locked_title'),
        subtitle: viral.cameraUnlocked ? l.t('camera_unlocked_sub') : l.t('camera_locked_sub'),
        icon: viral.cameraUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
        colors: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
        onTap: () async {
          if (viral.cameraUnlocked) { onOpenModule(StudyModule.solver); return; }
          final ok = await showShareToUnlockDialog(context, viral);
          if (ok) { await viral.unlockCamera(); onOpenModule(StudyModule.solver); }
        },
      ),
      const SizedBox(height: 12),
      _card(
        context,
        title: viral.dialectUnlocked ? l.t('dialect_unlocked_title') : l.t('dialect_locked_title'),
        subtitle: l.t('dialect_unlocked_sub'),
        icon: viral.dialectUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
        colors: const [Color(0xFF22C55E), Color(0xFFEAB308)],
        onTap: () async {
          if (viral.dialectUnlocked) { onOpenModule(StudyModule.dialect); return; }
          final ok = await showShareToUnlockDialog(context, viral);
          if (ok) { await viral.unlockDialect(); onOpenModule(StudyModule.dialect); }
        },
      ),
      const SizedBox(height: 12),
      _card(
        context,
        title: l.t('peer_title'),
        subtitle: l.t('peer_sub'),
        icon: Icons.sports_esports_rounded,
        colors: const [Color(0xFF10B981), Color(0xFF059669)],
        onTap: () {
          if (latest == null) { _snack(context, l.t('peer_need_quiz')); return; }
          final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().padRight(6, 'X').substring(0, 6);
          viral.shareText(l.t('peer_message').replaceAll('{title}', '${latest['result']['title']}').replaceAll('{link}', '$_kShareBaseUrl/quiz/$code'));
        },
      ),
      const SizedBox(height: 12),
      _card(
        context,
        title: l.t('pdf_title'),
        subtitle: l.t('pdf_sub'),
        icon: Icons.picture_as_pdf_rounded,
        colors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        onTap: () => _pdfSheet(context),
      ),
      if (viral.pdfStatus.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
          child: Text(viral.pdfStatus == 'ok' ? l.t('pdf_ok') : l.t('pdf_failed'), style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ],
      const SizedBox(height: 18),
      SectionTitle(l.t('story_title')),
      const SizedBox(height: 12),
      if (latest == null)
        NeuSurface(child: Text(l.t('story_empty'), style: const TextStyle(color: AppColors.muted, fontSize: 13)))
      else
        Column(children: [
          RepaintBoundary(
            key: viral.storyKey,
            child: StoryCard(result: Map<String, dynamic>.from(latest['result'] as Map), streak: streak, level: level, xp: xp, appName: l.t('app'), kicker: l.t('story_kicker')),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              final path = await viral.exportStoryPng();
              if (!context.mounted) return;
              _snack(context, path == null ? l.t('pdf_failed') : '${l.t('story_saved')}: $path');
              if (path != null) await viral.shareText(path);
            },
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(l.t('story_export')),
          ),
        ]),
    ]);
  }

  void _pdfSheet(BuildContext context) {
    final l = context.l10n;
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.t('pdf_title'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 6),
          Text(l.t('pdf_hint'), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, decoration: InputDecoration(hintText: '/storage/emulated/0/Download/lesson.pdf')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final text = await viral.ingestSharedFile(ctrl.text.trim());
              if (!context.mounted) return;
              Navigator.pop(context);
              if (text != null && text.isNotEmpty) {
                onOpenModule(StudyModule.summary);
                _snack(context, l.t('pdf_ok'));
              } else {
                _snack(context, l.t('pdf_none'));
              }
            },
            child: Text(l.t('generate')),
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  Widget _card(BuildContext context, {required String title, required String subtitle, required IconData icon, required List<Color> colors, required VoidCallback onTap}) => InkWell(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
          ]),
        ),
      );

  void _snack(BuildContext context, String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/* ═══════════════════════ 25. MODULE SCREEN ══════════════════════════════ */

class ModuleScreen extends StatefulWidget {
  const ModuleScreen({super.key, required this.controller, required this.level});
  final StudyController controller;
  final StudyLevel level;
  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final GlobalKey _recallKey = GlobalKey();
  String _target = 'English';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viral = viralOf(context);
    final m = widget.controller.module;
    if (viral.importedText != null && (m == StudyModule.summary || m == StudyModule.text)) {
      _ctrl.text = viral.importedText!;
      viral.consumeImport();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  void _scrollToQuiz() {
    final ctx = _recallKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = widget.controller.module;
    final colors = AppColors.gradient(m);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final s = widget.controller.state;
        final current = widget.controller.current;

        if (current != null) {
          final result = Map<String, dynamic>.from(current['result'] as Map);
          return Column(children: [
            Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: widget.controller.close, icon: const Icon(Icons.arrow_back_rounded), label: Text(l.t('back')))),
            _ResultView(
              session: current,
              result: result,
              controller: widget.controller,
              onTakeQuiz: _scrollToQuiz,
              recallKey: _recallKey,
            ),
          ]);
        }

        return Column(children: [
          GradientGlowCard(colors: colors, child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(15)), child: Icon(AppColors.icon(m), color: Colors.white, size: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.module(m), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(l.moduleDesc(m), style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
          ])),
          const SizedBox(height: 14),
          NeuSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _ctrl, minLines: 4, maxLines: 10, style: const TextStyle(height: 1.5), decoration: InputDecoration(hintText: l.t('ph_${m.name}'))),
            const SizedBox(height: 12),
            if (m == StudyModule.grammar)
              DropdownButtonFormField<String>(value: _target, decoration: InputDecoration(labelText: l.t('translate_to')), dropdownColor: AppColors.surfaceHi, items: [for (final x in ['English', 'French', 'Arabic', 'Spanish', 'German']) DropdownMenuItem(value: x, child: Text(x))], onChanged: (v) => setState(() => _target = v!)),
            if (m == StudyModule.solver && viralOf(context).cameraUnlocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  onPressed: () => _snack(l.t('camera_stub')),
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: Text(l.t('camera'), style: const TextStyle(fontSize: 13)),
                ),
              ),
            if (m == StudyModule.dialect && !viralOf(context).dialectUnlocked)
              FilledButton.tonal(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF22C55E).withOpacity(0.18), foregroundColor: const Color(0xFF4ADE80)),
                onPressed: () async {
                  final viral = viralOf(context);
                  final ok = await showShareToUnlockDialog(context, viral);
                  if (ok) await viral.unlockDialect();
                },
                child: Text(l.t('dialect_locked_title')),
              )
            else
              FilledButton(
                onPressed: s.status == StudyStatus.loading ? null : () { HapticFeedback.mediumImpact(); widget.controller.generate(input: _ctrl.text, lang: context.l10n.locale, level: widget.level, targetLanguage: m == StudyModule.grammar ? _target : null); },
                child: s.status == StudyStatus.loading ? Text(l.t('thinking')) : Text('✨ ${l.t('generate')}'),
              ),
          ])),
          if (s.status == StudyStatus.loading) Padding(padding: const EdgeInsets.only(top: 14), child: AISkeleton(accent: colors.first, label: l.t('thinking'))),
          if (s.error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(s.error!, style: const TextStyle(color: AppColors.danger, fontSize: 12))),
          if (widget.controller.history.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(alignment: AlignmentDirectional.centerStart, child: Text(l.t('library'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
            const SizedBox(height: 8),
            for (final h in widget.controller.history.take(6))
              Padding(padding: const EdgeInsets.only(bottom: 8), child: NeuSurface(
                padding: const EdgeInsets.all(12),
                onTap: () => widget.controller.open('${h['id']}'),
                child: Row(children: [
                  Container(width: 38, height: 38, decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(12)), child: Icon(AppColors.icon(m), color: Colors.white, size: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${h['result']['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                  if (h['quizScore'] != null) Text('${h['quizScore']}/3', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12)),
                ]),
              )),
          ],
        ]);
      },
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/* ══════════════════════ 26. RESULT VIEW ═════════════════════════════════ */

class _ResultView extends StatelessWidget {
  const _ResultView({required this.session, required this.result, required this.controller, required this.onTakeQuiz, required this.recallKey});
  final Map<String, dynamic> session;
  final Map<String, dynamic> result;
  final StudyController controller;
  final VoidCallback onTakeQuiz;
  final GlobalKey recallKey;

  List<Map<String, dynamic>> _maps(String k) => ((result[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<String> _strings(String k) => ((result[k] as List?) ?? []).map((e) => e.toString()).toList();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = controller.module;
    final accent = AppColors.accent(m);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GradientGlowCard(colors: AppColors.gradient(m), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${AppColors.emoji(m)} ${l.module(m)}', style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${result['title']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.15)),
      ])),
      const SizedBox(height: 10),
      Row(children: [
        _action(context, Icons.copy_rounded, l.t('copy'), () async { await Clipboard.setData(ClipboardData(text: _plainText(l))); _snack(context, l.t('copied')); }),
        const SizedBox(width: 8),
        _action(context, Icons.ios_share_rounded, l.t('share'), () => viralOf(context).shareText(_plainText(l))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton.icon(onPressed: onTakeQuiz, icon: const Icon(Icons.quiz_rounded, size: 18), label: Text(l.t('take_quiz'), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))),
      ]),
      const SizedBox(height: 14),
      ..._sections(context, l, accent),
      KeyedSubtree(
        key: recallKey,
        child: ActiveRecallWidget(
          recall: Map<String, dynamic>.from((result['recall'] as Map?) ?? {}),
          savedScore: session['quizScore'] as int?,
          onQuizComplete: (c, t) => controller.completeQuiz('${session['id']}', c, t),
        ),
      ),
    ]);
  }

  Widget _action(BuildContext context, IconData icon, String label, VoidCallback onTap) => Tooltip(
        message: label,
        child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), padding: EdgeInsets.zero), onPressed: onTap, child: Icon(icon, size: 20)),
      );

  List<Widget> _sections(BuildContext context, LocaleController l, Color accent) {
    Widget kv(String k, String v, {String? sub}) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surfaceLo, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: TextStyle(fontWeight: FontWeight.w800, color: accent, fontSize: 13)),
            const SizedBox(height: 3),
            SelectableText(v, style: const TextStyle(height: 1.4, fontSize: 13)),
            if (sub != null) Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontStyle: FontStyle.italic)),
          ]),
        );

    Widget bullets(List<String> xs) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final x in xs)
            Padding(padding: EdgeInsetsDirectional.only(bottom: 8, start: x.startsWith('  ') ? 18 : 0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(margin: const EdgeInsets.only(top: 7), width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
              const SizedBox(width: 10),
              Expanded(child: Text(x.trim().replaceFirst(RegExp(r'^-\s*'), ''), style: const TextStyle(height: 1.5, fontSize: 13))),
            ])),
        ]);

    switch (controller.module) {
      case StudyModule.text:
        return [
          _acc(l.t('core_ideas'), Icons.lightbulb_rounded, accent, bullets(_strings('coreIdeas'))),
          _acc(l.t('themes'), Icons.hub_rounded, accent, Column(children: [for (final x in _maps('subThemes')) kv('${x['theme']}', '${x['explanation']}')])),
          _acc(l.t('vocab'), Icons.spellcheck_rounded, accent, Column(children: [for (final x in _maps('vocabulary')) kv('${x['word']}', '${x['definition']}', sub: '“${x['contextSentence']}”')])),
          _acc(l.t('takeaways'), Icons.eco_rounded, accent, bullets(_strings('takeaways'))),
        ];
      case StudyModule.solver:
        return [
          _acc(l.t('problem'), Icons.push_pin_rounded, accent, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${result['problemRestatement']}', style: const TextStyle(height: 1.5, fontSize: 13)), const SizedBox(height: 8), Wrap(spacing: 6, children: [for (final c in _strings('concepts')) Chip(label: Text(c, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact))])),
          _acc(l.t('steps'), Icons.stairs_rounded, accent, StepByStepView(steps: _maps('steps'), finalAnswer: '${result['finalAnswer']}', whyLabel: l.t('why'), revealLabel: l.t('reveal'), finalLabel: l.t('final'))),
          _acc(l.t('mistakes'), Icons.warning_amber_rounded, accent, bullets(_strings('commonMistakes'))),
        ];
      case StudyModule.summary:
        return [
          _acc(l.t('notes'), Icons.notes_rounded, accent, bullets(_strings('bullets'))),
          _acc(l.t('equations'), Icons.functions_rounded, accent, Column(children: [for (final x in _maps('keyEquations')) kv('${x['name']}', '${x['formula']}', sub: '${x['meaning']}')])),
          _acc(l.t('slides'), Icons.slideshow_rounded, accent, Column(children: [for (var i = 0; i < _maps('slideOutline').length; i++) kv('${i + 1}. ${_maps('slideOutline')[i]['slideTitle']}', ((_maps('slideOutline')[i]['points'] as List?) ?? []).map((p) => '• $p').join('\n'))])),
        ];
      case StudyModule.grammar:
        final tr = Map<String, dynamic>.from((result['translation'] as Map?) ?? {});
        return [
          _acc(l.t('corrected'), Icons.check_circle_rounded, accent, Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: SelectableText('${result['correctedText']}', style: const TextStyle(height: 1.6, fontSize: 14)))),
          _acc(l.t('issues'), Icons.healing_rounded, accent, Column(children: [for (final x in _maps('issues')) kv('${x['original']} → ${x['fix']}', '${x['rule']}')])),
          _acc(l.t('analysis'), Icons.account_tree_rounded, accent, Column(children: [for (final x in _maps('sentenceAnalysis')) kv('${x['part']}', '${x['role']}', sub: '${x['note']}')])),
          _acc('${l.t('translation')} → ${tr['targetLanguage'] ?? ''}', Icons.public_rounded, accent, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SelectableText('${tr['text']}', style: const TextStyle(height: 1.6, fontSize: 14)), if ('${tr['notes']}'.isNotEmpty) Text('📝 ${tr['notes']}', style: const TextStyle(color: AppColors.muted, fontSize: 11))])),
        ];
      case StudyModule.dialect:
        return [
          _acc(l.t('dialect_summary'), Icons.record_voice_over_rounded, accent, Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: SelectableText('${result['dialectSummary']}', style: const TextStyle(height: 1.6, fontSize: 14)))),
          _acc(l.t('everyday_examples'), Icons.local_fire_department_rounded, accent, Column(children: [for (final x in _maps('everydayExamples')) kv('${x['example']}', '${x['linkToConcept']}')])),
          _acc(l.t('term_glossary'), Icons.swap_horiz_rounded, accent, Column(children: [for (final x in _maps('examTermGlossary')) kv('${x['dialectTerm']} → ${x['formalTerm']}', '${x['meaning']}')])),
          _acc(l.t('quick_steps'), Icons.checklist_rounded, accent, bullets(_strings('quickSteps'))),
        ];
    }
  }

  Widget _acc(String title, IconData icon, Color accent, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NeuSurface(padding: EdgeInsets.zero, glowColor: accent, child: Column(children: [
          ExpansionTile(
            initiallyExpanded: false,
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: accent.withOpacity(0.18), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accent, size: 20)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [Align(alignment: AlignmentDirectional.centerStart, child: child)],
          ),
        ])),
      );

  String _plainText(LocaleController l) {
    final b = StringBuffer('${result['title']}\n\n');
    void list(String h, List<String> xs) { if (xs.isNotEmpty) { b.writeln(h); for (final x in xs) b.writeln('• ${x.trim()}'); b.writeln(); } }
    switch (controller.module) {
      case StudyModule.text: list(l.t('core_ideas'), _strings('coreIdeas')); list(l.t('takeaways'), _strings('takeaways'));
      case StudyModule.solver: b.writeln(result['problemRestatement']); b.writeln(); for (final s in _maps('steps')) b.writeln('${s['title']}\n${s['content']}\n'); b.writeln('${l.t('final')}: ${result['finalAnswer']}');
      case StudyModule.summary: list(l.t('notes'), _strings('bullets'));
      case StudyModule.grammar: b.writeln(result['correctedText']); b.writeln(); b.writeln((result['translation'] as Map?)?['text']);
      case StudyModule.dialect: b.writeln(result['dialectSummary']); b.writeln(); list(l.t('quick_steps'), _strings('quickSteps'));
    }
    return b.toString();
  }

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

/* ═══════════════════════ 27. HISTORY SCREEN ═════════════════════════════ */

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.onOpenSession, required this.cache});
  final void Function(Map<String, dynamic>) onOpenSession;
  final CacheService cache;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AnimatedBuilder(
      animation: cache,
      builder: (context, _) {
        final all = cache.allSessions();
        if (all.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🗂️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(l.t('no_library'), style: const TextStyle(color: AppColors.muted)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          itemCount: all.length,
          itemBuilder: (context, i) {
            final s = all[i];
            StudyModule m = StudyModule.text;
            for (final v in StudyModule.values) {
              if (v.name == s['module']) m = v;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NeuSurface(
                padding: const EdgeInsets.all(14),
                onTap: () => onOpenSession(s),
                child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(gradient: LinearGradient(colors: AppColors.gradient(m)), borderRadius: BorderRadius.circular(14)), child: Icon(AppColors.icon(m), color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s['result']['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(('${s['createdAt']}').substring(0, s['createdAt'].toString().length > 16 ? 16 : s['createdAt'].toString().length), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  ])),
                  if (s['quizScore'] != null) Text('${s['quizScore']}/3', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800)),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

/* ═══════════════════════ 28. SETTINGS SCREEN ═════════════════════════════ */

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.cache, required this.viral, required this.level, required this.onSetLevel, required this.onSetLocale, required this.gamification});
  final CacheService cache;
  final ViralController viral;
  final StudyLevel level;
  final ValueChanged<StudyLevel> onSetLevel;
  final ValueChanged<AppLocale> onSetLocale;
  final GamificationController gamification;

  static const Map<StudyLevel, String> _levelLabels = {
    StudyLevel.bac: 'Baccalaureate (BAC)',
    StudyLevel.bem: 'BEM Exam',
    StudyLevel.secondary: 'Secondary School',
    StudyLevel.middle: 'Middle School',
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        SectionTitle(l.t('settings_profile')),
        const SizedBox(height: 12),
        NeuSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.t('level'), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButtonFormField<StudyLevel>(
            value: level,
            dropdownColor: AppColors.surfaceHi,
            items: [for (final e in _levelLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) { if (v != null) onSetLevel(v); },
          ),
        ])),
        const SizedBox(height: 16),
        NeuSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.t('language'), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButtonFormField<AppLocale>(
            value: context.l10n.locale,
            dropdownColor: AppColors.surfaceHi,
            items: [for (final loc in AppLocale.values) DropdownMenuItem(value: loc, child: Text('${loc.flag}  ${loc.label}'))],
            onChanged: (v) { if (v != null) onSetLocale(v); },
          ),
        ])),
        const SizedBox(height: 16),
        NeuSurface(child: Column(children: [
          SwitchListTile(value: viral.cameraUnlocked, activeColor: AppColors.primary, title: Text(l.t('camera_unlocked_title'), style: const TextStyle(fontSize: 13)), onChanged: (v) { if (v) viral.unlockCamera(); }),
          SwitchListTile(value: viral.dialectUnlocked, activeColor: AppColors.primary, title: Text(l.t('dialect_unlocked_title'), style: const TextStyle(fontSize: 13)), onChanged: (v) { if (v) viral.unlockDialect(); }),
        ])),
        const SizedBox(height: 16),
        NeuSurface(child: Column(children: [
          ListTile(dense: true, leading: const Icon(Icons.rate_review_rounded, color: AppColors.primary), title: Text(l.t('rate_app'), style: const TextStyle(fontSize: 14)), onTap: () => FirebaseService.trackValueMoment(threshold: 1)),
          ListTile(dense: true, leading: const Icon(Icons.share_rounded, color: AppColors.success), title: Text(l.t('share_app'), style: const TextStyle(fontSize: 14)), onTap: () => viral.shareText('${l.t('unlock_message')} $_kShareBaseUrl')),
          ListTile(dense: true, leading: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger), title: Text(l.t('clear_cache'), style: const TextStyle(fontSize: 14)), onTap: () => cache.clearSessions()),
        ])),
        const SizedBox(height: 16),
        NeuSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.t('about'), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Scholar AI v1.0.0\n${l.t('tagline')}\nFirebase: ${FirebaseService.ready ? 'connected' : 'standalone'}', style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6)),
        ])),
      ],
    );
  }
}

/* ═════════════════ 29. LANGUAGE TOGGLE + OFFLINE UI ═════════════════════ */

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); l.cycle(); },
      onLongPress: () => showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          for (final loc in AppLocale.values)
            ListTile(leading: Text(loc.flag, style: const TextStyle(fontSize: 22)), title: Text(loc.label), trailing: l.locale == loc ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null, onTap: () { l.set(loc); Navigator.pop(context); }),
          const SizedBox(height: 12),
        ])),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: AppColors.surfaceHi, border: Border.all(color: AppColors.primary.withOpacity(0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(l.locale.flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(l.locale.code, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 13)),
          const SizedBox(width: 2),
          const Icon(Icons.swap_horiz_rounded, size: 15, color: AppColors.primary),
        ]),
      ),
    );
  }
}

class OfflineDot extends StatelessWidget {
  const OfflineDot({super.key});
  @override
  Widget build(BuildContext context) {
    final online = ConnectivityProvider.of(context).isOnline;
    return Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? AppColors.success : AppColors.danger, boxShadow: [BoxShadow(color: (online ? AppColors.success : AppColors.danger).withOpacity(0.6), blurRadius: 8)]));
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.danger.withOpacity(0.4))),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(l.t('offline'), style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
