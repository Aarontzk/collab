import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:collab/screens/groups_screen.dart';
import 'package:collab/screens/new_password_screen.dart';
import 'package:collab/services/auth_service.dart';
import 'package:collab/screens/login_screen.dart';

/// Menampilkan halaman login atau daftar kelompok sesuai status login.
/// Kalau app dibuka dari link "lupa kata sandi", tampilkan form kata sandi baru.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _repo = AuthService();
  late final StreamSubscription<AuthState> _sub;
  late Session? _session = _repo.currentSession;
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    _sub = _repo.authChanges.listen((state) {
      if (!mounted) return;
      setState(() {
        _session = state.session;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _recovering = true;
        } else if (state.event == AuthChangeEvent.signedOut) {
          _recovering = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return const LoginScreen();
    if (_recovering) {
      return NewPasswordScreen(
        onDone: () => setState(() => _recovering = false),
      );
    }
    return const GroupsScreen();
  }
}
