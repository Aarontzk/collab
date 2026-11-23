import 'package:flutter/material.dart';

import 'package:collab/models/group.dart';
import 'package:collab/models/task.dart';
import 'package:collab/screens/task_detail_screen.dart';
import 'package:collab/screens/task_form_screen.dart';
import 'package:collab/services/meeting_service.dart';
import 'package:collab/services/supabase_service.dart';
import 'package:collab/services/task_service.dart';
import 'package:collab/utils/dates.dart';
import 'package:collab/utils/errors.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/collab_ui.dart';
import 'package:collab/widgets/common_widgets.dart';

/// Filter papan tugas (Figma Aludra T1–T3).
enum TaskFilter {
  all('Semua'),
  mine('Tugasku'),
  toValidate('Perlu Validasi');

  const TaskFilter(this.label);
  final String label;
}

/// Tab Tugas: ringkasan kelompok (Figma Farel F6) + papan tugas (Aludra T1).
class TaskBoardScreen extends StatefulWidget {
  const TaskBoardScreen({
    super.key,
    required this.group,
    required this.members,
  });
  final Group group;
  final List<Member> members;

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen> {
  final _repo = TaskService();
  late final Stream<List<Task>> _tasks = _repo.watchTasks(widget.group.id);
  late final Future<List<Meeting>> _meetings = MeetingService()
      .fetchMeetings(widget.group.id)
      .catchError((_) => <Meeting>[]);
  TaskFilter _filter = TaskFilter.all;

  void _open(Task task) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TaskDetailScreen(
        taskId: task.id,
        group: widget.group,
        members: widget.members,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.group.myRole.isStudent
          ? FloatingActionButton(
              tooltip: 'Tambah Tugas',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaskFormScreen(
                    group: widget.group,
                    members: widget.members,
                  ),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<Task>>(
        stream: _tasks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MessageView(
              icon: Icons.error_outline,
              message: friendlyError(snapshot.error!),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _board(snapshot.data!);
        },
      ),
    );
  }

  Widget _board(List<Task> all) {
    final me = currentUserId;
    final visible = filterTasks(all, _filter, me);
    return TabPageList(
      children: [
        _Summary(group: widget.group, tasks: all),
        const SizedBox(height: 12),
        _Stats(tasks: all, myUserId: me, meetings: _meetings),
        TabSection(
          title: 'Tugas Kelompok',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextTabs<TaskFilter>(
                items: [for (final f in TaskFilter.values) (f, f.label)],
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    switch (_filter) {
                      TaskFilter.all => 'Belum ada tugas.',
                      TaskFilter.mine => 'Belum ada tugas untukmu.',
                      TaskFilter.toValidate =>
                        'Tidak ada tugas yang perlu divalidasi.',
                    },
                    textAlign: TextAlign.center,
                    style: CText.meta,
                  ),
                )
              else
                OutlinedList(
                  children: [
                    for (final t in visible)
                      TaskRow(
                        task: t,
                        members: widget.members,
                        onTap: () => _open(t),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fungsi murni untuk filter papan tugas, supaya mudah dites.
List<Task> filterTasks(List<Task> tasks, TaskFilter filter, String me) =>
    switch (filter) {
      TaskFilter.all => tasks,
      TaskFilter.mine => tasks.where((t) => t.assigneeId == me).toList(),
      TaskFilter.toValidate =>
        tasks
            .where(
              (t) => t.status == TaskStatus.submitted && t.assigneeId != me,
            )
            .toList(),
    };

/// Kartu ringkasan: mata kuliah, peran, progres kelompok.
class _Summary extends StatelessWidget {
  const _Summary({required this.group, required this.tasks});

  final Group group;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.status == TaskStatus.approved).length;
    final pct = tasks.isEmpty ? 0 : (done * 100 / tasks.length).round();
    return SummaryCard(
      icon: Icons.checklist,
      title: 'Tugas',
      trailing: RolePill(group.myRole),
      value: '$pct%',
      caption: '$done dari ${tasks.length} tugas disetujui',
      progress: pct / 100,
    );
  }
}

/// Carousel angka singkat: tugasku, menunggu validasi, rapat berikutnya.
class _Stats extends StatelessWidget {
  const _Stats({
    required this.tasks,
    required this.myUserId,
    required this.meetings,
  });

  final List<Task> tasks;
  final String myUserId;
  final Future<List<Meeting>> meetings;

  @override
  Widget build(BuildContext context) {
    final mine = tasks
        .where(
          (t) => t.assigneeId == myUserId && t.status != TaskStatus.approved,
        )
        .length;
    final waiting = tasks.where((t) => t.status == TaskStatus.submitted).length;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: FutureBuilder<List<Meeting>>(
        future: meetings,
        builder: (context, snapshot) {
          final now = DateTime.now();
          final next = (snapshot.data ?? const <Meeting>[])
              .where((m) => m.startsAt.isAfter(now))
              .fold<Meeting?>(
                null,
                (best, m) => best == null || m.startsAt.isBefore(best.startsAt)
                    ? m
                    : best,
              );
          // Tiga kartu sama lebar, mengisi penuh lebar layar.
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatCard(
                  icon: Icons.checklist,
                  tint: ItsColors.blueContainer,
                  value: '$mine',
                  label: 'Tugasku',
                ),
                const SizedBox(width: 8),
                _StatCard(
                  icon: Icons.check_box_outlined,
                  tint: ItsColors.blueContainer,
                  value: '$waiting',
                  label: 'Perlu Dicek',
                ),
                const SizedBox(width: 8),
                _StatCard(
                  icon: Icons.groups_outlined,
                  tint: ItsColors.blueContainer,
                  value: next == null
                      ? '–'
                      : formatDayTime(next.startsAt).split(',').first,
                  label: next == null
                      ? 'Rapat'
                      : 'Rapat ${formatTime(next.startsAt)}',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: CColors.icon),
            const SizedBox(height: 12),
            Text(value, style: CText.stat),
            const SizedBox(height: 4),
            Text(
              label,
              style: CText.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip status lama (masih dipakai detail tugas): sekarang memakai Collab/Status chip.
class TaskStatusChip extends StatelessWidget {
  const TaskStatusChip({super.key, required this.status});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) => StatusPill(status);
}
