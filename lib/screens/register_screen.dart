import 'package:flutter/material.dart';

import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/auth_buttons.dart';
import 'package:collab/widgets/brand_lockup.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/labeled_field.dart';
import 'package:collab/utils/validators.dart';
import 'package:collab/services/auth_service.dart';
import 'package:collab/screens/verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repo = AuthService();
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final needsConfirmation = await _repo.signUp(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      if (needsConfirmation) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => VerifyEmailScreen(email: _email.text.trim()),
          ),
        );
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandLockup()),
                    const SizedBox(height: 24),
                    Text(
                      'Buat akun\nbaru',
                      textAlign: TextAlign.center,
                      style: text.headlineLarge?.copyWith(height: 1.15),
                    ),
                    const SizedBox(height: 32),
                    LabeledField(
                      label: 'Nama lengkap',
                      child: TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => Validators.requiredText(v, max: 100),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LabeledField(
                      label: 'Email',
                      child: TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          hintText: 'nama@student.its.ac.id',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LabeledField(
                      label: 'Password',
                      child: TextFormField(
                        controller: _password,
                        decoration: InputDecoration(
                          helperText: 'Minimal 8 karakter',
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Tampilkan password'
                                : 'Sembunyikan password',
                            icon: Text(
                              _hidePassword ? 'Lihat' : 'Tutup',
                              style: CText.label,
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        obscureText: _hidePassword,
                        validator: Validators.password,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    LoadingButton(
                      label: 'Daftar',
                      onPressed: _submit,
                      isLoading: _loading,
                    ),
                    const SizedBox(height: 16),
                    const SocialAuthButtons(verb: 'Daftar'),
                    const SizedBox(height: 32),
                    Text(
                      'Sudah punya akun?',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Masuk'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
