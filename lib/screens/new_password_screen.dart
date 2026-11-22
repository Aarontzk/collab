import 'package:flutter/material.dart';

import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/services/auth_service.dart';
import 'package:collab/utils/validators.dart';
import 'package:collab/widgets/auth_page.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/labeled_field.dart';

/// Buat kata sandi baru (A4). Muncul setelah user membuka link reset.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({
    super.key,
    required this.onDone,
    this.onSave,
    this.showBack = false,
  });

  final VoidCallback onDone;

  /// false saat dibuka dari link reset (tidak ada halaman sebelumnya).
  final bool showBack;

  /// Bisa diganti di tes; default ke Supabase.
  final Future<void> Function(String password)? onSave;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await (widget.onSave ?? AuthService().updatePassword)(_password.text);
      if (!mounted) return;
      showMessage(context, 'Kata sandi diperbarui');
      widget.onDone();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      tooltip: _hide ? 'Tampilkan password' : 'Sembunyikan password',
      icon: Text(_hide ? 'Lihat' : 'Tutup', style: CText.label),
      onPressed: () => setState(() => _hide = !_hide),
    );
    return AuthPage(
      icon: Icons.keyboard_outlined,
      title: 'Buat kata sandi baru',
      message: 'Pakai kata sandi yang belum pernah kamu pakai di akun ini.',
      showBack: widget.showBack,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Kata sandi baru',
                child: TextFormField(
                  controller: _password,
                  obscureText: _hide,
                  decoration: InputDecoration(suffixIcon: toggle),
                  validator: Validators.password,
                ),
              ),
              const SizedBox(height: 8),
              const RequirementList([
                'Minimal ${Validators.minPasswordLength} karakter',
              ]),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Ulangi kata sandi',
                child: TextFormField(
                  controller: _confirm,
                  obscureText: _hide,
                  validator: (v) =>
                      v == _password.text ? null : 'Kata sandi tidak sama',
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LoadingButton(
          label: 'Simpan kata sandi',
          onPressed: _submit,
          isLoading: _loading,
        ),
      ],
    );
  }
}
