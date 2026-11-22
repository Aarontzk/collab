// Dibuat oleh Gregorius Cahya Khrisna Setiaputra - 5026241122

import 'package:collab/utils/theme.dart';
import 'package:flutter/material.dart';

/// Status tugas untuk screen Detail Tugas. Nilainya sama dengan enum
/// `task_status` di supabase/schema.sql.
enum TaskDetailStatus {
  todo('Belum mulai', Color(0xFFEFF0F7)),
  inProgress('Dikerjakan', ItsColors.skyContainer),
  submitted('Menunggu validasi', ItsColors.yellowContainer),
  approved('Disetujui', ItsColors.blueContainer),
  rejected('Ditolak', Color(0xFFF9DEDC));

  const TaskDetailStatus(this.label, this.chipColor);

  final String label;

  /// Warna latar chip status (Figma: Kontri/Status chip).
  final Color chipColor;
}

/// Jenis bukti kerja. Sama dengan enum `evidence_type` di schema.sql.
enum EvidenceKind { image, file, link }

/// Satu bukti kerja (tautan, foto, atau file).
class EvidenceItem {
  const EvidenceItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.localPath,
    this.storagePath,
  });

  final EvidenceKind kind;

  /// Tautan, atau nama file.
  final String title;

  /// Baris kecil di bawah judul, mis. "1,2 MB · Foto di Storage".
  final String subtitle;

  /// Lokasi file yang baru dipilih di perangkat, sebelum diunggah ke Storage.
  final String? localPath;

  /// Path di bucket "evidences" (`{group_id}/{task_id}/{nama_file}`) untuk
  /// foto dan file yang sudah diunggah. Dipakai untuk meminta signed URL.
  final String? storagePath;
}

/// Hasil validasi satu anggota (tabel `task_validations`).
class ValidationEntry {
  const ValidationEntry({
    required this.validatorName,
    required this.approved,
    this.comment,
  });

  final String validatorName;
  final bool approved;
  final String? comment;
}

/// Data satu tugas untuk screen Detail Tugas.
///
/// Sementara berupa data contoh. Saat model Task dari Supabase sudah ada di
/// main, cukup petakan ke kelas ini (atau ganti tipe di screen).
class TaskDetailData {
  const TaskDetailData({
    required this.id,
    required this.title,
    required this.picName,
    required this.status,
    this.picId,
    this.description,
    this.weight = 2,
    this.deadline,
    this.evidences = const [],
    this.workNote = '',
    this.validations = const [],
    this.requiredApprovals = 2,
  });

  final String id;
  final String title;
  final String? description;
  final String picName;

  /// `tasks.assignee_id`, dipakai form ubah tugas untuk memilih PIC.
  final String? picId;
  final TaskDetailStatus status;

  /// 1 ringan, 2 sedang, 3 berat (sama dengan kolom `tasks.weight`).
  final int weight;
  final DateTime? deadline;
  final List<EvidenceItem> evidences;

  /// Catatan pekerjaan (opsional), disimpan ke `task_evidences.note`.
  final String workNote;
  final List<ValidationEntry> validations;

  /// Jumlah persetujuan anggota lain agar tugas dinyatakan Disetujui.
  final int requiredApprovals;

  int get approvedCount => validations.where((v) => v.approved).length;

  String get weightLabel => switch (weight) {
    1 => 'Ringan · 1 poin',
    3 => 'Berat · 3 poin',
    _ => 'Sedang · 2 poin',
  };

  TaskDetailData copyWith({
    String? title,
    String? description,
    String? picId,
    String? picName,
    int? weight,
    DateTime? deadline,
    TaskDetailStatus? status,
    List<EvidenceItem>? evidences,
    String? workNote,
    List<ValidationEntry>? validations,
  }) => TaskDetailData(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    picId: picId ?? this.picId,
    picName: picName ?? this.picName,
    status: status ?? this.status,
    weight: weight ?? this.weight,
    deadline: deadline ?? this.deadline,
    evidences: evidences ?? this.evidences,
    workNote: workNote ?? this.workNote,
    validations: validations ?? this.validations,
    requiredApprovals: requiredApprovals,
  );
}

/// Data contoh persis isi frame Figma "06 Detail tugas", untuk percobaan
/// tampilan. [now] dipakai supaya sisa waktunya selalu masuk akal.
TaskDetailData sampleTaskDetail(TaskDetailStatus status, {DateTime? now}) {
  final base = now ?? DateTime.now();
  final deadline = DateTime(
    base.year,
    base.month,
    base.day,
    23,
    59,
  ).add(Duration(days: status == TaskDetailStatus.rejected ? 1 : 3));

  const link = EvidenceItem(
    kind: EvidenceKind.link,
    title: 'github.com/Aarontzk/kontri/pull/7',
    subtitle: 'PR fitur QR · 14 Nov 2026, 20:15',
  );
  const photo = EvidenceItem(
    kind: EvidenceKind.image,
    title: 'hasil-uji-qr.png',
    subtitle: '1,2 MB · Foto di Storage',
  );
  const maria = ValidationEntry(
    validatorName: 'Maria Arum Ningtyas',
    approved: true,
    comment: 'Sudah dicoba, QR berganti tiap 30 detik.',
  );

  return TaskDetailData(
    id: 'contoh-tugas',
    title: 'Fitur absensi QR',
    description: 'QR berganti tiap 30 detik, anggota scan untuk absen rapat.',
    picId: 'aludra',
    picName: 'Aludra Nadia Salwa',
    weight: 3,
    deadline: deadline,
    status: status,
    workNote: status == TaskDetailStatus.inProgress
        ? 'Sudah diuji di emulator Android.'
        : '',
    evidences: switch (status) {
      TaskDetailStatus.todo => const [],
      TaskDetailStatus.inProgress => const [photo, link],
      _ => const [link, photo],
    },
    validations: switch (status) {
      TaskDetailStatus.submitted => const [maria],
      TaskDetailStatus.approved => const [
        maria,
        ValidationEntry(
          validatorName: 'M. Azwar Alfarezzel D.',
          approved: true,
          comment: 'Foto uji absensi & PR sudah sesuai.',
        ),
      ],
      TaskDetailStatus.rejected => const [
        ValidationEntry(
          validatorName: 'Maria Arum Ningtyas',
          approved: false,
          comment: 'QR masih statis, belum auto-refresh per 30 detik.',
        ),
      ],
      _ => const [],
    },
  );
}
