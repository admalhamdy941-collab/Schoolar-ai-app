import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'cache_service.dart';
import '../core/prompts.dart';
import '../models/models.dart';

/// Deep-link / web origin used in share messages.
const kShareBaseUrl = String.fromEnvironment('SHARE_BASE', defaultValue: 'https://scholar-ai.app');

/// Central controller for the four viral growth loops:
/// 1. Share-to-unlock camera solver
/// 2. Export lesson summaries as branded story cards
/// 3. Peer quiz challenge links
/// 4. Direct PDF / document import (WhatsApp, Telegram, Files)
class ViralController extends ChangeNotifier {
  ViralController(this._cache);
  final CacheService _cache;

  final ScreenshotController screenshot = ScreenshotController();
  StreamSubscription? _mediaSub;
  StreamSubscription? _textSub;

  bool cameraUnlocked = false;
  bool dialectUnlocked = false;
  String pdfStatus = '';
  String? importedText;
  StudyModule importedTarget = StudyModule.summary;
  Uint8List? importedImage;

  Future<void> init() async {
    cameraUnlocked = _cache.read<bool>('cameraUnlocked') ?? false;
    dialectUnlocked = _cache.read<bool>('dialectUnlocked') ?? false;
    notifyListeners();

    // Cold start: app launched via "Share to Scholar AI" from WhatsApp / Telegram.
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) await ingestShared(initial);
      ReceiveSharingIntent.instance.reset();
    } catch (_) {/* desktop / web stub */}

    try {
      _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
        if (files.isNotEmpty) ingestShared(files);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    _textSub?.cancel();
    super.dispose();
  }

  /* ─────────────── 1. Share to Unlock ─────────────── */
  String get shareBaseUrl => kShareBaseUrl;

  /// Performs the share sheet and reports whether the student completed it.
  /// Does NOT unlock anything — callers choose what to unlock.
  Future<bool> shareApp({required String message}) async {
    HapticFeedback.mediumImpact();
    try {
      final result = await Share.share(message);
      return result.status == ShareResultStatus.success;
    } catch (_) {
      return false;
    }
  }

  Future<void> unlockCamera() async {
    cameraUnlocked = true;
    await _cache.write('cameraUnlocked', true);
    notifyListeners();
  }

  Future<void> unlockDialect() async {
    dialectUnlocked = true;
    await _cache.write('dialectUnlocked', true);
    notifyListeners();
  }

  /* ─────────────── 2. Story card export ─────────────── */
  Future<void> shareStoryCard({required String caption}) async {
    HapticFeedback.mediumImpact();
    final image = await screenshot.capture(pixelRatio: 3);
    if (image == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/scholar_story_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(image);
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')], text: caption);
  }

  /* ─────────────── 3. Peer quiz challenge ─────────────── */
  Future<void> shareChallenge({required StudySession session, required String messageTemplate}) async {
    HapticFeedback.mediumImpact();
    final code = _encodeChallenge(session);
    final link = '$kShareBaseUrl/challenge/$code';
    final msg = messageTemplate.replaceAll('{link}', link).replaceAll('{title}', session.result.title);
    await Share.share(msg);
  }

  /// Compact payload the web challenge page can hydrate; also stored locally
  /// so the originating device can re-open the challenge offline.
  String _encodeChallenge(StudySession session) {
    final id = session.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').padRight(8, 'x').substring(0, 8);
    _cache.write('challenge_$id', session.toJson());
    return id.toUpperCase();
  }

  /* ─────────────── 4. PDF / document import ─────────────── */
  Future<void> ingestShared(List<SharedMediaFile> files) async {
    for (final f in files) {
      final path = f.path;
      final mime = (f.mimeType ?? '').toLowerCase();
      if (path.toLowerCase().endsWith('.pdf') || mime.contains('pdf')) {
        await extractPdf(path);
        return;
      }
      if (mime.startsWith('image/') || _isImage(path)) {
        try {
          importedImage = await File(path).readAsBytes();
          importedTarget = StudyModule.solver;
          pdfStatus = 'image';
          notifyListeners();
        } catch (_) {}
        return;
      }
      if (mime.startsWith('text/') || path.toLowerCase().endsWith('.txt')) {
        importedText = await File(path).readAsString();
        importedTarget = StudyModule.summary;
        pdfStatus = 'text';
        notifyListeners();
        return;
      }
    }
  }

  Future<String?> extractPdf(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return extractPdfBytes(bytes);
    } catch (e) {
      pdfStatus = 'error';
      notifyListeners();
      return null;
    }
  }

  Future<String?> extractPdfBytes(List<int> bytes) async {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText().trim();
      document.dispose();
      importedText = text;
      importedTarget = StudyModule.summary;
      pdfStatus = 'ok';
      notifyListeners();
      return text;
    } catch (_) {
      pdfStatus = 'error';
      notifyListeners();
      return null;
    }
  }

  void consumeImport() {
    importedText = null;
    importedImage = null;
    pdfStatus = '';
    notifyListeners();
  }

  bool _isImage(String p) => ['.png', '.jpg', '.jpeg', '.webp', '.heic'].any((e) => p.toLowerCase().endsWith(e));
}

class ViralScope extends InheritedNotifier<ViralController> {
  const ViralScope({super.key, required ViralController controller, required super.child}) : super(notifier: controller);
  static ViralController of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ViralScope>()!.notifier!;
}
