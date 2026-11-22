import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/models/profile.dart';
import 'package:collab/screens/profile_screen.dart';
import 'package:collab/services/profile_service.dart';
import 'package:collab/utils/theme.dart';

class _FakeProfiles extends ProfileService {
  Profile current = const Profile(id: 'u1', fullName: 'Azka');

  @override
  String? get email => 'azka@student.its.ac.id';

  @override
  Future<Profile> fetchMine() async => current;

  @override
  Future<Profile> updateMine({
    required String fullName,
    required String nrp,
  }) async => current = Profile(id: 'u1', fullName: fullName, nrp: nrp);
}

void main() {
  Future<bool?> openProfile(
    WidgetTester tester,
    _FakeProfiles fake, {
    required Future<void> Function() whileOpen,
  }) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: collabTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(service: fake),
                  ),
                );
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await whileOpen();
    await tester.pageBack();
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('kembali tanpa simpan mengembalikan false', (tester) async {
    final result = await openProfile(
      tester,
      _FakeProfiles(),
      whileOpen: () async => expect(find.text('Profil'), findsOneWidget),
    );
    expect(result, isFalse);
  });

  testWidgets('kembali setelah simpan mengembalikan true', (tester) async {
    final fake = _FakeProfiles();
    final result = await openProfile(
      tester,
      fake,
      whileOpen: () async {
        await tester.enterText(find.byType(TextFormField).last, '5026241130');
        await tester.pump();
        await tester.tap(find.text('Simpan perubahan'));
        await tester.pumpAndSettle();
      },
    );
    expect(result, isTrue);
    expect(fake.current.nrp, '5026241130');
  });
}
