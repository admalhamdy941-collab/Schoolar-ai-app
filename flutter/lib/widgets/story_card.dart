import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../core/l10n.dart';
import '../core/prompts.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/viral_controller.dart';

/// Branded 9:16-ish story card captured by [ScreenshotController] and shared
/// natively via `Share.shareXFiles`.
class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.session, required this.streak, required this.level, required this.xp});
  final StudySession session;
  final int streak, level, xp;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = session.result;
    final bullets = _bullets(r);
    return Container(
      width: 360,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF134E4A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFFC084FC)])), child: const Center(child: Text('🎓', style: TextStyle(fontSize: 18)))),
          const SizedBox(width: 8),
          Text(l.t('app'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          const Spacer(),
          Text('🔥 $streak  ·  Lv.$level', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
        const SizedBox(height: 18),
        Text(l.t('story_kicker'), style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.4)),
        const SizedBox(height: 6),
        Text(r.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, height: 1.2)),
        const SizedBox(height: 14),
        for (final b in bullets.take(5))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚡ ', style: TextStyle(fontSize: 12)),
            Expanded(child: Text(b, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35))),
          ])),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(999)),
          child: Text('${l.t('app')}  ·  $xp XP  ·  scholar-ai.app', style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  List<String> _bullets(AIResult r) {
    switch (r.module) {
      case StudyModule.summary: return r.strings('bullets').map((x) => x.trim().replaceFirst(RegExp(r'^-\s*'), '')).where((x) => x.isNotEmpty).toList();
      case StudyModule.text: return [...r.strings('coreIdeas'), ...r.strings('takeaways')];
      case StudyModule.solver: return [r.raw['problemRestatement']?.toString() ?? '', '${r.finalAnswer}'].where((x) => x.isNotEmpty).toList();
      case StudyModule.grammar: return [r.raw['correctedText']?.toString() ?? ''];
      case StudyModule.dialect: return [r.raw['dialectSummary']?.toString() ?? '', ...r.strings('quickSteps')];
    }
  }
}

/// Off-screen capture host — keep in the tree (opacity 0 / offstage) OR
/// visible as a compact preview on the Home dashboard.
class StoryExportBar extends StatelessWidget {
  const StoryExportBar({super.key, required this.viral, required this.session, required this.streak, required this.level, required this.xp});
  final ViralController viral;
  final StudySession? session;
  final int streak, level, xp;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (session == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Text('⚡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(l.t('story_empty'), style: const TextStyle(color: AppColors.muted, fontSize: 13))),
        ]),
      );
    }
    return Column(children: [
      // Hidden at 0.01 scale would break capture; we show a live preview.
      Screenshot(controller: viral.screenshot, child: StoryCard(session: session!, streak: streak, level: level, xp: xp)),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => viral.shareStoryCard(caption: l.t('story_caption')),
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(l.t('story_export')),
        ),
      ),
    ]);
  }
}
