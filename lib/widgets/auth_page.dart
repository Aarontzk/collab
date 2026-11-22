import 'dart:async';

import 'package:flutter/material.dart';

import 'package:collab/widgets/common_widgets.dart';

/// Kerangka halaman akun (lupa sandi, verifikasi email, dst.):
/// ikon besar, judul, penjelasan, lalu isi. Lebarnya sama dengan Login.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.children,
    this.showBack = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: showBack),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        icon,
                        size: 40,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol "Kirim ulang" dengan jeda supaya email tidak dikirim beruntun.
class ResendButton extends StatefulWidget {
  const ResendButton({
    super.key,
    required this.onResend,
    this.cooldown = const Duration(seconds: 60),
  });

  final Future<void> Function() onResend;
  final Duration cooldown;

  @override
  State<ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<ResendButton> {
  Timer? _timer;
  late int _left = widget.cooldown.inSeconds;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _left = widget.cooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) t.cancel();
      setState(() => _left--);
    });
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await widget.onResend();
      if (!mounted) return;
      showMessage(context, 'Email dikirim ulang');
      _start();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _left > 0;
    return OutlinedButton(
      onPressed: waiting || _sending ? null : _resend,
      child: Text(waiting ? 'Kirim ulang dalam ${_left}s' : 'Kirim ulang'),
    );
  }
}

/// Daftar syarat isian, satu poin per baris di bawah field.
class RequirementList extends StatelessWidget {
  const RequirementList(this.items, {super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(item, style: style),
              ],
            ),
        ],
      ),
    );
  }
}
