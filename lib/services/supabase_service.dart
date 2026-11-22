import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supabase => Supabase.instance.client;

/// ID user yang sedang login. Hanya dipanggil di halaman setelah login.
String get currentUserId {
  final id = supabase.auth.currentUser?.id;
  if (id == null) throw StateError('Belum login');
  return id;
}
