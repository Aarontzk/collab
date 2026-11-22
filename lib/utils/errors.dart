import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ubah error teknis menjadi pesan yang bisa dibaca pengguna.
/// Detail error tetap dicetak ke console untuk debugging.
String friendlyError(Object error) {
  debugPrint('Collab error: $error');

  if (error is AuthException) return _authMessage(error.message);
  if (error is PostgrestException) return _databaseMessage(error);
  if (error is StorageException) return 'Gagal upload file: ${error.message}';
  // StateError dilempar service dengan pesan bahasa Indonesia.
  if (error is StateError) return error.message;
  return 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';
}

String _authMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('invalid login')) return 'Email atau password salah';
  if (lower.contains('already registered')) return 'Email sudah terdaftar';
  if (lower.contains('email not confirmed')) {
    return 'Email belum dikonfirmasi. Cek inbox kamu';
  }
  return message;
}

String _databaseMessage(PostgrestException error) {
  // 42501 = ditolak RLS.
  if (error.code == '42501') return 'Kamu tidak punya akses untuk aksi ini';
  // P0001 = `raise exception` dari fungsi SQL, pesannya sudah bahasa Indonesia.
  if (error.code == 'P0001') return error.message;
  if (error.code == '23505') return 'Data ini sudah ada';
  return 'Gagal memproses data. Coba lagi.';
}
