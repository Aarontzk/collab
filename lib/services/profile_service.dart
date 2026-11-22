import 'package:collab/models/profile.dart';
import 'package:collab/services/supabase_service.dart';

class ProfileService {
  /// Email akun login (tidak disimpan di tabel profiles).
  String? get email => supabase.auth.currentUser?.email;

  Future<Profile> fetchMine() async {
    final row = await supabase
        .from('profiles')
        .select('id, full_name, nrp, avatar_url')
        .eq('id', currentUserId)
        .single();
    return Profile.fromJson(row);
  }

  /// NRP kosong disimpan sebagai null (kolomnya opsional).
  Future<Profile> updateMine({
    required String fullName,
    required String nrp,
  }) async {
    final trimmedNrp = nrp.trim();
    final row = await supabase
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'nrp': trimmedNrp.isEmpty ? null : trimmedNrp,
        })
        .eq('id', currentUserId)
        .select('id, full_name, nrp, avatar_url')
        .single();
    return Profile.fromJson(row);
  }
}
