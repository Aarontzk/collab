import 'package:collab/utils/dates.dart';
import 'package:collab/services/supabase_service.dart';

class ReceivedFeedback {
  const ReceivedFeedback({
    required this.weekStart,
    required this.score,
    this.comment,
  });

  final String weekStart;
  final int score;
  final String? comment;

  factory ReceivedFeedback.fromJson(Map<String, dynamic> json) =>
      ReceivedFeedback(
        weekStart: json['week_start'] as String,
        score: (json['score'] as num).toInt(),
        comment: json['comment'] as String?,
      );
}

/// Review yang saya berikan minggu ini.
class GivenReview {
  const GivenReview({required this.score, this.comment});
  final int score;
  final String? comment;
}

class PeerReviewService {
  /// Review yang sudah saya berikan minggu ini: revieweeId -> review.
  Future<Map<String, GivenReview>> fetchGivenThisWeek(String groupId) async {
    final rows = await supabase
        .from('peer_reviews')
        .select('reviewee_id, score, comment')
        .eq('group_id', groupId)
        .eq('reviewer_id', currentUserId)
        .eq('week_start', weekStartUtc(DateTime.now()));
    return {
      for (final r in rows)
        r['reviewee_id'] as String: GivenReview(
          score: (r['score'] as num).toInt(),
          comment: r['comment'] as String?,
        ),
    };
  }

  Future<void> submitReview({
    required String groupId,
    required String revieweeId,
    required int score,
    String? comment,
  }) async {
    if (score < 1 || score > 5) {
      throw ArgumentError.value(score, 'score', 'harus 1-5');
    }
    final trimmed = comment?.trim();
    await supabase.from('peer_reviews').insert({
      'group_id': groupId,
      'reviewee_id': revieweeId,
      'score': score,
      'comment': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    });
  }

  /// Ubah review minggu ini (review minggu lalu dikunci RLS).
  Future<void> updateReview({
    required String groupId,
    required String revieweeId,
    required int score,
    String? comment,
  }) async {
    if (score < 1 || score > 5) {
      throw ArgumentError.value(score, 'score', 'harus 1-5');
    }
    final trimmed = comment?.trim();
    final updated = await supabase
        .from('peer_reviews')
        .update({
          'score': score,
          'comment': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        })
        .eq('group_id', groupId)
        .eq('reviewer_id', currentUserId)
        .eq('reviewee_id', revieweeId)
        .eq('week_start', weekStartUtc(DateTime.now()))
        .select('id');
    if (updated.isEmpty) throw StateError('Review minggu ini tidak ditemukan');
  }

  /// Hapus review minggu ini.
  Future<void> deleteReview({
    required String groupId,
    required String revieweeId,
  }) async {
    final deleted = await supabase
        .from('peer_reviews')
        .delete()
        .eq('group_id', groupId)
        .eq('reviewer_id', currentUserId)
        .eq('reviewee_id', revieweeId)
        .eq('week_start', weekStartUtc(DateTime.now()))
        .select('id');
    if (deleted.isEmpty) throw StateError('Review minggu ini tidak ditemukan');
  }

  /// Feedback untuk saya, tanpa nama pemberi.
  Future<List<ReceivedFeedback>> fetchMyFeedback(String groupId) async {
    final rows = await supabase.rpc(
      'my_peer_feedback',
      params: {'gid': groupId},
    ) as List;
    return rows
        .cast<Map<String, dynamic>>()
        .map(ReceivedFeedback.fromJson)
        .toList();
  }
}
