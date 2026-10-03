import 'package:flutter/material.dart';
import 'prompts.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Localization Controller (AR · FR · EN) with native RTL/LTR switching.
/// A single ChangeNotifier drives both the string dictionary and
/// `Directionality`, so one tap in the header flips the whole app.
/// ─────────────────────────────────────────────────────────────────────────
enum AppLocale { en, fr, ar }

extension AppLocaleX on AppLocale {
  bool get isRtl => this == AppLocale.ar;
  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;
  String get flag => switch (this) { AppLocale.en => '🇬🇧', AppLocale.fr => '🇫🇷', AppLocale.ar => '🇸🇦' };
  String get code => switch (this) { AppLocale.en => 'EN', AppLocale.fr => 'FR', AppLocale.ar => 'ع' };
  String get label => switch (this) { AppLocale.en => 'English', AppLocale.fr => 'Français', AppLocale.ar => 'العربية' };
  String get ttsTag => switch (this) { AppLocale.en => 'en-US', AppLocale.fr => 'fr-FR', AppLocale.ar => 'ar-SA' };
  /// Maps to the prompt language used by the Gemini service.
  AppLang get promptLang => switch (this) { AppLocale.ar => AppLang.ar, AppLocale.fr => AppLang.fr, AppLocale.en => AppLang.en };
}

class LocaleController extends ChangeNotifier {
  AppLocale _locale = AppLocale.en;
  AppLocale get locale => _locale;
  bool get isRtl => _locale.isRtl;

  void set(AppLocale l) { if (l != _locale) { _locale = l; notifyListeners(); } }
  void cycle() => set(AppLocale.values[(_locale.index + 1) % AppLocale.values.length]);

  /// Lookup with English fallback.
  String t(String key) => L10n.dict[_locale]?[key] ?? L10n.dict[AppLocale.en]![key] ?? key;
  String module(StudyModule m) => t('mod_${m.name}');
  String moduleDesc(StudyModule m) => t('desc_${m.name}');
}

/// Inherited access: `context.l10n.t('key')`
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({super.key, required LocaleController controller, required super.child}) : super(notifier: controller);
  static LocaleController of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
}

extension L10nContext on BuildContext {
  LocaleController get l10n => LocaleScope.of(this);
  String tr(String key) => l10n.t(key);
}

class L10n {
  L10n._();
  static const Map<AppLocale, Map<String, String>> dict = {
    AppLocale.en: {
      'app': 'Scholar AI', 'tagline': 'Study smarter. Remember longer.',
      'hello': 'Hello', 'student': 'Scholar', 'home': 'Home',
      'mod_text': 'Text Prep', 'mod_solver': 'Exercise Solver', 'mod_summary': 'Lesson Summarizer', 'mod_grammar': 'Grammar Assistant', 'mod_dialect': 'Dialect Explainer',
      'desc_text': 'Ideas, themes, vocabulary & takeaways', 'desc_solver': 'Step-by-step with camera OCR',
      'desc_summary': 'Bullets, equations & slide outline', 'desc_grammar': 'Correct, parse & translate', 'desc_dialect': 'Simple Darija explanations & real-life examples',
      'streak': 'Daily Streak', 'days': 'Days', 'level': 'Level', 'xp': 'XP', 'scholar_rank': 'Scholar',
      'studied_today': 'Studied today', 'not_today': 'Study now to keep your streak!',
      'quick_start': 'Quick Start', 'badges': 'Badges', 'no_badges': 'Complete a session to unlock your first badge.',
      'library': 'Offline Library', 'sessions': 'sessions', 'best_streak': 'Best streak', 'total_xp': 'Total XP',
      'generate': 'Generate', 'thinking': 'Thinking…', 'camera': 'Camera', 'gallery': 'Gallery',
      'translate_to': 'Translate to', 'example': 'Example', 'back': 'Back',
      'copy': 'Copy', 'share': 'Share', 'listen': 'Listen', 'take_quiz': 'Take Micro-Quiz', 'copied': 'Copied to clipboard',
      'quiz': 'Micro-Quiz', 'flashcards': 'Flashcards', 'check': 'Check answers', 'score': 'Score', 'flip': 'Tap to flip',
      'why': 'Why this formula?', 'reveal': 'Reveal step', 'final': 'Final answer', 'problem': 'Problem', 'steps': 'Step-by-step',
      'mistakes': 'Common mistakes', 'core_ideas': 'Core ideas', 'themes': 'Sub-themes', 'vocab': 'Vocabulary in context',
      'takeaways': 'Takeaways', 'notes': 'Structured notes', 'equations': 'Key equations', 'slides': 'Slide outline',
      'corrected': 'Corrected text', 'issues': 'Issues & rules', 'analysis': 'Sentence analysis', 'translation': 'Translation',
      'ph_text': 'Paste the story, poem or passage to prepare…', 'ph_solver': 'Type the exercise or attach a photo…',
      'ph_summary': 'Paste your long lesson notes here…', 'ph_grammar': 'Paste a sentence to correct, parse and translate…', 'ph_dialect': 'Paste the lesson you want explained in dialect…',
      'dialect_locked_title': 'Explain in Dialect & Examples 🔒', 'dialect_locked_sub': 'Share with a friend to unlock', 'dialect_unlocked_title': 'Explain in Dialect & Examples 🔓', 'dialect_unlocked_sub': 'Simple Darija + real-life examples',
      'dialect_summary': 'Dialect summary', 'everyday_examples': 'Everyday examples', 'term_glossary': 'Dialect ↔ exam terms', 'quick_steps': 'How to answer in the exam',
      'offline': 'Offline — showing cached content', 'error_generic': 'Something went wrong. Please try again.',
      'xp_gained': 'XP gained', 'badge_unlocked': 'Badge unlocked',
      'history': 'History', 'settings': 'Settings', 'settings_profile': 'Settings & Profile',
      'language': 'App Language', 'rate_app': 'Rate Scholar AI', 'share_app': 'Share with friends',
      'clear_cache': 'Clear offline cache', 'about': 'About', 'no_library': 'No saved lessons yet — they are stored offline automatically.',
      'viral': 'Viral features',
      'unlock_title': 'Unlock Premium Feature 🚀',
      'unlock_body': 'Share Scholar AI with a classmate or your study group to instantly unlock the step-by-step camera exercise solver.',
      'unlock_share': 'Share to Unlock', 'unlock_later': 'Later',
      'unlock_success': 'Camera solver unlocked! 📸',
      'unlock_message': '🔥 Found the best AI app for lesson prep and step-by-step homework solving! Try Scholar AI: https://scholar-ai.app',
      'camera_locked_title': 'Camera Exercise Solver 🔒',
      'camera_locked_sub': 'Share with a friend to unlock',
      'camera_unlocked_title': 'Camera Exercise Solver 🔓',
      'camera_unlocked_sub': 'Snap a photo to solve',
      'peer_title': 'Peer Quiz Challenge',
      'peer_sub': 'Create and share quiz links with friends',
      'peer_need_quiz': 'Generate a lesson first — then challenge a classmate.',
      'peer_message': '🎯 I challenge you to beat my score on "{title}"! Tap to play: {link}',
      'pdf_title': 'Import PDF / Notes',
      'pdf_sub': 'Share a file from WhatsApp, Telegram or Files',
      'pdf_hint': 'From WhatsApp or Telegram, tap Share → Scholar AI. PDFs are extracted automatically.',
      'pdf_ok': 'PDF extracted successfully! Ready for AI processing ✨',
      'pdf_failed': 'Failed to parse PDF file.',
      'story_title': "Today's Summary Card ⚡",
      'story_export': 'Export as Story',
      'story_caption': "Check out today's lesson summary! ⚡ — Scholar AI",
      'story_kicker': "TODAY'S SUMMARY",
      'story_empty': 'Generate a lesson summary first, then export it as a branded story card.',
    },
    AppLocale.fr: {
      'app': 'Scholar AI', 'tagline': 'Étudie mieux. Retiens plus longtemps.',
      'hello': 'Bonjour', 'student': 'Érudit', 'home': 'Accueil',
      'mod_text': 'Préparation de textes', 'mod_solver': "Résolution d'exercices", 'mod_summary': 'Résumé de leçons', 'mod_grammar': 'Assistant Linguistique', 'mod_dialect': 'Expliqueur en dialecte',
      'desc_text': 'Idées, thèmes, vocabulaire & morale', 'desc_solver': 'Étape par étape avec OCR caméra',
      'desc_summary': 'Points clés, équations & plan de diapositives', 'desc_grammar': 'Corriger, analyser & traduire', 'desc_dialect': 'Explications en darija et exemples du quotidien',
      'streak': 'Série quotidienne', 'days': 'Jours', 'level': 'Niveau', 'xp': 'XP', 'scholar_rank': 'Érudit',
      'studied_today': "Étudié aujourd'hui", 'not_today': 'Étudie maintenant pour garder ta série !',
      'quick_start': 'Démarrage rapide', 'badges': 'Badges', 'no_badges': 'Termine une session pour débloquer ton premier badge.',
      'library': 'Bibliothèque hors ligne', 'sessions': 'sessions', 'best_streak': 'Meilleure série', 'total_xp': 'XP total',
      'generate': 'Générer', 'thinking': 'Réflexion…', 'camera': 'Caméra', 'gallery': 'Galerie',
      'translate_to': 'Traduire en', 'example': 'Exemple', 'back': 'Retour',
      'copy': 'Copier', 'share': 'Partager', 'listen': 'Écouter', 'take_quiz': 'Faire le micro-quiz', 'copied': 'Copié dans le presse-papiers',
      'quiz': 'Micro-quiz', 'flashcards': 'Cartes mémoire', 'check': 'Vérifier', 'score': 'Score', 'flip': 'Touchez pour retourner',
      'why': 'Pourquoi cette formule ?', 'reveal': "Révéler l'étape", 'final': 'Réponse finale', 'problem': 'Problème', 'steps': 'Étape par étape',
      'mistakes': 'Erreurs fréquentes', 'core_ideas': 'Idées principales', 'themes': 'Sous-thèmes', 'vocab': 'Vocabulaire en contexte',
      'takeaways': 'Leçons à retenir', 'notes': 'Notes structurées', 'equations': 'Équations clés', 'slides': 'Plan des diapositives',
      'corrected': 'Texte corrigé', 'issues': 'Erreurs & règles', 'analysis': 'Analyse de la phrase', 'translation': 'Traduction',
      'ph_text': 'Collez le texte, le poème ou le passage à préparer…', 'ph_solver': "Saisissez l'exercice ou joignez une photo…",
      'ph_summary': 'Collez vos longues notes de cours ici…', 'ph_grammar': 'Collez une phrase à corriger, analyser et traduire…', 'ph_dialect': 'Collez la leçon à expliquer en dialecte…',
      'dialect_locked_title': 'Expliquer en dialecte 🔒', 'dialect_locked_sub': 'Partage avec un ami pour débloquer', 'dialect_unlocked_title': 'Expliquer en dialecte 🔓', 'dialect_unlocked_sub': 'Darija simple + exemples réels',
      'dialect_summary': 'Résumé en dialecte', 'everyday_examples': 'Exemples du quotidien', 'term_glossary': 'Dialecte ↔ termes d\'examen', 'quick_steps': 'Comment répondre à l\'examen',
      'offline': 'Hors ligne — contenu en cache', 'error_generic': 'Une erreur est survenue. Réessayez.',
      'xp_gained': 'XP gagnés', 'badge_unlocked': 'Badge débloqué',
      'history': 'Historique', 'settings': 'Réglages', 'settings_profile': 'Réglages & Profil',
      'language': 'Langue', 'rate_app': 'Notier Scholar AI', 'share_app': 'Partager avec des amis',
      'clear_cache': 'Vider le cache', 'about': 'À propos', 'no_library': 'Aucune leçon enregistrée — elles sont stockées hors ligne automatiquement.',
      'viral': 'Fonctions virales',
      'unlock_title': 'Débloquer la fonction premium 🚀',
      'unlock_body': "Partage Scholar AI avec un camarade ou ton groupe d'étude pour débloquer instantanément le solveur d'exercices par caméra.",
      'unlock_share': 'Partager pour débloquer', 'unlock_later': 'Plus tard',
      'unlock_success': 'Solveur caméra débloqué ! 📸',
      'unlock_message': "🔥 La meilleure appli IA pour préparer les cours et résoudre les devoirs étape par étape ! Scholar AI : https://scholar-ai.app",
      'camera_locked_title': "Solveur d'exercices caméra 🔒",
      'camera_locked_sub': 'Partage avec un ami pour débloquer',
      'camera_unlocked_title': "Solveur d'exercices caméra 🔓",
      'camera_unlocked_sub': 'Prends une photo pour résoudre',
      'peer_title': 'Défi quiz entre camarades',
      'peer_sub': 'Crée et partage des liens de quiz',
      'peer_need_quiz': "Génère d'abord une leçon, puis défie un camarade.",
      'peer_message': '🎯 Je te défie de battre mon score sur « {title} » ! Joue ici : {link}',
      'pdf_title': 'Importer un PDF / notes',
      'pdf_sub': 'Partage un fichier depuis WhatsApp, Telegram ou Fichiers',
      'pdf_hint': "Depuis WhatsApp ou Telegram, appuie sur Partager → Scholar AI. Les PDF sont extraits automatiquement.",
      'pdf_ok': 'PDF extrait avec succès ! Prêt pour l\'IA ✨',
      'pdf_failed': "Impossible d'analyser le PDF.",
      'story_title': 'Carte résumé du jour ⚡',
      'story_export': 'Exporter en Story',
      'story_caption': "Voici le résumé du jour ! ⚡ — Scholar AI",
      'story_kicker': 'RÉSUMÉ DU JOUR',
      'story_empty': "Génère d'abord un résumé de leçon, puis exporte-le en carte story.",
    },
    AppLocale.ar: {
      'app': 'سكولار AI', 'tagline': 'ادرس بذكاء. تذكّر لفترة أطول.',
      'hello': 'مرحباً', 'student': 'الطالب', 'home': 'الرئيسية',
      'mod_text': 'تحضير النصوص', 'mod_solver': 'حل التمارين', 'mod_summary': 'تلخيص الدروس', 'mod_grammar': 'المساعد اللغوي', 'mod_dialect': 'الشرح بالدارجة',
      'desc_text': 'الأفكار والمحاور والمفردات والعِبر', 'desc_solver': 'حل تدريجي مع تصوير التمرين',
      'desc_summary': 'نقاط ومعادلات ومخطط شرائح', 'desc_grammar': 'تصحيح وإعراب وترجمة', 'desc_dialect': 'شرح مبسّط بالدارجة وأمثلة من الواقع',
      'streak': 'السلسلة اليومية', 'days': 'أيام', 'level': 'المستوى', 'xp': 'نقطة', 'scholar_rank': 'باحث',
      'studied_today': 'درستَ اليوم', 'not_today': 'ادرس الآن للحفاظ على سلسلتك!',
      'quick_start': 'ابدأ بسرعة', 'badges': 'الأوسمة', 'no_badges': 'أكمل جلسة لفتح أول وسام.',
      'library': 'المكتبة دون اتصال', 'sessions': 'جلسات', 'best_streak': 'أفضل سلسلة', 'total_xp': 'إجمالي النقاط',
      'generate': 'توليد', 'thinking': 'جارٍ التفكير…', 'camera': 'الكاميرا', 'gallery': 'المعرض',
      'translate_to': 'ترجم إلى', 'example': 'مثال', 'back': 'رجوع',
      'copy': 'نسخ', 'share': 'مشاركة', 'listen': 'استماع', 'take_quiz': 'ابدأ الاختبار القصير', 'copied': 'تم النسخ',
      'quiz': 'اختبار قصير', 'flashcards': 'بطاقات المراجعة', 'check': 'تحقق من الإجابات', 'score': 'النتيجة', 'flip': 'اضغط للقلب',
      'why': 'لماذا هذا القانون؟', 'reveal': 'أظهر الخطوة', 'final': 'الإجابة النهائية', 'problem': 'المسألة', 'steps': 'خطوة بخطوة',
      'mistakes': 'أخطاء شائعة', 'core_ideas': 'الأفكار الرئيسية', 'themes': 'المحاور الفرعية', 'vocab': 'المفردات في سياقها',
      'takeaways': 'العِبر', 'notes': 'ملاحظات منظمة', 'equations': 'المعادلات الأساسية', 'slides': 'مخطط الشرائح',
      'corrected': 'النص المصحح', 'issues': 'الأخطاء والقواعد', 'analysis': 'الإعراب', 'translation': 'الترجمة',
      'ph_text': 'الصق القصة أو القصيدة أو النص المراد تحضيره…', 'ph_solver': 'اكتب التمرين أو أرفق صورة…',
      'ph_summary': 'الصق ملاحظات الدرس الطويلة هنا…', 'ph_grammar': 'الصق جملة لتصحيحها وإعرابها وترجمتها…', 'ph_dialect': 'الصق الدرس لشرحه بالدارجة…',
      'dialect_locked_title': 'الشرح بالدارجة 🔒', 'dialect_locked_sub': 'شارك مع صديق لفتح الميزة', 'dialect_unlocked_title': 'الشرح بالدارجة 🔓', 'dialect_unlocked_sub': 'دارجة مبسّطة وأمثلة واقعية',
      'dialect_summary': 'الملخص بالدارجة', 'everyday_examples': 'أمثلة من الواقع', 'term_glossary': 'الدارجة ↔ مصطلحات الامتحان', 'quick_steps': 'كيف تجيب في الامتحان',
      'offline': 'غير متصل — يُعرض المحتوى المخزّن', 'error_generic': 'حدث خطأ ما. حاول مجدداً.',
      'xp_gained': 'نقاط مكتسبة', 'badge_unlocked': 'وسام جديد',
      'history': 'السجل', 'settings': 'الإعدادات', 'settings_profile': 'الإعدادات والملف',
      'language': 'لغة التطبيق', 'rate_app': 'قيّم سكولار AI', 'share_app': 'شارك مع الأصدقاء',
      'clear_cache': 'مسح الذاكرة المؤقتة', 'about': 'حول', 'no_library': 'لا توجد دروس محفوظة — تُخزَّن تلقائياً دون اتصال.',
      'viral': 'ميزات الانتشار',
      'unlock_title': 'افتح الميزة المميزة 🚀',
      'unlock_body': 'شارك سكولار AI مع زميل أو مجموعة دراسية لفتح حل التمارين بالكاميرا فوراً.',
      'unlock_share': 'شارك للفتح', 'unlock_later': 'لاحقاً',
      'unlock_success': 'تم فتح حلّال الكاميرا! 📸',
      'unlock_message': '🔥 أفضل تطبيق ذكاء اصطناعي لتحضير الدروس وحل الواجبات خطوة بخطوة! سكولار AI: https://scholar-ai.app',
      'camera_locked_title': 'حل التمارين بالكاميرا 🔒',
      'camera_locked_sub': 'شارك مع صديق لفتح الميزة',
      'camera_unlocked_title': 'حل التمارين بالكاميرا 🔓',
      'camera_unlocked_sub': 'التقط صورة للحل',
      'peer_title': 'تحدّي الاختبار مع الزملاء',
      'peer_sub': 'أنشئ روابط اختبار وشاركها مع أصدقائك',
      'peer_need_quiz': 'ولّد درساً أولاً ثم تحدَّ زميلاً.',
      'peer_message': '🎯 أتحداك أن تتجاوز نتيجتي في "{title}"! ابدأ من هنا: {link}',
      'pdf_title': 'استيراد PDF / ملاحظات',
      'pdf_sub': 'شارك ملفاً من واتساب أو تيليغرام أو الملفات',
      'pdf_hint': 'من واتساب أو تيليغرام اختر مشاركة → سكولار AI. تُستخرج ملفات PDF تلقائياً.',
      'pdf_ok': 'تم استخراج الـ PDF بنجاح! جاهز للمعالجة ✨',
      'pdf_failed': 'تعذّر تحليل ملف PDF.',
      'story_title': 'بطاقة ملخص اليوم ⚡',
      'story_export': 'تصدير كقصة',
      'story_caption': 'إليك ملخص درس اليوم! ⚡ — سكولار AI',
      'story_kicker': 'ملخص اليوم',
      'story_empty': 'ولّد ملخص درس أولاً ثم صدّره كبطاقة قصة.',
    },
  };
}
