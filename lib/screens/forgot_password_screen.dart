import 'package:flutter/material.dart';

import 'package:collab/services/auth_service.dart';
import 'package:collab/utils/validators.dart';
import 'package:collab/widgets/auth_page.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/labeled_field.dart';

/// Lupa kata sandi: isi email (A2), lalu "cek email kamu" (A3).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = '', this.onSend});

  final String initialEmail;

  /// Bisa diganti di tes; default ke Supabase.
  final Future<void> Function(String email)? onSend;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  String? _sentTo;

  Future<void> _send(String email) =>
      (widget.onSend ?? AuthService().sendPasswordReset)(email);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      await _send(email);
      if (mounted) setState(() => _sentTo = email);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    if (sentTo != null) {
      return AuthPage(
        icon: Icons.mark_email_unread_outlined,
        title: 'Cek email kamu',
        message:
            'Link untuk membuat kata sandi baru sudah dikirim ke $sentTo. '
            'Buka link itu dari HP ini.',
        children: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kembali ke login'),
          ),
          const SizedBox(height: 8),
          ResendButton(onResend: () => _send(sentTo)),
        ],
      );
    }
    return AuthPage(
      icon: Icons.undo,
      title: 'Lupa kata sandi?',
      message:
          'Masukkan email akunmu. Kami kirim link untuk membuat '
          'kata sandi baru.',
      children: [
        Form(
          key: _form,
          child: LabeledField(
            label: 'Email',
            child: TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                hintText: 'nama@student.its.ac.id',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        LoadingButton(
          label: 'Kirim link',
          onPressed: _submit,
          isLoading: _loading,
        ),
      ],
    );
  }
}
