import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/l10n.dart';
import '../core/prompts.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/viral_controller.dart';
import 'share_unlock_dialog.dart';
import 'story_card.dart';

/// Home-screen strip that surfaces the four viral loops.
class ViralHub extends StatelessWidget {
  const ViralHub({
    super.key,
    required this.viral,
    required this.latestSummary,
    required this.latestWithQuiz,
    required this.streak,
    required this.level,
    required this.xp,
    required this.onOpenModule,
  });

  final ViralController viral;
  final StudySession? latestSummary;
  final StudySession? latestWithQuiz;
  final int streak, level, xp;
  final void Function(StudyModule) onOpenModule;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title(l.t('viral')),
      const SizedBox(height: 12),
      _card(
        title: viral.cameraUnlocked ? l.t('camera_unlocked_title') : l.t('camera_locked_title'),
        subtitle: viral.cameraUnlocked ? l.t('camera_unlocked_sub') : l.t('camera_locked_sub'),
        icon: viral.cameraUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
        colors: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
        onTap: () async {
          if (viral.cameraUnlocked) {
            onOpenModule(StudyModule.solver);
            return;
          }
          final ok = await showShareToUnlockDialog(context, viral);
          if (ok && context.mounted) {
            await viral.unlockCamera();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('unlock_success'))));
            onOpenModule(StudyModule.solver);
          }
        },
      ),
      const SizedBox(height: 12),
      _card(
        title: viral.dialectUnlocked ? l.t('dialect_unlocked_title') : l.t('dialect_locked_title'),
        subtitle: viral.dialectUnlocked ? l.t('dialect_unlocked_sub') : l.t('dialect_locked_sub'),
        icon: viral.dialectUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
        colors: const [Color(0xFF22C55E), Color(0xFFEAB308)],
        onTap: () async {
          if (viral.dialectUnlocked) {
            onOpenModule(StudyModule.dialect);
            return;
          }
          final ok = await showShareToUnlockDialog(context, viral);
          if (ok) {
            await viral.unlockDialect();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('unlock_success'))));
              onOpenModule(StudyModule.dialect);
            }
          }
        },
      ),
      const SizedBox(height: 12),
      _card(
        title: l.t('peer_title'),
        subtitle: l.t('peer_sub'),
        icon: Icons.sports_esports_rounded,
        colors: const [Color(0xFF10B981), Color(0xFF059669)],
        onTap: () async {
          HapticFeedback.mediumImpact();
          final s = latestWithQuiz;
          if (s == null || s.result.recall.quiz.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('peer_need_quiz'))));
            return;
          }
          await viral.shareChallenge(session: s, messageTemplate: l.t('peer_message'));
        },
      ),
      const SizedBox(height: 12),
      _card(
        title: l.t('pdf_title'),
        subtitle: l.t('pdf_sub'),
        icon: Icons.picture_as_pdf_rounded,
        colors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        onTap: () {
          HapticFeedback.selectionClick();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('pdf_hint'))));
        },
      ),
      if (viral.pdfStatus.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.18), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.4))),
          child: Row(children: [
            Icon(viral.pdfStatus == 'error' ? Icons.error_outline : Icons.picture_as_pdf, color: const Color(0xFFA5B4FC), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(viral.pdfStatus == 'error' ? l.t('pdf_failed') : l.t('pdf_ok'), style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
        ),
      ],
      const SizedBox(height: 18),
      _title(l.t('story_title')),
      const SizedBox(height: 12),
      StoryExportBar(viral: viral, session: latestSummary, streak: streak, level: level, xp: xp),
    ]);
  }

  Widget _title(String t) => Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF22D3EE)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
        const SizedBox(width: 10),
        Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ]);

  Widget _card({required String title, required String subtitle, required IconData icon, required List<Color> colors, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: glowShadow(colors.first, strength: 0.35),
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
        ]),
      ),
    );
  }
}
