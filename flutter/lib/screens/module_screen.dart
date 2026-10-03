import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../bloc/study_cubit.dart';
import '../core/l10n.dart';
import '../core/prompts.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/viral_controller.dart';
import '../widgets/active_recall_widget.dart';
import '../widgets/ai_output_box.dart';
import '../widgets/gradient_card.dart';
import '../widgets/share_unlock_dialog.dart';
import '../widgets/step_by_step_view.dart';

/// Generic module tab: input panel → skeleton → AIOutputBox → Active Recall.
class ModuleScreen extends StatefulWidget {
  const ModuleScreen({super.key});
  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _recallKey = GlobalKey();
  Uint8List? _image;
  String _target = 'English';

  Future<void> _pick(ImageSource src) async {
    if (src == ImageSource.camera) {
      final viral = ViralScope.of(context);
      if (!viral.cameraUnlocked) {
        final ok = await showShareToUnlockDialog(context, viral);
        if (!ok) return;
      }
    }
    final x = await ImagePicker().pickImage(source: src, imageQuality: 85, maxWidth: 1600);
    if (x == null) return;
    HapticFeedback.lightImpact();
    final bytes = await x.readAsBytes();
    setState(() => _image = bytes);
  }

  void _scrollToQuiz() {
    final ctx = _recallKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viral = ViralScope.of(context);
    final m = context.read<StudyCubit>().module;
    if (viral.importedText != null && (m == viral.importedTarget || m == StudyModule.summary || m == StudyModule.text)) {
      _ctrl.text = viral.importedText!;
      viral.consumeImport();
    }
    if (viral.importedImage != null && m == StudyModule.solver) {
      _image = viral.importedImage;
      viral.consumeImport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<StudyCubit>();
    final level = RepositoryProvider.of<StudyLevel>(context);
    final m = cubit.module;
    final colors = AppColors.gradient(m);

    return BlocConsumer<StudyCubit, StudyState>(
      listener: (ctx, s) {
        if (s.status == StudyStatus.failure) {
          HapticFeedback.vibrate();
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(s.error ?? l.t('error_generic')), backgroundColor: AppColors.danger));
        }
        if (s.status == StudyStatus.success && s.current != null) { _ctrl.clear(); _image = null; }
      },
      builder: (ctx, s) => ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          if (s.current == null) ...[
            // ── Header banner ──
            GradientGlowCard(colors: colors, child: Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)), child: Icon(AppColors.icon(m), color: Colors.white, size: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.module(m), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                Text(l.moduleDesc(m), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ])),
            const SizedBox(height: 16),
            // ── Input panel ──
            NeuSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _ctrl, minLines: 5, maxLines: 12, style: const TextStyle(height: 1.5), decoration: InputDecoration(hintText: l.t('ph_${m.name}'))),
              const SizedBox(height: 12),
              if (m == StudyModule.grammar)
                DropdownButtonFormField<String>(value: _target, decoration: InputDecoration(labelText: l.t('translate_to'), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8)), dropdownColor: AppColors.surfaceHi, items: [for (final x in ['English', 'French', 'Arabic', 'Spanish', 'German']) DropdownMenuItem(value: x, child: Text(x))], onChanged: (v) => setState(() => _target = v!)),
              if (m == StudyModule.solver) ...[
                Row(children: [
                  Expanded(child: _Tool(icon: Icons.photo_camera_rounded, label: l.t('camera'), color: colors.first, onTap: () => _pick(ImageSource.camera))),
                  const SizedBox(width: 8),
                  Expanded(child: _Tool(icon: Icons.photo_library_rounded, label: l.t('gallery'), color: colors.first, onTap: () => _pick(ImageSource.gallery))),
                ]),
                if (_image != null) Padding(padding: const EdgeInsets.only(top: 12), child: Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.memory(_image!, height: 200, width: double.infinity, fit: BoxFit.cover)),
                  PositionedDirectional(top: 8, end: 8, child: IconButton.filled(style: IconButton.styleFrom(backgroundColor: Colors.black54), onPressed: () => setState(() => _image = null), icon: const Icon(Icons.close_rounded))),
                ])),
              ],
              const SizedBox(height: 14),
              _GenerateButton(colors: colors, loading: s.status == StudyStatus.loading, label: s.status == StudyStatus.loading ? l.t('thinking') : l.t('generate'),
                onTap: () { HapticFeedback.mediumImpact(); cubit.generate(input: _ctrl.text, lang: l.locale.promptLang, imageBytes: _image, targetLanguage: m == StudyModule.grammar ? _target : null, level: level); }),
            ])),
            if (s.status == StudyStatus.loading) Padding(padding: const EdgeInsets.only(top: 16), child: AISkeleton(accent: colors.first)),
            // ── Offline library ──
            if (s.history.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: [const Icon(Icons.offline_pin_rounded, color: AppColors.muted, size: 18), const SizedBox(width: 6), Text(l.t('library'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]),
              const SizedBox(height: 10),
              for (final h in s.history) Padding(padding: const EdgeInsets.only(bottom: 10), child: NeuSurface(
                padding: const EdgeInsets.all(14), onTap: () => cubit.open(h.id),
                child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(14)), child: Icon(AppColors.icon(m), color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h.result.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${h.createdAt.toLocal()}'.substring(0, 16), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  ])),
                  if (h.quizScore != null) GlowPill(label: '${h.quizScore}/3', color: AppColors.success, icon: Icons.check_rounded) else const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ]),
              )),
            ],
          ] else ...[
            // ── Result ──
            Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: cubit.close, icon: const Icon(Icons.arrow_back_rounded), label: Text(l.t('back')))),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (s.current!.module == StudyModule.summary || s.current!.module == StudyModule.text)
                FilledButton.tonalIcon(onPressed: () => ViralScope.of(context).shareStoryCard(caption: l.t('story_caption')), icon: const Icon(Icons.auto_awesome_mosaic_rounded, size: 18), label: Text(l.t('story_export'))),
              if (s.current!.result.recall.quiz.isNotEmpty)
                FilledButton.tonalIcon(onPressed: () => ViralScope.of(context).shareChallenge(session: s.current!, messageTemplate: l.t('peer_message')), icon: const Icon(Icons.sports_esports_rounded, size: 18), label: Text(l.t('peer_title'))),
            ]),
            const SizedBox(height: 8),
            AIOutputBox(result: s.current!.result, sections: _sections(ctx, s.current!.result), onTakeQuiz: _scrollToQuiz, plainText: _plain(ctx, s.current!.result)),
            const SizedBox(height: 8),
            KeyedSubtree(key: _recallKey, child: ActiveRecallWidget(recall: s.current!.result.recall, savedScore: s.current!.quizScore, onQuizComplete: (c, t) => cubit.completeQuiz(s.current!.id, c, t))),
          ],
        ],
      ),
    );
  }

  // ── Section builders per module ──
  List<AccordionSection> _sections(BuildContext ctx, AIResult r) {
    final l = ctx.l10n;
    Widget bullets(List<String> xs, {Color? dot}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final x in xs) Padding(padding: EdgeInsetsDirectional.only(bottom: 8, start: x.startsWith('  ') ? 18 : 0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(margin: const EdgeInsets.only(top: 7), width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: dot ?? AppColors.accent(r.module), boxShadow: glowShadow(dot ?? AppColors.accent(r.module), strength: 0.6))),
            const SizedBox(width: 10),
            Expanded(child: Text(x.trim().replaceFirst(RegExp(r'^-\s*'), ''), style: const TextStyle(height: 1.5))),
          ])),
        ]);
    Widget kv(String k, String v, {String? sub}) => Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surfaceLo, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent(r.module))),
            Text(v, style: const TextStyle(height: 1.4)),
            if (sub != null) Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
        );
    switch (r.module) {
      case StudyModule.text:
        return [
          AccordionSection(title: l.t('core_ideas'), icon: Icons.lightbulb_rounded, child: bullets(r.strings('coreIdeas'))),
          AccordionSection(title: l.t('themes'), icon: Icons.hub_rounded, child: Column(children: [for (final x in r.maps('subThemes')) kv(x['theme'] ?? '', x['explanation'] ?? '')])),
          AccordionSection(title: l.t('vocab'), icon: Icons.spellcheck_rounded, child: Column(children: [for (final x in r.maps('vocabulary')) kv(x['word'] ?? '', x['definition'] ?? '', sub: '“${x['contextSentence']}”')])),
          AccordionSection(title: l.t('takeaways'), icon: Icons.eco_rounded, child: bullets(r.strings('takeaways'))),
        ];
      case StudyModule.solver:
        return [
          AccordionSection(title: l.t('problem'), icon: Icons.push_pin_rounded, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.raw['problemRestatement']?.toString() ?? '', style: const TextStyle(height: 1.5)), const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: [for (final c in r.strings('concepts')) GlowPill(label: c, color: AppColors.accent(r.module))])])),
          AccordionSection(title: l.t('steps'), icon: Icons.stairs_rounded, child: StepByStepView(steps: r.steps, finalAnswer: r.finalAnswer)),
          AccordionSection(title: l.t('mistakes'), icon: Icons.warning_amber_rounded, child: bullets(r.strings('commonMistakes'), dot: AppColors.danger)),
        ];
      case StudyModule.summary:
        return [
          AccordionSection(title: l.t('notes'), icon: Icons.notes_rounded, child: bullets(r.strings('bullets'))),
          AccordionSection(title: l.t('equations'), icon: Icons.functions_rounded, child: Column(children: [for (final x in r.maps('keyEquations')) Directionality(textDirection: TextDirection.ltr, child: kv(x['name'] ?? '', x['formula'] ?? '', sub: x['meaning']))])),
          AccordionSection(title: l.t('slides'), icon: Icons.slideshow_rounded, child: Column(children: [for (final (i, x) in r.maps('slideOutline').indexed) kv('${i + 1}. ${x['slideTitle']}', (x['points'] as List? ?? []).map((p) => '• $p').join('\n'))])),
        ];
      case StudyModule.dialect:
        return [
          AccordionSection(title: l.t('dialect_summary'), icon: Icons.record_voice_over_rounded, child: Text(r.raw['dialectSummary']?.toString() ?? '', style: const TextStyle(height: 1.6, fontSize: 15))),
          AccordionSection(title: l.t('everyday_examples'), icon: Icons.local_fire_department_rounded, child: Column(children: [for (final x in r.maps('everydayExamples')) kv(x['example'] ?? '', x['linkToConcept'] ?? '')])),
          AccordionSection(title: l.t('term_glossary'), icon: Icons.swap_horiz_rounded, child: Column(children: [for (final x in r.maps('examTermGlossary')) kv('${x['dialectTerm']} → ${x['formalTerm']}', x['meaning'] ?? '')])),
          AccordionSection(title: l.t('quick_steps'), icon: Icons.checklist_rounded, child: bullets(r.strings('quickSteps'))),
        ];
      case StudyModule.grammar:
        final tr = Map<String, dynamic>.from(r.raw['translation'] ?? {});
        return [
          AccordionSection(title: l.t('corrected'), icon: Icons.check_circle_rounded, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.success.withOpacity(0.4))), child: SelectableText(r.raw['correctedText']?.toString() ?? '', style: const TextStyle(height: 1.6, fontSize: 15)))),
          AccordionSection(title: l.t('issues'), icon: Icons.healing_rounded, child: Column(children: [for (final x in r.maps('issues')) kv('${x['original']}  →  ${x['fix']}', x['rule'] ?? '')])),
          AccordionSection(title: l.t('analysis'), icon: Icons.account_tree_rounded, child: Column(children: [for (final x in r.maps('sentenceAnalysis')) kv(x['part'] ?? '', x['role'] ?? '', sub: x['note'])])),
          AccordionSection(title: '${l.t('translation')} → ${tr['targetLanguage'] ?? ''}', icon: Icons.public_rounded, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SelectableText(tr['text']?.toString() ?? '', style: const TextStyle(fontSize: 15, height: 1.6)), if ((tr['notes'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('📝 ${tr['notes']}', style: const TextStyle(color: AppColors.muted, fontSize: 12)))])),
        ];
    }
  }

  /// Plain-text export used by Copy / Share / TTS.
  String _plain(BuildContext ctx, AIResult r) {
    final b = StringBuffer('${r.title}\n\n');
    void list(String h, List<String> xs) { if (xs.isNotEmpty) { b.writeln(h); for (final x in xs) b.writeln('• ${x.trim()}'); b.writeln(); } }
    switch (r.module) {
      case StudyModule.text: list('Core ideas', r.strings('coreIdeas')); list('Takeaways', r.strings('takeaways'));
      case StudyModule.solver: b.writeln(r.raw['problemRestatement'] ?? ''); b.writeln(); for (final s in r.steps) b.writeln('${s.title}\n${s.content}\n'); b.writeln('Answer: ${r.finalAnswer}');
      case StudyModule.summary: list('Notes', r.strings('bullets'));
      case StudyModule.grammar: b.writeln(r.raw['correctedText'] ?? ''); b.writeln(); b.writeln((r.raw['translation'] ?? {})['text'] ?? '');
      case StudyModule.dialect: b.writeln(r.raw['dialectSummary'] ?? ''); b.writeln(); for (final x in r.strings('quickSteps')) b.writeln('• $x');
    }
    return b.toString();
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Container(
        height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: color.withOpacity(0.12), border: Border.all(color: color.withOpacity(0.4))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800))]),
      ));
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.colors, required this.loading, required this.label, required this.onTap});
  final List<Color> colors; final bool loading; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250), height: 56,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: loading ? [AppColors.surfaceHi, AppColors.surfaceHi] : colors), boxShadow: loading ? null : glowShadow(colors.first, strength: 0.55), border: Border.all(color: Colors.white24)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)) else const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
        ),
      );
}
