import 'package:collab/widgets/press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _scaleOf(WidgetTester tester) =>
    tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;

void main() {
  test('dampingRatio 1.0 menghasilkan spring teredam kritis', () {
    final s = appleSpring(dampingRatio: 1.0, response: 0.3);
    // Teredam kritis: c^2 = 4 * m * k.
    expect(s.damping * s.damping, closeTo(4 * s.mass * s.stiffness, 1e-6));
  });

  testWidgets('mengecil saat ditekan dan kembali saat dilepas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: PressScale(
            child: ColoredBox(
              color: Colors.blue,
              child: SizedBox.square(dimension: 100),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressScale)),
    );
    await tester.pumpAndSettle();
    expect(_scaleOf(tester), closeTo(0.97, 0.001));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_scaleOf(tester), closeTo(1.0, 0.001));
  });

  testWidgets('tidak beranimasi kalau animasi sistem dimatikan', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: PressScale(
          child: ColoredBox(
            color: Colors.blue,
            child: SizedBox.square(dimension: 100),
          ),
        ),
      ),
    );
    expect(find.byType(ScaleTransition), findsNothing);
  });
}
