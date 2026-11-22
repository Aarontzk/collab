import 'package:collab/models/group.dart';
import 'package:collab/models/home_summary.dart';
import 'package:collab/models/task.dart';
import 'package:collab/services/group_service.dart';
import 'package:collab/services/notification_service.dart';
import 'package:collab/services/supabase_service.dart';

/// Kelompok saya beserta semua tugasnya.
typedef MyWork = ({List<Group> groups, List<Task> tasks});

/// Data beranda (Kelompokku): kelompok saya dan tugas-tugasnya.
class HomeService {
  HomeService({GroupService? groups}) : _groups = groups ?? GroupService();
  final GroupService _groups;

  String get myUserId => currentUserId;

  Future<MyWork> fetchMyWork() async {
    final groups = await _groups.fetchMyGroups();
    final ids = groups.map((g) => g.id).toList();
    final rows = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : await supabase.from('tasks').select().inFilter('group_id', ids);
    return (groups: groups, tasks: rows.map(Task.fromJson).toList());
  }

  /// Jumlah rapat yang sudah dimulai per kelompok: groupId -> jumlah.
  Future<Map<String, int>> fetchMeetingCounts(List<String> groupIds) async {
    if (groupIds.isEmpty) return {};
    final rows = await supabase
        .from('meetings')
        .select('group_id')
        .inFilter('group_id', groupIds)
        .lte('starts_at', DateTime.now().toUtc().toIso8601String());
    final counts = <String, int>{};
    for (final r in rows) {
      final id = r['group_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<HomeSummary> fetchSummary() async {
    final work = await fetchMyWork();
    // Sekalian perbarui pengingat di HP; tidak ditunggu.
    NotificationService.instance.sync(
      myUserId: currentUserId,
      groups: work.groups,
      tasks: work.tasks,
    );
    return HomeSummary.compute(
      myUserId: currentUserId,
      groups: work.groups,
      tasks: work.tasks,
      now: DateTime.now(),
    );
  }
}
