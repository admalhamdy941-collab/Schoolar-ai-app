import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// GradientGlowCard — floating 24px-radius card with a vibrant gradient,
/// outer glow, 1px glass border and press-scale + haptic feedback.
/// ─────────────────────────────────────────────────────────────────────────
class GradientGlowCard extends StatefulWidget {
  const GradientGlowCard({super.key, required this.colors, required this.child, this.onTap, this.padding = const EdgeInsets.all(18), this.height, this.glow = 0.45});
  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double? height;
  final double glow;

  @override
  State<GradientGlowCard> createState() => _GradientGlowCardState();
}

class _GradientGlowCardState extends State<GradientGlowCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap == null ? null : () { HapticFeedback.lightImpact(); widget.onTap!(); },
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: AppRadii.rCard,
            gradient: LinearGradient(colors: widget.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: glowShadow(widget.colors.first, strength: _pressed ? widget.glow * 0.6 : widget.glow),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Stack(children: [
            // soft highlight blob (top-start) for a 3D feel
            PositionedDirectional(top: -40, start: -30, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.12)))),
            PositionedDirectional(bottom: -50, end: -40, child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.10)))),
            Padding(padding: widget.padding, child: widget.child),
          ]),
        ),
      ),
    );
  }
}

/// NeuSurface — raised dark neumorphic container used for content panels.
class NeuSurface extends StatelessWidget {
  const NeuSurface({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.glowColor, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? glowColor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.rCard,
        border: Border.all(color: glowColor?.withOpacity(0.35) ?? AppColors.border),
        boxShadow: [...neuShadow(), if (glowColor != null) ...glowShadow(glowColor!, strength: 0.18)],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return box;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: AppRadii.rCard, onTap: () { HapticFeedback.selectionClick(); onTap!(); }, child: box));
  }
}

/// Small glowing pill (tags, counters).
class GlowPill extends StatelessWidget {
  const GlowPill({super.key, required this.label, this.color = AppColors.primary, this.icon});
  final String label; final Color color; final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.4)), boxShadow: glowShadow(color, strength: 0.25)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      );
}
