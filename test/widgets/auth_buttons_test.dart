import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/auth_buttons.dart';

void main() {
  testWidgets('logo tombol login rata kiri, tulisan di tengah', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: collabTheme,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: SocialAuthButtons(verb: 'Masuk'),
            ),
          ),
        ),
      ),
    );

    for (final (button, label) in [
      (find.byType(FilledButton), 'Masuk dengan MyITS'),
      (find.byType(OutlinedButton), 'Masuk dengan Google'),
    ]) {
      final box = tester.getRect(button);
      final text = tester.getRect(find.text(label));
      final logo = tester.getRect(
        find.descendant(of: button, matching: find.byType(SizedBox)).first,
      );
      // Logo nempel di kiri (padding tombol 16), tulisan di tengah tombol.
      expect(logo.left - box.left, closeTo(16, 0.5));
      expect(text.center.dx, closeTo(box.center.dx, 0.5));
    }
  });
}
