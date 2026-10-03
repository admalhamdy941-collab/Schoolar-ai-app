import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

/// Step-by-Step Pedagogy Mode: progressive disclosure of collapsible steps,
/// each with a "Why this formula?" tooltip. The final answer is only revealed
/// after the student has walked through every step.
class StepByStepView extends StatefulWidget {
  const StepByStepView({super.key, required this.steps, required this.finalAnswer});
  final List<SolutionStep> steps;
  final String finalAnswer;
  @override
  State<StepByStepView> createState() => _StepByStepViewState();
}

class _StepByStepViewState extends State<StepByStepView> {
  int _revealed = 1;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = _revealed >= widget.steps.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < _revealed && i < widget.steps.length; i++)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            initiallyExpanded: i == _revealed - 1,
            leading: CircleAvatar(radius: 14, backgroundColor: cs.primary, child: Text('${i + 1}', style: TextStyle(color: cs.onPrimary, fontSize: 12))),
            title: Text(widget.steps[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              Align(alignment: AlignmentDirectional.centerStart, child: SelectableText(widget.steps[i].content, style: const TextStyle(height: 1.5))),
              if (widget.steps[i].why != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Tooltip(
                    message: widget.steps[i].why!,
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 8),
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Chip(avatar: const Text('❓'), label: const Text('Why this formula?'), backgroundColor: Colors.amber.withOpacity(0.15)),
                  ),
                ),
            ],
          ),
        ),
      if (!done)
        FilledButton.tonal(
          onPressed: () { HapticFeedback.lightImpact(); setState(() => _revealed++); },
          child: Text('Reveal step ${_revealed + 1}/${widget.steps.length} →'),
        )
      else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), border: Border.all(color: Colors.green, width: 2), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FINAL ANSWER', style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 4),
            SelectableText(widget.finalAnswer, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          ]),
        ),
    ]);
  }
}
