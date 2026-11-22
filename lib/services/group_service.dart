import 'package:collab/services/supabase_service.dart';
import 'package:collab/models/group.dart';

class GroupService {
  Future<List<Group>> fetchMyGroups() async {
    final rows = await supabase
        .from('group_members')
        .select('role, groups(*)')
        .eq('user_id', currentUserId)
        .order('joined_at', ascending: false);
    return rows.map(Group.fromMembershipJson).toList();
  }

  Future<Group> createGroup({required String name, String? courseName}) async {
    final row = await supabase.rpc(
      'create_group',
      params: {'p_name': name.trim(), 'p_course': courseName?.trim()},
    );
    return Group.fromJson(row as Map<String, dynamic>, MemberRole.leader);
  }

  /// Mengembalikan id kelompok yang diikuti.
  Future<String> joinGroup(String code) async {
    final id = await supabase.rpc(
      'join_group',
      params: {'p_code': code.trim().toUpperCase()},
    );
    return id as String;
  }

  Future<List<Member>> fetchMembers(String groupId) async {
    final rows = await supabase
        .from('group_members')
        .select('user_id, role, profiles(full_name, avatar_url, nrp)')
        .eq('group_id', groupId)
        .order('joined_at');
    return rows.map(Member.fromJson).toList();
  }

  /// Hanya ketua (RLS `groups_update`). Kalau bukan ketua, tidak ada baris
  /// yang kembali dan `.single()` melempar error.
  Future<Group> updateGroup(
    Group group, {
    required String name,
    String? courseName,
  }) async {
    final course = courseName?.trim();
    final row = await supabase
        .from('groups')
        .update({
          'name': name.trim(),
          'course_name': course == null || course.isEmpty ? null : course,
        })
        .eq('id', group.id)
        .select()
        .single();
    return Group.fromJson(row, group.myRole);
  }

  /// Hanya ketua (RLS `groups_delete`). Tugas, rapat, dan review ikut
  /// terhapus lewat `on delete cascade`.
  Future<void> deleteGroup(String groupId) async {
    final rows = await supabase
        .from('groups')
        .delete()
        .eq('id', groupId)
        .select('id');
    if (rows.isEmpty) {
      throw StateError('Hanya ketua yang bisa menghapus kelompok');
    }
  }

  Future<void> leaveGroup(String groupId) async {
    await supabase
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', currentUserId);
  }
}
