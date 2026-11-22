import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/screens/welcome_screen.dart';
import 'package:collab/utils/theme.dart';

void main() {
  testWidgets('welcome menampilkan logo dan tulisan Collab di tengah', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: collabTheme, home: const WelcomeView()),
    );
    final logo = find.byKey(const Key('welcome-logo'));
    expect(logo, findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('Collab'), findsOneWidget);
    final screen = tester.getRect(find.byType(Scaffold));
    expect(tester.getCenter(logo).dx, closeTo(screen.center.dx, 0.5));
    expect(
      tester.getTopLeft(find.text('Collab')).dy,
      greaterThan(tester.getBottomLeft(logo).dy),
    );
  });

  testWidgets('welcome pindah ke halaman berikutnya setelah jeda', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: collabTheme,
        home: const WelcomeScreen(
          duration: Duration(milliseconds: 300),
          next: Scaffold(body: Text('halaman login')),
        ),
      ),
    );
    expect(find.text('halaman login'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('halaman login'), findsOneWidget);
    expect(find.byKey(const Key('welcome-logo')), findsNothing);
  });
}
