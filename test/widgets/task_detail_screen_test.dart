// Dibuat oleh Gregorius Cahya Khrisna Setiaputra - 5026241122

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab/models/task_detail_data.dart';
import 'package:collab/screens/task_detail_screen.dart';
import 'package:collab/screens/task_form_screen.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/task_dialogs.dart';

import 'task_detail_fonts.dart';

Widget _app(Widget home) => MaterialApp(theme: collabTheme, home: home);

Future<void> _show(
  WidgetTester tester,
  TaskDetailStatus status, {
  bool isPic = false,
  bool isLeader = false,
  ValueChanged<TaskDetailData>? onChanged,
  VoidCallback? onDeleted,
  Future<void> Function(TaskFormValue)? onSaveEdit,
  TaskDetailData? task,
  Future<bool> Function(Uri)? openUrl,
  Future<String> Function(String)? signedUrlFor,
}) async {
  tester.view.physicalSize = const Size(412, 917);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      TaskDetailScreen(
        task: task ?? sampleTaskDetail(status),
        openUrl: openUrl,
        signedUrlFor: signedUrlFor,
        isPic: isPic,
        isLeader: isLeader,
        onChanged: onChanged,
        onDeleted: onDeleted,
        onSaveEdit: onSaveEdit,
        members: const [
          TaskFormMember(userId: 'aludra', fullName: 'Aludra Nadia Salwa'),
          TaskFormMember(userId: 'maria', fullName: 'Maria Arum Ningtyas'),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(loadCollabFonts);

  testWidgets('belum mulai: bukti terkunci, PIC menekan Mulai kerjakan', (
    tester,
  ) async {
    TaskDetailData? last;
    await _show(
      tester,
      TaskDetailStatus.todo,
      isPic: true,
      onChanged: (t) => last = t,
    );
    expect(find.text('Terkunci'), findsOneWidget);
    expect(find.text('Belum diajukan'), findsOneWidget);
    expect(find.text('Berat · 3 poin'), findsOneWidget);

    await tester.tap(find.text('Mulai kerjakan'));
    await tester.pump();
    expect(last?.status, TaskDetailStatus.inProgress);
    expect(find.text('Ajukan validasi'), findsOneWidget);
    expect(find.text('Upload Foto/File'), findsOneWidget);
  });

  testWidgets('bukan PIC tidak melihat tombol aksi saat belum mulai', (
    tester,
  ) async {
    await _show(tester, TaskDetailStatus.todo);
    expect(find.text('Mulai kerjakan'), findsNothing);
  });

  testWidgets('dikerjakan: ajukan ditolak kalau belum ada bukti', (
    tester,
  ) async {
    TaskDetailData? last;
    await _show(
      tester,
      TaskDetailStatus.inProgress,
      isPic: true,
      onChanged: (t) => last = t,
    );
    // Hapus dua bukti contoh.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
    }
    expect(find.text('Belum ada'), findsOneWidget);

    await tester.tap(find.text('Ajukan validasi'));
    await tester.pump();
    expect(find.textContaining('minimal satu bukti'), findsOneWidget);
    expect(last?.status, TaskDetailStatus.inProgress);
  });

  testWidgets('dikerjakan: ajukan validasi mengirim tugas', (tester) async {
    TaskDetailData? last;
    await _show(
      tester,
      TaskDetailStatus.inProgress,
      isPic: true,
      onChanged: (t) => last = t,
    );
    await tester.tap(find.text('Ajukan validasi'));
    await tester.pump();
    expect(last?.status, TaskDetailStatus.submitted);
    expect(last?.workNote, 'Sudah diuji di emulator Android.');
    expect(find.text('Menunggu validasi'), findsOneWidget);
  });

  testWidgets('menunggu validasi: setujui kedua selesai, tugas Disetujui', (
    tester,
  ) async {
    TaskDetailData? last;
    await _show(tester, TaskDetailStatus.submitted, onChanged: (t) => last = t);
    expect(find.text('1 / 2 setuju'), findsOneWidget);

    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    expect(find.text('Setujui tugas?'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      ' Sudah dicoba ',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(FilledButton, 'Setujui'),
      ),
    );
    await tester.pumpAndSettle();

    expect(last?.status, TaskDetailStatus.approved);
    expect(last?.validations.last.comment, 'Sudah dicoba');
    expect(find.text('2 / 2 setuju'), findsOneWidget);
    expect(
      find.text('Tugas selesai · dihitung ke skor kontribusi'),
      findsOneWidget,
    );
  });

  testWidgets('setujui: komentar boleh kosong, Batal tidak menyetujui', (
    tester,
  ) async {
    TaskDetailData? last;
    await _show(tester, TaskDetailStatus.submitted, onChanged: (t) => last = t);
    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(last, isNull);

    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(FilledButton, 'Setujui'),
      ),
    );
    await tester.pumpAndSettle();
    expect(last?.validations.last.approved, isTrue);
    expect(last?.validations.last.comment, isNull);
  });

  testWidgets('PIC tidak boleh menyetujui tugasnya sendiri', (tester) async {
    await _show(tester, TaskDetailStatus.submitted, isPic: true);
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
  });

  testWidgets('tolak tugas: alasan wajib, lalu status Ditolak', (tester) async {
    TaskDetailData? last;
    await _show(tester, TaskDetailStatus.submitted, onChanged: (t) => last = t);
    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    expect(find.text('Tolak tugas?'), findsOneWidget);
    expect(find.textContaining('agar Aludra Nadia Salwa tahu'), findsOneWidget);

    FilledButton rejectButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tolak tugas'),
    );
    expect(rejectButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(rejectButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), ' QR masih statis ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Tolak tugas'));
    await tester.pumpAndSettle();

    expect(last?.status, TaskDetailStatus.rejected);
    expect(last?.validations.last.comment, 'QR masih statis');
    expect(find.text('Perlu revisi'), findsOneWidget);
  });

  testWidgets('tolak tugas: Batal tidak mengubah apa pun', (tester) async {
    TaskDetailData? last;
    await _show(tester, TaskDetailStatus.submitted, onChanged: (t) => last = t);
    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(last, isNull);
    expect(find.text('Tolak tugas?'), findsNothing);
  });

  testWidgets('ditolak: PIC langsung bisa mengganti bukti lalu kirim ulang', (
    tester,
  ) async {
    TaskDetailData? last;
    await _show(
      tester,
      TaskDetailStatus.rejected,
      isPic: true,
      onChanged: (t) => last = t,
    );
    // Sama dengan Dikerjakan: tombol bukti langsung tampil, tanpa "Perbarui".
    expect(find.text('Perbarui'), findsNothing);
    expect(find.text('Upload Foto/File'), findsOneWidget);
    expect(find.text('Tempel Tautan'), findsOneWidget);
    expect(find.text('2 lampiran'), findsOneWidget);

    // Ganti bukti: hapus satu, bukti sisanya ikut terkirim.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(last?.evidences.length, 1);

    await tester.tap(find.text('Kirim ulang validasi'));
    await tester.pump();
    expect(last?.status, TaskDetailStatus.submitted);
    expect(last?.validations, isEmpty);
    expect(last?.evidences.length, 1);
  });

  testWidgets('ditolak: anggota lain tidak melihat tombol bukti', (
    tester,
  ) async {
    await _show(tester, TaskDetailStatus.rejected);
    expect(find.text('Upload Foto/File'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('tambah bukti: sheet menampilkan tiga sumber dan Tutup', (
    tester,
  ) async {
    await _show(tester, TaskDetailStatus.inProgress, isPic: true);
    await tester.tap(find.text('Upload Foto/File'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah bukti kerja'), findsOneWidget);
    expect(find.text('Ambil Foto / Pilih dari Galeri'), findsOneWidget);
    expect(find.text('Upload File Dokumen'), findsOneWidget);
    expect(find.text('Tempel Tautan URL'), findsOneWidget);

    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah bukti kerja'), findsNothing);
  });

  testWidgets('tempel tautan: hanya http(s) yang diterima', (tester) async {
    TaskDetailData? last;
    await _show(
      tester,
      TaskDetailStatus.inProgress,
      isPic: true,
      onChanged: (t) => last = t,
    );
    await tester.tap(find.text('Tempel Tautan'));
    await tester.pumpAndSettle();

    FilledButton addButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tambah'),
    );
    // Ada juga kolom catatan di balik dialog, jadi cari di dalam dialog saja.
    final urlField = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(urlField, 'bukan url');
    await tester.pump();
    expect(addButton().onPressed, isNull);

    await tester.enterText(urlField, 'https://figma.com/design/x');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
    await tester.pumpAndSettle();

    expect(last?.evidences.length, 3);
    expect(last?.evidences.last.kind, EvidenceKind.link);
    expect(find.text('figma.com/design/x'), findsOneWidget);
  });

  testWidgets('ketua: ikon ubah dan hapus, hapus butuh konfirmasi', (
    tester,
  ) async {
    var deleted = false;
    await _show(
      tester,
      TaskDetailStatus.approved,
      isLeader: true,
      onDeleted: () => deleted = true,
    );
    expect(find.byTooltip('Ubah tugas'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus tugas'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus tugas?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
  });

  testWidgets('anggota biasa tidak melihat ikon ubah dan hapus', (
    tester,
  ) async {
    await _show(tester, TaskDetailStatus.submitted);
    expect(find.byTooltip('Ubah tugas'), findsNothing);
    expect(find.byTooltip('Hapus tugas'), findsNothing);
  });

  testWidgets('ketua: ubah tugas membuka form berisi data lalu memperbarui', (
    tester,
  ) async {
    TaskFormValue? saved;
    await _show(
      tester,
      TaskDetailStatus.submitted,
      isLeader: true,
      onSaveEdit: (v) async => saved = v,
    );
    await tester.tap(find.byTooltip('Ubah tugas'));
    await tester.pumpAndSettle();

    // Form terbuka dalam mode ubah dan terisi data tugas.
    expect(find.text('Ubah tugas'), findsWidgets);
    final title = find.widgetWithText(TextFormField, 'Fitur absensi QR');
    expect(title, findsOneWidget);

    await tester.enterText(title, 'Fitur absensi QR v2');
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(saved?.title, 'Fitur absensi QR v2');
    expect(saved?.assigneeId, 'aludra');
    expect(saved?.weight, 3);
    // Kembali ke detail, judul ikut berubah.
    expect(find.text('Fitur absensi QR v2'), findsOneWidget);
    expect(find.text('Detail tugas'), findsOneWidget);
  });

  group('buka bukti', () {
    TaskDetailData withEvidence(List<EvidenceItem> items) =>
        sampleTaskDetail(TaskDetailStatus.submitted).copyWith(evidences: items);

    testWidgets('tautan dibuka di browser', (tester) async {
      final opened = <Uri>[];
      await _show(
        tester,
        TaskDetailStatus.submitted,
        openUrl: (u) async {
          opened.add(u);
          return true;
        },
      );
      await tester.tap(find.text('github.com/Aarontzk/kontri/pull/7'));
      await tester.pump();
      expect(
        opened.single.toString(),
        'https://github.com/Aarontzk/kontri/pull/7',
      );
    });

    testWidgets('tautan bukan http/https ditolak', (tester) async {
      final opened = <Uri>[];
      await _show(
        tester,
        TaskDetailStatus.submitted,
        task: withEvidence(const [
          EvidenceItem(
            kind: EvidenceKind.link,
            title: 'file.txt',
            subtitle: 'Tautan',
            localPath: 'file:///etc/passwd',
          ),
        ]),
        openUrl: (u) async {
          opened.add(u);
          return true;
        },
      );
      await tester.tap(find.text('file.txt'));
      await tester.pump();
      expect(opened, isEmpty);
      expect(find.textContaining('Hanya tautan http/https'), findsOneWidget);
    });

    testWidgets('file di Storage dibuka lewat signed URL', (tester) async {
      final opened = <Uri>[];
      final asked = <String>[];
      await _show(
        tester,
        TaskDetailStatus.submitted,
        task: withEvidence(const [
          EvidenceItem(
            kind: EvidenceKind.file,
            title: 'laporan.pdf',
            subtitle: '2,0 MB · File di Storage',
            storagePath: 'g1/t1/laporan.pdf',
          ),
        ]),
        signedUrlFor: (path) async {
          asked.add(path);
          return 'https://example.supabase.co/signed/laporan.pdf?token=x';
        },
        openUrl: (u) async {
          opened.add(u);
          return true;
        },
      );
      await tester.tap(find.text('laporan.pdf'));
      await tester.pump();
      expect(asked, ['g1/t1/laporan.pdf']);
      expect(opened.single.host, 'example.supabase.co');
    });

    testWidgets('foto di Storage dipratinjau di dialog', (tester) async {
      await _show(
        tester,
        TaskDetailStatus.submitted,
        task: withEvidence(const [
          EvidenceItem(
            kind: EvidenceKind.image,
            title: 'hasil-uji-qr.png',
            subtitle: '1,2 MB · Foto di Storage',
            storagePath: 'g1/t1/hasil-uji-qr.png',
          ),
        ]),
        signedUrlFor: (path) async => 'https://example.invalid/x.png',
      );
      await tester.tap(find.text('hasil-uji-qr.png'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('bukti tanpa sumber memberi tahu belum bisa dibuka', (
      tester,
    ) async {
      await _show(tester, TaskDetailStatus.submitted);
      await tester.tap(find.text('hasil-uji-qr.png'));
      await tester.pump();
      expect(find.textContaining('belum bisa dibuka'), findsOneWidget);
    });
  });

  group('aksi tidak dobel', () {
    testWidgets('tekan Upload dua kali cepat hanya membuka satu sheet', (
      tester,
    ) async {
      await _show(tester, TaskDetailStatus.inProgress, isPic: true);
      await tester.tap(find.text('Upload Foto/File'));
      await tester.tap(find.text('Upload Foto/File'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Tambah bukti kerja'), findsOneWidget);
    });

    testWidgets('tombol bawah nonaktif selama sheet terbuka', (tester) async {
      await _show(tester, TaskDetailStatus.inProgress, isPic: true);
      await tester.tap(find.text('Upload Foto/File'));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ajukan validasi'),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      final after = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ajukan validasi'),
      );
      expect(after.onPressed, isNotNull);
    });

    testWidgets('ikon hapus bukti cukup besar untuk disentuh', (tester) async {
      await _show(tester, TaskDetailStatus.inProgress, isPic: true);
      final size = tester.getSize(find.byTooltip('Hapus bukti').first);
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(40));
    });
  });

  group('pilihan sumber foto', () {
    Future<PhotoSource?> pick(WidgetTester tester, String label) async {
      PhotoSource? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showPhotoSourceSheet(context),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.text('Ambil foto bukti'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Ambil Foto memilih kamera', (tester) async {
      expect(await pick(tester, 'Ambil Foto'), PhotoSource.camera);
    });

    testWidgets('Pilih dari Galeri memilih galeri', (tester) async {
      expect(await pick(tester, 'Pilih dari Galeri'), PhotoSource.gallery);
    });
  });
}
