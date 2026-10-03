import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'gradient_card.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// AIOutputBox — animated response container.
///   • Gradient title banner (module-coloured)
///   • Action bar: Copy · Share · Listen (TTS) · Take Micro-Quiz
///   • Accordion sections (expand/collapse with animated chevrons)
///   • Staggered fade-slide entrance
/// ─────────────────────────────────────────────────────────────────────────
class AIOutputBox extends StatefulWidget {
  const AIOutputBox({super.key, required this.result, required this.sections, required this.onTakeQuiz, required this.plainText});
  final AIResult result;
  final List<AccordionSection> sections;
  final VoidCallback onTakeQuiz;
  /// Plain-text rendering of the result for Copy / Share / TTS.
  final String plainText;

  @override
  State<AIOutputBox> createState() => _AIOutputBoxState();
}

class _AIOutputBoxState extends State<AIOutputBox> with SingleTickerProviderStateMixin {
  late final _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  final _tts = FlutterTts();
  bool _speaking = false;

  @override
  void dispose() { _tts.stop(); _enter.dispose(); super.dispose(); }

  Future<void> _listen() async {
    HapticFeedback.selectionClick();
    if (_speaking) { await _tts.stop(); setState(() => _speaking = false); return; }
    await _tts.setLanguage(context.l10n.locale.ttsTag);
    await _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() => mounted ? setState(() => _speaking = false) : null);
    setState(() => _speaking = true);
    await _tts.speak(widget.plainText);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = AppColors.gradient(widget.result.module);
    Widget stagger(int i, Widget child) => AnimatedBuilder(
          animation: _enter,
          builder: (_, c) {
            final t = Curves.easeOutCubic.transform(((_enter.value - i * 0.08).clamp(0, 1)) / 1);
            return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: c));
          },
          child: child,
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      stagger(0, GradientGlowCard(
        colors: colors,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(AppColors.emoji(widget.result.module), style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(l.module(widget.result.module).toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(widget.result.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.15)),
        ]),
      )),
      const SizedBox(height: 12),
      // Action bar
      stagger(1, Row(children: [
        _Action(icon: Icons.copy_rounded, label: l.t('copy'), onTap: () async { await Clipboard.setData(ClipboardData(text: widget.plainText)); HapticFeedback.mediumImpact(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.t('copied')))); }),
        const SizedBox(width: 8),
        _Action(icon: Icons.ios_share_rounded, label: l.t('share'), onTap: () => Share.share(widget.plainText, subject: widget.result.title)),
        const SizedBox(width: 8),
        _Action(icon: _speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded, label: l.t('listen'), active: _speaking, onTap: _listen),
        const SizedBox(width: 8),
        Expanded(child: _Action(icon: Icons.quiz_rounded, label: l.t('take_quiz'), primary: true, color: colors.first, onTap: () { HapticFeedback.mediumImpact(); widget.onTakeQuiz(); })),
      ])),
      const SizedBox(height: 14),
      for (final (i, s) in widget.sections.indexed) stagger(i + 2, Padding(padding: const EdgeInsets.only(bottom: 10), child: _Accordion(section: s, accent: colors.first, initiallyOpen: i == 0))),
    ]);
  }
}

class AccordionSection {
  const AccordionSection({required this.title, required this.icon, required this.child});
  final String title; final IconData icon; final Widget child;
}

class _Accordion extends StatefulWidget {
  const _Accordion({required this.section, required this.accent, required this.initiallyOpen});
  final AccordionSection section; final Color accent; final bool initiallyOpen;
  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  late bool _open = widget.initiallyOpen;
  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      padding: EdgeInsets.zero,
      glowColor: _open ? widget.accent : null,
      child: Column(children: [
        InkWell(
          borderRadius: AppRadii.rCard,
          onTap: () { HapticFeedback.selectionClick(); setState(() => _open = !_open); },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: widget.accent.withOpacity(0.18), borderRadius: BorderRadius.circular(12)), child: Icon(widget.section.icon, color: widget.accent, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.section.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              AnimatedRotation(turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 250), child: const Icon(Icons.expand_more_rounded, color: AppColors.muted)),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic, alignment: Alignment.topCenter,
          child: _open ? Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Align(alignment: AlignmentDirectional.centerStart, child: widget.section.child)) : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.primary = false, this.active = false, this.color});
  final IconData icon; final String label; final VoidCallback onTap; final bool primary, active; final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final child = Container(
      height: 48, padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: primary ? LinearGradient(colors: [c, c.withOpacity(0.75)]) : null,
        color: primary ? null : (active ? c.withOpacity(0.25) : AppColors.surfaceHi),
        border: Border.all(color: primary ? Colors.white24 : (active ? c : AppColors.border)),
        boxShadow: primary ? glowShadow(c, strength: 0.5) : neuShadow(blur: 10, offset: 4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20, color: primary ? Colors.white : (active ? c : AppColors.text)),
        if (primary) ...[const SizedBox(width: 8), Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))],
      ]),
    );
    return Tooltip(message: label, child: GestureDetector(onTap: onTap, child: child));
  }
}

/// Shimmering skeleton shown while Gemini is thinking.
class AISkeleton extends StatefulWidget {
  const AISkeleton({super.key, required this.accent});
  final Color accent;
  @override
  State<AISkeleton> createState() => _AISkeletonState();
}

class _AISkeletonState extends State<AISkeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  Widget _bar(double w, double h) => AnimatedBuilder(animation: _c, builder: (_, __) => Container(
        height: h, width: w, margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: LinearGradient(begin: Alignment(-1 + 3 * _c.value, 0), end: Alignment(0 + 3 * _c.value, 0), colors: [AppColors.surfaceHi, widget.accent.withOpacity(0.35), AppColors.surfaceHi])),
      ));
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _bar(double.infinity, 92), _bar(220, 20), _bar(double.infinity, 14), _bar(double.infinity, 14), _bar(180, 14),
        const SizedBox(height: 8), _bar(double.infinity, 64), _bar(double.infinity, 64),
        Center(child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('thinking'), style: TextStyle(color: widget.accent, fontWeight: FontWeight.w700)))),
      ]);
}
