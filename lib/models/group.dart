enum MemberRole {
  leader('leader', 'Ketua'),
  member('member', 'Anggota'),
  lecturer('lecturer', 'Dosen');

  const MemberRole(this.dbValue, this.label);

  final String dbValue;
  final String label;

  bool get isStudent => this != MemberRole.lecturer;

  static MemberRole fromDb(String value) => MemberRole.values.firstWhere(
    (r) => r.dbValue == value,
    orElse: () => throw FormatException('Role tidak dikenal: $value'),
  );
}

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

  /// Anggota kelompok. Kosong kalau belum dimuat (lihat [withMembers]).
  final List<Member> members;

  bool get amLeader => myRole == MemberRole.leader;

  /// Jumlah mahasiswa (tanpa dosen).
  int get studentCount => members.students.length;

  /// Nama mata kuliah, atau penanda kalau kosong.
  String get displayCourse {
    final course = courseName?.trim();
    return (course == null || course.isEmpty) ? 'Tanpa mata kuliah' : course;
  }

  Group withMembers(List<Member> members) => Group(
    id: id,
    name: name,
    courseName: courseName,
    inviteCode: inviteCode,
    lecturerCode: lecturerCode,
    myRole: myRole,
    members: members,
  );

  factory Group.fromJson(Map<String, dynamic> json, MemberRole myRole) => Group(
    id: json['id'] as String,
    name: json['name'] as String,
    courseName: json['course_name'] as String?,
    inviteCode: json['invite_code'] as String,
    lecturerCode: json['lecturer_code'] as String,
    myRole: myRole,
  );

  /// Dari query `group_members.select('role, groups(*)')`.
  factory Group.fromMembershipJson(Map<String, dynamic> json) => Group.fromJson(
    json['groups'] as Map<String, dynamic>,
    MemberRole.fromDb(json['role'] as String),
  );
}

class Member {
  const Member({
    required this.userId,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.nrp,
  });

  final String userId;
  final String fullName;
  final MemberRole role;
  final String? avatarUrl;
  final String? nrp;

  /// Dari query `group_members.select('user_id, role, profiles(full_name, avatar_url)')`.
  factory Member.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>;
    return Member(
      userId: json['user_id'] as String,
      fullName: profile['full_name'] as String,
      role: MemberRole.fromDb(json['role'] as String),
      avatarUrl: profile['avatar_url'] as String?,
      nrp: profile['nrp'] as String?,
    );
  }
}

extension MemberLookup on List<Member> {
  List<Member> get students => where((m) => m.role.isStudent).toList();

  Member? byId(String userId) {
    for (final m in this) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  String nameOf(String? userId) {
    if (userId == null) return 'Belum ada PIC';
    for (final m in this) {
      if (m.userId == userId) return m.fullName;
    }
    return 'Anggota keluar';
  }
}
