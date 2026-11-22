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
