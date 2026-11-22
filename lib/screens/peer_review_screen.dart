import 'package:flutter/material.dart';

// ============================================================
// Collab - Kelompok 15 Tekber
// Peer Review & Beri Nilai (semua dalam satu file)
// ============================================================

const _navy = Color(0xFF1F3A82);
const _lightBlue = Color(0xFFD3EAF7);
const _chipBlue = _lightBlue;
const _bg = Color(0xFFF7F8FC);
const _star = Color(0xFFFFB800);

// ------------------------- MODELS -------------------------
/// Model data untuk fitur Peer Review (Collab - Kelompok 15 Tekber).

class TeamMember {
  final String id;
  final String name;

  /// Opsional: URL / path avatar. Jika null, dipakai inisial nama.
  final String? avatarUrl;

  /// Rating (1-5) yang sudah kamu berikan minggu ini. null = belum dinilai.
  final int? myRating;

  const TeamMember({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.myRating,
  });

  bool get isReviewed => myRating != null;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  TeamMember copyWith({int? myRating}) => TeamMember(
        id: id,
        name: name,
        avatarUrl: avatarUrl,
        myRating: myRating ?? this.myRating,
      );
}

/// Hasil yang dikembalikan oleh bottom sheet "Nilai teman".
class ReviewResult {
  final int rating;
  final Set<String> highlights;
  final String comment;

  const ReviewResult({
    required this.rating,
    required this.highlights,
    required this.comment,
  });
}

/// Feedback anonim yang diterima user dari teman.
class FeedbackItem {
  final int rating;
  final String comment;

  const FeedbackItem({required this.rating, required this.comment});
}

// --------------------- BOTTOM SHEET ----------------------



/// Menampilkan bottom sheet "Nilai <nama>" dan mengembalikan [ReviewResult]
/// saat user menekan "Kirim penilaian" (null jika dibatalkan).
Future<ReviewResult?> showRateMemberSheet(
  BuildContext context, {
  required TeamMember member,
  required int weekNumber,
}) {
  return showModalBottomSheet<ReviewResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => RateMemberSheet(member: member, weekNumber: weekNumber),
  );
}

class RateMemberSheet extends StatefulWidget {
  final TeamMember member;
  final int weekNumber;

  const RateMemberSheet({
    super.key,
    required this.member,
    required this.weekNumber,
  });

  @override
  State<RateMemberSheet> createState() => _RateMemberSheetState();
}

class _RateMemberSheetState extends State<RateMemberSheet> {
  static const _highlightOptions = [
    'Tepat waktu',
    'Komunikatif',
    'Kualitas kerja',
    'Aktif di rapat',
  ];

  static const _ratingLabels = {
    1: 'Sangat kurang',
    2: 'Kurang',
    3: 'Cukup',
    4: 'Baik',
    5: 'Sangat baik',
  };

  int _rating = 0;
  final Set<String> _highlights = {};
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      ReviewResult(
        rating: _rating,
        highlights: _highlights,
        comment: _commentController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + nama
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF8EC5F0),
                  backgroundImage: widget.member.avatarUrl != null
                      ? NetworkImage(widget.member.avatarUrl!)
                      : null,
                  child: widget.member.avatarUrl == null
                      ? Text(widget.member.initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nilai ${widget.member.name}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Review minggu ke-${widget.weekNumber} · anonim',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bintang
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final filled = i < _rating;
                      return IconButton(
                        onPressed: () => setState(() => _rating = i + 1),
                        iconSize: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          filled ? Icons.star_rounded : Icons.star_border_rounded,
                          color: filled
                              ? const Color(0xFFFFB800)
                              : Colors.grey.shade400,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _rating == 0 ? 'Ketuk bintang untuk menilai' : _ratingLabels[_rating]!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _rating == 0 ? Colors.grey.shade600 : _navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Yang menonjol
            const Text('Yang menonjol (opsional)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: _highlightOptions.map((label) {
                final selected = _highlights.contains(label);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  showCheckmark: true,
                  selectedColor: _chipBlue,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected ? _chipBlue : Colors.grey.shade400,
                  ),
                  shape: const StadiumBorder(),
                  labelStyle: TextStyle(
                    color: selected ? _navy : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  onSelected: (v) => setState(() {
                    v ? _highlights.add(label) : _highlights.remove(label);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Komentar
            TextField(
              controller: _commentController,
              maxLines: 3,
              minLines: 2,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Komentar (opsional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _navy, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tombol aksi
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: _navy,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _rating == 0 ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: _navy,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Kirim penilaian'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------ SCREEN -------------------------



/// Screen Peer Review & Beri Nilai — Collab (Kelompok 15 Tekber).
class PeerReviewScreen extends StatefulWidget {
  const PeerReviewScreen({super.key});

  @override
  State<PeerReviewScreen> createState() => _PeerReviewScreenState();
}

class _PeerReviewScreenState extends State<PeerReviewScreen> {
  static const int _currentWeek = 12;

  // TODO: ganti dengan data dari backend (Supabase / Firebase, dsb).
  List<TeamMember> _members = const [
    TeamMember(id: '1', name: 'Muhammad Azka Bilfaqih', myRating: 4),
    TeamMember(id: '2', name: 'Aludra Nadia Salwa', myRating: 5),
    TeamMember(id: '3', name: 'Ahmad Maulana Al Farel R.'),
    TeamMember(id: '4', name: 'Gregorius Cahya K. S.'),
    TeamMember(id: '5', name: 'M. Azwar Alfarezzel D.'),
    TeamMember(id: '6', name: 'Maria Arum Ningtyas'),
  ];

  final Map<int, List<FeedbackItem>> _feedbackByWeek = const {
    11: [
      FeedbackItem(rating: 4, comment: 'Database rapi dan RLS-nya jelas. Mantap.'),
      FeedbackItem(rating: 5, comment: 'Responsif dan selalu bantu kalau ada kendala.'),
    ],
    10: [
      FeedbackItem(rating: 4, comment: 'Progress stabil tiap minggu.'),
    ],
  };

  int _selectedWeek = 11;
  int _navIndex = 2; // Tab "Review"

  int get _reviewedCount => _members.where((m) => m.isReviewed).length;

  Future<void> _rate(TeamMember member) async {
    final result = await showRateMemberSheet(
      context,
      member: member,
      weekNumber: _currentWeek,
    );
    if (result == null || !mounted) return;

    setState(() {
      _members = [
        for (final m in _members)
          m.id == member.id ? m.copyWith(myRating: result.rating) : m,
      ];
    });

    // TODO: kirim result (rating, highlights, comment) ke backend.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Penilaian untuk ${member.name} terkirim')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedbacks = _feedbackByWeek[_selectedWeek] ?? const [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Kelompok 15 Tekber',
          style: TextStyle(
              color: _navy, fontSize: 26, fontWeight: FontWeight.w800),
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: _navy, size: 28),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Tentang Peer Review'),
                  content: const Text(
                    'Penilaianmu bersifat anonim. Teman hanya melihat bintang dan komentar.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SummaryCard(
            week: _currentWeek,
            reviewed: _reviewedCount,
            total: _members.length,
          ),
          const SizedBox(height: 24),
          const Text('Beri nilai teman',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._members.expand((m) => [
                _MemberTile(member: m, onRate: () => _rate(m)),
                if (m != _members.last)
                  Divider(height: 1, color: Colors.grey.shade300),
              ]),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: Text('Feedback untukmu',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              _WeekDropdown(
                value: _selectedWeek,
                weeks: _feedbackByWeek.keys.toList()..sort((a, b) => b - a),
                onChanged: (w) => setState(() => _selectedWeek = w),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (feedbacks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Belum ada feedback untuk minggu ini',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            )
          else
            ...feedbacks.map((f) => _FeedbackCard(item: f)),
        ],
      ),
      // Catatan: kalau bottom nav sudah ada di shell/main screen
      // kelompokmu, hapus bagian ini dan pakai nav yang sama.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        backgroundColor: const Color(0xFFF0F1FA),
        indicatorColor: _lightBlue,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.checklist_rounded), label: 'Tugas'),
          NavigationDestination(
              icon: Icon(Icons.groups_rounded), label: 'Rapat'),
          NavigationDestination(
              icon: Icon(Icons.rate_review_outlined),
              selectedIcon: Icon(Icons.rate_review),
              label: 'Review'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded), label: 'Kontribusi'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Komponen-komponen
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final int week;
  final int reviewed;
  final int total;

  const _SummaryCard({
    required this.week,
    required this.reviewed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE3FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.star_rounded, color: _navy, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Review minggu ke-$week',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3B0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Tutup Min, 23.59',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5C4A00))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('$reviewed/$total',
                  style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: _navy)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('teman sudah kamu nilai',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : reviewed / total,
                        minHeight: 12,
                        backgroundColor: const Color(0xFFDDE3FA),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_navy),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.vpn_key_rounded, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Penilaianmu anonim. Teman hanya melihat bintang dan komentar.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final TeamMember member;
  final VoidCallback onRate;

  const _MemberTile({required this.member, required this.onRate});

  static const _avatarColors = [
    Color(0xFFE5524A),
    Color(0xFFF2B93B),
    Color(0xFF5B9BD5),
    Color(0xFF7E57C2),
    Color(0xFF26A69A),
    Color(0xFFEF8F5B),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[member.name.hashCode.abs() % _avatarColors.length];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color,
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Text(member.initials,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (member.isReviewed)
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < member.myRating!
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 20,
                        color: i < member.myRating!
                            ? _star
                            : Colors.grey.shade400,
                      ),
                    ),
                  )
                else
                  Text('Belum dinilai',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (member.isReviewed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEDEDF5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 18),
                  SizedBox(width: 6),
                  Text('Sudah',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
            )
          else
            FilledButton(
              onPressed: onRate,
              style: FilledButton.styleFrom(
                backgroundColor: _lightBlue,
                foregroundColor: const Color(0xFF0B4F6C),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('Beri nilai'),
            ),
        ],
      ),
    );
  }
}

class _WeekDropdown extends StatelessWidget {
  final int value;
  final List<int> weeks;
  final ValueChanged<int> onChanged;

  const _WeekDropdown({
    required this.value,
    required this.weeks,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          borderRadius: BorderRadius.circular(16),
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          items: weeks
              .map((w) => DropdownMenuItem(value: w, child: Text('Minggu $w')))
              .toList(),
          onChanged: (w) {
            if (w != null) onChanged(w);
          },
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackItem item;

  const _FeedbackCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < item.rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 22,
                  color: i < item.rating ? _star : Colors.grey.shade400,
                ),
              ),
              const Spacer(),
              Text('Anonim',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.comment, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}