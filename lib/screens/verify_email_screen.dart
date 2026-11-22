import 'package:flutter/material.dart';

import 'package:collab/services/auth_service.dart';
import 'package:collab/widgets/auth_page.dart';

/// Verifikasi email setelah daftar (A5).
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, required this.email, this.onResend});

  final String email;

  /// Bisa diganti di tes; default ke Supabase.
  final Future<void> Function(String email)? onResend;

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      icon: Icons.mark_email_unread_outlined,
      title: 'Verifikasi email kamu',
      message:
          'Kami kirim link konfirmasi ke $email. Buka link itu, lalu '
          'masuk dengan akunmu.',
      children: [
        FilledButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('Kembali ke login'),
        ),
        const SizedBox(height: 8),
        ResendButton(
          onResend: () => (onResend ?? AuthService().resendConfirmation)(email),
        ),
      ],
    );
  }
}
