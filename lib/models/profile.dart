/// Satu baris tabel `profiles` (lihat supabase/schema.sql).
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    this.nrp,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String? nrp;
  final String? avatarUrl;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    nrp: json['nrp'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );
}
