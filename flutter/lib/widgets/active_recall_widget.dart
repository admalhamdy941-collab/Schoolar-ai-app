import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

/// Active Recall Widget — appended after EVERY AI response.
/// 3-question interactive micro-quiz + 3 Anki-style flip flashcards.
class ActiveRecallWidget extends StatelessWidget {
  const ActiveRecallWidget({super.key, required this.recall, required this.savedScore, required this.onQuizComplete});
  final ActiveRecall recall;
  final int? savedScore;
  final void Function(int correct, int total) onQuizComplete;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 16),
      Row(children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('ACTIVE RECALL', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2))),
        const Expanded(child: Divider()),
      ]),
      const SizedBox(height: 12),
      if (recall.quiz.isNotEmpty) _MicroQuiz(quiz: recall.quiz, savedScore: savedScore, onComplete: onQuizComplete),
      const SizedBox(height: 12),
      if (recall.flashcards.isNotEmpty) _FlashcardDeck(cards: recall.flashcards),
    ]);
  }
}

class _MicroQuiz extends StatefulWidget {
  const _MicroQuiz({required this.quiz, required this.savedScore, required this.onComplete});
  final List<QuizQuestion> quiz;
  final int? savedScore;
  final void Function(int, int) onComplete;
  @override
  State<_MicroQuiz> createState() => _MicroQuizState();
}

class _MicroQuizState extends State<_MicroQuiz> {
  late final List<int?> _answers = List.filled(widget.quiz.length, null);
  late bool _checked = widget.savedScore != null;

  int get _correct => [for (var i = 0; i < widget.quiz.length; i++) if (_answers[i] == widget.quiz[i].answerIndex) 1].length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Text('🎯 ', style: TextStyle(fontSize: 18)),
            Text('Micro-Quiz', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_checked) Chip(label: Text('Score: ${widget.savedScore ?? _correct}/${widget.quiz.length}'), backgroundColor: cs.tertiaryContainer),
          ]),
          const SizedBox(height: 8),
          for (var qi = 0; qi < widget.quiz.length; qi++) ...[
            Text('${qi + 1}. ${widget.quiz[qi].question}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (var oi = 0; oi < widget.quiz[qi].options.length; oi++)
              _OptionTile(
                label: widget.quiz[qi].options[oi],
                letter: String.fromCharCode(65 + oi),
                selected: _answers[qi] == oi,
                state: !_checked ? null : (oi == widget.quiz[qi].answerIndex ? true : (_answers[qi] == oi ? false : null)),
                onTap: _checked ? null : () { HapticFeedback.selectionClick(); setState(() => _answers[qi] = oi); },
              ),
            if (_checked) Padding(padding: const EdgeInsets.only(top: 4, bottom: 12), child: Text('💡 ${widget.quiz[qi].explanation}', style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 8),
          ],
          if (!_checked)
            FilledButton(
              onPressed: _answers.contains(null) ? null : () {
                setState(() => _checked = true);
                _correct == widget.quiz.length ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
                widget.onComplete(_correct, widget.quiz.length);
              },
              child: const Text('Check answers'),
            ),
        ]),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.letter, required this.selected, required this.state, required this.onTap});
  final String label, letter;
  final bool selected;
  final bool? state; // true=correct, false=wrong, null=neutral
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = state == true ? Colors.green : state == false ? Colors.red : (selected ? cs.primary : cs.outlineVariant);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(border: Border.all(color: color, width: selected || state != null ? 2 : 1), borderRadius: BorderRadius.circular(12), color: color.withOpacity(selected || state != null ? 0.08 : 0)),
      child: ListTile(dense: true, onTap: onTap, leading: CircleAvatar(radius: 12, child: Text(letter, style: const TextStyle(fontSize: 11))), title: Text(label), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}

class _FlashcardDeck extends StatefulWidget {
  const _FlashcardDeck({required this.cards});
  final List<Flashcard> cards;
  @override
  State<_FlashcardDeck> createState() => _FlashcardDeckState();
}

class _FlashcardDeckState extends State<_FlashcardDeck> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  int _index = 0;

  void _flip() { HapticFeedback.lightImpact(); _ctrl.isCompleted ? _ctrl.reverse() : _ctrl.forward(); }
  void _go(int d) { HapticFeedback.selectionClick(); _ctrl.reset(); setState(() => _index = (_index + d) % widget.cards.length); }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[_index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            const Text('🃏 ', style: TextStyle(fontSize: 18)),
            Text('Flashcards', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${_index + 1} / ${widget.cards.length}', style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _flip,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final angle = _ctrl.value * math.pi;
                final showBack = angle > math.pi / 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                  child: showBack
                      ? Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateY(math.pi), child: _Face(text: card.back, label: 'BACK', colors: const [Color(0xFF10B981), Color(0xFF0D9488)]))
                      : _Face(text: card.front, label: 'FRONT', colors: const [Color(0xFF6366F1), Color(0xFF7C3AED)]),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TextButton(onPressed: () => _go(widget.cards.length - 1), child: const Text('← Prev')),
            TextButton(onPressed: () => _go(1), child: const Text('Next →')),
          ]),
        ]),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.text, required this.label, required this.colors});
  final String text, label;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) => Container(
        height: 170, width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: colors.first.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2)),
          const Spacer(),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, height: 1.3)),
          const Spacer(),
          const Text('Tap to flip', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
}
