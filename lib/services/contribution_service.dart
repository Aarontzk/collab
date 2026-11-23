import 'package:collab/models/contribution.dart';
import 'package:collab/models/task.dart';
import 'package:collab/services/meeting_service.dart';
import 'package:collab/services/supabase_service.dart';
import 'package:collab/services/task_service.dart';

/// Semua data yang dibutuhkan halaman Kontribusi satu kelompok.
class ContributionData {
  const ContributionData({
    required this.scores,
    required this.tasks,
    required this.totalMeetings,
  });

  final List<ContributionScore> scores;
  final List<Task> tasks;
  final int totalMeetings;
}

class ContributionService {
  final _tasks = TaskService();
  final _meetings = MeetingService();

  /// Skor dari RPC `contribution_scores(gid)`, urut skor menurun.
  Future<List<ContributionScore>> fetchScores(String groupId) async {
    final rows = await supabase.rpc(
      'contribution_scores',
      params: {'gid': groupId},
    );
    if (rows is! List) return const [];
    final scores = [
      for (final row in rows)
        if (row is Map<String, dynamic>) ContributionScore.fromJson(row),
    ]..sort((a, b) => b.contributionPct.compareTo(a.contributionPct));
    return scores;
  }

  Future<ContributionData> fetchGroup(String groupId) async {
    final scoresFuture = fetchScores(groupId);
    final tasksFuture = _tasks.watchTasks(groupId).first;
    final meetingsFuture = _meetings.fetchMeetings(groupId);
    return ContributionData(
      scores: await scoresFuture,
      tasks: await tasksFuture,
      totalMeetings: (await meetingsFuture).length,
    );
  }
}
