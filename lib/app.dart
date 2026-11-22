import 'package:flutter/material.dart';

import 'package:collab/utils/theme.dart';
import 'package:collab/screens/auth_gate.dart';
import 'package:collab/screens/welcome_screen.dart';

class CollabApp extends StatelessWidget {
  const CollabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collab',
      debugShowCheckedModeBanner: false,
      theme: collabTheme,
      scrollBehavior: const CollabScrollBehavior(),
      home: const WelcomeScreen(next: AuthGate()),
    );
  }
}

/// Ditampilkan kalau aplikasi dijalankan tanpa env.json.
class MissingEnvApp extends StatelessWidget {
  const MissingEnvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: collabTheme,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Kunci Supabase belum diisi.\n\n'
              '1. Salin env.example.json menjadi env.json\n'
              '2. Isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY\n'
              '3. Jalankan: flutter run --dart-define-from-file=env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Scroll mentul di ujung (rubber-band) di semua platform, bukan efek
/// glow Android yang berhenti mendadak. Mouse juga bisa menyeret di web.
class CollabScrollBehavior extends MaterialScrollBehavior {
  const CollabScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
