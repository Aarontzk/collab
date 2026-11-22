import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collab/utils/app_assets.dart';
import 'package:collab/utils/theme.dart';

/// Layar pembuka berisi logo saja, gayanya mengikuti cover (Figma: AZKA/Welcome).
/// Tampil sebentar lalu pindah ke [next] dengan efek pudar.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.next,
    this.duration = const Duration(milliseconds: 1500),
  });

  final Widget next;
  final Duration duration;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.duration, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => widget.next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const WelcomeView();
}

/// Tampilan layar pembuka tanpa logika navigasi, supaya bisa dites.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  // Ukuran di Figma dibuat untuk lebar 412; semua dekor diskalakan dari sini.
  static const _designWidth = 412.0;
  static const _logoSize = 144.0;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, box) {
            final s = box.maxWidth / _designWidth;
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ItsColors.blue, ItsColors.skyBlue],
                ),
              ),
              child: Stack(
                children: [
                  // Dekor kiri atas.
                  _circle(s, left: -195, top: -195, size: 390, outline: true),
                  _circle(
                    s,
                    left: -165,
                    top: -165,
                    size: 330,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  _circle(
                    s,
                    left: -121,
                    top: -121,
                    size: 243,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                  _circle(
                    s,
                    left: -78,
                    top: -78,
                    size: 156,
                    color: ItsColors.lightBlue.withValues(alpha: 0.35),
                  ),
                  // Dekor kanan bawah.
                  _circle(
                    s,
                    right: -169,
                    bottom: -169,
                    size: 338,
                    color: ItsColors.lightBlue.withValues(alpha: 0.18),
                  ),
                  _circle(
                    s,
                    right: -126,
                    bottom: -126,
                    size: 252,
                    color: ItsColors.lightBlue.withValues(alpha: 0.22),
                  ),
                  _circle(
                    s,
                    right: -83,
                    bottom: -83,
                    size: 165,
                    color: ItsColors.lightBlue.withValues(alpha: 0.30),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          // Pendar putih di belakang logo, sama dengan cover.
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.48),
                                blurRadius: 28,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            AppAssets.logoMark,
                            key: const Key('welcome-logo'),
                            width: _logoSize,
                            height: _logoSize,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Collab',
                          style: TextStyle(
                            fontFamily: AppFonts.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 45,
                            height: 1.25,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _circle(
    double s, {
    double? left,
    double? top,
    double? right,
    double? bottom,
    required double size,
    Color? color,
    bool outline = false,
  }) {
    return Positioned(
      left: left == null ? null : left * s,
      top: top == null ? null : top * s,
      right: right == null ? null : right * s,
      bottom: bottom == null ? null : bottom * s,
      width: size * s,
      height: size * s,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: outline
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 0.65,
                )
              : null,
        ),
      ),
    );
  }
}
