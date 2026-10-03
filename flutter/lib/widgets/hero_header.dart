import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../bloc/gamification_cubit.dart';
import '../core/l10n.dart';
import '../core/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// HeroHeader — avatar, glowing pulsing streak flame, level ring + XP bar.
/// ─────────────────────────────────────────────────────────────────────────
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
    final progress = g.xpIntoLevel / g.xpForNextLevel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [...neuShadow(blur: 24, offset: 10), ...glowShadow(AppColors.primary, strength: 0.25)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar with level ring
          Stack(alignment: Alignment.center, children: [
            SizedBox(width: 64, height: 64, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: progress), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic, builder: (_, v, __) => CircularProgressIndicator(value: v, strokeWidth: 4, backgroundColor: Colors.white12, color: AppColors.primary, strokeCap: StrokeCap.round))),
            Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFFC084FC)]), boxShadow: glowShadow(AppColors.primary)), child: const Center(child: Text('🎓', style: TextStyle(fontSize: 24)))),
            PositionedDirectional(bottom: -2, end: -2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.primary)), child: Text('${g.level}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary)))),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${l.t('hello')}, ${l.t('student')} 👋', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            Text('${l.t('level')} ${g.level} ${l.t('scholar_rank')}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
            const SizedBox(height: 4),
            Text('${g.xpIntoLevel} / ${g.xpForNextLevel} ${l.t('xp')}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
          ])),
          // Glowing streak flame
          AnimatedBuilder(animation: _pulse, builder: (_, __) {
            final s = 0.9 + 0.1 * _pulse.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                boxShadow: [BoxShadow(color: AppColors.fire.withOpacity(0.35 + 0.35 * _pulse.value), blurRadius: 24 * s, spreadRadius: 1)],
              ),
              child: Column(children: [
                Transform.scale(scale: s, child: const Text('🔥', style: TextStyle(fontSize: 22))),
                Text('${g.liveStreak} ${l.t('days')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
              ]),
            );
          }),
        ]),
        const SizedBox(height: 16),
        // XP bar with shimmer
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(children: [
            Container(height: 12, color: Colors.white10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress), duration: const Duration(milliseconds: 1100), curve: Curves.easeOutCubic,
              builder: (_, v, __) => FractionallySizedBox(widthFactor: v.clamp(0.02, 1), child: Container(height: 12, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFFA78BFA), Color(0xFF22D3EE)]), boxShadow: glowShadow(AppColors.primary, strength: 0.6)))),
            ),
            AnimatedBuilder(animation: _pulse, builder: (_, __) => Positioned.fill(child: FractionallySizedBox(alignment: Alignment((_pulse.value * 2 - 1) * 1.4, 0), widthFactor: 0.25, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withOpacity(0.35), Colors.transparent])))))),
          ]),
        ),
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

/// Decorative animated background orbs behind the dashboard.
class GlowOrbs extends StatelessWidget {
  const GlowOrbs({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(child: Stack(children: [
        _orb(-80, -60, 260, const Color(0xFF6366F1)),
        _orb(null, 220, 220, const Color(0xFF06B6D4), right: -100),
        _orb(520, -40, 200, const Color(0xFFF43F5E)),
      ]));
  Widget _orb(double? top, double? left, double size, Color c, {double? right}) => Positioned(
        top: top, left: left, right: right,
        child: Transform.rotate(angle: math.pi / 6, child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withOpacity(0.22), c.withOpacity(0)])))),
      );
}
