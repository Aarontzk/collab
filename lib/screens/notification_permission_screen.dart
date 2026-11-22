import 'package:flutter/material.dart';

import 'package:collab/services/notification_service.dart';
import 'package:collab/widgets/auth_page.dart';

/// Ajakan mengizinkan notifikasi (N4). Ditampilkan sekali setelah login.
class NotificationPermissionScreen extends StatelessWidget {
  const NotificationPermissionScreen({super.key, this.onAllow, this.onLater});

  /// Bisa diganti di tes; default minta izin ke sistem.
  final Future<void> Function()? onAllow;
  final Future<void> Function()? onLater;

  /// Tampilkan layar izin kalau belum pernah ditanya dan izin belum aktif.
  static Future<void> maybeShow(BuildContext context) async {
    final service = NotificationService.instance;
    if (await service.store.wasPermissionAsked()) return;
    if (await service.isEnabled()) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const NotificationPermissionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = NotificationService.instance;
    return AuthPage(
      icon: Icons.notifications_outlined,
      title: 'Jangan sampai telat deadline',
      message:
          'Izinkan notifikasi supaya Collab bisa mengingatkan deadline tugasmu '
          'dan mengabari saat tugasmu disetujui atau ditolak.',
      showBack: false,
      children: [
        FilledButton(
          onPressed: () async {
            await (onAllow ?? service.requestPermission)();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Izinkan notifikasi'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () async {
            await (onLater ?? service.store.markPermissionAsked)();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Nanti saja'),
        ),
      ],
    );
  }
}
