/// Peran anggota di dalam kelompok, sama dengan enum `member_role` di
/// supabase/schema.sql.
enum MemberRole {
  leader('leader', 'Ketua'),
  member('member', 'Anggota'),
  lecturer('lecturer', 'Dosen');

  const MemberRole(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static MemberRole fromDb(String? value) => switch (value) {
    'leader' => MemberRole.leader,
    'lecturer' => MemberRole.lecturer,
    _ => MemberRole.member,
  };
}

/// Satu anggota kelompok (baris `group_members` + profilnya).
class Member {
  const Member({
    required this.userId,
    required this.fullName,
    this.nrp,
    this.avatarUrl,
    this.role = MemberRole.member,
  });

  final String userId;
  final String fullName;
  final String? nrp;
  final String? avatarUrl;
  final MemberRole role;

  factory Member.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return Member(
      userId: (json['user_id'] ?? profile?['id'] ?? '') as String,
      fullName: (profile?['full_name'] ?? json['full_name'] ?? 'Anggota') as String,
      nrp: profile?['nrp'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      role: MemberRole.fromDb(json['role'] as String?),
    );
  }

  String get firstName {
    final name = fullName.trim();
    if (name.isEmpty) return 'Anggota';
    return name.split(RegExp(r'\s+')).first;
  }
}

/// Satu kelompok beserta peran saya di dalamnya.
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.lecturerCode,
    required this.myRole,
    this.courseName,
    this.members = const [],
  });

  final String id;
  final String name;
  final String? courseName;
  final String inviteCode;
  final String lecturerCode;
  final MemberRole myRole;
  final List<Member> members;

  factory Group.fromJson(
    Map<String, dynamic> json, {
    required MemberRole myRole,
    List<Member> members = const [],
  }) => Group(
    id: json['id'] as String,
    name: json['name'] as String,
    courseName: json['course_name'] as String?,
    inviteCode: (json['invite_code'] ?? '') as String,
    lecturerCode: (json['lecturer_code'] ?? '') as String,
    myRole: myRole,
    members: members,
  );

  Group copyWith({List<Member>? members, MemberRole? myRole}) => Group(
    id: id,
    name: name,
    courseName: courseName,
    inviteCode: inviteCode,
    lecturerCode: lecturerCode,
    myRole: myRole ?? this.myRole,
    members: members ?? this.members,
  );

  /// Jumlah anggota mahasiswa (dosen tidak dihitung).
  int get studentCount => members
      .where((m) => m.role != MemberRole.lecturer)
      .length;

  String get displayCourse {
    final course = courseName?.trim();
    return course == null || course.isEmpty ? 'Tanpa mata kuliah' : course;
  }
}

extension MemberList on List<Member> {
  Member? byId(String? userId) {
    for (final member in this) {
      if (member.userId == userId) return member;
    }
    return null;
  }

  String nameOf(String? userId) => byId(userId)?.fullName ?? 'Tanpa PIC';

  String firstNameOf(String? userId) => byId(userId)?.firstName ?? 'Tanpa PIC';
}
