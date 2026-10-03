import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';
import '../services/viral_controller.dart';

/// Locks a premium feature behind a share-to-unlock gate.
/// Returns `true` only when the student actually completed a share.
///
/// NOTE: this dialog performs the share and returns the outcome — the caller
/// decides *which* feature to unlock, so it can gate camera, dialect, or any
/// future Remote-Config flag.
Future<bool> showShareToUnlockDialog(
  BuildContext context,
  ViralController viral, {
  String? title,
  String? body,
  String? analyticsEvent,
}) async {
  final l = context.l10n;
  final unlocked = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      title: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]),
          ),
          child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title ?? l.t('unlock_title'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
      ]),
      content: Text(body ?? l.t('unlock_body'), style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.45)),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, false),
          child: Text(l.t('unlock_later'), style: const TextStyle(color: Colors.white38)),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1), minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
          icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
          label: Text(l.t('unlock_share'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          onPressed: () async {
            HapticFeedback.mediumImpact();
            final ok = await viral.shareApp(message: '${l.t('unlock_message')} ${viral.shareBaseUrl}');
            await FirebaseService.logEvent(analyticsEvent ?? 'unlocked_via_share');
            if (dialogCtx.mounted) Navigator.pop(dialogCtx, ok);
          },
        ),
      ],
    ),
  );
  return unlocked == true;
}
