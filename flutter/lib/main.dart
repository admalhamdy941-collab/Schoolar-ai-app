import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'bloc/gamification_cubit.dart';
import 'bloc/study_cubit.dart';
import 'core/l10n.dart';
import 'core/prompts.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'screens/module_screen.dart';
import 'services/cache_service.dart';
import 'services/firebase_service.dart';
import 'services/gemini_service.dart';
import 'services/prefs_service.dart';
import 'services/viral_controller.dart';
import 'widgets/gradient_card.dart';
import 'widgets/hero_header.dart';
import 'widgets/viral_hub.dart';

/// ═════════════════════════════════════════════════════════════════════════
/// SCHOLAR AI — unified production entrypoint.
///
/// Boot order matters:
///  1. `.env`          → secure key management (real keys never committed)
///  2. Hive            → offline cache + history + preferences
///  3. Firebase        → Remote Config · Analytics · Crashlytics (optional)
///  4. Viral loops     → share-intent listener for PDFs from WhatsApp/Telegram
///  5. runZonedGuarded → nothing crashes silently
/// ═════════════════════════════════════════════════════════════════════════
Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 1 ─ Secure .env key management.
      await dotenv.load(fileName: '.env');
      final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

      // 2 ─ Hive caching, offline history and preferences.
      final cache = CacheService();
      await cache.init();
      final prefs = PrefsService(await Hive.openBox('prefs_box'));

      // 3 ─ Firebase (Remote Config · Analytics · Crashlytics).
      await FirebaseService.init();

      // 4 ─ Viral loops + incoming share intents.
      final viral = ViralController(cache);
      await viral.init();

      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.bg,
      ));

      // Remote Config defaults, overridden by a local share-to-unlock win.
      final flags = await FirebaseService.fetchFlags();
      if (flags[FirebaseService.kCameraLocked] == false) await viral.unlockCamera();
      if (flags[FirebaseService.kDialectLocked] == false) await viral.unlockDialect();

      await FirebaseService.logAppOpen();
      await FirebaseService.setUserProperty('study_level', prefs.level);

      runApp(UltimateStudentApp(
        cache: cache,
        prefs: prefs,
        viral: viral,
        gemini: GeminiService(apiKey: geminiKey),
      ));
    },
    (error, stack) => FirebaseService.recordError(error, stack, reason: 'Uncaught zone error'),
  );
}

/// ═════════════════════════════════════════════════════════════════════════
/// Root widget — owns the LocaleController so a single tap re-flips RTL/LTR
/// for the whole tree (Arabic · French · English).
/// ═════════════════════════════════════════════════════════════════════════
class UltimateStudentApp extends StatefulWidget {
  const UltimateStudentApp({super.key, required this.cache, required this.prefs, required this.viral, required this.gemini});

  final CacheService cache;
  final PrefsService prefs;
  final ViralController viral;
  final GeminiService gemini;

  @override
  State<UltimateStudentApp> createState() => _UltimateStudentAppState();
}

class _UltimateStudentAppState extends State<UltimateStudentApp> {
  late final LocaleController _locale;

  @override
  void initState() {
    super.initState();
    _locale = LocaleController()
      ..set(AppLocale.values.firstWhere((l) => l.name == widget.prefs.locale, orElse: () => AppLocale.en));
  }

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: _locale,
      child: ViralScope(
        controller: widget.viral,
        child: RepositoryProvider.value(
          value: widget.cache,
          child: RepositoryProvider<StudyLevel>.value(
          value: StudyLevelX.fromKey(widget.prefs.level),
          child: BlocProvider(
            create: (_) => GamificationCubit(widget.cache),
            child: AnimatedBuilder(
              animation: _locale,
              builder: (context, _) => MaterialApp(
                title: 'Scholar AI',
                debugShowCheckedModeBanner: false,
                theme: buildTheme(_locale.isRtl),
                builder: (ctx, child) => Directionality(textDirection: _locale.locale.direction, child: child!),
                home: MainNavigationHolder(gemini: widget.gemini, prefs: widget.prefs),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// ═════════════════════════════════════════════════════════════════════════
/// Bottom navigation holder: Home · Saved History · Settings/Profile.
/// Owns one StudyCubit per module so state survives navigation.
/// ═════════════════════════════════════════════════════════════════════════
class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key, required this.gemini, required this.prefs});
  final GeminiService gemini;
  final PrefsService prefs;

  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  int _currentIndex = 0;
  StudyModule? _activeModule;
  final Map<StudyModule, StudyCubit> _cubits = {};

  StudyCubit _cubitFor(BuildContext ctx, StudyModule m) => _cubits.putIfAbsent(
        m,
        () => StudyCubit(
          module: m,
          gemini: widget.gemini,
          cache: ctx.read<CacheService>(),
          gamification: ctx.read<GamificationCubit>(),
        ),
      );

  void _openModule(StudyModule m) {
    HapticFeedback.selectionClick();
    FirebaseService.logEvent('open_module', {'module': m.name});
    setState(() {
      _activeModule = m;
      _currentIndex = 0;
    });
  }

  void _openSession(StudySession s) {
    HapticFeedback.selectionClick();
    final cubit = _cubitFor(context, s.module);
    cubit.open(s.id);
    setState(() {
      _activeModule = s.module;
      _currentIndex = 0;
    });
  }

  ViralController? _viral;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Route a file shared from WhatsApp / Telegram to the right module.
    final viral = ViralScope.of(context);
    if (!identical(viral, _viral)) {
      _viral?.removeListener(_onViralChange);
      _viral = viral;
      viral.addListener(_onViralChange);
    }
  }

  void _onViralChange() {
    final viral = _viral;
    if (viral == null) return;
    if (viral.importedText != null) {
      setState(() => _activeModule = viral.importedTarget);
    } else if (viral.importedImage != null) {
      setState(() => _activeModule = StudyModule.solver);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viral?.removeListener(_onViralChange);
    for (final c in _cubits.values) {
      c.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocListener<GamificationCubit, GamificationState>(
      listenWhen: (p, c) => c.xp != p.xp,
      listener: (ctx, g) {
        final delta = g.xp - ctx.read<GamificationCubit>().previousXp;
        final msg = StringBuffer('⚡ +$delta ${l.t('xp_gained')}');
        for (final b in g.justUnlocked) {
          msg.write('\n${b.emoji} ${l.t('badge_unlocked')}: ${b.name}');
        }
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(msg.toString()), duration: Duration(seconds: g.justUnlocked.isEmpty ? 2 : 5)),
        );
      },
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFFC084FC)]),
                boxShadow: glowShadow(AppColors.primary),
              ),
              child: const Center(child: Text('🎓', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.t('app'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, height: 1)),
              Text(l.t('tagline'), style: const TextStyle(color: AppColors.muted, fontSize: 10)),
            ]),
          ]),
          actions: const [OfflineDot(), SizedBox(width: 6), LanguageToggle(), SizedBox(width: 12)],
        ),
        body: IndexedStack(index: _currentIndex, children: [
          HomeScreen(
            onOpenModule: _openModule,
            activeModule: _activeModule,
            cubitFor: _cubitFor,
          ),
          HistoryScreen(onOpenSession: _openSession),
          SettingsScreen(prefs: widget.prefs),
        ]),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(26),
                boxShadow: neuShadow(blur: 24, offset: 8),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (i) {
                  HapticFeedback.selectionClick();
                  FirebaseService.logEvent('nav_tab', {'index': i});
                  setState(() => _currentIndex = i);
                },
                destinations: [
                  NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: l.t('home')),
                  NavigationDestination(icon: const Icon(Icons.history_rounded), label: l.t('history')),
                  NavigationDestination(icon: const Icon(Icons.settings_rounded), label: l.t('settings')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ═════════════════════════════════════════════════════════════════════════
/// HOME — offline banner, hero header, module grid, viral loops (camera ·
/// dialect · peer challenge · PDF import) and the story-card export.
/// ═════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenModule, required this.activeModule, required this.cubitFor});

  final void Function(StudyModule) onOpenModule;
  final StudyModule? activeModule;
  final StudyCubit Function(BuildContext, StudyModule) cubitFor;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final viral = ViralScope.of(context);
    final cache = context.read<CacheService>();

    return AnimatedBuilder(
      animation: viral,
      builder: (context, _) => BlocBuilder<GamificationCubit, GamificationState>(
        builder: (context, g) {
          final all = cache.allSessions();
          StudySession? latestSummary;
          StudySession? latestQuiz;
          for (final s in all) {
            latestSummary ??= (s.module == StudyModule.summary || s.module == StudyModule.text) ? s : null;
            latestQuiz ??= s.result.recall.quiz.isNotEmpty ? s : null;
          }

          return Stack(children: [
            const GlowOrbs(),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                const OfflineBanner(),
                HeroHeader(state: g),
                const SizedBox(height: 22),
                Text(l.t('quick_start'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: StudyModule.values.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.98),
                  itemBuilder: (_, i) {
                    final m = StudyModule.values[i];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 500 + i * 110),
                      curve: Curves.easeOutBack,
                      builder: (_, v, child) => Transform.scale(scale: 0.85 + 0.15 * v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
                      child: GradientGlowCard(
                        colors: AppColors.gradient(m),
                        onTap: () => onOpenModule(m),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white30)),
                              child: Icon(AppColors.icon(m), color: Colors.white, size: 24),
                            ),
                            Text(AppColors.emoji(m), style: const TextStyle(fontSize: 22)),
                          ]),
                          const Spacer(),
                          Text(l.module(m), maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, height: 1.15)),
                          const SizedBox(height: 4),
                          Text(l.moduleDesc(m), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(999)),
                              child: Text('${g.moduleCounts[m] ?? 0} ${l.t('sessions')}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                NeuSurface(
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _Stat('${g.moduleCounts.values.fold(0, (a, b) => a + b)}', l.t('sessions'), AppColors.primary),
                    _vDivider(),
                    _Stat('${g.longestStreak}', l.t('best_streak'), AppColors.fire),
                    _vDivider(),
                    _Stat('${g.xp}', l.t('total_xp'), AppColors.success),
                  ]),
                ),
                const SizedBox(height: 22),
                Text(l.t('badges'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                g.badges.isEmpty
                    ? NeuSurface(child: Row(children: [
                        const Text('🔒', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l.t('no_badges'), style: const TextStyle(color: AppColors.muted))),
                      ]))
                    : Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final b in g.badges)
                          Tooltip(
                            message: b.description,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                                boxShadow: glowShadow(AppColors.primary, strength: 0.2),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)])),
                                  child: Center(child: Text(b.emoji, style: const TextStyle(fontSize: 16))),
                                ),
                                const SizedBox(width: 8),
                                Text(b.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              ]),
                            ),
                          ),
                      ]),
                const SizedBox(height: 22),
                ViralHub(
                  viral: viral,
                  latestSummary: latestSummary ?? (all.isEmpty ? null : all.first),
                  latestWithQuiz: latestQuiz,
                  streak: g.liveStreak,
                  level: g.level,
                  xp: g.xp,
                  onOpenModule: onOpenModule,
                ),
                if (activeModule != null) ...[
                  const SizedBox(height: 26),
                  Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: AppColors.gradient(activeModule!)), borderRadius: BorderRadius.circular(14)), child: Icon(AppColors.icon(activeModule!), color: Colors.white, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.module(activeModule!), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => onOpenModule(activeModule!), icon: const Icon(Icons.refresh_rounded)),
                  ]),
                  const SizedBox(height: 12),
                  BlocProvider.value(value: cubitFor(context, activeModule!), child: ModuleScreen(key: ValueKey(activeModule))),
                ],
              ],
            ),
          ]);
        },
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 36, color: AppColors.border);
}

/// ═════════════════════════════════════════════════════════════════════════
/// HISTORY — offline Hive library of every generated session.
/// ═════════════════════════════════════════════════════════════════════════
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.onOpenSession});
  final void Function(StudySession) onOpenSession;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cache = context.read<CacheService>();
    return ValueListenableBuilder(
      valueListenable: cache.sessionsListenable,
      builder: (context, _, __) {
        final all = cache.allSessions();
        if (all.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 60),
              const Text('🗂️', style: TextStyle(fontSize: 44), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(l.t('no_library'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          itemCount: all.length,
          itemBuilder: (context, i) {
            final s = all[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NeuSurface(
                padding: const EdgeInsets.all(14),
                onTap: () => onOpenSession(s),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: AppColors.gradient(s.module)), borderRadius: BorderRadius.circular(14)),
                    child: Icon(AppColors.icon(s.module), color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.result.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${s.createdAt.toLocal()}'.substring(0, 16), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  ])),
                  if (s.quizScore != null)
                    Text('${s.quizScore}/3', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800))
                  else
                    const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

/// ═════════════════════════════════════════════════════════════════════════
/// SETTINGS — educational level, language, unlock states, cache & review.
/// ═════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.prefs});
  final PrefsService prefs;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final viral = ViralScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Text(l.t('settings_profile'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        NeuSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.t('level'), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: widget.prefs.level,
            dropdownColor: AppColors.surfaceHi,
            items: [for (final e in PrefsService.levels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) async {
              if (v == null) return;
              await widget.prefs.setLevel(v);
              await FirebaseService.setUserProperty('study_level', v);
              setState(() {});
            },
          ),
        ])),
        const SizedBox(height: 16),
        NeuSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.t('language'), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<AppLocale>(
            value: context.l10n.locale,
            dropdownColor: AppColors.surfaceHi,
            items: [for (final loc in AppLocale.values) DropdownMenuItem(value: loc, child: Text('${loc.flag}  ${loc.label}'))],
            onChanged: (v) async {
              if (v == null) return;
              context.l10n.set(v);
              await widget.prefs.setLocale(v.name);
            },
          ),
        ])),
        const SizedBox(height: 16),
        NeuSurface(child: Column(children: [
          SwitchListTile(
            value: viral.cameraUnlocked,
            activeColor: AppColors.primary,
            title: Text(l.t('camera_unlocked_title'), style: const TextStyle(fontSize: 14)),
            onChanged: (v) async { if (v) { await viral.unlockCamera(); setState(() {}); } },
          ),
          SwitchListTile(
            value: viral.dialectUnlocked,
            activeColor: AppColors.primary,
            title: Text(l.t('dialect_unlocked_title'), style: const TextStyle(fontSize: 14)),
            onChanged: (v) async { if (v) { await viral.unlockDialect(); setState(() {}); } },
          ),
        ])),
        const SizedBox(height: 16),
        NeuSurface(child: Column(children: [
          ListTile(
            leading: const Icon(Icons.rate_review_rounded, color: AppColors.primary),
            title: Text(l.t('rate_app')),
            onTap: () => FirebaseService.trackValueMoment(threshold: 1),
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded, color: AppColors.success),
            title: Text(l.t('share_app')),
            onTap: () => viral.shareApp(message: '${l.t('unlock_message')} ${viral.shareBaseUrl}'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger),
            title: Text(l.t('clear_cache')),
            onTap: () async {
              await context.read<CacheService>().clearAll();
              setState(() {});
            },
          ),
        ])),
        const SizedBox(height: 16),
        NeuSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.t('about'), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Scholar AI v1.0.0\n${l.t('tagline')}\nFirebase: ${FirebaseService.ready ? 'connected' : 'standalone'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6),
          ),
        ])),
      ],
    );
  }
}

/* ═══════════════════════════ shared UI ═══════════════════════════ */

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF22D3EE)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color, shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 14)])),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ]);
}

/// Quick language toggle: tap cycles EN → FR → AR, long-press opens a picker.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        l.cycle();
      },
      onLongPress: () => showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            for (final loc in AppLocale.values)
              ListTile(
                leading: Text(loc.flag, style: const TextStyle(fontSize: 22)),
                title: Text(loc.label),
                trailing: l.locale == loc ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                onTap: () {
                  l.set(loc);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.surfaceHi,
          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
          boxShadow: glowShadow(AppColors.primary, strength: 0.3),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text(l.locale.flag, key: ValueKey(l.locale), style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 6),
          Text(l.locale.code, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
          const SizedBox(width: 2),
          const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primary),
        ]),
      ),
    );
  }
}

/* ═══════════════════════ connectivity indicators ═══════════════════════════ */

/// Single shared connectivity source for the whole app.
class ConnectivityController extends ChangeNotifier {
  ConnectivityController() {
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != isOnline) {
        isOnline = online;
        notifyListeners();
      }
    });
  }

  bool isOnline = true;
}

class _ConnectivityScope extends InheritedNotifier<ConnectivityController> {
  const _ConnectivityScope({required ConnectivityController controller, required super.child}) : super(notifier: controller);
}

/// Provides one app-wide [ConnectivityController].
class ConnectivityProvider extends StatefulWidget {
  const ConnectivityProvider({super.key, required this.child});
  final Widget child;

  static ConnectivityController of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_ConnectivityScope>()!.notifier!;

  @override
  State<ConnectivityProvider> createState() => _ConnectivityProviderState();
}

class _ConnectivityProviderState extends State<ConnectivityProvider> {
  final _controller = ConnectivityController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ConnectivityScope(controller: _controller, child: widget.child);
}

/// Pulsing green/red connectivity dot in the app bar.
class OfflineDot extends StatefulWidget {
  const OfflineDot({super.key});

  @override
  State<OfflineDot> createState() => _OfflineDotState();
}

class _OfflineDotState extends State<OfflineDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = ConnectivityProvider.of(context).isOnline;
    final color = online ? AppColors.success : AppColors.danger;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color.withOpacity(0.3 + 0.5 * _pulse.value), blurRadius: 10)],
        ),
      ),
    );
  }
}

/// Full-width offline banner explaining which features are unavailable.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late final ConnectivityController _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c = ConnectivityProvider.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => _c.isOnline
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.danger.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(l.t('offline'), style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
            ),
    );
  }
}

/// Convenience accessor for the secure Gemini key.
String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
