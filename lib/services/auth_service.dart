import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:collab/services/supabase_service.dart';

class AuthService {
  Stream<AuthState> get authChanges => supabase.auth.onAuthStateChange;

  Session? get currentSession => supabase.auth.currentSession;

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Login Google. Di Android pakai pemilih akun bawaan HP (nama "Collab"
  /// yang tampil, bukan domain Supabase). Di web pakai Supabase OAuth.
  /// Provider Google harus aktif di dashboard Supabase.
  Future<void> signInWithGoogle() async {
    if (_useNativeGoogle) {
      await _signInWithGoogleNative();
      return;
    }
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : _mobileRedirect,
    );
  }

  static const _mobileRedirect = 'id.collab.app://login-callback';

  /// Client ID OAuth tipe "Web application" dari Google Cloud (sama dengan
  /// yang diisi di Supabase). Dari env.json: GOOGLE_WEB_CLIENT_ID.
  static const _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static bool get _useNativeGoogle =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _googleWebClientId.isNotEmpty;

  static Future<void>? _googleInit;

  Future<void> _signInWithGoogleNative() async {
    final google = GoogleSignIn.instance;
    await (_googleInit ??= google.initialize(
      serverClientId: _googleWebClientId,
    ));
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      // User menutup pemilih akun: bukan error.
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google tidak mengirim ID token.');
    }
    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// Mengembalikan `true` kalau user perlu konfirmasi email dulu.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
    return response.session == null;
  }

  /// Kirim email berisi link untuk membuat kata sandi baru. Link membuka app
  /// lewat deep link yang sama dengan login Google, lalu Supabase memicu
  /// event `passwordRecovery` (ditangani AuthGate).
  Future<void> sendPasswordReset(String email) =>
      supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : _mobileRedirect,
      );

  Future<void> updatePassword(String password) =>
      supabase.auth.updateUser(UserAttributes(password: password));

  /// Kirim ulang email konfirmasi pendaftaran.
  Future<void> resendConfirmation(String email) => supabase.auth.resend(
    type: OtpType.signup,
    email: email.trim(),
    emailRedirectTo: kIsWeb ? null : _mobileRedirect,
  );

  Future<void> signOut() => supabase.auth.signOut();
}
