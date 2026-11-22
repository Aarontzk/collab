import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Spring gaya Apple, ditulis dengan dua parameter yang dipakai desainer:
/// [dampingRatio] (1.0 = tanpa pantulan) dan [response] (detik, makin kecil
/// makin cepat). Dikonversi ke massa/kekakuan/redaman milik Flutter.
SpringDescription appleSpring({
  double dampingRatio = 1.0,
  double response = 0.3,
}) {
  final stiffness = math.pow(2 * math.pi / response, 2).toDouble();
  final damping = 4 * math.pi * dampingRatio / response;
  return SpringDescription(mass: 1, stiffness: stiffness, damping: damping);
}

/// Mengecilkan [child] sedikit begitu jari menyentuh (bukan saat dilepas),
/// lalu kembali dengan spring. Animasi selalu mulai dari nilai yang sedang
/// tampil plus kecepatannya, jadi bisa disela kapan saja tanpa loncat.
///
/// Kalau sistem minta animasi dikurangi, skala tidak berubah sama sekali;
/// ripple bawaan InkWell tetap jadi tanda tekan.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  static final _spring = appleSpring();

  // Tanpa batas bawah/atas supaya spring boleh lewat sedikit tanpa terpotong.
  late final _controller = AnimationController.unbounded(vsync: this, value: 1);

  void _animateTo(double target) {
    _controller.animateWith(
      SpringSimulation(
        _spring,
        _controller.value,
        target,
        _controller.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.enabled || reduceMotion) return widget.child;
    return Listener(
      onPointerDown: (_) => _animateTo(widget.pressedScale),
      onPointerUp: (_) => _animateTo(1),
      onPointerCancel: (_) => _animateTo(1),
      child: ScaleTransition(scale: _controller, child: widget.child),
    );
  }
}
