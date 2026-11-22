import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/models/profile.dart';
import 'package:collab/screens/profile_screen.dart';
import 'package:collab/utils/theme.dart';

void main() {
  const azka = Profile(id: 'u1', fullName: 'Azka', nrp: '5025231001');

  Future<List<(String, String)>> pump(
    WidgetTester tester, {
    VoidCallback? onSignOut,
  }) async {
    final saves = <(String, String)>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: collabTheme,
        home: Scaffold(
          body: ProfileView(
            profile: azka,
            email: 'azka@student.its.ac.id',
            onSave: (name, nrp) async {
              saves.add((name, nrp));
              return Profile(id: 'u1', fullName: name.trim(), nrp: nrp);
            },
            onSignOut: onSignOut ?? () {},
          ),
        ),
      ),
    );
    return saves;
  }

  testWidgets('menampilkan avatar, nama, email, dan data awal', (tester) async {
    await pump(tester);
    expect(find.text('A'), findsOneWidget); // inisial avatar
    expect(find.text('Azka'), findsWidgets);
    expect(find.text('azka@student.its.ac.id'), findsOneWidget);
    expect(find.text('5025231001'), findsOneWidget);
  });

  testWidgets('NRP berlabel opsional dengan syarat berpoin', (tester) async {
    await pump(tester);
    expect(find.text('NRP (Opsional)', findRichText: true), findsOneWidget);
    expect(find.text('Hanya angka'), findsOneWidget);
    expect(find.text('5–20 digit'), findsOneWidget);
  });

  testWidgets('NRP tidak valid tidak disimpan', (tester) async {
    final saves = await pump(tester);
    await tester.enterText(find.byType(TextFormField).last, '12ab');
    await tester.pump();
    await tester.tap(find.text('Simpan perubahan'));
    await tester.pump();
    expect(find.text('NRP hanya angka, 5-20 digit'), findsOneWidget);
    expect(saves, isEmpty);
  });

  testWidgets('simpan memperbarui nama di header', (tester) async {
    final saves = await pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Azka Putra');
    await tester.pump();
    await tester.tap(find.text('Simpan perubahan'));
    await tester.pumpAndSettle();
    expect(saves, [('Azka Putra', '5025231001')]);
    expect(find.text('Profil disimpan'), findsOneWidget);
    // Header + field sama-sama menampilkan nama baru.
    expect(find.text('Azka Putra'), findsNWidgets(2));
  });

  testWidgets('tombol keluar akun memanggil onSignOut', (tester) async {
    var signedOut = false;
    await pump(tester, onSignOut: () => signedOut = true);
    await tester.scrollUntilVisible(
      find.text('Keluar akun'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Keluar akun'));
    expect(signedOut, isTrue);
  });
}
