import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/models/profile.dart';
import 'package:collab/screens/forgot_password_screen.dart';
import 'package:collab/screens/new_password_screen.dart';
import 'package:collab/screens/settings_screen.dart';
import 'package:collab/screens/verify_email_screen.dart';
import 'package:collab/utils/theme.dart';

Widget _app(Widget home) => MaterialApp(theme: collabTheme, home: home);

void main() {
  testWidgets('lupa sandi: kirim email lalu tampil "Cek email kamu"', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(
      _app(ForgotPasswordScreen(onSend: (e) async => sent.add(e))),
    );
    await tester.tap(find.text('Kirim link'));
    await tester.pump();
    expect(find.text('Email wajib diisi'), findsOneWidget);
    expect(sent, isEmpty);

    await tester.enterText(find.byType(TextFormField), ' azka@its.ac.id ');
    await tester.tap(find.text('Kirim link'));
    await tester.pump();
    expect(sent, ['azka@its.ac.id']);
    expect(find.text('Cek email kamu'), findsOneWidget);
    expect(find.text('Kirim ulang dalam 60s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.text('Kirim ulang'));
    await tester.pump();
    expect(sent, ['azka@its.ac.id', 'azka@its.ac.id']);
  });

  testWidgets('sandi baru: harus sama dan minimal 8 karakter', (tester) async {
    final saved = <String>[];
    var done = false;
    await tester.pumpWidget(
      _app(
        NewPasswordScreen(
          onSave: (p) async => saved.add(p),
          onDone: () => done = true,
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'rahasia123');
    await tester.enterText(fields.last, 'rahasia124');
    await tester.tap(find.text('Simpan kata sandi'));
    await tester.pump();
    expect(find.text('Kata sandi tidak sama'), findsOneWidget);
    expect(saved, isEmpty);

    await tester.enterText(fields.last, 'rahasia123');
    await tester.ensureVisible(find.text('Simpan kata sandi'));
    await tester.pump();
    await tester.tap(find.text('Simpan kata sandi'));
    await tester.pump();
    expect(saved, ['rahasia123']);
    expect(done, isTrue);
  });

  testWidgets('verifikasi email menampilkan alamat email', (tester) async {
    await tester.pumpWidget(
      _app(VerifyEmailScreen(email: 'azka@its.ac.id', onResend: (_) async {})),
    );
    expect(find.textContaining('azka@its.ac.id'), findsOneWidget);
    expect(find.text('Kembali ke login'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
  });

  group('pengaturan', () {
    const me = Profile(id: 'u1', fullName: 'Azka');

    Future<void> pump(WidgetTester tester, {VoidCallback? onSignOut}) =>
        tester.pumpWidget(
          _app(
            Scaffold(
              body: SettingsView(
                profile: me,
                email: 'azka@its.ac.id',
                onSignOut: onSignOut ?? () {},
              ),
            ),
          ),
        );

    testWidgets('kartu akun dan kategori tampil', (tester) async {
      await pump(tester);
      expect(find.text('Azka'), findsOneWidget);
      expect(find.text('azka@its.ac.id'), findsOneWidget);
      for (final t in ['Notifikasi', 'Akun', 'Keamanan', 'Tentang Collab']) {
        expect(find.text(t), findsOneWidget);
      }
    });

    testWidgets('pencarian menyaring kategori', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'sandi');
      await tester.pump();
      expect(find.text('Keamanan'), findsOneWidget);
      expect(find.text('Notifikasi'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Tidak ada pengaturan yang cocok'), findsOneWidget);
    });

    testWidgets('keluar akun memanggil onSignOut', (tester) async {
      var out = false;
      await pump(tester, onSignOut: () => out = true);
      await tester.tap(find.text('Keluar akun'));
      expect(out, isTrue);
    });
  });
}
