import 'package:flutter/material.dart';

import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/auth_buttons.dart';
import 'package:collab/widgets/brand_lockup.dart';
import 'package:collab/widgets/common_widgets.dart';
import 'package:collab/widgets/labeled_field.dart';
import 'package:collab/utils/validators.dart';
import 'package:collab/services/auth_service.dart';
import 'package:collab/screens/register_screen.dart';
import 'package:collab/screens/forgot_password_screen.dart';
import 'package:collab/screens/verify_email_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repo = AuthService();
  bool _loading = false;
  bool _hidePassword = true;

  /// Error dari server, ditampilkan di bawah field kata sandi (A1).
  String? _loginError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loginError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _repo.signIn(email: _email.text, password: _password.text);
      // AuthGate otomatis pindah ke halaman kelompok.
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (e.code == 'invalid_credentials' || msg.contains('invalid login')) {
        setState(() => _loginError = 'Email atau kata sandi salah');
      } else if (e.code == 'email_not_confirmed' ||
          msg.contains('email not confirmed')) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VerifyEmailScreen(email: _email.text.trim()),
          ),
        );
      } else {
        showError(context, e);
      }
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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
                      'Selamat datang\nkembali',
                      textAlign: TextAlign.center,
                      style: text.headlineLarge?.copyWith(height: 1.15),
                    ),
                    const SizedBox(height: 32),
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
                          errorText: _loginError,
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
                        onChanged: (_) {
                          if (_loginError != null) {
                            setState(() => _loginError = null);
                          }
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ForgotPasswordScreen(
                              initialEmail: _email.text.trim(),
                            ),
                          ),
                        ),
                        child: const Text('Lupa kata sandi?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LoadingButton(
                      label: 'Masuk',
                      onPressed: _submit,
                      isLoading: _loading,
                    ),
                    const SizedBox(height: 16),
                    const SocialAuthButtons(verb: 'Masuk'),
                    const SizedBox(height: 32),
                    Text(
                      'Belum punya akun?',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text('Daftar'),
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
